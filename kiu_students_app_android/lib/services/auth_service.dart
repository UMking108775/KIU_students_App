import '../models/api_response.dart';
import '../models/user_model.dart';
import 'api_service.dart';
import 'storage_service.dart';

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
    final response = await _apiService.post<AuthResponseData>(
      '/auth/register',
      body: {
        'kiu_id': kiuId,
        'name': name,
        'whatsapp_number': whatsappNumber,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
      fromJsonT: (data) => AuthResponseData.fromJson(data),
    );

    if (response.success && response.data != null) {
      final authData = response.data!;
      final user = UserModel.fromJson(authData.user);

      // Save token and user data
      await _storageService.saveToken(authData.token);
      await _storageService.saveUser(user);

      return ApiResponse(success: true, message: response.message, data: user);
    }

    return ApiResponse(
      success: false,
      message: response.message,
      errors: response.errors,
    );
  }

  /// Login user
  Future<ApiResponse<UserModel>> login({
    required String kiuId,
    required String password,
  }) async {
    final response = await _apiService.post<AuthResponseData>(
      '/auth/login',
      body: {'kiu_id': kiuId, 'password': password},
      fromJsonT: (data) => AuthResponseData.fromJson(data),
    );

    if (response.success && response.data != null) {
      final authData = response.data!;
      final user = UserModel.fromJson(authData.user);

      // Save token and user data
      await _storageService.saveToken(authData.token);
      await _storageService.saveUser(user);

      return ApiResponse(success: true, message: response.message, data: user);
    }

    return ApiResponse(
      success: false,
      message: response.message,
      errors: response.errors,
    );
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
