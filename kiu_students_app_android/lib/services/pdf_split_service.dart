import 'dart:io';
import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'pdf_creator_service.dart';

/// Splits an existing PDF into several smaller PDFs, losslessly (pages are
/// copied, preserving text and quality).
class PdfSplitService {
  final PdfCreatorService _creator = PdfCreatorService();

  /// Number of pages in [bytes]. Throws if the PDF can't be read.
  int pageCount(Uint8List bytes) {
    final doc = sf.PdfDocument(inputBytes: bytes);
    final count = doc.pages.count;
    doc.dispose();
    return count;
  }

  /// Splits [sourceBytes] into consecutive chunks of [pagesPerPart] pages each,
  /// saving every chunk to the KIU PDFs library as `baseName - part N`.
  /// Returns the saved files in order.
  Future<List<File>> splitByPageChunks({
    required Uint8List sourceBytes,
    required int pagesPerPart,
    required String baseName,
  }) async {
    final source = sf.PdfDocument(inputBytes: sourceBytes);
    final total = source.pages.count;
    final per = pagesPerPart < 1 ? 1 : pagesPerPart;
    final files = <File>[];

    try {
      var part = 1;
      for (var start = 0; start < total; start += per) {
        final end = (start + per) < total ? (start + per) : total;

        final out = sf.PdfDocument();
        out.pageSettings.margins.all = 0;
        for (var i = start; i < end; i++) {
          final srcPage = source.pages[i];
          final size = srcPage.size;
          final template = srcPage.createTemplate();
          out.pageSettings.size = size;
          out.pages.add().graphics.drawPdfTemplate(template, Offset.zero, size);
        }

        final bytes = await out.save();
        out.dispose();
        files.add(
          await _creator.saveBytesToLibrary(bytes, '$baseName - part $part'),
        );
        part++;
      }
      return files;
    } finally {
      source.dispose();
    }
  }
}
