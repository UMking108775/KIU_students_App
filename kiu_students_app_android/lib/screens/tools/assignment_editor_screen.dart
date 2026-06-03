import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
// intl exports its own bidi TextDirection; hide it so Flutter's (used by
// Directionality) resolves correctly.
import 'package:intl/intl.dart' hide TextDirection;
import '../../config/app_theme.dart';
import '../../services/assignment_draft_service.dart';
import '../../services/assignment_fonts.dart';
import '../../services/assignment_html_service.dart';
import '../../services/assignment_pdf_service.dart';
import 'html_preview_screen.dart';
import 'pdf_result_screen.dart';

enum _ExitChoice { save, discard, cancel }

/// MS-Word-style rich text editor for writing assignments in Urdu (RTL).
/// Supports bold/italic/underline/colour/alignment/lists, saves drafts, and
/// exports to a print-ready A4 PDF.
class AssignmentEditorScreen extends StatefulWidget {
  /// An existing draft to open, or null to start a new document.
  final AssignmentDraft? draft;

  const AssignmentEditorScreen({super.key, this.draft});

  @override
  State<AssignmentEditorScreen> createState() => _AssignmentEditorScreenState();
}

class _AssignmentEditorScreenState extends State<AssignmentEditorScreen> {
  final AssignmentDraftService _draftService = AssignmentDraftService();
  final AssignmentPdfService _pdfService = AssignmentPdfService();
  final AssignmentHtmlService _htmlService = AssignmentHtmlService();

  late final QuillController _controller;
  // Drives the page-break guides: we read its offset to position each guide as
  // the document scrolls.
  final ScrollController _scrollController = ScrollController();
  late String _id;
  late String _title;
  late DateTime _createdAt;

  bool _dirty = false;
  bool _exporting = false;

  /// Live geometry of the on-screen page (logical px), recorded each layout so
  /// the exported PDF page can be the *same* page the student writes on:
  /// content column size and a uniform margin on all four sides.
  double _pageContentWidth = 0;
  double _pageContentHeight = 0;
  double _pageMargin = 0;

  /// Preset header students can drop in at the top of a new assignment.
  /// A plain hyphen rule is used for the divider (Nastaliq fonts often lack
  /// box-drawing glyphs, which would render as empty boxes).
  static const String _headerTemplate = 'نام: \n'
      'اسائمنٹ: \n'
      'رولنمبر: \n'
      'سمسٹر: \n'
      'جامعہ معرفہ العالمیہ، ریاض، سعودی عرب\n'
      '----------------------------------------\n';

  @override
  void initState() {
    super.initState();
    // Paste text from other apps as PLAIN text so it adopts this document's
    // font and (Nastaliq) line height. Rich paste dragged in foreign
    // line-height / font-size attributes, which made the spacing inconsistent.
    // `onPlainTextPaste` also strips the extra blank lines that otherwise show
    // up as big gaps (each empty line is a full 2.0-height Nastaliq line).
    final controllerConfig = QuillControllerConfig(
      clipboardConfig: QuillClipboardConfig(
        enableExternalRichPaste: false,
        onPlainTextPaste: (text) async => _stripExtraEmptyLines(text),
      ),
    );

    final draft = widget.draft;
    if (draft != null) {
      _id = draft.id;
      _title = draft.title;
      _createdAt = draft.createdAt;
      _controller = QuillController(
        document: draft.delta.isEmpty
            ? Document()
            : Document.fromJson(draft.delta),
        selection: const TextSelection.collapsed(offset: 0),
        config: controllerConfig,
      );
    } else {
      _id = _draftService.newId();
      _title = 'Assignment ${DateFormat('yyyy-MM-dd').format(DateTime.now())}';
      _createdAt = DateTime.now();
      _controller = QuillController.basic(config: controllerConfig);
    }
    _controller.addListener(_onChanged);
    // Once the editor has laid out, its scroll position is attached and we know
    // the document height — rebuild so the page-break guides paint immediately
    // (before the user scrolls).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _onChanged() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _persist() async {
    final draft = AssignmentDraft(
      id: _id,
      title: _title,
      delta: _controller.document.toDelta().toJson(),
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
    );
    await _draftService.save(draft);
    if (mounted) setState(() => _dirty = false);
  }

