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
      id: json['id'] as int,
      title: json['title'] as String,
      message: json['message'] as String,
      type: json['type'] as String,
      actionUrl: json['action_url'] as String?,
      actionText: json['action_text'] as String?,
      categoryId: json['category_id'] as int?,
      priority: json['priority'] as int? ?? 0,
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] != null
          ? DateTime.parse(
              json['read_at'].toString().endsWith('Z')
                  ? json['read_at']
                  : '${json['read_at']}Z',
            ).toLocal()
          : null,
      createdAt: DateTime.parse(
        json['created_at'].toString().endsWith('Z')
            ? json['created_at']
            : '${json['created_at']}Z',
      ).toLocal(),
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.parse(
              json['scheduled_at'].toString().endsWith('Z')
                  ? json['scheduled_at']
                  : '${json['scheduled_at']}Z',
            ).toLocal()
          : null,
    );
  }
}
