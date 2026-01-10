import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/category_model.dart';
import '../../models/content_model.dart';
import '../../screens/audio/audio_player_screen.dart';
import '../../screens/material/material_detail_screen.dart';
import '../../screens/pdf/pdf_viewer_screen.dart';
import '../../services/api_service.dart';
import '../../services/audio_service.dart';
import '../../services/cache_service.dart';
import '../../services/category_service.dart';
import '../../services/content_service.dart';
import '../../services/download_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/audio/mini_player.dart';
import '../../widgets/common/breadcrumbs.dart';
import '../../widgets/common/connectivity_banner.dart';
import '../../widgets/common/screen_header.dart';
import '../../widgets/home/app_drawer.dart';
import '../../widgets/home/category_card.dart';
import '../../widgets/home/material_card.dart';

import '../../widgets/common/zoom_drawer.dart';

/// Screen for displaying subcategories and materials
class CategoryScreen extends StatefulWidget {
  final CategoryModel category;
  final List<BreadcrumbItem> parentBreadcrumbs;

  const CategoryScreen({
    super.key,
    required this.category,
    this.parentBreadcrumbs = const [],
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ZoomDrawerController _zoomDrawerController = ZoomDrawerController();

  final CategoryService _categoryService = CategoryService(
    apiService: ApiService(),
    storageService: StorageService(),
    cacheService: CacheService(),
  );
  final ContentService _contentService = ContentService(
    apiService: ApiService(),
    storageService: StorageService(),
  );

  List<CategoryModel> _subcategories = [];
  List<ContentModel> _contents = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch subcategories from API
      final subcategoriesResponse = await _categoryService.getSubcategories(
        widget.category.id,
      );

      if (subcategoriesResponse.success && subcategoriesResponse.data != null) {
        _subcategories = subcategoriesResponse.data!;
      } else {
        // Fallback to children from passed category
        _subcategories = widget.category.children;
      }

      // Load contents for this category
      final contentsResponse = await _contentService.getContentsByCategory(
        widget.category.id,
      );

      if (contentsResponse.success && contentsResponse.data != null) {
        _contents = contentsResponse.data!;
      }
    } catch (e) {
      _errorMessage = 'Failed to load data';
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Get audio files for playlist
  List<ContentModel> get _audioContents {
    return _contents
        .where((c) => c.contentType.toLowerCase() == 'audio')
        .toList();
  }

  void _openContent(ContentModel content) async {
    final downloadService = DownloadService();

    // Check if already downloaded
    final existingDownload = await downloadService.getDownloadedItem(
      content.id,
    );
    final isDownloaded =
        existingDownload != null &&
        File(existingDownload.localPath).existsSync();

    // If audio, show stream/download dialog
    if (content.contentType.toLowerCase() == 'audio') {
      _showAudioOptionsDialog(
        content,
        isDownloaded,
        existingDownload?.localPath,
      );
    }
    // If PDF, download first then open
    else if (content.contentType.toLowerCase() == 'pdf') {
      if (isDownloaded) {
        // Already downloaded, open directly
        _openPdfViewer(content, existingDownload.localPath);
      } else {
        // Download first
        _showPdfDownloadDialog(content);
      }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MaterialDetailScreen(content: content),
        ),
      );
    }
  }

  void _showAudioOptionsDialog(
    ContentModel content,
    bool isDownloaded,
    String? localPath,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),

