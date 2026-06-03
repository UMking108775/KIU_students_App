import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

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

  /// Exposes the printer so callers can access clipboard utilities.
  HtmlPdfPrinter get printer => _printer;

  /// Family name → bundled asset, so we embed only the fonts actually used.
  static const Map<String, String> _fontAssets = {
    AssignmentFonts.notoNastaliqUrduFamily:
        'assets/fonts/NotoNastaliqUrdu-Regular.ttf',
    AssignmentFonts.bahijKarimFamily: 'assets/fonts/BahijKarim-Regular.ttf',
    AssignmentFonts.bahijNassimFamily: 'assets/fonts/BahijNassim-Regular.ttf',
  };

  /// The shared print document (head + CSS + body) used for the raw-HTML export
  /// so it paginates and shapes identically to the on-screen editor.
  String _printShell({
    required String body,
    required String fontsCss,
    required double fontSizePx,
    required double lineHeight,
    required bool border,
  }) {
    final base = AssignmentFonts.fallbackFamily;
    // Draw the frame on the BODY itself with box-decoration-break:clone so it
    // repeats per page (an inner wrapper could fragment and strand a heading).
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
h1 { font-size: 1.4em; } h2 { font-size: 1.2em; } h3 { font-size: 1.08em; }
h4 { font-size: 1em; } h5 { font-size: 0.95em; } h6 { font-size: 0.9em; }
ul, ol { margin: 0; padding-right: 1.6em; padding-left: 0; }
blockquote { border-right: 4px solid #ccc; border-left: 0; margin: 0; padding-right: 12px; }
table { border-collapse: collapse; width: 100%; table-layout: fixed; }
td, th { border: 1px solid #888; padding: 4px 8px; vertical-align: top;
  word-wrap: break-word; overflow-wrap: break-word; word-break: break-word; }
a { color: #1d4ed8; text-decoration: underline; }
img { max-width: 100%; }
/* Smart page breaks: nothing forced onto its own page; break only between lines
   (the browser never splits a line mid-way); a heading stays with its text. */
* {
  break-before: auto; page-break-before: auto;
  break-inside: auto; page-break-inside: auto;
  orphans: 1; widows: 1;
}
h1, h2, h3, h4, h5, h6 { break-after: avoid; page-break-after: avoid; }
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

  /// A small inline-SVG alignment icon (uses currentColor so it flips white
  /// when the button is active).
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

  /// A small inline-SVG list icon: three rows of text, with bullets ([ordered]
  /// false) or 1./2./3. numbers ([ordered] true) as the markers. RTL-laid out
  /// (markers on the right) to match the writing direction.
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

  /// A small inline-SVG table (grid) icon.
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

  /// Builds the self-contained HTML for the WebView editor: a small toolbar
  /// (bold/italic/underline, font family & size, colour, RTL/LTR) over a
  /// page-styled `contenteditable` area, with all fonts embedded. [initialBody]
  /// is the saved draft's inner HTML (empty for a new document).
  Future<String> buildEditorHtml({
    String initialBody = '',
    double fontSizePx = 16,
    double lineHeight = 2.0,
  }) async {
    final fontsCss = await _fontFaceCssForFamilies(_fontAssets.keys);
    final base = AssignmentFonts.fallbackFamily;
    // Always start inside a <p> so all content lives in block elements (the
    // paginator measures element children).
    final startBody =
        initialBody.trim().isEmpty ? '<p><br></p>' : initialBody;
    final pad = (fontSizePx * 2.2).round(); // page inner margin (top/right/bottom/left)
    final ph = (12 * fontSizePx * lineHeight).round();
    const gap = 22; // grey desk gap between sheets
    final sheetH = ph + 2 * pad;
    final step = sheetH + gap;
    const palette = [
      '#000000', '#374151', '#6b7280', '#9ca3af',
      '#e11d48', '#dc2626', '#ea580c', '#d97706',
      '#ca8a04', '#16a34a', '#059669', '#0891b2',
      '#0284c7', '#1d4ed8', '#4f46e5', '#7c3aed',
      '#9333ea', '#db2777', '#be123c', '#78350f',
    ];
    // Custom dropdown buttons (NOT native <select>/<input>, which steal focus on
    // tap and wipe the text selection). Each uses preventDefault to keep the
    // editor selection intact, exactly like the working B/I/U buttons.
    final fontMenu = _fontAssets.keys
        .map((f) =>
            "<button class=\"opt\" onmousedown=\"event.preventDefault()\" onclick=\"setFont('$f');closeMenus()\">$f</button>")
        .join();
    final colorMenu = palette
        .map((c) =>
            "<button class=\"sw\" style=\"background:$c\" onmousedown=\"event.preventDefault()\" onclick=\"setColor('$c');closeMenus()\"></button>")
        .join();
    // A 6×6 hover/tap grid for choosing the new table's size (rows × cols).
    final tableGrid = StringBuffer();
    for (var r = 1; r <= 6; r++) {
      for (var c = 1; c <= 6; c++) {
        tableGrid.write('<div class="tgc" data-r="$r" data-c="$c" '
            'onpointerover="tgHover(this)" onmousedown="event.preventDefault()" '
            'onclick="insertTable($r,$c);closeMenus()"></div>');
      }
    }

    return '''
<!DOCTYPE html>
<html lang="ur" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<style>
$fontsCss
* { -webkit-tap-highlight-color: transparent; box-sizing: border-box;
    -webkit-user-select: none; user-select: none; }
html, body { margin: 0; padding: 0; background: #e5e7eb; }
#toolbar {
  position: sticky; top: 0; z-index: 10;
  display: flex; flex-wrap: nowrap; overflow-x: auto; gap: 5px; align-items: center;
  background: #fff; border-bottom: 1px solid #d1d5db; padding: 7px 8px; direction: ltr;
  -webkit-overflow-scrolling: touch;
}
#toolbar::-webkit-scrollbar { height: 0; }
.btn {
  flex: 0 0 auto; height: 40px; min-width: 42px; padding: 0 10px;
  display: inline-flex; align-items: center; justify-content: center;
  border: 1px solid #d1d5db; border-radius: 9px; background: #f9fafb; color: #111827;
  font-size: 17px; font-family: serif; line-height: 1;
}
.btn svg { width: 19px; height: 19px; display: block; }
.btn.active { background: #2563eb; border-color: #2563eb; color: #fff; }
.btn:active { transform: scale(.95); }
.col { flex-direction: column; gap: 0; }
#cbar { display: block; width: 16px; height: 3px; background: #000; margin-top: 2px; border-radius: 2px; }
.sep { flex: 0 0 auto; width: 1px; height: 26px; background: #e5e7eb; margin: 0 3px; }
.dd { position: relative; flex: 0 0 auto; }
/* Menus are position:fixed (NOT absolute) so they escape the toolbar's
   overflow-x:auto box, which would otherwise clip them (a horizontal overflow
   forces overflow-y to compute to auto, hiding anything below the bar). Their
   top/left are set in JS from the trigger button's rect. */
.menu { display: none; position: fixed; top: 0; left: 0; z-index: 30;
  background: #fff; border: 1px solid #d1d5db; border-radius: 10px; padding: 6px;
  box-shadow: 0 10px 26px rgba(0,0,0,.20); max-height: 55vh; overflow: auto; min-width: 130px; }
.menu.open { display: block; }
.menu.grid3.open { display: grid; grid-template-columns: repeat(3,1fr); gap: 5px; min-width: 150px; }
.menu.grid4.open { display: grid; grid-template-columns: repeat(4,1fr); gap: 8px; min-width: 0; }
.opt { display: block; width: 100%; text-align: right; padding: 9px 12px; border: 0;
  background: #fff; border-radius: 7px; font: 14px sans-serif; white-space: nowrap; color: #111827; }
.opt.sz { text-align: center; border: 1px solid #e5e7eb; padding: 9px 4px; }
.opt:active { background: #eef2ff; }
.sw { width: 30px; height: 30px; border-radius: 7px; border: 1px solid rgba(0,0,0,.25); padding: 0; }
#linkbar { display: none; position: sticky; top: 54px; z-index: 9; align-items: center;
  gap: 6px; background: #fff; border-bottom: 1px solid #d1d5db; padding: 6px 8px; direction: ltr; }
#linkbar.open { display: flex; }
#linkInput { flex: 1 1 auto; min-width: 0; height: 38px; border: 1px solid #d1d5db;
  border-radius: 8px; padding: 0 10px; font: 15px sans-serif; color: #111827;
  -webkit-user-select: text; user-select: text; }
.tablemenu { min-width: 0; }
.tglabel { text-align: center; font: 600 12px sans-serif; color: #374151; padding: 2px 0 7px; }
#tgrid { display: grid; grid-template-columns: repeat(6, 1fr); gap: 3px; direction: ltr; }
.tgc { width: 22px; height: 22px; border: 1px solid #d1d5db; border-radius: 3px; background: #fff; }
.tgc.on { background: #bfdbfe; border-color: #2563eb; }
.tact { display: flex; flex-wrap: wrap; gap: 5px; margin-top: 9px; }
.tactb { width: auto; flex: 1 1 42%; text-align: center; border: 1px solid #e5e7eb; padding: 9px 4px; }
#scroller { padding: 14px 10px 50vh; }
#pagewrap { position: relative; margin: 0 auto; }
#sheets { position: absolute; inset: 0; z-index: 0; pointer-events: none; }
#sheets .sheet { position: absolute; left: 0; right: 0; background: #fff;
  border-radius: 3px; box-shadow: 0 2px 12px rgba(0,0,0,.22); }
#sheets .snum { position: absolute; left: 50%; transform: translateX(-50%);
  font: 600 11px sans-serif; color: #9ca3af; }
#page {
  position: relative; z-index: 1; background: transparent; margin: 0;
  padding: ${pad}px; min-height: ${sheetH}px;
  direction: rtl; text-align: right;
  font-family: '$base', serif; font-size: ${fontSizePx}px; line-height: $lineHeight;
  color: #000; outline: none; -webkit-user-select: text; user-select: text;
}
#page:empty:before { content: attr(data-ph); color: #9ca3af; }
#page p { margin: 0; }
#page h1,#page h2,#page h3,#page h4,#page h5,#page h6 { line-height: 1.4; margin: .3em 0; font-weight: 700; }
#page h1 { font-size: 1.4em; } #page h2 { font-size: 1.2em; } #page h3 { font-size: 1.08em; }
#page h4 { font-size: 1em; } #page h5 { font-size: 0.95em; } #page h6 { font-size: 0.9em; }
#page ul, #page ol { margin: 0; padding-right: 1.6em; padding-left: 0; }
#page blockquote { border-right: 4px solid #ccc; margin: 0; padding-right: 12px; }
#page table { border-collapse: collapse; width: 100%; table-layout: fixed; }
#page td, #page th { border: 1px solid #888; padding: 4px 8px; vertical-align: top;
  word-wrap: break-word; overflow-wrap: break-word; word-break: break-word; }
#page a { color: #1d4ed8; }
.tail, .gap { width: 100%; }
</style>
</head>
<body>
<div id="toolbar">
  <button class="btn" onmousedown="event.preventDefault()" onclick="cmd('undo')" title="Undo">↶</button>
  <button class="btn" onmousedown="event.preventDefault()" onclick="cmd('redo')" title="Redo">↷</button>
  <span class="sep"></span>
  <button class="btn" onmousedown="event.preventDefault()" onclick="pasteFromClipboard()" title="Paste (keeps formatting)">📋</button>
  <span class="sep"></span>
  <button class="btn" data-cmd="bold" onmousedown="event.preventDefault()" onclick="cmd('bold')"><b>B</b></button>
  <button class="btn" data-cmd="italic" onmousedown="event.preventDefault()" onclick="cmd('italic')"><i>I</i></button>
  <button class="btn" data-cmd="underline" onmousedown="event.preventDefault()" onclick="cmd('underline')"><u>U</u></button>
  <span class="sep"></span>
  <button class="btn" data-cmd="justifyRight" onmousedown="event.preventDefault()" onclick="cmd('justifyRight')">${_alignSvg('right')}</button>
  <button class="btn" data-cmd="justifyCenter" onmousedown="event.preventDefault()" onclick="cmd('justifyCenter')">${_alignSvg('center')}</button>
  <button class="btn" data-cmd="justifyLeft" onmousedown="event.preventDefault()" onclick="cmd('justifyLeft')">${_alignSvg('left')}</button>
  <button class="btn" data-cmd="justifyFull" onmousedown="event.preventDefault()" onclick="cmd('justifyFull')">${_alignSvg('full')}</button>
  <span class="sep"></span>
  <button class="btn" data-cmd="insertUnorderedList" onmousedown="event.preventDefault()" onclick="cmd('insertUnorderedList')" title="Bulleted list">${_listSvg(false)}</button>
  <button class="btn" data-cmd="insertOrderedList" onmousedown="event.preventDefault()" onclick="cmd('insertOrderedList')" title="Numbered list">${_listSvg(true)}</button>
  <div class="dd">
    <button class="btn" onmousedown="event.preventDefault()" onclick="toggle('mTable', this)" title="Table">${_tableSvg()} ▾</button>
    <div id="mTable" class="menu tablemenu">
      <div id="tgLabel" class="tglabel">Insert table</div>
      <div id="tgrid">$tableGrid</div>
      <div class="tact">
        <button class="opt tactb" onmousedown="event.preventDefault()" onclick="addRow();closeMenus()">+ Row</button>
        <button class="opt tactb" onmousedown="event.preventDefault()" onclick="addCol();closeMenus()">+ Col</button>
        <button class="opt tactb" onmousedown="event.preventDefault()" onclick="delRow();closeMenus()">− Row</button>
        <button class="opt tactb" onmousedown="event.preventDefault()" onclick="delCol();closeMenus()">− Col</button>
        <button class="opt tactb" onmousedown="event.preventDefault()" onclick="delTable();closeMenus()" style="flex:1 1 100%;color:#dc2626">Delete table</button>
      </div>
    </div>
  </div>
  <span class="sep"></span>
  <div class="dd">
    <button id="styleBtn" class="btn" onmousedown="event.preventDefault()" onclick="toggle('mStyle', this)" title="Paragraph style">Normal ▾</button>
    <div id="mStyle" class="menu">
      <button class="opt" onmousedown="event.preventDefault()" onclick="setBlock('p');closeMenus()">Normal</button>
      <button class="opt" onmousedown="event.preventDefault()" onclick="setBlock('h1');closeMenus()" style="font-size:1.4em;font-weight:700">Heading 1</button>
      <button class="opt" onmousedown="event.preventDefault()" onclick="setBlock('h2');closeMenus()" style="font-size:1.2em;font-weight:700">Heading 2</button>
      <button class="opt" onmousedown="event.preventDefault()" onclick="setBlock('h3');closeMenus()" style="font-size:1.08em;font-weight:700">Heading 3</button>
      <button class="opt" onmousedown="event.preventDefault()" onclick="setBlock('blockquote');closeMenus()" style="color:#6b7280">❝ Quote</button>
    </div>
  </div>
  <button class="btn" onmousedown="event.preventDefault()" onclick="indent(-1)" title="Decrease indent">⇤</button>
  <button class="btn" onmousedown="event.preventDefault()" onclick="indent(1)" title="Increase indent">⇥</button>
  <span class="sep"></span>
  <button class="btn" onmousedown="event.preventDefault()" onclick="openLink()" title="Insert link">🔗</button>
  <button class="btn" onmousedown="event.preventDefault()" onclick="clearFmt()" title="Clear formatting"><span style="text-decoration:underline">T</span>x</button>
  <span class="sep"></span>
  <div class="dd">
    <button class="btn" onmousedown="event.preventDefault()" onclick="toggle('mFont', this)" title="Font">خط ▾</button>
    <div id="mFont" class="menu">$fontMenu</div>
  </div>
  <div class="dd">
    <button class="btn col" onmousedown="event.preventDefault()" onclick="toggle('mColor', this)" title="Colour">A<i id="cbar"></i></button>
    <div id="mColor" class="menu grid4">$colorMenu</div>
  </div>
  <span class="sep"></span>
  <button class="btn" onmousedown="event.preventDefault()" onclick="setDir('rtl')" title="RTL">RTL</button>
  <button class="btn" onmousedown="event.preventDefault()" onclick="setDir('ltr')" title="LTR">LTR</button>
</div>
<div id="linkbar">
  <input id="linkInput" type="url" inputmode="url" placeholder="https://example.com" />
  <button class="btn" onmousedown="event.preventDefault()" onclick="applyLink()" title="Apply">✓</button>
  <button class="btn" onmousedown="event.preventDefault()" onclick="cancelLink()" title="Cancel">✕</button>
</div>
<div id="scroller">
<div id="pagewrap">
<div id="sheets"></div>
<div id="page" contenteditable="true" data-ph="یہاں اپنی اسائنمنٹ لکھیں…">$startBody</div>
</div>
</div>
<script>
  var page = document.getElementById('page');
  document.execCommand('styleWithCSS', true);
  try { document.execCommand('defaultParagraphSeparator', false, 'p'); } catch(e){}
  var saved = null;
  function snapshot(){ var s = window.getSelection(); if (s.rangeCount && page.contains(s.anchorNode)) { saved = s.getRangeAt(0).cloneRange(); } }
  function restore(){ if (!saved) return; var s = window.getSelection(); s.removeAllRanges(); s.addRange(saved); }
  function notify(){ try { Editor.postMessage('changed'); } catch(e){} }
  // Insert an HTML string at the caret as REAL nodes. We do this manually rather
  // than execCommand('insertHTML') because that command's fragment sanitiser on
  // Android WebView silently DROPS tables (and mangles headings/links) while
  // keeping lists — which is why pasted rich content used to come in flattened.
  function placeCaretEnd(el){
    var r = document.createRange();
    if (el && el.nodeType === 1){ r.selectNodeContents(el); r.collapse(false); }
    else if (el){ r.setStartAfter(el); r.collapse(true); }
    else return;
    var s = window.getSelection(); s.removeAllRanges(); s.addRange(r);
    if (page.contains(r.startContainer)) saved = r.cloneRange();
  }
  function insertHtmlAtCaret(html){
    var temp = document.createElement('div');
    temp.innerHTML = html;
    var nodes = [];
    while (temp.firstChild){ nodes.push(temp.firstChild); temp.removeChild(temp.firstChild); }
    if (!nodes.length) return;
    var sel = window.getSelection();
    if (!sel.rangeCount || !page.contains(sel.anchorNode)){
      for (var a=0;a<nodes.length;a++) page.appendChild(nodes[a]);
      placeCaretEnd(nodes[nodes.length-1]); return;
    }
    var range = sel.getRangeAt(0);
    range.deleteContents();
    var block = blockOf(range.startContainer);
    if (block === page){
      var frag = document.createDocumentFragment();
      for (var c=0;c<nodes.length;c++) frag.appendChild(nodes[c]);
      range.insertNode(frag);
    } else {
      // Insert the pasted blocks as siblings AFTER the current block; drop the
      // current block if it was empty (e.g. pasting into a blank document).
      var ref = block.nextSibling;
      for (var d=0;d<nodes.length;d++) page.insertBefore(nodes[d], ref);
      if (isEmptyBlock(block) && block.parentNode) block.parentNode.removeChild(block);
    }
    placeCaretEnd(nodes[nodes.length-1]);
  }
  function cmd(c){ page.focus(); restore(); document.execCommand(c, false, null); snapshot(); update(); notify(); repaginate(); }
  function setFont(f){ page.focus(); restore(); document.execCommand('fontName', false, f); snapshot(); update(); notify(); repaginate(); }
  function setColor(v){ page.focus(); restore(); document.execCommand('foreColor', false, v); snapshot(); update(); notify(); repaginate(); }
  function blockOf(node){
    while (node && node !== page) {
      if (node.nodeType === 1) {
        var t = node.tagName;
        if (t==='P'||t==='DIV'||t==='H1'||t==='H2'||t==='H3'||t==='H4'||t==='LI'||t==='BLOCKQUOTE') return node;
      }
      node = node.parentNode;
    }
    return page;
  }
  function setDir(dir){
    page.focus(); restore();
    var s = window.getSelection();
    var b = s.rangeCount ? blockOf(s.getRangeAt(0).startContainer) : page;
    b.style.direction = dir;
    b.style.textAlign = (dir === 'rtl') ? 'right' : 'left';
    snapshot(); notify(); repaginate();
  }
  // Heading / quote / normal paragraph (formatBlock wraps the whole block).
  function setBlock(tag){ page.focus(); restore(); document.execCommand('formatBlock', false, '<'+tag+'>'); snapshot(); update(); notify(); repaginate(); }
  function clearFmt(){ page.focus(); restore(); document.execCommand('removeFormat'); document.execCommand('unlink'); snapshot(); update(); notify(); repaginate(); }
  function inList(){
    var s = window.getSelection(); if (!s.rangeCount) return false;
    var n = s.anchorNode;
    while (n && n !== page) { if (n.nodeType===1) { var t=n.tagName; if (t==='LI'||t==='UL'||t==='OL') return true; } n = n.parentNode; }
    return false;
  }
  // Indent/outdent: inside a list this nests/un-nests the item; elsewhere it
  // steps the block's start margin (margin-right, since the page is RTL).
  function indent(dir){
    page.focus(); restore();
    if (inList()) {
      document.execCommand(dir > 0 ? 'indent' : 'outdent', false, null);
    } else {
      var s = window.getSelection();
      if (s.rangeCount) {
        var b = blockOf(s.getRangeAt(0).startContainer);
        if (b !== page) {
          var cur = parseInt(b.style.marginRight || '0', 10) || 0;
          cur = Math.max(0, cur + dir * 24);
          b.style.marginRight = cur ? cur + 'px' : '';
        }
      }
    }
    snapshot(); update(); notify(); repaginate();
  }
  // Link: a small in-page URL bar (window.prompt is unreliable in the WebView).
  // The caret/selection is preserved in `saved`, so we restore it before linking.
  function openLink(){
    closeMenus();
    var lb = document.getElementById('linkbar'); lb.classList.add('open');
    var inp = document.getElementById('linkInput'); inp.value = 'https://';
    setTimeout(function(){ inp.focus(); inp.select(); }, 0);
  }
  function cancelLink(){ document.getElementById('linkbar').classList.remove('open'); page.focus(); restore(); }
  function applyLink(){
    var url = document.getElementById('linkInput').value.trim();
    document.getElementById('linkbar').classList.remove('open');
    page.focus(); restore();
    if (!url) return;
    if (!/^(https?:|mailto:)/i.test(url)) url = 'https://' + url;
    var s = window.getSelection();
    if (s.isCollapsed && s.rangeCount) {
      var a = document.createElement('a'); a.href = url; a.textContent = url;
      var rg = s.getRangeAt(0); rg.insertNode(a);
      rg.setStartAfter(a); rg.collapse(true); s.removeAllRanges(); s.addRange(rg);
    } else {
      document.execCommand('createLink', false, url);
    }
    snapshot(); update(); notify(); repaginate();
  }
  // ---- Tables ----
  // A table is ONE block child, so the on-screen paginator can't split one taller
  // than a page (it overflows the sheet); the PDF export, on its CSS paged-media
  // path, DOES split a tall table between rows. Cells are plain contenteditable.
  function insertTable(rows, cols){
    page.focus(); restore();
    var html = '<table>';
    for (var r=0;r<rows;r++){ html += '<tr>'; for (var c=0;c<cols;c++){ html += '<td><br></td>'; } html += '</tr>'; }
    html += '</table><p><br></p>';
    insertHtmlAtCaret(html);
    snapshot(); update(); notify(); repaginate();
  }
  function tgHover(el){
    var R = +el.getAttribute('data-r'), C = +el.getAttribute('data-c');
    var cells = document.querySelectorAll('#tgrid .tgc');
    for (var i=0;i<cells.length;i++){
      var r = +cells[i].getAttribute('data-r'), c = +cells[i].getAttribute('data-c');
      cells[i].classList.toggle('on', r<=R && c<=C);
    }
    document.getElementById('tgLabel').textContent = R + ' × ' + C;
  }
  function curCell(){
    var s = window.getSelection(); if (!s.rangeCount) return null;
    var n = s.anchorNode;
    while (n && n !== page){ if (n.nodeType===1 && (n.tagName==='TD'||n.tagName==='TH')) return n; n = n.parentNode; }
    return null;
  }
  function curTable(){
    var c = curCell(); var n = c;
    while (n && n !== page){ if (n.nodeType===1 && n.tagName==='TABLE') return n; n = n.parentNode; }
    return null;
  }
  function cellIndex(cell){ var tr = cell.parentNode; for (var i=0;i<tr.children.length;i++) if (tr.children[i]===cell) return i; return -1; }
  function placeCaret(el){
    var r = document.createRange(); r.selectNodeContents(el); r.collapse(true);
    var s = window.getSelection(); s.removeAllRanges(); s.addRange(r); saved = r.cloneRange();
  }
  function addRow(){
    restore(); var cell = curCell(); if (!cell) return null;
    var tr = cell.parentNode, cols = tr.children.length;
    var ntr = document.createElement('tr');
    for (var i=0;i<cols;i++){ var td = document.createElement('td'); td.innerHTML = '<br>'; ntr.appendChild(td); }
    tr.parentNode.insertBefore(ntr, tr.nextSibling);
    notify(); repaginate(); return ntr;
  }
  function delRow(){
    restore(); var cell = curCell(); if (!cell) return;
    var table = curTable();
    if (table && table.rows.length <= 1){ delTable(); return; }
    var tr = cell.parentNode; tr.parentNode.removeChild(tr);
    page.focus(); notify(); repaginate();
  }
  function addCol(){
    restore(); var cell = curCell(); if (!cell) return;
    var idx = cellIndex(cell), table = curTable(); if (!table) return;
    var rows = table.rows;
    for (var i=0;i<rows.length;i++){
      var ref = rows[i].cells[idx+1] || null;
      var td = document.createElement('td'); td.innerHTML = '<br>';
      rows[i].insertBefore(td, ref);
    }
    notify(); repaginate();
  }
  function delCol(){
    restore(); var cell = curCell(); if (!cell) return;
    var idx = cellIndex(cell), table = curTable(); if (!table) return;
    if (table.rows[0].cells.length <= 1){ delTable(); return; }
    for (var i=0;i<table.rows.length;i++){ if (table.rows[i].cells[idx]) table.rows[i].deleteCell(idx); }
    page.focus(); notify(); repaginate();
  }
  function delTable(){
    restore(); var t = curTable(); if (!t) return;
    t.parentNode.removeChild(t); page.focus(); snapshot(); notify(); repaginate();
  }
  // Tab / Shift+Tab moves between cells (hardware keyboards); Tab past the last
  // cell appends a row.
  page.addEventListener('keydown', function(e){
    if (e.key !== 'Tab') return;
    var cell = curCell(); if (!cell) return;
    e.preventDefault();
    var t = curTable(); if (!t) return;
    var list = Array.prototype.slice.call(t.querySelectorAll('td,th'));
    var i = list.indexOf(cell), nx = e.shiftKey ? i-1 : i+1;
    if (nx >= 0 && nx < list.length){ placeCaret(list[nx]); }
    else if (!e.shiftKey){ var ntr = addRow(); if (ntr) placeCaret(ntr.cells[0]); }
  });
  function curEl(){
    var s = window.getSelection();
    if (!s.rangeCount) return page;
    var n = s.anchorNode;
    if (n && n.nodeType === 3) n = n.parentElement;
    return (n && page.contains(n)) ? n : page;
  }
  function hex2(n){ n = n.toString(16); return n.length === 1 ? '0' + n : n; }
  function rgbToHex(rgb){
    var m = rgb && rgb.match(/\\d+/g);
    if (!m || m.length < 3) return '#000000';
    return '#' + hex2(+m[0]) + hex2(+m[1]) + hex2(+m[2]);
  }
  function closeMenus(){ var m = document.querySelectorAll('.menu'); for (var i=0;i<m.length;i++) m[i].classList.remove('open'); }
  // Open/close a dropdown, anchoring it under (and right-aligned to) its button,
  // clamped to stay on screen. Fixed positioning means we must place it in JS.
  function toggle(id, btn){
    var el = document.getElementById(id);
    var was = el.classList.contains('open');
    closeMenus();
    if (was) return;
    el.classList.add('open');                 // show first so we can measure it
    var r = btn.getBoundingClientRect();
    var top = r.bottom + 4;
    el.style.maxHeight = (window.innerHeight - top - 10) + 'px';
    var w = el.offsetWidth;
    var left = r.right - w;                    // right-align to the button
    var maxLeft = window.innerWidth - w - 6;
    if (left > maxLeft) left = maxLeft;
    if (left < 6) left = 6;
    el.style.top = top + 'px';
    el.style.left = left + 'px';
  }
  function update(){
    var cmds = ['bold','italic','underline','justifyLeft','justifyCenter','justifyRight','justifyFull'];
    var btns = document.querySelectorAll('[data-cmd]');
    for (var j=0;j<btns.length;j++){ var c = btns[j].getAttribute('data-cmd'); var on=false; try { on = document.queryCommandState(c); } catch(e){} btns[j].classList.toggle('active', on); }
    // Reflect the cursor's actual colour in the toolbar.
    var cs = getComputedStyle(curEl());
    document.getElementById('cbar').style.background = rgbToHex(cs.color);
    // Reflect the cursor's current block style.
    var s = window.getSelection();
    var label = 'Normal';
    if (s.rangeCount) {
      var bt = blockOf(s.getRangeAt(0).startContainer).tagName;
      if (bt==='H1'||bt==='H2'||bt==='H3') label = bt;
      else if (bt==='BLOCKQUOTE') label = 'Quote';
    }
    document.getElementById('styleBtn').textContent = label + ' ▾';
  }
  document.addEventListener('selectionchange', function(){ if (page.contains(window.getSelection().anchorNode)) { snapshot(); update(); } });
  page.addEventListener('input', function(){ notify(); repaginate(); });
  page.addEventListener('pointerdown', closeMenus);
  // Clean body for save/export: strip the layout-only spacers.
  function getBody(){
    var c = page.cloneNode(true);
    var junk = c.querySelectorAll('.tail,.gap,.brk');
    for (var i = 0; i < junk.length; i++) junk[i].remove();
    return c.innerHTML;
  }

  // ---- Smart paste: clean rich text copied from Word / Google Docs / the web. -
  // Pasted HTML carries mso-* junk, device-missing fonts, absolute sizes and deep
  // span soup that break the paginator and the PDF. We parse it into a DETACHED
  // document, keep only an allowlist of tags/attributes, normalise font families
  // (-> bundled families, else dropped so the base Nastaliq applies) and sizes
  // (-> px), drop the rest, then insert clean block HTML at the caret.
  var KEEP = {P:1,BR:1,B:1,I:1,U:1,S:1,SPAN:1,H1:1,H2:1,H3:1,UL:1,OL:1,LI:1,
              BLOCKQUOTE:1,A:1,TABLE:1,THEAD:1,TBODY:1,TR:1,TD:1,TH:1};
  var DROP = {SCRIPT:1,STYLE:1,META:1,LINK:1,TITLE:1,HEAD:1,'O:P':1,IFRAME:1,
              OBJECT:1,EMBED:1,NOSCRIPT:1,IMG:1,SVG:1,INPUT:1,BUTTON:1};
  var RENAME = {STRONG:'B',EM:'I',STRIKE:'S',DEL:'S',H4:'H3',H5:'H3',H6:'H3',
                FONT:'SPAN',DIV:'P'};
  var FONTPX = {'1':10,'2':13,'3':16,'4':18,'5':24,'6':32,'7':48};
  var OKFAMILIES = ['Noto Nastaliq Urdu','Bahij Karim','Bahij Nassim'];

  function blockTag(t){ return /^(P|H1|H2|H3|UL|OL|LI|BLOCKQUOTE|TABLE|THEAD|TBODY|TR|TD|TH)\$/.test(t); }
  function mapFamily(v){
    if(!v) return '';
    var s = v.replace(/["']/g,'').toLowerCase();
    for(var i=0;i<OKFAMILIES.length;i++){ if(s.indexOf(OKFAMILIES[i].toLowerCase())>=0) return OKFAMILIES[i]; }
    return ''; // unknown family -> drop so the editor's base Nastaliq applies
  }
  function sizeToPx(v){
    if(!v) return '';
    var m = String(v).match(/([0-9.]+)\\s*(px|pt|)/i);
    if(!m) return '';
    var n = parseFloat(m[1]); if(!(n>0)) return '';
    if((m[2]||'').toLowerCase()==='pt') n = n*96/72; // pt -> px
    n = Math.round(n); if(n<8) n=8; if(n>96) n=96;
    return n+'px';
  }
  function cleanStyle(el){
    var s = el.style, out = '';
    var fw = s.fontWeight;
    if(fw==='bold'||fw==='bolder'||parseInt(fw,10)>=600) out+='font-weight:bold;';
    if(s.fontStyle==='italic') out+='font-style:italic;';
    var td = s.textDecorationLine||s.textDecoration||'';
    if(td.indexOf('underline')>=0) out+='text-decoration:underline;';
    else if(td.indexOf('line-through')>=0) out+='text-decoration:line-through;';
    if(s.color) out+='color:'+s.color+';';
    var fs = sizeToPx(s.fontSize); if(fs) out+='font-size:'+fs+';';
    var ff = mapFamily(s.fontFamily); if(ff) out+="font-family:'"+ff+"';";
    var ta = s.textAlign;
    if(ta==='left'||ta==='right'||ta==='center'||ta==='justify') out+='text-align:'+ta+';';
    if(s.direction==='ltr'||s.direction==='rtl') out+='direction:'+s.direction+';';
    return out;
  }
  function unwrap(node){
    var p = node.parentNode; if(!p) return;
    while(node.firstChild) p.insertBefore(node.firstChild, node);
    p.removeChild(node);
  }
  function cleanChildren(el){
    var kids = []; for(var i=0;i<el.childNodes.length;i++) kids.push(el.childNodes[i]);
    for(var j=0;j<kids.length;j++) cleanNode(kids[j]);
  }
  function cleanNode(node){
    if(node.nodeType===8){ if(node.parentNode) node.parentNode.removeChild(node); return; } // comment
    if(node.nodeType!==1) return; // text node -> keep
    var tag = node.tagName.toUpperCase();
    if(DROP[tag]){ node.parentNode.removeChild(node); return; }
    if(tag==='FONT'){ // legacy <font> -> translate attrs into style before cleaning
      var col=node.getAttribute('color'); if(col) node.style.color=col;
      var sz=node.getAttribute('size'); if(sz&&FONTPX[sz]) node.style.fontSize=FONTPX[sz]+'px';
      var fc=node.getAttribute('face'); if(fc) node.style.fontFamily=fc;
    }
    cleanChildren(node); // depth-first: descendants are clean before we rebuild
    if(tag==='DIV'){ // a DIV wrapping block content -> just unwrap (P can't hold blocks)
      for(var c=0;c<node.children.length;c++){
        if(blockTag(node.children[c].tagName.toUpperCase())){ unwrap(node); return; }
      }
    }
    var to = RENAME[tag] || (KEEP[tag] ? tag : null);
    if(!to){ unwrap(node); return; } // unknown tag -> keep its (cleaned) children only
    var st = cleanStyle(node);
    if(to==='SPAN' && !st){ unwrap(node); return; } // styleless span soup -> drop wrapper
    var ne = document.createElement(to);
    if(to==='A'){ var h=node.getAttribute('href')||''; if(/^(https?:|mailto:)/i.test(h)) ne.setAttribute('href',h); }
    if(to==='TD'||to==='TH'){
      var csp=node.getAttribute('colspan'), rsp=node.getAttribute('rowspan');
      if(csp) ne.setAttribute('colspan',csp); if(rsp) ne.setAttribute('rowspan',rsp);
    }
    while(node.firstChild) ne.appendChild(node.firstChild);
    if(st) ne.setAttribute('style', st);
    node.parentNode.replaceChild(ne, node);
  }
  function wrapInlines(body){
    var run=null, kids=[];
    for(var i=0;i<body.childNodes.length;i++) kids.push(body.childNodes[i]);
    for(var j=0;j<kids.length;j++){
      var n=kids[j];
      if(n.nodeType===1 && blockTag(n.tagName.toUpperCase())){ run=null; continue; }
      if(n.nodeType===3 && !/\\S/.test(n.nodeValue)){ body.removeChild(n); continue; }
      if(!run){ run=document.createElement('P'); body.insertBefore(run, n); }
      run.appendChild(n);
    }
  }
  // A block counts as "empty" if it carries no visible text (tables, lists and
  // images are never empty). Used to squeeze the blank-line spam that pasted
  // Word / Docs content is full of.
  function isEmptyBlock(el){
    if(el.nodeType!==1) return false;
    var t=el.tagName;
    if(t==='TABLE'||t==='UL'||t==='OL'||t==='IMG'||t==='HR') return false;
    return (el.textContent||'').replace(/\\u00a0/g,' ').trim().length===0;
  }
  // Collapse runs of blank paragraphs to a SINGLE blank, and trim blank blocks
  // at the very start/end -> at most one empty line of spacing between content.
  function minify(body){
    var kids=[]; for(var i=0;i<body.children.length;i++) kids.push(body.children[i]);
    var prevEmpty=false;
    for(var j=0;j<kids.length;j++){
      var empty=isEmptyBlock(kids[j]);
      if(empty && prevEmpty){ body.removeChild(kids[j]); continue; }
      prevEmpty=empty;
    }
    while(body.firstElementChild && isEmptyBlock(body.firstElementChild)) body.removeChild(body.firstElementChild);
    while(body.lastElementChild && isEmptyBlock(body.lastElementChild)) body.removeChild(body.lastElementChild);
  }
  function sanitizeHtml(html){
    var root;
    try { root = new DOMParser().parseFromString(html, 'text/html').body; }
    catch(e){ root = document.createElement('div'); root.innerHTML = html; }
    cleanChildren(root); wrapInlines(root); minify(root);
    return root.innerHTML;
  }
  ${_mdConverterJs()}
  // Apply pasted content (called both by the paste event and by Dart injection).
  function doPaste(clean){
    page.focus(); restore();
    try { insertHtmlAtCaret(clean); } catch(_3){ try { document.execCommand('insertHTML', false, clean); } catch(_4){} }
    snapshot(); update(); notify(); repaginate();
  }
  // Does the cleaned HTML carry real block structure (headings, tables, lists,
  // quotes)? If not, and the plain text looks like Markdown, we recover the
  // structure from the Markdown instead of pasting one flat paragraph.
  function hasRichBlocks(html){ return /<(h[1-6]|table|ul|ol|li|blockquote)\\b/i.test(html); }
  function looksMarkdown(t){
    if(!t) return false;
    if(/(^|\\n)\\s{0,3}(#{1,6}\\s|[-*+]\\s|\\d+[.)]\\s|>\\s)/.test(t)) return true; // headings/lists/quotes
    if(/\\|[^\\n]*\\|/.test(t)) return true;                                       // table row
    if(/\\*\\*[^*]+\\*\\*/.test(t) || /(^|\\s)\\*[^*\\s][^*]*\\*/.test(t)) return true; // bold/italic
    return false;
  }
  // Single entry point called by Dart after it reads the system clipboard.
  // html = the clipboard's rich HTML (Word / Docs / web), text = its plain text
  // (the Markdown an AI app copies). Prefer real rich HTML; otherwise build
  // formatted HTML from the Markdown so headings, lists and tables survive.
  function pasteFromDart(html, text){
    var h = (html||'').trim(), tx = (text||'').trim();
    if(h){
      var clean = sanitizeHtml(h);
      if(!hasRichBlocks(clean) && tx && looksMarkdown(tx)){ doPaste(mdToHtml(tx)); return; }
      if(clean && clean.replace(/<[^>]*>/g,'').trim()){ doPaste(clean); return; }
    }
    if(tx){ doPaste(mdToHtml(tx)); return; }
  }
  // Toolbar "Paste" button: ask Dart to read the system clipboard and inject.
  function pasteFromClipboard(){
    page.focus(); restore();
    try { ClipboardBridge.postMessage(JSON.stringify({html:'', text:''})); } catch(_){}
  }
  page.addEventListener('paste', function(e){
    // The WebView's own clipboardData is unreliable on Android (often empty for
    // text/html, sometimes for text/plain too). So we ALWAYS hand the paste to
    // Dart, which reads the system clipboard natively and injects once. We still
    // capture whatever clipboardData exposed and pass it along as a fallback for
    // the rare case the native read fails. preventDefault stops the browser's
    // own flattened paste.
    e.preventDefault();
    var data = e.clipboardData || window.clipboardData;
    var ehtml = '', etext = '';
    try { if(data){ ehtml = data.getData('text/html')||''; etext = data.getData('text/plain')||''; } } catch(_){}
    try {
      ClipboardBridge.postMessage(JSON.stringify({html: ehtml, text: etext}));
    } catch(_2){
      // No native bridge (e.g. plain browser) — use the event data directly.
      if(ehtml && ehtml.trim()) doPaste(sanitizeHtml(ehtml));
      else if(etext && etext.trim()) doPaste(mdToHtml(etext));
    }
  });

  // ---- Auto-flow: every page is a FIXED-size separate floating white sheet. ----
  var PH = $ph, PAD = $pad, GAP = $gap, SHEETH = $sheetH, STEP = $step;
  var sheets = document.getElementById('sheets');
  function clearAux(){ var b = page.querySelectorAll('.tail,.gap'); for (var i=0;i<b.length;i++) b[i].remove(); }
  function spacer(cls, h){ var d = document.createElement('div'); d.className = cls; d.setAttribute('contenteditable','false'); d.style.height = h + 'px'; return d; }
  function paginate(){
    clearAux();
    var blocks = [];
    for (var i=0;i<page.children.length;i++){ var el = page.children[i]; if (!el.classList.contains('tail') && !el.classList.contains('gap')) blocks.push(el); }
    var GAPH = 2*PAD + GAP;                            // bottom margin + desk gap + top margin
    var used = 0;
    for (var j=0;j<blocks.length;j++){
      var h = blocks[j].offsetHeight;
      // Block won't fit in what's left of this page -> push it to the next page,
      // filling the remaining height (the page's bottom margin) with a spacer.
      if (used > 0 && used + h > PH + 2){
        var fillH = PH - used;
        if (fillH > 0) page.insertBefore(spacer('tail', fillH), blocks[j]);
        page.insertBefore(spacer('gap', GAPH), blocks[j]);
        used = 0;
      }
      used += h;
      // A single block taller than a page can't be split: carry the overflow as
      // the remainder so `used` stays the true position within its last page.
      // The block flows across boundaries; the measured sheet count below always
      // draws enough white paper beneath it (never spills onto the grey desk).
      while (used > PH + 2){ used -= PH; }
    }
    // Fill the last page's bottom margin — but NOT when content ended exactly on
    // a page boundary (used==0), which would add a stray blank page.
    if (used > 0){ var lastFill = PH - used; if (lastFill > 0) page.appendChild(spacer('tail', lastFill)); }
    // Sheet count is driven by the laid-out height (not a running counter), so a
    // block taller than a page always gets enough sheets. +GAP guarantees the
    // last inter-page gap is covered; -2 absorbs sub-pixel rounding.
    var pages = Math.max(1, Math.ceil((page.offsetHeight + GAP - 2) / STEP));
    var html = '';
    for (var k=0;k<pages;k++){
      var top = k*STEP;
      html += '<div class="sheet" style="top:' + top + 'px;height:' + SHEETH + 'px"></div>';
      html += '<div class="snum" style="top:' + (top + SHEETH - 24) + 'px">صفحہ ' + (k+1) + '</div>';
    }
    sheets.innerHTML = html;
  }
  var pTimer = null;
  function repaginate(){ clearTimeout(pTimer); pTimer = setTimeout(paginate, 180); }
  window.addEventListener('load', function(){ setTimeout(paginate, 60); });
  setTimeout(paginate, 80);
</script>
</body>
</html>''';
  }

  /// Exports already-edited body HTML (the editor's `contenteditable` content)
  /// to a real, paginated PDF and saves it. Mirrors [exportPdf] but takes raw
  /// HTML instead of a Quill delta.
  Future<File> exportPdfFromBody({
    required String bodyHtml,
    required String fileName,
    required double contentWidthPx,
    bool border = false,
    double marginMm = 12,
    int linesPerPage = 12,
    double lineHeight = 2.0,
    double fontSizePx = 16,
  }) async {
    final families = <String>{AssignmentFonts.fallbackFamily};
    for (final f in _fontAssets.keys) {
      if (bodyHtml.contains(f)) families.add(f);
    }
    final fontsCss = await _fontFaceCssForFamilies(families);
    final html = _printShell(
      body: bodyHtml,
      fontsCss: fontsCss,
      fontSizePx: fontSizePx,
      lineHeight: lineHeight,
      border: border,
    );

    const milsPerInch = 1000.0;
    const cssPxPerInch = 96.0;
    const mmPerInch = 25.4;
    final marginMils = (marginMm / mmPerInch * milsPerInch).round();
    final widthMils =
        (contentWidthPx / cssPxPerInch * milsPerInch).round() + 2 * marginMils;
    final lineBoxPx = fontSizePx * lineHeight;
    final contentHeightPx = linesPerPage * lineBoxPx + (border ? 16.0 : 0.0) + 1.0;
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
    } catch (_) {}
    return _creator.saveBytesToLibrary(bytes, fileName);
  }

  /// Returns the JavaScript `esc()`, `inlineMd()` and `mdToHtml()` functions
  /// as a raw string so that regex backslash sequences like `\s`, `\d`, `\*`
  /// are preserved verbatim (Dart raw strings don't process `\` as escapes).
  static String _mdConverterJs() {
    // Using r'''...''' so that \s, \d, \*, \1 etc. pass through to the
    // JavaScript output literally, exactly as written.
    return r'''
  function esc(s){ return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }
  function inlineMd(s){
    s = s.replace(/\*\*(.+?)\*\*/g, '<b>$1</b>');
    s = s.replace(/__(.+?)__/g, '<b>$1</b>');
    s = s.replace(/\*(.+?)\*/g, '<i>$1</i>');
    s = s.replace(/(^|\s)_(.+?)_(?=\s|$)/g, '$1<i>$2</i>');
    s = s.replace(/`([^`]+)`/g, '<span style="background:#f3f4f6;padding:0 3px;border-radius:3px;font-family:monospace">$1</span>');
    s = s.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
    return s;
  }
  // Line classifiers. AI apps copy "loose" Markdown with a BLANK line between
  // every row / list item, so each block-gathering loop below tolerates blank
  // lines as long as the next non-blank line continues the same block.
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
      if(!line.trim()){ i++; continue; } // blank line: a block separator -> skip
      // Heading (#..###). Levels 4-6 collapse to h3 (the editor's smallest).
      var hm = line.match(/^\s*(#{1,6})\s+(.+)/);
      if(hm){ var lvl=Math.min(hm[1].length,3); out+='<h'+lvl+'>'+inlineMd(esc(hm[2].trim()))+'</h'+lvl+'>'; i++; continue; }
      // Table: a run of pipe rows, blank lines between rows allowed. First row
      // becomes the header; the |---| separator row is dropped.
      if(mdIsTableRow(line)){
        var rows=[];
        while(i<len){
          if(!lines[i].trim()){ var jn=mdNextContent(lines,i); if(jn<len && mdIsTableRow(lines[jn])){ i=jn; continue; } break; }
          if(!mdIsTableRow(lines[i])) break;
          if(mdIsSep(lines[i])){ i++; continue; }
          var r=lines[i].trim();
          if(r.charAt(0)==='|') r=r.substring(1);
          if(r.charAt(r.length-1)==='|') r=r.substring(0,r.length-1);
          rows.push(r.split('|'));
          i++;
        }
        if(rows.length){
          out+='<table>';
          for(var ri=0;ri<rows.length;ri++){
            out+='<tr>';
            var tag=(ri===0)?'th':'td';
            for(var ci=0;ci<rows[ri].length;ci++) out+='<'+tag+'>'+inlineMd(esc(rows[ri][ci].trim()))+'</'+tag+'>';
            out+='</tr>';
          }
          out+='</table>';
        }
        continue;
      }
      // Horizontal rule (---, ***, ___): no editor element for it -> skip.
      if(/^\s*([-*_])\s*(\1\s*){2,}$/.test(line)){ i++; continue; }
      // Blockquote.
      if(mdIsQuote(line)){
        var bq='';
        while(i<len){
          if(!lines[i].trim()){ var jq=mdNextContent(lines,i); if(jq<len && mdIsQuote(lines[jq])){ i=jq; continue; } break; }
          if(!mdIsQuote(lines[i])) break;
          var qln=lines[i].replace(/^\s*>\s?/,'').trim();
          if(qln) bq+='<p>'+inlineMd(esc(qln))+'</p>';
          i++;
        }
        out+='<blockquote>'+(bq||'<p><br></p>')+'</blockquote>';
        continue;
      }
      // List (bulleted or numbered), kept to one type per <ul>/<ol>.
      if(mdIsList(line)){
        var ordered=mdIsOrdered(line);
        out+= ordered ? '<ol>' : '<ul>';
        while(i<len){
          if(!lines[i].trim()){ var jl=mdNextContent(lines,i); if(jl<len && mdIsList(lines[jl]) && mdIsOrdered(lines[jl])===ordered){ i=jl; continue; } break; }
          if(!mdIsList(lines[i]) || mdIsOrdered(lines[i])!==ordered) break;
          var item=lines[i].replace(/^\s*(?:[-*+]|\d+[.)])\s+/,'').trim();
          out+='<li>'+inlineMd(esc(item))+'</li>';
          i++;
        }
        out+= ordered ? '</ol>' : '</ul>';
        continue;
      }
      // Plain paragraph.
      out+='<p>'+inlineMd(esc(line.trim()))+'</p>';
      i++;
    }
    return out || '<p><br></p>';
  }
''';
  }
}
