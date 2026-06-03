import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../config/app_theme.dart';
import '../../services/assignment_draft_service.dart';
import 'web_assignment_editor_screen.dart';

/// Lists saved assignment drafts and lets the student open or create one.
class AssignmentListScreen extends StatefulWidget {
  const AssignmentListScreen({super.key});

  @override
  State<AssignmentListScreen> createState() => _AssignmentListScreenState();
}

class _AssignmentListScreenState extends State<AssignmentListScreen> {
  final AssignmentDraftService _service = AssignmentDraftService();
  List<AssignmentDraft> _drafts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final drafts = await _service.list();
    if (mounted) {
      setState(() {
        _drafts = drafts;
        _loading = false;
      });
    }
  }

  Future<void> _openEditor([AssignmentDraft? draft]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WebAssignmentEditorScreen(draft: draft)),
    );
    _load(); // refresh after returning
  }

  Future<void> _delete(AssignmentDraft draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete draft?'),
        content: Text('Delete "${draft.title}"? This cannot be undone.'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.delete(draft.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Write Assignment')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New'),
      ),
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(ThemeColors colors) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_drafts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_note_rounded, size: 72, color: colors.textHint),
              const SizedBox(height: 16),
              Text(
                'No assignments yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap "New" to start writing. You can save your work and come '
                'back to it any time, then export it as a PDF.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        itemCount: _drafts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final draft = _drafts[index];
          return _DraftTile(
            colors: colors,
            draft: draft,
            onTap: () => _openEditor(draft),
            onDelete: () => _delete(draft),
          );
        },
      ),
    );
  }
}

class _DraftTile extends StatelessWidget {
  final ThemeColors colors;
  final AssignmentDraft draft;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DraftTile({
    required this.colors,
    required this.draft,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final preview = draft.preview;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.description_rounded,
                  color: colors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Edited ${DateFormat('d MMM yyyy, h:mm a').format(draft.updatedAt)}',
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
        ),
      ),
    );
  }
}
