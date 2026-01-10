import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/support/help_support_screen.dart';
import '../screens/notifications/notification_screen.dart';

/// App route definitions
class AppRoutes {
  // Route names
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String help = '/help';
  static const String notifications = '/notifications';

  // Initial route
  static const String initial = login;

  // Route map
  static Map<String, WidgetBuilder> get routes => {
    login: (context) => const LoginScreen(),
    register: (context) => const RegisterScreen(),
    home: (context) => const HomeScreen(),
    profile: (context) => const ProfileScreen(),
    help: (context) => const HelpSupportScreen(),
    notifications: (context) => const NotificationScreen(),
  };
}
