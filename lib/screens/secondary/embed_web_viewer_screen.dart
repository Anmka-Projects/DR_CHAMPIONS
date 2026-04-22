import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/design/app_colors.dart';

/// Full-screen WebView for embedded content (e.g. Google Drive preview).
class EmbedWebViewerScreen extends StatefulWidget {
  final String initialUrl;
  final String? title;

  const EmbedWebViewerScreen({
    super.key,
    required this.initialUrl,
    this.title,
  });

  @override
  State<EmbedWebViewerScreen> createState() => _EmbedWebViewerScreenState();
}

class _EmbedWebViewerScreenState extends State<EmbedWebViewerScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title ?? '',
          style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const ColoredBox(
              color: Colors.white,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.purple),
              ),
            ),
        ],
      ),
    );
  }
}
