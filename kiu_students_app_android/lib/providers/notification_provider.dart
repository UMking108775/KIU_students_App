import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService;

  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _errorMessage;

  NotificationProvider({NotificationService? notificationService})
    : _notificationService = notificationService ?? NotificationService();

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchNotifications({bool refresh = false}) async {
    if (_isLoading && !refresh) return;

    _isLoading = true;
    _errorMessage = null;
    if (refresh) {
      notifyListeners();
    }

    final response = await _notificationService.getNotifications();

    _isLoading = false;

    if (response.success && response.data != null) {
      _notifications = response.data!;
      // Update unread count based on fetched list is not enough as there might be more
      // But we can calculate from this list if we want, or fetch count separately.
      // Better to fetch count separately to be accurate.
      fetchUnreadCount();
    } else {
      _errorMessage = response.message;
    }
    notifyListeners();
  }

  Future<void> fetchUnreadCount() async {
    final response = await _notificationService.getUnreadCount();
    if (response.success && response.data != null) {
      _unreadCount = response.data!;
      notifyListeners();
    }
  }

  Future<bool> markAsRead(int id) async {
    // Optimistic update
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      // Create modified copy
      // Note: Model is final, so we can't modify.
      // We could replace it, but simpler to just decrement count locally and wait for refresh?
      // Or we should allow making it mutable orcopyWith.
      // For now, let's call API.

      final response = await _notificationService.markAsRead(id);
      if (response.success) {
        _unreadCount = (_unreadCount - 1).clamp(0, 999);
        // Refresh list to update UI
        await fetchNotifications();
        return true;
      }
    }
    return false;
  }

  Future<bool> markAllAsRead() async {
    if (_unreadCount == 0) return true;

    // Optimistic
    final previousCount = _unreadCount;
    _unreadCount = 0;
    notifyListeners();

    final response = await _notificationService.markAllAsRead();

    if (response.success) {
      await fetchNotifications();
      return true;
    } else {
      // Revert
      _unreadCount = previousCount;
      notifyListeners();
      return false;
    }
  }
}