            // Stream option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.play_circle_outline,
                  color: AppColors.primary,
                ),
              ),
              title: const Text('Stream Now'),
              subtitle: const Text('Play directly without downloading'),
              onTap: () {
                Navigator.pop(ctx);
                _playAudio(content, null);
              },
            ),

            const SizedBox(height: 8),

            // Download option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDownloaded
                      ? AppColors.success.withValues(alpha: 0.1)
                      : const Color(0xFF00ACC1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDownloaded ? Icons.download_done : Icons.download_outlined,
                  color: isDownloaded
                      ? AppColors.success
                      : const Color(0xFF00ACC1),
                ),
              ),
              title: Text(isDownloaded ? 'Play Downloaded' : 'Download & Play'),
              subtitle: Text(
                isDownloaded
                    ? 'Play from saved file (offline)'
                    : 'Save for offline listening',
              ),
              onTap: () {
                Navigator.pop(ctx);
                if (isDownloaded) {
                  _playAudio(content, localPath);
                } else {
                  _downloadAndPlayAudio(content);
                }
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _playAudio(ContentModel content, String? localPath) {
    final audioList = _audioContents;
    final index = audioList.indexWhere((c) => c.id == content.id);

    final audioService = context.read<AudioService>();

    if (localPath != null) {
      // Play from local path
      audioService.initSingle(content, localPath: localPath);
    } else {
      // Stream from URL
      audioService.initPlaylist(audioList, index >= 0 ? index : 0);
    }
    audioService.play();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AudioPlayerScreen()),
    );
  }

  void _downloadAndPlayAudio(ContentModel content) async {
    // Show download progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DownloadProgressDialog(
        content: content,
        onComplete: (localPath) {
          Navigator.pop(ctx);
          _playAudio(content, localPath);
        },
        onError: (error) {
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download failed: $error'),
              backgroundColor: AppColors.error,
            ),
          );
        },
      ),
    );
  }

  void _showPdfDownloadDialog(ContentModel content) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DownloadProgressDialog(
        content: content,
        onComplete: (localPath) {
          Navigator.pop(ctx);
          _openPdfViewer(content, localPath);
        },
        onError: (error) {
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download failed: $error'),
              backgroundColor: AppColors.error,
            ),
          );
        },
      ),
    );
  }

  void _openPdfViewer(ContentModel content, String localPath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(content: content, localPath: localPath),
      ),
    );
  }

  List<BreadcrumbItem> get _breadcrumbs {
    return [
      ...widget.parentBreadcrumbs,
      BreadcrumbItem(title: widget.category.title, category: widget.category),
    ];
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
              Breadcrumbs(items: _breadcrumbs),
              ScreenHeader(
                title: widget.category.title,
                onBack: () => Navigator.pop(context),
              ),
              const Divider(height: 1),

              // Main Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                    ? _buildErrorState()
                    : _buildContent(),
              ),

              // Mini Player
              const MiniPlayer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(_errorMessage!),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_subcategories.isEmpty && _contents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No content available',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Subcategories Section
          if (_subcategories.isNotEmpty) ...[
            Text(
              'Subcategories',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemCount: _subcategories.length,
              itemBuilder: (context, index) {
                final subcategory = _subcategories[index];
                return CategoryCard(
                  category: subcategory,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoryScreen(
                          category: subcategory,
                          parentBreadcrumbs: _breadcrumbs,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
          ],

          // Materials Section
          if (_contents.isNotEmpty) ...[
            Text(
              'Materials',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...List.generate(_contents.length, (index) {
              final content = _contents[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MaterialCard(
                  content: content,
                  onTap: () => _openContent(content),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

/// Download progress dialog
class _DownloadProgressDialog extends StatefulWidget {
  final ContentModel content;
  final void Function(String localPath) onComplete;
  final void Function(String error) onError;

  const _DownloadProgressDialog({
    required this.content,
    required this.onComplete,
    required this.onError,
  });

  @override
  State<_DownloadProgressDialog> createState() =>
      _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      // Get app's private directory
      final dir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${dir.path}/downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Generate filename
      final extension = _getFileExtension(widget.content.contentType);
      final filename =
          '${widget.content.id}_${DateTime.now().millisecondsSinceEpoch}$extension';
      final filePath = '${downloadsDir.path}/$filename';

      // Download file
      final dio = Dio();
      await dio.download(
        widget.content.backblazeUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              _progress = received / total;
            });
          }
        },
      );

      // Get file size and save to database
      final file = File(filePath);
      final fileSize = await file.length();

      final downloadService = DownloadService();
      final downloadedItem = DownloadedItem.fromContent(
        widget.content,
        filePath,
        fileSize,
      );
      await downloadService.saveDownload(downloadedItem);

      setState(() => _isComplete = true);

      // Small delay to show completion
      await Future.delayed(const Duration(milliseconds: 300));

      widget.onComplete(filePath);
    } catch (e) {
      widget.onError(e.toString());
    }
  }

  String _getFileExtension(String contentType) {
    switch (contentType.toLowerCase()) {
      case 'pdf':
        return '.pdf';
      case 'audio':
        return '.mp3';
      case 'video':
        return '.mp4';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: _isComplete
                ? Icon(Icons.check, size: 40, color: AppColors.success)
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          value: _progress > 0 ? _progress : null,
                          strokeWidth: 4,
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                      Text(
                        '${(_progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          Text(
            _isComplete ? 'Download Complete!' : 'Downloading...',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            widget.content.title,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
