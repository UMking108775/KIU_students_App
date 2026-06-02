import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/api_response.dart';

/// HTTP API service for making requests to the backend
/// Uses Singleton pattern - only ONE instance exists throughout the app
/// Benefits:
/// - Memory efficient (one HTTP client instead of many)
/// - Consistent configuration across all services
/// - Easier to manage and test
class ApiService {
  // Singleton instance - created once, reused everywhere
  static final ApiService _instance = ApiService._internal();

  // Factory constructor returns the same instance every time
  factory ApiService() => _instance;

  // Private constructor - can only be called once internally
  ApiService._internal() : _client = http.Client();

  final http.Client _client;

  /// Default headers for API requests
  Map<String, String> _headers({String? token}) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Make a GET request
  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    String? token,
    T? Function(dynamic)? fromJsonT,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.baseUrl}$endpoint'),
            headers: _headers(token: token),
          )
          .timeout(AppConfig.apiTimeout);

      return _handleResponse(response, fromJsonT);
    } on SocketException {
      return ApiResponse(
        success: false,
        message: 'No internet connection. Please check your network.',
      );
    } catch (e) {
      debugPrint('[ApiService] GET $endpoint error: $e');
      return ApiResponse(
        success: false,
        message: 'An error occurred. Please try again.',
      );
    }
  }

  /// Make a POST request
  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
    T? Function(dynamic)? fromJsonT,
  }) async {
    try {
      debugPrint('[ApiService] POST $endpoint');
      final response = await _client
          .post(
            Uri.parse('${AppConfig.baseUrl}$endpoint'),
            headers: _headers(token: token),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(AppConfig.apiTimeout);

      debugPrint('[ApiService] Response: ${response.statusCode}');
      return _handleResponse(response, fromJsonT);
    } on SocketException {
      return ApiResponse(
        success: false,
        message: 'No internet connection. Please check your network.',
      );
    } catch (e) {
      debugPrint('[ApiService] POST $endpoint error: $e');
      return ApiResponse(
        success: false,
        message: 'An error occurred. Please try again.',
      );
    }
  }

  /// Handle HTTP response and parse to ApiResponse
  /// Now with proper JSON decode error handling
  ApiResponse<T> _handleResponse<T>(
    http.Response response,
    T? Function(dynamic)? fromJsonT,
  ) {
    // Safe JSON parsing with error handling
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException catch (e) {
      // Server returned invalid JSON (HTML error page, empty response, etc.)
      debugPrint('[ApiService] Invalid JSON response: $e');
      debugPrint(
        '[ApiService] Response body: ${response.body.substring(0, response.body.length.clamp(0, 200))}...',
      );
      return ApiResponse(
        success: false,
        message: 'Server returned an invalid response. Please try again.',
      );
    } catch (e) {
      debugPrint('[ApiService] JSON decode error: $e');
      return ApiResponse(
        success: false,
        message: 'Failed to parse server response.',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ApiResponse.fromJson(body, fromJsonT);
    } else if (response.statusCode == 401) {
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Unauthorized. Please login again.',
      );
    } else if (response.statusCode == 422) {
      return ApiResponse.fromJson(body, fromJsonT);
    } else if (response.statusCode == 429) {
      return ApiResponse(
        success: false,
        message: 'Too many requests. Please wait a moment.',
      );
    } else {
      return ApiResponse(
        success: false,
        message: body['message'] ?? 'Something went wrong. Please try again.',
      );
    }
  }

  /// Dispose the client (rarely needed with singleton)
  void dispose() {
    _client.close();
  }
}
