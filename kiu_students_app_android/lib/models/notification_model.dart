class NotificationModel {
  final int id;
  final String title;
  final String message;
  final String type;
  final String? actionUrl;
  final String? actionText;
  final int? categoryId;
  final int priority;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;
  final DateTime? scheduledAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.actionUrl,
    this.actionText,
    this.categoryId,
    required this.priority,
    required this.isRead,
    this.readAt,
    required this.createdAt,
    this.scheduledAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      actionUrl: json['action_url']?.toString(),
      actionText: json['action_text']?.toString(),
      categoryId: (json['category_id'] as num?)?.toInt(),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      isRead: json['is_read'] == true,
      readAt: json['read_at'] != null
          ? DateTime.tryParse(
              json['read_at'].toString().endsWith('Z')
                  ? json['read_at'].toString()
                  : '${json['read_at']}Z',
            )?.toLocal()
          : null,
      createdAt:
          DateTime.tryParse(
            json['created_at'].toString().endsWith('Z')
                ? json['created_at'].toString()
                : '${json['created_at']}Z',
          )?.toLocal() ??
          DateTime.now(),
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.tryParse(
              json['scheduled_at'].toString().endsWith('Z')
                  ? json['scheduled_at'].toString()
                  : '${json['scheduled_at']}Z',
            )?.toLocal()
          : null,
    );
  }
}
