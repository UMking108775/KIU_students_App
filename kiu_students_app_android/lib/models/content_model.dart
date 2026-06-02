/// Content/Material model representing study material
class ContentModel {
  final int id;
  final String title;
  final String contentType;
  final String backblazeUrl;
  final bool isActive;
  final ContentCategory? category;
  final DateTime createdAt;
  final DateTime updatedAt;

  ContentModel({
    required this.id,
    required this.title,
    required this.contentType,
    required this.backblazeUrl,
    required this.isActive,
    this.category,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create ContentModel from JSON
  factory ContentModel.fromJson(Map<String, dynamic> json) {
    return ContentModel(
      id: json['id'] as int,
      title: json['title'] as String,
      contentType: json['content_type'] as String,
      backblazeUrl: json['backblaze_url'] as String,
      isActive: json['is_active'] as bool? ?? true,
      category: json['category'] != null
          ? ContentCategory.fromJson(json['category'])
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert ContentModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content_type': contentType,
      'backblaze_url': backblazeUrl,
      'is_active': isActive,
      'category': category?.toJson(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Get icon for content type
  String get typeIcon {
    switch (contentType.toLowerCase()) {
      case 'pdf':
        return '📄';
      case 'video':
        return '📹';
      case 'audio':
        return '🎵';
      case 'ppt':
        return '📊';
      case 'doc':
        return '📝';
      case 'image':
        return '🖼️';
      case 'zip':
        return '📦';
      case 'link':
        return '🔗';
      default:
        return '📁';
    }
  }

  /// Get display name for content type
  String get typeDisplayName {
    switch (contentType.toLowerCase()) {
      case 'pdf':
        return 'PDF Document';
      case 'video':
        return 'Video';
      case 'audio':
        return 'Audio';
      case 'ppt':
        return 'Presentation';
      case 'doc':
        return 'Document';
      case 'image':
        return 'Image';
      case 'zip':
        return 'Archive';
      case 'link':
        return 'Link';
      default:
        return 'File';
    }
  }
}

/// Simplified category info for content
class ContentCategory {
  final int id;
  final String title;
  final int level;

  ContentCategory({required this.id, required this.title, required this.level});

  factory ContentCategory.fromJson(Map<String, dynamic> json) {
    return ContentCategory(
      id: json['id'] as int,
      title: json['title'] as String,
      level: json['level'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'title': title, 'level': level};
  }
}
