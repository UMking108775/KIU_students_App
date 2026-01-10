import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/content_model.dart';

/// Material/Content card widget for displaying study material
class MaterialCard extends StatelessWidget {
  final ContentModel content;
  final VoidCallback? onTap;

  const MaterialCard({super.key, required this.content, this.onTap});

  IconData _getTypeIcon() {
    switch (content.contentType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'video':
        return Icons.play_circle_outline;
      case 'audio':
        return Icons.audiotrack_outlined;
      case 'ppt':
        return Icons.slideshow_outlined;
      case 'doc':
        return Icons.description_outlined;
      case 'image':
        return Icons.image_outlined;
      case 'zip':
        return Icons.folder_zip_outlined;
      case 'link':
        return Icons.link;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color _getTypeColor() {
    switch (content.contentType.toLowerCase()) {
      case 'pdf':
        return const Color(0xFFE53935);
      case 'video':
        return const Color(0xFF8E24AA);
      case 'audio':
        return const Color(0xFF00ACC1);
      case 'ppt':
        return const Color(0xFFFF7043);
      case 'doc':
        return const Color(0xFF1E88E5);
      case 'image':
        return const Color(0xFF43A047);
      case 'zip':
        return const Color(0xFF8D6E63);
      case 'link':
        return const Color(0xFF5C6BC0);
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Type Icon - Smaller
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getTypeColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_getTypeIcon(), color: _getTypeColor(), size: 20),
            ),
            const SizedBox(width: 12),

            // Title and Type
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    content.typeDisplayName,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _getTypeColor(),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Arrow
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
