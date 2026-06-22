import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

/// Custom styled text field for authentication forms.
///
/// Compact, small-radius, with a crisp bottom-right drop shadow so the inputs
/// feel tactile and intentionally designed (not flat / generic).
class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final bool enabled;
  final int maxLines;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.enabled = true,
    this.maxLines = 1,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c, width: w),
        );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : const Color(0xFF1E293B).withValues(alpha: 0.10),
            blurRadius: 6,
            offset: const Offset(3, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: widget.controller,
        obscureText: widget.isPassword && _obscureText,
        keyboardType: widget.keyboardType,
        validator: widget.validator,
        enabled: widget.enabled,
        maxLines: widget.isPassword ? 1 : widget.maxLines,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onFieldSubmitted,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          border: border(colors.border),
          enabledBorder: border(colors.border),
          focusedBorder: border(colors.primary, 1.5),
          errorBorder: border(colors.error),
          focusedErrorBorder: border(colors.error, 1.5),
          prefixIcon: widget.prefixIcon != null
              ? Icon(widget.prefixIcon, color: colors.textSecondary, size: 21)
              : null,
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(
                    _obscureText
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: colors.textSecondary,
                    size: 21,
                  ),
                  onPressed: () =>
                      setState(() => _obscureText = !_obscureText),
                )
              : null,
        ),
      ),
    );
  }
}
