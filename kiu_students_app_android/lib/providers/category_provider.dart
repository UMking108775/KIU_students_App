import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../services/api_service.dart';
import '../services/category_service.dart';
import '../services/storage_service.dart';
import '../services/cache_service.dart';

/// Category state management provider
class CategoryProvider extends ChangeNotifier {
  final CategoryService _categoryService;

  List<CategoryModel> _categories = [];
  bool _isLoading = false;
  bool _isOfflineMode = false;
  String? _errorMessage;

  CategoryProvider({CategoryService? categoryService})
    : _categoryService =
          categoryService ??
          CategoryService(
            apiService: ApiService(),
            storageService: StorageService(),
            cacheService: CacheService(),
          );

  // Getters
  List<CategoryModel> get categories => _categories;
  bool get isLoading => _isLoading;
  bool get isOfflineMode => _isOfflineMode;
  String? get errorMessage => _errorMessage;
  bool get hasCategories => _categories.isNotEmpty;

  /// Load main categories with caching
  Future<void> loadCategories({bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _categoryService.getMainCategories(
      forceRefresh: forceRefresh,
    );

    _isLoading = false;

    if (response.success && response.data != null) {
      _categories = response.data!;
      _isOfflineMode = response.message.contains('offline');
      _errorMessage = null;
    } else {
      _errorMessage = response.message;
      // Keep existing categories if we have them
      if (_categories.isEmpty) {
        _categories = [];
      }
    }

    notifyListeners();
  }

  /// Refresh categories (pull-to-refresh)
  Future<void> refreshCategories() async {
    await loadCategories(forceRefresh: true);
  }

  /// Clear categories
  void clearCategories() {
    _categories = [];
    _isOfflineMode = false;
    _errorMessage = null;
    notifyListeners();
  }
}
