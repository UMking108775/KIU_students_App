import 'package:flutter/material.dart';

/// A reusable single-field text-input dialog that OWNS its
/// [TextEditingController] — created in `initState`, disposed in `dispose`.
///
/// This avoids the "A TextEditingController was used after being disposed" crash
/// that happens when a caller creates a controller locally and disposes it right
/// after `await showDialog(...)` returns: the dialog's pop/exit animation rebuilds
/// the `TextField` for a few frames after that, and would touch the disposed
/// controller. Because this widget disposes the controller in its own State
/// lifecycle, the controller stays alive until the dialog is fully gone.
class TextPromptDialog extends StatefulWidget {
  final String title;
  final String label;
  final String initialText;
  final String? suffixText;
  final String confirmLabel;
  final TextCapitalization textCapitalization;
  final TextInputType keyboardType;

  const TextPromptDialog({
    super.key,
    required this.title,
    this.label = '',
    this.initialText = '',
    this.suffixText,
    this.confirmLabel = 'Save',
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType = TextInputType.text,
  });

  @override
  State<TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<TextPromptDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: widget.textCapitalization,
        keyboardType: widget.keyboardType,
        decoration: InputDecoration(
          labelText: widget.label.isEmpty ? null : widget.label,
          suffixText: widget.suffixText,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
