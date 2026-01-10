import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../config/app_theme.dart';
import '../../services/portal_visit_service.dart';

/// Embedded browser for KIU Web Portal
class WebPortalScreen extends StatefulWidget {
  final bool isForced;
  const WebPortalScreen({super.key, this.isForced = false});

  @override
  State<WebPortalScreen> createState() => _WebPortalScreenState();
}

class _WebPortalScreenState extends State<WebPortalScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _canGoBack = false;
  bool _isDesktopMode = false;
  double _loadingProgress = 0;
  final String _portalUrl = 'https://ur.kiu.org/login/index.php';

  // User agents
  static const _mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36';
  static const _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Safari/537.36';

  @override
  void initState() {
    super.initState();
    _initWebView();
    // Mark visit for weekly tracking
    PortalVisitService().markVisit();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_mobileUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
              _loadingProgress = 0;
            });
          },
          onProgress: (progress) {
            setState(() => _loadingProgress = progress / 100);
          },
          onPageFinished: (url) async {
            setState(() => _isLoading = false);
            final canGoBack = await _controller.canGoBack();
            setState(() => _canGoBack = canGoBack);

            if (mounted) {
              await _updateViewport();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_portalUrl));
  }

  Future<void> _updateViewport() async {
    final script = _isDesktopMode
        ? '''
        (function() {
          var meta = document.querySelector('meta[name="viewport"]');
          if (meta) { 
            meta.setAttribute('content', 'width=1024, initial-scale=0.0, maximum-scale=5.0, user-scalable=yes'); 
          } else { 
            var newMeta = document.createElement('meta');
            newMeta.name = 'viewport';
            newMeta.content = 'width=1024, initial-scale=0.0, maximum-scale=5.0, user-scalable=yes';
            document.getElementsByTagName('head')[0].appendChild(newMeta);
          }
        })();
      '''
        : '''
        (function() {
          var meta = document.querySelector('meta[name="viewport"]');
          if (meta) { 
            meta.setAttribute('content', 'width=device-width, initial-scale=1.0, user-scalable=yes'); 
          }
        })();
      ''';
    try {
      await _controller.runJavaScript(script);
    } catch (_) {}
  }

  void _toggleDesktopMode() {
    setState(() => _isDesktopMode = !_isDesktopMode);
    _controller.setUserAgent(
      _isDesktopMode ? _desktopUserAgent : _mobileUserAgent,
    );
    // We need to reload to apply User Agent, then script will run in onPageFinished
    _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: AppBar(
          toolbarHeight: 48,
          leading: IconButton(
            icon: const Icon(Icons.close, size: 22),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
          title: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.language,
                  color: Colors.white,
                  size: 12,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'KIU Portal',
                  style: TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            // Back button
            IconButton(
              icon: Icon(
                Icons.arrow_back_ios,
                size: 18,
                color: _canGoBack ? Colors.white : Colors.white38,
              ),
              onPressed: _canGoBack ? () => _controller.goBack() : null,
              tooltip: 'Back',
            ),
            // Refresh
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: () => _controller.reload(),
              tooltip: 'Refresh',
            ),
            // Desktop/Mobile toggle
            IconButton(
              icon: Icon(
                _isDesktopMode ? Icons.desktop_windows : Icons.phone_android,
                size: 18,
                color: _isDesktopMode ? AppColors.accentLight : Colors.white,
              ),
              onPressed: _toggleDesktopMode,
              tooltip: _isDesktopMode
                  ? 'Switch to Mobile'
                  : 'Switch to Desktop',
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
      body: Column(
        children: [
          // Loading indicator
          if (_isLoading)
            LinearProgressIndicator(
              value: _loadingProgress,
              minHeight: 2,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(AppColors.accent),
            ),
          // Forced visit banner
          if (widget.isForced)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: AppColors.warning.withValues(alpha: 0.15),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Weekly portal visit required. Browse to continue.',
                      style: TextStyle(fontSize: 11, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          // WebView
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
