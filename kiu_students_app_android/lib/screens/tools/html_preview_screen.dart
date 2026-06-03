import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Renders the assignment's generated HTML in a real browser engine (WebView).
///
/// This is the validation step for the browser-based PDF export: it proves the
/// embedded fonts load, Urdu/Pashto Nastaliq shapes correctly, and the
/// formatting (bold, sizes, alignment, RTL) is right — before we wire the
/// browser's print engine to produce the paginated PDF.
class HtmlPreviewScreen extends StatefulWidget {
  final String html;
  final String title;

  const HtmlPreviewScreen({
    super.key,
    required this.html,
    required this.title,
  });

  @override
  State<HtmlPreviewScreen> createState() => _HtmlPreviewScreenState();
}

class _HtmlPreviewScreenState extends State<HtmlPreviewScreen> {
  WebViewController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // The HTML embeds fonts as base64 and can be a few MB, so write it to a
      // temp file and load that (more reliable than loadHtmlString for big docs).
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/assignment_preview.html');
      await file.writeAsString(widget.html);
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..loadFile(file.path);
      if (mounted) setState(() => _controller = controller);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Preview — ${widget.title}')),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not render the preview.\n\n($_error)'),
              ),
            )
          : _controller == null
              ? const Center(child: CircularProgressIndicator())
              : WebViewWidget(controller: _controller!),
    );
  }
}
