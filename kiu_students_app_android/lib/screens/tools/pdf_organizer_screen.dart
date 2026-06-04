import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../widgets/common/text_prompt_dialog.dart';
import '../../services/pdf_creator_service.dart';
import '../../services/pdf_organizer_service.dart';
import 'pdf_result_screen.dart';
import 'widgets/pdf_source_selector.dart';

/// One page tile in the organizer. [id] is unique per tile (so a duplicated
/// page — which shares [originalIndex] — still has a stable reorder/animation
/// key). [rotation] is clockwise quarter-turns (0..3) applied on save.
class _OrgPage {
  final int id;
  final int originalIndex;
  final List<int> thumbnail;
  int rotation;
  _OrgPage(this.id, this.originalIndex, this.thumbnail, {this.rotation = 0});
}

/// Tool: open an existing PDF (from My PDFs or device storage), reorder/delete
/// its pages, and save the result as a new PDF.
class PdfOrganizerScreen extends StatefulWidget {
  /// When provided (e.g. launched from "My PDFs"), skips source selection.
  final File? initialFile;

  const PdfOrganizerScreen({super.key, this.initialFile});

  @override
  State<PdfOrganizerScreen> createState() => _PdfOrganizerScreenState();
}

class _PdfOrganizerScreenState extends State<PdfOrganizerScreen> {
  final PdfOrganizerService _organizer = PdfOrganizerService();

  File? _source;
  Uint8List? _sourceBytes;
  final List<_OrgPage> _pages = [];
  int _nextId = 0;

  bool _loading = false;
  bool _saving = false;
  bool _modified = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadSource(widget.initialFile!);
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Source selection + loading
  // ---------------------------------------------------------------------------

  Future<void> _loadSource(File file) async {
    setState(() {
      _source = file;
      _loading = true;
      _modified = false;
      _pages.clear();
    });

    try {
      final bytes = await file.readAsBytes();
      final thumbs = await _organizer.renderThumbnails(bytes);
      if (!mounted) return;
      if (thumbs.isEmpty) {
        throw Exception('This PDF has no readable pages.');
      }
      setState(() {
        _sourceBytes = bytes;
        for (var i = 0; i < thumbs.length; i++) {
          _pages.add(_OrgPage(_nextId++, i, thumbs[i]));
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _source = null;
        _sourceBytes = null;
        _pages.clear();
      });
      _snack(
        'Could not open this PDF. It may be password-protected or damaged.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Editing
  // ---------------------------------------------------------------------------

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final page = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, page);
      _modified = true;
    });
  }

  void _deletePage(_OrgPage page) {
    if (_pages.length <= 1) {
      _snack('A PDF must keep at least one page.');
      return;
    }
    setState(() {
      _pages.removeWhere((p) => p.id == page.id);
      _modified = true;
    });
  }

  void _rotatePage(_OrgPage page) {
    setState(() {
      page.rotation = (page.rotation + 1) % 4;
      _modified = true;
    });
  }

  /// Opens a large, zoomable preview of the page (rendered crisply on demand).
  Future<void> _previewPage(_OrgPage page) async {
    if (_sourceBytes == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _PagePreviewDialog(
        future: _organizer.renderPage(_sourceBytes!, page.originalIndex),
        rotation: page.rotation,
      ),
    );
  }

  void _duplicatePage(_OrgPage page) {
    setState(() {
      final at = _pages.indexWhere((p) => p.id == page.id);
      _pages.insert(
        at + 1,
        _OrgPage(_nextId++, page.originalIndex, page.thumbnail,
            rotation: page.rotation),
      );
      _modified = true;
    });
  }

  // ---------------------------------------------------------------------------
  // Saving
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    if (_sourceBytes == null || _pages.isEmpty) return;

    final base = _source != null
        ? PdfCreatorService.displayName(_source!)
        : 'Document';
    final name = await _askFileName('${base}_organized');
    if (name == null) return;

