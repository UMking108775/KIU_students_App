import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:intl/intl.dart';
import '../../../config/app_theme.dart';
import '../../../services/pdf_creator_service.dart';
import 'tool_card_style.dart';

/// Helpers for choosing a source PDF, shared by the Organize / Compress / Split
/// tools. Source can be one of the student's saved PDFs ("My PDFs") or any PDF
/// from device storage (via the system file picker).
class PdfSourcePicker {
  static final PdfCreatorService _creator = PdfCreatorService();

  /// Shows a sheet of the student's saved PDFs. Returns the chosen file, or
  /// null if there are none / the sheet was dismissed.
  static Future<File?> pickFromLibrary(BuildContext context) async {
    final files = await _creator.listSavedPdfs();
    if (!context.mounted) return null;
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have no PDFs in "My PDFs" yet.')),
      );
      return null;
    }
    return _showLibrarySheet(context, files);
  }

  /// Opens the system file picker filtered to PDFs. Returns null if cancelled.
  static Future<File?> pickFromDevice() async {
    final path = await FlutterFileDialog.pickFile(
      params: const OpenFileDialogParams(
        dialogType: OpenFileDialogType.document,
        fileExtensionsFilter: ['pdf'],
        mimeTypesFilter: ['application/pdf'],
      ),
    );
    return path == null ? null : File(path);
  }

  static Future<File?> _showLibrarySheet(
    BuildContext context,
    List<File> files,
  ) {
    final colors = AppColors.of(context);
    return showModalBottomSheet<File>(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.6,
            ),
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
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.folder_copy_rounded, color: colors.accent),
                      const SizedBox(width: 10),
                      Text(
                        'Choose from My PDFs',
                        style: Theme.of(sheetContext).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: files.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: colors.divider),
                    itemBuilder: (context, index) {
                      final file = files[index];
                      final stat = file.statSync();
                      return ListTile(
                        leading: Icon(
                          Icons.picture_as_pdf_rounded,
                          color: colors.error,
                        ),
                        title: Text(
                          PdfCreatorService.displayName(file),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${DateFormat('d MMM yyyy').format(stat.modified)}'
                          '  •  ${PdfCreatorService.formatSize(stat.size)}',
                        ),
                        onTap: () => Navigator.pop(sheetContext, file),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The empty-state UI shown by PDF tools before a source is chosen: a heading
/// plus two big buttons (My PDFs / device storage). Calls [onPicked] with the
/// chosen file.
class PdfSourceSelector extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String urduLine;
  final String englishLine;
  final ValueChanged<File> onPicked;

  const PdfSourceSelector({
    super.key,
    required this.icon,
    required this.title,
    required this.urduLine,
    required this.englishLine,
    required this.onPicked,
    this.iconColor,
  });

  Future<void> _fromLibrary(BuildContext context) async {
    final file = await PdfSourcePicker.pickFromLibrary(context);
    if (file != null) onPicked(file);
  }

  Future<void> _fromDevice(BuildContext context) async {
    try {
      final file = await PdfSourcePicker.pickFromDevice();
      if (file != null) onPicked(file);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the file picker. ($e)')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final accent = iconColor ?? colors.accent;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 42, color: accent),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '$urduLine\n$englishLine',
            style: TextStyle(color: colors.textSecondary, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          PdfSourceCard(
            icon: Icons.folder_copy_rounded,
            iconColor: colors.accent,
            title: 'Choose from My PDFs',
            subtitle: 'PDFs you created in this app',
            onTap: () => _fromLibrary(context),
          ),
          const SizedBox(height: 14),
          PdfSourceCard(
            icon: Icons.sd_storage_rounded,
            iconColor: colors.primary,
            title: 'Choose from device storage',
            subtitle: 'Any PDF on your phone',
            onTap: () => _fromDevice(context),
          ),
        ],
      ),
    );
  }
}

/// A large tappable "source" button used in [PdfSourceSelector].
class PdfSourceCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const PdfSourceCard({
    super.key,
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
