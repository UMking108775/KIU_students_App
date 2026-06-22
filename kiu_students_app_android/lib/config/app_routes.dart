import 'package:flutter/material.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/support/help_support_screen.dart';
import '../screens/support/important_links_screen.dart';
import '../screens/notifications/notification_screen.dart';
import '../screens/tools/tools_hub_screen.dart';

/// App route definitions
class AppRoutes {
  // Route names
  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String dataLoading = '/data-loading';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String help = '/help';
  static const String importantLinks = '/important-links';
  static const String notifications = '/notifications';
  static const String tools = '/tools';

  // Initial route
  static const String initial = splash;

  // Route map
  static Map<String, WidgetBuilder> get routes => {
    splash: (context) => const SplashScreen(),
    login: (context) => const LoginScreen(),
    register: (context) => const RegisterScreen(),
    // dataLoading route removed
    home: (context) => const HomeScreen(),
    profile: (context) => const ProfileScreen(),
    help: (context) => const HelpSupportScreen(),
    importantLinks: (context) => const ImportantLinksScreen(),
    notifications: (context) => const NotificationScreen(),
    tools: (context) => const ToolsHubScreen(),
  };
}
