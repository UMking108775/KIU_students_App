import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../config/app_theme.dart';
import '../../services/assignment_draft_service.dart';
import 'web_assignment_editor_screen.dart';
import 'widgets/tool_card_style.dart';

/// Lists saved assignment drafts and lets the student open or create one.
class AssignmentListScreen extends StatefulWidget {
  const AssignmentListScreen({super.key});

  @override
  State<AssignmentListScreen> createState() => _AssignmentListScreenState();
}

class _AssignmentListScreenState extends State<AssignmentListScreen> {
  final AssignmentDraftService _service = AssignmentDraftService();
  final TextEditingController _searchCtrl = TextEditingController();
  List<AssignmentDraft> _drafts = [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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

  List<AssignmentDraft> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _drafts;
    return _drafts
        .where((d) =>
            d.title.toLowerCase().contains(q) ||
            d.preview.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Write Assignment')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(colors),
                Expanded(child: _buildList(colors)),
              ],
            ),
    );
  }

  /// "Create new blank document" action + search field.
  Widget _buildHeader(ThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
      child: Column(
        children: [
          _CreateDocumentButton(
            colors: colors,
            onTap: () => _openEditor(),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: toolCardDecoration(context),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search documents',
                prefixIcon:
                    Icon(Icons.search_rounded, color: colors.textSecondary),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: colors.textSecondary),
                        tooltip: 'Clear',
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(ThemeColors colors) {
    if (_drafts.isEmpty) {
      return _emptyState(
        colors,
        icon: Icons.edit_note_rounded,
        title: 'No assignments yet',
        body: 'Tap "Create new blank document" to start writing. You can save '
            'your work and come back any time, then export it as a PDF.',
      );
    }

    final filtered = _filtered;
    if (filtered.isEmpty) {
      return _emptyState(
        colors,
        icon: Icons.search_off_rounded,
        title: 'No matches',
        body: 'No documents match "${_query.trim()}".',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Text(
              'Recent documents',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final draft = filtered[index];
                return _DraftTile(
                  colors: colors,
                  draft: draft,
                  onOpen: () => _openEditor(draft),
                  onDelete: () => _delete(draft),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(
    ThemeColors colors, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: colors.textHint),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Prominent primary call-to-action for starting a new blank document.
class _CreateDocumentButton extends StatelessWidget {
  final ThemeColors colors;
  final VoidCallback onTap;

  const _CreateDocumentButton({required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colors.primary, colors.primaryLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.note_add_rounded,
                      color: Colors.white, size: 23),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create new blank document',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Start writing from scratch',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DraftTile extends StatelessWidget {
  final ThemeColors colors;
  final AssignmentDraft draft;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _DraftTile({
    required this.colors,
    required this.draft,
    required this.onOpen,
    required this.onDelete,
  });

  /// Shows the Open / Delete context menu at [position] (used for both the
  /// 3-dots button and long-press).
  Future<void> _showContextMenu(BuildContext context, Offset position) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(
          value: 'open',
          child: ListTile(
            leading: Icon(Icons.open_in_new_rounded),
            title: Text('Open'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: colors.error),
            title: Text('Delete', style: TextStyle(color: colors.error)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
    if (value == 'open') {
      onOpen();
    } else if (value == 'delete') {
      onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = draft.preview;
    // Captured by both onTapDown and onLongPress so the context menu can open
    // at the press location.
    var pressPosition = Offset.zero;
    return Container(
      decoration: toolCardDecoration(context),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          onTapDown: (details) => pressPosition = details.globalPosition,
          onLongPress: () => _showContextMenu(context, pressPosition),
          child: Padding(
            padding: const EdgeInsets.all(12),
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
                Builder(
                  builder: (btnContext) => IconButton(
                    onPressed: () {
                      final box =
                          btnContext.findRenderObject() as RenderBox;
                      final pos = box.localToGlobal(
                        box.size.center(Offset.zero),
                      );
                      _showContextMenu(btnContext, pos);
                    },
                    icon: Icon(Icons.more_vert_rounded,
                        color: colors.textSecondary),
                    tooltip: 'More',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
