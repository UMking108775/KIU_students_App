import '../models/api_response.dart';
import '../models/support_models.dart';
import 'api_service.dart';
import 'storage_service.dart';

class HelpService {
  final ApiService _apiService;
  final StorageService _storageService;

  HelpService({required ApiService apiService, StorageService? storageService})
    : _apiService = apiService,
      _storageService = storageService ?? StorageService();

  /// Get all FAQs from API
  Future<ApiResponse<List<FaqModel>>> getFaqs() async {
    final token = await _storageService.getToken();
    if (token == null) {
      return ApiResponse(success: false, message: 'Please login first');
    }

    try {
      final response = await _apiService.get('/support/faqs', token: token);

      if (response.success && response.data != null) {
        final faqsData = response.data['faqs'] as List<dynamic>? ?? [];
        final faqs = faqsData.map((e) => FaqModel.fromJson(e)).toList();
        return ApiResponse(
          success: true,
          message: response.message,
          data: faqs,
        );
      }

      return ApiResponse(success: false, message: response.message);
    } catch (e) {
      return ApiResponse(success: false, message: 'Failed to load FAQs: $e');
    }
  }

  /// Submit a support ticket
  Future<ApiResponse<SupportTicket?>> submitTicket(
    String subject,
    String message,
  ) async {
    final token = await _storageService.getToken();
    if (token == null) {
      return ApiResponse(success: false, message: 'Please login first');
    }

    try {
      final response = await _apiService.post(
        '/support/submit',
        token: token,
        body: {'subject': subject, 'message': message},
      );

      if (response.success && response.data != null) {
        final ticket = SupportTicket.fromJson(response.data);
        return ApiResponse(
          success: true,
          message: response.message,
          data: ticket,
        );
      }

      return ApiResponse(success: false, message: response.message);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Failed to submit ticket: $e',
      );
    }
  }

  /// Get user's support tickets
  Future<ApiResponse<List<SupportTicket>>> getMyTickets() async {
    final token = await _storageService.getToken();
    if (token == null) {
      return ApiResponse(success: false, message: 'Please login first');
    }

    try {
      final response = await _apiService.get('/support/tickets', token: token);

      if (response.success && response.data != null) {
        final ticketsData = response.data['tickets'] as List<dynamic>? ?? [];
        final tickets = ticketsData
            .map((e) => SupportTicket.fromJson(e))
            .toList();
        return ApiResponse(
          success: true,
          message: response.message,
          data: tickets,
        );
      }

      return ApiResponse(success: false, message: response.message);
    } catch (e) {
      return ApiResponse(success: false, message: 'Failed to load tickets: $e');
    }
  }

  /// Get a specific ticket detail
  Future<ApiResponse<SupportTicket?>> getTicket(int id) async {
    final token = await _storageService.getToken();
    if (token == null) {
      return ApiResponse(success: false, message: 'Please login first');
    }

    try {
      final response = await _apiService.get(
        '/support/tickets/$id',
        token: token,
      );

      if (response.success && response.data != null) {
        final ticket = SupportTicket.fromJson(response.data);
        return ApiResponse(
          success: true,
          message: response.message,
          data: ticket,
        );
      }

      return ApiResponse(success: false, message: response.message);
    } catch (e) {
      return ApiResponse(success: false, message: 'Failed to load ticket: $e');
    }
  }
}
