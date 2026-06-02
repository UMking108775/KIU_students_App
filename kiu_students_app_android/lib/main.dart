import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'config/app_routes.dart';
import 'config/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/category_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/theme_provider.dart';
import 'services/api_service.dart';
import 'services/audio_service.dart';
import 'services/connectivity_service.dart';
import 'services/background_notification_service.dart';
import 'services/background_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Background Audio
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.kiustudents.app.channel.audio',
    androidNotificationChannelName: 'Audio Playback',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'drawable/ic_notification',
  );

  // Initialize local notifications
  await BackgroundNotificationService.initializeNotifications();

  // Initialize workmanager for background tasks
  await BackgroundNotificationService.initializeWorkmanager();

  // Initialize background sync service
  final backgroundSyncService = BackgroundSyncService();
  backgroundSyncService.initialize();

  // Initialize theme provider
  final themeProvider = ThemeProvider();
  await themeProvider.initialize();

  // Handle expired/invalid tokens (401 on authenticated requests):
  // clear the session and force re-login.
  ApiService.onUnauthorized = () async {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final didExpire = await authProvider.handleSessionExpired();
    if (didExpire) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );
    }
  };

  runApp(KIUStudentsApp(themeProvider: themeProvider));
}

/// Global navigator key so non-widget code (e.g. the 401 handler) can navigate.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class KIUStudentsApp extends StatelessWidget {
  final ThemeProvider themeProvider;

  const KIUStudentsApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ChangeNotifierProvider.value(value: AudioService()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider.value(value: BackgroundSyncService()),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'KIU Urdu',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.materialThemeMode,
            initialRoute: AppRoutes.initial,
            routes: AppRoutes.routes,
          );
        },
      ),
    );
  }
}
