import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/app_theme.dart';
import '../../widgets/common/text_prompt_dialog.dart';
import '../../services/assignment_draft_service.dart';
import '../../services/assignment_geometry.dart';
import '../../services/assignment_html_service.dart';
import 'pdf_result_screen.dart';

enum _ExitChoice { save, discard, cancel }

/// A lightweight, page-styled rich-text editor built on a WebView
/// (contenteditable). Because the editor and the PDF use the SAME browser
/// engine AND the SAME [AssignmentGeometry] + page fragments, what the student
/// sees is exactly what the PDF contains — correct Urdu/Pashto shaping, RTL,
/// equal margins, and matching page breaks.
class WebAssignmentEditorScreen extends StatefulWidget {
  final AssignmentDraft? draft;

  const WebAssignmentEditorScreen({super.key, this.draft});

  @override
  State<WebAssignmentEditorScreen> createState() =>
      _WebAssignmentEditorScreenState();
}

class _WebAssignmentEditorScreenState extends State<WebAssignmentEditorScreen>
    with WidgetsBindingObserver {
  final AssignmentDraftService _draftService = AssignmentDraftService();
  final AssignmentHtmlService _htmlService = AssignmentHtmlService();

  WebViewController? _controller;
  late String _id;
  late String _title;
  late DateTime _createdAt;
  double _marginPx = AssignmentMargin.narrowPx;
  late AssignmentGeometry _geom;

  final Set<String> _loadedFonts = {};
  Timer? _autosave;

  bool _dirty = false;
  bool _ready = false;
  bool _exporting = false;
  bool _booted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final draft = widget.draft;
    if (draft != null) {
      _id = draft.id;
      _title = draft.title;
      _createdAt = draft.createdAt;
      _marginPx = draft.marginPx;
    } else {
      _id = _draftService.newId();
      _title = 'Assignment ${DateFormat('yyyy-MM-dd').format(DateTime.now())}';
      _createdAt = DateTime.now();
    }
    // MediaQuery isn't available in initState; bootstrap after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrap();
    });
  }

  @override
  void dispose() {
    _autosave?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Persist unsaved work when the app is backgrounded so it survives a kill.
    // Only on `paused` (a real background transition): `inactive` fires constantly
    // (dialogs, the notification shade, permission prompts) and would trigger
    // redundant full getBody()+write round-trips.
    if (state == AppLifecycleState.paused && _dirty && _ready) {
      _persist();
    }
  }

  Future<void> _bootstrap() async {
    if (_booted) return;
    _booted = true;
    try {
      final width = MediaQuery.of(context).size.width;
      _geom = AssignmentGeometry.forScreen(width, marginPx: _marginPx);

      final openingHtml = widget.draft?.openingHtml ?? '';
      final embed = _familiesIn(openingHtml);
      _loadedFonts.addAll(embed);

      final html = await _htmlService.buildEditorHtml(
        geom: _geom,
        initialBody: openingHtml,
        embedFamilies: embed,
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/editor_$_id.html');
      await file.writeAsString(html);

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFFE5E7EB))
        ..addJavaScriptChannel('Editor', onMessageReceived: (_) {
          if (mounted && !_dirty) setState(() => _dirty = true);
          _scheduleAutosave();
        })
        ..addJavaScriptChannel('Fonts', onMessageReceived: (msg) {
          _ensureFont(msg.message);
        })
        ..addJavaScriptChannel('ClipboardBridge', onMessageReceived: (msg) {
          _handleClipboardRequest(msg.message);
        })
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (mounted) setState(() => _ready = true);
            },
          ),
        )
        ..loadFile(file.path);

      if (mounted) setState(() => _controller = controller);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the editor.\n\n($e)')),
        );
      }
    }
  }

  /// Bundled families referenced in [html] (so we embed only what's needed).
  Set<String> _familiesIn(String html) {
    final out = <String>{};
    for (final f in AssignmentHtmlService.fontFamilies) {
      if (html.contains(f)) out.add(f);
    }
    return out;
  }

  /// Injects a font's `@font-face` on demand the first time it's used (keeps the
  /// initial editor load light — Noto Nastaliq alone is ~1.2 MB).
  Future<void> _ensureFont(String family) async {
    if (_loadedFonts.contains(family)) return;
    _loadedFonts.add(family);
    try {
      final b64 = await _htmlService.fontBase64(family);
      if (b64 == null) return;
      await _controller
          ?.runJavaScript('injectFont(${jsonEncode(family)}, ${jsonEncode(b64)});');
    } catch (_) {
      _loadedFonts.remove(family); // allow a retry
    }
  }

  void _scheduleAutosave() {
    _autosave?.cancel();
    _autosave = Timer(const Duration(milliseconds: 2500), () {
      if (mounted && _dirty) _persist();
    });
  }

  Future<void> _handleClipboardRequest(String raw) async {
    final c = _controller;
    if (c == null) return;
    String? evHtml, evText;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        evHtml = decoded['html'] as String?;
        evText = decoded['text'] as String?;
      }
    } catch (_) {}

    String? html, text;
    try {
      final clip = await _htmlService.printer.readClipboard();
      html = clip?.html;
      text = clip?.text;
    } catch (_) {}

    if (html == null || html.trim().isEmpty) html = evHtml;
    if (text == null || text.trim().isEmpty) text = evText;

    final hasHtml = html != null && html.trim().isNotEmpty;
    final hasText = text != null && text.trim().isNotEmpty;
    if (!hasHtml && !hasText) return;

    try {
      await c.runJavaScript(
          'pasteFromDart(${jsonEncode(html ?? '')}, ${jsonEncode(text ?? '')});');
    } catch (_) {}
  }

  /// Reads a JS string result, unwrapping the JSON-quoting Android adds.
  Future<String> _jsString(String expr) async {
    final c = _controller;
    if (c == null) return '';
    final res = await c.runJavaScriptReturningResult(expr);
    var s = res.toString();
    if (s.startsWith('"') && s.endsWith('"')) {
      try {
        s = jsonDecode(s) as String;
      } catch (_) {}
    }
    return s;
  }

  Future<String> _readBody() => _jsString('getBody()');

  Future<void> _persist() async {
    if (!_ready) return;
    // Defensive: a transient WebView read/save failure must never crash the app
    // (autosave runs on a timer). On failure we keep `_dirty` and retry later.
    try {
      final body = await _readBody();
      final draft = AssignmentDraft(
        id: _id,
        title: _title,
        html: body,
        marginPx: _marginPx,
        createdAt: _createdAt,
        updatedAt: DateTime.now(),
      );
      await _draftService.save(draft);
      if (mounted) setState(() => _dirty = false);
    } catch (_) {
      // keep dirty; next autosave/save will retry
    }
  }

  Future<void> _saveButton() async {
    await _persist();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Saved'),
          backgroundColor: AppColors.of(context).success,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _rename() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => TextPromptDialog(
        title: 'Document name',
        label: 'Title',
        initialText: _title,
        textCapitalization: TextCapitalization.words,
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      setState(() {
        _title = name.trim();
        _dirty = true;
      });
      _scheduleAutosave();
    }
  }

  Future<void> _pageSetup() async {
    final chosen = await showDialog<AssignmentMargin>(
      context: context,
      builder: (dialogContext) {
        final current = AssignmentMargin.fromPx(_marginPx);
        return SimpleDialog(
          title: const Text('Page margins'),
          children: [
            for (final m in AssignmentMargin.values)
              ListTile(
                title: Text(m.label),
                subtitle: Text('${m.px.round()} px margin'),
                trailing: current == m
                    ? Icon(Icons.check, color: AppColors.of(context).primary)
                    : null,
                onTap: () => Navigator.pop(dialogContext, m),
              ),
          ],
        );
      },
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _marginPx = chosen.px;
      _geom = _geom.copyWith(marginPx: chosen.px);
      _dirty = true;
    });
    try {
      await _controller
          ?.runJavaScript('setGeo(${jsonEncode(_geom.toJsConfig())});');
    } catch (_) {}
    _scheduleAutosave();
  }

  /// Inserts the fixed KIU cover block at the very top of the document — no form;
  /// the student fills the blank fields in the editor.
  Future<void> _insertCover() async {
    try {
      await _controller?.runJavaScript('insertCover();');
    } catch (_) {}
    setState(() => _dirty = true);
    _scheduleAutosave();
  }

  Future<void> _exportPdf() async {
    await _persist();
    if (!mounted) return;
    setState(() => _exporting = true);
    try {
      final body = await _readBody();
      final file = await _htmlService.exportPdf(
        bodyHtml: body,
        geom: _geom,
        fileName: _title,
      );
      if (!mounted) return;
      setState(() => _exporting = false);
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PdfResultScreen(file: file)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _exporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not export the PDF.\n\n($e)'),
          backgroundColor: AppColors.of(context).error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<_ExitChoice> _confirmExit() async {
    if (!_dirty) return _ExitChoice.discard;
    final choice = await showDialog<_ExitChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save changes?'),
        content: const Text('Save this assignment before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _ExitChoice.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.of(context).error,
            ),
            onPressed: () => Navigator.pop(dialogContext, _ExitChoice.discard),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, _ExitChoice.save),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return choice ?? _ExitChoice.cancel;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final choice = await _confirmExit();
        if (choice == _ExitChoice.cancel) return;
        if (choice == _ExitChoice.save) await _persist();
        navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: InkWell(
            onTap: _rename,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.edit_outlined, size: 16),
              ],
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Save',
              onPressed: _dirty ? _saveButton : null,
              icon: const Icon(Icons.save_outlined),
            ),
            IconButton(
              tooltip: 'Export to PDF',
              onPressed: (_ready && !_exporting) ? _exportPdf : null,
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
            PopupMenuButton<String>(
              enabled: _ready,
              onSelected: (v) {
                switch (v) {
                  case 'cover':
                    _insertCover();
                    break;
                  case 'page':
                    _pageSetup();
                    break;
                  case 'rename':
                    _rename();
                    break;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'cover',
                  child: ListTile(
                    leading: Icon(Icons.article_outlined),
                    title: Text('Insert cover page'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'page',
                  child: ListTile(
                    leading: Icon(Icons.settings_outlined),
                    title: Text('Page setup'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'rename',
                  child: ListTile(
                    leading: Icon(Icons.drive_file_rename_outline),
                    title: Text('Rename'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Stack(
          children: [
            if (_controller != null) WebViewWidget(controller: _controller!),
            if (!_ready) const Center(child: CircularProgressIndicator()),
            if (_exporting)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.45),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: colors.primary),
                          const SizedBox(height: 16),
                          Text(
                            'Creating PDF…',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
