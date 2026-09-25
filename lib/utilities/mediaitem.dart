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

import 'package:audio_service/audio_service.dart';
import 'package:catchify/services/artwork_service.dart';
import 'package:catchify/services/common_services.dart';
import 'package:catchify/services/io_service.dart';
import 'package:catchify/utilities/queue_entry_utils.dart';

Map mediaItemToMap(MediaItem mediaItem) {
  final extras = mediaItem.extras;
  final ytid = extras?['ytid']?.toString().trim();
  final canonicalId = ytid != null && ytid.isNotEmpty ? ytid : mediaItem.id;
  final artworkPath = extras?['artworkPath']?.toString();
  return {
    'id': canonicalId,
    'ytid': canonicalId,
    'album': mediaItem.album.toString(),
    'artist': mediaItem.artist.toString(),
    'title': mediaItem.title,
    'artistId': extras?['artistId'],
    'videoAuthor': extras?['videoAuthor'],
    'image': extras?['image'] ?? mediaItem.artUri.toString(),
    'highResImage': extras?['highResImage'] ?? mediaItem.artUri.toString(),
    'lowResImage': extras?['lowResImage'],
    'isLive': extras?['isLive'] ?? false,
    'duration': mediaItem.duration?.inSeconds,
    'artworkPath': artworkPath != null && artworkPath.isNotEmpty
        ? artworkPath
        : null,
    'source': extras?['source'],
    'contentType': extras?['contentType'],
  };
}

MediaItem mapToMediaItem(
  Map song, {
  void Function(Uri squareUri)? onSquareArtworkReady,
}) {
  final ytid = canonicalSongId(song);
  final offlineSong = ytid != null
      ? getOfflineSongByYtid(ytid)
      : <String, dynamic>{};
  final isOffline = offlineSong.isNotEmpty;

  final storedArtworkPath = isOffline
      ? offlineSong['artworkPath']?.toString()
      : null;
  final offlineArtworkPath = resolveOfflineArtworkPath(ytid, storedArtworkPath);

  final artUri = ArtworkService.instance.resolveArtUri(
    song,
    offlineArtworkPath: offlineArtworkPath,
    onSquareReady: onSquareArtworkReady,
  );

  Duration? parsedDuration;
  final rawDuration = song['duration'] ?? offlineSong['duration'];
  if (rawDuration is Duration) {
    parsedDuration = rawDuration;
  } else if (rawDuration is num) {
    parsedDuration = Duration(seconds: rawDuration.toInt());
  } else if (rawDuration != null) {
    final parsed = int.tryParse(rawDuration.toString());
    if (parsed != null) parsedDuration = Duration(seconds: parsed);
  }

  return MediaItem(
    id: ytid ?? '',
    artist: (song['artist'] ?? '').toString().trim(),
    title: (song['title'] ?? '').toString(),
    artUri: artUri,
    duration: parsedDuration,
    extras: {
      'image': song['image'],
      'lowResImage': song['lowResImage'],
      'ytid': ytid,
      'artistId': song['artistId'],
      'videoAuthor': song['videoAuthor'],
      'isLive': song['isLive'],
      'highResImage': song['highResImage'],
      'artworkPath': offlineArtworkPath,
      'artWorkPath': offlineArtworkPath,
      'source': song['source'],
      'contentType': song['contentType'],
    },
  );
}

String? resolveOfflineArtworkPath(String? ytid, String? storedPath) {
  if (ytid == null || ytid.isEmpty) return null;

  final candidates = <String>[
    if (storedPath != null && storedPath.isNotEmpty) storedPath,
    if (_canonicalArtworkPath(ytid) case final canonicalPath?) canonicalPath,
  ];
  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync() && file.lengthSync() > 0) return file.path;
  }
  return null;
}

String? _canonicalArtworkPath(String ytid) {
  try {
    return FilePaths.getArtworkPath(ytid);
  } catch (error) {
    if (error.toString().contains('LateInitializationError')) return null;
    rethrow;
  }
}

/// Compares two Duration objects with tolerance for minor differences.
///
/// This prevents unnecessary updates when duration values have minor variations
/// (e.g., due to buffering or precision differences).
bool durationEquals(Duration? prev, Duration? curr) {
  if (prev == curr) return true;
  if (prev == null || curr == null) return prev == curr;

  // Consider durations equal if they differ by less than 1 second
  return (prev - curr).abs() < const Duration(seconds: 1);
}
