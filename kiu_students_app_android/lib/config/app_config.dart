/// App configuration constants
class AppConfig {
  // API Configuration
  static const String baseUrl = 'https://kiustudentsapp.ssatechs.com/api/v1';
  static const Duration apiTimeout = Duration(seconds: 30);

  // App Info
  static const String appName = 'KIU Students';
  static const String appVersion = '1.0.0';

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';

  // Validation
  static const int minPasswordLength = 6;
  static const int minKiuIdLength = 4;
  static const int maxKiuIdLength = 20;

  // Admin Contact
  static const String adminWhatsApp = '+966580165689';
  static const String adminWhatsAppDisplay = '+966 58 016 5689';
  static const String noAccessMessage =
      'Hello, I am a KIU student and I need access to study materials. '
      'My KIU ID is: ';
}
