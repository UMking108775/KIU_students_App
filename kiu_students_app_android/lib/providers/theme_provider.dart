import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode options
enum AppThemeMode {
  system, // Follow device setting
  light, // Always light
  dark, // Always dark
}

/// Theme provider for managing app theme state
/// Persists theme preference to local storage
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'app_theme_mode';

  AppThemeMode _themeMode = AppThemeMode.system;
  bool _isInitialized = false;

  AppThemeMode get themeMode => _themeMode;
  bool get isInitialized => _isInitialized;

  /// Get the current ThemeMode for MaterialApp
  ThemeMode get materialThemeMode {
    switch (_themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  /// Initialize - load saved preference
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_themeKey);

      if (savedMode != null) {
        _themeMode = AppThemeMode.values.firstWhere(
          (e) => e.name == savedMode,
          orElse: () => AppThemeMode.system,
        );
      }
    } catch (e) {
      debugPrint('[ThemeProvider] Error loading theme: $e');
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Set theme mode and persist
  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, mode.name);
    } catch (e) {
      debugPrint('[ThemeProvider] Error saving theme: $e');
    }
  }

  /// Toggle between light and dark (ignoring system)
  Future<void> toggleTheme() async {
    if (_themeMode == AppThemeMode.dark) {
      await setThemeMode(AppThemeMode.light);
    } else {
      await setThemeMode(AppThemeMode.dark);
    }
  }

  /// Check if currently in dark mode (for UI checks)
  bool isDarkMode(BuildContext context) {
    if (_themeMode == AppThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return _themeMode == AppThemeMode.dark;
  }
}
