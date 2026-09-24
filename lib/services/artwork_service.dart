/*
 *     Copyright (C) 2026 Thamodharan Ganesan
 *
 *     Catchify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Catchify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Catchify, including how to contribute,
 *     please visit: https://github.com/catchify0/catchify0.github.io
 */

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:catchify/main.dart' show logger;
import 'package:catchify/services/proxy_manager.dart';
import 'package:catchify/utilities/formatter.dart';
import 'package:path_provider/path_provider.dart';

class ArtworkService {
  ArtworkService._();
  static final ArtworkService instance = ArtworkService._();

  static Directory? _cacheDir;
  final Set<String> _processingYtids = <String>{};

  static String sanitizeId(String id) =>
      id.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');

  static bool isGoogleArtworkUrl(String url) {
    final uri = Uri.tryParse(url);
    final host = uri?.host.toLowerCase() ?? '';
    return host.endsWith('googleusercontent.com') || host.endsWith('ggpht.com');
  }

  static bool isYouTubeThumbnailUrl(String url) {
    final uri = Uri.tryParse(url);
    final host = uri?.host.toLowerCase() ?? '';
    return host.contains('ytimg.com') || host.contains('youtube.com');
  }

  Future<Directory> _getCacheDirectory() async {
    if (_cacheDir != null && await _cacheDir!.exists()) {
      return _cacheDir!;
    }
    final temp = await getTemporaryDirectory();
    final dir = Directory('${temp.path}/square_artworks');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  Future<File> _cacheFileForYtid(String ytid) async {
    final dir = await _getCacheDirectory();
    return File('${dir.path}/sq_${sanitizeId(ytid)}.png');
  }

  /// Returns the cached square artwork file if it exists, otherwise null.
  Future<File?> getCachedSquareFile(String ytid) async {
    try {
      final file = await _cacheFileForYtid(ytid);
      if (await file.exists() && await file.length() > 0) {
        return file;
      }
    } catch (_) {}
    return null;
  }

  /// Prunes cached square artworks if total disk footprint exceeds [maxBytes] (default 150MB),
  /// deleting oldest files first.
  Future<void> pruneOldArtworkCache({int maxBytes = 150 * 1024 * 1024}) async {
    try {
      final dir = await _getCacheDirectory();
      if (!await dir.exists()) return;

      final entities = await dir.list().where((e) => e is File).cast<File>().toList();
      var totalSize = 0;
      final fileStats = <({File file, int size, DateTime modified})>[];

      for (final file in entities) {
        try {
          final stat = await file.stat();
          totalSize += stat.size;
          fileStats.add((file: file, size: stat.size, modified: stat.modified));
        } catch (_) {}
      }

      if (totalSize > maxBytes) {
        fileStats.sort((a, b) => a.modified.compareTo(b.modified));
        for (final item in fileStats) {
          if (totalSize <= maxBytes) break;
          try {
            await item.file.delete();
            totalSize -= item.size;
          } catch (_) {}
        }
        logger.log(
          '[ARTWORK] Pruned artwork cache to ${(totalSize / (1024 * 1024)).toStringAsFixed(1)}MB',
        );
      }
    } catch (e, st) {
      logger.log('Error during pruneOldArtworkCache', error: e, stackTrace: st);
    }
  }

  /// Center-crops image bytes to a 1:1 square, returning PNG bytes.
  /// If the image is already square, returns the original or PNG bytes.
  static Future<Uint8List> cropCenterSquare(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final width = image.width;
    final height = image.height;

    // If already square (or within 1% of square), return as-is
    if ((width - height).abs() <= 2) {
      return bytes;
    }

    var side = math.min(width, height).toDouble();
    var srcX = (width - side) / 2.0;
    var srcY = (height - side) / 2.0;

    // Detect YouTube 4:3 letterboxed thumbnails (e.g. 480x360 hqdefault or 640x480 sddefault)
    // where 16:9 video content is centered with black bars on top and bottom.
    if ((width * 3 == height * 4) || ((width / height - 4 / 3).abs() < 0.02)) {
      final contentHeight = width * 9.0 / 16.0;
      final blackBar = (height - contentHeight) / 2.0;
      side = contentHeight;
      srcX = (width - side) / 2.0;
      srcY = blackBar;
    }

    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawImageRect(
      image,
      ui.Rect.fromLTWH(srcX, srcY, side, side),
      ui.Rect.fromLTWH(0, 0, side, side),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );

    final picture = recorder.endRecording();
    final cropped = await picture.toImage(side.round(), side.round());
    final byteData = await cropped.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) return bytes;
    return byteData.buffer.asUint8List();
  }

