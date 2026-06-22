import 'dart:convert';

/// The single source of truth for the assignment page's geometry.
///
/// CRITICAL: the on-screen editor AND the exported PDF are both built from the
/// SAME instance of this class, so the text column width, page margins, font
/// size, line height and lines-per-page are byte-for-byte identical. This is
/// what makes the PDF match the editor exactly — earlier the editor used a
/// narrow column (screen − padding) while the export used the full screen
/// width, so every line wrapped differently and the pages never matched.
///
/// All values are CSS pixels (which equal Flutter logical pixels / dp, so the
/// Dart side can compute them from `MediaQuery` and the WebView renders them at
/// the same scale).
class AssignmentGeometry {
  /// Base body font size in CSS px.
  final double fontSizePx;

  /// Line-height multiplier for the base font.
  final double lineHeight;

  /// How many base lines fit in one page's content area (the page height).
  final int linesPerPage;

  /// Uniform inner page margin (padding) in CSS px, on all four sides.
  final double marginPx;

  /// The sheet's outer width in CSS px (content column + 2 × margin).
  final double pageWidthPx;

  const AssignmentGeometry({
    required this.pageWidthPx,
    this.fontSizePx = 12,
    this.lineHeight = 2.0,
    this.linesPerPage = 18,
    this.marginPx = 36,
  });

  /// A little under half a line of slack added to the page content height.
  /// Without it a full page of lines would exactly equal the capacity, and
  /// sub-pixel rounding differences between the editor's `offsetHeight` and the
  /// PDF's print layout could spill the last line onto the next page in the PDF
  /// (making "some pages short"). The slack is identical in the editor and the
  /// PDF, so the page SIZE stays the same in both.
  double get _slackPx => fontSizePx * lineHeight * 0.45;

  /// Width of the text column (where the text actually wraps).
  double get contentWidthPx => pageWidthPx - 2 * marginPx;

  /// Height of the content area of one page (the writable area). Rounded to a
  /// whole pixel so the editor sheet height and the (rounded) native PDF page
  /// height match exactly — a fractional height would make the `.page` box a
  /// fraction taller than the printable area and spawn stray blank pages.
  double get contentHeightPx =>
      (linesPerPage * fontSizePx * lineHeight + _slackPx).roundToDouble();

  /// The full sheet height (content area + 2 × margin).
  double get sheetHeightPx => contentHeightPx + 2 * marginPx;

  /// Grey "desk" gap drawn between consecutive sheets in the editor.
  static const double deskGap = 22;

  /// Builds the geometry for a given device screen width. A small desk margin
  /// is left on each side so the sheet reads like a page floating on a desk.
  /// [screenWidthPx] is the logical/CSS width (e.g. `MediaQuery.size.width`).
  factory AssignmentGeometry.forScreen(
    double screenWidthPx, {
    double fontSizePx = 12,
    double lineHeight = 2.0,
    int linesPerPage = 18,
    double marginPx = 36,
  }) {
    // 10px desk on each side (matches the editor's scroller padding). Clamp so
    // the sheet is sane on tiny and very wide (tablet/landscape) screens.
    // Rounded to a whole pixel so the editor and the (rounded) native PDF page
    // width are identical.
    final pageWidth = (screenWidthPx - 20).clamp(280.0, 760.0).roundToDouble();
    return AssignmentGeometry(
      pageWidthPx: pageWidth,
      fontSizePx: fontSizePx,
      lineHeight: lineHeight,
      linesPerPage: linesPerPage,
      marginPx: marginPx,
    );
  }

  AssignmentGeometry copyWith({
    double? fontSizePx,
    double? lineHeight,
    int? linesPerPage,
    double? marginPx,
    double? pageWidthPx,
  }) {
    return AssignmentGeometry(
      pageWidthPx: pageWidthPx ?? this.pageWidthPx,
      fontSizePx: fontSizePx ?? this.fontSizePx,
      lineHeight: lineHeight ?? this.lineHeight,
      linesPerPage: linesPerPage ?? this.linesPerPage,
      marginPx: marginPx ?? this.marginPx,
    );
  }

  /// A JSON object the editor's JavaScript reads as `window.GEO` so the JS
  /// paginator uses the exact same numbers as Dart.
  String toJsConfig() => jsonEncode({
        'font': fontSizePx,
        'lh': lineHeight,
        'lpp': linesPerPage,
        'pad': marginPx,
        'pageW': pageWidthPx,
        'contentW': contentWidthPx,
        'ph': contentHeightPx,
        'sheetH': sheetHeightPx,
        'gap': deskGap,
        'step': sheetHeightPx + deskGap,
      });
}

/// Named margin presets offered in the page-setup dialog (in CSS px).
enum AssignmentMargin {
  narrow('Narrow', 18),
  normal('Normal', 36),
  wide('Wide', 54);

  const AssignmentMargin(this.label, this.px);
  final String label;
  final double px;

  /// Margins in px, usable as `const` default values.
  static const double narrowPx = 18;
  static const double normalPx = 36;

  static AssignmentMargin fromPx(double px) {
    for (final m in values) {
      if ((m.px - px).abs() < 0.5) return m;
    }
    return normal;
  }
}
