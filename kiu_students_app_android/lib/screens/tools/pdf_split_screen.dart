import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/pdf_creator_service.dart';
import '../../services/pdf_split_service.dart';
import 'my_pdfs_screen.dart';
import 'widgets/pdf_source_selector.dart';

enum _SplitMode { parts, size, everyN, range }

/// Tool: split one PDF into several smaller PDFs, either by number of parts or
/// by an approximate size limit per file.
class PdfSplitScreen extends StatefulWidget {
  final File? initialFile;
  const PdfSplitScreen({super.key, this.initialFile});

  @override
  State<PdfSplitScreen> createState() => _PdfSplitScreenState();
}

class _PdfSplitScreenState extends State<PdfSplitScreen> {
  final PdfSplitService _service = PdfSplitService();

  File? _source;
  Uint8List? _sourceBytes;
  int _totalPages = 0;
  int _fileSize = 0;

  _SplitMode _mode = _SplitMode.parts;
  int _parts = 2;
  int _mb = 5;
  int _kb = 500;
  bool _sizeKb = false; // unit for "by size" mode (KB vs MB)
  int _perFile = 1; // "every N pages" mode
  int _rangeStart = 1; // "page range" mode
  int _rangeEnd = 1;

  bool _loading = false;
  bool _splitting = false;

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
      final pages = _service.pageCount(bytes);
      if (!mounted) return;
      setState(() {
        _source = file;
        _sourceBytes = bytes;
        _fileSize = bytes.length;
        _totalPages = pages;
        _parts = pages >= 2 ? 2 : 1;
        _perFile = 1;
        _rangeStart = 1;
        _rangeEnd = pages;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Could not open this PDF. It may be password-protected.');
    }
  }

  // pages per file for the current settings
  int get _pagesPerPart {
    if (_mode == _SplitMode.parts) {
      return (_totalPages / _parts).ceil().clamp(1, _totalPages);
    }
    if (_mode == _SplitMode.everyN) {
      return _perFile.clamp(1, _totalPages);
    }
    // by size: estimate from average page weight
    final avg = _totalPages > 0 ? _fileSize / _totalPages : _fileSize;
    final target = _sizeKb ? _kb * 1024 : _mb * 1024 * 1024;
    final per = avg > 0 ? (target / avg).floor() : _totalPages;
    return per.clamp(1, _totalPages);
  }

  int get _resultingFiles {
    final per = _pagesPerPart;
    return per > 0 ? (_totalPages / per).ceil() : 1;
  }

  Future<void> _split() async {
    if (_sourceBytes == null || _totalPages < 2) return;

    setState(() => _splitting = true);
    try {
      final base = _source != null
          ? PdfCreatorService.displayName(_source!)
          : 'Document';
      if (_mode == _SplitMode.range) {
        await _service.extractRange(
          sourceBytes: _sourceBytes!,
          startOneBased: _rangeStart,
          endOneBased: _rangeEnd,
          baseName: base,
        );
        if (!mounted) return;
        setState(() => _splitting = false);
        await _showDoneDialog(1);
      } else {
        final files = await _service.splitByPageChunks(
          sourceBytes: _sourceBytes!,
          pagesPerPart: _pagesPerPart,
          baseName: base,
        );
        if (!mounted) return;
        setState(() => _splitting = false);
        await _showDoneDialog(files.length);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _splitting = false);
      _snack('Could not split this PDF. ($e)');
    }
  }

