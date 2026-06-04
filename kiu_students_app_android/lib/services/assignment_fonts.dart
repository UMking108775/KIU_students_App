/// A selectable writing font for the assignment editor.
///
/// Each font is bundled locally (see `pubspec.yaml` > flutter > fonts) and
/// embedded as base64 `@font-face` in the editor and PDF HTML, so the WebView
/// shapes the text identically on screen and in the exported PDF, fully offline
/// — including Nastaliq, which the pure-Dart `pdf` package cannot shape.
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
}
