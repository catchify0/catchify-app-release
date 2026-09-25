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
 */

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:catchify/main.dart' show audioHandler, logger;
import 'package:catchify/services/common_services.dart';
import 'package:catchify/services/data_manager.dart';
import 'package:catchify/services/io_service.dart';
import 'package:catchify/services/playlist_download_service.dart';
import 'package:catchify/services/proxy_manager.dart';

/// Canonical download states for tracks and playlists.
enum DownloadStatus {
  queued,
  downloading,
  completed,
  failed,
  cancelled,
  deleting,
  missing;

  static DownloadStatus fromString(String? value) {
    if (value == null) return DownloadStatus.queued;
    for (final status in DownloadStatus.values) {
      if (status.name == value) return status;
    }
    return DownloadStatus.queued;
  }
}

/// Granular progress and state details for an individual download task.
class DownloadProgressInfo {
  DownloadProgressInfo({
    required this.ytid,
    required this.title,
    required this.status,
    this.progress = 0.0,
    this.bytesDownloaded = 0,
    this.totalBytes = 0,
    this.error,
    this.retryCount = 0,
  });

  final String ytid;
  final String title;
  final DownloadStatus status;
  final double progress;
  final int bytesDownloaded;
  final int totalBytes;
  final String? error;
  final int retryCount;

