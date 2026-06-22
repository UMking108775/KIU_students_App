import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';

/// The shared card / box surface used across the **Student Tools hub** — the
/// exact look of the tool tiles on the hub (soft border, 12px radius, crisp
/// bottom-right drop shadow).
///
/// Defined once here so every tool-hub screen (My PDFs, Write Assignment,
/// Organize / Split / Compress PDF, GPA, …) matches the hub — and ONLY those
/// screens. The rest of the app keeps its own styling, so use this helper only
/// inside `lib/screens/tools/`.
BoxDecoration toolCardDecoration(
  BuildContext context, {
  double radius = 10,
  Color? color,
}) {
  final colors = AppColors.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: color ?? colors.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: isDark ? colors.border : colors.border.withValues(alpha: 0.7),
    ),
    boxShadow: [
      // A defined, slightly HARD drop shadow nudged toward the bottom-right —
      // a crisp production edge, not a soft glow. Tight blur + a touch more
      // opacity reads as deliberate rather than fuzzy.
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.55)
            : const Color(0xFF1E293B).withValues(alpha: 0.22),
        blurRadius: 6,
        offset: const Offset(3, 5),
      ),
    ],
  );
}
