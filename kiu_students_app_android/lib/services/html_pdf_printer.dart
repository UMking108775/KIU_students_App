import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Bridges to the native print framework to turn an HTML page into a real,
/// paginated PDF (text stays vector/selectable; the browser engine paginates
/// and shapes complex scripts). Android-only for now.
class HtmlPdfPrinter {
  static const MethodChannel _channel = MethodChannel('com.kiu.assignment/pdf');

  /// Writes [html] to a temp file, asks the native side to print it to a PDF,
  /// and returns that PDF file. Times out so a stuck WebView can't hang forever
  /// (the caller then falls back to the image exporter).
  Future<File> printToPdf(
    String html, {
    String name = 'assignment',
    required int widthMils,
    required int heightMils,
    required int marginMils,
  }) async {
    final dir = await getTemporaryDirectory();
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final htmlFile = File('${dir.path}/${safe}_$stamp.html');
    final outPath = '${dir.path}/${safe}_$stamp.pdf';

    await htmlFile.writeAsString(html);
    try {
      final result = await _channel.invokeMethod<String>('htmlToPdf', {
        'htmlPath': htmlFile.path,
        'outputPath': outPath,
        'widthMils': widthMils,
        'heightMils': heightMils,
        'marginMils': marginMils,
      }).timeout(const Duration(seconds: 40));

      final path = result ?? outPath;
      final file = File(path);
      if (!await file.exists()) {
        throw Exception('The PDF was not produced.');
      }
      return file;
    } finally {
      try {
        await htmlFile.delete();
      } catch (_) {
        // Best-effort cleanup.
      }
    }
  }
}
