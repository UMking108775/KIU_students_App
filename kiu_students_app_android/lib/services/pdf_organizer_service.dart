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

  /// Builds a new PDF from [orderedZeroBasedIndices] (in that exact order, so a
  /// repeated index DUPLICATES that page) copied from [sourceBytes], applying an
  /// optional per-output-page clockwise rotation ([rotationsQuarterTurns], 0..3,
  /// parallel to the indices), then saves it to the KIU PDFs library.
  Future<File> buildReorganizedPdf({
    required Uint8List sourceBytes,
    required List<int> orderedZeroBasedIndices,
    required String fileName,
    List<int>? rotationsQuarterTurns,
  }) async {
    // Pass 1 — reorder / delete / duplicate by stamping page templates into a
    // fresh document (lossless: text & quality preserved).
    final sf.PdfDocument source = sf.PdfDocument(inputBytes: sourceBytes);
    final sf.PdfDocument output = sf.PdfDocument();
    output.pageSettings.margins.all = 0;
    List<int> bytes;
    try {
      for (final index in orderedZeroBasedIndices) {
        if (index < 0 || index >= source.pages.count) continue;
        final srcPage = source.pages[index];
        final size = srcPage.size;
        final template = srcPage.createTemplate();
        output.pageSettings.size = size;
        output.pages.add().graphics.drawPdfTemplate(template, Offset.zero, size);
      }
      bytes = await output.save();
    } finally {
      source.dispose();
      output.dispose();
    }

    // Pass 2 — apply rotations. syncfusion's `PdfPage.rotation` setter only
    // takes effect on a LOADED page, so we reload the just-built document and
    // set the /Rotate flag there (viewers display the page turned; the content
    // stays untouched, so it remains lossless and selectable).
    final hasRotation = rotationsQuarterTurns != null &&
        rotationsQuarterTurns.any((t) => t % 4 != 0);
    if (hasRotation) {
      final sf.PdfDocument doc = sf.PdfDocument(
        inputBytes: Uint8List.fromList(bytes),
      );
      try {
        final count = doc.pages.count;
        for (var k = 0; k < count && k < rotationsQuarterTurns.length; k++) {
          final turns = rotationsQuarterTurns[k] % 4;
          if (turns == 1) {
            doc.pages[k].rotation = sf.PdfPageRotateAngle.rotateAngle90;
          } else if (turns == 2) {
            doc.pages[k].rotation = sf.PdfPageRotateAngle.rotateAngle180;
          } else if (turns == 3) {
            doc.pages[k].rotation = sf.PdfPageRotateAngle.rotateAngle270;
          }
        }
        bytes = await doc.save();
      } finally {
        doc.dispose();
      }
    }

    return _creator.saveBytesToLibrary(bytes, fileName);
  }

  /// Renders ONE page of [bytes] (0-based [zeroBasedIndex]) to a crisp PNG for a
  /// full-size preview. Higher dpi than the list thumbnails.
  Future<Uint8List?> renderPage(
    Uint8List bytes,
    int zeroBasedIndex, {
    double dpi = 150,
  }) async {
    await for (final PdfRaster page
        in Printing.raster(bytes, pages: [zeroBasedIndex], dpi: dpi)) {
      return page.toPng();
    }
    return null;
  }
}
