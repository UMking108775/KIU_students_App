/// Category model representing a content category
class CategoryModel {
  final int id;
  final String title;
  final String? image;
  final int? parentId;
  final int level;
  final bool isActive;
  final int contentsCount;
  final List<CategoryModel> children;
  final DateTime createdAt;
  final DateTime updatedAt;

  CategoryModel({
    required this.id,
    required this.title,
    this.image,
    this.parentId,
    required this.level,
    required this.isActive,
    this.contentsCount = 0,
    this.children = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create CategoryModel from JSON
  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as int,
      title: json['title'] as String,
      image: json['image'] as String?,
      parentId: json['parent_id'] as int?,
      level: json['level'] as int,
      isActive: json['is_active'] as bool? ?? true,
      contentsCount: json['contents_count'] as int? ?? 0,
      children: json['children'] != null
          ? (json['children'] as List)
                .map((e) => CategoryModel.fromJson(e))
                .toList()
          : [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert CategoryModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'image': image,
      'parent_id': parentId,
      'level': level,
      'is_active': isActive,
      'contents_count': contentsCount,
      'children': children.map((e) => e.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
