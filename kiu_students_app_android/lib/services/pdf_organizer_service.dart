import 'dart:io';
import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'pdf_creator_service.dart';

/// Loads an existing PDF so its pages can be reordered or deleted, then writes
/// the result back into the app's "KIU PDFs" library.
///
/// * Thumbnails are rendered with the `printing` package (native rasteriser).
/// * Page reordering/deletion is done losslessly with Syncfusion's pure-Dart
///   PDF library (text and quality are preserved – pages are copied, not
///   re-rasterised).
class PdfOrganizerService {
  final PdfCreatorService _creator = PdfCreatorService();

  /// Renders every page of [bytes] to a small PNG thumbnail, in page order.
  /// Throws if the PDF cannot be read (e.g. password-protected/corrupt).
  Future<List<Uint8List>> renderThumbnails(
    Uint8List bytes, {
    double dpi = 45,
  }) async {
    final thumbs = <Uint8List>[];
    await for (final PdfRaster page in Printing.raster(bytes, dpi: dpi)) {
      thumbs.add(await page.toPng());
    }
    return thumbs;
  }

  /// Builds a new PDF containing only [orderedZeroBasedIndices] (in that exact
  /// order) copied from [sourceBytes], then saves it to the KIU PDFs library.
  /// Returns the saved file.
  Future<File> buildReorganizedPdf({
    required Uint8List sourceBytes,
    required List<int> orderedZeroBasedIndices,
    required String fileName,
  }) async {
    final sf.PdfDocument source = sf.PdfDocument(inputBytes: sourceBytes);
    final sf.PdfDocument output = sf.PdfDocument();
    output.pageSettings.margins.all = 0;

    try {
      for (final index in orderedZeroBasedIndices) {
        if (index < 0 || index >= source.pages.count) continue;
        final srcPage = source.pages[index];
        final size = srcPage.size;
        final template = srcPage.createTemplate();

        // Match the output page to the source page size, then stamp the
        // original page content onto it (lossless copy).
        output.pageSettings.size = size;
        final newPage = output.pages.add();
        newPage.graphics.drawPdfTemplate(template, Offset.zero, size);
      }

      final List<int> bytes = await output.save();
      return _creator.saveBytesToLibrary(bytes, fileName);
    } finally {
      source.dispose();
      output.dispose();
    }
  }
}
