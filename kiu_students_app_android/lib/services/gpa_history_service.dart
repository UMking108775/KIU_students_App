import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A saved GPA calculation.
class GpaResult {
  /// Unique id (milliseconds since epoch of when it was saved).
  final int id;
  final double gpa;
  final double scaleMax;
  final double totalCredits;
  final int courseCount;
  final String? label;
  final DateTime savedAt;

  const GpaResult({
    required this.id,
    required this.gpa,
    required this.scaleMax,
    required this.totalCredits,
    required this.courseCount,
    required this.savedAt,
    this.label,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'gpa': gpa,
        'scale_max': scaleMax,
        'total_credits': totalCredits,
        'course_count': courseCount,
        'label': label,
        'saved_at': savedAt.toIso8601String(),
      };

  factory GpaResult.fromJson(Map<String, dynamic> json) => GpaResult(
        id: json['id'] as int,
        gpa: (json['gpa'] as num).toDouble(),
        scaleMax: (json['scale_max'] as num).toDouble(),
        totalCredits: (json['total_credits'] as num).toDouble(),
        courseCount: json['course_count'] as int? ?? 0,
        label: json['label'] as String?,
        savedAt: DateTime.parse(json['saved_at'] as String),
      );
}

/// Stores GPA results so students can review past calculations.
class GpaHistoryService {
  static const String _key = 'gpa_history';

  /// All saved results, newest first.
  Future<List<GpaResult>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_key);
    if (str == null || str.isEmpty) return [];
    try {
      final list = jsonDecode(str) as List<dynamic>;
      final results = list
          .map((e) => GpaResult.fromJson(e as Map<String, dynamic>))
          .toList();
      results.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      return results;
    } catch (_) {
      return [];
    }
  }

  Future<void> add(GpaResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await getAll();
    all.add(result);
    await prefs.setString(
      _key,
      jsonEncode(all.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> deleteById(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await getAll();
    all.removeWhere((e) => e.id == id);
    await prefs.setString(
      _key,
      jsonEncode(all.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
