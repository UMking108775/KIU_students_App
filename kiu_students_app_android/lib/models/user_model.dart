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
      id: json['id'] as int,
      kiuId: json['kiu_id'] as String,
      name: json['name'] as String,
      whatsappNumber: json['whatsapp_number'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
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
