import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'assignment_fonts.dart';
import 'pdf_creator_service.dart';

/// Exports a rich-text assignment ([Document]) to a print-ready A4 PDF.
///
/// ## Why render to images instead of writing PDF text?
/// Urdu / Arabic / Pashto — and Nastaliq in particular — need full OpenType
/// shaping (GSUB/GPOS): contextual letter forms, ligatures and dot positioning.
/// Flutter's engine (HarfBuzz) does this, which is why the on-screen editor
/// looks correct. The pure-Dart `pdf` package does NOT shape complex scripts, so
/// emitting the text as PDF glyphs produces broken / "tofu" box output.
///
/// So we render the document with Flutter — exactly as the student sees it —
/// off-screen, capture it one page at a time, and embed those page images into
/// the PDF. Capturing page-by-page (instead of one tall image) keeps every
/// snapshot small, so we never hit a device's max GPU texture size on a long
/// document. Each page breaks on a blank row so a line of text is never sliced
/// in half.
///
/// ## Why the page is NOT A4
/// The page geometry (column width, page height, margin) is passed in from the
/// live editor, so the exported page is the *same page the student writes on*:
/// the text is the same size, lines wrap identically, and every page is the
/// same width and height with a uniform margin on all four sides. The PDF page
/// itself is sized to the content — the image is the page, never an image
/// floated onto a fixed A4 sheet.
class AssignmentPdfService {
  final PdfCreatorService _creator = PdfCreatorService();

  /// Target width (px) of each captured page image. The capture density is
  /// derived from this so even a narrow phone column produces a crisp page.
  static const double _targetImageWidth = 1400;

  /// Capture density is clamped to this range: high enough for crisp Nastaliq
  /// strokes, low enough to stay well under a device's max GPU texture size.
  static const double _minPixelRatio = 2.0;
  static const double _maxPixelRatio = 5.0;

  Future<File> export({
    required OverlayState overlay,
    required Document document,
    required String fontFamily,
    required String fileName,
    required double pageContentWidth,
    required double pageContentHeight,
    required double margin,
    // Draw a frame around the content on every page, with padding inside it.
    bool border = false,
  }) async {
    // Render a private clone so the live editor's document is never touched.
    final deltaJson = document.toDelta().toJson();
    final cloned = deltaJson.isEmpty ? Document() : Document.fromJson(deltaJson);

    final pages = await _capturePages(
      overlay,
      cloned,
      fontFamily,
      pageContentWidth,
      pageContentHeight,
    );
    if (pages.isEmpty) {
      throw Exception('There is nothing to export yet.');
    }
    final bytes = await _buildPdf(
      pages,
      pageContentWidth,
      pageContentHeight,
      margin,
      border,
    );
    return _creator.saveBytesToLibrary(bytes, fileName);
  }

  /// Mounts the off-screen renderer in [overlay] and awaits the captured page
  /// images. [pageContentWidth]/[pageContentHeight] are the editor's content
  /// column size (page minus margins), so the capture wraps text exactly like
  /// the live editor.
  Future<List<Uint8List>> _capturePages(
    OverlayState overlay,
    Document document,
    String fontFamily,
    double pageContentWidth,
    double pageContentHeight,
  ) async {
    final pixelRatio = (_targetImageWidth / pageContentWidth)
        .clamp(_minPixelRatio, _maxPixelRatio);
    final controller = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
    final completer = Completer<List<Uint8List>>();

    final entry = OverlayEntry(
      builder: (_) => Positioned(
        // Far off-screen so it never flashes to the user; still laid out/painted.
        left: -(pageContentWidth + 400),
        top: 0,
        child: _PdfCaptureWidget(
          controller: controller,
          fontFamily: fontFamily,
          pageWidth: pageContentWidth,
          pageHeight: pageContentHeight,
          pixelRatio: pixelRatio,
          onResult: (pages) {
            if (!completer.isCompleted) completer.complete(pages);
          },
          onError: (error, stack) {
            if (!completer.isCompleted) completer.completeError(error, stack);
          },
        ),
      ),
    );

    overlay.insert(entry);
    try {
      return await completer.future;
    } finally {
      entry.remove();
      controller.dispose();
    }
  }

  /// Assembles the captured page images into a PDF whose page is sized to the
  /// content — NOT A4. Each page is [pageContentWidth] × [pageContentHeight]
  /// plus a uniform [margin] on all four sides, so every page is identical in
  /// size and the text appears at exactly the size the student wrote it.
  Future<Uint8List> _buildPdf(
    List<Uint8List> pageImages,
    double pageContentWidth,
    double pageContentHeight,
    double margin,
    bool border,
  ) async {
    final doc = pw.Document();
    // Map logical pixels straight to PDF points; only the ratios matter for an
    // image-backed page, and this keeps the margin fraction identical to the
    // editor (uniform on all four sides).
    final pageFormat = PdfPageFormat(
      pageContentWidth + 2 * margin,
      pageContentHeight + 2 * margin,
      marginAll: margin,
    );
    // Padding between the frame and the text when a border is drawn (~3% of the
    // content width, uniform on all four sides).
    final framePad = pageContentWidth * 0.03;
    for (final png in pageImages) {
      final image = pw.MemoryImage(png);
      // A full page fills the content box exactly; a partly-filled final page
      // sits at the TOP with white below, so all pages stay the same size.
      // NB: pw.Image defaults to alignment:center — without topCenter here a
      // short page's content floats to the middle of the sheet.
      final content = pw.Image(
        image,
        fit: pw.BoxFit.fitWidth,
        alignment: pw.Alignment.topCenter,
      );
      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (_) => border
              // A full-size frame around the content area, with the text padded
              // inside it. Identical on every page.
              ? pw.Container(
                  width: pageContentWidth,
                  height: pageContentHeight,
                  padding: pw.EdgeInsets.all(framePad),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: PdfColors.grey700,
                      width: 1.2,
                    ),
                  ),
                  child: content,
                )
              : content,
        ),
      );
    }
    return doc.save();
  }
}

