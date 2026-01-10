import 'package:shared_preferences/shared_preferences.dart';

/// Service to track weekly portal visits
class PortalVisitService {
  static const _lastVisitKey = 'portal_last_visit';
  static const _weekInMillis = 7 * 24 * 60 * 60 * 1000; // 7 days

  /// Check if user needs to visit portal this week
  Future<bool> needsWeeklyVisit() async {
    final prefs = await SharedPreferences.getInstance();
    final lastVisit = prefs.getInt(_lastVisitKey);

    if (lastVisit == null) return true;

    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - lastVisit) > _weekInMillis;
  }

  /// Mark portal as visited
  Future<void> markVisit() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastVisitKey, DateTime.now().millisecondsSinceEpoch);
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
}
