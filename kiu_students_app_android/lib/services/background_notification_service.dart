import 'dart:async';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Background notification service for checking new notifications
/// and showing local push notifications
class BackgroundNotificationService {
  static const String _taskName = 'notificationCheck';
  static const String _lastUnreadCountKey = 'last_unread_count';

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Initialize the local notifications plugin
  static Future<void> initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Request permissions for Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  /// Handle notification tap
  static void _onNotificationTap(NotificationResponse response) {
    // The app will be opened, and the notification screen can be navigated to
    // This is handled by the app's navigation when it opens
  }

  /// Initialize workmanager for background tasks
  static Future<void> initializeWorkmanager() async {
    await Workmanager().initialize(callbackDispatcher);

    // Register periodic task - runs every 15 minutes
    await Workmanager().registerPeriodicTask(
      _taskName,
      _taskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  /// Cancel all background tasks
  static Future<void> cancelBackgroundTasks() async {
    await Workmanager().cancelAll();
  }

  /// Check for new notifications and show push notification if found
  static Future<void> checkForNewNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        return; // Not logged in
      }

      // Fetch unread count from API
      final response = await http
          .get(
            Uri.parse('${AppConfig.baseUrl}/notifications/count'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final currentUnreadCount = data['data']['count'] as int? ?? 0;
          final lastUnreadCount = prefs.getInt(_lastUnreadCountKey) ?? 0;

          // If there are more unread notifications than before, show push notification
          if (currentUnreadCount > lastUnreadCount && currentUnreadCount > 0) {
            await _showNotification(
              title: 'New Notifications',
              body:
                  'You have $currentUnreadCount unread notification${currentUnreadCount > 1 ? 's' : ''}',
            );
          }

          // Update stored count
          await prefs.setInt(_lastUnreadCountKey, currentUnreadCount);
        }
      }
    } catch (e) {
      // Silently fail in background
    }
  }

  /// Show a local push notification
  static Future<void> _showNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'kiu_notifications',
      'KIU Notifications',
      channelDescription: 'Notifications from KIU Students App',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  /// Reset the stored notification count (call when user reads notifications)
  static Future<void> resetStoredCount() async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt(_lastUnreadCountKey) ?? 0;
    // Keep current count so we don't re-notify for same notifications
    await prefs.setInt(_lastUnreadCountKey, currentCount);
  }

  /// Update stored count to match current count
  static Future<void> updateStoredCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastUnreadCountKey, count);
  }
}

/// Workmanager callback dispatcher - must be top-level function
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == BackgroundNotificationService._taskName) {
      await BackgroundNotificationService.checkForNewNotifications();
    }
    return true;
  });
}
