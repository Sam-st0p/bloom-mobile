import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: depend_on_referenced_packages
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;
import '../theme/app_theme.dart';

class PdfViewerScreen extends StatefulWidget {
  final String url;
  final String title;

  const PdfViewerScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late final String _viewId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _viewId = 'pdf-viewer-${DateTime.now().millisecondsSinceEpoch}';

    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) {
        final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
        // Use Google Docs Viewer to embed PDF inline instead of opening a new tab
        final embedUrl = 'https://docs.google.com/viewer?url=${Uri.encodeComponent(widget.url)}&embedded=true';
        iframe.src = embedUrl;
        iframe.style.border = 'none';
        iframe.style.width = '100%';
        iframe.style.height = '100%';
        return iframe;
      },
    );

    // Fallback loading timeout
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _loading) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2d2d2d),
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Stack(
        children: [
          HtmlElementView(
            viewType: _viewId,
            onPlatformViewCreated: (_) {
              if (mounted) setState(() => _loading = false);
            },
          ),
          if (_loading)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text('Loading PDF…',
                        style: GoogleFonts.nunito(
                            color: AppColors.textMid, fontSize: 14)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}