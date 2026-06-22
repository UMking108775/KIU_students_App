import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/category_model.dart';

/// Category card widget for displaying a category item - Compact modern design
class CategoryCard extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback? onTap;

  const CategoryCard({super.key, required this.category, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter to invert colors for dark mode (makes black icons white)
    final darkFilter = const ColorFilter.matrix([
      -1,
      0,
      0,
      0,
      255,
      0,
      -1,
      0,
      0,
      255,
      0,
      0,
      -1,
      0,
      255,
      0,
      0,
      0,
      1,
      0,
    ]);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          // Hairline border all around (uniform — required when a borderRadius
          // is set), kept faint on the top/left.
          border: Border.all(
            color: colors.border.withValues(alpha: isDark ? 0.4 : 0.25),
            width: 1,
          ),
          boxShadow: [
            // Tight, near-solid line hugging the bottom-right edge — reads as a
            // prominent stroke on just those two sides.
            BoxShadow(
              color: isDark
                  ? colors.border
                  : const Color(0xFF1E293B).withValues(alpha: 0.55),
              blurRadius: 1,
              spreadRadius: 0,
              offset: const Offset(2, 2),
            ),
            // Soft drop shadow toward the bottom-right for a tactile, raised feel.
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.55)
                  : const Color(0xFF1E293B).withValues(alpha: 0.18),
              blurRadius: 9,
              offset: const Offset(4, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Category Image with gradient overlay
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    category.image != null
                        ? CachedNetworkImage(
                            imageUrl: category.image!,
                            fit: BoxFit.cover,
                            color: isDark ? Colors.white : null,
                            colorBlendMode: isDark ? BlendMode.srcIn : null,
                            // Fallback to simple color filter if srcIn is too aggressive?
                            // User asked for "filter". srcIn with white allows coloring icon white.
                            // If they are photos, this might be bad. But 'icons' usually implies SVG/PNG shapes.
                            // Let's stick to the colorBlendMode: BlendMode.srcIn for now as it's standard for icons.
                            // actually, let's use the matrix filter approach for "inversion" if they are mixed content.
                            // But usually tinting is safer for simple icons.
                            // Let's use the USER's specific request "use flutter filter".
                            // I will use ColorFilter in the image builder if needed, or just the property.
                            // The property 'color' and 'colorBlendMode' is easiest for mono icons.
                            // If it's a photo, 'color: Colors.white, colorBlendMode: BlendMode.modulate' does nothing.
                            // Let's use INVERT filter as it handles both adequately for "dark mode support" of dark assets.
                            // Actually, CachedNetworkImage doesn't support 'colorFilter' directly in the constructor?
                            // It does NOT. It has 'color' and 'colorBlendMode'.
                            // It has 'imageBuilder'.
                            imageBuilder: (context, imageProvider) => Container(
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: imageProvider,
                                  fit: BoxFit.cover,
                                  colorFilter: isDark ? darkFilter : null,
                                ),
                              ),
                            ),
                            placeholder: (context, url) =>
                                _buildLoadingPlaceholder(colors),
                            errorWidget: (context, url, error) =>
                                _buildPlaceholder(colors),
                          )
                        : _buildPlaceholder(colors),
                    // Subtle gradient overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              (isDark ? Colors.white : Colors.black).withValues(
                                alpha: 0.1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Category Info with Arrow - Compact
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      category.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeColors colors) {
    return Container(
      color: colors.primary.withValues(alpha: 0.1),
      child: Center(
        child: Icon(Icons.category_outlined, size: 48, color: colors.primary),
      ),
    );
  }

  Widget _buildLoadingPlaceholder(ThemeColors colors) {
    return Container(
      color: colors.background,
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
