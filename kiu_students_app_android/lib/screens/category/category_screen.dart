import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/category_model.dart';
import '../../models/content_model.dart';
import '../../providers/auth_provider.dart';
import '../../screens/audio/audio_player_screen.dart';
import '../../screens/material/material_detail_screen.dart';
import '../../screens/pdf/pdf_viewer_screen.dart';
import '../../services/audio_service.dart';
import '../../services/category_service.dart';
import '../../services/content_service.dart';
import '../../services/download_service.dart';
import '../../services/guest_service.dart';
import 'dart:async'; // Added
import 'package:connectivity_plus/connectivity_plus.dart'; // For connectivity check
import '../../services/background_sync_service.dart'; // Added
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

  final CategoryService _categoryService = CategoryService();
  final ContentService _contentService = ContentService();

  List<CategoryModel> _subcategories = [];
  List<ContentModel> _contents = [];
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initSyncListener();
  }

  void _initSyncListener() {
    // Listen for background sync events
    try {
      final syncService = BackgroundSyncService();
      if (syncService.isInitialized) {
        _syncSubscription = syncService.syncEvents.listen((event) {
          if (event.type == SyncEventType.categoriesUpdated ||
              event.type == SyncEventType.contentUpdated) {
            // Refresh data from cache (sync service already updated the cache)
            if (mounted) {
              _loadData(forceRefresh: false);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error initializing sync listener: $e');
    }
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _zoomDrawerController.dispose();
    super.dispose();
  }

  /// Load data - uses cache first for instant display
  /// If cache exists, displays instantly without loading spinner
  Future<void> _loadData({bool forceRefresh = false}) async {
    // Only show loading if we have no data yet
    if (_subcategories.isEmpty && _contents.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // Fetch subcategories (uses cache-first)
      final subcategoriesResponse = await _categoryService.getSubcategories(
        widget.category.id,
        forceRefresh: forceRefresh,
      );

      if (subcategoriesResponse.success && subcategoriesResponse.data != null) {
        _subcategories = subcategoriesResponse.data!;
      } else if (_subcategories.isEmpty) {
        // Fallback to children from passed category only if we have nothing
        _subcategories = widget.category.children;
      }

      // Load contents for this category (uses cache-first)
      final contentsResponse = await _contentService.getContentsByCategory(
        widget.category.id,
        forceRefresh: forceRefresh,
      );

      if (contentsResponse.success && contentsResponse.data != null) {
        _contents = contentsResponse.data!;
      }
    } catch (e) {
      if (_subcategories.isEmpty && _contents.isEmpty) {
        _errorMessage = 'Failed to load data';
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Smart refresh - only refreshes current page content (not all categories)
  Future<void> _refreshData() async {
    await _loadData(forceRefresh: true);
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
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MaterialDetailScreen(content: content),
          ),
        );
      }
    }
  }

  void _showAudioOptionsDialog(
    ContentModel content,
    bool isDownloaded,
    String? localPath,
  ) {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),

            // Stream option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.play_circle_outline, color: colors.primary),
              ),
              title: Text(
                'Stream Now',
                style: TextStyle(color: colors.textPrimary),
              ),
              subtitle: Text(
                'Play directly without downloading',
                style: TextStyle(color: colors.textSecondary),
              ),
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
                      ? colors.success.withValues(alpha: 0.1)
                      : colors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDownloaded ? Icons.download_done : Icons.download_outlined,
                  color: isDownloaded ? colors.success : colors.info,
                ),
              ),
              title: Text(
                isDownloaded ? 'Play Downloaded' : 'Download & Play',
                style: TextStyle(color: colors.textPrimary),
              ),
              subtitle: Text(
                isDownloaded
                    ? 'Play from saved file (offline)'
                    : 'Save for offline listening',
                style: TextStyle(color: colors.textSecondary),
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
    final authProvider = context.read<AuthProvider>();
    final audioService = context.read<AudioService>();

    if (localPath != null) {
      // Play from local path - single track only
      audioService.initSingle(content, localPath: localPath);
    } else if (authProvider.isGuestMode) {
      // Guest mode: only pass the single allowed audio, no playlist access
      audioService.initSingle(content);
    } else {
      // Logged in user: full playlist access
      final audioList = _audioContents;
      final index = audioList.indexWhere((c) => c.id == content.id);
      audioService.initPlaylist(audioList, index >= 0 ? index : 0);
    }
    audioService.play();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AudioPlayerScreen()),
    );
  }

  void _downloadAndPlayAudio(ContentModel content) async {
    // Get context-dependent values before async operations
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.user;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (currentUser == null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Please login to download'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Check connectivity first
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.isEmpty || connectivity.first == ConnectivityResult.none) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('No internet connection. Please check your network.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    // Show download progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DownloadProgressDialog(
        content: content,
        userKiuId: currentUser.kiuId,
        onComplete: (localPath) {
          Navigator.pop(ctx);
          _playAudio(content, localPath);
        },
        onError: (error) {
          Navigator.pop(ctx);
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Download failed: $error'),
              backgroundColor: AppColors.error,
            ),
          );
        },
      ),
    );
  }

  void _showPdfDownloadDialog(ContentModel content) async {
    // Get context-dependent values before async operations
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.user;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (currentUser == null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Please login to download'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Check connectivity first
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.isEmpty || connectivity.first == ConnectivityResult.none) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('No internet connection. Please check your network.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DownloadProgressDialog(
        content: content,
        userKiuId: currentUser.kiuId,
        onComplete: (localPath) {
          Navigator.pop(ctx);
          _openPdfViewer(content, localPath);
        },
        onError: (error) {
          Navigator.pop(ctx);
          scaffoldMessenger.showSnackBar(
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
    // Get theme colors
    final colors = AppColors.of(context);

    return ChangeNotifierProvider.value(
      value: _zoomDrawerController,
      child: ZoomDrawer(
        controller: _zoomDrawerController,
        menuScreen: const AppDrawer(),
        mainScreen: Scaffold(
          key: _scaffoldKey,
          backgroundColor: colors.background,
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
                  decoration: BoxDecoration(
                    color: colors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset('assets/images/kiu_logo.png', height: 28),
                ),
                const SizedBox(width: 10),
                Text(
                  'KIU Students',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
              Divider(height: 1, color: colors.border),

              // Main Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                    ? _buildErrorState(colors)
                    : _buildContent(colors),
              ),

              // Mini Player
              const MiniPlayer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: colors.error),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: TextStyle(color: colors.textPrimary)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeColors colors) {
    if (_subcategories.isEmpty && _contents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open_outlined,
              size: 64,
              color: colors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No content available',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    final authProvider = context.read<AuthProvider>();
    var displaySubcategories = _subcategories;
    var displayContents = _contents;

    // Filter for guest mode
    if (authProvider.isGuestMode) {
      final guestService = GuestService();
      displaySubcategories = guestService.filterCategoriesForGuest(
        _subcategories,
      );
      displayContents = guestService.filterContentForGuest(
        _contents,
        getFileType: (c) => c.contentType,
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: colors.primary, // Add refresh color
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Guest Mode Limits Banner
          if (authProvider.isGuestMode)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: colors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Guest Mode: Showing limited content (${displaySubcategories.length} subcategory, ${displayContents.where((c) => c.contentType.toLowerCase().contains('audio')).length} audio, ${displayContents.where((c) => c.contentType.toLowerCase().contains('pdf')).length} PDF).',
                      style: TextStyle(fontSize: 12, color: colors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),

          // Subcategories Section
          if (displaySubcategories.isNotEmpty) ...[
            Text(
              'Subcategories',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
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
              itemCount: displaySubcategories.length,
              itemBuilder: (context, index) {
                final subcategory = displaySubcategories[index];
                return CategoryCard(
                  category: subcategory,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoryScreen(
                          category: subcategory,
                          parentBreadcrumbs: widget.parentBreadcrumbs.isEmpty
                              ? [BreadcrumbItem(title: widget.category.title)]
                              : [
                                  ...widget.parentBreadcrumbs,
                                  BreadcrumbItem(title: widget.category.title),
                                ],
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
          if (displayContents.isNotEmpty) ...[
            Text(
              'Materials',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(displayContents.length, (index) {
              final content = displayContents[index];
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
  final String userKiuId;
  final void Function(String localPath) onComplete;
  final void Function(String error) onError;

  const _DownloadProgressDialog({
    required this.content,
    required this.userKiuId,
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
      final downloadService = DownloadService();

      // Get user-specific download directory based on content type
      Directory userDir;
      if (widget.content.contentType.toLowerCase() == 'audio') {
        userDir = await downloadService.getUserAudioDir(widget.userKiuId);
      } else if (widget.content.contentType.toLowerCase() == 'pdf') {
        userDir = await downloadService.getUserPdfDir(widget.userKiuId);
      } else {
        userDir = await downloadService.getUserDownloadDir(widget.userKiuId);
      }

      // Generate filename
      final extension = _getFileExtension(widget.content.contentType);
      final filename =
          '${widget.content.id}_${DateTime.now().millisecondsSinceEpoch}$extension';
      final filePath = '${userDir.path}/$filename';

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

      final downloadedItem = DownloadedItem.fromContent(
        widget.content,
        filePath,
        fileSize,
        widget.userKiuId,
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
    final colors = AppColors.of(context);

    return AlertDialog(
      backgroundColor: colors.surface,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: _isComplete
                ? Icon(Icons.check, size: 40, color: colors.success)
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          value: _progress > 0 ? _progress : null,
                          strokeWidth: 4,
                          valueColor: AlwaysStoppedAnimation(colors.primary),
                        ),
                      ),
                      Text(
                        '${(_progress * 100).toInt()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          Text(
            _isComplete ? 'Download Complete!' : 'Downloading...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
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
