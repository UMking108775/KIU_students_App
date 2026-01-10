import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../../config/app_theme.dart';
import '../../models/content_model.dart';
import '../../services/pdf_bookmark_service.dart';
import '../../widgets/common/connectivity_banner.dart';

/// Fast native PDF viewer with page navigation and bookmarks
class PdfViewerScreen extends StatefulWidget {
  final ContentModel content;
  final String? localPath;

  const PdfViewerScreen({super.key, required this.content, this.localPath});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen>
    with TickerProviderStateMixin {
  final PdfBookmarkService _bookmarkService = PdfBookmarkService();
  PDFViewController? _pdfViewController;

  int _currentPage = 0;
  int _totalPages = 0;
  bool _isReady = false;
  bool _isCurrentPageBookmarked = false;
  bool _showControls = true;
  List<PdfBookmark> _bookmarks = [];

  // Animation controllers for smooth slide
  late AnimationController _topBarController;
  late AnimationController _bottomBarController;
  late Animation<Offset> _topBarSlideAnimation;
  late Animation<Offset> _bottomBarSlideAnimation;

  // Text field controller for page navigation
  final TextEditingController _pageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
    _loadLastReadPage();

    // Initialize animations
    _topBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bottomBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _topBarSlideAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(0, -1)).animate(
          CurvedAnimation(parent: _topBarController, curve: Curves.easeInOut),
        );

