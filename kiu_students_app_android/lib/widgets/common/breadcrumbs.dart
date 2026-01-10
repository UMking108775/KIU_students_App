import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/category_model.dart';

/// Breadcrumb navigation widget for nested category screens - Web-style compact design
class Breadcrumbs extends StatelessWidget {
  final List<BreadcrumbItem> items;

  const Breadcrumbs({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: AppColors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Home icon only (no text, more compact)
            GestureDetector(
              onTap: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: const Icon(
                Icons.home_outlined,
                size: 16,
                color: AppColors.primary,
              ),
            ),

            // Breadcrumb items with "/" separator
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isLast = index == items.length - 1;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Web-style "/" separator
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '/',
                      style: TextStyle(fontSize: 12, color: AppColors.textHint),
                    ),
                  ),
                  // Breadcrumb text link
                  GestureDetector(
                    onTap: isLast
                        ? null
                        : () {
                            if (item.onTap != null) {
                              item.onTap!();
                            } else {
                              for (
                                int i = 0;
                                i < items.length - index - 1;
                                i++
                              ) {
                                Navigator.pop(context);
                              }
                            }
                          },
                    child: Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 12,
                        color: isLast
                            ? AppColors.textPrimary
                            : AppColors.primary,
                        fontWeight: isLast ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Breadcrumb item model
class BreadcrumbItem {
  final String title;
  final CategoryModel? category;
  final VoidCallback? onTap;

  BreadcrumbItem({required this.title, this.category, this.onTap});
}
