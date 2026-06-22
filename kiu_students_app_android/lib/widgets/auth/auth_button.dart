import 'package:flutter/material.dart';

/// Primary action button for authentication forms.
///
/// Compact, small-radius, with a bottom-right drop shadow tinted by the primary
/// colour for a tactile, designed feel.
class AuthButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;

  const AuthButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    if (isOutlined) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: primary, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _buildChild(context),
        ),
      );
    }

    final enabled = !isLoading && onPressed != null;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: primary.withValues(alpha: 0.30),
                  blurRadius: 10,
                  offset: const Offset(3, 5),
                ),
              ]
            : null,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _buildChild(context),
        ),
      ),
    );
  }

  Widget _buildChild(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(
            isOutlined ? Theme.of(context).colorScheme.primary : Colors.white,
          ),
        ),
      );
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
        color: isOutlined ? Theme.of(context).colorScheme.primary : null,
      ),
    );
  }
}
