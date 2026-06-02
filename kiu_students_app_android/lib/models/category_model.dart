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
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      image: json['image']?.toString(),
      parentId: (json['parent_id'] as num?)?.toInt(),
      level: (json['level'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] == null ? true : json['is_active'] == true,
      contentsCount: (json['contents_count'] as num?)?.toInt() ?? 0,
      children: (json['children'] as List?)
              ?.map((e) => CategoryModel.fromJson(e))
              .toList() ??
          [],
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
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