  /// Inserts the assignment header preset at the top of the document.
  void _insertHeaderTemplate() {
    _controller.replaceText(
      0,
      0,
      _headerTemplate,
      const TextSelection.collapsed(offset: 0),
    );
    // Scroll back to the top so the freshly added header is visible.
    _controller.moveCursorToStart();
  }

  Future<void> _saveButton() async {
    await _persist();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Saved'),
          backgroundColor: AppColors.of(context).success,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: _title);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Document name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Title'),
          onSubmitted: (v) => Navigator.pop(dialogContext, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      setState(() {
        _title = name.trim();
        _dirty = true;
      });
    }
  }

  /// Asks how the PDF should look. Returns null if the student cancels, else
  /// whether to draw a page border.
  Future<bool?> _askExportOptions() {
    var border = false;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Export to PDF'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: border,
                onChanged: (v) => setLocal(() => border = v),
                title: const Text('Page border'),
                subtitle: const Text(
                  'A frame around the content on every page, with padding.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, border),
              child: const Text('Export'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    // Capture the overlay before any await; the PDF renderer mounts an
    // off-screen page into it to snapshot the document.
    final overlay = Overlay.of(context);
    final border = await _askExportOptions();
    if (border == null || !mounted) return; // cancelled
    await _persist(); // never lose work before a long operation
    if (!mounted) return;
    setState(() => _exporting = true);
    try {
      File file;
      try {
        // Preferred: real, paginated, selectable-text PDF rendered by the
        // browser engine (correct Urdu/Pashto shaping, proper page breaks).
        // Use the SAME text-column width and margin as the writer sheet, so the
        // PDF wraps, sizes and spaces exactly like the editor. Fall back to the
        // device width if the page hasn't been measured yet.
        final mq = MediaQuery.of(context).size.width;
        final contentWidthPx = _pageContentWidth > 0 ? _pageContentWidth : mq;
        final marginPx = _pageMargin > 0 ? _pageMargin : contentWidthPx * 0.095;
        file = await _htmlService.exportPdf(
          delta: _controller.document.toDelta().toJson(),
          fileName: _title,
          border: border,
          contentWidthPx: contentWidthPx,
          marginMm: marginPx / 96.0 * 25.4, // logical px → mm
        );
      } catch (_) {
        // Fallback: the older image-based exporter, always available offline.
        file = await _exportImagePdf(overlay, border);
      }
      if (!mounted) return;
      setState(() => _exporting = false);
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PdfResultScreen(file: file)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _exporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not export the PDF.\n\n($e)'),
          backgroundColor: AppColors.of(context).error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// Older image-based export (screenshot the rendered editor, slice into
  /// pages). Kept as a fallback if the browser print path is unavailable.
  Future<File> _exportImagePdf(OverlayState overlay, bool border) {
    // Fall back to an A4-proportioned page if the editor hasn't laid out yet.
    final contentWidth = _pageContentWidth > 0 ? _pageContentWidth : 360.0;
    final margin = _pageMargin > 0 ? _pageMargin : contentWidth * (20.0 / 170.0);
    final contentHeight =
        _pageContentHeight > 0 ? _pageContentHeight : contentWidth * (257 / 170);
    return _pdfService.export(
      overlay: overlay,
      document: _controller.document,
      fontFamily: AssignmentFonts.fallbackFamily,
      fileName: _title,
      pageContentWidth: contentWidth,
      pageContentHeight: contentHeight,
      margin: margin,
      border: border,
    );
  }

  /// Renders the document as HTML in a WebView (browser engine) — the prototype
  /// for the upcoming browser-based PDF export. Lets us verify Nastaliq shaping,
  /// embedded fonts and formatting before wiring print-to-PDF.
  Future<void> _previewHtml() async {
    await _persist();
    if (!mounted) return;
    setState(() => _exporting = true);
    try {
      final html = await _htmlService.buildHtml(
        delta: _controller.document.toDelta().toJson(),
      );
      if (!mounted) return;
      setState(() => _exporting = false);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HtmlPreviewScreen(html: html, title: _title),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _exporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not build the preview.\n\n($e)'),
          backgroundColor: AppColors.of(context).error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<_ExitChoice> _confirmExit() async {
    if (!_dirty) return _ExitChoice.discard;
    final choice = await showDialog<_ExitChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save changes?'),
        content: const Text(
          'Do you want to save this assignment before leaving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _ExitChoice.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.of(context).error,
            ),
            onPressed: () => Navigator.pop(dialogContext, _ExitChoice.discard),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, _ExitChoice.save),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return choice ?? _ExitChoice.cancel;
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    const desk = Color(0xFFE5E7EB); // grey "desk" behind the page

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final choice = await _confirmExit();
        if (choice == _ExitChoice.cancel) return;
        if (choice == _ExitChoice.save) await _persist();
        navigator.pop();
      },
      child: Scaffold(
        backgroundColor: desk,
        appBar: AppBar(
          title: InkWell(
            onTap: _rename,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.edit_outlined, size: 16),
              ],
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Save',
              onPressed: _dirty ? _saveButton : null,
              icon: const Icon(Icons.save_outlined),
            ),
            IconButton(
              tooltip: 'HTML preview (beta)',
              onPressed: _exporting ? null : _previewHtml,
              icon: const Icon(Icons.web_outlined),
            ),
            IconButton(
              tooltip: 'Export to PDF',
              onPressed: _exporting ? null : _exportPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                _buildToolbar(colors),
                Divider(height: 1, color: colors.border),
                Expanded(child: _buildPage(desk, colors)),
              ],
            ),
            if (_exporting) _buildExportingOverlay(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(ThemeColors colors) {
    return Container(
      color: colors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1 (top) — rarely used: undo/redo, clear, direction, quote,
          // indent, link, and the assignment-header preset.
          QuillSimpleToolbar(
            controller: _controller,
            config: QuillSimpleToolbarConfig(
              multiRowsDisplay: false,
              axis: Axis.horizontal,
              showDividers: true,
              showUndo: true,
              showRedo: true,
              showClearFormat: true,
              showDirection: true,
              showQuote: true,
              showIndent: true,
              showLink: true,
              // Line height is fixed (2.0) for consistent pagination — the
              // student only changes font size, not line spacing.
              showLineHeightButton: false,
              // Everything that lives on the main (second) row:
              showFontFamily: false,
              showFontSize: false,
              showBoldButton: false,
              showItalicButton: false,
              showUnderLineButton: false,
              showStrikeThrough: false,
              showInlineCode: false,
              showColorButton: false,
              showBackgroundColorButton: false,
              showAlignmentButtons: false,
              showLeftAlignment: false,
              showCenterAlignment: false,
              showRightAlignment: false,
              showJustifyAlignment: false,
              showHeaderStyle: false,
              showListNumbers: false,
              showListBullets: false,
              showListCheck: false,
              showCodeBlock: false,
              showSearchButton: false,
              showSubscript: false,
              showSuperscript: false,
              showClipboardCopy: false,
              showClipboardCut: false,
              showClipboardPaste: false,
              showSmallButton: false,
              customButtons: [
                QuillToolbarCustomButtonOptions(
                  icon: const Icon(Icons.post_add, size: 22),
                  tooltip: 'Insert assignment header',
                  onPressed: _insertHeaderTemplate,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          // Row 2 (bottom) — main formatting: font, size, styles, colours,
          // alignment, lists, and headings.
          QuillSimpleToolbar(
            controller: _controller,
            config: const QuillSimpleToolbarConfig(
              multiRowsDisplay: false,
              axis: Axis.horizontal,
              showDividers: true,
              showFontFamily: true,
              buttonOptions: QuillSimpleToolbarButtonOptions(
                fontFamily: QuillToolbarFontFamilyButtonOptions(
                  items: AssignmentFonts.toolbarItems,
                  defaultDisplayText: 'Font',
                ),
              ),
              showFontSize: true,
              showBoldButton: true,
              showItalicButton: true,
              showUnderLineButton: true,
              showStrikeThrough: true,
              showColorButton: true,
              showBackgroundColorButton: true,
              showAlignmentButtons: true,
              showLeftAlignment: true,
              showCenterAlignment: true,
              showRightAlignment: true,
              showJustifyAlignment: true,
              showHeaderStyle: true,
              showListNumbers: true,
              showListBullets: true,
              // Hidden here (they live on the first row):
              showUndo: false,
              showRedo: false,
              showClearFormat: false,
              showDirection: false,
              showQuote: false,
              showIndent: false,
              showLink: false,
              showInlineCode: false,
              showListCheck: false,
              showCodeBlock: false,
              showSearchButton: false,
              showSubscript: false,
              showSuperscript: false,
              showClipboardCopy: false,
              showClipboardCut: false,
              showClipboardPaste: false,
              showSmallButton: false,
              showLineHeightButton: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(Color desk, ThemeColors colors) {
    // Hide the page-break guides while the keyboard is up: they repaint every
    // frame as the keyboard animates and the editor reflows, which read as
    // flicker/shake. They're only useful when reviewing/scrolling anyway.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Container(
      color: desk,
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Make the white sheet look like an A4 page: cap its width on wide
          // screens and use the SAME margin proportion as the exported PDF
          // (20 mm on a 210 mm-wide page), so the editor ≈ the PDF.
          final sheetWidth = constraints.maxWidth.clamp(280.0, 820.0).toDouble();
          final margin = sheetWidth * (20.0 / 210.0);
          // Record this page's geometry so an export reproduces the same page
          // the student writes on. Page HEIGHT is derived from the width at the
          // A4 content ratio (170 mm × 257 mm) — a STABLE value. (It used to be
          // one screenful, but that changed when the keyboard opened, which made
          // the page model — and the break guides — jump around.)
          _pageContentWidth = sheetWidth - 2 * margin;
          _pageContentHeight = _pageContentWidth * (257.0 / 170.0);
          _pageMargin = margin;
          final pageH = _pageContentHeight;
          return Center(
            child: SizedBox(
              width: sheetWidth,
              height: constraints.maxHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(margin),
                child: Stack(
                  children: [
                    // Page-break guides sit BEHIND the text (painted first) so
                    // they never float on top of it, and they scroll with the
                    // content via the shared scroll controller. Hidden while the
                    // keyboard is open to avoid flicker during reflow.
                    if (!keyboardOpen)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: _PageBreakGuides(
                            scrollController: _scrollController,
                            pageHeight: pageH,
                          ),
                        ),
                      ),
                    Directionality(
                  textDirection: TextDirection.rtl,
                  // Light theme + pure-black text + default local font so the
                  // page matches the exported PDF (which renders the same way).
                  child: Theme(
                    data: ThemeData.light().copyWith(
                      textTheme: ThemeData.light().textTheme.apply(
                            fontFamily: AssignmentFonts.fallbackFamily,
                            bodyColor: Colors.black,
                            displayColor: Colors.black,
                          ),
                      colorScheme:
                          ColorScheme.fromSeed(seedColor: colors.primary),
                    ),
                    child: QuillEditor.basic(
                      controller: _controller,
                      scrollController: _scrollController,
                      config: QuillEditorConfig(
                        placeholder: 'یہاں اپنی اسائنمنٹ لکھیں…',
                        padding: EdgeInsets.zero,
                        expands: true,
                        scrollable: true,
                        autoFocus: false,
                        // Generous Nastaliq line height so tall Urdu lines do
                        // not collide; identical to the exported PDF.
                        customStyles: AssignmentFonts.quillStyles(
                          fontFamily: AssignmentFonts.fallbackFamily,
                          lineHeight: AssignmentFonts.fallback.lineHeight,
                        ),
                        // Show the zoom loupe while dragging a selection handle.
                        quillMagnifierBuilder: defaultQuillMagnifierBuilder,
                      ),
                    ),
                  ),
                ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExportingOverlay(ThemeColors colors) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: colors.primary),
                const SizedBox(height: 16),
                Text(
                  'Creating PDF…',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cleans pasted plain text: normalises line endings, trims trailing spaces,
/// collapses runs of blank lines down to a single one, and drops leading/
/// trailing blank lines — so pasted text doesn't bring in big empty gaps (each
/// blank line is a full-height Nastaliq line).
String _stripExtraEmptyLines(String input) {
  final normalized = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final out = <String>[];
  var prevBlank = false;
  for (final raw in normalized.split('\n')) {
    final line = raw.trimRight();
    final blank = line.trim().isEmpty;
    if (blank && prevBlank) continue; // skip extra consecutive blank lines
    out.add(blank ? '' : line);
    prevBlank = blank;
  }
  while (out.isNotEmpty && out.first.trim().isEmpty) {
    out.removeAt(0);
  }
  while (out.isNotEmpty && out.last.trim().isEmpty) {
    out.removeLast();
  }
  return out.join('\n');
}

/// Draws MS-Word-style page-break guides over the editor: a dashed line plus a
/// small "Page N" pill at every [pageHeight] of document content, repositioned
/// as the document scrolls. Purely visual — the lines mark roughly where the
/// exported PDF breaks; they do not reflow the text.
class _PageBreakGuides extends StatelessWidget {
  final ScrollController scrollController;
  final double pageHeight;

  const _PageBreakGuides({
    required this.scrollController,
    required this.pageHeight,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: scrollController,
      builder: (context, _) {
        final position =
            scrollController.hasClients ? scrollController.position : null;
        final offset = position?.pixels ?? 0.0;
        // Total document height = what's scrolled past + what's on screen.
        final contentHeight = position != null
            ? position.maxScrollExtent + position.viewportDimension
            : 0.0;
        return CustomPaint(
          painter: _PageBreakPainter(
            scrollOffset: offset,
            pageHeight: pageHeight,
            contentHeight: contentHeight,
          ),
        );
      },
    );
  }
}

class _PageBreakPainter extends CustomPainter {
  final double scrollOffset;
  final double pageHeight;

  /// Total height of the document content; boundaries beyond it aren't drawn.
  final double contentHeight;

  _PageBreakPainter({
    required this.scrollOffset,
    required this.pageHeight,
    required this.contentHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pageHeight <= 0) return;

    // A soft grey band + crisp line reads like a real page separation.
    final band = Paint()..color = const Color(0x0F000000); // faint shade
    final line = Paint()
      ..color = const Color(0x33000000)
      ..strokeWidth = 1.0;
    const bandHeight = 10.0;

    var boundary = pageHeight;
    var page = 2; // the boundary at 1×pageHeight starts page 2
    while (boundary < contentHeight) {
      final y = boundary - scrollOffset;
      if (y > size.height) break;
      if (y >= 0) {
        canvas.drawRect(
          Rect.fromLTWH(0, y - bandHeight / 2, size.width, bandHeight),
          band,
        );
        canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
        _paintLabel(canvas, size, y, page);
      }
      boundary += pageHeight;
      page++;
      if (page > 500) break; // safety
    }
  }

  void _paintLabel(Canvas canvas, Size size, double y, int page) {
    final tp = TextPainter(
      text: TextSpan(
        text: 'صفحہ $page',
        style: const TextStyle(
          color: Color(0xFF6B7280), // neutral grey
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();

    const padX = 7.0;
    const padY = 2.0;
    final pillW = tp.width + padX * 2;
    final pillH = tp.height + padY * 2;
    // Centre the pill on the break line, horizontally centred on the page.
    final left = (size.width - pillW) / 2;
    final rect = Rect.fromLTWH(left, y - pillH / 2, pillW, pillH);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(9));
    canvas.drawRRect(rrect, Paint()..color = const Color(0xFFEFF1F4));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0x22000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    tp.paint(canvas, Offset(left + padX, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(_PageBreakPainter old) =>
      old.scrollOffset != scrollOffset ||
      old.pageHeight != pageHeight ||
      old.contentHeight != contentHeight;
}
