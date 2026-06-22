import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_theme.dart';
import 'kiu_gpa_data.dart';
import 'kiu_gpa_model.dart';
import 'kiu_gpa_pdf.dart';

/// KIU GPA / CGPA calculator.
///
/// A faithful port of the official KIU web calculator: pick a semester (1–8)
/// to seed its exact subjects & credit hours, enter Faculty (/30) and Final
/// (/70) marks, and the tool grades each subject on KIU's 5.0 scale and rolls
/// up Quarterly GPA per semester plus an overall Cumulative CGPA.
class GpaCalculatorScreen extends StatefulWidget {
  const GpaCalculatorScreen({super.key});

  @override
  State<GpaCalculatorScreen> createState() => _GpaCalculatorScreenState();
}

class _GpaCalculatorScreenState extends State<GpaCalculatorScreen> {
  final KiuGpaStore _store = KiuGpaStore();
  final List<GpaSemester> _semesters = [];

  /// Selected value of the "Add semester" dropdown ('1'..'8' or 'custom').
  String _dropdown = '1';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await _store.load();
    if (!mounted) return;
    setState(() {
      _semesters
        ..clear()
        ..addAll(loaded);
      _loading = false;
    });
  }

  @override
  void dispose() {
    for (final s in _semesters) {
      s.dispose();
    }
    super.dispose();
  }

  String _newId() => UniqueKey().toString();

  void _persist() => _store.save(_semesters);

  /// Recompute + save after any edit.
  void _onChanged() {
    setState(() {});
    _persist();
  }

  // ---------------------------------------------------------------------------
  // Totals
  // ---------------------------------------------------------------------------

  double get _globalCredits {
    var c = 0.0;
    for (final s in _semesters) {
      c += s.totalCredits;
    }
    return c;
  }

  double get _globalPoints {
    var p = 0.0;
    for (final s in _semesters) {
      p += s.totalPoints;
    }
    return p;
  }

  double get _overallCgpa =>
      _globalCredits > 0 ? _globalPoints / _globalCredits : 0;

  /// Cumulative CGPA up to and including [index] (running, in display order).
  double _cumulativeCgpaUpTo(int index) {
    var credits = 0.0;
    var points = 0.0;
    for (var i = 0; i <= index; i++) {
      credits += _semesters[i].totalCredits;
      points += _semesters[i].totalPoints;
    }
    return credits > 0 ? points / credits : 0;
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _addSemester() {
    final List<GpaSubject> subjects;
    final String name;
    final n = int.tryParse(_dropdown);
    if (n != null && kiuPredefinedSemesters.containsKey(n)) {
      name = 'Semester $n';
      subjects = kiuPredefinedSemesters[n]!
          .map((p) => GpaSubject.create(
                id: _newId(),
                name: p.name,
                credits: p.credits,
              ))
          .toList();
    } else {
      name = 'Semester ${_semesters.length + 1}';
      subjects = List.generate(
        3,
        (_) => GpaSubject.create(id: _newId()),
      );
    }
    setState(() {
      _semesters.add(GpaSemester(
        id: _newId(),
        title: TextEditingController(text: name),
        subjects: subjects,
      ));
    });
    _persist();
  }

  Future<void> _removeSemester(int index) async {
    final ok = await _confirm(
      'Remove semester?',
      'This will delete the semester and all its subjects.',
    );
    if (ok != true) return;
    setState(() {
      _semesters.removeAt(index).dispose();
    });
    _persist();
  }

  void _addSubject(GpaSemester sem) {
    setState(() {
      sem.subjects.add(GpaSubject.create(id: _newId()));
    });
    _persist();
  }

  void _removeSubject(GpaSemester sem, GpaSubject sub) {
    setState(() {
      sem.subjects.remove(sub);
      sub.dispose();
    });
    _persist();
  }

  Future<void> _resetAll() async {
    final ok = await _confirm(
      'Reset everything?',
      'All semesters and entered marks will be permanently removed.',
    );
    if (ok != true) return;
    setState(() {
      for (final s in _semesters) {
        s.dispose();
      }
      _semesters.clear();
    });
    await _store.clear();
  }

  Future<bool?> _confirm(String title, String body) {
    final colors = AppColors.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: colors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _export(bool print) async {
    if (_semesters.isEmpty) {
      _toast('Add a semester first.');
      return;
    }
    try {
      if (print) {
        await KiuGpaPdf.printReport(_semesters);
      } else {
        await KiuGpaPdf.share(_semesters);
      }
    } catch (e) {
      _toast('Could not create the report. Check your connection and retry.');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('GPA Calculator'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'pdf':
                  _export(false);
                  break;
                case 'print':
                  _export(true);
                  break;
                case 'reset':
                  _resetAll();
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'pdf',
                child: ListTile(
                  leading: Icon(Icons.picture_as_pdf_outlined),
                  title: Text('Export / Share PDF'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'print',
                child: ListTile(
                  leading: Icon(Icons.print_outlined),
                  title: Text('Print'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'reset',
                child: ListTile(
                  leading: Icon(Icons.restart_alt_rounded),
                  title: Text('Reset all'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _dashboard(colors),
                const SizedBox(height: 16),
                if (_semesters.isEmpty)
                  _emptyState(colors)
                else
                  for (var i = 0; i < _semesters.length; i++) ...[
                    _semesterCard(colors, i),
                    const SizedBox(height: 16),
                  ],
                _addSemesterBar(colors),
              ],
            ),
    );
  }

  Widget _dashboard(ThemeColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _statBox('Overall CGPA', _overallCgpa.toStringAsFixed(2), big: true),
          _divider(),
          _statBox('Credits', _trim(_globalCredits)),
          _divider(),
          _statBox('Points', _globalPoints.toStringAsFixed(2)),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, {bool big = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: big ? 30 : 22,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 40,
        color: Colors.white.withValues(alpha: 0.25),
      );

  Widget _emptyState(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.school_outlined, size: 56, color: colors.textHint),
          const SizedBox(height: 14),
          Text(
            'No semesters yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Choose a semester below and tap "Add Semester" to load its '
            'subjects, then enter your marks.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  // --- Semester card ---------------------------------------------------------

  Widget _semesterCard(ThemeColors colors, int index) {
    final sem = _semesters[index];
    final cgpa = _cumulativeCgpaUpTo(index);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: sem.title,
                    onChanged: (_) => _persist(),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Semester name',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove semester',
                  onPressed: () => _removeSemester(index),
                  icon: Icon(Icons.delete_outline_rounded, color: colors.error),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          // Subjects
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Column(
              children: [
                for (final sub in sem.subjects)
                  _subjectCard(colors, sem, sub),
              ],
            ),
          ),
          // Add subject
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _addSubject(sem),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add subject'),
                style: TextButton.styleFrom(foregroundColor: colors.primary),
              ),
            ),
          ),
          // Footer totals
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Credits ${_trim(sem.totalCredits)}  •  '
                        'Points ${sem.totalPoints.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Cumulative CGPA: ${cgpa.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Quarterly GPA',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                    Text(
                      sem.gpa.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Subject card ----------------------------------------------------------

  Widget _subjectCard(ThemeColors colors, GpaSemester sem, GpaSubject sub) {
    final grade = sub.grade;
    final total = sub.totalMarks;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 12),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + remove
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: sub.name,
                  textAlign: TextAlign.right,
                  onChanged: (_) => _persist(),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Subject name',
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Remove subject',
                onPressed: () => _removeSubject(sem, sub),
                icon: Icon(Icons.close_rounded, size: 18, color: colors.error),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Marks inputs
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _markField(
                  colors,
                  controller: sub.faculty,
                  label: 'Faculty /30',
                  error: sub.facultyError ? 'Max 30' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _markField(
                  colors,
                  controller: sub.finalMarks,
                  label: 'Final /70',
                  error: sub.finalError ? 'Max 70' : null,
                ),
              ),
              const SizedBox(width: 8),
              _creditsBox(colors, sub.creditVal),
            ],
          ),
          const SizedBox(height: 10),
          // Result row: total, grade, gpa, points
          Row(
            children: [
              _chip(colors, 'Total',
                  total == null ? '—' : _trim(total),
                  danger: sub.totalError),
              const SizedBox(width: 8),
              _gradeBadge(colors, grade),
              const Spacer(),
              _miniStat(colors, 'GPA',
                  grade == null ? '—' : grade.gpa.toStringAsFixed(2)),
              const SizedBox(width: 14),
              _miniStat(colors, 'Points',
                  sub.counts ? sub.points.toStringAsFixed(2) : '0.00'),
            ],
          ),
        ],
      ),
    );
  }

  /// Fixed, non-editable credit-hours display (credits come from the KIU
  /// syllabus and must not be changed).
  Widget _creditsBox(ThemeColors colors, int credits) {
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Credits',
            style: TextStyle(fontSize: 9, color: colors.textHint),
          ),
          const SizedBox(height: 2),
          Text(
            '$credits',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _markField(
    ThemeColors colors, {
    required TextEditingController controller,
    required String label,
    String? error,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          onChanged: (_) => _onChanged(),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            isDense: true,
            labelText: label,
            errorText: error,
            errorStyle: const TextStyle(fontSize: 10, height: 0.8),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(ThemeColors colors, String label, String value,
      {bool danger = false}) {
    final c = danger ? colors.error : colors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c),
      ),
    );
  }

  Widget _gradeBadge(ThemeColors colors, KiuGrade? grade) {
    final label = grade?.letter ?? '—';
    final color = grade?.color(colors) ?? colors.textHint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _miniStat(ThemeColors colors, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: colors.textHint),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }

  // --- Add semester bar ------------------------------------------------------

  Widget _addSemesterBar(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add a semester',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _dropdown,
                  isExpanded: true,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: [
                    for (var i = 1; i <= 8; i++)
                      DropdownMenuItem(
                        value: '$i',
                        child: Text('Semester $i'),
                      ),
                    const DropdownMenuItem(
                      value: 'custom',
                      child: Text('Custom semester'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _dropdown = v ?? '1'),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _addSemester,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Formats a number without a trailing ".0".
  String _trim(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }
}
