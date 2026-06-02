import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../config/app_theme.dart';
import '../../widgets/common/webview_moodle_support.dart';

/// Embedded browser for SSA Printshop (Semester Notes Order)
class PrintshopScreen extends StatefulWidget {
  const PrintshopScreen({super.key});

  @override
  State<PrintshopScreen> createState() => _PrintshopScreenState();
}

class _PrintshopScreenState extends State<PrintshopScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _canGoBack = false;
  double _loadingProgress = 0;
  final String _printshopUrl = 'https://printshop.ssatechs.com/';

  // Desktop user agent for better experience
  static const _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Safari/537.36';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_desktopUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
              _loadingProgress = 0;
            });
          },
          onProgress: (progress) {
            setState(() {
              _loadingProgress = progress / 100;
            });
          },
          onPageFinished: (url) async {
            setState(() {
              _isLoading = false;
            });
            _updateNavigationState();

            // Force desktop viewport
            await _controller.runJavaScript('''
              (function() {
                var viewport = document.querySelector('meta[name="viewport"]');
                if (viewport) {
                  viewport.setAttribute('content', 'width=1280, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes');
                } else {
                  var meta = document.createElement('meta');
                  meta.name = 'viewport';
                  meta.content = 'width=1280, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes';
                  document.getElementsByTagName('head')[0].appendChild(meta);
                }
              })();
            ''');
          },
        ),
      );

    // Enable file uploads + JS confirm/alert/prompt dialogs.
    await WebViewMoodleSupport.configure(
      controller: _controller,
      context: () => context,
      mounted: () => mounted,
    );

    await _controller.loadRequest(Uri.parse(_printshopUrl));
  }

  Future<void> _updateNavigationState() async {
    final canGoBack = await _controller.canGoBack();
    if (mounted) {
      setState(() {
        _canGoBack = canGoBack;
      });
    }
  }

  Future<void> _reload() async {
    await _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Semester Notes'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Reload button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
            tooltip: 'Reload',
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),

          // Loading indicator
          if (_isLoading)
            Column(
              children: [
                LinearProgressIndicator(
                  value: _loadingProgress,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppColors.primary),
                          const SizedBox(height: 16),
                          const Text(
                            'Loading Printshop...',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),

      // Bottom navigation bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Back button
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _canGoBack
                        ? () async {
                            await _controller.goBack();
                            _updateNavigationState();
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Icon(
                        Icons.arrow_back,
                        color: _canGoBack
                            ? AppColors.primary
                            : AppColors.textHint,
                      ),
                    ),
                  ),
                ),
              ),

              // Forward button
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      if (await _controller.canGoForward()) {
                        await _controller.goForward();
                        _updateNavigationState();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Icon(
                        Icons.arrow_forward,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                ),
              ),

              // Home button
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _controller.loadRequest(Uri.parse(_printshopUrl));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Icon(Icons.home, color: AppColors.primary),
                    ),
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
