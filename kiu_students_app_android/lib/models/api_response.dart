/// Generic API response wrapper
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final Map<String, List<String>>? errors;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.errors,
  });

  factory ApiResponse.error(String message) {
    return ApiResponse(success: false, message: message);
  }

  /// Create ApiResponse from JSON
  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T? Function(dynamic)? fromJsonT,
  ) {
    return ApiResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'] as T?,
      errors: json['errors'] != null
          ? (json['errors'] as Map<String, dynamic>).map(
              (key, value) => MapEntry(
                key,
                (value as List).map((e) => e.toString()).toList(),
              ),
            )
          : null,
    );
  }

  /// Check if response has validation errors
  bool get hasErrors => errors != null && errors!.isNotEmpty;

  /// Get first error message for a field
  String? getFieldError(String field) {
    if (errors != null && errors!.containsKey(field)) {
      return errors![field]?.first;
    }
    return null;
  }

  /// Get all error messages as a single string
  String get allErrorMessages {
    if (errors == null || errors!.isEmpty) return message;
    return errors!.values.expand((e) => e).join('\n');
  }
}

/// Auth response data containing user and token
class AuthResponseData {
  final Map<String, dynamic> user;
  final String token;
  final String tokenType;
  final String expiresIn;

  AuthResponseData({
    required this.user,
    required this.token,
    required this.tokenType,
    required this.expiresIn,
  });

  factory AuthResponseData.fromJson(Map<String, dynamic> json) {
    return AuthResponseData(
      user: json['user'] as Map<String, dynamic>,
      token: json['token'] as String,
      tokenType: json['token_type'] as String,
      expiresIn: json['expires_in'] as String,
    );
  }
}
