import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../config/app_theme.dart';
import '../../services/portal_visit_service.dart';
import '../../widgets/common/webview_moodle_support.dart';

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

  Future<void> _initWebView() async {
    final portalService = PortalVisitService();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_mobileUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _loadingProgress = 0;
            });
          },
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _loadingProgress = progress / 100);
          },
          onPageFinished: (url) async {
            if (!mounted) return;
            setState(() => _isLoading = false);
            final canGoBack = await _controller.canGoBack();
            if (!mounted) return;
            setState(() => _canGoBack = canGoBack);

            // Check if user has successfully logged in
            if (portalService.isLoggedInUrl(url)) {
              await portalService.markLogin();
              // Show success message if forced visit
              if (widget.isForced && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Weekly login completed! ✓'),
                    backgroundColor: Color(0xFF4CAF50),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            }

            if (mounted) {
              await _updateViewport();
            }
          },
        ),
      );

    // Enable Moodle file uploads + JS confirm/alert/prompt dialogs.
    await WebViewMoodleSupport.configure(
      controller: _controller,
      context: () => context,
      mounted: () => mounted,
    );

    await _controller.loadRequest(Uri.parse(_portalUrl));
  }

  Future<void> _updateViewport() async {
    if (_isDesktopMode) {
      await _injectDesktopModeScript();
    } else {
      await _injectMobileModeScript();
    }
  }

  /// Advanced JavaScript injection to force desktop layout
  Future<void> _injectDesktopModeScript() async {
    const desktopScript = '''
      (function() {
        // 1. Set desktop viewport
        var meta = document.querySelector('meta[name="viewport"]');
        if (meta) {
          meta.setAttribute('content', 'width=1280, initial-scale=0.3, minimum-scale=0.1, maximum-scale=5.0, user-scalable=yes');
        } else {
          var newMeta = document.createElement('meta');
          newMeta.name = 'viewport';
          newMeta.content = 'width=1280, initial-scale=0.3, minimum-scale=0.1, maximum-scale=5.0, user-scalable=yes';
          document.head.appendChild(newMeta);
        }

        // 2. Override window.innerWidth and screen properties to fake desktop
        Object.defineProperty(window, 'innerWidth', { value: 1280, writable: true, configurable: true });
        Object.defineProperty(window, 'innerHeight', { value: 800, writable: true, configurable: true });
        Object.defineProperty(screen, 'width', { value: 1920, writable: true, configurable: true });
        Object.defineProperty(screen, 'height', { value: 1080, writable: true, configurable: true });
        Object.defineProperty(screen, 'availWidth', { value: 1920, writable: true, configurable: true });
        Object.defineProperty(screen, 'availHeight', { value: 1040, writable: true, configurable: true });

        // 3. Override matchMedia to return desktop-like results
        var originalMatchMedia = window.matchMedia;
        window.matchMedia = function(query) {
          // Force desktop-like responses for common mobile detection queries
          if (query.includes('max-width: 767px') || 
              query.includes('max-width: 768px') ||
              query.includes('max-width: 991px') ||
              query.includes('max-width: 1024px') ||
              query.includes('max-device-width')) {
            return { matches: false, media: query, onchange: null, addListener: function(){}, removeListener: function(){} };
          }
          if (query.includes('min-width: 992px') ||
              query.includes('min-width: 1024px') ||
              query.includes('min-width: 1200px')) {
            return { matches: true, media: query, onchange: null, addListener: function(){}, removeListener: function(){} };
          }
          return originalMatchMedia(query);
        };

        // 4. Add CSS to force desktop styles and override mobile CSS
        var style = document.getElementById('force-desktop-style');
        if (!style) {
          style = document.createElement('style');
          style.id = 'force-desktop-style';
          style.textContent = `
            /* Force desktop widths */
            body, html {
              min-width: 1280px !important;
              overflow-x: auto !important;
            }
            
            /* Hide mobile-only elements */
            .mobile-only, .show-mobile, .visible-xs, .visible-sm,
            [class*="mobile-menu"], [class*="mobile-nav"],
            .navbar-toggle, .menu-toggle {
              display: none !important;
            }
            
            /* Show desktop-only elements */
            .desktop-only, .show-desktop, .hidden-xs, .hidden-sm,
            .visible-md, .visible-lg {
              display: block !important;
            }
            
            /* Ensure containers are desktop width */
            .container, .container-fluid, main, #page, #wrapper {
              min-width: 1200px !important;
              width: 100% !important;
            }
            
            /* Force sidebars visible */
            #block-region-side-pre, #block-region-side-post,
            .sidebar, aside, [role="complementary"] {
              display: block !important;
              width: 280px !important;
            }
          `;
          document.head.appendChild(style);
        }

        // 5. Dispatch resize event to trigger responsive recalculation
        window.dispatchEvent(new Event('resize'));
        
        // 6. Trigger any framework-specific desktop detection
        if (typeof jQuery !== 'undefined') {
          jQuery(window).trigger('resize');
        }

        console.log('Desktop mode forced successfully');
      })();
    ''';

    try {
      await _controller.runJavaScript(desktopScript);
    } catch (e) {
      debugPrint('Desktop script error: $e');
    }
  }

  /// Reset to mobile mode
  Future<void> _injectMobileModeScript() async {
    const mobileScript = '''
      (function() {
        // Reset viewport
        var meta = document.querySelector('meta[name="viewport"]');
        if (meta) {
          meta.setAttribute('content', 'width=device-width, initial-scale=1.0, user-scalable=yes');
        }
        
        // Remove desktop style overrides
        var style = document.getElementById('force-desktop-style');
        if (style) style.remove();
        
        // Trigger resize
        window.dispatchEvent(new Event('resize'));
      })();
    ''';

    try {
      await _controller.runJavaScript(mobileScript);
    } catch (_) {}
  }

  void _toggleDesktopMode() async {
    setState(() => _isDesktopMode = !_isDesktopMode);

    // Set appropriate user agent
    await _controller.setUserAgent(
      _isDesktopMode ? _desktopUserAgent : _mobileUserAgent,
    );

    // Reload page to apply user agent change
    await _controller.reload();
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
