import 'package:shared_preferences/shared_preferences.dart';

/// Service to track weekly portal visits and logins
class PortalVisitService {
  static const _lastVisitKey = 'portal_last_visit';
  static const _lastLoginKey = 'portal_last_login';
  static const _weekInMillis = 7 * 24 * 60 * 60 * 1000; // 7 days

  /// Check if user needs to visit portal this week
  Future<bool> needsWeeklyVisit() async {
    final prefs = await SharedPreferences.getInstance();
    final lastVisit = prefs.getInt(_lastVisitKey);

    if (lastVisit == null) return true;

    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - lastVisit) > _weekInMillis;
  }

  /// Check if user needs to login to portal this week
  Future<bool> needsWeeklyLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final lastLogin = prefs.getInt(_lastLoginKey);

    if (lastLogin == null) return true;

    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - lastLogin) > _weekInMillis;
  }

  /// Mark portal as visited
  Future<void> markVisit() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastVisitKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Mark portal login as completed
  Future<void> markLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastLoginKey, DateTime.now().millisecondsSinceEpoch);
    // Also mark as visited
    await markVisit();
  }

  /// Check if URL indicates successful login (user is on dashboard/my page)
  bool isLoggedInUrl(String url) {
    final lowerUrl = url.toLowerCase();
    // Common Moodle logged-in URLs
    return lowerUrl.contains('/my/') ||
        lowerUrl.contains('/user/') ||
        lowerUrl.contains('/course/') ||
        lowerUrl.contains('/mod/') ||
        lowerUrl.contains('/calendar/') ||
        lowerUrl.contains('/message/') ||
        lowerUrl.contains('/grade/') ||
        (lowerUrl.contains('ur.kiu.org') && !lowerUrl.contains('/login/'));
  }

  /// Get days until next required login
  Future<int> daysUntilLoginRequired() async {
    final prefs = await SharedPreferences.getInstance();
    final lastLogin = prefs.getInt(_lastLoginKey);

    if (lastLogin == null) return 0;

    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - lastLogin;
    final remaining = _weekInMillis - elapsed;

    if (remaining <= 0) return 0;
    return (remaining / (24 * 60 * 60 * 1000)).ceil();
  }

  /// Get days until next required visit
  Future<int> daysUntilRequired() async {
    final prefs = await SharedPreferences.getInstance();
    final lastVisit = prefs.getInt(_lastVisitKey);

    if (lastVisit == null) return 0;

    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - lastVisit;
    final remaining = _weekInMillis - elapsed;

    if (remaining <= 0) return 0;
    return (remaining / (24 * 60 * 60 * 1000)).ceil();
  }

  /// Get last visit date as formatted string
  Future<String?> getLastVisitFormatted() async {
    final prefs = await SharedPreferences.getInstance();
    final lastVisit = prefs.getInt(_lastVisitKey);

    if (lastVisit == null) return null;

    final date = DateTime.fromMillisecondsSinceEpoch(lastVisit);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${diff.inDays} days ago';
    }
  }

  /// Get last login date as formatted string
  Future<String?> getLastLoginFormatted() async {
    final prefs = await SharedPreferences.getInstance();
    final lastLogin = prefs.getInt(_lastLoginKey);

    if (lastLogin == null) return 'Never';

    final date = DateTime.fromMillisecondsSinceEpoch(lastLogin);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${diff.inDays} days ago';
    }
  }
}
