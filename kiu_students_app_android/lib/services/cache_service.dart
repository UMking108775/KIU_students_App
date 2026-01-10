import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache service for persistent data storage with offline support
class CacheService {
  static const String _categoriesCacheKey = 'cached_categories';
  static const String _categoriesCacheTimeKey = 'cached_categories_time';

  SharedPreferences? _prefs;

  /// Initialize SharedPreferences
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Save categories to cache
  Future<void> cacheCategories(List<Map<String, dynamic>> categories) async {
    await init();
    await _prefs!.setString(_categoriesCacheKey, jsonEncode(categories));
    await _prefs!.setString(
      _categoriesCacheTimeKey,
      DateTime.now().toIso8601String(),
    );
  }

  /// Get cached categories
  Future<List<Map<String, dynamic>>?> getCachedCategories() async {
    await init();
    final cached = _prefs!.getString(_categoriesCacheKey);
    if (cached != null) {
      final List<dynamic> decoded = jsonDecode(cached);
      return decoded.cast<Map<String, dynamic>>();
    }
    return null;
  }

  /// Get cache timestamp
  Future<DateTime?> getCategoriesCacheTime() async {
    await init();
    final timeStr = _prefs!.getString(_categoriesCacheTimeKey);
    if (timeStr != null) {
      return DateTime.parse(timeStr);
    }
    return null;
  }

  /// Check if categories cache exists
  Future<bool> hasCachedCategories() async {
    await init();
    return _prefs!.containsKey(_categoriesCacheKey);
  }

  /// Clear specific cache
  Future<void> clearCategoriesCache() async {
    await init();
    await _prefs!.remove(_categoriesCacheKey);
    await _prefs!.remove(_categoriesCacheTimeKey);
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    await init();
    await _prefs!.clear();
  }
}
