import '../models/api_response.dart';
import '../models/notification_model.dart';
import 'api_service.dart';
import 'storage_service.dart';

class NotificationService {
  final ApiService _apiService;
  final StorageService _storageService;

  NotificationService({ApiService? apiService, StorageService? storageService})
    : _apiService = apiService ?? ApiService(),
      _storageService = storageService ?? StorageService();

  Future<ApiResponse<List<NotificationModel>>> getNotifications({
    int limit = 20,
  }) async {
    final token = await _storageService.getToken();
    if (token == null) {
      return ApiResponse.error('No token found');
    }

    return _apiService.get<List<NotificationModel>>(
      '/notifications?limit=$limit',
      token: token,
      fromJsonT: (json) {
        if (json is Map<String, dynamic> && json.containsKey('notifications')) {
          final list = json['notifications'] as List;
          return list.map((item) => NotificationModel.fromJson(item)).toList();
        }
        return [];
      },
    );
  }

  Future<ApiResponse<int>> getUnreadCount() async {
    final token = await _storageService.getToken();
    if (token == null) {
      return ApiResponse.error('No token found');
    }

    return _apiService.get<int>(
      '/notifications/count',
      token: token,
      fromJsonT: (json) {
        if (json is Map<String, dynamic> && json.containsKey('count')) {
          return json['count'] as int;
        }
        return 0;
      },
    );
  }

  Future<ApiResponse<void>> markAsRead(int id) async {
    final token = await _storageService.getToken();
    if (token == null) {
      return ApiResponse.error('No token found');
    }

    return _apiService.post<void>(
      '/notifications/$id/mark-read',
      token: token,
      fromJsonT: (_) {},
    );
  }

  Future<ApiResponse<void>> markAllAsRead() async {
    final token = await _storageService.getToken();
    if (token == null) {
      return ApiResponse.error('No token found');
    }

    return _apiService.post<void>(
      '/notifications/mark-all-read',
      token: token,
      fromJsonT: (_) {},
    );
  }
}