// ---------------------------------------------------------------------------
// Off-screen page renderer
// ---------------------------------------------------------------------------

/// Renders [controller]'s document off-screen and snapshots it one page at a
/// time, reporting the encoded page PNGs through [onResult].
class _PdfCaptureWidget extends StatefulWidget {
  final QuillController controller;
  final String fontFamily;
  final double pageWidth;
  final double pageHeight;
  final double pixelRatio;
  final ValueChanged<List<Uint8List>> onResult;
  final void Function(Object error, StackTrace stack) onError;

  const _PdfCaptureWidget({
    required this.controller,
    required this.fontFamily,
    required this.pageWidth,
    required this.pageHeight,
    required this.pixelRatio,
    required this.onResult,
    required this.onError,
  });

  @override
  State<_PdfCaptureWidget> createState() => _PdfCaptureWidgetState();
}

class _PdfCaptureWidgetState extends State<_PdfCaptureWidget> {
  final GlobalKey _boundaryKey = GlobalKey();
  final GlobalKey _contentKey = GlobalKey();

  /// Logical pixels already consumed from the top of the document.
  double _offset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    try {
      // Let the editor finish its initial (full-height) layout.
      await WidgetsBinding.instance.endOfFrame;
      final content =
          _contentKey.currentContext?.findRenderObject() as RenderBox?;
      final totalHeight = content?.size.height ?? 0;
      final pr = widget.pixelRatio;

      // A pixel darker than this counts as text "ink" when finding line breaks.
      const inkThreshold = 235;

      final pages = <Uint8List>[];
      var consumed = 0.0;
      var guard = 0;
      while (consumed < totalHeight - 0.5 && guard < 300) {
        guard++;
        if (_offset != consumed) {
          setState(() => _offset = consumed);
        }
        // Two frames: apply the translate, then guarantee it is painted.
        await WidgetsBinding.instance.endOfFrame;
        await WidgetsBinding.instance.endOfFrame;

        final boundary = _boundaryKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: pr);
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final width = image.width;
        final height = image.height;
        image.dispose();
        if (byteData == null) {
          throw Exception('Failed to read a rendered page.');
        }

        final isLast = consumed + widget.pageHeight >= totalHeight;
        final remainingPx = ((totalHeight - consumed) * pr).round();

        final result = await compute(
          _processPage,
          _PageJob(
            rgba: byteData.buffer.asUint8List(),
            width: width,
            height: height,
            isLast: isLast,
            remainingPx: remainingPx,
            inkThreshold: inkThreshold,
          ),
        );

        pages.add(result.png);
        final advanced = result.cutPx / pr;
        // Always move forward so the loop can never get stuck.
        consumed += advanced <= 0 ? widget.pageHeight : advanced;
      }