    setState(() => _saving = true);
    try {
      final file = await _organizer.buildReorganizedPdf(
        sourceBytes: _sourceBytes!,
        orderedZeroBasedIndices: _pages.map((p) => p.originalIndex).toList(),
        rotationsQuarterTurns: _pages.map((p) => p.rotation).toList(),
        fileName: name,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _modified = false;
      });
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfResultScreen(file: file, pageCount: _pages.length),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Could not save the organized PDF. ($e)');
    }
  }

  Future<String?> _askFileName(String defaultName) {
    return showDialog<String>(
      context: context,
      builder: (_) => TextPromptDialog(
        title: 'Save organized PDF',
        label: 'File name',
        initialText: defaultName,
        suffixText: '.pdf',
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Misc
  // ---------------------------------------------------------------------------

  Future<bool> _confirmDiscard() async {
    if (!_modified) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'Your page changes have not been saved. Leave without saving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.of(context).error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _snack(String message, {bool success = false}) {
    if (!mounted) return;
    final colors = AppColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? colors.success : colors.error,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasPages = _pages.isNotEmpty;

    return PopScope(
      canPop: !_modified,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) navigator.pop();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: const Text('Organize PDF'),
          actions: [
            if (hasPages)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Text(
                    '${_pages.length} page${_pages.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: Stack(
          children: [
            if (_loading)
              _buildLoading(colors)
            else if (hasPages)
              _buildOrganizer(colors)
            else
              _buildEmptyState(colors),
            if (_saving) _buildSavingOverlay(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading(ThemeColors colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: colors.primary),
          const SizedBox(height: 16),
          Text(
            'Opening PDF…',
            style: TextStyle(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeColors colors) {
    return PdfSourceSelector(
      icon: Icons.reorder_rounded,
      iconColor: colors.accent,
      title: 'Organize PDF Pages',
      urduLine: 'صفحات کو آگے پیچھے کریں یا غیر ضروری صفحہ حذف کریں',
      englishLine: 'Reorder pages or remove the ones you don\'t need.',
      onPicked: _loadSource,
    );
  }

  Widget _buildOrganizer(ThemeColors colors) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Icon(Icons.touch_app_rounded, size: 16, color: colors.textHint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tap a page to preview • drag to reorder • rotate / duplicate / remove',
                  style: TextStyle(fontSize: 12, color: colors.textHint),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            itemCount: _pages.length,
            onReorder: _onReorder,
            itemBuilder: (context, index) {
              final page = _pages[index];
              return _OrgPageTile(
                key: ValueKey(page.id),
                position: index + 1,
                thumbnail: page.thumbnail,
                rotation: page.rotation,
                colors: colors,
                onPreview: () => _previewPage(page),
                onRotate: () => _rotatePage(page),
                onDuplicate: () => _duplicatePage(page),
                onDelete: () => _deletePage(page),
              );
            },
          ),
        ),
        _buildBottomBar(colors),
      ],
    );
  }

  Widget _buildBottomBar(ThemeColors colors) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save_rounded, size: 20),
          label: const Text('Save PDF'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildSavingOverlay(ThemeColors colors) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: colors.primary),
                const SizedBox(height: 16),
                Text(
                  'Saving…',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Sub-widgets
// -----------------------------------------------------------------------------

class _OrgPageTile extends StatelessWidget {
  final int position;
  final List<int> thumbnail;
  final int rotation;
  final ThemeColors colors;
  final VoidCallback onPreview;
  final VoidCallback onRotate;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _OrgPageTile({
    required super.key,
    required this.position,
    required this.thumbnail,
    required this.rotation,
    required this.colors,
    required this.onPreview,
    required this.onRotate,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            // Thumbnail (tap to preview; shown turned to reflect rotation).
            InkWell(
              onTap: onPreview,
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 56,
                      height: 74,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: RotatedBox(
                          quarterTurns: rotation,
                          child: Image.memory(
                            Uint8List.fromList(thumbnail),
                            width: 56,
                            height: 74,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (context, error, stack) => Container(
                              width: 56,
                              height: 74,
                              color: colors.border,
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: colors.textHint,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.zoom_in_rounded,
                          size: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Page $position',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (rotation != 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Rotated ${rotation * 90}°',
                      style: TextStyle(fontSize: 11, color: colors.textHint),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: onRotate,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.rotate_right_rounded, color: colors.primary),
              tooltip: 'Rotate',
            ),
            PopupMenuButton<int>(
              icon: Icon(Icons.more_vert_rounded, color: colors.textSecondary),
              onSelected: (v) {
                if (v == 0) onDuplicate();
                if (v == 1) onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 0,
                  child: ListTile(
                    leading: Icon(Icons.copy_all_rounded),
                    title: Text('Duplicate'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 1,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline_rounded,
                        color: colors.error),
                    title: const Text('Remove'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            ReorderableDragStartListener(
              index: position - 1,
              child: Icon(Icons.drag_handle_rounded, color: colors.textHint),
            ),
          ],
        ),
      ),
    );
  }
}

/// A full-size, pinch-zoomable preview of a single page (rendered on demand).
class _PagePreviewDialog extends StatelessWidget {
  final Future<Uint8List?> future;
  final int rotation;

  const _PagePreviewDialog({required this.future, required this.rotation});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(10),
      child: Stack(
        children: [
          Positioned.fill(
            child: FutureBuilder<Uint8List?>(
              future: future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }
                final png = snap.data;
                if (png == null) {
                  return const Center(
                    child: Text(
                      'Could not render this page.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }
                return InteractiveViewer(
                  maxScale: 5,
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: rotation,
                      child: Image.memory(png, fit: BoxFit.contain),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
