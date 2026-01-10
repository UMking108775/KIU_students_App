import '../models/api_response.dart';
import '../models/category_model.dart';
import 'api_service.dart';
import 'storage_service.dart';
import 'cache_service.dart';

/// Category service for fetching and caching category data
class CategoryService {
  final ApiService _apiService;
  final StorageService _storageService;
  final CacheService _cacheService;

  CategoryService({
    required ApiService apiService,
    required StorageService storageService,
    required CacheService cacheService,
  }) : _apiService = apiService,
       _storageService = storageService,
       _cacheService = cacheService;

  /// Get main categories (level 1) with caching
  /// - Online: Fetch fresh data and update cache
  /// - Offline: Return cached data if available
  Future<ApiResponse<List<CategoryModel>>> getMainCategories({
    bool forceRefresh = false,
  }) async {
    final token = await _storageService.getToken();
    if (token == null) {
      return ApiResponse(
        success: false,
        message: 'Please login to access categories',
      );
    }

    // Try to fetch from API
    final response = await _apiService.get<List<dynamic>>(
      '/categories',
      token: token,
      fromJsonT: (data) => data as List<dynamic>,
    );

    if (response.success && response.data != null) {
      // Parse categories
      final categories = response.data!
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // Cache the raw data for offline use
      await _cacheService.cacheCategories(
        response.data!.cast<Map<String, dynamic>>(),
      );

      return ApiResponse(
        success: true,
        message: response.message,
        data: categories,
      );
    }

    // If API failed (network error), try to load from cache
    final cachedData = await _cacheService.getCachedCategories();
    if (cachedData != null && cachedData.isNotEmpty) {
      final categories = cachedData
          .map((e) => CategoryModel.fromJson(e))
          .toList();

      return ApiResponse(
        success: true,
        message: 'Loaded from cache (offline mode)',
        data: categories,
      );
    }

    // No cache available
    return ApiResponse(success: false, message: response.message);
  }

  /// Get subcategories for a parent category
  Future<ApiResponse<List<CategoryModel>>> getSubcategories(
    int parentId,
  ) async {
    final token = await _storageService.getToken();
    if (token == null) {
      return ApiResponse(
        success: false,
        message: 'Please login to access categories',
      );
    }

    final response = await _apiService.get<List<dynamic>>(
      '/categories/$parentId/subcategories',
      token: token,
      fromJsonT: (data) => data as List<dynamic>,
    );

    if (response.success && response.data != null) {
      final categories = response.data!
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();

      return ApiResponse(
        success: true,
        message: response.message,
        data: categories,
      );
    }

    return ApiResponse(success: false, message: response.message);
  }
}
