import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

import 'assignment_fonts.dart';
import 'assignment_geometry.dart';
import 'html_pdf_printer.dart';
import 'pdf_creator_service.dart';

/// Builds the self-contained HTML for the WebView assignment editor and for the
/// PDF export.
///
/// The editor and the PDF are built from the SAME [AssignmentGeometry] and the
/// SAME page fragments (the editor hands its already-paginated pages to the
/// exporter), so the PDF is a byte-faithful copy of what the student sees —
/// same column width, same margins, same font size, same page breaks. The fonts
/// are embedded as base64 `@font-face` so Urdu / Pashto / Arabic Nastaliq shapes
/// correctly and identically, fully offline.
class AssignmentHtmlService {
  final HtmlPdfPrinter _printer = HtmlPdfPrinter();
  final PdfCreatorService _creator = PdfCreatorService();

  /// Exposes the printer so callers can access clipboard utilities.
  HtmlPdfPrinter get printer => _printer;

  /// Family name → bundled asset, so we embed only the fonts actually used.
  static const Map<String, String> _fontAssets = {
    AssignmentFonts.notoNastaliqUrduFamily:
        'assets/fonts/NotoNastaliqUrdu-Regular.ttf',
    AssignmentFonts.bahijKarimFamily: 'assets/fonts/BahijKarim-Regular.ttf',
    AssignmentFonts.bahijNassimFamily: 'assets/fonts/BahijNassim-Regular.ttf',
  };

  /// The font families offered in the picker.
  static List<String> get fontFamilies => _fontAssets.keys.toList();

  /// Font sizes (px) offered in the size picker.
  static const List<int> sizes = [10, 12, 14, 16, 18, 20, 24, 28, 32, 36, 48];

  /// Text-colour swatches.
  static const List<String> palette = [
    '#000000', '#374151', '#6b7280', '#9ca3af',
    '#e11d48', '#dc2626', '#ea580c', '#d97706',
    '#ca8a04', '#16a34a', '#059669', '#0891b2',
    '#0284c7', '#1d4ed8', '#4f46e5', '#7c3aed',
    '#9333ea', '#db2777', '#be123c', '#78350f',
  ];

  /// Highlight (text background) swatches; the first clears the highlight.
  static const List<String> highlights = [
    'transparent', '#fff59d', '#fde68a', '#a7f3d0',
    '#bfdbfe', '#ddd6fe', '#fbcfe8', '#fecaca',
  ];

  /// Returns the base64 of a bundled font (for lazy injection at runtime), or
  /// null if the family isn't one we bundle.
  Future<String?> fontBase64(String family) async {
    final path = _fontAssets[family];
    if (path == null) return null;
    final bytes = await rootBundle.load(path);
    return base64Encode(bytes.buffer.asUint8List());
  }

