/// FAQ model for help and support
class FaqModel {
  final int id;
  final String question;
  final String answer;
  final int order;
  final DateTime? createdAt;

  FaqModel({
    required this.id,
    required this.question,
    required this.answer,
    this.order = 0,
    this.createdAt,
  });

  factory FaqModel.fromJson(Map<String, dynamic> json) {
    return FaqModel(
      id: json['id'] as int,
      question: json['question'] as String,
      answer: json['answer'] as String,
      order: json['order'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}

/// Support ticket model
class SupportTicket {
  final int id;
  final String subject;
  final String message;
  final String status; // 'pending', 'responded', 'closed'
  final String? adminResponse;
  final DateTime? respondedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  SupportTicket({
    required this.id,
    required this.subject,
    required this.message,
    required this.status,
    this.adminResponse,
    this.respondedAt,
    required this.createdAt,
    this.updatedAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'] as int,
      subject: json['subject'] as String,
      message: json['message'] as String,
      status: json['status'] as String? ?? 'pending',
      adminResponse: json['admin_response'] as String?,
      respondedAt: json['responded_at'] != null
          ? DateTime.tryParse(json['responded_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
    );
  }

  bool get hasResponse => adminResponse != null && adminResponse!.isNotEmpty;

  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'responded':
        return 'Responded';
      case 'closed':
        return 'Closed';
      default:
        return status;
    }
  }
}
