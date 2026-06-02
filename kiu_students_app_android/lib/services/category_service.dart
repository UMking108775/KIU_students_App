import '../models/api_response.dart';
import '../models/category_model.dart';
import 'api_service.dart';
import 'storage_service.dart';
import 'cache_service.dart';

/// Category service for fetching and caching category data
/// Implements cache-first approach for offline support
class CategoryService {
  final ApiService _apiService;
  final StorageService _storageService;
  final CacheService _cacheService;

  CategoryService({
    ApiService? apiService,
    StorageService? storageService,
    CacheService? cacheService,
  }) : _apiService = apiService ?? ApiService(),
       _storageService = storageService ?? StorageService(),
       _cacheService = cacheService ?? CacheService();

  /// Get all categories (flat list) with caching
  /// Used by background sync and for building category tree
  Future<ApiResponse<List<CategoryModel>>> getCategories({
    bool forceRefresh = false,
  }) async {
    // Check cache first (unless force refresh)
    if (!forceRefresh) {
      final cached = await _cacheService.getCachedCategories();
      if (cached != null && cached.isNotEmpty) {
        return ApiResponse(
          success: true,
          message: 'Loaded from cache',
          data: cached,
        );
      }
    }

    final token = await _storageService.getToken();

    // Note: API is now public for categories, so we can proceed even without token (Guest Mode)

    // If we have cached data and offline/no token, we could return it,
    // but now we want to try fetching fresh guest data if possible.

    try {
      // Fetch from API
      final response = await _apiService.get<List<dynamic>>(
        '/categories',
        token: token,
        fromJsonT: (data) => data as List<dynamic>,
      );

      if (response.success && response.data != null) {
        final categories = response.data!
            .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
            .toList();

        // Cache for offline use
        await _cacheService.cacheCategories(categories);

        return ApiResponse(
          success: true,
          message: response.message,
          data: categories,
        );
      }

      // API failed - try cache (even if expired for offline mode)
      final cached = await _cacheService.getCachedCategories();
      if (cached != null && cached.isNotEmpty) {
        return ApiResponse(
          success: true,
          message: 'Loaded from cache (offline mode)',
          data: cached,
        );
      }

      return ApiResponse(success: false, message: response.message);
    } catch (e) {
      // On error, return cached data
      final cached = await _cacheService.getCachedCategories();
      if (cached != null) {
        return ApiResponse(
          success: true,
          message: 'Offline mode',
          data: cached,
        );
      }
      return ApiResponse(success: false, message: 'Failed to load categories');
    }
  }

  /// Get main categories (level 1 only)
  Future<ApiResponse<List<CategoryModel>>> getMainCategories({
    bool forceRefresh = false,
  }) async {
    final response = await getCategories(forceRefresh: forceRefresh);

    if (response.success && response.data != null) {
      // Filter to only main categories (no parent)
      final mainCategories = response.data!
          .where((c) => c.parentId == null)
          .toList();

      return ApiResponse(
        success: true,
        message: response.message,
        data: mainCategories,
      );
    }

    return response;
  }

  /// Get subcategories for a parent category (with caching)
  Future<ApiResponse<List<CategoryModel>>> getSubcategories(
    int parentId, {
    bool forceRefresh = false,
  }) async {
    // Check cache first if not forcing refresh
    if (!forceRefresh) {
      final cached = await _cacheService.getCachedSubcategories(parentId);
      if (cached != null && cached.isNotEmpty) {
        return ApiResponse(
          success: true,
          message: 'Loaded from cache',
          data: cached,
        );
      }
    }

    final token = await _storageService.getToken();

    // Note: API is now public for categories, so we can proceed even without token (Guest Mode)

    try {
      final response = await _apiService.get<List<dynamic>>(
        '/categories/$parentId/subcategories',
        token: token,
        fromJsonT: (data) => data as List<dynamic>,
      );

      if (response.success && response.data != null) {
        final categories = response.data!
            .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
            .toList();

        // Cache the subcategories
        await _cacheService.cacheSubcategories(parentId, categories);

        return ApiResponse(
          success: true,
          message: response.message,
          data: categories,
        );
      }

      // On API failure, try cached data
      final cached = await _cacheService.getCachedSubcategories(parentId);
      if (cached != null) {
        return ApiResponse(
          success: true,
          message: 'Loaded from cache',
          data: cached,
        );
      }

      return ApiResponse(success: false, message: response.message);
    } catch (e) {
      // On error, return cached data if available
      final cached = await _cacheService.getCachedSubcategories(parentId);
      if (cached != null) {
        return ApiResponse(
          success: true,
          message: 'Offline mode',
          data: cached,
        );
      }
      return ApiResponse(
        success: false,
        message: 'Failed to load subcategories',
      );
    }
  }

  /// Pre-fetch all category levels for a main category
  /// This ensures instant navigation for subcategories
  Future<void> prefetchCategoryTree(int mainCategoryId) async {
    // The getCategories method already fetches all categories
    // So just calling it once is enough
    await getCategories();
  }
}
