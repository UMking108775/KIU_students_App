import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../services/gpa_history_service.dart';

/// Shows the student's saved GPA results.
class GpaHistoryScreen extends StatefulWidget {
  const GpaHistoryScreen({super.key});

  @override
  State<GpaHistoryScreen> createState() => _GpaHistoryScreenState();
}

class _GpaHistoryScreenState extends State<GpaHistoryScreen> {
  final GpaHistoryService _service = GpaHistoryService();
  List<GpaResult> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await _service.getAll();
    if (mounted) {
      setState(() {
        _results = results;
        _loading = false;
      });
    }
  }

  Future<void> _delete(GpaResult r) async {
    await _service.deleteById(r.id);
    _load();
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('This will remove all saved GPA results.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.of(context).error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.clear();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('GPA History'),
        actions: [
          if (_results.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_sweep_rounded),
            ),
        ],
      ),
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(ThemeColors colors) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_rounded, size: 64, color: colors.textHint),
              const SizedBox(height: 16),
              Text(
                'No saved results yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Calculate your GPA, then tap "Save result" to keep it here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final r = _results[index];
        return _ResultTile(colors: colors, result: r, onDelete: () => _delete(r));
      },
    );
  }
}

class _ResultTile extends StatelessWidget {
  final ThemeColors colors;
  final GpaResult result;
  final VoidCallback onDelete;

  const _ResultTile({
    required this.colors,
    required this.result,
    required this.onDelete,
  });

  String _trim(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('d MMM yyyy, h:mm a').format(result.savedAt);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          // GPA badge
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.primary, colors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  result.gpa.toStringAsFixed(2),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '/ ${_trim(result.scaleMax)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.label?.isNotEmpty == true ? result.label! : 'Result',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${result.courseCount} course'
                  '${result.courseCount == 1 ? '' : 's'}  •  '
                  '${_trim(result.totalCredits)} credit hrs',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  dateText,
                  style: TextStyle(fontSize: 11, color: colors.textHint),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline_rounded, color: colors.error),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }
}
