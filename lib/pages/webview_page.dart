import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/theme_service.dart';

class WebViewPage extends StatefulWidget {
  final String title;
  final String url;
  final bool isDarkMode;

  const WebViewPage({
    super.key,
    required this.title,
    required this.url,
    required this.isDarkMode,
  });

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(
        widget.isDarkMode ? const Color(0xFF0F1117) : Colors.white,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() {
            _isLoading = true;
            _hasError = false;
          }),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (WebResourceError error) {
            // Only treat explicit main-frame errors as page failures.
            // If isForMainFrame is null, ignore — it's a sub-resource.
            if (error.isForMainFrame == true) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            }
          },
          // Ignore onHttpError entirely — sub-resources frequently return
          // non-200 and would falsely trigger the error screen.
          // The page itself returns 200; rely on onWebResourceError for failures.
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          widget.isDarkMode ? ThemeService.bgMain : Colors.white,
      appBar: AppBar(
        backgroundColor:
            widget.isDarkMode ? ThemeService.bgMain : Colors.white,
        foregroundColor:
            widget.isDarkMode ? Colors.white : const Color(0xFF222222),
        elevation: 0,
        centerTitle: false,
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          if (_hasError)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 56,
                    color: widget.isDarkMode
                        ? Colors.white38
                        : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Could not load page',
                    style: TextStyle(
                      fontSize: 16,
                      color: widget.isDarkMode
                          ? Colors.white54
                          : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _hasError = false;
                        _isLoading = true;
                      });
                      _controller.reload();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A59),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          else
            WebViewWidget(controller: _controller),
          if (_isLoading && !_hasError)
            const LinearProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(Color(0xFFFF7A59)),
              backgroundColor: Colors.transparent,
            ),
        ],
      ),
    );
  }
}
