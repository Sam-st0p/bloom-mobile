// lib/services/file_download_service.dart
// BLOOM GAD Mobile App — File Download Service
//
// Images  -> saved to the device gallery via gal (no picker, no
//            permission prompt needed on modern Android/iOS).
// Anything else (PDF, DOCX, PPTX, video, etc.) -> saved directly to
//            the public Downloads folder via flutter_file_downloader.
//            Zero share-sheet picker — the file just lands in
//            /storage/emulated/0/Download (Android) or the app's
//            Files location (iOS), with the OS download-progress
//            notification doing the rest.

import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:flutter_file_downloader/flutter_file_downloader.dart';

class FileDownloadService {
  /// True if this file type is an image gal can save directly to the
  /// gallery (jpg/jpeg/png/gif/webp/heic).
  static bool isImageFile(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic');
  }

  /// Saves an already-downloaded local image file to the device gallery.
  /// gal handles the platform permission prompt internally.
  static Future<void> saveImageToGallery(String localPath) async {
    try {
      await Gal.putImage(localPath, album: 'BLOOM GAD');
    } on GalException catch (e) {
      throw Exception('Could not save image: ${e.type.message}');
    }
  }

  /// Downloads [url] directly into the device's public Downloads
  /// folder. No picker, no share sheet — the OS shows its own
  /// download notification and the file appears in Downloads /
  /// Files app immediately.
  static Future<void> downloadToDownloadsFolder({
    required String url,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    final completer = Completer<void>();

    await FileDownloader.downloadFile(
      url: url,
      name: fileName,
      onProgress: (fileName, progress) {
        onProgress?.call(progress / 100);
      },
      onDownloadCompleted: (path) {
        if (!completer.isCompleted) completer.complete();
      },
      onDownloadError: (errorMessage) {
        if (!completer.isCompleted) {
          completer.completeError(Exception(errorMessage));
        }
      },
    );

    return completer.future;
  }

  /// One-call convenience: routes to gallery save (images) or direct
  /// Downloads-folder save (everything else) based on file type.
  /// For images we still need the file locally first since gal saves
  /// from a local path, not a URL — so images take a quick detour
  /// through a temp file. Everything else downloads straight to
  /// Downloads without ever touching app-private storage.
  static Future<void> downloadAndSave({
    required String url,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    if (isImageFile(fileName)) {
      final tempPath = await _downloadToTemp(
        url: url,
        fileName: fileName,
        onProgress: onProgress,
      );
      await saveImageToGallery(tempPath);
    } else {
      await downloadToDownloadsFolder(
        url: url,
        fileName: fileName,
        onProgress: onProgress,
      );
    }
  }

  // Only used internally for the image -> gallery path, since gal
  // needs a local file path rather than a remote URL.
  static Future<String> _downloadToTemp({
    required String url,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final filePath = '${dir.path}/$safeName';
    final file = File(filePath);

    if (await file.exists()) {
      onProgress?.call(1.0);
      return filePath;
    }

    final request = http.Request('GET', Uri.parse(url));
    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      throw Exception('Failed to download file (HTTP ${response.statusCode})');
    }

    final total = response.contentLength ?? 0;
    var received = 0;

    final sink = file.openWrite();
    try {
      await response.stream.listen(
        (chunk) {
          received += chunk.length;
          sink.add(chunk);
          if (total > 0) onProgress?.call(received / total);
        },
        onDone: () {},
        cancelOnError: true,
      ).asFuture<void>();
      await sink.flush();
    } finally {
      await sink.close();
    }

    onProgress?.call(1.0);
    return filePath;
  }
}