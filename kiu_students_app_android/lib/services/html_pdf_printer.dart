import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Bridges to the native renderer that turns an HTML page into a real,
/// paginated PDF. The native side tries the WebView print framework first
/// (selectable vector text, exact CSS pages) and falls back to a canvas
/// renderer if that hangs on a budget device. Android-only for now.
class HtmlPdfPrinter {
  static const MethodChannel _channel = MethodChannel('com.kiu.assignment/pdf');

  /// Writes [html] to a temp file, asks the native side to render it to a PDF
  /// sized to [pageWidthPx] × [pageHeightPx] (CSS px — the editor's sheet size),
  /// and returns that PDF file. Times out so a stuck WebView can't hang forever.
  Future<File> printToPdf(
    String html, {
    String name = 'assignment',
    required int pageWidthPx,
    required int pageHeightPx,
    int marginPx = 36,
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
        'pageWidthPx': pageWidthPx,
        'pageHeightPx': pageHeightPx,
        'marginPx': marginPx,
      }).timeout(const Duration(seconds: 90));

      final path = result ?? outPath;
      final file = File(path);
      if (!await file.exists()) {
        throw Exception('The PDF was not produced.');
      }
      return file;
    } on TimeoutException {
      throw Exception(
        'PDF export timed out. The device may be low on memory. '
        'Please close other apps and try again.',
      );
    } finally {
      try {
        await htmlFile.delete();
      } catch (_) {
        // Best-effort cleanup.
      }
    }
  }

  /// Reads the system clipboard (Android's ClipboardManager) and returns both
  /// its `html` (when the source provided rich HTML, e.g. Word / Docs / the web)
  /// and its `text` (the plain text, e.g. the Markdown an AI app copies). Either
  /// value may be null/empty. Returns null only if the channel call fails.
  Future<({String? html, String? text})?> readClipboard() async {
    try {
      final result = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('readClipboard')
          .timeout(const Duration(seconds: 2));
      if (result == null) return (html: null, text: null);
      return (
        html: result['html'] as String?,
        text: result['text'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
