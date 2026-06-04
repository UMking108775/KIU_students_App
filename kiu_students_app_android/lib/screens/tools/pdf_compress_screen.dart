import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../widgets/common/text_prompt_dialog.dart';
import '../../services/pdf_creator_service.dart';
import '../../services/pdf_compress_service.dart';
import 'pdf_result_screen.dart';
import 'widgets/pdf_source_selector.dart';

/// Tool: shrink a PDF's file size so it's easier to send or upload.
class PdfCompressScreen extends StatefulWidget {
  final File? initialFile;
  const PdfCompressScreen({super.key, this.initialFile});

  @override
  State<PdfCompressScreen> createState() => _PdfCompressScreenState();
}

class _PdfCompressScreenState extends State<PdfCompressScreen> {
  final PdfCompressService _service = PdfCompressService();

  File? _source;
  Uint8List? _sourceBytes;
  int _originalSize = 0;
  CompressLevel _level = CompressLevel.balanced;

  bool _loading = false;
  bool _compressing = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadSource(widget.initialFile!);
      });
    }
  }

  Future<void> _loadSource(File file) async {
    setState(() => _loading = true);
    try {
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _source = file;
        _sourceBytes = bytes;
        _originalSize = bytes.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Could not open this PDF. ($e)');
    }
  }

  Future<void> _compress() async {
    if (_sourceBytes == null) return;
    final base = _source != null
        ? PdfCreatorService.displayName(_source!)
        : 'Document';
    final name = await _askFileName('${base}_compressed');
    if (name == null) return;

    setState(() => _compressing = true);
    try {
      final file = await _service.compress(
        sourceBytes: _sourceBytes!,
        level: _level,
        fileName: name,
      );
      if (!mounted) return;
      setState(() => _compressing = false);

      final newSize = file.lengthSync();
      final message = _savingsMessage(_originalSize, newSize);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfResultScreen(file: file, successMessage: message),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _compressing = false);
      _snack('Could not compress this PDF. ($e)');
    }
  }

  String _savingsMessage(int oldSize, int newSize) {
    final oldText = PdfCreatorService.formatSize(oldSize);
    final newText = PdfCreatorService.formatSize(newSize);
    if (oldSize > 0 && newSize < oldSize) {
      final pct = ((1 - newSize / oldSize) * 100).round();
      return 'Compressed: $oldText → $newText  ($pct% smaller)';
    }
    return 'Saved: $newText (this PDF was already well compressed)';
  }

  Future<String?> _askFileName(String defaultName) {
    return showDialog<String>(
      context: context,
      builder: (_) => TextPromptDialog(
        title: 'Save compressed PDF',
        label: 'File name',
        initialText: defaultName,
        suffixText: '.pdf',
        confirmLabel: 'Compress',
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.of(context).error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasSource = _sourceBytes != null;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Compress PDF')),
      body: Stack(
        children: [
          if (_loading)
            Center(child: CircularProgressIndicator(color: colors.primary))
          else if (hasSource)
            _buildConfig(colors)
          else
            _buildEmptyState(colors),
          if (_compressing) _buildOverlay(colors),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeColors colors) {
    return PdfSourceSelector(
      icon: Icons.compress_rounded,
      iconColor: colors.warning,
      title: 'Compress PDF',
      urduLine: 'پی ڈی ایف کا سائز چھوٹا کریں',
      englishLine: 'Make a PDF smaller so it\'s easy to send or upload.',
      onPicked: _loadSource,
    );
  }

  Widget _buildConfig(ThemeColors colors) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _FileInfoCard(
                colors: colors,
                name: _source != null
                    ? PdfCreatorService.displayName(_source!)
                    : 'Document',
                info: 'Current size: '
                    '${PdfCreatorService.formatSize(_originalSize)}',
              ),
              const SizedBox(height: 20),
              Text(
                'Choose compression level',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _LevelTile(
                colors: colors,
                selected: _level == CompressLevel.high,
                title: 'High quality',
                subtitle: 'Slightly smaller • best page clarity',
                onTap: () => setState(() => _level = CompressLevel.high),
              ),
              const SizedBox(height: 10),
              _LevelTile(
                colors: colors,
                selected: _level == CompressLevel.balanced,
                title: 'Balanced (recommended)',
                subtitle: 'Good size and clarity',
                onTap: () => setState(() => _level = CompressLevel.balanced),
              ),
              const SizedBox(height: 10),
              _LevelTile(
                colors: colors,
                selected: _level == CompressLevel.small,
                title: 'Smallest size',
                subtitle: 'Maximum shrink • lower clarity',
                onTap: () => setState(() => _level = CompressLevel.small),
              ),
              const SizedBox(height: 12),
              _NoteRow(
                colors: colors,
                text: 'Pages are re-saved as images, so text may no longer be '
                    'selectable. Great for scanned assignments.',
              ),
            ],
          ),
        ),
        _buildBottomBar(colors),
      ],
    );
  }

  Widget _buildBottomBar(ThemeColors colors) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _compressing ? null : _compress,
          icon: const Icon(Icons.compress_rounded, size: 20),
          label: const Text('Compress PDF'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(ThemeColors colors) {
    return Positioned.fill(
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
                  'Compressing…',
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
    );
  }
}

class _FileInfoCard extends StatelessWidget {
  final ThemeColors colors;
  final String name;
  final String info;

  const _FileInfoCard({
    required this.colors,
    required this.name,
    required this.info,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.picture_as_pdf_rounded,
              color: colors.error,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  info,
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final ThemeColors colors;
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LevelTile({
    required this.colors,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? colors.primary : colors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? colors.primary : colors.textHint,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  final ThemeColors colors;
  final String text;
  const _NoteRow({required this.colors, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: colors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
