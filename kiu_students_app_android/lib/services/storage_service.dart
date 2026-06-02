import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../config/app_config.dart';
import '../models/user_model.dart';

/// Secure storage service for managing auth tokens and user data
class StorageService {
  final FlutterSecureStorage _storage;

  StorageService()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );

  /// Save auth token
  Future<void> saveToken(String token) async {
    await _storage.write(key: AppConfig.tokenKey, value: token);
  }

  /// Get auth token
  Future<String?> getToken() async {
    return await _storage.read(key: AppConfig.tokenKey);
  }

  /// Delete auth token
  Future<void> deleteToken() async {
    await _storage.delete(key: AppConfig.tokenKey);
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Save user data
  Future<void> saveUser(UserModel user) async {
    await _storage.write(
      key: AppConfig.userKey,
      value: jsonEncode(user.toJson()),
    );
  }

  /// Get user data
  Future<UserModel?> getUser() async {
    final userData = await _storage.read(key: AppConfig.userKey);
    if (userData != null) {
      return UserModel.fromJson(jsonDecode(userData));
    }
    return null;
  }

  /// Delete user data
  Future<void> deleteUser() async {
    await _storage.delete(key: AppConfig.userKey);
  }

  /// Clear all stored data (logout)
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
