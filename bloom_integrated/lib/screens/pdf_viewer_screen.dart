import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';
import '../services/file_download_service.dart';

class PdfViewerScreen extends StatefulWidget {
  final String url;
  final String title;
  final VoidCallback? onComplete;

  const PdfViewerScreen({
    super.key,
    required this.url,
    required this.title,
    this.onComplete,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  String? _localPath;
  bool _loading = true;
  String? _error;
  int _totalPages = 0;
  int _currentPage = 0;

  bool   _saving       = false;
  double _saveProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _downloadPdf();
  }

  Future<void> _downloadPdf() async {
    try {
      final response = await http.get(Uri.parse(widget.url));
      if (response.statusCode != 200) {
        throw Exception('Failed to load PDF (${response.statusCode})');
      }

      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(response.bodyBytes);

      if (mounted) {
        setState(() {
          _localPath = file.path;
          _loading   = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error   = e.toString();
          _loading = false;
        });
      }
    }
  }

  // Downloads straight to the device's public Downloads folder —
  // no share-sheet picker. The file appears in Downloads / Files app
  // immediately, with the OS's own download notification.
  Future<void> _handleDownload() async {
    if (_saving) return;
    setState(() { _saving = true; _saveProgress = 0.0; });

    try {
      final fileName = widget.title.toLowerCase().endsWith('.pdf')
          ? widget.title
          : '${widget.title}.pdf';

      await FileDownloadService.downloadToDownloadsFolder(
        url:      widget.url,
        fileName: fileName,
        onProgress: (p) {
          if (mounted) setState(() => _saveProgress = p);
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Saved to Downloads.',
              style: GoogleFonts.nunito(color: Colors.white)),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e, st) {
      debugPrint('PDF download failed: $e');
      debugPrintStack(stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Download failed: $e',
              style: GoogleFonts.nunito(color: Colors.white, fontSize: 12)),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
        actions: [
          if (!_loading && _error == null && _totalPages > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              child: Center(
                child: Text(
                  '${_currentPage + 1} / $_totalPages',
                  style: GoogleFonts.nunito(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (!_loading && _error == null)
            IconButton(
              tooltip: 'Download to Downloads',
              onPressed: _saving ? null : _handleDownload,
              icon: _saving
                  ? SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        value: _saveProgress > 0 ? _saveProgress : null,
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.download_outlined, color: Colors.white),
            ),
        ],
      ),
      body: _loading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : PDFView(
                  filePath: _localPath!,
                  enableSwipe: true,
                  swipeHorizontal: false,
                  autoSpacing: true,
                  pageFling: true,
                  onRender: (pages) {
                    if (mounted) setState(() => _totalPages = pages ?? 0);
                  },
                  onPageChanged: (page, total) {
                    if (mounted) setState(() => _currentPage = page ?? 0);
                        if (total != null && page != null && total > 0 && page >= total - 1) {
                      widget.onComplete?.call();
                    }
                  },
                  onError: (error) {
                    if (mounted) setState(() => _error = error.toString());
                  },
                ),
    );
  }

  Widget _buildLoading() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Loading PDF...',
              style: GoogleFonts.nunito(
                color: AppColors.textMid,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Could not load PDF',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() { _loading = true; _error = null; });
                  _downloadPdf();
                },
                icon: const Icon(Icons.refresh),
                label: Text('Retry', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}