import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../config/app_routes.dart';
import '../../config/app_theme.dart';
import '../../services/pdf_creator_service.dart';

/// Shows a created (or saved) PDF with an in-app preview and the actions a
/// student needs: share to a teacher, or save a copy to a chosen location.
class PdfResultScreen extends StatefulWidget {
  final File file;

  /// Number of pages, when known (right after creation). Optional.
  final int? pageCount;

  /// When true, shows the "Saved" success banner (freshly created PDFs).
  final bool justCreated;

  /// Optional custom text for the success banner (e.g. compression savings).
  /// Falls back to the default "PDF created and saved" message.
  final String? successMessage;

  const PdfResultScreen({
    super.key,
    required this.file,
    this.pageCount,
    this.justCreated = true,
    this.successMessage,
  });

  @override
  State<PdfResultScreen> createState() => _PdfResultScreenState();
}

class _PdfResultScreenState extends State<PdfResultScreen> {
  final PdfCreatorService _pdfService = PdfCreatorService();
  // Read once so PdfPreview doesn't re-rasterise on every rebuild.
  late final Future<Uint8List> _pdfBytes = widget.file.readAsBytes();
  bool _busy = false;

  /// Opens the system print sheet (print, save-as-PDF, or send to a printer app).
  Future<void> _print() async {
    try {
      final bytes = await _pdfBytes;
      await Printing.layoutPdf(
        onLayout: (_) => bytes,
        name: PdfCreatorService.displayName(widget.file),
      );
    } catch (e) {
      _snack('Could not open print. ($e)');
    }
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      await _pdfService.sharePdf(
        widget.file,
        text: PdfCreatorService.displayName(widget.file),
      );
    } catch (e) {
      _snack('Could not share the PDF. ($e)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveToDevice() async {
    setState(() => _busy = true);
    try {
      final savedPath = await _pdfService.saveToDevice(widget.file);
      if (savedPath != null) {
        _snack('Saved to your device.', success: true);
      }
      // null => student cancelled the dialog; stay silent.
    } catch (e) {
      _snack('Could not save the PDF. ($e)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Returns to a fresh Tools hub, clearing the create/preview flow so the
  /// student can pick another tool.
  void _done() {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.tools, (route) => route.isFirst);
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
    final sizeText = PdfCreatorService.formatSize(widget.file.lengthSync());
    final pagesText = widget.pageCount != null
        ? '${widget.pageCount} page${widget.pageCount == 1 ? '' : 's'} • '
        : '';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          PdfCreatorService.displayName(widget.file),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Print',
            onPressed: _busy ? null : _print,
            icon: const Icon(Icons.print_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.justCreated) _buildSuccessBanner(colors),
          // Info line
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Icon(Icons.picture_as_pdf_rounded,
                    size: 16, color: colors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$pagesText$sizeText',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          // Preview — pages rendered on a soft gray desk with spacing, fit to
          // width. PdfPreview is pure Flutter, so the gray shows consistently
          // from the first export (the native PDFView left it white the first
          // time) and the pages fill the width.
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: PdfPreview(
                build: (format) => _pdfBytes,
                useActions: false,
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                scrollViewDecoration:
                    const BoxDecoration(color: Color(0xFFBCC2CA)),
                previewPageMargin: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                padding: EdgeInsets.zero,
                loadingWidget: const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
          _buildActionBar(colors),
        ],
      ),
    );
  }

  Widget _buildSuccessBanner(ThemeColors colors) {
    return Container(
      width: double.infinity,
      color: colors.success.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: colors.success, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.successMessage ??
                  'PDF created and saved. Find it anytime under "My PDFs".',
              style: TextStyle(
                fontSize: 12.5,
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(ThemeColors colors) {
    final shareIsPrimary = !widget.justCreated;
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _saveToDevice,
                  icon: const Icon(Icons.save_alt_rounded, size: 20),
                  label: const Text('Save to device'),
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
                child: shareIsPrimary
                    ? ElevatedButton.icon(
                        onPressed: _busy ? null : _share,
                        icon: const Icon(Icons.share_rounded, size: 20),
                        label: const Text('Share'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: _busy ? null : _share,
                        icon: const Icon(Icons.share_rounded, size: 20),
                        label: const Text('Share'),
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
            ],
          ),
          if (widget.justCreated) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _done,
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: const Text('Done'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
