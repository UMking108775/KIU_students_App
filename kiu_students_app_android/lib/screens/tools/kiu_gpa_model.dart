import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kiu_gpa_data.dart';

/// One subject row. Holds its own text controllers so the UI can edit it
/// directly; derived values (total, grade, points) are computed on the fly.
class GpaSubject {
  final String id;
  final TextEditingController name;
  final TextEditingController faculty; // out of 30
  final TextEditingController finalMarks; // out of 70
  final TextEditingController credits;

  GpaSubject({
    required this.id,
    required this.name,
    required this.faculty,
    required this.finalMarks,
    required this.credits,
  });

  factory GpaSubject.create({
    required String id,
    String name = '',
    String faculty = '',
    String finalMarks = '',
    int credits = 3,
  }) {
    return GpaSubject(
      id: id,
      name: TextEditingController(text: name),
      faculty: TextEditingController(text: faculty),
      finalMarks: TextEditingController(text: finalMarks),
      credits: TextEditingController(text: credits.toString()),
    );
  }

  double? _parse(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  double? get facultyVal => _parse(faculty.text);
  double? get finalVal => _parse(finalMarks.text);
  int get creditVal => int.tryParse(credits.text.trim()) ?? 0;

  bool get facultyError => (facultyVal ?? 0) > kFacultyMax || (facultyVal ?? 0) < 0;
  bool get finalError => (finalVal ?? 0) > kFinalMax || (finalVal ?? 0) < 0;

  /// Combined marks (Faculty + Final), or null when neither has been entered.
  double? get totalMarks {
    if (faculty.text.trim().isEmpty && finalMarks.text.trim().isEmpty) {
      return null;
    }
    return (facultyVal ?? 0) + (finalVal ?? 0);
  }

  bool get totalError {
    final t = totalMarks;
    return t != null && (t > kTotalMax || t < 0);
  }

  bool get hasError => facultyError || finalError || totalError;

  KiuGrade? get grade => hasError ? null : gradeForMarks(totalMarks);

  /// Whether this subject contributes to the GPA (valid marks + credits).
  bool get counts {
    final t = totalMarks;
    return !hasError && t != null && t >= 0 && t <= kTotalMax && creditVal > 0;
  }

  double get points {
    if (!counts) return 0;
    return (grade?.gpa ?? 0) * creditVal;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name.text,
        'faculty': faculty.text,
        'final': finalMarks.text,
        'credits': credits.text,
      };

  factory GpaSubject.fromJson(Map<String, dynamic> json) => GpaSubject(
        id: json['id'] as String,
        name: TextEditingController(text: json['name'] as String? ?? ''),
        faculty: TextEditingController(text: json['faculty'] as String? ?? ''),
        finalMarks: TextEditingController(text: json['final'] as String? ?? ''),
        credits: TextEditingController(text: json['credits'] as String? ?? '3'),
      );

  void dispose() {
    name.dispose();
    faculty.dispose();
    finalMarks.dispose();
    credits.dispose();
  }
}

/// A semester: a title plus its subjects.
class GpaSemester {
  final String id;
  final TextEditingController title;
  final List<GpaSubject> subjects;

  GpaSemester({
    required this.id,
    required this.title,
    required this.subjects,
  });

  double get totalCredits {
    var c = 0.0;
    for (final s in subjects) {
      if (s.counts) c += s.creditVal;
    }
    return c;
  }

  double get totalPoints {
    var p = 0.0;
    for (final s in subjects) {
      p += s.points;
    }
    return p;
  }

  /// Quarterly GPA for this semester (0 when nothing valid is entered).
  double get gpa {
    final c = totalCredits;
    return c > 0 ? totalPoints / c : 0;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': title.text,
        'subjects': subjects.map((s) => s.toJson()).toList(),
      };

  factory GpaSemester.fromJson(Map<String, dynamic> json) => GpaSemester(
        id: json['id'] as String,
        title: TextEditingController(text: json['name'] as String? ?? 'Semester'),
        subjects: ((json['subjects'] as List<dynamic>?) ?? [])
            .map((e) => GpaSubject.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  void dispose() {
    title.dispose();
    for (final s in subjects) {
      s.dispose();
    }
  }
}

/// Persists the working set of semesters (like the web tool's localStorage).
class KiuGpaStore {
  static const String _key = 'kiu_gpa_calculator_v1';

  Future<List<GpaSemester>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_key);
    if (str == null || str.isEmpty) return [];
    try {
      final list = jsonDecode(str) as List<dynamic>;
      return list
          .map((e) => GpaSemester.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<GpaSemester> semesters) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(semesters.map((s) => s.toJson()).toList()),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
