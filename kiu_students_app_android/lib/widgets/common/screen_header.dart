import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

/// Reusable screen header with inline back button and title
/// Used for nested screens where the app bar shows hamburger menu
class ScreenHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;

  const ScreenHeader({super.key, required this.title, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Back button
          if (onBack != null)
            GestureDetector(
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
            ),
          if (onBack != null) const SizedBox(width: 12),
          // Title
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