  /// Resolves the best square artUri for a song map.
  /// If a cached square file is ready, returns `Uri.file(...)`.
  /// If the URL is already a square Google User Content URL, returns high-res square URL.
  /// If it is a 16:9 YouTube thumbnail, returns the remote URL immediately and triggers
  /// background center-cropping, notifying via [onSquareReady] when finished.
  Uri resolveArtUri(
    Map song, {
    String? offlineArtworkPath,
    void Function(Uri squareUri)? onSquareReady,
    int targetResolution = 1080,
  }) {
    final ytid = song['ytid']?.toString() ?? song['id']?.toString() ?? '';
    final rawHighRes =
        (song['highResImage'] ?? song['image'] ?? '').toString().trim();

    // 1. Offline artwork path provided and valid
    if (offlineArtworkPath != null && offlineArtworkPath.isNotEmpty) {
      final file = File(offlineArtworkPath);
      if (file.existsSync() && file.lengthSync() > 0) {
        // If it's not known whether it's square, schedule background check/crop
        if (onSquareReady != null && ytid.isNotEmpty) {
          _processOfflineFileIfNeeded(ytid, file, onSquareReady);
        }
        return Uri.file(file.path);
      }
    }

    if (rawHighRes.isEmpty) {
      return Uri.parse('');
    }

    final highResUrl = formatArtworkResolution(rawHighRes, targetResolution);

    // 2. Google user content is already square; return crisp square URL
    if (isGoogleArtworkUrl(highResUrl)) {
      return Uri.parse(highResUrl);
    }

    // 3. Local file URI
    if (highResUrl.startsWith('file://')) {
      return Uri.parse(highResUrl);
    }

    // 4. Check if we already have a cached square file for this ytid
    if (ytid.isNotEmpty) {
      final cached = _syncCheckCachedFile(ytid);
      if (cached != null) {
        return Uri.file(cached.path);
      }
    }

    // 5. If YouTube thumbnail, trigger background crop and return 1080p URL
    if (ytid.isNotEmpty &&
        (isYouTubeThumbnailUrl(highResUrl) || onSquareReady != null)) {
      _downloadAndCropInBackground(ytid, highResUrl, onSquareReady);
    }

    return Uri.tryParse(highResUrl) ?? Uri.parse('');
  }

  File? _syncCheckCachedFile(String ytid) {
    if (_cacheDir == null) return null;
    final file = File('${_cacheDir!.path}/sq_${sanitizeId(ytid)}.png');
    if (file.existsSync() && file.lengthSync() > 0) {
      return file;
    }
    return null;
  }

  void _downloadAndCropInBackground(
    String ytid,
    String imageUrl,
    void Function(Uri squareUri)? onSquareReady,
  ) {
    if (_processingYtids.contains(ytid)) return;
    _processingYtids.add(ytid);

    Future<void>(() async {
      try {
        final cacheFile = await _cacheFileForYtid(ytid);
        if (await cacheFile.exists() && await cacheFile.length() > 0) {
          onSquareReady?.call(Uri.file(cacheFile.path));
          return;
        }

        var response =
            await ProxyManager().getProxiedResponse(Uri.parse(imageUrl));
        if (response.statusCode != 200 &&
            imageUrl.contains('maxresdefault.jpg')) {
          final fallbackUrl =
              imageUrl.replaceFirst('maxresdefault.jpg', 'hqdefault.jpg');
          response =
              await ProxyManager().getProxiedResponse(Uri.parse(fallbackUrl));
        }

        if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
          return;
        }

        final croppedBytes = await cropCenterSquare(response.bodyBytes);
        await cacheFile.writeAsBytes(croppedBytes, flush: true);

        if (await cacheFile.exists() && await cacheFile.length() > 0) {
          onSquareReady?.call(Uri.file(cacheFile.path));
        }
      } catch (e, st) {
        logger.log('ArtworkService: background crop failed for $ytid',
            error: e, stackTrace: st);
      } finally {
        _processingYtids.remove(ytid);
      }
    });
  }

  void _processOfflineFileIfNeeded(
    String ytid,
    File file,
    void Function(Uri squareUri) onSquareReady,
  ) {
    if (_processingYtids.contains(ytid)) return;
    _processingYtids.add(ytid);

    Future<void>(() async {
      try {
        final cacheFile = await _cacheFileForYtid(ytid);
        if (await cacheFile.exists() && await cacheFile.length() > 0) {
          onSquareReady(Uri.file(cacheFile.path));
          return;
        }

        final bytes = await file.readAsBytes();
        final croppedBytes = await cropCenterSquare(bytes);
        if (croppedBytes != bytes) {
          // It was cropped from 16:9; save square cache and overwrite offline file if desired
          await cacheFile.writeAsBytes(croppedBytes, flush: true);
          onSquareReady(Uri.file(cacheFile.path));
        }
      } catch (_) {
      } finally {
        _processingYtids.remove(ytid);
      }
    });
  }
}
