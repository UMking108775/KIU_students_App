import 'package:flutter/material.dart';

import '../../config/app_theme.dart';

/// KIU's marks → grade → GPA scale and the predefined semester syllabus.
///
/// Mirrors the official KIU web GPA calculator: each subject is marked out of
/// 100 (Faculty /30 + Final /70), graded on a 5.0 scale.

/// The semantic colour of a grade badge.
enum GradeTone { success, normal, warning, danger }

/// A resolved grade for a given total-marks value.
class KiuGrade {
  final String letter;
  final double gpa;
  final GradeTone tone;
  const KiuGrade(this.letter, this.gpa, this.tone);

  Color color(ThemeColors colors) {
    switch (tone) {
      case GradeTone.success:
        return colors.success;
      case GradeTone.warning:
        return colors.warning;
      case GradeTone.danger:
        return colors.error;
      case GradeTone.normal:
        return colors.textSecondary;
    }
  }
}

/// The maximum GPA on KIU's scale.
const double kiuMaxGpa = 5.0;

/// Maximum allowed marks per field.
const int kFacultyMax = 30;
const int kFinalMax = 70;
const int kTotalMax = 100;

/// Resolves the grade for a total-marks value (0–100), or `null` when no marks
/// have been entered yet. Out-of-range marks return the "Invalid" sentinel.
KiuGrade? gradeForMarks(double? marks) {
  if (marks == null) return null;
  if (marks < 0 || marks > 100) {
    return const KiuGrade('Invalid', 0, GradeTone.danger);
  }
  if (marks >= 95) return const KiuGrade('A+', 5.0, GradeTone.success);
  if (marks >= 90) return const KiuGrade('A', 4.75, GradeTone.success);
  if (marks >= 85) return const KiuGrade('B+', 4.5, GradeTone.success);
  if (marks >= 80) return const KiuGrade('B', 4.0, GradeTone.success);
  if (marks >= 75) return const KiuGrade('C+', 3.75, GradeTone.normal);
  if (marks >= 70) return const KiuGrade('C', 3.0, GradeTone.normal);
  if (marks >= 65) return const KiuGrade('D+', 2.75, GradeTone.warning);
  if (marks >= 60) return const KiuGrade('D', 2.0, GradeTone.warning);
  if (marks >= 50) return const KiuGrade('F', 1.0, GradeTone.danger);
  return const KiuGrade('F', 0.0, GradeTone.danger);
}

/// A predefined subject (name + credit hours).
class PredefinedSubject {
  final String name;
  final int credits;
  const PredefinedSubject(this.name, this.credits);
}

/// The official KIU syllabus for semesters 1–8. Picking a semester from the
/// dropdown seeds these exact subjects and credit hours.
const Map<int, List<PredefinedSubject>> kiuPredefinedSemesters = {
  1: [
    PredefinedSubject('سیرت نبوی (1) (ش1)', 2),
    PredefinedSubject('فقه طهارت (1) (ش1)', 3),
    PredefinedSubject('عقیده (1) (ش1)', 3),
    PredefinedSubject('حدیث شریف (1) (ش1)', 3),
    PredefinedSubject('تجوید (1) (ش1)', 2),
    PredefinedSubject('تفسیر قرآن کریم (1) (ش1)', 2),
    PredefinedSubject('عربی زبان (1) (ش1)', 3),
  ],
  2: [
    PredefinedSubject('تجوید (2)', 2),
    PredefinedSubject('تفسیر قرآن کریم (2)', 2),
    PredefinedSubject('حدیث شریف (2)', 3),
    PredefinedSubject('سیرت نبوی (2)', 2),
    PredefinedSubject('عربی زبان (2)', 3),
    PredefinedSubject('عقیده (2)', 3),
    PredefinedSubject('فقه صلاة (2)', 3),
  ],
  3: [
    PredefinedSubject('تفسیر قرآن کریم (3)', 2),
    PredefinedSubject('حدیث شریف (3)', 3),
    PredefinedSubject('عقیده (3)', 3),
    PredefinedSubject('فقه زكاة و صيام (3)', 3),
    PredefinedSubject('صرف (1)', 2),
    PredefinedSubject('عربی زبان (3)', 3),
    PredefinedSubject('مصطلح الحدیث (1)', 2),
    PredefinedSubject('رسرچ حال', 2),
  ],
  4: [
    PredefinedSubject('حدیث شریف (4)', 3),
    PredefinedSubject('تفسیر قرآن کریم (4)', 2),
    PredefinedSubject('فقه حج (4)', 3),
    PredefinedSubject('عقیده (4)', 3),
    PredefinedSubject('علوم قرآن (1)', 2),
    PredefinedSubject('مصطلح الحدیث (2)', 2),
    PredefinedSubject('علم صرف (2)', 2),
    PredefinedSubject('اصلاحی دعوت', 2),
  ],
  5: [
    PredefinedSubject('اصول فقه (1)', 2),
    PredefinedSubject('فقه اسرة (5)', 3),
    PredefinedSubject('عقیده (5)', 3),
    PredefinedSubject('مصطلح الحدیث (3)', 2),
    PredefinedSubject('حدیث شریف (5)', 3),
    PredefinedSubject('علوم قرآن (2)', 2),
    PredefinedSubject('تفسیر قرآن کریم (5)', 3),
    PredefinedSubject('نحو (1)', 3),
  ],
  6: [
    PredefinedSubject('نحو (2)', 3),
    PredefinedSubject('اصول فقه (2)', 2),
    PredefinedSubject('حدیث شریف (6)', 3),
    PredefinedSubject('فقه معاملات (6)', 3),
    PredefinedSubject('عقیده (6)', 3),
    PredefinedSubject('علوم قرآن کریم (3)', 2),
    PredefinedSubject('تفسیر قرآن کریم (6)', 3),
  ],
  7: [
    PredefinedSubject('نحو 3', 3),
    PredefinedSubject('دراسة ادیان و مذاہب 1', 3),
    PredefinedSubject('فقه معاملات و جنایات 7', 3),
    PredefinedSubject('عقیده 7', 3),
    PredefinedSubject('تخریج حدیث', 3),
    PredefinedSubject('حدیث شریف 7', 3),
    PredefinedSubject('تفسیر قرآن کریم 7', 3),
  ],
  8: [
    PredefinedSubject('دراسة ادیان و مذاہب (2)', 3),
    PredefinedSubject('بحث التخرج', 4),
    PredefinedSubject('فقه وراثت (8)', 3),
    PredefinedSubject('دراسة اسانید', 3),
    PredefinedSubject('تفسیر قرآن کریم (8)', 3),
    PredefinedSubject('حدیث شریف (8)', 3),
  ],
};
