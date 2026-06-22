import 'dart:io';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../services/pdf_creator_service.dart';
import 'pdf_result_screen.dart';
import 'widgets/tool_card_style.dart';

/// A single page in the document being built. Carries a stable [id] so the
/// reorderable list keeps working even if the same image is added twice.
class _PageItem {
  final String path;
  final int id;
  const _PageItem(this.path, this.id);
}

/// Tool: capture/select images → build a PDF → preview & save.
class ScanToPdfScreen extends StatefulWidget {
  const ScanToPdfScreen({super.key});

  @override
  State<ScanToPdfScreen> createState() => _ScanToPdfScreenState();
}

class _ScanToPdfScreenState extends State<ScanToPdfScreen> {
  final PdfCreatorService _pdfService = PdfCreatorService();
  final ImagePicker _imagePicker = ImagePicker();

  final List<_PageItem> _pages = [];
  int _nextId = 0;
  bool _isCreating = false;

  bool get _hasPages => _pages.isNotEmpty;

  // ---------------------------------------------------------------------------
  // Adding pages
  // ---------------------------------------------------------------------------

  Future<void> _scanWithCamera() async {
    try {
      final paths = await CunningDocumentScanner.getPictures(
        noOfPages: 50,
        isGalleryImportAllowed: false,
      );
      if (paths != null && paths.isNotEmpty) {
        _addPaths(paths);
      }
    } catch (e) {
      _showError(
        'Camera scanner could not start. Please make sure Google Play '
        'Services is up to date.\n\n($e)',
      );
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await _imagePicker.pickMultiImage();
      if (picked.isNotEmpty) {
        _addPaths(picked.map((x) => x.path).toList());
      }
    } catch (e) {
      _showError('Could not open the gallery.\n\n($e)');
    }
  }

  void _addPaths(List<String> paths) {
    setState(() {
      for (final p in paths) {
        _pages.add(_PageItem(p, _nextId++));
      }
    });
  }

  void _showAddSheet() {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: _SheetIcon(
                  icon: Icons.document_scanner_rounded,
                  color: colors.primary,
                ),
                title: const Text('Scan with Camera'),
                subtitle: const Text('Auto-crop & clean up the page'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _scanWithCamera();
                },
              ),
              ListTile(
                leading: _SheetIcon(
                  icon: Icons.photo_library_rounded,
                  color: colors.accent,
                ),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Pick existing photos'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickFromGallery();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Editing pages
  // ---------------------------------------------------------------------------

  void _removePage(_PageItem item) {
    setState(() => _pages.removeWhere((p) => p.id == item.id));
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, item);
    });
  }

  // ---------------------------------------------------------------------------
  // Creating the PDF
  // ---------------------------------------------------------------------------

  Future<void> _startCreate() async {
    final defaultName =
        'Assignment_${DateFormat('yyyy-MM-dd').format(DateTime.now())}';
    final name = await _askFileName(defaultName);
    if (name == null) return; // cancelled

    setState(() => _isCreating = true);
    try {
      final file = await _pdfService.createPdfFromImages(
        imagePaths: _pages.map((p) => p.path).toList(),
        fileName: name,
      );
      if (!mounted) return;
      setState(() => _isCreating = false);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PdfResultScreen(file: file, pageCount: _pages.length),
        ),
      );
      // Returning here keeps the captured pages so the student can tweak and
      // re-export if they want; they can also just leave the screen.
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      _showError('Could not create the PDF.\n\n($e)');
    }
  }

  Future<String?> _askFileName(String defaultName) {
    final controller = TextEditingController(text: defaultName);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Name your PDF'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'File name',
              suffixText: '.pdf',
            ),
            onSubmitted: (v) => Navigator.pop(dialogContext, v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Create PDF'),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Navigation guard
  // ---------------------------------------------------------------------------

  Future<bool> _confirmDiscard() async {
    if (!_hasPages) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard pages?'),
        content: const Text(
          'You have unsaved pages. Leaving now will remove them.',
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.of(context).error,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return PopScope(
      canPop: !_hasPages,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final shouldDiscard = await _confirmDiscard();
        if (shouldDiscard) navigator.pop();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: const Text('Scan & Make PDF'),
          actions: [
            if (_hasPages)
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
            _hasPages ? _buildReview(colors) : _buildEmptyState(colors),
            if (_isCreating) _buildCreatingOverlay(colors),
          ],
        ),
      ),
    );
  }

  // Empty state: two big entry buttons.
  Widget _buildEmptyState(ThemeColors colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.picture_as_pdf_rounded,
              size: 42,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Create an Assignment PDF',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'اپنی اسائنمنٹ یا نوٹس کی تصویر سے پی ڈی ایف بنائیں\n'
            'Scan your pages or pick photos, then save as one PDF.',
            style: TextStyle(color: colors.textSecondary, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          _EntryCard(
            icon: Icons.document_scanner_rounded,
            iconColor: colors.primary,
            title: 'Scan with Camera',
            subtitle: 'Auto-crop, straighten & clean up each page',
            onTap: _scanWithCamera,
          ),
          const SizedBox(height: 14),
          _EntryCard(
            icon: Icons.photo_library_rounded,
            iconColor: colors.accent,
            title: 'Choose from Gallery',
            subtitle: 'Select one or more existing photos',
            onTap: _pickFromGallery,
          ),
          const SizedBox(height: 24),
          _TipRow(
            colors: colors,
            text: 'Tip: You can add more pages and reorder them before saving.',
          ),
        ],
      ),
    );
  }

  // Review state: reorderable list of pages + bottom action bar.
  Widget _buildReview(ThemeColors colors) {
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
                  'Hold and drag to reorder pages',
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
              final item = _pages[index];
              return _PageTile(
                key: ValueKey(item.id),
                index: index,
                path: item.path,
                colors: colors,
                onDelete: () => _removePage(item),
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
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isCreating ? null : _showAddSheet,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Add pages'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.primary,
                side: BorderSide(color: colors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isCreating ? null : _startCreate,
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
              label: const Text('Create PDF'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatingOverlay(ThemeColors colors) {
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
                  'Creating PDF…',
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

class _EntryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _EntryCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: toolCardDecoration(context),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PageTile extends StatelessWidget {
  final int index;
  final String path;
  final ThemeColors colors;
  final VoidCallback onDelete;

  const _PageTile({
    required super.key,
    required this.index,
    required this.path,
    required this.colors,
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
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(path),
                width: 52,
                height: 68,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  width: 52,
                  height: 68,
                  color: colors.border,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: colors.textHint,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Page ${index + 1}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline_rounded, color: colors.error),
              tooltip: 'Remove page',
            ),
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.drag_handle_rounded, color: colors.textHint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _SheetIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _TipRow extends StatelessWidget {
  final ThemeColors colors;
  final String text;
  const _TipRow({required this.colors, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline_rounded, size: 18, color: colors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
