// lib/screens/file_viewer_screen.dart
// BLOOM GAD Mobile App — Generic File Viewer
//
// Shown for any module file that isn't a PDF (images, videos, PPTX,
// DOCX, etc.). Images get an in-app preview via Image.network and are
// saved to the gallery on download. Everything else gets a file-info
// card and downloads straight to the public Downloads folder — no
// share-sheet picker for either path.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/file_download_service.dart';

class FileViewerScreen extends StatefulWidget {
  final String url;
  final String title;
  final String? fileType;

  const FileViewerScreen({
    super.key,
    required this.url,
    required this.title,
    this.fileType,
  });

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  bool   _saving       = false;
  double _saveProgress = 0.0;

  bool get _isImage => FileDownloadService.isImageFile(widget.title);

  IconData get _icon {
    final t = (widget.fileType ?? '').toLowerCase();
    final n = widget.title.toLowerCase();
    if (t.contains('video') || n.endsWith('.mp4')) return Icons.play_circle_outline;
    if (n.endsWith('.pptx') || n.endsWith('.ppt')) return Icons.slideshow_outlined;
    if (n.endsWith('.docx') || n.endsWith('.doc')) return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }

  String get _typeLabel {
    final t = (widget.fileType ?? '').toLowerCase();
    final n = widget.title.toLowerCase();
    if (t.contains('video') || n.endsWith('.mp4')) return 'Video file';
    if (n.endsWith('.pptx') || n.endsWith('.ppt')) return 'PowerPoint presentation';
    if (n.endsWith('.docx') || n.endsWith('.doc')) return 'Word document';
    return 'File';
  }

  Future<void> _handleDownload() async {
    if (_saving) return;
    setState(() { _saving = true; _saveProgress = 0.0; });
    try {
      await FileDownloadService.downloadAndSave(
        url:      widget.url,
        fileName: widget.title,
        onProgress: (p) {
          if (mounted) setState(() => _saveProgress = p);
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            _isImage ? 'Saved to your gallery.' : 'Saved to Downloads.',
            style: GoogleFonts.nunito(color: Colors.white),
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e, st) {
      debugPrint('File download failed: $e');
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
      backgroundColor: _isImage ? Colors.black : AppColors.background,
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
          IconButton(
            tooltip: _isImage ? 'Save to gallery' : 'Download to Downloads',
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
      body: _isImage ? _buildImagePreview() : _buildFileInfoCard(),
    );
  }

  Widget _buildImagePreview() {
    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4,
        child: Image.network(
          widget.url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const CircularProgressIndicator(color: AppColors.primary);
          },
          errorBuilder: (_, __, ___) => Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Could not load image.',
              style: GoogleFonts.nunito(color: Colors.white70),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileInfoCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(_icon, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _typeLabel,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'This file type can\'t be previewed in the app.\n'
              'Tap the download icon above to save it to your Downloads folder.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: AppColors.textMid,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _saving ? null : _handleDownload,
              icon: _saving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined, size: 18),
              label: Text(
                _saving ? 'Downloading...' : 'Download',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}