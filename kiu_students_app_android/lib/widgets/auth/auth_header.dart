import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';

/// Header widget with KIU logo and title for auth screens.
///
/// Compact, with a softly rounded logo tile and a bottom-right shadow.
class AuthHeader extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final double logoHeight;

  const AuthHeader({
    super.key,
    this.title,
    this.subtitle,
    this.logoHeight = 72,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Logo tile
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.4)
                    : colors.primary.withValues(alpha: 0.15),
                blurRadius: 14,
                offset: const Offset(3, 6),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/kiu_logo.png',
            height: logoHeight,
            fit: BoxFit.contain,
          ),
        ),

        if (title != null) ...[
          const SizedBox(height: 18),
          Text(
            title!,
            style: GoogleFonts.poppins(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ],

        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: colors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
