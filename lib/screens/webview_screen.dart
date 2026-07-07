import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/app_theme.dart';

/// Simple in-app browser used for the Privacy Policy and Support pages.
class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            if (mounted) {
              setState(() {
                _loading = false;
                _error = true;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _reload() {
    setState(() {
      _error = false;
      _loading = true;
    });
    _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.panelPurpleDark,
        foregroundColor: AppColors.textLight,
        elevation: 0,
        title: Text(widget.title, style: AppText.label(18)),
        iconTheme: const IconThemeData(color: AppColors.goldLight),
      ),
      body: Stack(
        children: [
          Container(color: Colors.white),
          if (!_error) WebViewWidget(controller: _controller),
          if (_loading && !_error)
            const Center(
              child: CircularProgressIndicator(color: AppColors.panelPurple),
            ),
          if (_error) _errorView(),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  color: AppColors.panelPurpleLight, size: 64),
              const SizedBox(height: 16),
              Text('Unable to load the page',
                  style: AppText.label(18, color: AppColors.deepPurple),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Please check your connection and try again.',
                  style: AppText.body(14, color: AppColors.panelPurple),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _reload,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.deepPurple,
                  backgroundColor: AppColors.gold,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
                child: Text('Retry',
                    style:
                        AppText.label(16, color: const Color(0xFF5A3B08))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
