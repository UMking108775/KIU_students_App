import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

/// Authentication state management provider
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  UserModel? _user;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;

  AuthProvider({AuthService? authService})
    : _authService =
          authService ??
          AuthService(
            apiService: ApiService(),
            storageService: StorageService(),
          );

  // Getters
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;

  /// Initialize auth state on app start
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    final isLoggedIn = await _authService.isLoggedIn();
    if (isLoggedIn) {
      _user = await _authService.getStoredUser();
    }

    _isLoading = false;
    _isInitialized = true;
    notifyListeners();
  }

  /// Login user
  Future<bool> login({required String kiuId, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _authService.login(kiuId: kiuId, password: password);

    _isLoading = false;

    if (response.success && response.data != null) {
      _user = response.data;
      notifyListeners();
      return true;
    } else {
      _errorMessage = response.message;
      notifyListeners();
      return false;
    }
  }

  /// Register new user
  Future<bool> register({
    required String kiuId,
    required String name,
    required String whatsappNumber,
    required String password,
    required String passwordConfirmation,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _authService.register(
      kiuId: kiuId,
      name: name,
      whatsappNumber: whatsappNumber,
      password: password,
      passwordConfirmation: passwordConfirmation,
    );

    _isLoading = false;

    if (response.success && response.data != null) {
      _user = response.data;
      notifyListeners();
      return true;
    } else {
      _errorMessage = response.hasErrors
          ? response.allErrorMessages
          : response.message;
      notifyListeners();
      return false;
    }
  }

  /// Logout user
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await _authService.logout();

    _user = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Update user profile
  Future<bool> updateProfile({String? name, String? whatsappNumber}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _authService.updateProfile(
      name: name,
      whatsappNumber: whatsappNumber,
    );

    _isLoading = false;

    if (response.success && response.data != null) {
      _user = response.data;
      notifyListeners();
      return true;
    } else {
      _errorMessage = response.hasErrors
          ? response.allErrorMessages
          : response.message;
      notifyListeners();
      return false;
    }
  }
}
