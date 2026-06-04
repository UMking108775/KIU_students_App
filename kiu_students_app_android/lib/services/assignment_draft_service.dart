import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'assignment_geometry.dart';

/// A saved (possibly unfinished) assignment written in the rich-text editor.
///
/// New drafts store their content as [html] (the WebView editor's body). Older
/// drafts written with the previous flutter_quill editor stored a Quill [delta];
/// those are migrated to HTML on first open (see [legacyHtml]) so no work is
/// lost.
class AssignmentDraft {
  final String id;
  final String title;

  /// Legacy Quill delta (older drafts). New drafts use [html].
  final List<dynamic> delta;

  /// The editor content as HTML (the WebView editor's `contenteditable` body).
  final String html;

  /// Persisted page margin (CSS px) chosen in page-setup, so the editor and the
  /// PDF reopen with the same geometry.
  final double marginPx;

  final DateTime createdAt;
  final DateTime updatedAt;

  const AssignmentDraft({
    required this.id,
    required this.title,
    this.delta = const <dynamic>[],
    this.html = '',
    this.marginPx = AssignmentMargin.narrowPx,
    required this.createdAt,
    required this.updatedAt,
  });

  /// The body HTML to open the editor with: the stored [html], or — for a legacy
  /// Quill draft that has no HTML yet — the delta converted to HTML so the
  /// student's content survives the editor change.
  String get openingHtml {
    if (html.trim().isNotEmpty) return html;
    if (delta.isNotEmpty) return deltaToHtml(delta);
    return '';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'delta': delta,
        'html': html,
        'margin_px': marginPx,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory AssignmentDraft.fromJson(Map<String, dynamic> json) => AssignmentDraft(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Untitled',
        delta: (json['delta'] as List<dynamic>?) ?? const <dynamic>[],
        html: json['html'] as String? ?? '',
        marginPx: (json['margin_px'] as num?)?.toDouble() ??
            AssignmentMargin.narrowPx,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  AssignmentDraft copyWith({
    String? title,
    String? html,
    double? marginPx,
    DateTime? updatedAt,
  }) {
    return AssignmentDraft(
      id: id,
      title: title ?? this.title,
      delta: delta,
      html: html ?? this.html,
      marginPx: marginPx ?? this.marginPx,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// A short plain-text preview of the content for the drafts list.
  String get preview {
    final source = html.isNotEmpty ? html : (delta.isNotEmpty ? deltaToHtml(delta) : '');
    if (source.isNotEmpty) {
      return source
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }
    return '';
  }
}

/// Converts a legacy Quill [delta] (list of ops) to editor HTML, preserving the
/// text and the common inline/block formatting (bold/italic/underline/strike,
/// colour, size, font, links, headings, quotes, lists, alignment). Embeds
/// (images) are skipped. Best-effort — the goal is to not lose the student's
/// content when migrating off flutter_quill.
String deltaToHtml(List<dynamic> delta) {
  final buf = StringBuffer();
  final lineSegs = <String>[]; // built-up inline HTML for the current line
  String? listOpen; // 'ul' | 'ol' while inside a run of list items

  String esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  String inline(String text, Map? a) {
    var html = esc(text);
    if (a == null) return html;
    final styles = <String>[];
    if (a['color'] is String) styles.add('color:${a['color']}');
    if (a['background'] is String) styles.add('background-color:${a['background']}');
    final size = a['size'];
    if (size is num) {
      styles.add('font-size:${size}px');
    } else if (size is String) {
      final px = {'small': 13, 'large': 24, 'huge': 32}[size];
      if (px != null) {
        styles.add('font-size:${px}px');
      } else if (RegExp(r'^\d').hasMatch(size)) {
        styles.add('font-size:$size');
      }
    }
    if (a['font'] is String) styles.add("font-family:'${a['font']}'");
    if (styles.isNotEmpty) html = '<span style="${styles.join(';')}">$html</span>';
    if (a['bold'] == true) html = '<b>$html</b>';
    if (a['italic'] == true) html = '<i>$html</i>';
    if (a['underline'] == true) html = '<u>$html</u>';
    if (a['strike'] == true) html = '<s>$html</s>';
    if (a['link'] is String) html = '<a href="${esc(a['link'] as String)}">$html</a>';
    return html;
  }

  void closeList() {
    if (listOpen != null) {
      buf.write('</$listOpen>');
      listOpen = null;
    }
  }

  void flushLine(Map? lineAttrs) {
    final content = lineSegs.join();
    lineSegs.clear();
    final inner = content.isEmpty ? '<br>' : content;

    final align = lineAttrs?['align'];
    final alignStyle =
        (align is String && align.isNotEmpty) ? ' style="text-align:$align"' : '';

    final list = lineAttrs?['list'];
    if (list == 'bullet' || list == 'ordered') {
      final want = list == 'ordered' ? 'ol' : 'ul';
      if (listOpen != want) {
        closeList();
        buf.write('<$want>');
        listOpen = want;
      }
      buf.write('<li$alignStyle>$inner</li>');
      return;
    }
    closeList();

    final header = lineAttrs?['header'];
    if (header is num) {
      final lvl = header.clamp(1, 3).toInt();
      buf.write('<h$lvl$alignStyle>$inner</h$lvl>');
    } else if (lineAttrs?['blockquote'] == true) {
      buf.write('<blockquote$alignStyle>$inner</blockquote>');
    } else {
      buf.write('<p$alignStyle>$inner</p>');
    }
  }

  for (final op in delta) {
    if (op is! Map) continue;
    final ins = op['insert'];
    final attrs = op['attributes'] as Map?;
    if (ins is! String) continue; // skip embeds
    final parts = ins.split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) lineSegs.add(inline(parts[i], attrs));
      if (i < parts.length - 1) flushLine(attrs); // the newline carries block attrs
    }
  }
  if (lineSegs.isNotEmpty) flushLine(null);
  closeList();

  final out = buf.toString();
  return out.isEmpty ? '<p><br></p>' : out;
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
