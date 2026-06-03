import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

import 'assignment_fonts.dart';
import 'html_pdf_printer.dart';
import 'pdf_creator_service.dart';

/// Converts an assignment ([Document] delta) into a self-contained HTML page for
/// the browser-based PDF export.
///
/// Why HTML? A real browser engine (the WebView) shapes Urdu / Pashto / Arabic
/// Nastaliq correctly AND paginates with CSS paged-media — giving real, vector,
/// selectable text pages instead of sliced screenshots. The fonts are embedded
/// as base64 `@font-face` so the page renders identically offline.
class AssignmentHtmlService {
  final HtmlPdfPrinter _printer = HtmlPdfPrinter();
  final PdfCreatorService _creator = PdfCreatorService();

  /// Builds the HTML, prints it to a real paginated PDF via the browser engine,
  /// and saves it into the KIU PDFs library. Returns the saved file.
  ///
  /// [contentWidthPx] is the on-screen layout width (the editor/preview width in
  /// logical px). The PDF page is sized to it so the text wraps and reads at the
  /// SAME size as the preview — not stretched to a wide A4 column.
  Future<File> exportPdf({
    required List<dynamic> delta,
    required String fileName,
    required double contentWidthPx,
    bool border = false,
    double marginMm = 12,
    int linesPerPage = 12,
    double lineHeight = 2.0,
  }) async {
    final html = await buildHtml(delta: delta, border: border, lineHeight: lineHeight);

    // Page geometry in mils (1/1000 inch — the unit the print framework uses).
    const milsPerInch = 1000.0;
    const cssPxPerInch = 96.0; // CSS reference DPI used by the print engine
    const mmPerInch = 25.4;
    final marginMils = (marginMm / mmPerInch * milsPerInch).round();
    final contentWidthMils = (contentWidthPx / cssPxPerInch * milsPerInch).round();
    final widthMils = contentWidthMils + 2 * marginMils;

    // Page HEIGHT = exactly [linesPerPage] lines tall, so the PDF breaks after a
    // fixed number of lines whatever the font size. One line box = fontSize ×
    // line-height; we use the document's dominant font size (since line-height
    // is fixed). +1px slack guards sub-pixel rounding; +16px if a border (its
    // 8px top/bottom padding repeats on every page).
    final baseSize = _dominantFontSize(delta);
    final lineBoxPx = baseSize * lineHeight;
    final borderPadPx = border ? 16.0 : 0.0;
    final contentHeightPx = linesPerPage * lineBoxPx + borderPadPx + 1.0;
    final heightMils =
        (contentHeightPx / cssPxPerInch * milsPerInch).round() + 2 * marginMils;

    final temp = await _printer.printToPdf(
      html,
      name: fileName,
      widthMils: widthMils,
      heightMils: heightMils,
      marginMils: marginMils,
    );
    final bytes = await temp.readAsBytes();
    try {
      await temp.delete();
    } catch (_) {
      // Best-effort cleanup of the temp file.
    }
    return _creator.saveBytesToLibrary(bytes, fileName);
  }

