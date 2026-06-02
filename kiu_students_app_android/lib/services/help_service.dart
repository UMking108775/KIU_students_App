import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/api_response.dart';
import '../models/support_models.dart';
import 'api_service.dart';
import 'cache_service.dart';
import 'storage_service.dart';

class HelpService {
  final ApiService _apiService;
  final StorageService _storageService;
  final CacheService _cacheService;

  HelpService({
    required ApiService apiService,
    StorageService? storageService,
    CacheService? cacheService,
  }) : _apiService = apiService,
       _storageService = storageService ?? StorageService(),
       _cacheService = cacheService ?? CacheService();

  /// Get all FAQs from API (with caching)
  Future<ApiResponse<List<FaqModel>>> getFaqs({
    bool forceRefresh = false,
  }) async {
    // Check cache first
    if (!forceRefresh) {
      final cached = await _cacheService.getCachedFaqs();
      if (cached != null && cached.isNotEmpty) {
        return ApiResponse(
          success: true,
          message: 'Loaded from cache',
          data: cached,
        );
      }
    }

    final token = await _storageService.getToken();
    if (token == null) {
      // Try cached data when no token
      final cached = await _cacheService.getCachedFaqs();
      if (cached != null) {
        return ApiResponse(
          success: true,
          message: 'Offline mode',
          data: cached,
        );
      }
      return ApiResponse(success: false, message: 'Please login first');
    }

    try {
      final response = await _apiService.get('/support/faqs', token: token);

      if (response.success && response.data != null) {
        final faqsData = response.data['faqs'] as List<dynamic>? ?? [];
        final faqs = faqsData.map((e) => FaqModel.fromJson(e)).toList();

        // Cache FAQs
        await _cacheService.cacheFaqs(faqs);

        return ApiResponse(
          success: true,
          message: response.message,
          data: faqs,
        );
      }

      // Try cached on API failure
      final cached = await _cacheService.getCachedFaqs();
      if (cached != null) {
        return ApiResponse(
          success: true,
          message: 'Offline mode',
          data: cached,
        );
      }

      return ApiResponse(success: false, message: response.message);
    } catch (e) {
      // Return cached on error
      final cached = await _cacheService.getCachedFaqs();
      if (cached != null) {
        return ApiResponse(
          success: true,
          message: 'Offline mode',
          data: cached,
        );
      }
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
      // Append device info to message significantly for admin context
      String finalMessage = message;
      try {
        if (Platform.isAndroid) {
          final deviceInfo = DeviceInfoPlugin();
          final androidInfo = await deviceInfo.androidInfo;

          final deviceDetails =
              '\n\n--------------------------------\n'
              'Device Info:\n'
              '• Device: ${androidInfo.brand.toUpperCase()} ${androidInfo.model}\n'
              '• OS: Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})\n'
              '• Firmware: ${androidInfo.display}\n'
              '• Hardware: ${androidInfo.hardware}';

          finalMessage = '$message$deviceDetails';
        }
      } catch (e) {
        // Find silently if device info fails, don't block ticket submission
        debugPrint('Failed to get device info: $e');
      }

      final response = await _apiService.post(
        '/support/submit',
        token: token,
        body: {'subject': subject, 'message': finalMessage},
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

  /// Get user's support tickets (with caching)
  Future<ApiResponse<List<SupportTicket>>> getMyTickets({
    bool forceRefresh = false,
  }) async {
    // Check cache first
    if (!forceRefresh) {
      final cached = await _cacheService.getCachedTickets();
      if (cached != null && cached.isNotEmpty) {
        return ApiResponse(
          success: true,
          message: 'Loaded from cache',
          data: cached,
        );
      }
    }

    final token = await _storageService.getToken();
    if (token == null) {
      final cached = await _cacheService.getCachedTickets();
      if (cached != null) {
        return ApiResponse(
          success: true,
          message: 'Offline mode',
          data: cached,
        );
      }
      return ApiResponse(success: false, message: 'Please login first');
    }

    try {
      final response = await _apiService.get('/support/tickets', token: token);

      if (response.success && response.data != null) {
        final ticketsData = response.data['tickets'] as List<dynamic>? ?? [];
        final tickets = ticketsData
            .map((e) => SupportTicket.fromJson(e))
            .toList();

        // Cache tickets
        await _cacheService.cacheTickets(tickets);

        return ApiResponse(
          success: true,
          message: response.message,
          data: tickets,
        );
      }

      final cached = await _cacheService.getCachedTickets();
      if (cached != null) {
        return ApiResponse(
          success: true,
          message: 'Offline mode',
          data: cached,
        );
      }

      return ApiResponse(success: false, message: response.message);
    } catch (e) {
      final cached = await _cacheService.getCachedTickets();
      if (cached != null) {
        return ApiResponse(
          success: true,
          message: 'Offline mode',
          data: cached,
        );
      }
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

  /// Get all Important Links from API (with caching)
  Future<ApiResponse<List<ImportantLinkModel>>> getImportantLinks({
    bool forceRefresh = false,
  }) async {
    // Check cache first
    if (!forceRefresh) {
      final cached = await _cacheService.getCachedImportantLinks();
      if (cached != null && cached.isNotEmpty) {
        return ApiResponse(
          success: true,
          message: 'Loaded from cache',
          data: cached,
        );
      }
    }

    // Note: Important Links API is public, no token required
    try {
      final response = await _apiService.get('/important-links', token: null);

      if (response.success && response.data != null) {
        final linksData = response.data['links'] as List<dynamic>? ?? [];
        final links = linksData
            .map((e) => ImportantLinkModel.fromJson(e))
            .toList();

        // Cache Important Links
        await _cacheService.cacheImportantLinks(links);

        return ApiResponse(
          success: true,
          message: response.message,
          data: links,
        );
      }

      // Try cached on API failure
      final cached = await _cacheService.getCachedImportantLinks();
      if (cached != null) {
        return ApiResponse(
          success: true,
          message: 'Offline mode',
          data: cached,
        );
      }

      return ApiResponse(success: false, message: response.message);
    } catch (e) {
      // Return cached on error
      final cached = await _cacheService.getCachedImportantLinks();
      if (cached != null) {
        return ApiResponse(
          success: true,
          message: 'Offline mode',
          data: cached,
        );
      }
      return ApiResponse(
        success: false,
        message: 'Failed to load important links: $e',
      );
    }
  }
}