  /// Base64 `@font-face` rules for the given [families] (skips unknown ones).
  Future<String> _fontFaceCssForFamilies(Iterable<String> families) async {
    final buf = StringBuffer();
    for (final family in families.toSet()) {
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

  /// Which bundled families appear in [html] (so the export embeds only those).
  Set<String> _familiesIn(String html) {
    final out = <String>{AssignmentFonts.fallbackFamily};
    for (final f in _fontAssets.keys) {
      if (html.contains(f)) out.add(f);
    }
    return out;
  }

  // ---- Toolbar SVG icons (currentColor so they flip white when active). ----
  static String _alignSvg(String kind) {
    String line(num x1, num x2, num y) =>
        '<line x1="$x1" y1="$y" x2="$x2" y2="$y"/>';
    String l1, l2, l3;
    switch (kind) {
      case 'left':
        l1 = line(3, 15, 5); l2 = line(3, 11, 9); l3 = line(3, 13, 13); break;
      case 'center':
        l1 = line(3, 15, 5); l2 = line(5, 13, 9); l3 = line(4, 14, 13); break;
      case 'full':
        l1 = line(3, 15, 5); l2 = line(3, 15, 9); l3 = line(3, 15, 13); break;
      case 'right':
      default:
        l1 = line(3, 15, 5); l2 = line(7, 15, 9); l3 = line(5, 15, 13); break;
    }
    return '<svg viewBox="0 0 18 18" fill="none" stroke="currentColor" '
        'stroke-width="1.7" stroke-linecap="round">$l1$l2$l3</svg>';
  }

  static String _listSvg(bool ordered) {
    String row(num y) => '<line x1="3" y1="$y" x2="11" y2="$y"/>';
    final lines = '${row(5)}${row(9)}${row(13)}';
    final markers = ordered
        ? '<text x="13.5" y="7" font-size="6" fill="currentColor" stroke="none">1</text>'
            '<text x="13.5" y="11" font-size="6" fill="currentColor" stroke="none">2</text>'
            '<text x="13.5" y="15" font-size="6" fill="currentColor" stroke="none">3</text>'
        : '<circle cx="15" cy="5" r="1.1" fill="currentColor" stroke="none"/>'
            '<circle cx="15" cy="9" r="1.1" fill="currentColor" stroke="none"/>'
            '<circle cx="15" cy="13" r="1.1" fill="currentColor" stroke="none"/>';
    return '<svg viewBox="0 0 18 18" fill="none" stroke="currentColor" '
        'stroke-width="1.7" stroke-linecap="round">$lines$markers</svg>';
  }

  /// Clean line icons (stroke = currentColor so they turn white when a button is
  /// active). Used instead of emoji where a proper glyph reads better.
  static String _icon(String name) {
    const open = '<svg viewBox="0 0 18 18" fill="none" stroke="currentColor" '
        'stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">';
    String body;
    switch (name) {
      case 'undo':
        body = '<path d="M6.5 6 3.5 9l3 3"/><path d="M3.5 9H11a3.4 3.4 0 0 1 0 6.8H8.5"/>';
        break;
      case 'redo':
        body = '<path d="M11.5 6 14.5 9l-3 3"/><path d="M14.5 9H7a3.4 3.4 0 0 0 0 6.8h2.5"/>';
        break;
      case 'paste':
        body = '<rect x="3.5" y="4" width="11" height="11.5" rx="1.5"/>'
            '<path d="M6.5 4V3.3A1.3 1.3 0 0 1 7.8 2h2.4a1.3 1.3 0 0 1 1.3 1.3V4"/>'
            '<line x1="6" y1="8.2" x2="12" y2="8.2"/><line x1="6" y1="11.2" x2="11" y2="11.2"/>';
        break;
      case 'link':
        body = '<rect x="2.4" y="6.4" width="7.2" height="5.2" rx="2.6"/>'
            '<rect x="8.4" y="6.4" width="7.2" height="5.2" rx="2.6"/>';
        break;
      case 'find':
        body = '<circle cx="8" cy="8" r="4.2"/><line x1="11.3" y1="11.3" x2="15" y2="15"/>';
        break;
      case 'highlight':
        body = '<path d="M3.5 15.2h11"/><path d="M6 12l5-5 2.4 2.4-5 5H6z"/>'
            '<path d="M10.6 6.4 12.6 4.4a1.4 1.4 0 0 1 2 2l-2 2"/>';
        break;
      case 'indentIn':
        body = '<line x1="3" y1="4.5" x2="15" y2="4.5"/><line x1="8" y1="9" x2="15" y2="9"/>'
            '<line x1="3" y1="13.5" x2="15" y2="13.5"/>'
            '<path d="M3 7 5.6 9 3 11z" fill="currentColor" stroke="none"/>';
        break;
      case 'indentOut':
        body = '<line x1="3" y1="4.5" x2="15" y2="4.5"/><line x1="8" y1="9" x2="15" y2="9"/>'
            '<line x1="3" y1="13.5" x2="15" y2="13.5"/>'
            '<path d="M5.6 7 3 9 5.6 11z" fill="currentColor" stroke="none"/>';
        break;
      case 'spacing':
        body = '<line x1="8" y1="4.5" x2="15" y2="4.5"/><line x1="8" y1="9" x2="15" y2="9"/>'
            '<line x1="8" y1="13.5" x2="15" y2="13.5"/><path d="M4 3.8V14.2"/>'
            '<path d="M2.4 5.4 4 3.8l1.6 1.6"/><path d="M2.4 12.6 4 14.2l1.6-1.6"/>';
        break;
      default:
        body = '';
    }
    return '$open$body</svg>';
  }

  static String _tableSvg() {
    return '<svg viewBox="0 0 18 18" fill="none" stroke="currentColor" '
        'stroke-width="1.5">'
        '<rect x="2.5" y="2.5" width="13" height="13" rx="1.5"/>'
        '<line x1="2.5" y1="7" x2="15.5" y2="7"/>'
        '<line x1="2.5" y1="11.5" x2="15.5" y2="11.5"/>'
        '<line x1="7" y1="2.5" x2="7" y2="15.5"/>'
        '<line x1="11.5" y1="2.5" x2="11.5" y2="15.5"/>'
        '</svg>';
  }

  /// Shared block-level CSS used by BOTH the editor `#page` and the export
  /// `.page`, prefixed with [scope] (e.g. `#page` or `.page`). Keeping it in one
  /// place guarantees headings/lists/tables look the same on screen and in PDF.
  static String _blockCss(String scope) => '''
$scope p { margin: 0; }
/* Headings use PADDING (not margin) for spacing so offsetHeight measures their
   FULL height — margins would be invisible to the paginator and cause drift. */
$scope h1,$scope h2,$scope h3,$scope h4,$scope h5,$scope h6 { line-height: 1.4; margin: 0; padding: .3em 0 .15em; font-weight: 700; }
$scope h1 { font-size: 1.4em; } $scope h2 { font-size: 1.2em; } $scope h3 { font-size: 1.08em; }
$scope h4 { font-size: 1em; } $scope h5 { font-size: 0.95em; } $scope h6 { font-size: 0.9em; }
$scope ul, $scope ol { margin: 0; padding-right: 1.6em; padding-left: 0; }
$scope li { margin: 0; }
$scope blockquote { border-right: 4px solid #ccc; border-left: 0; margin: 0; padding-right: 12px; color: #374151; }
$scope table { border-collapse: collapse; width: 100%; table-layout: fixed; }
$scope td, $scope th { border: 1px solid #888; padding: 4px 8px; vertical-align: top; background: #fff;
  word-wrap: break-word; overflow-wrap: break-word; word-break: break-word; }
$scope a { color: #1d4ed8; text-decoration: underline; }
$scope img { max-width: 100%; }
$scope .ql-align-center { text-align: center; }
$scope .ql-align-left { text-align: left; }
$scope .ql-align-justify { text-align: justify; }''';

  /// Builds the editor HTML for the given [geom]. [initialBody] is the saved
  /// draft's inner HTML; [embedFamilies] are the font families to embed up front
  /// (the default plus any used in the draft) — others are injected on demand to
  /// keep the initial load light.
  Future<String> buildEditorHtml({
    required AssignmentGeometry geom,
    String initialBody = '',
    Set<String>? embedFamilies,
  }) async {
    final families = <String>{AssignmentFonts.fallbackFamily, ...?embedFamilies};
    final fontsCss = await _fontFaceCssForFamilies(families);
    final base = AssignmentFonts.fallbackFamily;
    final startBody = initialBody.trim().isEmpty ? '<p><br></p>' : initialBody;

    final geoJson = geom.toJsConfig();
    final fontsJson = jsonEncode(fontFamilies);
    final sizesJson = jsonEncode(sizes);
    final paletteJson = jsonEncode(palette);
    final hilitesJson = jsonEncode(highlights);
    final bodyJson = jsonEncode(startBody);

    final g = geom;
    return '''
<!DOCTYPE html>
<html lang="ur" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<style>
$fontsCss
:root {
  --pad: ${g.marginPx}px; --pageW: ${g.pageWidthPx}px; --contentW: ${g.contentWidthPx}px;
  --ph: ${g.contentHeightPx}px; --sheetH: ${g.sheetHeightPx}px;
  --step: ${g.sheetHeightPx + AssignmentGeometry.deskGap}px;
  --font: ${g.fontSizePx}px; --lh: ${g.lineHeight};
}
* { -webkit-tap-highlight-color: transparent; box-sizing: border-box;
    -webkit-user-select: none; user-select: none; }
html, body { margin: 0; padding: 0; background: #e5e7eb; }
/* Two-row toolbar: row 1 = most-used tools, row 2 = secondary (both scroll
   horizontally if they overflow). */
#toolbar { position: sticky; top: 0; z-index: 10; background: #dfe3e8; border-bottom: 1px solid #c2c8d0; }
.trow {
  display: flex; flex-wrap: nowrap; overflow-x: auto; gap: 5px; align-items: center;
  padding: 6px 8px; direction: ltr; -webkit-overflow-scrolling: touch;
}
.trow.r2 { padding-top: 5px; padding-bottom: 6px; border-top: 1px solid #cdd3db; }
.trow::-webkit-scrollbar { height: 0; }
.btn {
  flex: 0 0 auto; height: 38px; min-width: 40px; padding: 0 9px;
  display: inline-flex; align-items: center; justify-content: center;
  border: 1px solid #c7ccd3; border-radius: 6px; background: #fff; color: #1f2937;
  font-size: 16px; font-family: serif; line-height: 1; white-space: nowrap;
}
.btn svg { width: 19px; height: 19px; display: block; }
.btn.active { background: #2563eb; border-color: #2563eb; color: #fff; }
.btn:active { transform: scale(.95); }
.btn.txt { font: 600 13px sans-serif; }
.col { flex-direction: column; gap: 0; }
#cbar { display: block; width: 16px; height: 3px; background: #000; margin-top: 2px; border-radius: 2px; }
#hbar { display: block; width: 16px; height: 3px; background: #fff59d; margin-top: 2px; border-radius: 2px; border: 1px solid #e5e7eb; }
.sep { flex: 0 0 auto; width: 1px; height: 26px; background: #e5e7eb; margin: 0 3px; }
.dd { position: relative; flex: 0 0 auto; }
.menu { display: none; position: fixed; top: 0; left: 0; z-index: 30;
  background: #fff; border: 1px solid #c7ccd3; border-radius: 8px; padding: 6px;
  box-shadow: 0 10px 26px rgba(0,0,0,.20); max-height: 55vh; overflow: auto; min-width: 130px; }
.menu.open { display: block; }
.menu.grid3.open { display: grid; grid-template-columns: repeat(3,1fr); gap: 5px; min-width: 150px; }
.menu.grid4.open { display: grid; grid-template-columns: repeat(4,1fr); gap: 8px; min-width: 0; }
.opt { display: block; width: 100%; text-align: right; padding: 9px 12px; border: 0;
  background: #fff; border-radius: 5px; font: 14px sans-serif; white-space: nowrap; color: #111827; }
.opt.sz { text-align: center; border: 1px solid #e5e7eb; padding: 9px 4px; }
.opt:active { background: #eef2ff; }
.sw { width: 30px; height: 30px; border-radius: 5px; border: 1px solid rgba(0,0,0,.25); padding: 0; }
.sw.none { background: #fff !important; position: relative; }
.sw.none:after { content: ''; position: absolute; left: 3px; right: 3px; top: 13px; height: 2px; background: #dc2626; transform: rotate(-45deg); }
.bar { display: none; position: fixed; top: 0; left: 0; right: 0; z-index: 12; align-items: center;
  gap: 6px; background: #fff; border-bottom: 1px solid #d1d5db; padding: 8px; direction: ltr;
  flex-wrap: wrap; box-shadow: 0 3px 10px rgba(0,0,0,.12); }
.bar.open { display: flex; }
.bar input { flex: 1 1 120px; min-width: 0; height: 38px; border: 1px solid #c7ccd3;
  border-radius: 6px; padding: 0 10px; font: 15px sans-serif; color: #111827;
  -webkit-user-select: text; user-select: text; }
.tablemenu { min-width: 190px; }
.tglabel { text-align: center; font: 600 12px sans-serif; color: #374151; padding: 2px 0 7px; }
.tstep { display: flex; align-items: center; gap: 8px; padding: 4px 2px; }
.tlab { flex: 1 1 auto; font: 13px sans-serif; color: #374151; text-align: left; }
.tbtn { width: 32px; height: 32px; border: 1px solid #c7ccd3; border-radius: 6px; background: #fff; color: #111827; font: 600 18px sans-serif; line-height: 1; }
.tbtn:active { background: #eef2ff; }
.tstep b { min-width: 24px; text-align: center; font: 700 15px sans-serif; color: #111827; }
.tins { text-align: center; background: #2563eb; color: #fff; font-weight: 700; margin-top: 6px; }
.tins:active { background: #1d4ed8; }
.tsep2 { height: 1px; background: #e5e7eb; margin: 9px 0 4px; }
.tact { display: flex; flex-wrap: wrap; gap: 5px; margin-top: 7px; }
.tactb { width: auto; flex: 1 1 42%; text-align: center; border: 1px solid #e5e7eb; padding: 9px 4px; }
#scroller { padding: 16px 0 calc(45vh); }
#pagewrap { position: relative; margin: 0 auto; width: var(--pageW); }
/* CONTINUOUS white paper: it grows with the content, so text can NEVER overflow
   the page. Page breaks are drawn as guide lines (snapped to real text lines) —
   there are NO spacers, so editing/changing a font never makes content "jump" to
   another page, and paragraphs / lists / tables all flow across page boundaries
   instead of jumping whole. The authoritative pagination is the PDF (CSS paged
   media), which breaks at the same line positions. */
#page {
  position: relative; z-index: 1; background: #fff; margin: 0;
  width: var(--pageW); padding: var(--pad); min-height: var(--sheetH);
  box-shadow: 0 1px 10px rgba(0,0,0,.18); border-radius: 2px;
  direction: rtl; text-align: right;
  font-family: '$base', serif; font-size: var(--font); line-height: var(--lh);
  color: #000; outline: none; -webkit-user-select: text; user-select: text;
  word-wrap: break-word; overflow-wrap: break-word; word-break: break-word;
}
#guides { position: absolute; inset: 0; z-index: 2; pointer-events: none; }
#guides .pb { position: absolute; left: 0; right: 0; border-top: 2px dashed #b3bac4; }
#guides .pn { position: absolute; right: 6px; font: 600 10px sans-serif; color: #8b93a1;
  background: rgba(255,255,255,.96); padding: 1px 5px; border: 1px solid #e5e7eb; border-radius: 4px; }
${_blockCss('#page')}
#statusbar { position: fixed; bottom: 0; left: 0; right: 0; z-index: 8;
  background: rgba(255,255,255,.95); border-top: 1px solid #e5e7eb; direction: ltr;
  font: 12px sans-serif; color: #6b7280; padding: 5px 12px; display: flex; gap: 14px; }
</style>
</head>
<body>
<div id="toolbar">
  <div class="trow r1">
    <button class="btn" onmousedown="event.preventDefault()" onclick="cmd('undo')" title="Undo">${_icon('undo')}</button>
    <button class="btn" onmousedown="event.preventDefault()" onclick="cmd('redo')" title="Redo">${_icon('redo')}</button>
    <span class="sep"></span>
    <button class="btn" data-cmd="bold" onmousedown="event.preventDefault()" onclick="cmd('bold')"><b>B</b></button>
    <button class="btn" data-cmd="italic" onmousedown="event.preventDefault()" onclick="cmd('italic')"><i>I</i></button>
    <button class="btn" data-cmd="underline" onmousedown="event.preventDefault()" onclick="cmd('underline')"><u>U</u></button>
    <span class="sep"></span>
    <div class="dd">
      <button id="styleBtn" class="btn txt" onmousedown="event.preventDefault()" onclick="toggle('mStyle', this)" title="Paragraph style">Normal ▾</button>
      <div id="mStyle" class="menu">
        <button class="opt" onmousedown="event.preventDefault()" onclick="setBlock('p');closeMenus()">Normal</button>
        <button class="opt" onmousedown="event.preventDefault()" onclick="setBlock('h1');closeMenus()" style="font-size:1.4em;font-weight:700">Heading 1</button>
        <button class="opt" onmousedown="event.preventDefault()" onclick="setBlock('h2');closeMenus()" style="font-size:1.2em;font-weight:700">Heading 2</button>
        <button class="opt" onmousedown="event.preventDefault()" onclick="setBlock('h3');closeMenus()" style="font-size:1.08em;font-weight:700">Heading 3</button>
        <button class="opt" onmousedown="event.preventDefault()" onclick="setBlock('blockquote');closeMenus()" style="color:#6b7280">❝ Quote</button>
      </div>
    </div>
    <div class="dd">
      <button id="sizeBtn" class="btn txt" onmousedown="event.preventDefault()" onclick="toggle('mSize', this)" title="Font size">16 ▾</button>
      <div id="mSize" class="menu grid3"></div>
    </div>
    <span class="sep"></span>
    <button class="btn" data-cmd="justifyRight" onmousedown="event.preventDefault()" onclick="cmd('justifyRight')" title="Align right">${_alignSvg('right')}</button>
    <button class="btn" data-cmd="justifyCenter" onmousedown="event.preventDefault()" onclick="cmd('justifyCenter')" title="Centre">${_alignSvg('center')}</button>
    <button class="btn" data-cmd="justifyLeft" onmousedown="event.preventDefault()" onclick="cmd('justifyLeft')" title="Align left">${_alignSvg('left')}</button>
    <span class="sep"></span>
    <button class="btn" onmousedown="event.preventDefault()" onclick="cmd('insertUnorderedList')" title="Bulleted list">${_listSvg(false)}</button>
    <button class="btn" onmousedown="event.preventDefault()" onclick="cmd('insertOrderedList')" title="Numbered list">${_listSvg(true)}</button>
  </div>
  <div class="trow r2">
    <button class="btn" onmousedown="event.preventDefault()" onclick="pasteFromClipboard()" title="Paste (keeps formatting)">${_icon('paste')}</button>
    <span class="sep"></span>
    <div class="dd">
      <button id="fontBtn" class="btn txt" onmousedown="event.preventDefault()" onclick="toggle('mFont', this)" title="Font">خط ▾</button>
      <div id="mFont" class="menu"></div>
    </div>
    <div class="dd">
      <button class="btn col" onmousedown="event.preventDefault()" onclick="toggle('mColor', this)" title="Text colour">A<i id="cbar"></i></button>
      <div id="mColor" class="menu grid4"></div>
    </div>
    <div class="dd">
      <button class="btn col" onmousedown="event.preventDefault()" onclick="toggle('mHilite', this)" title="Highlight">${_icon('highlight')}<i id="hbar"></i></button>
      <div id="mHilite" class="menu grid4"></div>
    </div>
    <span class="sep"></span>
    <button class="btn" data-cmd="justifyFull" onmousedown="event.preventDefault()" onclick="cmd('justifyFull')" title="Justify">${_alignSvg('full')}</button>
    <button class="btn" onmousedown="event.preventDefault()" onclick="indent(1)" title="Increase indent">${_icon('indentIn')}</button>
    <button class="btn" onmousedown="event.preventDefault()" onclick="indent(-1)" title="Decrease indent">${_icon('indentOut')}</button>
    <div class="dd">
      <button class="btn" onmousedown="event.preventDefault()" onclick="toggle('mSpacing', this)" title="Line spacing">${_icon('spacing')} ▾</button>
      <div id="mSpacing" class="menu">
        <button class="opt" onmousedown="event.preventDefault()" onclick="setLineSpacing('1');closeMenus()">Single</button>
        <button class="opt" onmousedown="event.preventDefault()" onclick="setLineSpacing('1.5');closeMenus()">1.5</button>
        <button class="opt" onmousedown="event.preventDefault()" onclick="setLineSpacing('2');closeMenus()">Double</button>
        <button class="opt" onmousedown="event.preventDefault()" onclick="setLineSpacing('');closeMenus()">Default</button>
      </div>
    </div>
    <span class="sep"></span>
    <div class="dd">
      <button class="btn" onmousedown="event.preventDefault()" onclick="toggle('mTable', this)" title="Table">${_tableSvg()} ▾</button>
      <div id="mTable" class="menu tablemenu">
        <div class="tglabel">Insert a table</div>
        <div class="tstep"><span class="tlab">Rows</span>
          <button class="tbtn" onmousedown="event.preventDefault()" onclick="tAdj('R',-1)">−</button>
          <b id="tR">2</b>
          <button class="tbtn" onmousedown="event.preventDefault()" onclick="tAdj('R',1)">+</button></div>
        <div class="tstep"><span class="tlab">Columns</span>
          <button class="tbtn" onmousedown="event.preventDefault()" onclick="tAdj('C',-1)">−</button>
          <b id="tC">2</b>
          <button class="tbtn" onmousedown="event.preventDefault()" onclick="tAdj('C',1)">+</button></div>
        <button class="opt tins" onmousedown="event.preventDefault()" onclick="doInsertTable()">Insert</button>
        <div class="tsep2"></div>
        <div class="tglabel">Edit the table you're in</div>
        <div class="tact">
          <button class="opt tactb" onmousedown="event.preventDefault()" onclick="addRow();closeMenus()">+ Row</button>
          <button class="opt tactb" onmousedown="event.preventDefault()" onclick="addCol();closeMenus()">+ Column</button>
          <button class="opt tactb" onmousedown="event.preventDefault()" onclick="delRow();closeMenus()">− Row</button>
          <button class="opt tactb" onmousedown="event.preventDefault()" onclick="delCol();closeMenus()">− Column</button>
          <button class="opt tactb" onmousedown="event.preventDefault()" onclick="delTable();closeMenus()" style="flex:1 1 100%;color:#dc2626">Delete table</button>
        </div>
      </div>
    </div>
    <button class="btn" onmousedown="event.preventDefault()" onclick="openLink()" title="Insert link">${_icon('link')}</button>
    <button class="btn" onmousedown="event.preventDefault()" onclick="openFind()" title="Find &amp; replace">${_icon('find')}</button>
    <span class="sep"></span>
    <button class="btn" data-cmd="strikeThrough" onmousedown="event.preventDefault()" onclick="cmd('strikeThrough')" title="Strikethrough"><s>S</s></button>
    <button class="btn txt" data-cmd="subscript" onmousedown="event.preventDefault()" onclick="cmd('subscript')" title="Subscript">X₂</button>
    <button class="btn txt" data-cmd="superscript" onmousedown="event.preventDefault()" onclick="cmd('superscript')" title="Superscript">X²</button>
    <button class="btn" onmousedown="event.preventDefault()" onclick="clearFmt()" title="Clear formatting"><span style="text-decoration:underline">T</span>x</button>
    <span class="sep"></span>
    <button class="btn" onmousedown="event.preventDefault()" onclick="setDir('rtl')" title="Right-to-left">RTL</button>
    <button class="btn" onmousedown="event.preventDefault()" onclick="setDir('ltr')" title="Left-to-right">LTR</button>
  </div>
</div>
<div id="linkbar" class="bar">
  <input id="linkInput" type="url" inputmode="url" placeholder="https://example.com" />
  <button class="btn" onmousedown="event.preventDefault()" onclick="applyLink()" title="Apply">✓</button>
  <button class="btn" onmousedown="event.preventDefault()" onclick="cancelLink()" title="Cancel">✕</button>
</div>
<div id="findbar" class="bar">
  <input id="findInput" type="text" placeholder="Find" />
  <input id="replaceInput" type="text" placeholder="Replace with" />
  <button class="btn txt" onmousedown="event.preventDefault()" onclick="findNext()">Next</button>
  <button class="btn txt" onmousedown="event.preventDefault()" onclick="replaceOne()">Replace</button>
  <button class="btn txt" onmousedown="event.preventDefault()" onclick="replaceAll()">All</button>
  <button class="btn" onmousedown="event.preventDefault()" onclick="closeFind()">✕</button>
</div>
<div id="scroller">
<div id="pagewrap">
<div id="page" contenteditable="true" data-ph="یہاں اپنی اسائنمنٹ لکھیں…"></div>
<div id="guides"></div>
</div>
</div>
<div id="statusbar"><span id="wcWords">0 words</span><span id="wcPages">1 page</span></div>
<script>
window.GEO = $geoJson;
window.FONTS = $fontsJson;
window.SIZES = $sizesJson;
window.PALETTE = $paletteJson;
window.HILITES = $hilitesJson;
window.INITIAL_BODY = $bodyJson;
window.LOADED_FONTS = ${jsonEncode(families.toList())};
</script>
<script>
${_editorJs()}
${_mdConverterJs()}
</script>
</body>
</html>''';
  }

  /// Exports the editor's body HTML to a PDF via CSS paged-media, with the SAME
  /// geometry as the editor (column width, margins, font, line height), so the
  /// PDF breaks at the same line positions the student sees — paragraphs, lists
  /// and tables all split across pages. Vector text on capable devices; a raster
  /// fallback otherwise.
  Future<File> exportPdf({
    required String bodyHtml,
    required AssignmentGeometry geom,
    required String fileName,
  }) async {
    final fontsCss = await _fontFaceCssForFamilies(_familiesIn(bodyHtml));
    final base = AssignmentFonts.fallbackFamily;
    final g = geom;
    final body = bodyHtml.trim().isEmpty ? '<p><br></p>' : bodyHtml;

    final html = '''
<!DOCTYPE html>
<html lang="ur" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=${g.contentWidthPx.round()}, initial-scale=1">
<style>
$fontsCss
/* Page SIZE comes from the native print attributes (pageW × sheetH); the equal
   per-page MARGIN comes from @page margin (honoured by the print engine). */
@page { size: auto; margin: ${g.marginPx}px; }
html, body { margin: 0; padding: 0; background: #fff; }
body { width: ${g.contentWidthPx}px; margin: 0 auto; direction: rtl; text-align: right;
  font-family: '$base', serif; font-size: ${g.fontSizePx}px; line-height: ${g.lineHeight};
  color: #000; -webkit-text-size-adjust: 100%; }
${_blockCss('body')}
/* Break only between lines (never mid-line); keep a list item / table row / image
   whole; repeat a table's header row on each page it continues onto. */
body * { orphans: 1; widows: 1; }
p, blockquote { break-inside: auto; page-break-inside: auto; }
li, tr, img { break-inside: avoid; page-break-inside: avoid; }
table { break-inside: auto; page-break-inside: auto; }
thead { display: table-header-group; }
h1, h2, h3, h4, h5, h6 { break-after: avoid; page-break-after: avoid; }
</style>
</head>
<body>$body</body>
</html>''';

    final temp = await _printer.printToPdf(
      html,
      name: fileName,
      pageWidthPx: g.pageWidthPx.round(),
      pageHeightPx: g.sheetHeightPx.round(),
      marginPx: g.marginPx.round(),
    );
    final bytes = await temp.readAsBytes();
    try {
      await temp.delete();
    } catch (_) {}
    return _creator.saveBytesToLibrary(bytes, fileName);
  }

  /// The editor's JavaScript (commands, tables, pagination, paste, find). Kept
  /// in a raw string so regex backslashes (`\\s`, `\\d`, `\\*`) survive intact;
  /// it reads its geometry/config from the `window.*` globals set above.
  static String _editorJs() {
    return r'''
  var GEO = window.GEO;
  var page = document.getElementById('page');
  page.innerHTML = window.INITIAL_BODY || '<p><br></p>';
  var loadedFonts = {}; (window.LOADED_FONTS||[]).forEach(function(f){ loadedFonts[f]=1; });
  document.execCommand('styleWithCSS', true);
  try { document.execCommand('defaultParagraphSeparator', false, 'p'); } catch(e){}

  function applyGeoVars(){
    var r = document.documentElement.style;
    r.setProperty('--pad', GEO.pad+'px'); r.setProperty('--pageW', GEO.pageW+'px');
    r.setProperty('--contentW', GEO.contentW+'px'); r.setProperty('--ph', GEO.ph+'px');
    r.setProperty('--sheetH', GEO.sheetH+'px'); r.setProperty('--step', GEO.step+'px');
    r.setProperty('--font', GEO.font+'px'); r.setProperty('--lh', GEO.lh);
  }
  // Called from Dart when the page-setup dialog changes margins / size / lines.
  window.setGeo = function(json){ try { GEO = JSON.parse(json); applyGeoVars(); paginate(); notify(); } catch(e){} };
  // Called from Dart to add a font's @font-face after the user picks it.
  window.injectFont = function(family, b64){
    if (loadedFonts[family]) return; loadedFonts[family]=1;
    var st = document.createElement('style');
    st.textContent = "@font-face{font-family:'"+family+"';src:url(data:font/truetype;base64,"+b64+") format('truetype');font-weight:normal;font-style:normal;font-display:swap;}";
    document.head.appendChild(st); repaginate();
  };

  var saved = null;
  function snapshot(){ var s = window.getSelection(); if (s.rangeCount && page.contains(s.anchorNode)) { saved = s.getRangeAt(0).cloneRange(); } }
  function restore(){ if (!saved) return; var s = window.getSelection(); s.removeAllRanges(); s.addRange(saved); }
  function notify(){ try { Editor.postMessage('changed'); } catch(e){} }

  function placeCaretEnd(el){
    var r = document.createRange();
    if (el && el.nodeType === 1){ r.selectNodeContents(el); r.collapse(false); }
    else if (el){ r.setStartAfter(el); r.collapse(true); }
    else return;
    var s = window.getSelection(); s.removeAllRanges(); s.addRange(r);
    if (page.contains(r.startContainer)) saved = r.cloneRange();
  }
  // Insert an HTML string at the caret as REAL nodes (execCommand('insertHTML')
  // drops tables on Android WebView).
  function insertHtmlAtCaret(html){
    var temp = document.createElement('div'); temp.innerHTML = html;
    var nodes = []; while (temp.firstChild){ nodes.push(temp.firstChild); temp.removeChild(temp.firstChild); }
    if (!nodes.length) return;
    var sel = window.getSelection();
    if (!sel.rangeCount || !page.contains(sel.anchorNode)){
      for (var a=0;a<nodes.length;a++) page.appendChild(nodes[a]);
      placeCaretEnd(nodes[nodes.length-1]); return;
    }
    var range = sel.getRangeAt(0); range.deleteContents();
    var cell = blockOf(range.startContainer, true);
    if (cell && (cell.tagName==='TD'||cell.tagName==='TH')){
      // Inside a table cell: insert inline at the caret, don't break out.
      var frag0 = document.createDocumentFragment();
      for (var z=0;z<nodes.length;z++) frag0.appendChild(nodes[z]);
      range.insertNode(frag0); placeCaretEnd(nodes[nodes.length-1]); return;
    }
    var block = blockOf(range.startContainer);
    if (block === page){
      var frag = document.createDocumentFragment();
      for (var c=0;c<nodes.length;c++) frag.appendChild(nodes[c]);
      range.insertNode(frag);
    } else {
      var ref = block.nextSibling;
      for (var d=0;d<nodes.length;d++) page.insertBefore(nodes[d], ref);
      if (isEmptyBlock(block) && block.parentNode) block.parentNode.removeChild(block);
    }
    placeCaretEnd(nodes[nodes.length-1]);
  }

  function cmd(c){ page.focus(); restore(); document.execCommand(c, false, null); snapshot(); update(); notify(); repaginate(); }
  function setColor(v){ page.focus(); restore(); document.execCommand('foreColor', false, v); snapshot(); update(); notify(); repaginate(); }
  function setHighlight(v){
    page.focus(); restore();
    if (v === 'transparent'){
      // Remove highlight: hiliteColor can't clear, so strip background styles in range.
      var ok=false; try { ok = document.execCommand('hiliteColor', false, 'transparent'); } catch(e){}
      if (!ok) try { document.execCommand('backColor', false, 'transparent'); } catch(e2){}
    } else {
      var done=false; try { done = document.execCommand('hiliteColor', false, v); } catch(e){}
      if (!done) try { document.execCommand('backColor', false, v); } catch(e3){}
    }
    snapshot(); update(); notify(); repaginate();
  }
  function setFont(f){
    page.focus(); restore();
    document.execCommand('fontName', false, f);
    try { Fonts.postMessage(f); } catch(e){}  // ask Dart to embed it if needed
    snapshot(); update(); notify(); repaginate();
  }
  // Font size: execCommand('fontSize') only takes 1..7, so we emit <font size=7>
  // (styleWithCSS off) then rewrite it to a span with the exact px.
  function setSize(px){
    page.focus(); restore();
    var sel = window.getSelection();
    if (sel.rangeCount && sel.isCollapsed){
      // No selection: drop a sized zero-width span and type inside it.
      var span = document.createElement('span'); span.style.fontSize = px+'px';
      span.appendChild(document.createTextNode('​'));
      var rg = sel.getRangeAt(0); rg.insertNode(span);
      var r2 = document.createRange(); r2.selectNodeContents(span); r2.collapse(false);
      sel.removeAllRanges(); sel.addRange(r2); saved = r2.cloneRange();
      update(); notify(); return;
    }
    document.execCommand('styleWithCSS', false, false);
    document.execCommand('fontSize', false, '7');
    document.execCommand('styleWithCSS', false, true);
    var fonts = page.querySelectorAll('font[size="7"]');
    for (var i=0;i<fonts.length;i++){
      var f = fonts[i]; var span2 = document.createElement('span'); span2.style.fontSize = px+'px';
      while (f.firstChild) span2.appendChild(f.firstChild);
      var nested = span2.querySelectorAll('[style*="font-size"]');
      for (var k=0;k<nested.length;k++) nested[k].style.fontSize = '';
      f.parentNode.replaceChild(span2, f);
    }
    snapshot(); update(); notify(); repaginate();
  }
  function blockOf(node, wantCell){
    while (node && node !== page) {
      if (node.nodeType === 1) {
        var t = node.tagName;
        if (wantCell && (t==='TD'||t==='TH')) return node;
        if (t==='P'||t==='DIV'||t==='H1'||t==='H2'||t==='H3'||t==='H4'||t==='H5'||t==='H6'||t==='LI'||t==='BLOCKQUOTE') return node;
      }
      node = node.parentNode;
    }
    return page;
  }
  function eachSelectedBlock(fn){
    var s = window.getSelection(); if (!s.rangeCount){ return; }
    var rg = s.getRangeAt(0);
    var blocks = [], all = page.children;
    if (s.isCollapsed){ var b = blockOf(rg.startContainer); if (b!==page) fn(b); return; }
    for (var i=0;i<all.length;i++){ if (rg.intersectsNode && rg.intersectsNode(all[i])) blocks.push(all[i]); }
    if (!blocks.length){ var b2 = blockOf(rg.startContainer); if (b2!==page) blocks.push(b2); }
    for (var j=0;j<blocks.length;j++) fn(blocks[j]);
  }
  function setDir(dir){
    page.focus(); restore();
    eachSelectedBlock(function(b){ b.style.direction = dir; b.style.textAlign = (dir==='rtl')?'right':'left'; });
    snapshot(); notify(); repaginate();
  }
  function setLineSpacing(v){
    page.focus(); restore();
    eachSelectedBlock(function(b){ b.style.lineHeight = v; });
    snapshot(); notify(); repaginate();
  }
  function setBlock(tag){ page.focus(); restore(); document.execCommand('formatBlock', false, '<'+tag+'>'); snapshot(); update(); notify(); repaginate(); }
  function clearFmt(){ page.focus(); restore(); document.execCommand('removeFormat'); document.execCommand('unlink'); snapshot(); update(); notify(); repaginate(); }
  function inList(){
    var s = window.getSelection(); if (!s.rangeCount) return false;
    var n = s.anchorNode;
    while (n && n !== page) { if (n.nodeType===1) { var t=n.tagName; if (t==='LI'||t==='UL'||t==='OL') return true; } n = n.parentNode; }
    return false;
  }
  function indent(dir){
    page.focus(); restore();
    if (inList()) { document.execCommand(dir > 0 ? 'indent' : 'outdent', false, null); }
    else {
      eachSelectedBlock(function(b){
        var cur = parseInt(b.style.marginRight || '0', 10) || 0;
        cur = Math.max(0, cur + dir * 24); b.style.marginRight = cur ? cur + 'px' : '';
      });
    }
    snapshot(); update(); notify(); repaginate();
  }

  // ---- Link bar ----
  function openLink(){ closeMenus(); closeFind(); var lb=document.getElementById('linkbar'); lb.classList.add('open');
    var inp=document.getElementById('linkInput'); inp.value='https://'; setTimeout(function(){ inp.focus(); inp.select(); },0); }
  function cancelLink(){ document.getElementById('linkbar').classList.remove('open'); page.focus(); restore(); }
  function applyLink(){
    var url=document.getElementById('linkInput').value.trim();
    document.getElementById('linkbar').classList.remove('open'); page.focus(); restore();
    if (!url) return; if (!/^(https?:|mailto:)/i.test(url)) url='https://'+url;
    var s=window.getSelection();
    if (s.isCollapsed && s.rangeCount){
      var a=document.createElement('a'); a.href=url; a.textContent=url;
      var rg=s.getRangeAt(0); rg.insertNode(a); rg.setStartAfter(a); rg.collapse(true); s.removeAllRanges(); s.addRange(rg);
    } else { document.execCommand('createLink', false, url); }
    snapshot(); update(); notify(); repaginate();
  }

  // ---- Find & replace ----
  function openFind(){ closeMenus(); document.getElementById('linkbar').classList.remove('open');
    var fb=document.getElementById('findbar'); fb.classList.add('open');
    var fi=document.getElementById('findInput'); setTimeout(function(){ fi.focus(); },0); }
  function closeFind(){ document.getElementById('findbar').classList.remove('open'); }
  function findNext(){
    var q=document.getElementById('findInput').value; if(!q) return;
    page.focus();
    // window.find walks from the caret; wrap to the top when it fails.
    var found=false; try { found=window.find(q,false,false,true,false,false,false); } catch(e){}
    if(found){ snapshot(); var sn=window.getSelection(); if(sn.rangeCount){ var el=sn.getRangeAt(0).startContainer; if(el.nodeType===3) el=el.parentElement; if(el&&el.scrollIntoView) el.scrollIntoView({block:'center'}); } }
  }
  function replaceOne(){
    var q=document.getElementById('findInput').value, rep=document.getElementById('replaceInput').value; if(!q) return;
    var s=window.getSelection();
    if(s.rangeCount && !s.isCollapsed && s.toString().toLowerCase()===q.toLowerCase()){
      document.execCommand('insertText', false, rep); notify(); repaginate();
    }
    findNext();
  }
  function replaceAll(){
    var q=document.getElementById('findInput').value, rep=document.getElementById('replaceInput').value; if(!q) return;
    var walker=document.createTreeWalker(page, NodeFilter.SHOW_TEXT, null, false);
    var nodes=[], n; while(n=walker.nextNode()) nodes.push(n);
    var ql=q.toLowerCase(), count=0;
    for(var i=0;i<nodes.length;i++){
      var t=nodes[i].nodeValue, lo=t.toLowerCase(), idx, out='', from=0;
      while((idx=lo.indexOf(ql,from))>=0){ out+=t.substring(from,idx)+rep; from=idx+q.length; count++; }
      if(count && from>0){ out+=t.substring(from); nodes[i].nodeValue=out; }
    }
    if(count){ notify(); repaginate(); update(); }
  }

  // ---- Tables ----
  function insertTable(rows, cols){
    page.focus(); restore();
    var html='<table>'; for (var r=0;r<rows;r++){ html+='<tr>'; for (var c=0;c<cols;c++){ html+='<td><br></td>'; } html+='</tr>'; } html+='</table><p><br></p>';
    insertHtmlAtCaret(html); snapshot(); update(); notify(); repaginate();
  }
  var tRows=2, tCols=2;
  function tAdj(which, d){
    if(which==='R'){ tRows=Math.max(1, Math.min(20, tRows+d)); document.getElementById('tR').textContent=tRows; }
    else { tCols=Math.max(1, Math.min(10, tCols+d)); document.getElementById('tC').textContent=tCols; }
  }
  function doInsertTable(){ insertTable(tRows, tCols); closeMenus(); }
  function curCell(){ var s=window.getSelection(); if(!s.rangeCount) return null; var n=s.anchorNode;
    while(n && n!==page){ if(n.nodeType===1 && (n.tagName==='TD'||n.tagName==='TH')) return n; n=n.parentNode; } return null; }
  function curTable(){ var c=curCell(); var n=c; while(n && n!==page){ if(n.nodeType===1 && n.tagName==='TABLE') return n; n=n.parentNode; } return null; }
  function cellIndex(cell){ var tr=cell.parentNode; for(var i=0;i<tr.children.length;i++) if(tr.children[i]===cell) return i; return -1; }
  function placeCaret(el){ var r=document.createRange(); r.selectNodeContents(el); r.collapse(true); var s=window.getSelection(); s.removeAllRanges(); s.addRange(r); saved=r.cloneRange(); }
  function addRow(){ restore(); var cell=curCell(); if(!cell) return null; var tr=cell.parentNode, cols=tr.children.length;
    var ntr=document.createElement('tr'); for(var i=0;i<cols;i++){ var td=document.createElement('td'); td.innerHTML='<br>'; ntr.appendChild(td); }
    tr.parentNode.insertBefore(ntr, tr.nextSibling); notify(); repaginate(); return ntr; }
  function delRow(){ restore(); var cell=curCell(); if(!cell) return; var table=curTable();
    if(table && table.rows.length<=1){ delTable(); return; } var tr=cell.parentNode; tr.parentNode.removeChild(tr); page.focus(); notify(); repaginate(); }
  function addCol(){ restore(); var cell=curCell(); if(!cell) return; var idx=cellIndex(cell), table=curTable(); if(!table) return;
    var rows=table.rows; for(var i=0;i<rows.length;i++){ var ref=rows[i].cells[idx+1]||null; var td=document.createElement('td'); td.innerHTML='<br>'; rows[i].insertBefore(td, ref); } notify(); repaginate(); }
  function delCol(){ restore(); var cell=curCell(); if(!cell) return; var idx=cellIndex(cell), table=curTable(); if(!table) return;
    if(table.rows[0].cells.length<=1){ delTable(); return; } for(var i=0;i<table.rows.length;i++){ if(table.rows[i].cells[idx]) table.rows[i].deleteCell(idx); } page.focus(); notify(); repaginate(); }
  function delTable(){ restore(); var t=curTable(); if(!t) return; t.parentNode.removeChild(t); page.focus(); snapshot(); notify(); repaginate(); }
  page.addEventListener('keydown', function(e){
    if (e.key !== 'Tab') return; var cell=curCell(); if(!cell) return; e.preventDefault();
    var t=curTable(); if(!t) return; var list=Array.prototype.slice.call(t.querySelectorAll('td,th'));
    var i=list.indexOf(cell), nx=e.shiftKey ? i-1 : i+1;
    if(nx>=0 && nx<list.length){ placeCaret(list[nx]); } else if(!e.shiftKey){ var ntr=addRow(); if(ntr) placeCaret(ntr.cells[0]); }
  });

  // ---- Toolbar state ----
  function curEl(){ var s=window.getSelection(); if(!s.rangeCount) return page; var n=s.anchorNode; if(n && n.nodeType===3) n=n.parentElement; return (n && page.contains(n))?n:page; }
  function hex2(n){ n=n.toString(16); return n.length===1?'0'+n:n; }
  function rgbToHex(rgb){ var m=rgb && rgb.match(/\d+/g); if(!m||m.length<3) return '#000000'; return '#'+hex2(+m[0])+hex2(+m[1])+hex2(+m[2]); }
  function isTransparent(c){ return !c || c==='transparent' || /rgba\(0,\s*0,\s*0,\s*0\)/.test(c); }
  function shortFont(f){ if(!f) return 'خط'; f=f.replace(/['"]/g,''); var first=f.split(',')[0].trim();
    if(/noto/i.test(first)) return 'Noto'; if(/karim/i.test(first)) return 'Karim'; if(/nassim/i.test(first)) return 'Nassim'; return first.substring(0,7); }
  function closeMenus(){ var m=document.querySelectorAll('.menu'); for(var i=0;i<m.length;i++) m[i].classList.remove('open'); }
  function toggle(id, btn){
    var el=document.getElementById(id); var was=el.classList.contains('open'); closeMenus(); if(was) return;
    el.classList.add('open'); var r=btn.getBoundingClientRect(); var top=r.bottom+4;
    el.style.maxHeight=(window.innerHeight-top-10)+'px'; var w=el.offsetWidth; var left=r.right-w;
    var maxLeft=window.innerWidth-w-6; if(left>maxLeft) left=maxLeft; if(left<6) left=6;
    el.style.top=top+'px'; el.style.left=left+'px';
  }
  function update(){
    var cmds=['bold','italic','underline','strikeThrough','subscript','superscript','justifyLeft','justifyCenter','justifyRight','justifyFull'];
    var btns=document.querySelectorAll('[data-cmd]');
    for(var j=0;j<btns.length;j++){ var c=btns[j].getAttribute('data-cmd'); var on=false; try{ on=document.queryCommandState(c); }catch(e){} btns[j].classList.toggle('active', on); }
    var el=curEl(); var cs=getComputedStyle(el);
    document.getElementById('cbar').style.background = rgbToHex(cs.color);
    var bg=cs.backgroundColor; document.getElementById('hbar').style.background = isTransparent(bg)?'#fff':rgbToHex(bg);
    var px=Math.round(parseFloat(cs.fontSize)||GEO.font); document.getElementById('sizeBtn').textContent = px + ' ▾';
    document.getElementById('fontBtn').textContent = shortFont(cs.fontFamily) + ' ▾';
    var s=window.getSelection(); var label='Normal';
    if(s.rangeCount){ var bt=blockOf(s.getRangeAt(0).startContainer).tagName;
      if(bt==='H1'||bt==='H2'||bt==='H3') label=bt; else if(bt==='BLOCKQUOTE') label='Quote'; }
    document.getElementById('styleBtn').textContent = label + ' ▾';
  }
  document.addEventListener('selectionchange', function(){ if (page.contains(window.getSelection().anchorNode)) { snapshot(); update(); } });
  page.addEventListener('input', function(){ notify(); repaginate(); });
  page.addEventListener('pointerdown', closeMenus);

  // ---- Build dropdown menus from the injected config ----
  function buildMenus(){
    var mFont=document.getElementById('mFont');
    mFont.innerHTML = window.FONTS.map(function(f){ return '<button class="opt" onmousedown="event.preventDefault()" onclick="setFont(\''+f+'\');closeMenus()">'+f+'</button>'; }).join('');
    var mSize=document.getElementById('mSize');
    mSize.innerHTML = window.SIZES.map(function(s){ return '<button class="opt sz" onmousedown="event.preventDefault()" onclick="setSize('+s+');closeMenus()">'+s+'</button>'; }).join('');
    var mColor=document.getElementById('mColor');
    mColor.innerHTML = window.PALETTE.map(function(c){ return '<button class="sw" style="background:'+c+'" onmousedown="event.preventDefault()" onclick="setColor(\''+c+'\');closeMenus()"></button>'; }).join('');
    var mHilite=document.getElementById('mHilite');
    mHilite.innerHTML = window.HILITES.map(function(c){ var cls=(c==='transparent')?'sw none':'sw'; return '<button class="'+cls+'" style="background:'+c+'" onmousedown="event.preventDefault()" onclick="setHighlight(\''+c+'\');closeMenus()"></button>'; }).join('');
  }

  // ---- Cover page: insert the fixed KIU header block at the top of page 1.
  // No form — the student fills the blank fields right in the editor.
  window.insertCover = function(){
    if (page.querySelector('.cv')) return; // already added — don't duplicate
    function field(lbl){ return '<p class="cv" style="font-weight:700;border-bottom:1px solid #94a3b8;padding:9px 2px 5px;margin:0">'+lbl+' </p>'; }
    var html =
      '<p class="cv" style="text-align:center;font-weight:700;font-size:1.3em;padding:4px 0 8px;margin:0">جامعہ معرفہ العالمیہ، ریاض، سعودی عرب</p>' +
      '<hr class="cv" style="border:0;border-top:2px solid #334155;margin:2px 0 14px">' +
      field('نام:') + field('اسائمنٹ:') + field('رولنمبر:') + field('سمسٹر:') +
      '<p><br></p>';
    var tmp=document.createElement('div'); tmp.innerHTML=html;
    var first=page.firstChild;
    while(tmp.firstChild){ page.insertBefore(tmp.firstChild, first); }
    snapshot(); notify(); repaginate();
  };

  // ---- Clean body for save (strip layout spacers + zero-width spaces). ----
  function cleanClone(){
    var c=page.cloneNode(true);
    var junk=c.querySelectorAll('.tail,.gap,.brk'); for(var i=0;i<junk.length;i++) junk[i].remove();
    // strip zero-width spaces used by the collapsed-caret size hack
    var w=document.createTreeWalker(c, NodeFilter.SHOW_TEXT, null, false), n;
    while(n=w.nextNode()){ if(n.nodeValue.indexOf('​')>=0) n.nodeValue=n.nodeValue.replace(/​/g,''); }
    return c;
  }
  function getBody(){ return cleanClone().innerHTML; }
  function makeP(){ var p=document.createElement('p'); p.appendChild(document.createElement('br')); return p; }
  // Always keep a plain paragraph after a trailing table/list/etc. so the caret
  // can be placed (and text typed) below it — fixes "can't write under a table".
  function ensureTrailingParagraph(){
    var last=page.lastElementChild;
    while(last && last.classList && last.classList.contains('gap')){ last=last.previousElementSibling; }
    if(!last){ page.appendChild(makeP()); return; }
    var t=last.tagName;
    if(t==='TABLE'||t==='UL'||t==='OL'||t==='BLOCKQUOTE'||t==='HR'||t==='IMG') page.appendChild(makeP());
  }
  // ---- Continuous pagination ----
  // Draw page-break GUIDE lines snapped to real text lines. There are NO spacers,
  // so changing a font / editing never makes content "jump" to another page, and
  // paragraphs, lists and tables all flow across page boundaries (the PDF, via
  // CSS paged-media, breaks at the same line positions). getClientRects() over the
  // whole content gives one rect per line box; we cut every page-height (`ph`) at
  // the last line that fits, so every page holds the same amount → uniform pages.
  var guides=document.getElementById('guides');
  function pageBreaks(){
    var ph=GEO.ph, pad=GEO.pad, tol=2;
    var pr=page.getBoundingClientRect();
    var rng=document.createRange(); rng.selectNodeContents(page);
    var rects=rng.getClientRects();
    var bs=[], seen={};
    for(var i=0;i<rects.length;i++){ var r=rects[i]; if(r.height<=0) continue;
      var b=Math.round(r.bottom - pr.top); if(b>pad && !seen[b]){ seen[b]=1; bs.push(b); } }
    bs.sort(function(a,b){ return a-b; });
    var breaks=[], top=pad, prev=pad;
    for(var j=0;j<bs.length;j++){
      var b=bs[j];
      // While this line overruns the current page, break at the last line that fit
      // (or hard-break if a single line is taller than a whole page).
      while(b - top > ph + tol){
        var by=(prev > top + tol) ? prev : (top + ph);
        breaks.push(by); top=by; if(prev<top) prev=top;
      }
      prev=b;
    }
    return breaks;
  }
  function paginate(){
    ensureTrailingParagraph();
    var breaks=pageBreaks();
    var tops=[GEO.pad].concat(breaks);
    var html='';
    for(var i=0;i<tops.length;i++){
      if(i>0) html+='<div class="pb" style="top:'+tops[i]+'px"></div>';
      html+='<div class="pn" style="top:'+(tops[i]+(i>0?8:4))+'px">صفحہ '+(i+1)+'</div>';
    }
    guides.innerHTML=html;
    updateCounts(tops.length);
  }
  function updateCounts(pageCount){
    var text=(page.innerText||'').replace(/​/g,'').trim();
    var words=text?text.split(/\s+/).length:0;
    document.getElementById('wcWords').textContent=words+(words===1?' word':' words');
    document.getElementById('wcPages').textContent=pageCount+(pageCount===1?' page':' pages');
  }
  var pTimer=null; function repaginate(){ clearTimeout(pTimer); pTimer=setTimeout(paginate, 160); }

  // ---- Smart paste (clean Word/Docs/web HTML or AI-app Markdown). ----
  var KEEP={P:1,BR:1,B:1,I:1,U:1,S:1,SPAN:1,H1:1,H2:1,H3:1,UL:1,OL:1,LI:1,BLOCKQUOTE:1,A:1,TABLE:1,THEAD:1,TBODY:1,TR:1,TD:1,TH:1,SUB:1,SUP:1};
  var DROP={SCRIPT:1,STYLE:1,META:1,LINK:1,TITLE:1,HEAD:1,'O:P':1,IFRAME:1,OBJECT:1,EMBED:1,NOSCRIPT:1,IMG:1,SVG:1,INPUT:1,BUTTON:1};
  var RENAME={STRONG:'B',EM:'I',STRIKE:'S',DEL:'S',H4:'H3',H5:'H3',H6:'H3',FONT:'SPAN',DIV:'P'};
  var FONTPX={'1':10,'2':13,'3':16,'4':18,'5':24,'6':32,'7':48};
  var OKFAMILIES=['Noto Nastaliq Urdu','Bahij Karim','Bahij Nassim'];
  function blockTag(t){ return /^(P|H1|H2|H3|UL|OL|LI|BLOCKQUOTE|TABLE|THEAD|TBODY|TR|TD|TH)$/.test(t); }
  function mapFamily(v){ if(!v) return ''; var s=v.replace(/["']/g,'').toLowerCase();
    for(var i=0;i<OKFAMILIES.length;i++){ if(s.indexOf(OKFAMILIES[i].toLowerCase())>=0) return OKFAMILIES[i]; } return ''; }
  function sizeToPx(v){ if(!v) return ''; var m=String(v).match(/([0-9.]+)\s*(px|pt|)/i); if(!m) return '';
    var n=parseFloat(m[1]); if(!(n>0)) return ''; if((m[2]||'').toLowerCase()==='pt') n=n*96/72; n=Math.round(n); if(n<8) n=8; if(n>96) n=96; return n+'px'; }
  function cleanStyle(el){ var s=el.style, out='';
    var fw=s.fontWeight; if(fw==='bold'||fw==='bolder'||parseInt(fw,10)>=600) out+='font-weight:bold;';
    if(s.fontStyle==='italic') out+='font-style:italic;';
    var td=s.textDecorationLine||s.textDecoration||''; if(td.indexOf('underline')>=0) out+='text-decoration:underline;'; else if(td.indexOf('line-through')>=0) out+='text-decoration:line-through;';
    if(s.color) out+='color:'+s.color+';';
    var bg=s.backgroundColor; if(bg && !/rgba?\(0,\s*0,\s*0,\s*0\)|transparent/.test(bg)) out+='background-color:'+bg+';';
    var fs=sizeToPx(s.fontSize); if(fs) out+='font-size:'+fs+';';
    var ff=mapFamily(s.fontFamily); if(ff) out+="font-family:'"+ff+"';";
    var ta=s.textAlign; if(ta==='left'||ta==='right'||ta==='center'||ta==='justify') out+='text-align:'+ta+';';
    if(s.direction==='ltr'||s.direction==='rtl') out+='direction:'+s.direction+';';
    return out; }
  function unwrap(node){ var p=node.parentNode; if(!p) return; while(node.firstChild) p.insertBefore(node.firstChild,node); p.removeChild(node); }
  function cleanChildren(el){ var kids=[]; for(var i=0;i<el.childNodes.length;i++) kids.push(el.childNodes[i]); for(var j=0;j<kids.length;j++) cleanNode(kids[j]); }
  function cleanNode(node){
    if(node.nodeType===8){ if(node.parentNode) node.parentNode.removeChild(node); return; }
    if(node.nodeType!==1) return;
    var tag=node.tagName.toUpperCase();
    if(DROP[tag]){ node.parentNode.removeChild(node); return; }
    if(tag==='FONT'){ var col=node.getAttribute('color'); if(col) node.style.color=col;
      var sz=node.getAttribute('size'); if(sz&&FONTPX[sz]) node.style.fontSize=FONTPX[sz]+'px';
      var fc=node.getAttribute('face'); if(fc) node.style.fontFamily=fc; }
    cleanChildren(node);
    if(tag==='DIV'){ for(var c=0;c<node.children.length;c++){ if(blockTag(node.children[c].tagName.toUpperCase())){ unwrap(node); return; } } }
    var to=RENAME[tag] || (KEEP[tag]?tag:null);
    if(!to){ unwrap(node); return; }
    var st=cleanStyle(node);
    if(to==='SPAN' && !st){ unwrap(node); return; }
    var ne=document.createElement(to);
    if(to==='A'){ var h=node.getAttribute('href')||''; if(/^(https?:|mailto:)/i.test(h)) ne.setAttribute('href',h); }
    if(to==='TD'||to==='TH'){ var csp=node.getAttribute('colspan'), rsp=node.getAttribute('rowspan'); if(csp) ne.setAttribute('colspan',csp); if(rsp) ne.setAttribute('rowspan',rsp); }
    while(node.firstChild) ne.appendChild(node.firstChild);
    if(st) ne.setAttribute('style', st);
    node.parentNode.replaceChild(ne, node);
  }
  function wrapInlines(body){ var run=null, kids=[]; for(var i=0;i<body.childNodes.length;i++) kids.push(body.childNodes[i]);
    for(var j=0;j<kids.length;j++){ var n=kids[j];
      if(n.nodeType===1 && blockTag(n.tagName.toUpperCase())){ run=null; continue; }
      if(n.nodeType===3 && !/\S/.test(n.nodeValue)){ body.removeChild(n); continue; }
      if(!run){ run=document.createElement('P'); body.insertBefore(run, n); } run.appendChild(n); } }
  function isEmptyBlock(el){ if(el.nodeType!==1) return false; var t=el.tagName; if(t==='TABLE'||t==='UL'||t==='OL'||t==='IMG'||t==='HR') return false; return (el.textContent||'').replace(/ /g,' ').trim().length===0; }
  function minify(body){ var kids=[]; for(var i=0;i<body.children.length;i++) kids.push(body.children[i]); var prevEmpty=false;
    for(var j=0;j<kids.length;j++){ var empty=isEmptyBlock(kids[j]); if(empty&&prevEmpty){ body.removeChild(kids[j]); continue; } prevEmpty=empty; }
    while(body.firstElementChild && isEmptyBlock(body.firstElementChild)) body.removeChild(body.firstElementChild);
    while(body.lastElementChild && isEmptyBlock(body.lastElementChild)) body.removeChild(body.lastElementChild); }
  function sanitizeHtml(html){ var root; try { root=new DOMParser().parseFromString(html,'text/html').body; } catch(e){ root=document.createElement('div'); root.innerHTML=html; }
    cleanChildren(root); wrapInlines(root); minify(root); return root.innerHTML; }
  function doPaste(clean){ page.focus(); restore(); try { insertHtmlAtCaret(clean); } catch(_3){ try { document.execCommand('insertHTML', false, clean); } catch(_4){} }
    requestPasteFonts(clean); snapshot(); update(); notify(); repaginate(); }
  function requestPasteFonts(html){ for(var i=0;i<OKFAMILIES.length;i++){ if(html.indexOf(OKFAMILIES[i])>=0){ try { Fonts.postMessage(OKFAMILIES[i]); } catch(e){} } } }
  function hasRichBlocks(html){ return /<(h[1-6]|table|ul|ol|li|blockquote)\b/i.test(html); }
  function looksMarkdown(t){ if(!t) return false;
    if(/(^|\n)[ \t]{0,3}(#{1,6}[ \t]+|[-*+][ \t]+|\d+[.)][ \t]+|>[ \t]?)/.test(t)) return true; // headings/lists/quotes
    if(/(^|\n)[^\n]*\|[^\n]*\|/.test(t)) return true;                                            // table row
    if(/\*\*[^*\n]+\*\*/.test(t) || /(^|\s)\*[^*\s][^*\n]*\*(\s|$)/.test(t)) return true;          // bold/italic
    if(/(^|\s)`[^`\n]+`/.test(t)) return true;                                                     // inline code
    return false; }
  // Flatten cleaned HTML to plain text, turning block tags into line breaks, so
  // we can detect/convert Markdown that a source pasted as flat HTML (e.g. an AI
  // app whose clipboard HTML is just <div>### Heading</div> with literal '###').
  function htmlToPlain(html){
    var d=document.createElement('div'); d.innerHTML=html;
    function walk(node){ var out='';
      for(var i=0;i<node.childNodes.length;i++){ var c=node.childNodes[i];
        if(c.nodeType===3){ out+=c.nodeValue; }
        else if(c.nodeType===1){ var t=c.tagName;
          if(t==='BR'){ out+='\n'; }
          else { out+=walk(c); if(/^(P|DIV|H[1-6]|LI|TR|BLOCKQUOTE|UL|OL|TABLE)$/.test(t)) out+='\n'; } } }
      return out; }
    return walk(d).replace(/[ \t]+\n/g,'\n').replace(/\n{3,}/g,'\n\n').trim();
  }
  // Decide how to insert pasted content:
  //  - rich HTML with real structure (headings/tables/lists) -> clean & keep it
  //  - flat HTML / plain text that LOOKS like Markdown -> convert to formatted HTML
  //  - otherwise -> keep the cleaned inline HTML (preserves bold/colour) or wrap text
  window.pasteFromDart = function(html, text){
    var h=(html||'').trim(), tx=(text||'').trim();
    if(h){
      var clean=sanitizeHtml(h);
      if(hasRichBlocks(clean)){ doPaste(clean); return; }
      var plain=htmlToPlain(clean);
      var md = (tx && looksMarkdown(tx)) ? tx : (looksMarkdown(plain) ? plain : '');
      if(md){ doPaste(mdToHtml(md)); return; }
      if(clean && clean.replace(/<[^>]*>/g,'').trim()){ doPaste(clean); return; }
    }
    if(tx){ doPaste(mdToHtml(tx)); return; }
  };
  function pasteFromClipboard(){ page.focus(); restore(); try { ClipboardBridge.postMessage(JSON.stringify({html:'',text:''})); } catch(_){} }
  // All paste routes go through here so content is ALWAYS cleaned/converted, never
  // inserted raw. The bridge asks Dart to read the system clipboard natively
  // (reliable on Android); the event data is a fallback. A short guard dedupes
  // the paste + beforeinput pair that some WebViews fire for one paste.
  var lastPaste = 0;
  function triggerPaste(ehtml, etext){
    var now = +new Date(); if (now - lastPaste < 350) return; lastPaste = now;
    try { ClipboardBridge.postMessage(JSON.stringify({html: ehtml||'', text: etext||''})); }
    catch(_2){ if(ehtml && ehtml.trim()) doPaste(sanitizeHtml(ehtml)); else if(etext && etext.trim()) doPaste(mdToHtml(etext)); }
  }
  page.addEventListener('paste', function(e){ e.preventDefault();
    var data=e.clipboardData||window.clipboardData; var ehtml='', etext='';
    try { if(data){ ehtml=data.getData('text/html')||''; etext=data.getData('text/plain')||''; } } catch(_){}
    triggerPaste(ehtml, etext);
  });
  // Catch system-menu pastes on WebViews that fire beforeinput but not a
  // cancelable paste event (otherwise raw '### ...' would slip straight in).
  page.addEventListener('beforeinput', function(e){
    if(e.inputType==='insertFromPaste'){ try { e.preventDefault(); } catch(_){} triggerPaste('', ''); }
  });

  // ---- Boot ----
  applyGeoVars(); buildMenus();
  window.addEventListener('load', function(){ setTimeout(paginate, 60); });
  setTimeout(function(){ paginate(); update(); }, 80);
''';
  }

  /// JS Markdown → HTML converter (raw string so regex escapes pass through).
  static String _mdConverterJs() {
    return r'''
  function esc(s){ return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }
  function inlineMd(s){
    s = s.replace(/\*\*(.+?)\*\*/g, '<b>$1</b>');
    s = s.replace(/__(.+?)__/g, '<b>$1</b>');
    s = s.replace(/\*(.+?)\*/g, '<i>$1</i>');
    s = s.replace(/(^|\s)_(.+?)_(?=\s|$)/g, '$1<i>$2</i>');
    s = s.replace(/`([^`]+)`/g, '<span style="background:#f3f4f6;padding:0 3px;border-radius:3px;font-family:monospace">$1</span>');
    s = s.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
    return s;
  }
  function mdNextContent(lines, i){ while(i<lines.length && !lines[i].trim()) i++; return i; }
  function mdIsOrdered(l){ return /^\s*\d+[.)]\s+/.test(l); }
  function mdIsList(l){ return /^\s*[-*+]\s+/.test(l) || mdIsOrdered(l); }
  function mdIsQuote(l){ return /^\s*>\s?/.test(l); }
  function mdIsTableRow(l){ return l.trim().length>0 && (l.match(/\|/g)||[]).length>=2; }
  function mdIsSep(l){ var s=l.trim(); return /^[\s|:\-]+$/.test(s) && s.indexOf('-')>=0; }
  function mdToHtml(t){
    var lines = (t||'').replace(/\r\n/g,'\n').replace(/\r/g,'\n').split('\n');
    var out='', i=0, len=lines.length;
    while(i<len){
      var line = lines[i];
      if(!line.trim()){ i++; continue; }
      var hm = line.match(/^\s*(#{1,6})\s+(.+)/);
      if(hm){ var lvl=Math.min(hm[1].length,3); out+='<h'+lvl+'>'+inlineMd(esc(hm[2].trim()))+'</h'+lvl+'>'; i++; continue; }
      if(mdIsTableRow(line)){
        var rows=[];
        while(i<len){
          if(!lines[i].trim()){ var jn=mdNextContent(lines,i); if(jn<len && mdIsTableRow(lines[jn])){ i=jn; continue; } break; }
          if(!mdIsTableRow(lines[i])) break;
          if(mdIsSep(lines[i])){ i++; continue; }
          var r=lines[i].trim(); if(r.charAt(0)==='|') r=r.substring(1); if(r.charAt(r.length-1)==='|') r=r.substring(0,r.length-1);
          rows.push(r.split('|')); i++;
        }
        if(rows.length){ out+='<table>';
          for(var ri=0;ri<rows.length;ri++){ out+='<tr>'; var tag=(ri===0)?'th':'td';
            for(var ci=0;ci<rows[ri].length;ci++) out+='<'+tag+'>'+inlineMd(esc(rows[ri][ci].trim()))+'</'+tag+'>'; out+='</tr>'; }
          out+='</table>'; }
        continue;
      }
      if(/^\s*([-*_])\s*(\1\s*){2,}$/.test(line)){ i++; continue; }
      if(mdIsQuote(line)){ var bq='';
        while(i<len){ if(!lines[i].trim()){ var jq=mdNextContent(lines,i); if(jq<len && mdIsQuote(lines[jq])){ i=jq; continue; } break; }
          if(!mdIsQuote(lines[i])) break; var qln=lines[i].replace(/^\s*>\s?/,'').trim(); if(qln) bq+='<p>'+inlineMd(esc(qln))+'</p>'; i++; }
        out+='<blockquote>'+(bq||'<p><br></p>')+'</blockquote>'; continue; }
      if(mdIsList(line)){ var ordered=mdIsOrdered(line); out+= ordered?'<ol>':'<ul>';
        while(i<len){ if(!lines[i].trim()){ var jl=mdNextContent(lines,i); if(jl<len && mdIsList(lines[jl]) && mdIsOrdered(lines[jl])===ordered){ i=jl; continue; } break; }
          if(!mdIsList(lines[i]) || mdIsOrdered(lines[i])!==ordered) break; var item=lines[i].replace(/^\s*(?:[-*+]|\d+[.)])\s+/,'').trim(); out+='<li>'+inlineMd(esc(item))+'</li>'; i++; }
        out+= ordered?'</ol>':'</ul>'; continue; }
      out+='<p>'+inlineMd(esc(line.trim()))+'</p>'; i++;
    }
    return out || '<p><br></p>';
  }
''';
  }
}
