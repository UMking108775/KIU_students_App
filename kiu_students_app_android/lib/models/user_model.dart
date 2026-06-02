/// User model representing authenticated user data
class UserModel {
  final int id;
  final String kiuId;
  final String name;
  final String whatsappNumber;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.kiuId,
    required this.name,
    required this.whatsappNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create UserModel from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      kiuId: json['kiu_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      whatsappNumber: json['whatsapp_number']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  /// Convert UserModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kiu_id': kiuId,
      'name': name,
      'whatsapp_number': whatsappNumber,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
