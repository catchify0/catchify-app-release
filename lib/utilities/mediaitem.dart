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

import 'package:audio_service/audio_service.dart';
import 'package:catchify/services/artwork_service.dart';
import 'package:catchify/services/common_services.dart';

Map mediaItemToMap(MediaItem mediaItem) {
  final extras = mediaItem.extras;
  return {
    'id': mediaItem.id,
    'ytid': extras?['ytid'] ?? mediaItem.id,
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
    'source': extras?['source'],
    'contentType': extras?['contentType'],
  };
}

MediaItem mapToMediaItem(
  Map song, {
  void Function(Uri squareUri)? onSquareArtworkReady,
}) {
  final ytid = song['ytid']?.toString();
  final offlineSong = ytid != null
      ? getOfflineSongByYtid(ytid)
      : <String, dynamic>{};
  final isOffline = offlineSong.isNotEmpty;

  final offlineArtworkPath =
      isOffline ? offlineSong['artworkPath']?.toString() : null;

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
    id: (song['id'] ?? song['ytid'] ?? '').toString(),
    artist: (song['artist'] ?? '').toString().trim(),
    title: (song['title'] ?? '').toString(),
    artUri: artUri,
    duration: parsedDuration,
    extras: {
      'image': song['image'],
      'lowResImage': song['lowResImage'],
      'ytid': song['ytid'] ?? song['id'],
      'artistId': song['artistId'],
      'videoAuthor': song['videoAuthor'],
      'isLive': song['isLive'],
      'highResImage': song['highResImage'],
      'artworkPath': isOffline ? offlineSong['artworkPath']?.toString() : null,
      'artWorkPath': isOffline ? offlineSong['artworkPath']?.toString() : null,
      'source': song['source'],
      'contentType': song['contentType'],
    },
  );
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
