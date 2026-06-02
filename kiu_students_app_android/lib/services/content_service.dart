import '../models/api_response.dart';
import '../models/content_model.dart';
import 'api_service.dart';
import 'storage_service.dart';
import 'cache_service.dart';

/// Content service for fetching materials with caching
/// Implements cache-first approach for offline support
class ContentService {
  final ApiService _apiService;
  final StorageService _storageService;
  final CacheService _cacheService;

  ContentService({
    ApiService? apiService,
    StorageService? storageService,
    CacheService? cacheService,
  }) : _apiService = apiService ?? ApiService(),
       _storageService = storageService ?? StorageService(),
       _cacheService = cacheService ?? CacheService();

  /// Get contents for a specific category with caching
  Future<ApiResponse<List<ContentModel>>> getContentsByCategory(
    int categoryId, {
    bool forceRefresh = false,
  }) async {
    // Check cache first (unless force refresh)
    if (!forceRefresh) {
      final cached = await _cacheService.getCachedContent(categoryId);
      if (cached != null && cached.isNotEmpty) {
        return ApiResponse(
          success: true,
          message: 'Loaded from cache',
          data: cached,
        );
      }
    }

    final token = await _storageService.getToken();

    // Note: API is now public for contents, so we can proceed without token (Guest Mode)

    // Fetch from API
    final response = await _apiService.get<Map<String, dynamic>>(
      '/categories/$categoryId/contents',
      token: token,
      fromJsonT: (data) => data as Map<String, dynamic>,
    );

    if (response.success && response.data != null) {
      final contentsData = response.data!['contents'] as List<dynamic>?;
      final contents = contentsData != null
          ? contentsData
                .map((e) => ContentModel.fromJson(e as Map<String, dynamic>))
                .toList()
          : <ContentModel>[];

      // Cache for offline use
      await _cacheService.cacheContent(categoryId, contents);

      return ApiResponse(
        success: true,
        message: response.message,
        data: contents,
      );
    }

    // API failed - try cache (even if expired for offline mode)
    final cached = await _cacheService.getCachedContent(categoryId);
    if (cached != null) {
      return ApiResponse(
        success: true,
        message: 'Loaded from cache (offline mode)',
        data: cached,
      );
    }

    return ApiResponse(success: false, message: response.message);
  }

  /// Get a single content by ID
  Future<ApiResponse<ContentModel>> getContentById(int id) async {
    final token = await _storageService.getToken();
    // Allow guest access (null token)

    final response = await _apiService.get<Map<String, dynamic>>(
      '/contents/$id',
      token: token,
      fromJsonT: (data) => data as Map<String, dynamic>,
    );

    if (response.success && response.data != null) {
      final content = ContentModel.fromJson(response.data!);
      return ApiResponse(
        success: true,
        message: response.message,
        data: content,
      );
    }

    return ApiResponse(success: false, message: response.message);
  }
}
