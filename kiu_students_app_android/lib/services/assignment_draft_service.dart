import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// A saved (possibly unfinished) assignment written in the rich-text editor.
/// [delta] is the flutter_quill document serialized as a Quill Delta (the JSON
/// op list), which preserves all formatting so the student can resume editing.
class AssignmentDraft {
  final String id;
  final String title;
  final List<dynamic> delta;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AssignmentDraft({
    required this.id,
    required this.title,
    required this.delta,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'delta': delta,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory AssignmentDraft.fromJson(Map<String, dynamic> json) => AssignmentDraft(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Untitled',
        delta: (json['delta'] as List<dynamic>?) ?? const <dynamic>[],
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  /// A short plain-text preview of the content for the drafts list.
  String get preview {
    final sb = StringBuffer();
    for (final op in delta) {
      if (op is Map && op['insert'] is String) {
        sb.write(op['insert'] as String);
        if (sb.length > 120) break;
      }
    }
    return sb.toString().replaceAll('\n', ' ').trim();
  }
}

/// Stores assignment drafts as JSON files in the app's documents directory so
/// students can save unfinished work and come back to it later.
class AssignmentDraftService {
  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/Assignments');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// A new unique draft id.
  String newId() => 'doc_${DateTime.now().millisecondsSinceEpoch}';

  /// All drafts, most recently edited first.
  Future<List<AssignmentDraft>> list() async {
    final dir = await _dir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.json'));

    final drafts = <AssignmentDraft>[];
    for (final f in files) {
      try {
        final json = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        drafts.add(AssignmentDraft.fromJson(json));
      } catch (_) {
        // Skip unreadable/corrupt files.
      }
    }
    drafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return drafts;
  }

  Future<void> save(AssignmentDraft draft) async {
    final dir = await _dir();
    final file = File('${dir.path}/${draft.id}.json');
    await file.writeAsString(jsonEncode(draft.toJson()));
  }

  Future<void> delete(String id) async {
    final dir = await _dir();
    final file = File('${dir.path}/$id.json');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
