import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../widgets/common/text_prompt_dialog.dart';
import '../../services/pdf_creator_service.dart';
import 'pdf_result_screen.dart';
import 'pdf_organizer_screen.dart';
import 'scan_to_pdf_screen.dart';
import 'widgets/tool_card_style.dart';

/// History of PDFs the student has created with the Scan & Make PDF tool.
class MyPdfsScreen extends StatefulWidget {
  const MyPdfsScreen({super.key});

  @override
  State<MyPdfsScreen> createState() => _MyPdfsScreenState();
}

class _MyPdfsScreenState extends State<MyPdfsScreen> {
  final PdfCreatorService _pdfService = PdfCreatorService();
  final TextEditingController _searchCtrl = TextEditingController();
  List<File> _files = [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final files = await _pdfService.listSavedPdfs();
    if (mounted) {
      setState(() {
        _files = files;
        _loading = false;
      });
    }
  }

  Future<void> _open(File file) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfResultScreen(file: file, justCreated: false),
      ),
    );
    _load(); // refresh in case it was renamed/deleted from the viewer later
  }

  Future<void> _share(File file) async {
    try {
      await _pdfService.sharePdf(
        file,
        text: PdfCreatorService.displayName(file),
      );
    } catch (e) {
      _snack('Could not share. ($e)');
    }
  }

  Future<void> _saveToDevice(File file) async {
    try {
      final path = await _pdfService.saveToDevice(file);
      if (path != null) _snack('Saved to your device.', success: true);
    } catch (e) {
      _snack('Could not save. ($e)');
    }
  }

  Future<void> _organize(File file) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfOrganizerScreen(initialFile: file),
      ),
    );
    _load(); // a new organized PDF may have been saved
  }

  Future<void> _rename(File file) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => TextPromptDialog(
        title: 'Rename PDF',
        label: 'File name',
        initialText: PdfCreatorService.displayName(file),
        suffixText: '.pdf',
      ),
    );

    if (newName == null || newName.trim().isEmpty) return;
    try {
      await _pdfService.renamePdf(file, newName);
      _load();
    } catch (e) {
      _snack('Could not rename. ($e)');
    }
  }

  Future<void> _delete(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete PDF?'),
        content: Text(
          'Delete "${PdfCreatorService.displayName(file)}"? This cannot be '
          'undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.of(context).error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _pdfService.deletePdf(file);
      _load();
    }
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

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('My PDFs')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ScanToPdfScreen()),
          );
          _load();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New PDF'),
      ),
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(ThemeColors colors) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_files.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_open_rounded, size: 64, color: colors.textHint),
              const SizedBox(height: 16),
              Text(
                'No PDFs yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap "New PDF" to scan or pick images and create your first '
                'assignment PDF.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _files
        : _files
            .where((f) =>
                PdfCreatorService.displayName(f).toLowerCase().contains(q))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Container(
            decoration: toolCardDecoration(context),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search PDFs',
                prefixIcon:
                    Icon(Icons.search_rounded, color: colors.textSecondary),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: colors.textSecondary),
                        tooltip: 'Clear',
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
              ),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No PDFs match "${_query.trim()}".',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final file = filtered[index];
                      final stat = file.statSync();
                      final subtitle =
                          '${DateFormat('d MMM yyyy, h:mm a').format(stat.modified)}'
                          '  •  ${PdfCreatorService.formatSize(stat.size)}';

                      return _PdfListTile(
                        colors: colors,
                        name: PdfCreatorService.displayName(file),
                        subtitle: subtitle,
                        onTap: () => _open(file),
                        onAction: (action) {
                          switch (action) {
                            case _PdfAction.open:
                              _open(file);
                            case _PdfAction.organize:
                              _organize(file);
                            case _PdfAction.share:
                              _share(file);
                            case _PdfAction.save:
                              _saveToDevice(file);
                            case _PdfAction.rename:
                              _rename(file);
                            case _PdfAction.delete:
                              _delete(file);
                          }
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

enum _PdfAction { open, organize, share, save, rename, delete }

class _PdfListTile extends StatelessWidget {
  final ThemeColors colors;
  final String name;
  final String subtitle;
  final VoidCallback onTap;
  final ValueChanged<_PdfAction> onAction;

  const _PdfListTile({
    required this.colors,
    required this.name,
    required this.subtitle,
    required this.onTap,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: toolCardDecoration(context),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.picture_as_pdf_rounded,
                  color: colors.error,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_PdfAction>(
                icon: Icon(Icons.more_vert_rounded, color: colors.textSecondary),
                onSelected: onAction,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _PdfAction.open,
                    child: _MenuRow(icon: Icons.visibility_outlined, label: 'Open'),
                  ),
                  PopupMenuItem(
                    value: _PdfAction.organize,
                    child: _MenuRow(
                      icon: Icons.reorder_rounded,
                      label: 'Organize pages',
                    ),
                  ),
                  PopupMenuItem(
                    value: _PdfAction.share,
                    child: _MenuRow(icon: Icons.share_outlined, label: 'Share'),
                  ),
                  PopupMenuItem(
                    value: _PdfAction.save,
                    child: _MenuRow(
                      icon: Icons.save_alt_outlined,
                      label: 'Save to device',
                    ),
                  ),
                  PopupMenuItem(
                    value: _PdfAction.rename,
                    child: _MenuRow(
                      icon: Icons.drive_file_rename_outline,
                      label: 'Rename',
                    ),
                  ),
                  PopupMenuItem(
                    value: _PdfAction.delete,
                    child: _MenuRow(
                      icon: Icons.delete_outline,
                      label: 'Delete',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}
