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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'answer': answer,
      'order': order,
      'created_at': createdAt?.toIso8601String(),
    };
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'message': message,
      'status': status,
      'admin_response': adminResponse,
      'responded_at': respondedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
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

/// Important Link model
class ImportantLinkModel {
  final int id;
  final String title;
  final String videoLink;
  final String description;
  final DateTime? createdAt;

  ImportantLinkModel({
    required this.id,
    required this.title,
    required this.videoLink,
    required this.description,
    this.createdAt,
  });

  factory ImportantLinkModel.fromJson(Map<String, dynamic> json) {
    return ImportantLinkModel(
      id: json['id'] as int,
      title: json['title'] as String,
      videoLink: json['video_link'] as String,
      description: json['description'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'video_link': videoLink,
      'description': description,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// Check if the link is a YouTube URL
  bool get isYouTubeLink {
    final uri = Uri.tryParse(videoLink);
    if (uri == null) return false;

    final host = uri.host.toLowerCase();
    return host.contains('youtube.com') ||
        host.contains('youtu.be') ||
        host.contains('m.youtube.com');
  }

  /// Extract YouTube video ID from various URL formats
  String? get youtubeVideoId {
    if (!isYouTubeLink) return null;

    final uri = Uri.tryParse(videoLink);
    if (uri == null) return null;

    // Handle youtu.be/VIDEO_ID format
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : null;
    }

    // Handle youtube.com/watch?v=VIDEO_ID format
    if (uri.queryParameters.containsKey('v')) {
      return uri.queryParameters['v'];
    }

    // Handle youtube.com/embed/VIDEO_ID format
    if (uri.pathSegments.contains('embed') && uri.pathSegments.length > 1) {
      final embedIndex = uri.pathSegments.indexOf('embed');
      return uri.pathSegments[embedIndex + 1];
    }

    return null;
  }
}
