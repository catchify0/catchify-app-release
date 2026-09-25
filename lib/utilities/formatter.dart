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

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

const _noiseTerms =
    'official music video|official lyric video|official lyrics video|'
    'official video song|official video|official 4k video|official audio song|official audio|'
    'music video|lyric video|lyrics video|video song|full video song|full video|'
    'official hd video|lyric visualizer|lyric vizualizer|'
    'official visualizer|official vizualizer|official visualiser|official vizualiser|'
    'lyrics|lyric|official song clip|official|karaoke|video|teaser|promo';

// Bracket groups that contain a noise term anywhere inside: (Official Video)
final _bracketedNoisePattern = RegExp(
  r'[\(\[][^\)\]]*(?:' + _noiseTerms + r')[^\)\]]*[\)\]]',
  caseSensitive: false,
);

// Same noise phrases unbracketed at the end of a title, e.g. after | is stripped.
final _trailingNoisePattern = RegExp(
  r'\s*[-–—]?\s*\b(?:' + _noiseTerms + r'|audio)\b\s*$',
  caseSensitive: false,
);

String formatSongTitle(String title) {
  // Remove bracketed groups first to avoid false matches on real title words.
  var t = title.replaceAll(_bracketedNoisePattern, '');

  // Strip lone brackets, pipes, and decode HTML entities.
  t = t
      .replaceAll(RegExp(r'[\[\]()|]'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&#039;', "'")
      .replaceAll('&quot;', '"')
      .trimLeft();

  // Strip trailing unbracketed noise; loop to handle stacked suffixes.
  String prev;
  do {
    prev = t;
    t = t.replaceAll(_trailingNoisePattern, '');
  } while (t != prev);

  return t.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
}

String cleanArtworkUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return trimmed;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return trimmed;
  final host = uri.host.toLowerCase();
  if (host.contains('youtube.com') || host.contains('ytimg.com')) {
    final clean = uri.replace(queryParameters: {}).toString();
    return clean.endsWith('?') ? clean.substring(0, clean.length - 1) : clean;
  }
  return trimmed;
}

String formatArtworkResolution(String url, int size) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return trimmed;
  final uri = Uri.tryParse(trimmed);
  final host = uri?.host.toLowerCase() ?? '';
  if (!host.endsWith('googleusercontent.com') && !host.endsWith('ggpht.com')) {
    if (host.contains('youtube.com') || host.contains('ytimg.com')) {
      final cleanUri = uri != null && uri.hasQuery
          ? uri.replace(queryParameters: {})
          : uri;
      var clean = cleanUri?.toString() ?? trimmed;
      if (clean.endsWith('?')) clean = clean.substring(0, clean.length - 1);

      if (size >= 720) {
        clean = clean.replaceFirst(
          RegExp(r'/(?:default|mqdefault|hqdefault|sddefault)\.jpg'),
          '/maxresdefault.jpg',
        );
      } else {
        // Use mqdefault (320x180, true 16:9) to avoid hqdefault's 4:3 black bars
        clean = clean.replaceFirst(
          RegExp(r'/(?:default|hqdefault|sddefault)\.jpg'),
          '/mqdefault.jpg',
        );
      }
      return clean;
    }
    return trimmed;
  }

  var result = trimmed;
  if (result.contains(RegExp(r'=w\d+-h\d+'))) {
    result = result.replaceFirst(
      RegExp(r'=w\d+-h\d+.*$'),
      '=w$size-h$size-l90-rj',
    );
  } else if (result.contains(RegExp(r'=s\d+'))) {
    result = result.replaceFirst(RegExp(r'=s\d+.*$'), '=w$size-h$size-l90-rj');
  } else if (result.contains('=')) {
    result = result.replaceFirst(RegExp(r'=[^=]*$'), '=w$size-h$size-l90-rj');
  } else {
    result = '$result=w$size-h$size-l90-rj';
  }
  return result;
}

Map<String, dynamic> returnSongLayout(
  int index,
  Video song, {
  String? playlistImage,
}) {
  final String artist;
  final String rawTitle;

  final musicData = song.musicData.firstOrNull;
  if (musicData != null &&
      musicData.artist != null &&
      musicData.artist!.trim().isNotEmpty) {
    artist = musicData.artist!.trim();
    rawTitle = song.title;
  } else {
    // Split only on the first ' - ' so dashes inside the title are preserved.
    final sep = song.title.indexOf(' - ');
    artist = sep != -1 ? song.title.substring(0, sep) : song.author;
    rawTitle = sep != -1 ? song.title.substring(sep + 3) : song.title;
  }
  final title = formatSongTitle(rawTitle);

  final musicImage = song.musicData.isNotEmpty
      ? song.musicData.first.image?.toString()
      : null;
  // Always prioritize the individual song's artwork over the playlist cover!
  final effectiveImage = (musicImage != null && musicImage.trim().isNotEmpty)
      ? musicImage.trim()
      : (playlistImage != null && playlistImage.trim().isNotEmpty
            ? playlistImage.trim()
            : null);

  final videoId = song.id.value;
  final defaultMaxRes = 'https://i.ytimg.com/vi/$videoId/maxresdefault.jpg';
  final defaultHq = 'https://i.ytimg.com/vi/$videoId/mqdefault.jpg';

  final cleanImage = (effectiveImage != null && effectiveImage.isNotEmpty)
      ? cleanArtworkUrl(effectiveImage)
      : null;

  return {
    'id': index,
    'ytid': song.id.toString(),
    'title': title.isEmpty ? rawTitle.trim() : title,
    'artist': artist,
    'artistId': song.channelId.toString(),
    'videoAuthor': song.author,
    'image': cleanImage != null
        ? formatArtworkResolution(cleanImage, 1080)
        : defaultMaxRes,
    'lowResImage': cleanImage != null
        ? formatArtworkResolution(cleanImage, 544)
        : defaultHq,
    'highResImage': cleanImage != null
        ? formatArtworkResolution(cleanImage, 1080)
        : defaultMaxRes,
    'duration': song.duration?.inSeconds,
    'isLive': song.isLive,
  };
}

String? getSongId(String url) => VideoId.parseVideoId(url);

String formatDuration(dynamic audioDuration) {
  var totalSeconds = 0;
  if (audioDuration is Duration) {
    totalSeconds = audioDuration.inSeconds;
  } else if (audioDuration is int) {
    totalSeconds = audioDuration;
  } else if (audioDuration is num) {
    totalSeconds = audioDuration.round();
  } else if (audioDuration is String) {
    totalSeconds =
        int.tryParse(audioDuration) ??
        double.tryParse(audioDuration)?.round() ??
        0;
  }

  if (totalSeconds < 0) totalSeconds = 0;

  final duration = Duration(seconds: totalSeconds);

  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  return [
    if (hours > 0) hours.toString().padLeft(2, '0'),
    minutes.toString().padLeft(2, '0'),
    seconds.toString().padLeft(2, '0'),
  ].join(':');
}
