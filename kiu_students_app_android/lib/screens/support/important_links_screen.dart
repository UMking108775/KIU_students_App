import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../models/support_models.dart';
import '../../services/api_service.dart';
import '../../services/help_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/common/zoom_drawer.dart';
import '../../widgets/home/app_drawer.dart';

class ImportantLinksScreen extends StatefulWidget {
  const ImportantLinksScreen({super.key});

  @override
  State<ImportantLinksScreen> createState() => _ImportantLinksScreenState();
}

class _ImportantLinksScreenState extends State<ImportantLinksScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ZoomDrawerController _zoomDrawerController = ZoomDrawerController();
  late HelpService _helpService;
  List<ImportantLinkModel> _links = [];
  bool _isLoading = true;
  String? _error;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _helpService = HelpService(
      apiService: ApiService(),
      storageService: StorageService(),
    );
    _loadLinks();
  }

  @override
  void dispose() {
    _zoomDrawerController.dispose();
    super.dispose();
  }

  Future<void> _loadLinks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response = await _helpService.getImportantLinks();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.success) {
          _links = response.data ?? [];
        } else {
          _error = response.message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ChangeNotifierProvider.value(
      value: _zoomDrawerController,
      child: ZoomDrawer(
        controller: _zoomDrawerController,
        menuScreen: const AppDrawer(),
        mainScreen: Scaffold(
          key: _scaffoldKey,
          backgroundColor: colors.background,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: AppBar(
              toolbarHeight: 48,
              leading: IconButton(
                icon: const Icon(Icons.menu, size: 22),
                onPressed: () => _zoomDrawerController.toggle(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              title: const Text(
                'Important Links',
                style: TextStyle(fontSize: 16),
              ),
              centerTitle: true,
            ),
          ),
          body: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final colors = AppColors.of(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colors.error),
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadLinks,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_links.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link_off, size: 48, color: colors.textHint),
            const SizedBox(height: 12),
            Text(
              'No important links available',
              style: TextStyle(color: colors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final response = await _helpService.getImportantLinks(
          forceRefresh: true,
        );
        if (mounted && response.success) {
          setState(() {
            _links = response.data ?? [];
          });
        }
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _links.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final link = _links[index];
          final isExpanded = _expandedIndex == index;

          return _ImportantLinkCard(
            link: link,
            isExpanded: isExpanded,
            onTap: () {
              setState(() {
                _expandedIndex = isExpanded ? null : index;
              });
            },
          );
        },
      ),
    );
  }
}

class _ImportantLinkCard extends StatelessWidget {
  final ImportantLinkModel link;
  final bool isExpanded;
  final VoidCallback onTap;

  const _ImportantLinkCard({
    required this.link,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded
              ? colors.primary.withValues(alpha: 0.3)
              : colors.border,
          width: isExpanded ? 1.5 : 0.5,
        ),
        boxShadow: isExpanded
            ? [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.primary,
                          colors.primary.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      link.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: colors.textSecondary,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedContent(context),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Video Thumbnail with Play Button
              _buildVideoThumbnail(context),
              const SizedBox(height: 14),
              // Description
              _buildDescription(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoThumbnail(BuildContext context) {
    final isYouTube = link.isYouTubeLink && link.youtubeVideoId != null;
    final thumbnailUrl = isYouTube
        ? 'https://img.youtube.com/vi/${link.youtubeVideoId}/hqdefault.jpg'
        : null;

    return GestureDetector(
      onTap: () => _openUrl(link.videoLink),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background - thumbnail or gradient
                if (thumbnailUrl != null)
                  CachedNetworkImage(
                    imageUrl: thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[900],
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[900],
                      child: Icon(
                        Icons.video_library,
                        size: 40,
                        color: Colors.grey[700],
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.grey[900]!, Colors.grey[800]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(
                      Icons.video_library,
                      size: 40,
                      color: Colors.grey[600],
                    ),
                  ),

                // Dark overlay
                Container(color: Colors.black.withValues(alpha: 0.25)),

                // Play Button
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: isYouTube
                          ? Colors.red
                          : AppColors.of(context).primary,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),

                // Label at bottom
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isYouTube ? Icons.smart_display : Icons.open_in_new,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isYouTube ? 'Watch on YouTube' : 'Open Video',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDescription(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DESCRIPTION',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: colors.textHint,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        _LinkifiedText(
          text: link.description,
          style: TextStyle(
            fontSize: 13,
            color: colors.textSecondary,
            height: 1.5,
          ),
          linkStyle: TextStyle(
            fontSize: 13,
            color: colors.primary,
            decoration: TextDecoration.underline,
            decorationColor: colors.primary.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Lightweight widget that makes URLs clickable
class _LinkifiedText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextStyle linkStyle;

  const _LinkifiedText({
    required this.text,
    required this.style,
    required this.linkStyle,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(text: TextSpan(children: _parseText(text)));
  }

  List<TextSpan> _parseText(String text) {
    final List<TextSpan> spans = [];
    final urlRegex = RegExp(r'https?://[^\s\)]+', caseSensitive: false);

    int lastEnd = 0;
    for (final match in urlRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(text: text.substring(lastEnd, match.start), style: style),
        );
      }

      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: linkStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final uri = Uri.tryParse(url);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: style));
    }

    return spans;
  }
}
