import 'package:flutter/material.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Wires a [WebViewController] up so interactive sites (Moodle / LMS / web
/// forms) actually work inside the in-app browser.
///
/// Two things break Moodle assignment submission in a bare `webview_flutter`
/// controller, and this fixes both:
///
///  1. **File uploads.** An HTML `<input type="file">` does nothing unless
///     [AndroidWebViewController.setOnShowFileSelector] is provided. That's the
///     "Add submission → Choose a file" button in Moodle — without this it
///     looks dead.
///  2. **JavaScript dialogs.** If `confirm()` / `alert()` / `prompt()` handlers
///     aren't set, the plugin auto-answers `confirm()` with `false`. Moodle's
///     "Are you sure you want to submit? You won't be able to make changes"
///     step uses `confirm()`, so submission silently does nothing.
class WebViewMoodleSupport {
  /// Configures [controller]. [context] and [mounted] are providers (not
  /// captured values) so the dialog callbacks always use a live context.
  static Future<void> configure({
    required WebViewController controller,
    required BuildContext Function() context,
    required bool Function() mounted,
  }) async {
    // --- JavaScript dialogs (cross-platform API on WebViewController) ---
    await controller.setOnJavaScriptAlertDialog((request) async {
      if (!mounted()) return;
      await _alert(context(), request.message);
    });

    await controller.setOnJavaScriptConfirmDialog((request) async {
      if (!mounted()) return false;
      return _confirm(context(), request.message);
    });

    await controller.setOnJavaScriptTextInputDialog((request) async {
      if (!mounted()) return request.defaultText ?? '';
      final value = await _prompt(context(), request.message, request.defaultText);
      return value ?? '';
    });

    // --- File uploads (Android-only API) ---
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      await platform.setOnShowFileSelector(_pickFiles);
    }
  }

  /// Opens a real picker for an HTML file input and returns the chosen file(s)
  /// as `file://` URIs (what the Android WebView expects).
  static Future<List<String>> _pickFiles(FileSelectorParams params) async {
    try {
      final imageOnly = params.acceptTypes.isNotEmpty &&
          params.acceptTypes.every((t) => t.trim().startsWith('image/'));

      // Photo capture or image-only inputs → camera/gallery picker.
      if (params.isCaptureEnabled || imageOnly) {
        final image = await ImagePicker().pickImage(
          source: params.isCaptureEnabled
              ? ImageSource.camera
              : ImageSource.gallery,
        );
        return image == null ? const <String>[] : [_toFileUri(image.path)];
      }

      // Everything else (PDF / DOCX / any assignment file) → document picker.
      final path = await FlutterFileDialog.pickFile(
        params: const OpenFileDialogParams(
          dialogType: OpenFileDialogType.document,
        ),
      );
      return path == null ? const <String>[] : [_toFileUri(path)];
    } catch (_) {
      return const <String>[];
    }
  }

  /// Converts a filesystem path to a properly-encoded `file://` URI string.
  /// (Cache filenames can contain spaces, e.g. "My Assignment.pdf", which a
  /// bare "file://$path" would turn into an invalid URI that fails to upload.)
  static String _toFileUri(String path) => Uri.file(path).toString();

  static Future<void> _alert(BuildContext context, String message) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static Future<bool> _confirm(BuildContext context, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static Future<String?> _prompt(
    BuildContext context,
    String message,
    String? defaultText,
  ) {
    final controller = TextEditingController(text: defaultText ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.isNotEmpty) ...[
              Text(message),
              const SizedBox(height: 12),
            ],
            TextField(controller: controller, autofocus: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
