import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'storage_check_native.dart'
    if (dart.library.html) 'storage_check_stub.dart';
import '../utils/av1_support.dart';

const int _kMinFreeBytes = 1024 * 1024 * 1024; // 1 GB

String get kForwardVideo => 'forward${av1Supported ? '_av1' : ''}.mp4';
String get kForwardMobileVideo =>
    'forward_mobile${av1Supported ? '_av1' : ''}.mp4';

const _kAllVideoFilenames = [
  'forward.mp4',
  'forward_mobile.mp4',
  'forward_av1.mp4',
  'forward_mobile_av1.mp4',
];

class OfflineVideoService {
  static final ValueNotifier<Set<int>> savedTrickIds = ValueNotifier(const {});
  static bool _scanning = false;

  /// Scans the tricks directory at startup and populates [savedTrickIds].
  static Future<void> loadSavedTrickIds() async {
    if (kIsWeb || _scanning) return;
    _scanning = true;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final tricksDir = Directory('${docs.path}/tricks');
      if (!await tricksDir.exists()) return;
      final ids = <int>{};
      await for (final entity in tricksDir.list()) {
        if (entity is! Directory) continue;
        final name = entity.path.replaceAll('\\', '/').split('/').last;
        final id = int.tryParse(name);
        if (id == null) continue;
        bool hasVideo = false;
        for (final name in _kAllVideoFilenames) {
          if (await File('${entity.path}/$name').exists()) {
            hasVideo = true;
            break;
          }
        }
        if (hasVideo) ids.add(id);
      }
      savedTrickIds.value = ids;
    } finally {
      _scanning = false;
    }
  }

  static void markSaved(int trickId) {
    savedTrickIds.value = {...savedTrickIds.value, trickId};
  }

  static void markDeleted(int trickId) {
    savedTrickIds.value = {...savedTrickIds.value}..remove(trickId);
  }

  static Future<String> videoPath(int trickId, String filename) async {
    final docs = await getApplicationDocumentsDirectory();
    return '${docs.path}/tricks/$trickId/$filename';
  }

  static Future<bool> videoExists(int trickId, String filename) async {
    if (kIsWeb) return false;
    final path = await videoPath(trickId, filename);
    return File(path).exists();
  }

  /// Returns false only when free storage is confirmed < 1 GB.
  /// Returns true when storage is sufficient or cannot be determined.
  static Future<bool> hasSufficientStorage() async {
    if (kIsWeb) return true;
    if (!Platform.isAndroid && !Platform.isIOS) return true;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final free = statvfsFreeBytes(docs.path);
      // Negative result means uint64 overflow (exabytes free) — allow the op.
      if (free == null || free < 0) return true;
      return free >= _kMinFreeBytes;
    } catch (_) {
      return true;
    }
  }

  /// Copies [sourcePath] to permanent storage for [trickId]/[filename].
  /// Writes to a .tmp file first and renames atomically on success so a
  /// crashed mid-copy never leaves a partial file at the destination.
  static Future<void> saveFromCache(
      String sourcePath, int trickId, String filename) async {
    final destPath = await videoPath(trickId, filename);
    final tmpPath = '$destPath.tmp';
    final tmpFile = File(tmpPath);
    await tmpFile.parent.create(recursive: true);
    if (await tmpFile.exists()) await tmpFile.delete().catchError((_) => tmpFile);
    try {
      await File(sourcePath).copy(tmpPath);
      await tmpFile.rename(destPath);
    } catch (_) {
      await tmpFile.delete().catchError((_) => tmpFile);
      rethrow;
    }
  }

  static Future<void> deleteVideo(int trickId, String filename) async {
    final path = await videoPath(trickId, filename);
    final file = File(path);
    if (await file.exists()) await file.delete();
    try {
      final dir = file.parent;
      if (await dir.exists() && await dir.list().isEmpty) {
        await dir.delete();
      }
    } catch (_) {}
  }

  /// Deletes the entire trick directory for [trickId], removing all video
  /// files and any partial .tmp files left by a crashed download.
  static Future<void> deleteAllVideos(int trickId) async {
    if (kIsWeb) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/tricks/$trickId');
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  /// Downloads [url] directly to permanent storage as [trickId]/[filename].
  /// Writes to a .tmp file and renames atomically on success so a crashed
  /// mid-download never leaves a partial file at the destination path.
  static Future<String> downloadToPermanent(
    String url,
    int trickId,
    String filename, {
    void Function(double)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final path = await videoPath(trickId, filename);
    final tmpPath = '$path.tmp';
    final tmpFile = File(tmpPath);
    await tmpFile.parent.create(recursive: true);
    if (await tmpFile.exists()) await tmpFile.delete().catchError((_) => tmpFile);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    IOSink? sink;
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final total = response.contentLength;
      sink = tmpFile.openWrite();
      int received = 0;
      await for (final chunk in response.timeout(const Duration(seconds: 60))) {
        if (isCancelled?.call() == true) throw OfflineVideoCancelledException();
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && onProgress != null) onProgress(received / total);
      }
      await sink.close();
      sink = null;
      if (total > 0 && received < total) {
        await tmpFile.delete().catchError((_) => tmpFile);
        throw Exception('Incomplete download: received $received of $total bytes');
      }
      await tmpFile.rename(path);
      return path;
    } catch (e) {
      try {
        await sink?.close();
      } catch (_) {}
      await tmpFile.delete().catchError((_) => tmpFile);
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Downloads [url] to the application cache directory, keyed by [cacheKey].
  /// Skips the download if a non-empty cached file already exists.
  /// Returns the local path on success, or null on error or cancellation —
  /// callers should fall back to streaming from [url] when null is returned.
  /// Writes to a .tmp file and renames atomically so a crashed mid-download
  /// never leaves a partial file that passes the re-use check on next launch.
  static Future<String?> downloadToCache(
    String url, {
    required String cacheKey,
    bool Function()? isCancelled,
    void Function(double)? onProgress,
  }) async {
    try {
      final dir = await getApplicationCacheDirectory();
      final path = '${dir.path}/ts_$cacheKey.mp4';
      final tmpPath = '$path.tmp';
      final file = File(path);
      try {
        if (await file.exists() && await file.length() > 0) return path;
      } catch (_) {
        // File was deleted between exists() and length() — re-download.
      }
      final tmpFile = File(tmpPath);
      if (await tmpFile.exists()) await tmpFile.delete().catchError((_) => tmpFile);
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 30);
      try {
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        if (response.statusCode != 200) return null;
        final total = response.contentLength;
        final sink = tmpFile.openWrite();
        int received = 0;
        try {
          await for (final chunk in response.timeout(const Duration(seconds: 60))) {
            if (isCancelled?.call() == true) {
              await sink.close().catchError((_) {});
              await tmpFile.delete().catchError((_) => tmpFile);
              return null;
            }
            sink.add(chunk);
            received += chunk.length;
            if (total > 0 && onProgress != null) onProgress(received / total);
          }
          await sink.close();
        } catch (_) {
          await sink.close().catchError((_) {});
          await tmpFile.delete().catchError((_) => tmpFile);
          rethrow;
        }
        if (total > 0 && received < total) {
          await tmpFile.delete().catchError((_) => tmpFile);
          return null;
        }
        await tmpFile.rename(path);
        return path;
      } finally {
        client.close();
      }
    } catch (e, st) {
      debugPrint('OfflineVideoService.downloadToCache failed, falling back to stream: $e\n$st');
      return null;
    }
  }
}

class OfflineVideoCancelledException implements Exception {
  @override
  String toString() => 'Cancelled';
}
