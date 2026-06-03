import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/app_theme.dart';
import '../../services/assignment_draft_service.dart';
import '../../services/assignment_html_service.dart';
import 'pdf_result_screen.dart';

enum _ExitChoice { save, discard, cancel }

/// A lightweight, page-styled rich-text editor built on a WebView
/// (contenteditable). Because the editor and the PDF use the SAME browser
/// engine, what the student sees is exactly what the PDF contains — correct
/// Urdu/Pashto shaping, RTL, and pagination, with no translation bugs.
class WebAssignmentEditorScreen extends StatefulWidget {
  final AssignmentDraft? draft;

  const WebAssignmentEditorScreen({super.key, this.draft});

  @override
  State<WebAssignmentEditorScreen> createState() =>
      _WebAssignmentEditorScreenState();
}

class _WebAssignmentEditorScreenState extends State<WebAssignmentEditorScreen> {
  final AssignmentDraftService _draftService = AssignmentDraftService();
  final AssignmentHtmlService _htmlService = AssignmentHtmlService();

  WebViewController? _controller;
  late String _id;
  late String _title;
  late DateTime _createdAt;

  bool _dirty = false;
  bool _ready = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    if (draft != null) {
      _id = draft.id;
      _title = draft.title;
      _createdAt = draft.createdAt;
    } else {
      _id = _draftService.newId();
      _title = 'Assignment ${DateFormat('yyyy-MM-dd').format(DateTime.now())}';
      _createdAt = DateTime.now();
    }
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final html = await _htmlService.buildEditorHtml(
        initialBody: widget.draft?.html ?? '',
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/editor_$_id.html');
      await file.writeAsString(html);

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFFE5E7EB))
        ..addJavaScriptChannel('Editor', onMessageReceived: (_) {
          if (!_dirty && mounted) setState(() => _dirty = true);
        })
        ..addJavaScriptChannel('ClipboardBridge', onMessageReceived: (msg) {
          // The WebView's own JS clipboard access is unreliable on Android, so
          // BOTH the paste event and the toolbar's Paste button delegate here.
          // We read the system clipboard natively (reliable) and inject the
          // result once — rich HTML if the source had any, else the plain text
          // (Markdown from an AI app) converted to formatted HTML.
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

  /// Handles a paste request from the WebView (the paste event or the toolbar's
  /// Paste button). Reads the system clipboard natively — the reliable source on
  /// Android — and injects the content once. Prefers the clipboard's rich HTML;
  /// falls back to the plain text the WebView's paste event managed to capture.
  ///
  /// [raw] is a JSON object `{html, text}` carrying whatever the WebView could
  /// read from its own (often-empty) clipboardData, used only as a fallback.
  Future<void> _handleClipboardRequest(String raw) async {
    final c = _controller;
    if (c == null) return;

    String? evHtml;
    String? evText;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        evHtml = decoded['html'] as String?;
        evText = decoded['text'] as String?;
      }
    } catch (_) {
      // Not JSON (older bridge message) — ignore; the native read covers it.
    }

    String? html;
    String? text;
    try {
      final clip = await _htmlService.printer.readClipboard();
      html = clip?.html;
      text = clip?.text;
    } catch (_) {
      // Native read failed — fall back to the WebView-captured data below.
    }

    // Prefer the native clipboard; fall back to what the paste event captured.
    if (html == null || html.trim().isEmpty) html = evHtml;
    if (text == null || text.trim().isEmpty) text = evText;

    final hasHtml = html != null && html.trim().isNotEmpty;
    final hasText = text != null && text.trim().isNotEmpty;
    if (!hasHtml && !hasText) return;

    // jsonEncode produces a safe JS string literal (handles quotes, newlines and
    // Unicode), so Urdu/Pashto content survives the injection intact.
    final jsHtml = jsonEncode(html ?? '');
    final jsText = jsonEncode(text ?? '');
    try {
      await c.runJavaScript('pasteFromDart($jsHtml, $jsText);');
    } catch (_) {
      // Best-effort.
    }
  }

  /// Reads the current editor body HTML out of the WebView.
  Future<String> _readBody() async {
    final c = _controller;
    if (c == null) return '';
    final res = await c.runJavaScriptReturningResult('getBody()');
    var html = res.toString();
    // Android returns the JS string JSON-encoded (quoted/escaped).
    if (html.startsWith('"') && html.endsWith('"')) {
      try {
        html = jsonDecode(html) as String;
      } catch (_) {}
    }
    return html;
  }

  Future<void> _persist() async {
    final body = await _readBody();
    final draft = AssignmentDraft(
      id: _id,
      title: _title,
      html: body,
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
    );
    await _draftService.save(draft);
    if (mounted) setState(() => _dirty = false);
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
    final controller = TextEditingController(text: _title);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Document name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Title'),
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
    if (name != null && name.trim().isNotEmpty) {
      setState(() {
        _title = name.trim();
        _dirty = true;
      });
    }
  }

  Future<bool?> _askBorder() {
    var border = false;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Export to PDF'),
          content: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: border,
            onChanged: (v) => setLocal(() => border = v),
            title: const Text('Page border'),
            subtitle: const Text('A frame around the content on every page.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, border),
              child: const Text('Export'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    final width = MediaQuery.of(context).size.width;
    final border = await _askBorder();
    if (border == null || !mounted) return;
    await _persist();
    if (!mounted) return;
    setState(() => _exporting = true);
    try {
      final body = await _readBody();
      final file = await _htmlService.exportPdfFromBody(
        bodyHtml: body,
        fileName: _title,
        border: border,
        contentWidthPx: width,
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
          ],
        ),
        body: Stack(
          children: [
            if (_controller != null) WebViewWidget(controller: _controller!),
            if (!_ready)
              const Center(child: CircularProgressIndicator()),
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
