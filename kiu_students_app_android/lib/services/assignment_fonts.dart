import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// A selectable writing font for the assignment editor.
///
/// Each font is bundled locally (see `pubspec.yaml` > flutter > fonts) so the
/// editor and the exported PDF render identically and fully offline. Because the
/// PDF is produced by rendering the on-screen page to images (Flutter shapes the
/// text with HarfBuzz), whichever font is chosen here is exactly what appears in
/// the PDF — including Nastaliq, which the pure-Dart `pdf` package cannot shape.
class AssignmentFont {
  /// The family name exactly as registered in `pubspec.yaml`.
  final String family;

  /// Short label shown in the picker (native script + name).
  final String label;

  /// The language(s) this font is recommended for.
  final String language;

  /// Line-height multiplier this font reads best at. Nastaliq fonts are very
  /// tall and their lines collide at a normal (~1.15) height, so they need a
  /// generous value; Naskh fonts need less.
  final double lineHeight;

  const AssignmentFont({
    required this.family,
    required this.label,
    required this.language,
    required this.lineHeight,
  });
}

/// The fonts offered in the editor's writing-font picker.
class AssignmentFonts {
  AssignmentFonts._();

  // Family names — must match the `family:` entries in pubspec.yaml exactly.
  static const String notoNastaliqUrduFamily = 'Noto Nastaliq Urdu';
  static const String bahijKarimFamily = 'Bahij Karim';
  static const String bahijNassimFamily = 'Bahij Nassim';

  /// Default font family (usable in `const` default parameter values).
  static const String fallbackFamily = notoNastaliqUrduFamily;

  /// Urdu Nastaliq — Google Fonts' Noto Nastaliq Urdu (full Urdu coverage).
  /// Its glyphs are exceptionally tall, hence the large line height.
  static const AssignmentFont notoNastaliqUrdu = AssignmentFont(
    family: notoNastaliqUrduFamily,
    label: 'اردو — Noto Nastaliq',
    language: 'Urdu',
    lineHeight: 2.0,
  );

  /// Arabic / Pashto (Naskh).
  static const AssignmentFont bahijKarim = AssignmentFont(
    family: bahijKarimFamily,
    label: 'عربی / پښتو — Bahij Karim',
    language: 'Arabic / Pashto',
    lineHeight: 1.6,
  );

  /// Arabic / Pashto (Naskh).
  static const AssignmentFont bahijNassim = AssignmentFont(
    family: bahijNassimFamily,
    label: 'عربی / پښتو — Bahij Nassim',
    language: 'Arabic / Pashto',
    lineHeight: 1.6,
  );

  /// All fonts offered in the picker, in display order.
  static const List<AssignmentFont> all = <AssignmentFont>[
    notoNastaliqUrdu,
    bahijKarim,
    bahijNassim,
  ];

  /// The default font for new documents (and old drafts saved before fonts
  /// were selectable).
  static const AssignmentFont fallback = notoNastaliqUrdu;

  /// Resolves a stored family name back to a font, defaulting to [fallback].
  static AssignmentFont byFamily(String? family) {
    for (final font in all) {
      if (font.family == family) return font;
    }
    return fallback;
  }

  /// Items for the editor toolbar's font-family dropdown: a concise label →
  /// font-family value, plus a "Default" entry that clears the per-run font and
  /// falls back to [fallbackFamily]. ('Clear' is flutter_quill's reset value.)
  static const Map<String, String> toolbarItems = <String, String>{
    'اردو (نوٹو)': notoNastaliqUrduFamily,
    'بہیج کریم (عربی)': bahijKarimFamily,
    'بہیج نسیم (عربی)': bahijNassimFamily,
    'Default': 'Clear',
  };

  /// Builds the [DefaultStyles] the editor (and the PDF capture) apply on top of
  /// flutter_quill's defaults, so body text uses [fontFamily] at [lineHeight].
  ///
  /// flutter_quill's stock line height (~1.15) makes tall Nastaliq lines collide
  /// ("lines mixed up"). We override the block styles that carry body text —
  /// paragraph, alignment, indent, lists, quote, the placeholder, and the four
  /// named line-height presets — so the spacing is correct in the editor and the
  /// exported PDF alike. Anything not listed here is inherited unchanged via the
  /// editor's `merge(customStyles)`.
  static DefaultStyles quillStyles({
    String fontFamily = fallbackFamily,
    double lineHeight = 2.0,
    Color color = Colors.black,
    double fontSize = 16,
  }) {
    final base = TextStyle(
      fontFamily: fontFamily,
      color: color,
      fontSize: fontSize,
      height: lineHeight,
      decoration: TextDecoration.none,
    );
    const hs = HorizontalSpacing(0, 0);
    const noGap = VerticalSpacing(0, 0);
    const blockGap = VerticalSpacing(6, 0);
    const listLineGap = VerticalSpacing(0, 6);

    DefaultTextBlockStyle block(double h) =>
        DefaultTextBlockStyle(base.copyWith(height: h), hs, noGap, noGap, null);

    return DefaultStyles(
      paragraph: block(lineHeight),
      align: block(lineHeight),
      indent: DefaultTextBlockStyle(
        base.copyWith(height: lineHeight),
        hs,
        blockGap,
        listLineGap,
        null,
      ),
      lists: DefaultListBlockStyle(
        base.copyWith(height: lineHeight),
        hs,
        blockGap,
        listLineGap,
        null,
        null,
      ),
      quote: DefaultTextBlockStyle(
        base.copyWith(
          color: color.withValues(alpha: 0.6),
          height: lineHeight,
        ),
        hs,
        blockGap,
        const VerticalSpacing(6, 2),
        BoxDecoration(
          border: Border(
            left: BorderSide(width: 4, color: Colors.grey.shade300),
          ),
        ),
      ),
      placeHolder: DefaultTextBlockStyle(
        base.copyWith(
          fontSize: 20,
          color: Colors.grey.withValues(alpha: 0.6),
          height: lineHeight,
        ),
        hs,
        noGap,
        noGap,
        null,
      ),
      // Make the toolbar's line-height presets Nastaliq-appropriate, scaled
      // around the font's natural height.
      lineHeightTight: block(lineHeight * 0.85),
      lineHeightNormal: block(lineHeight),
      lineHeightOneAndHalf: block(lineHeight * 1.2),
      lineHeightDouble: block(lineHeight * 1.45),
    );
  }
}