  Future<void> _showDoneDialog(int count) {
    final colors = AppColors.of(context);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: colors.success),
            const SizedBox(width: 10),
            const Text('Done'),
          ],
        ),
        content: Text(
          'Split into $count file${count == 1 ? '' : 's'} and saved to '
          '"My PDFs".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Stay here'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyPdfsScreen()),
              );
            },
            child: const Text('View in My PDFs'),
          ),
        ],
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
      appBar: AppBar(title: const Text('Split PDF')),
      body: Stack(
        children: [
          if (_loading)
            Center(child: CircularProgressIndicator(color: colors.primary))
          else if (hasSource)
            _buildConfig(colors)
          else
            _buildEmptyState(colors),
          if (_splitting) _buildOverlay(colors),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeColors colors) {
    return PdfSourceSelector(
      icon: Icons.call_split_rounded,
      iconColor: colors.info,
      title: 'Split PDF',
      urduLine: 'ایک پی ڈی ایف کو کئی چھوٹی فائلوں میں تقسیم کریں',
      englishLine: 'Break one PDF into several smaller files.',
      onPicked: _loadSource,
    );
  }

  Widget _buildConfig(ThemeColors colors) {
    final canSplit = _totalPages >= 2;
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
                info: '$_totalPages page${_totalPages == 1 ? '' : 's'}  •  '
                    '${PdfCreatorService.formatSize(_fileSize)}',
              ),
              const SizedBox(height: 20),
              if (!canSplit)
                _NoteRow(
                  colors: colors,
                  text: 'This PDF has only one page, so it cannot be split.',
                )
              else ...[
                Text(
                  'How would you like to split?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _modeChip(colors, _SplitMode.parts,
                        Icons.grid_view_rounded, 'Equal parts'),
                    _modeChip(colors, _SplitMode.everyN,
                        Icons.layers_rounded, 'Every N pages'),
                    _modeChip(colors, _SplitMode.size,
                        Icons.sd_storage_rounded, 'By size'),
                    _modeChip(colors, _SplitMode.range,
                        Icons.content_cut_rounded, 'Page range'),
                  ],
                ),
                const SizedBox(height: 20),
                ..._modeControls(colors),
                const SizedBox(height: 16),
                _PreviewRow(colors: colors, text: _previewText()),
              ],
            ],
          ),
        ),
        _buildBottomBar(colors, canSplit),
      ],
    );
  }

  Widget _modeChip(
      ThemeColors colors, _SplitMode mode, IconData icon, String label) {
    final selected = _mode == mode;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => setState(() => _mode = mode),
      avatar: Icon(icon,
          size: 16, color: selected ? Colors.white : colors.textSecondary),
      label: Text(label),
      labelStyle: TextStyle(
        color: selected ? Colors.white : colors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      selectedColor: colors.primary,
      backgroundColor: colors.surface,
      showCheckmark: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: selected ? colors.primary : colors.border),
      ),
    );
  }

  Widget _unitToggle(ThemeColors colors) {
    Widget chip(String label, bool kb) {
      final sel = _sizeKb == kb;
      return ChoiceChip(
        selected: sel,
        onSelected: (_) => setState(() => _sizeKb = kb),
        label: Text(label),
        labelStyle: TextStyle(
          color: sel ? Colors.white : colors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        selectedColor: colors.primary,
        backgroundColor: colors.surface,
        showCheckmark: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: sel ? colors.primary : colors.border),
        ),
      );
    }

    return Row(
      children: [
        Text('Unit', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
        const SizedBox(width: 12),
        chip('KB', true),
        const SizedBox(width: 8),
        chip('MB', false),
      ],
    );
  }

  List<Widget> _modeControls(ThemeColors colors) {
    switch (_mode) {
      case _SplitMode.parts:
        return [
          _StepperRow(
            colors: colors,
            label: 'Number of parts',
            value: '$_parts',
            onMinus: _parts > 2 ? () => setState(() => _parts--) : null,
            onPlus:
                _parts < _totalPages ? () => setState(() => _parts++) : null,
          ),
        ];
      case _SplitMode.everyN:
        return [
          _StepperRow(
            colors: colors,
            label: 'Pages per file',
            value: '$_perFile',
            onMinus: _perFile > 1 ? () => setState(() => _perFile--) : null,
            onPlus: _perFile < _totalPages
                ? () => setState(() => _perFile++)
                : null,
          ),
        ];
      case _SplitMode.size:
        return [
          _unitToggle(colors),
          const SizedBox(height: 12),
          if (_sizeKb)
            _StepperRow(
              colors: colors,
              label: 'Max size per file',
              value: '$_kb KB',
              onMinus: _kb > 100 ? () => setState(() => _kb -= 100) : null,
              onPlus: _kb < 5000 ? () => setState(() => _kb += 100) : null,
            )
          else
            _StepperRow(
              colors: colors,
              label: 'Max size per file',
              value: '$_mb MB',
              onMinus: _mb > 1 ? () => setState(() => _mb--) : null,
              onPlus: _mb < 100 ? () => setState(() => _mb++) : null,
            ),
        ];
      case _SplitMode.range:
        return [
          _StepperRow(
            colors: colors,
            label: 'From page',
            value: '$_rangeStart',
            onMinus: _rangeStart > 1
                ? () => setState(() {
                      _rangeStart--;
                      if (_rangeEnd < _rangeStart) _rangeEnd = _rangeStart;
                    })
                : null,
            onPlus: _rangeStart < _totalPages
                ? () => setState(() {
                      _rangeStart++;
                      if (_rangeEnd < _rangeStart) _rangeEnd = _rangeStart;
                    })
                : null,
          ),
          const SizedBox(height: 12),
          _StepperRow(
            colors: colors,
            label: 'To page',
            value: '$_rangeEnd',
            onMinus: _rangeEnd > _rangeStart
                ? () => setState(() => _rangeEnd--)
                : null,
            onPlus: _rangeEnd < _totalPages
                ? () => setState(() => _rangeEnd++)
                : null,
          ),
        ];
    }
  }

  String _previewText() {
    if (_mode == _SplitMode.range) {
      final n = (_rangeEnd - _rangeStart + 1).clamp(1, _totalPages);
      return 'Creates 1 file with $n page${n == 1 ? '' : 's'} '
          '(pages $_rangeStart–$_rangeEnd).';
    }
    final files = _resultingFiles;
    final per = _pagesPerPart;
    if (_mode == _SplitMode.parts) {
      return 'Creates about $files file${files == 1 ? '' : 's'}, '
          '~$per page${per == 1 ? '' : 's'} each.';
    }
    if (_mode == _SplitMode.everyN) {
      return 'Creates $files file${files == 1 ? '' : 's'} of up to '
          '$per page${per == 1 ? '' : 's'} each.';
    }
    return 'Creates about $files file${files == 1 ? '' : 's'} '
        '(~$per page${per == 1 ? '' : 's'} each). Sizes are approximate.';
  }

  Widget _buildBottomBar(ThemeColors colors, bool canSplit) {
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
          onPressed: (!canSplit || _splitting) ? null : _split,
          icon: const Icon(Icons.call_split_rounded, size: 20),
          label: const Text('Split PDF'),
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
                  'Splitting…',
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

class _StepperRow extends StatelessWidget {
  final ThemeColors colors;
  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  const _StepperRow({
    required this.colors,
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
          ),
          _RoundButton(
            icon: Icons.remove_rounded,
            colors: colors,
            onTap: onMinus,
          ),
          Container(
            width: 64,
            alignment: Alignment.center,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
          _RoundButton(
            icon: Icons.add_rounded,
            colors: colors,
            onTap: onPlus,
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final ThemeColors colors;
  final VoidCallback? onTap;

  const _RoundButton({
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled
          ? colors.primary.withValues(alpha: 0.1)
          : colors.border.withValues(alpha: 0.4),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? colors.primary : colors.textHint,
          ),
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final ThemeColors colors;
  final String text;
  const _PreviewRow({required this.colors, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: colors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
            ),
          ),
        ],
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
        color: colors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: colors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
