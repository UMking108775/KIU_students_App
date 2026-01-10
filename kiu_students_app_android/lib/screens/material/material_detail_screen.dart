import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../models/content_model.dart';
import '../../screens/audio/audio_player_screen.dart';
import '../../screens/pdf/pdf_viewer_screen.dart';
import '../../services/download_service.dart';
import '../../widgets/common/connectivity_banner.dart';
import '../../widgets/common/screen_header.dart';
import '../../widgets/home/app_drawer.dart';

import 'package:provider/provider.dart';
import '../../widgets/common/zoom_drawer.dart';

/// Screen for viewing material details and opening/downloading content
class MaterialDetailScreen extends StatefulWidget {
  final ContentModel content;

  const MaterialDetailScreen({super.key, required this.content});

  @override
  State<MaterialDetailScreen> createState() => _MaterialDetailScreenState();
}

class _MaterialDetailScreenState extends State<MaterialDetailScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ZoomDrawerController _zoomDrawerController = ZoomDrawerController();
  final DownloadService _downloadService = DownloadService();
  bool _isDownloading = false;
  double _downloadProgress = 0;
  bool _isDownloaded = false;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _checkIfDownloaded();
  }

  Future<void> _checkIfDownloaded() async {
    final item = await _downloadService.getDownloadedItem(widget.content.id);
    if (item != null && File(item.localPath).existsSync()) {
      setState(() {
        _isDownloaded = true;
        _localPath = item.localPath;
      });
    }
  }

  IconData _getTypeIcon() {
    switch (widget.content.contentType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'video':
        return Icons.play_circle_outline;
      case 'audio':
        return Icons.audiotrack_outlined;
      case 'ppt':
        return Icons.slideshow_outlined;
      case 'doc':
        return Icons.description_outlined;
      case 'image':
        return Icons.image_outlined;
      case 'zip':
        return Icons.folder_zip_outlined;
      case 'link':
        return Icons.link;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color _getTypeColor() {
    switch (widget.content.contentType.toLowerCase()) {
      case 'pdf':
        return const Color(0xFFE53935);
      case 'video':
        return const Color(0xFF8E24AA);
      case 'audio':
        return const Color(0xFF00ACC1);
      case 'ppt':
        return const Color(0xFFFF7043);
      case 'doc':
        return const Color(0xFF1E88E5);
      case 'image':
        return const Color(0xFF43A047);
      case 'zip':
        return const Color(0xFF8D6E63);
      case 'link':
        return const Color(0xFF5C6BC0);
      default:
        return AppColors.primary;
    }
  }

  Future<void> _downloadContent() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    try {
      // Get app's private directory
      final dir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${dir.path}/downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Generate filename
      final extension = _getFileExtension();
      final filename =
          '${widget.content.id}_${DateTime.now().millisecondsSinceEpoch}$extension';
      final filePath = '${downloadsDir.path}/$filename';

      // Download file
      final dio = Dio();
      await dio.download(
        widget.content.backblazeUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      // Get file size
      final file = File(filePath);
      final fileSize = await file.length();

      // Save to database
      final downloadedItem = DownloadedItem.fromContent(
        widget.content,
        filePath,
        fileSize,
      );
      await _downloadService.saveDownload(downloadedItem);

      setState(() {
        _isDownloaded = true;
        _localPath = filePath;
        _isDownloading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded: ${widget.content.title}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _getFileExtension() {
    switch (widget.content.contentType.toLowerCase()) {
      case 'pdf':
        return '.pdf';
      case 'audio':
        return '.mp3';
      case 'video':
        return '.mp4';
      case 'ppt':
        return '.pptx';
      case 'doc':
        return '.docx';
      case 'image':
        return '.jpg';
      case 'zip':
        return '.zip';
      default:
        return '';
    }
  }

  Future<void> _openContent() async {
    // For audio, open in our audio player
    if (widget.content.contentType.toLowerCase() == 'audio') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              AudioPlayerScreen(content: widget.content, localPath: _localPath),
        ),
      );
      return;
    }

    // For PDF, open in our PDF viewer
    if (widget.content.contentType.toLowerCase() == 'pdf') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PdfViewerScreen(content: widget.content, localPath: _localPath),
        ),
      );
      return;
    }

    // For other types, open externally
    final uri = Uri.parse(widget.content.backblazeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open this content'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => _zoomDrawerController,
      child: ZoomDrawer(
        controller: _zoomDrawerController,
        menuScreen: const AppDrawer(),
        mainScreen: Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _zoomDrawerController.toggle(),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset('assets/images/kiu_logo.png', height: 28),
                ),
                const SizedBox(width: 10),
                const Text('KIU Students'),
              ],
            ),
          ),
          body: Column(
            children: [
              const ConnectivityBanner(),
              ScreenHeader(
                title: widget.content.title,
                onBack: () => Navigator.pop(context),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),

                      // Type Icon
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: _getTypeColor().withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(
                          _getTypeIcon(),
                          size: 48,
                          color: _getTypeColor(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Title
                      Text(
                        widget.content.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 12),

                      // Type Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _getTypeColor().withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.content.typeDisplayName,
                              style: TextStyle(
                                color: _getTypeColor(),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_isDownloaded) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.download_done,
                                    size: 16,
                                    color: AppColors.success,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Downloaded',
                                    style: TextStyle(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Info Cards
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            if (widget.content.category != null) ...[
                              _InfoRow(
                                icon: Icons.folder_outlined,
                                label: 'Category',
                                value: widget.content.category!.title,
                              ),
                              const Divider(height: 24),
                            ],
                            _InfoRow(
                              icon: Icons.calendar_today_outlined,
                              label: 'Added',
                              value: _formatDate(widget.content.createdAt),
                            ),
                            const Divider(height: 24),
                            _InfoRow(
                              icon: Icons.update_outlined,
                              label: 'Updated',
                              value: _formatDate(widget.content.updatedAt),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Download Progress
                      if (_isDownloading) ...[
                        Column(
                          children: [
                            LinearProgressIndicator(
                              value: _downloadProgress,
                              backgroundColor: AppColors.border,
                              valueColor: AlwaysStoppedAnimation(
                                _getTypeColor(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Downloading... ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isDownloading
                                  ? null
                                  : (_isDownloaded ? null : _downloadContent),
                              icon: Icon(
                                _isDownloaded
                                    ? Icons.download_done
                                    : Icons.download_outlined,
                              ),
                              label: Text(
                                _isDownloaded ? 'Downloaded' : 'Download',
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                side: BorderSide(
                                  color: _isDownloaded
                                      ? AppColors.success
                                      : _getTypeColor(),
                                ),
                                foregroundColor: _isDownloaded
                                    ? AppColors.success
                                    : _getTypeColor(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _openContent,
                              icon: Icon(
                                widget.content.contentType.toLowerCase() ==
                                        'audio'
                                    ? Icons.play_arrow
                                    : Icons.open_in_new,
                              ),
                              label: Text(
                                widget.content.contentType.toLowerCase() ==
                                        'audio'
                                    ? 'Play'
                                    : 'Open',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _getTypeColor(),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
