import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_theme.dart';
import '../../services/gpa_history_service.dart';
import 'gpa_history_screen.dart';

/// A letter grade and the grade points it is worth on a given scale.
class _GradeOption {
  final String label;
  final double points;
  const _GradeOption(this.label, this.points);
}

/// A grading scale (its maximum GPA and the letter→points table).
class _GpaScale {
  final String id;
  final double max;
  final List<_GradeOption> grades;
  const _GpaScale(this.id, this.max, this.grades);
}

/// Common scales. Points use widely-used defaults; students can verify each
/// letter's points (shown in the dropdown) against their transcript.
const List<_GpaScale> _scales = [
  _GpaScale('4.0', 4.0, [
    _GradeOption('A+', 4.0),
    _GradeOption('A', 4.0),
    _GradeOption('A-', 3.7),
    _GradeOption('B+', 3.3),
    _GradeOption('B', 3.0),
    _GradeOption('B-', 2.7),
    _GradeOption('C+', 2.3),
    _GradeOption('C', 2.0),
    _GradeOption('C-', 1.7),
    _GradeOption('D+', 1.3),
    _GradeOption('D', 1.0),
    _GradeOption('F', 0.0),
  ]),
  _GpaScale('5.0', 5.0, [
    _GradeOption('A', 5.0),
    _GradeOption('B', 4.0),
    _GradeOption('C', 3.0),
    _GradeOption('D', 2.0),
    _GradeOption('E', 1.0),
    _GradeOption('F', 0.0),
  ]),
  _GpaScale('10.0', 10.0, [
    _GradeOption('O', 10.0),
    _GradeOption('A+', 9.0),
    _GradeOption('A', 8.0),
    _GradeOption('B+', 7.0),
    _GradeOption('B', 6.0),
    _GradeOption('C', 5.0),
    _GradeOption('D', 4.0),
    _GradeOption('F', 0.0),
  ]),
];

/// One course row: a name, credit hours, and the selected grade (by index into
/// the current scale's grade list).
class _Course {
  final TextEditingController name;
  final TextEditingController credits;

  /// Custom grade-points input, used when [gradeIndex] is [customGradeIndex].
  final TextEditingController custom;

  /// Index into the current scale's grades, or [customGradeIndex] for a
  /// student-entered points value.
  int gradeIndex = 0;

  _Course({
    required this.name,
    required this.credits,
    required this.custom,
  });

  void dispose() {
    name.dispose();
    credits.dispose();
    custom.dispose();
  }
}

/// Sentinel [_Course.gradeIndex] value meaning "custom points entered".
const int customGradeIndex = -1;

/// Tool: calculate GPA on a selectable scale (out of 4.0, 5.0, 10.0).
class GpaCalculatorScreen extends StatefulWidget {
  const GpaCalculatorScreen({super.key});

  @override
  State<GpaCalculatorScreen> createState() => _GpaCalculatorScreenState();
}

class _GpaCalculatorScreenState extends State<GpaCalculatorScreen> {
  final GpaHistoryService _history = GpaHistoryService();
  int _scaleIndex = 0;
  final List<_Course> _courses = [];