  DownloadProgressInfo copyWith({
    DownloadStatus? status,
    double? progress,
    int? bytesDownloaded,
    int? totalBytes,
    String? error,
    int? retryCount,
  }) {
    return DownloadProgressInfo(
      ytid: ytid,
      title: title,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
      error: error ?? this.error,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

/// Aggregate storage accounting details for downloaded media.
class StorageAccounting {
  const StorageAccounting({
    required this.downloadedSongsCount,
    required this.totalFilesCount,
    required this.totalStorageBytes,
  });

  final int downloadedSongsCount;
  final int totalFilesCount;
  final int totalStorageBytes;

  String get formattedStorageSize {
    if (totalStorageBytes <= 0) return '0.0 MB';
    final mb = totalStorageBytes / (1024 * 1024);
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(2)} GB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }
}

/// DownloadManager: Single source of truth for all download operations,
/// queueing, status management, storage integrity, and offline accounting.
class DownloadManager {
  factory DownloadManager() => _instance;
  DownloadManager._internal();
  static final DownloadManager _instance = DownloadManager._internal();
  static DownloadManager get instance => _instance;

  /// Concurrency limit for background downloading.
  static const int maxConcurrentDownloads = 3;

  /// Max retries for transient stream errors.
  static const int maxRetriesDefault = 3;

  /// Reactive state of all active and recently completed/failed downloads.
  final ValueNotifier<Map<String, DownloadProgressInfo>> activeDownloads =
      ValueNotifier<Map<String, DownloadProgressInfo>>({});

  /// Internal FIFO queue for pending download jobs.
  final Queue<_DownloadJob> _downloadQueue = Queue<_DownloadJob>();

  /// Set of active ytid download jobs currently in flight.
  final Set<String> _inFlightYtids = <String>{};

  /// Cancellation tokens for active streams: ytid -> Completer.
  final Map<String, Completer<void>> _cancellationTokens = {};

  /// Completion signals for active jobs, used to serialize cancellation and retry.
  final Map<String, Completer<void>> _activeJobCompletions = {};

  bool _initialized = false;

  /// Initializes the download manager and reconciles local storage integrity.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await reconcileStorageIntegrity();
    } catch (e, stackTrace) {
      logger.log(
        '[DOWNLOAD] Initialization integrity reconciliation error',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Returns the current canonical status for a song ytid.
  DownloadStatus getSongStatus(String ytid) {
    if (ytid.isEmpty) return DownloadStatus.missing;

    final active = activeDownloads.value[ytid];
    if (active != null) return active.status;

    final offlineSong = getOfflineSongByYtid(ytid);
    if (offlineSong.isNotEmpty) {
      final audioPath = offlineSong['audioPath'] ?? offlineSong['localPath'];
      if (audioPath != null && audioPath.toString().isNotEmpty) {
        if (File(audioPath.toString()).existsSync()) {
          return DownloadStatus.completed;
        }
      }
      return DownloadStatus.missing;
    }

    return DownloadStatus.queued;
  }

  /// Returns whether a song is completely downloaded and ready for offline play.
  bool isSongCompleted(String ytid) {
    return getSongStatus(ytid) == DownloadStatus.completed;
  }

  /// Returns whether a song is currently queued or downloading.
  bool isSongDownloading(String ytid) {
    final status = getSongStatus(ytid);
    return status == DownloadStatus.queued ||
        status == DownloadStatus.downloading;
  }

  /// Returns current progress for a song (0.0 to 1.0).
  double getSongProgress(String ytid) {
    final active = activeDownloads.value[ytid];
    if (active != null) return active.progress;
    if (isSongCompleted(ytid)) return 1;
    return 0;
  }

  /// Queues a single song for download.
  /// Rejects duplicate downloads if the song is already downloading or completed.
  Future<bool> downloadSong(
    dynamic song, {
    int maxRetries = maxRetriesDefault,
  }) async {
    if (song == null || song is! Map) {
      logger.log('[DOWNLOAD] Invalid song payload provided for download');
      return false;
    }

    final ytid = song['ytid']?.toString() ?? song['id']?.toString();
    if (ytid == null || ytid.isEmpty) {
      logger.log('[DOWNLOAD] Song ytid is missing or empty');
      return false;
    }

    // Check duplicate prevention: already downloaded and file exists
    final existingPath = FilePaths.getAudioPath(ytid);
    if (isSongAlreadyOffline(ytid) && await File(existingPath).exists()) {
      logger.log(
        '[DOWNLOAD] Song $ytid is already downloaded and exists on disk',
      );
      _updateActiveProgress(
        DownloadProgressInfo(
          ytid: ytid,
          title: song['title']?.toString() ?? ytid,
          status: DownloadStatus.completed,
          progress: 1,
        ),
      );
      return true;
    }

    // Check duplicate prevention: already queued or downloading
    if (_inFlightYtids.contains(ytid) ||
        _downloadQueue.any((job) => job.ytid == ytid)) {
      logger.log('[DOWNLOAD] Duplicate download request ignored for $ytid');
      return true;
    }

    final title = song['title']?.toString() ?? ytid;
    final job = _DownloadJob(
      song: Map<String, dynamic>.from(song),
      ytid: ytid,
      title: title,
      maxRetries: maxRetries,
    );

    _updateActiveProgress(
      DownloadProgressInfo(
        ytid: ytid,
        title: title,
        status: DownloadStatus.queued,
      ),
    );

    _downloadQueue.add(job);
    _pumpQueue();

    return job.completer.future;
  }

  /// Cancels an in-progress or queued song download.
  Future<void> cancelSongDownload(String ytid) async {
    // 1. Remove from pending queue if not yet started
    _downloadQueue.removeWhere((job) {
      if (job.ytid == ytid) {
        job.completer.complete(false);
        return true;
      }
      return false;
    });

    // 2. Signal active download worker to cancel
    final token = _cancellationTokens[ytid];
    if (token != null && !token.isCompleted) {
      token.complete();
      await _activeJobCompletions[ytid]?.future;
    }

    _updateActiveProgress(
      DownloadProgressInfo(
        ytid: ytid,
        title: activeDownloads.value[ytid]?.title ?? ytid,
        status: DownloadStatus.cancelled,
      ),
    );

    // Clean any partial temp file
    try {
      final tmpFile = File('${FilePaths.getAudioPath(ytid)}.tmp');
      if (await tmpFile.exists()) {
        await tmpFile.delete();
      }
    } catch (_) {}
  }

  /// Retries a failed download for a song.
  Future<bool> retryDownload(String ytid, {Map? songFallback}) async {
    final song = songFallback ?? getOfflineSongByYtid(ytid);

    await cancelSongDownload(ytid);
    return downloadSong(song);
  }

  /// Deletes a downloaded song from filesystem and Hive metadata.
  Future<bool> deleteSongDownload(String ytid) async {
    if (ytid.isEmpty) return false;

    _updateActiveProgress(
      DownloadProgressInfo(
        ytid: ytid,
        title: activeDownloads.value[ytid]?.title ?? ytid,
        status: DownloadStatus.deleting,
      ),
    );

    // 1. Cancel ongoing download if any
    await cancelSongDownload(ytid);

    // 2. Remove audio and artwork files
    try {
      final audioFile = File(FilePaths.getAudioPath(ytid));
      if (await audioFile.exists()) {
        await audioFile.delete();
      }

      final tmpAudioFile = File('${FilePaths.getAudioPath(ytid)}.tmp');
      if (await tmpAudioFile.exists()) {
        await tmpAudioFile.delete();
      }

      final artworkFile = File(FilePaths.getArtworkPath(ytid));
      if (await artworkFile.exists()) {
        await artworkFile.delete();
      }
    } catch (e, stackTrace) {
      logger.log(
        '[DOWNLOAD] Error deleting files for $ytid',
        error: e,
        stackTrace: stackTrace,
      );
    }

    // 3. Remove metadata from userOfflineSongs and persist to Hive
    try {
      final updatedList = List<dynamic>.from(userOfflineSongs.value)
        ..removeWhere((s) => s is Map && s['ytid']?.toString() == ytid);
      userOfflineSongs.value = updatedList;

      await addOrUpdateData<List>('userNoBackup', 'offlineSongs', updatedList);
    } catch (e, stackTrace) {
      logger.log(
        '[DOWNLOAD] Error removing $ytid from offlineSongs metadata',
        error: e,
        stackTrace: stackTrace,
      );
    }

    // 4. Clean active downloads state
    final nextMap = Map<String, DownloadProgressInfo>.from(
      activeDownloads.value,
    )..remove(ytid);
    activeDownloads.value = nextMap;

    return true;
  }

  /// Deletes all downloaded media and cleans metadata.
  Future<void> deleteAllDownloads() async {
    // 1. Cancel all pending and active jobs
    final allYtids = activeDownloads.value.keys.toList();
    for (final id in allYtids) {
      await cancelSongDownload(id);
    }
    while (_downloadQueue.isNotEmpty) {
      final job = _downloadQueue.removeFirst();
      if (!job.completer.isCompleted) {
        job.completer.complete(false);
      }
      _updateActiveProgress(
        DownloadProgressInfo(
          ytid: job.ytid,
          title: job.title,
          status: DownloadStatus.cancelled,
        ),
      );
    }

    // 2. Delete tracks and artworks directories
    try {
      final tracksDir = Directory('$applicationDirPath/${FilePaths.tracksDir}');
      final artworksDir = Directory(
        '$applicationDirPath/${FilePaths.artworksDir}',
      );

      if (await tracksDir.exists()) {
        await tracksDir.delete(recursive: true);
      }
      if (await artworksDir.exists()) {
        await artworksDir.delete(recursive: true);
      }

      await FilePaths.ensureDirectoriesExist();
    } catch (e, stackTrace) {
      logger.log(
        '[DOWNLOAD] Error deleting media directories',
        error: e,
        stackTrace: stackTrace,
      );
    }

    // 3. Reset Hive metadata
    userOfflineSongs.value = [];
    await addOrUpdateData<List>('userNoBackup', 'offlineSongs', []);

    offlinePlaylistService.offlinePlaylists.value = [];
    await addOrUpdateData<List>('userNoBackup', 'offlinePlaylists', []);

    activeDownloads.value = {};
    logger.log(
      '[DOWNLOAD] All downloads deleted and storage reset successfully',
    );
  }

  /// Reconciles local filesystem audio files with Hive metadata on app startup.
  /// - If metadata exists and file exists -> status: completed, updates fileSize
  /// - If metadata exists and file missing -> status: missing
  /// - Deletes orphaned .tmp partial files from interrupted app runs
  Future<void> reconcileStorageIntegrity() async {
    logger.log('[DOWNLOAD] Starting storage integrity reconciliation...');

    final rawOfflineSongs = userOfflineSongs.value;
    final reconciledSongs = <dynamic>[];
    var missingCount = 0;
    var completedCount = 0;

    for (final item in rawOfflineSongs) {
      if (item is! Map) continue;
      final song = Map<String, dynamic>.from(item);
      final ytid = song['ytid']?.toString() ?? song['id']?.toString() ?? '';
      if (ytid.isEmpty) continue;

      final expectedAudioPath = FilePaths.getAudioPath(ytid);
      final audioFile = File(expectedAudioPath);

      if (await audioFile.exists()) {
        final length = await audioFile.length();
        song['audioPath'] = expectedAudioPath;
        song['localPath'] = expectedAudioPath;
        song['fileSize'] = length;
        song['status'] = DownloadStatus.completed.name;
        reconciledSongs.add(song);
        completedCount++;
      } else {
        // Mark missing
        song['status'] = DownloadStatus.missing.name;
        song['audioPath'] = expectedAudioPath;
        song['localPath'] = expectedAudioPath;
        reconciledSongs.add(song);
        missingCount++;
        logger.log('[DOWNLOAD] Marked track as missing from disk: $ytid');
      }
    }

    userOfflineSongs.value = reconciledSongs;
    await addOrUpdateData<List>(
      'userNoBackup',
      'offlineSongs',
      reconciledSongs,
    );

    // Clean orphaned .tmp files in tracks dir
    try {
      final tracksDir = Directory('$applicationDirPath/${FilePaths.tracksDir}');
      if (await tracksDir.exists()) {
        await for (final file in tracksDir.list()) {
          if (file is File && file.path.endsWith('.tmp')) {
            try {
              await file.delete();
              logger.log(
                '[DOWNLOAD] Cleaned up orphaned tmp file: ${file.path}',
              );
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    logger.log(
      '[DOWNLOAD] Storage integrity reconciled: $completedCount verified, $missingCount missing',
    );
  }

  /// Returns storage usage accounting for offline songs and artworks.
  Future<StorageAccounting> getStorageAccounting() async {
    var totalBytes = 0;
    var totalFiles = 0;

    try {
      final tracksDir = Directory('$applicationDirPath/${FilePaths.tracksDir}');
      if (await tracksDir.exists()) {
        await for (final file in tracksDir.list()) {
          if (file is File) {
            totalFiles++;
            totalBytes += await file.length();
          }
        }
      }

      final artworksDir = Directory(
        '$applicationDirPath/${FilePaths.artworksDir}',
      );
      if (await artworksDir.exists()) {
        await for (final file in artworksDir.list()) {
          if (file is File) {
            totalFiles++;
            totalBytes += await file.length();
          }
        }
      }
    } catch (e, stackTrace) {
      logger.log(
        '[DOWNLOAD] Error calculating storage accounting',
        error: e,
        stackTrace: stackTrace,
      );
    }

    final completedSongs = userOfflineSongs.value.where((s) {
      if (s is! Map) return false;
      final ytid = s['ytid']?.toString();
      if (ytid == null || ytid.isEmpty) return false;
      return File(FilePaths.getAudioPath(ytid)).existsSync();
    }).length;

    return StorageAccounting(
      downloadedSongsCount: completedSongs,
      totalFilesCount: totalFiles,
      totalStorageBytes: totalBytes,
    );
  }

  // --- Internal Worker Engine ---

  void _pumpQueue() {
    while (_inFlightYtids.length < maxConcurrentDownloads &&
        _downloadQueue.isNotEmpty) {
      final nextJob = _downloadQueue.removeFirst();
      _inFlightYtids.add(nextJob.ytid);
      _activeJobCompletions[nextJob.ytid] = Completer<void>();
      _executeDownload(nextJob);
    }
  }

  Future<void> _executeDownload(_DownloadJob job) async {
    final ytid = job.ytid;
    final cancelToken = Completer<void>();
    _cancellationTokens[ytid] = cancelToken;

    var attempt = 0;
    var success = false;
    String? lastError;

    while (attempt < job.maxRetries && !success && !cancelToken.isCompleted) {
      attempt++;
      try {
        _updateActiveProgress(
          DownloadProgressInfo(
            ytid: ytid,
            title: job.title,
            status: DownloadStatus.downloading,
            progress: 0.05,
            retryCount: attempt - 1,
          ),
        );

        success = await _downloadTrackStreamWithCancellation(job, cancelToken);
      } catch (e, stackTrace) {
        lastError = e.toString();
        logger.log(
          '[DOWNLOAD] Attempt $attempt failed for ${job.title} ($ytid)',
          error: e,
          stackTrace: stackTrace,
        );

        if (attempt < job.maxRetries && !cancelToken.isCompleted) {
          // Exponential backoff before retry (e.g. 1s, 2s, 4s)
          final delayMs = 1000 * math.pow(2, attempt - 1).toInt();
          await Future.any([
            Future.delayed(Duration(milliseconds: delayMs)),
            cancelToken.future,
          ]);
        }
      }
    }

    _inFlightYtids.remove(ytid);
    _cancellationTokens.remove(ytid);
    _activeJobCompletions.remove(ytid)?.complete();

    if (cancelToken.isCompleted) {
      job.completer.complete(false);
    } else if (success) {
      job.completer.complete(true);
    } else {
      _updateActiveProgress(
        DownloadProgressInfo(
          ytid: ytid,
          title: job.title,
          status: DownloadStatus.failed,
          error: lastError ?? 'Download failed after $attempt attempts',
          retryCount: attempt,
        ),
      );
      job.completer.complete(false);
    }

    _pumpQueue();
  }

  Future<bool> _downloadTrackStreamWithCancellation(
    _DownloadJob job,
    Completer<void> cancelToken,
  ) async {
    final ytid = job.ytid;
    final audioFinalPath = FilePaths.getAudioPath(ytid);
    final audioTmpPath = '$audioFinalPath.tmp';
    final audioTmpFile = File(audioTmpPath);

    await audioTmpFile.parent.create(recursive: true);

    final audioManifest = await fetchBestAudioStream(ytid);
    if (audioManifest == null) {
      throw StateError('Audio stream manifest not found for $ytid');
    }

    if (cancelToken.isCompleted) return false;

    final totalSize = audioManifest.size.totalBytes;
    var receivedBytes = 0;

    // Check for resumable partial download
    var existingBytes = 0;
    if (await audioTmpFile.exists()) {
      existingBytes = await audioTmpFile.length();
      if (existingBytes >= totalSize && totalSize > 0) {
        // Corrupt or oversized partial file, reset
        try {
          await audioTmpFile.delete();
        } catch (_) {}
        existingBytes = 0;
      }
    }

    final isResuming = existingBytes > 0;
    receivedBytes = existingBytes;

    if (isResuming && totalSize > 0) {
      final initialRatio = (receivedBytes / totalSize).clamp(0.0, 1.0);
      logger.log(
        '[DOWNLOAD] Resuming interrupted download for $ytid from byte $existingBytes of $totalSize (${(initialRatio * 100).toStringAsFixed(1)}%)',
      );
      _updateActiveProgress(
        DownloadProgressInfo(
          ytid: ytid,
          title: job.title,
          status: DownloadStatus.downloading,
          progress: initialRatio,
          bytesDownloaded: receivedBytes,
          totalBytes: totalSize,
        ),
      );
    }

    final stream = ytClient.videos.streamsClient.get(
      audioManifest,
      headers: isResuming ? {'Range': 'bytes=$existingBytes-'} : null,
    );
    final sink = audioTmpFile.openWrite(
      mode: isResuming ? FileMode.append : FileMode.write,
    );

    final streamCompleter = Completer<bool>();
    StreamSubscription<List<int>>? subscription;

    var lastReportedRatio = 0.0;
    var lastReportedMs = 0;

    subscription = stream.listen(
      (chunk) {
        if (cancelToken.isCompleted) {
          subscription?.cancel();
          if (!streamCompleter.isCompleted) streamCompleter.complete(false);
          return;
        }

        sink.add(chunk);
        receivedBytes += chunk.length;

        final ratio = totalSize > 0
            ? (receivedBytes / totalSize).clamp(0.0, 1.0)
            : 0.5;

        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final shouldNotify =
            (ratio - lastReportedRatio).abs() >= 0.03 ||
            (nowMs - lastReportedMs) >= 500 ||
            ratio >= 1.0;

        if (shouldNotify) {
          lastReportedRatio = ratio;
          lastReportedMs = nowMs;
          _updateActiveProgress(
            DownloadProgressInfo(
              ytid: ytid,
              title: job.title,
              status: DownloadStatus.downloading,
              progress: ratio,
              bytesDownloaded: receivedBytes,
              totalBytes: totalSize,
            ),
          );
        }
      },
      onError: (err) {
        if (!streamCompleter.isCompleted) streamCompleter.completeError(err);
      },
      onDone: () {
        _updateActiveProgress(
          DownloadProgressInfo(
            ytid: ytid,
            title: job.title,
            status: DownloadStatus.downloading,
            progress: 1,
            bytesDownloaded: receivedBytes,
            totalBytes: totalSize,
          ),
        );
        if (!streamCompleter.isCompleted) streamCompleter.complete(true);
      },
      cancelOnError: true,
    );

    // Listen for cancel signal
    unawaited(
      cancelToken.future.then((_) {
        subscription?.cancel();
        if (!streamCompleter.isCompleted) streamCompleter.complete(false);
      }),
    );

    final streamSuccess = await streamCompleter.future;
    await sink.flush();
    await sink.close();

    if (!streamSuccess || cancelToken.isCompleted) {
      // Only delete partial file if the user explicitly cancelled the download.
      // On network failure or retryable error, preserve the partial bytes so subsequent
      // attempts resume cleanly without starting back at 0 bytes.
      if (cancelToken.isCompleted && await audioTmpFile.exists()) {
        try {
          await audioTmpFile.delete();
        } catch (_) {}
      }
      return false;
    }

    // Atomically rename .tmp to final audio file
    final finalFile = File(audioFinalPath);
    if (await finalFile.exists()) {
      await finalFile.delete();
    }
    await audioTmpFile.rename(audioFinalPath);

    // Download artwork
    String? artworkPath;
    try {
      final imgUrl =
          job.song['highResImage'] ??
          job.song['image'] ??
          job.song['lowResImage'];
      if (imgUrl != null && imgUrl.toString().isNotEmpty) {
        final expectedArtPath = FilePaths.getArtworkPath(ytid);
        final artFile = await _downloadArtwork(
          imgUrl.toString(),
          expectedArtPath,
        );
        if (artFile != null && await artFile.exists()) {
          artworkPath = expectedArtPath;
        }
      }
    } catch (e) {
      logger.log('[DOWNLOAD] Artwork download skipped for $ytid: $e');
    }

    // Duration fallback
    var duration = job.song['duration'];
    if (duration == null || (duration is num && duration <= 0)) {
      final current = audioHandler.mediaItem.valueOrNull;
      if (current != null &&
          current.extras?['ytid'] == ytid &&
          current.duration != null) {
        duration = current.duration!.inSeconds;
      }
    }

    // Build canonical metadata
    final canonicalSong = buildCanonicalMetadata(
      song: job.song,
      ytid: ytid,
      localPath: audioFinalPath,
      artworkPath: artworkPath,
      fileSize: totalSize > 0 ? totalSize : await finalFile.length(),
      duration: duration is num ? duration.toInt() : null,
      status: DownloadStatus.completed,
    );

    // Save to userOfflineSongs & Hive userNoBackup
    final currentList = List<dynamic>.from(userOfflineSongs.value);
    final idx = currentList.indexWhere(
      (s) => s is Map && s['ytid']?.toString() == ytid,
    );

    if (idx != -1) {
      currentList[idx] = canonicalSong;
    } else {
      currentList.add(canonicalSong);
    }

    userOfflineSongs.value = currentList;
    await addOrUpdateData<List>('userNoBackup', 'offlineSongs', currentList);

    _updateActiveProgress(
      DownloadProgressInfo(
        ytid: ytid,
        title: job.title,
        status: DownloadStatus.completed,
        progress: 1,
        bytesDownloaded: totalSize,
        totalBytes: totalSize,
      ),
    );

    logger.log(
      '[DOWNLOAD] Successfully downloaded and stored: ${job.title} ($ytid)',
    );
    return true;
  }

  Future<File?> _downloadArtwork(String url, String targetPath) async {
    try {
      final response = await ProxyManager().getProxiedResponse(Uri.parse(url));
      if (response.statusCode == 200) {
        final file = File(targetPath);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(response.bodyBytes);
        if (await file.exists() && await file.length() > 0) {
          return file;
        }
      }
    } catch (_) {}
    return null;
  }

  void _updateActiveProgress(DownloadProgressInfo info) {
    final next = Map<String, DownloadProgressInfo>.from(activeDownloads.value);
    next[info.ytid] = info;
    activeDownloads.value = next;
  }

  /// Builds a canonical map representing a downloaded song.
  static Map<String, dynamic> buildCanonicalMetadata({
    required Map song,
    required String ytid,
    required String localPath,
    String? artworkPath,
    required int fileSize,
    int? duration,
    required DownloadStatus status,
    int? downloadedAt,
  }) {
    final now = downloadedAt ?? DateTime.now().millisecondsSinceEpoch;
    return {
      'ytid': ytid,
      'id': ytid,
      'title': song['title']?.toString() ?? ytid,
      'artist': song['artist']?.toString() ?? '',
      'artistId': song['artistId']?.toString(),
      'album': song['album']?.toString(),
      'image': song['image']?.toString() ?? song['highResImage']?.toString(),
      'highResImage':
          song['highResImage']?.toString() ?? song['image']?.toString(),
      'lowResImage':
          song['lowResImage']?.toString() ?? song['image']?.toString(),
      'duration': duration ?? song['duration'],
      'localPath': localPath,
      'audioPath': localPath, // Backward compatibility with existing player
      'artworkPath': artworkPath,
      'downloadedAt': now,
      'dateAdded': now, // Backward compatibility
      'fileSize': fileSize,
      'status': status.name,
      'isLive': false,
    };
  }
}

class _DownloadJob {
  _DownloadJob({
    required this.song,
    required this.ytid,
    required this.title,
    required this.maxRetries,
  });

  final Map<String, dynamic> song;
  final String ytid;
  final String title;
  final int maxRetries;
  final Completer<bool> completer = Completer<bool>();
}

/// Global convenience accessor
final downloadManager = DownloadManager.instance;