    _bottomBarSlideAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(0, 1)).animate(
          CurvedAnimation(
            parent: _bottomBarController,
            curve: Curves.easeInOut,
          ),
        );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _topBarController.dispose();
    _bottomBarController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _topBarController.reverse();
      _bottomBarController.reverse();
    } else {
      _topBarController.forward();
      _bottomBarController.forward();
    }
  }

  Future<void> _loadBookmarks() async {
    final bookmarks = await _bookmarkService.getBookmarks(
      widget.content.id.toString(),
    );
    if (mounted) {
      setState(() {
        _bookmarks = bookmarks;
      });
    }
    _checkCurrentPageBookmark();
  }

  Future<void> _loadLastReadPage() async {
    final lastPage = await _bookmarkService.getLastReadPage(
      widget.content.id.toString(),
    );
    if (lastPage > 0 && _pdfViewController != null) {
      _pdfViewController!.setPage(lastPage);
    }
  }

  void _checkCurrentPageBookmark() async {
    final isBookmarked = await _bookmarkService.isBookmarked(
      widget.content.id.toString(),
      _currentPage + 1, // 1-indexed for display
    );
    if (mounted) {
      setState(() {
        _isCurrentPageBookmarked = isBookmarked;
      });
    }
  }

  Future<void> _toggleBookmark() async {
    final pageNumber = _currentPage + 1; // 1-indexed for display
    if (_isCurrentPageBookmarked) {
      await _bookmarkService.removeBookmark(
        widget.content.id.toString(),
        pageNumber,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bookmark removed from page $pageNumber'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      await _bookmarkService.addBookmark(
        PdfBookmark(
          contentId: widget.content.id.toString(),
          pageNumber: pageNumber,
          createdAt: DateTime.now(),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Page $pageNumber bookmarked'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    await _loadBookmarks();
  }

  void _showBookmarksSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildBookmarksSheet(),
    );
  }

  void _showGoToPageDialog() {
    _pageController.text = (_currentPage + 1).toString();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Go to Page'),
        content: TextField(
          controller: _pageController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Page number (1-$_totalPages)',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final page = int.tryParse(_pageController.text);
              if (page != null && page >= 1 && page <= _totalPages) {
                _pdfViewController?.setPage(page - 1); // 0-indexed
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Please enter a valid page number (1-$_totalPages)',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localPath = widget.localPath;

    // Check if we have a valid local file
    if (localPath == null || !File(localPath).existsSync()) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(widget.content.title),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              const Text('PDF file not found'),
              const SizedBox(height: 8),
              Text(
                'Please download the file first',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // PDF Viewer (tap to toggle controls)
            GestureDetector(
              onTap: _toggleControls,
              child: PDFView(
                filePath: localPath,
                enableSwipe: true,
                swipeHorizontal: false,
                autoSpacing: true,
                pageFling: true,
                pageSnap: true,
                fitPolicy: FitPolicy.BOTH,
                preventLinkNavigation: false,
                onRender: (pages) {
                  setState(() {
                    _totalPages = pages ?? 0;
                    _isReady = true;
                  });
                },
                onError: (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error loading PDF: $error'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                },
                onPageError: (page, error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error on page $page: $error'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                },
                onViewCreated: (PDFViewController pdfViewController) {
                  _pdfViewController = pdfViewController;
                  _loadLastReadPage();
                },
                onPageChanged: (int? page, int? total) {
                  if (page != null) {
                    setState(() {
                      _currentPage = page;
                      if (total != null) _totalPages = total;
                    });
                    _bookmarkService.saveLastReadPage(
                      widget.content.id.toString(),
                      page,
                    );
                    _checkCurrentPageBookmark();
                  }
                },
              ),
            ),

            // Loading overlay
            if (!_isReady)
              Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf,
                          size: 40,
                          color: Color(0xFFE53935),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Color(0xFFE53935)),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Loading PDF...',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),

            // Top controls with slide animation
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: _topBarSlideAnimation,
                child: _buildTopBar(),
              ),
            ),

            // Bottom controls with slide animation
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: _bottomBarSlideAnimation,
                child: _buildBottomBar(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
        ),
      ),
      child: Column(
        children: [
          const ConnectivityBanner(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                // Back button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),

                // Title
                Expanded(
                  child: Text(
                    widget.content.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Bookmark current page
                Container(
                  decoration: BoxDecoration(
                    color: _isCurrentPageBookmarked
                        ? Colors.amber.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isCurrentPageBookmarked
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      color: _isCurrentPageBookmarked
                          ? Colors.amber
                          : Colors.white,
                      size: 22,
                    ),
                    onPressed: _toggleBookmark,
                    tooltip: 'Bookmark this page',
                  ),
                ),
                const SizedBox(width: 8),

                // View all bookmarks
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Stack(
                      children: [
                        const Icon(
                          Icons.bookmarks_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                        if (_bookmarks.isNotEmpty)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 14,
                                minHeight: 14,
                              ),
                              child: Text(
                                '${_bookmarks.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onPressed: _showBookmarksSheet,
                    tooltip: 'View bookmarks',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.9), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Page slider
          Row(
            children: [
              Text(
                '1',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16,
                    ),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: (_currentPage + 1).toDouble().clamp(
                      1,
                      _totalPages > 0 ? _totalPages.toDouble() : 1,
                    ),
                    min: 1,
                    max: _totalPages > 0 ? _totalPages.toDouble() : 1,
                    onChanged: (value) {
                      _pdfViewController?.setPage(value.toInt() - 1);
                    },
                    activeColor: AppColors.primary,
                    inactiveColor: Colors.white30,
                  ),
                ),
              ),
              Text(
                '$_totalPages',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Page controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // First page
              _buildControlButton(
                Icons.first_page,
                () => _pdfViewController?.setPage(0),
                enabled: _currentPage > 0,
              ),

              // Previous page
              _buildControlButton(
                Icons.chevron_left,
                () => _pdfViewController?.setPage(_currentPage - 1),
                enabled: _currentPage > 0,
                size: 32,
              ),

              // Page indicator (tappable)
              GestureDetector(
                onTap: _showGoToPageDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    '${_currentPage + 1} / $_totalPages',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

              // Next page
              _buildControlButton(
                Icons.chevron_right,
                () => _pdfViewController?.setPage(_currentPage + 1),
                enabled: _currentPage < _totalPages - 1,
                size: 32,
              ),

              // Last page
              _buildControlButton(
                Icons.last_page,
                () => _pdfViewController?.setPage(_totalPages - 1),
                enabled: _currentPage < _totalPages - 1,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
    IconData icon,
    VoidCallback onPressed, {
    bool enabled = true,
    double size = 24,
    String? tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: enabled
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.3),
          size: size,
        ),
        onPressed: enabled ? onPressed : null,
        tooltip: tooltip,
      ),
    );
  }

  Widget _buildBookmarksSheet() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bookmarks, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Text(
                'Bookmarks',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_bookmarks.length} saved',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Bookmarks list
          if (_bookmarks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.bookmark_border,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No bookmarks yet',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap the bookmark icon to save pages',
                      style: TextStyle(color: AppColors.textHint, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _bookmarks.length,
                itemBuilder: (context, index) {
                  final bookmark = _bookmarks[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${bookmark.pageNumber}',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      title: Text(
                        'Page ${bookmark.pageNumber}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Added ${_formatDate(bookmark.createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: AppColors.error,
                        onPressed: () async {
                          await _bookmarkService.removeBookmark(
                            widget.content.id.toString(),
                            bookmark.pageNumber,
                          );
                          await _loadBookmarks();
                        },
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _pdfViewController?.setPage(bookmark.pageNumber - 1);
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'today';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
