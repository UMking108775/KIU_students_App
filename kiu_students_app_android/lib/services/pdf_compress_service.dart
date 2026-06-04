import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'pdf_creator_service.dart';

/// How aggressively to shrink the PDF. Higher compression = smaller file but
/// lower page resolution.
enum CompressLevel { high, balanced, small }

class _CompressSettings {
  /// Render resolution in dots-per-inch.
  final double dpi;

  /// JPEG quality (0–100) for each page image.
  final int quality;

  const _CompressSettings(this.dpi, this.quality);
}

/// Arguments for the JPEG-transcoding isolate.
class _TranscodeArgs {
  final Uint8List png;
  final int quality;
  const _TranscodeArgs(this.png, this.quality);
}

/// Decodes a (correctly-coloured) PNG and re-encodes it as a quality-reduced
/// JPEG in a background isolate. Decoding the PNG — rather than hand-reading the
/// raw raster buffer — avoids any channel-order/alpha mistakes that would tint
/// the page.
Uint8List _transcodePngToJpg(_TranscodeArgs a) {
  final decoded = img.decodeImage(a.png);
  if (decoded == null) return a.png;
  return img.encodeJpg(decoded, quality: a.quality);
}

/// Compresses a PDF by rasterising each page and re-encoding it as a quality-
/// reduced JPEG, then rebuilding the document. This is highly effective for
/// scanned / image-based PDFs (the common case for student assignments).
class PdfCompressService {
  final PdfCreatorService _creator = PdfCreatorService();

  _CompressSettings _settingsFor(CompressLevel level) {
    switch (level) {
      case CompressLevel.high:
        return const _CompressSettings(150, 80);
      case CompressLevel.balanced:
        return const _CompressSettings(120, 65);
      case CompressLevel.small:
        return const _CompressSettings(90, 50);
    }
  }

  /// Rasterises [sourceBytes] at the chosen [level], rebuilds a compressed PDF,
  /// and saves it to the KIU PDFs library. Returns the saved file.
  Future<File> compress({
    required Uint8List sourceBytes,
    required CompressLevel level,
    required String fileName,
  }) async {
    final settings = _settingsFor(level);
    final doc = pw.Document();

    await for (final PdfRaster page in Printing.raster(
      sourceBytes,
      dpi: settings.dpi,
    )) {
      // Render to PNG via the engine (correct colours), then transcode to a
      // smaller JPEG off the UI thread.
      final png = await page.toPng();
      final jpg = await compute(
        _transcodePngToJpg,
        _TranscodeArgs(png, settings.quality),
      );

      final image = pw.MemoryImage(jpg);
      // Convert pixel dimensions back to PDF points (72pt = 1 inch) so the page
      // keeps its original physical size.
      final widthPt = page.width / settings.dpi * 72.0;
      final heightPt = page.height / settings.dpi * 72.0;

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(widthPt, heightPt),
          margin: pw.EdgeInsets.zero,
          build: (context) => pw.Image(image, fit: pw.BoxFit.fill),
        ),
      );
    }

    final List<int> bytes = await doc.save();
    // Never hand back a file BIGGER than the original. Re-rasterising a text /
    // vector PDF can produce a larger file (text compresses better as text than
    // as a page image), so keep whichever is smaller — "compress" must never
    // inflate the document.
    final List<int> out =
        bytes.length < sourceBytes.length ? bytes : sourceBytes;
    return _creator.saveBytesToLibrary(out, fileName);
  }
}
