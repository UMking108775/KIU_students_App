import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/api_response.dart';

/// HTTP API service for making requests to the backend
class ApiService {
  final http.Client _client;

  ApiService() : _client = http.Client();

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
      final response = await _client
          .post(
            Uri.parse('${AppConfig.baseUrl}$endpoint'),
            headers: _headers(token: token),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(AppConfig.apiTimeout);

      return _handleResponse(response, fromJsonT);
    } on SocketException {
      return ApiResponse(
        success: false,
        message: 'No internet connection. Please check your network.',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'An error occurred. Please try again.',
      );
    }
  }

  /// Handle HTTP response and parse to ApiResponse
  ApiResponse<T> _handleResponse<T>(
    http.Response response,
    T? Function(dynamic)? fromJsonT,
  ) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;

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

  /// Dispose the client
  void dispose() {
    _client.close();
  }
}