  /// The font size (px) most of the document's text uses, so "12 lines per page"
  /// is measured at the size the student is actually writing in. Unsized text
  /// counts as 16 (the editor base); defaults to 16 for an empty document.
  double _dominantFontSize(List<dynamic> delta) {
    final tally = <double, int>{};
    for (final op in delta) {
      if (op is! Map) continue;
      final insert = op['insert'];
      if (insert is! String) continue;
      final len = insert.replaceAll('\n', '').length;
      if (len == 0) continue;
      var size = 16.0;
      final attrs = op['attributes'];
      if (attrs is Map && attrs['size'] != null) {
        final s = attrs['size'].toString();
        final n = double.tryParse(s);
        if (n != null) {
          size = n;
        } else if (s == 'small') {
          size = 12;
        } else if (s == 'large') {
          size = 24;
        } else if (s == 'huge') {
          size = 32;
        }
      }
      tally[size] = (tally[size] ?? 0) + len;
    }
    if (tally.isEmpty) return 16;
    return tally.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// Family name → bundled asset, so we embed only the fonts actually used.
  static const Map<String, String> _fontAssets = {
    AssignmentFonts.notoNastaliqUrduFamily:
        'assets/fonts/NotoNastaliqUrdu-Regular.ttf',
    AssignmentFonts.bahijKarimFamily: 'assets/fonts/BahijKarim-Regular.ttf',
    AssignmentFonts.bahijNassimFamily: 'assets/fonts/BahijNassim-Regular.ttf',
  };

  /// Builds a complete HTML document. [delta] is `document.toDelta().toJson()`.
  ///
  /// Page size & margins are NOT set here — the native print side controls them
  /// (Android honours the print attributes, not CSS @page size), so the PDF can
  /// use the same narrow, phone-width layout as the on-screen preview instead of
  /// a wide A4 layout.
  Future<String> buildHtml({
    required List<dynamic> delta,
    double fontSizePx = 16, // matches the editor's base size
    double lineHeight = 2.0,
    bool border = false,
  }) async {
    final ops = delta.cast<Map<String, dynamic>>();
    final body = _deltaToHtml(ops);
    final fontsCss = await _fontFaceCss(ops);
    final base = AssignmentFonts.fallbackFamily;

    // When a border is requested, draw the frame on the page BODY itself with
    // `box-decoration-break: clone` so it repeats on every page. (Putting it on
    // an inner wrapper div could fragment oddly and strand a heading on page 1.)
    final borderCss = border
        ? '''
body {
  border: 1px solid #444;
  padding: 8px;
  -webkit-box-decoration-break: clone;
  box-decoration-break: clone;
}'''
        : '';

    return '''
<!DOCTYPE html>
<html lang="ur" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
$fontsCss
@page { size: auto; margin: 0; }
html, body { margin: 0; padding: 0; }
body {
  direction: rtl;
  font-family: '$base', serif;
  font-size: ${fontSizePx}px;
  line-height: $lineHeight;
  color: #000;
  -webkit-text-size-adjust: 100%;
  text-align: right;
}
p { margin: 0; }
h1, h2, h3, h4, h5, h6 { margin: 0.3em 0; line-height: 1.4; }
h1 { font-size: 1.8em; } h2 { font-size: 1.5em; } h3 { font-size: 1.3em; }
h4 { font-size: 1.15em; } h5 { font-size: 1em; } h6 { font-size: 0.9em; }
ul, ol { margin: 0; padding-right: 1.6em; padding-left: 0; }
blockquote {
  border-right: 4px solid #ccc; border-left: 0;
  margin: 0; padding-right: 12px;
}
img { max-width: 100%; }
/* Smart page breaks: nothing is forced onto its own page; everything may break
   between lines (the browser never splits a line mid-way). A heading is kept
   with the text that follows it, so it never lands alone on a page. */
* {
  break-before: auto; page-break-before: auto;
  break-inside: auto; page-break-inside: auto;
  orphans: 1; widows: 1;
}
h1, h2, h3, h4, h5, h6 {
  break-after: avoid; page-break-after: avoid;
}
.ql-align-center  { text-align: center; }
.ql-align-right   { text-align: right; }
.ql-align-left    { text-align: left; }
.ql-align-justify { text-align: justify; }
.ql-direction-rtl { direction: rtl; }
$borderCss
</style>
</head>
<body>$body</body>
</html>''';
  }

  String _deltaToHtml(List<Map<String, dynamic>> ops) {
    final converter = QuillDeltaToHtmlConverter(
      ops,
      ConverterOptions(
        converterOptions: OpConverterOptions(
          // Emit inline styles (not ql-font-* classes): our font values are real
          // family names with spaces, which can't be valid CSS class suffixes.
          inlineStylesFlag: true,
          inlineStyles: InlineStyles({
            'font': InlineStyleType(fn: (value, _) => "font-family: '$value'"),
            // flutter_quill stores numeric sizes (e.g. "20"); the default only
            // knows small/large/huge, so handle numbers too.
            'size': InlineStyleType(fn: (value, _) {
              switch (value) {
                case 'small':
                  return 'font-size: 0.75em';
                case 'large':
                  return 'font-size: 1.5em';
                case 'huge':
                  return 'font-size: 2.5em';
                default:
                  return double.tryParse(value) != null
                      ? 'font-size: ${value}px'
                      : null;
              }
            }),
          }),
        ),
      ),
    );
    return converter.convert();
  }

  /// Embeds (only) the fonts the document actually uses, base64-encoded, plus
  /// the base family — so the WebView renders correctly with no network.
  Future<String> _fontFaceCss(List<Map<String, dynamic>> ops) async {
    final used = <String>{AssignmentFonts.fallbackFamily};
    for (final op in ops) {
      final attrs = op['attributes'];
      if (attrs is Map && attrs['font'] is String) {
        used.add(attrs['font'] as String);
      }
    }

    final buf = StringBuffer();
    for (final family in used) {
      final path = _fontAssets[family];
      if (path == null) continue;
      final bytes = await rootBundle.load(path);
      final b64 = base64Encode(bytes.buffer.asUint8List());
      buf.writeln("@font-face { font-family: '$family'; "
          "src: url(data:font/truetype;base64,$b64) format('truetype'); "
          "font-weight: normal; font-style: normal; font-display: swap; }");
    }
    return buf.toString();
  }
}
