import '../models/api_response.dart';
import '../models/content_model.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Content service for fetching materials
class ContentService {
  final ApiService _apiService;
  final StorageService _storageService;

  ContentService({
    required ApiService apiService,
    required StorageService storageService,
  }) : _apiService = apiService,
       _storageService = storageService;

  /// Get contents for a specific category
  Future<ApiResponse<List<ContentModel>>> getContentsByCategory(
    int categoryId,
  ) async {
    final token = await _storageService.getToken();
    if (token == null) {
      return ApiResponse(
        success: false,
        message: 'Please login to access contents',
      );
    }

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

      return ApiResponse(
        success: true,
        message: response.message,
        data: contents,
      );
    }

    return ApiResponse(success: false, message: response.message);
  }

  /// Get a single content by ID
  Future<ApiResponse<ContentModel>> getContentById(int id) async {
    final token = await _storageService.getToken();
    if (token == null) {
      return ApiResponse(
        success: false,
        message: 'Please login to access content',
      );
    }

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