  _GpaScale get _scale => _scales[_scaleIndex];

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 3; i++) {
      _courses.add(_newCourse());
    }
  }

  @override
  void dispose() {
    for (final c in _courses) {
      c.dispose();
    }
    super.dispose();
  }

  _Course _newCourse() => _Course(
        name: TextEditingController(),
        credits: TextEditingController(),
        custom: TextEditingController(),
      );

  void _addCourse() {
    setState(() => _courses.add(_newCourse()));
  }

  void _removeCourse(int index) {
    setState(() {
      _courses.removeAt(index).dispose();
    });
  }

  void _changeScale(int index) {
    setState(() {
      _scaleIndex = index;
      final max = _scale.grades.length - 1;
      for (final c in _courses) {
        // Keep custom grades as-is; clamp letter grades to the new scale.
        if (c.gradeIndex != customGradeIndex && c.gradeIndex > max) {
          c.gradeIndex = max;
        }
      }
    });
  }

  void _clearAll() {
    setState(() {
      for (final c in _courses) {
        c.dispose();
      }
      _courses
        ..clear()
        ..addAll([_newCourse(), _newCourse(), _newCourse()]);
    });
  }

  /// Grade points for a course, or null if its grade isn't entered yet (e.g. a
  /// "Custom" grade with an empty/invalid points field).
  double? _pointsFor(_Course c) {
    if (c.gradeIndex == customGradeIndex) {
      final p = double.tryParse(c.custom.text.trim());
      if (p == null) return null;
      return p.clamp(0.0, _scale.max);
    }
    final idx = c.gradeIndex.clamp(0, _scale.grades.length - 1);
    return _scale.grades[idx].points;
  }

  /// A course contributes to the GPA only when it has positive credit hours and
  /// a valid grade.
  bool _counts(_Course c) {
    final cr = double.tryParse(c.credits.text.trim()) ?? 0;
    return cr > 0 && _pointsFor(c) != null;
  }

  int get _countedCourses => _courses.where(_counts).length;

  double get _totalCredits {
    var total = 0.0;
    for (final c in _courses) {
      if (!_counts(c)) continue;
      total += double.parse(c.credits.text.trim());
    }
    return total;
  }

  double? get _gpa {
    var totalCredits = 0.0;
    var weighted = 0.0;
    for (final c in _courses) {
      if (!_counts(c)) continue;
      final cr = double.parse(c.credits.text.trim());
      totalCredits += cr;
      weighted += cr * _pointsFor(c)!;
    }
    if (totalCredits <= 0) return null;
    return weighted / totalCredits;
  }

  // ---------------------------------------------------------------------------
  // History
  // ---------------------------------------------------------------------------

  Future<void> _saveResult() async {
    final gpa = _gpa;
    if (gpa == null) return;

    final label = await _askLabel();
    if (label == null) return; // cancelled

    final now = DateTime.now();
    await _history.add(
      GpaResult(
        id: now.millisecondsSinceEpoch,
        gpa: gpa,
        scaleMax: _scale.max,
        totalCredits: _totalCredits,
        courseCount: _countedCourses,
        label: label.trim().isEmpty ? null : label.trim(),
        savedAt: now,
      ),
    );
    if (mounted) {
      final colors = AppColors.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Saved to history'),
          backgroundColor: colors.success,
        ),
      );
    }
  }

  Future<String?> _askLabel() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save result'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Label (optional)',
            hintText: 'e.g. Semester 1',
          ),
          onSubmitted: (v) => Navigator.pop(dialogContext, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GpaHistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('GPA Calculator'),
        actions: [
          IconButton(
            tooltip: 'History',
            onPressed: _openHistory,
            icon: const Icon(Icons.history_rounded),
          ),
          IconButton(
            tooltip: 'Clear all',
            onPressed: _clearAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _buildScaleSelector(colors),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildResultCard(colors),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: _courses.length,
              itemBuilder: (context, index) => _buildCourseCard(colors, index),
            ),
          ),
          _buildBottomBar(colors),
        ],
      ),
    );
  }

  Widget _buildScaleSelector(ThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Grading scale (out of)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              for (var i = 0; i < _scales.length; i++)
                ButtonSegment(value: i, label: Text(_scales[i].id)),
            ],
            selected: {_scaleIndex},
            onSelectionChanged: (s) => _changeScale(s.first),
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(ThemeColors colors) {
    final gpa = _gpa;
    final gpaText = gpa != null ? gpa.toStringAsFixed(2) : '—';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'Your GPA',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: gpaText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                TextSpan(
                  text: '  / ${_scale.max.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Total credit hours: ${_trim(_totalCredits)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12.5,
            ),
          ),
          if (gpa != null) ...[
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: _saveResult,
              icon: const Icon(Icons.bookmark_add_rounded, size: 18),
              label: const Text('Save result'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCourseCard(ThemeColors colors, int index) {
    final course = _courses[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Course ${index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textHint,
                ),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _removeCourse(index),
                icon: Icon(Icons.close_rounded, size: 20, color: colors.error),
                tooltip: 'Remove course',
              ),
            ],
          ),
          TextField(
            controller: course.name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Course name (optional)',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: course.credits,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Credit hours',
                    hintText: 'e.g. 3',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: ValueKey('grade-$index-$_scaleIndex'),
                  initialValue: course.gradeIndex,
                  isDense: true,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Grade',
                  ),
                  items: [
                    for (var i = 0; i < _scale.grades.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                          '${_scale.grades[i].label}  '
                          '(${_trim(_scale.grades[i].points)})',
                        ),
                      ),
                    const DropdownMenuItem(
                      value: customGradeIndex,
                      child: Text('Custom…'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => course.gradeIndex = value);
                    }
                  },
                ),
              ),
            ],
          ),
          if (course.gradeIndex == customGradeIndex) ...[
            const SizedBox(height: 12),
            TextField(
              controller: course.custom,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                labelText: 'Grade points (out of ${_trim(_scale.max)})',
                hintText: 'e.g. 3.5',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar(ThemeColors colors) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _addCourse,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('Add course'),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.primary,
            side: BorderSide(color: colors.primary),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  /// Formats a number without a trailing ".0" (e.g. 3.0 -> "3", 1.5 -> "1.5").
  String _trim(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }
}