      widget.onResult(pages);
    } catch (error, stack) {
      widget.onError(error, stack);
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.light();
    return Material(
      type: MaterialType.transparency,
      child: RepaintBoundary(
        key: _boundaryKey,
        child: Container(
          width: widget.pageWidth,
          height: widget.pageHeight,
          // Paper background; also makes inter-line gaps detectable as blank.
          color: Colors.white,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: 0,
              maxHeight: double.infinity,
              child: Transform.translate(
                offset: Offset(0, -_offset),
                child: SizedBox(
                  key: _contentKey,
                  width: widget.pageWidth,
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Theme(
                      data: base.copyWith(
                        // Pure-black default text (Material's default is a soft
                        // near-black). Per-run colours in the document override.
                        textTheme: base.textTheme.apply(
                          fontFamily: widget.fontFamily,
                          bodyColor: Colors.black,
                          displayColor: Colors.black,
                        ),
                      ),
                      child: QuillEditor.basic(
                        controller: widget.controller,
                        config: QuillEditorConfig(
                          scrollable: false,
                          expands: false,
                          autoFocus: false,
                          showCursor: false,
                          enableInteractiveSelection: false,
                          padding: EdgeInsets.zero,
                          // Same Nastaliq line height as the live editor, so the
                          // PDF wraps and spaces lines identically.
                          customStyles: AssignmentFonts.quillStyles(
                            fontFamily: widget.fontFamily,
                            lineHeight:
                                AssignmentFonts.byFamily(widget.fontFamily)
                                    .lineHeight,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Background-isolate page processing
// ---------------------------------------------------------------------------

/// One captured page window handed to the background isolate for cutting and
/// PNG encoding.
class _PageJob {
  final Uint8List rgba; // raw RGBA bytes of the captured window
  final int width;
  final int height;
  final bool isLast;
  final int remainingPx; // content pixels left (used for the final page)
  final int inkThreshold; // a pixel darker than this counts as text "ink"

  const _PageJob({
    required this.rgba,
    required this.width,
    required this.height,
    required this.isLast,
    required this.remainingPx,
    required this.inkThreshold,
  });
}

class _PageResult {
  final Uint8List png;
  final int cutPx; // where this page was cut, in pixels

  const _PageResult(this.png, this.cutPx);
}

/// Runs in a background isolate: decides where to cut this page, crops to it and
/// encodes the page as PNG.
///
/// For non-final pages it detects the text lines and breaks just ABOVE the line
/// that the window's bottom edge would slice — keeping every line that fits, so
/// each page is filled as much as possible without splitting a line.
///
/// Finally every page gets a few pixels of white "bleed" on all four sides so
/// the embedded image never paints a hairline border in the PDF and no glyph
/// sits exactly on the page edge.
_PageResult _processPage(_PageJob job) {
  final full = img.Image.fromBytes(
    width: job.width,
    height: job.height,
    bytes: job.rgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );

  int cut;
  if (job.isLast) {
    cut = job.remainingPx.clamp(1, job.height);
  } else {
    cut = _findBreak(full, job.inkThreshold);
  }

  final content = cut >= job.height
      ? full
      : img.copyCrop(full, x: 0, y: 0, width: job.width, height: cut);

  // White bleed: ~1% of the page width on every side (clamped to a sane range).
  final pad = (job.width * 0.01).round().clamp(3, 14);
  final page = img.Image(
    width: content.width + 2 * pad,
    height: content.height + 2 * pad,
    numChannels: 4,
  );
  img.fill(page, color: img.ColorRgba8(255, 255, 255, 255));
  img.compositeImage(page, content, dstX: pad, dstY: pad);

  // Report the content cut (not the padded height) so the loop advances by the
  // pixels actually consumed from the document.
  return _PageResult(Uint8List.fromList(img.encodePng(page, level: 6)), cut);
}

/// Chooses the row to cut a (non-final) page at so the page is filled as much
/// as possible WITHOUT splitting a line.
///
/// It detects the text lines (merging the small sub-gaps inside a Nastaliq line)
/// and breaks just above the line the window's bottom edge would slice — i.e. it
/// keeps every line that fits completely. This is what stops pages ending early
/// with a big empty band at the bottom.
int _findBreak(img.Image image, int inkThreshold) {
  final height = image.height;
  final lines = _detectLineBands(image, inkThreshold);
  if (lines.isEmpty) return height; // blank window — nothing to protect

  final last = lines.last;
  // Clear blank space below the last line ⇒ content ended inside this window;
  // keep all of it (also covers the rare non-`isLast` short window).
  if (last[1] < height - 2) return height;

  // The last line touches the bottom edge ⇒ it's sliced; break above it.
  if (lines.length == 1) return height; // one line fills the window; unavoidable
  final prev = lines[lines.length - 2];
  return (((prev[1] + last[0]) / 2).round()).clamp(1, height);
}

/// Detects horizontal text-line bands in [image] as `[topY, bottomY]` pairs,
/// merging bands separated only by a small gap (the dots/diacritics of one
/// Nastaliq line) so each entry is one whole line of writing.
List<List<int>> _detectLineBands(img.Image image, int inkThreshold) {
  final w = image.width;
  final h = image.height;
  final samples = (w / 4).ceil();
  // Tolerate a few stray pixels (a lone dot) without calling a row "text".
  final allowance = (samples * 0.012).round();

  final bands = <List<int>>[];
  int? start;
  for (var y = 0; y < h; y++) {
    final on = _rowInk(image, y, inkThreshold) > allowance;
    if (on && start == null) {
      start = y;
    } else if (!on && start != null) {
      bands.add([start, y - 1]);
      start = null;
    }
  }
  if (start != null) bands.add([start, h - 1]);

  final lines = <List<int>>[];
  for (final b in bands) {
    if (lines.isEmpty) {
      lines.add([b[0], b[1]]);
      continue;
    }
    final prev = lines.last;
    final gap = b[0] - prev[1] - 1;
    final prevH = prev[1] - prev[0] + 1;
    if (gap < prevH * 0.45) {
      prev[1] = b[1]; // same line's dots/diacritics — merge
    } else {
      lines.add([b[0], b[1]]);
    }
  }
  return lines;
}

/// Counts the (sampled) pixels in row [y] darker than [threshold] — a cheap
/// measure of how much text sits on that row.
int _rowInk(img.Image image, int y, int threshold) {
  const step = 4;
  var count = 0;
  for (var x = 0; x < image.width; x += step) {
    final p = image.getPixel(x, y);
    if (p.r < threshold || p.g < threshold || p.b < threshold) count++;
  }
  return count;
}

