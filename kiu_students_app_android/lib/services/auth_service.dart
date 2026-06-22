import '../models/api_response.dart';
import '../models/user_model.dart';
import 'api_service.dart';
import 'device_service.dart';
import 'storage_service.dart';
import 'cache_service.dart';

/// Authentication service handling login, register, logout
class AuthService {
  final ApiService _apiService;
  final StorageService _storageService;

  AuthService({
    required ApiService apiService,
    required StorageService storageService,
  }) : _apiService = apiService,
       _storageService = storageService;

  /// Register a new user
  Future<ApiResponse<UserModel>> register({
    required String kiuId,
    required String name,
    required String whatsappNumber,
    required String password,
    required String passwordConfirmation,
  }) async {
    final device = DeviceService();
    final response = await _apiService.post<AuthResponseData>(
      '/auth/register',
      body: {
        'kiu_id': kiuId,
        'name': name,
        'whatsapp_number': whatsappNumber,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'device_id': await device.getDeviceId(),
        'device_name': await device.getDeviceName(),
      },
      fromJsonT: (data) => AuthResponseData.fromJson(data),
    );

    if (response.success && response.data != null) {
      final authData = response.data!;
      final user = UserModel.fromJson(authData.user);

      // Save token and user data
      await _storageService.saveToken(authData.token);
      await _storageService.saveUser(user);

      // Clear cache to ensure fresh data for new user session
      try {
        final cacheService = CacheService();
        await cacheService.clearAllCache();
      } catch (e) {
        // Ignored
      }

      return ApiResponse(success: true, message: response.message, data: user);
    }

    return ApiResponse(
      success: false,
      message: response.message,
      errors: response.errors,
    );
  }

  /// Login user.
  ///
  /// Pass [force] = true to proceed even when the account is currently logged
  /// in on another device (that device will be signed out). When [force] is
  /// false and another device is active, the response carries
  /// [ApiResponse.requiresConfirmation] so the UI can ask the user first.
  Future<ApiResponse<UserModel>> login({
    required String kiuId,
    required String password,
    bool force = false,
  }) async {
    final device = DeviceService();
    final response = await _apiService.post<AuthResponseData>(
      '/auth/login',
      body: {
        'kiu_id': kiuId,
        'password': password,
        'device_id': await device.getDeviceId(),
        'device_name': await device.getDeviceName(),
        'force': force,
      },
      fromJsonT: (data) => AuthResponseData.fromJson(data),
    );

    if (response.success && response.data != null) {
      final authData = response.data!;
      final user = UserModel.fromJson(authData.user);

      // Save token and user data
      await _storageService.saveToken(authData.token);
      await _storageService.saveUser(user);

      // Clear cache to ensure fresh data for new user session
      try {
        final cacheService = CacheService();
        await cacheService.clearAllCache();
      } catch (e) {
        // Ignored
      }

      return ApiResponse(success: true, message: response.message, data: user);
    }

    return ApiResponse(
      success: false,
      message: response.message,
      errors: response.errors,
      requiresConfirmation: response.requiresConfirmation,
    );
  }

  /// Ask the backend why this device's session ended (called after a 401).
  ///
  /// Returns one of: `active`, `logged_in_elsewhere`, `expired`, `unknown`.
  /// Unauthenticated by design — the token is already gone. Falls back to
  /// `expired` when the endpoint is unavailable (e.g. older backend).
  Future<String> getSessionEndReason({required String kiuId}) async {
    try {
      final deviceId = await DeviceService().getDeviceId();
      final response = await _apiService.post<Map<String, dynamic>>(
        '/auth/session-state',
        body: {'kiu_id': kiuId, 'device_id': deviceId},
        fromJsonT: (data) => data as Map<String, dynamic>,
      );
      if (response.success && response.data != null) {
        return response.data!['reason']?.toString() ?? 'expired';
      }
    } catch (_) {
      // Ignored — fall back below.
    }
    return 'expired';
  }

  /// Get current user profile
  Future<ApiResponse<UserModel>> getProfile() async {
    final token = await _storageService.getToken();
    if (token == null) {
      return ApiResponse(
        success: false,
        message: 'No token found. Please login.',
      );
    }

    final response = await _apiService.get<Map<String, dynamic>>(
      '/auth/user',
      token: token,
      fromJsonT: (data) => data as Map<String, dynamic>,
    );

    if (response.success && response.data != null) {
      final user = UserModel.fromJson(response.data!);
      await _storageService.saveUser(user);

      return ApiResponse(success: true, message: response.message, data: user);
    }

    return ApiResponse(success: false, message: response.message);
  }

  /// Logout user
  Future<ApiResponse<void>> logout() async {
    final token = await _storageService.getToken();

    if (token != null) {
      await _apiService.post('/auth/logout', token: token);
    }

    // Clear local storage regardless of API response
    await _storageService.clearAll();

    return ApiResponse(success: true, message: 'Logged out successfully');
  }

  /// Clear the local session WITHOUT calling the logout API.
  /// Used when the token is already invalid (e.g. server returned 401).
  Future<void> clearSession() async {
    await _storageService.clearAll();
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    return await _storageService.isLoggedIn();
  }

  /// Get stored user
  Future<UserModel?> getStoredUser() async {
    return await _storageService.getUser();
  }

  /// Update user profile
  Future<ApiResponse<UserModel>> updateProfile({
    String? name,
    String? whatsappNumber,
  }) async {
    final token = await _storageService.getToken();
    if (token == null) {
      return ApiResponse(
        success: false,
        message: 'No token found. Please login.',
      );
    }

    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (whatsappNumber != null) body['whatsapp_number'] = whatsappNumber;

    final response = await _apiService.post<Map<String, dynamic>>(
      '/auth/update-profile',
      token: token,
      body: body,
      fromJsonT: (data) => data as Map<String, dynamic>,
    );

    if (response.success && response.data != null) {
      final user = UserModel.fromJson(response.data!);
      await _storageService.saveUser(user);
      return ApiResponse(success: true, message: response.message, data: user);
    }

    return ApiResponse(
      success: false,
      message: response.message,
      errors: response.errors,
    );
  }
}
