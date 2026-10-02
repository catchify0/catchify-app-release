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
 *     For more information about Catchify, including how to contribute,
 *     please visit: https://github.com/catchify0/catchify0.github.io
 */

import 'dart:async';
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:catchify/main.dart' show logger;
import 'package:catchify/services/artist_service.dart' show ytMusicClient;
import 'package:catchify/services/data_manager.dart';
import 'package:catchify/utilities/formatter.dart'
    show isOfficialSquareArtwork, returnSongLayout;
import 'package:catchify/utilities/language_utils.dart';
import 'package:youtube_music_explode_dart/youtube_music_explode_dart.dart';

/// Service providing access to free public global charts (Deezer Public API & Apple Music RSS)
/// paired with YouTube Music for seamless playback.
class GlobalChartsService {
  factory GlobalChartsService() => _instance;
  GlobalChartsService._internal();
  static final GlobalChartsService _instance = GlobalChartsService._internal();

  static const _deezerGlobalChartUrl = 'https://api.deezer.com/chart/0/tracks?limit=50';
  static const _requestTimeout = Duration(seconds: 5);

  final Map<String, List<Map<String, dynamic>>> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const _cacheDuration = Duration(hours: 4);

  /// Fetches real-time worldwide Top 50 chart from Deezer's free public endpoint.
  Future<List<Map<String, dynamic>>> getGlobalTop50({
    bool forceRefresh = false,
  }) async {
    const cacheKey = 'deezer_global_top_50_v1';

    // 1. In-memory cache
    if (!forceRefresh && _memoryCache.containsKey(cacheKey)) {
      final ts = _cacheTimestamps[cacheKey];
      if (ts != null && DateTime.now().difference(ts) < _cacheDuration) {
        return _memoryCache[cacheKey]!;
      }
    }

    // 2. Persistent Hive cache
    if (!forceRefresh && Hive.isBoxOpen('cache')) {
      try {
        final cached = await getData('cache', cacheKey);
        if (cached is List && cached.isNotEmpty) {
          final mapped = cached
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList();
          _memoryCache[cacheKey] = mapped;
          _cacheTimestamps[cacheKey] = DateTime.now();
          return mapped;
        }
      } catch (_) {}
    }

    try {
      final response = await http
          .get(Uri.parse(_deezerGlobalChartUrl))
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json is Map && json['data'] is List) {
          final items = <Map<String, dynamic>>[];
          final list = json['data'] as List;

          for (final (index, item) in list.indexed) {
            if (item is! Map) continue;
            final title = item['title']?.toString() ?? '';
            final artistMap = item['artist'];
            final artistName = artistMap is Map ? artistMap['name']?.toString() ?? '' : '';
            final albumMap = item['album'];
            final coverUrl = albumMap is Map
                ? (albumMap['cover_xl'] ?? albumMap['cover_big'] ?? albumMap['cover_medium'])?.toString()
                : null;
            final duration = (item['duration'] as num?)?.toInt() ?? 0;

            items.add({
              'id': index,
              'title': title,
              'artist': artistName,
              'image': coverUrl,
              'highResImage': coverUrl,
              'lowResImage': albumMap is Map ? albumMap['cover_small']?.toString() : coverUrl,
              'duration': duration,
              'chartRank': index + 1,
              'source': 'deezer-chart',
            });
          }

          if (items.isNotEmpty) {
            _memoryCache[cacheKey] = items;
            _cacheTimestamps[cacheKey] = DateTime.now();
            if (Hive.isBoxOpen('cache')) {
              unawaited(addOrUpdateData('cache', cacheKey, items));
            }
            return items;
          }
        }
      }
    } catch (e) {
      logger.log('[GLOBAL_CHARTS] Deezer chart fetch failed: $e');
    }

    return _memoryCache[cacheKey] ?? const [];
  }

  /// Fetches official country music charts from Apple Music's free public RSS feed.
  Future<List<Map<String, dynamic>>> getAppleMusicCountryChart(
    String countryCode, {
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    final cleanCode = resolveCountryCode(countryCode).toLowerCase();
    final effectiveCode = cleanCode == 'global' ? 'us' : cleanCode;
    final cacheKey = 'apple_music_chart_v1_${effectiveCode}_$limit';

    // 1. In-memory cache
    if (!forceRefresh && _memoryCache.containsKey(cacheKey)) {
      final ts = _cacheTimestamps[cacheKey];
      if (ts != null && DateTime.now().difference(ts) < _cacheDuration) {
        return _memoryCache[cacheKey]!;
      }
    }

    // 2. Persistent Hive cache
    if (!forceRefresh && Hive.isBoxOpen('cache')) {
      try {
        final cached = await getData('cache', cacheKey);
        if (cached is List && cached.isNotEmpty) {
          final mapped = cached
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList();
          _memoryCache[cacheKey] = mapped;
          _cacheTimestamps[cacheKey] = DateTime.now();
          return mapped;
        }
      } catch (_) {}
    }

    final url =
        'https://rss.applemarketingtools.com/api/v2/$effectiveCode/music/most-played/$limit/songs.json';

    try {
      final response =
          await http.get(Uri.parse(url)).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json is Map &&
            json['feed'] is Map &&
            json['feed']['results'] is List) {
          final results = json['feed']['results'] as List;
          final items = <Map<String, dynamic>>[];

          for (final (index, entry) in results.indexed) {
            if (entry is! Map) continue;
            final name = entry['name']?.toString() ?? '';
            final artistName = entry['artistName']?.toString() ?? '';
            final rawArt = entry['artworkUrl100']?.toString() ?? '';
            final highResArt = rawArt.replaceAll(RegExp(r'\d+x\d+bb'), '600x600bb');

            items.add({
              'id': index,
              'title': name,
              'artist': artistName,
              'image': highResArt,
              'highResImage': highResArt,
              'lowResImage': rawArt,
              'chartRank': index + 1,
              'source': 'apple-music-rss',
            });
          }

          if (items.isNotEmpty) {
            _memoryCache[cacheKey] = items;
            _cacheTimestamps[cacheKey] = DateTime.now();
            if (Hive.isBoxOpen('cache')) {
              unawaited(addOrUpdateData('cache', cacheKey, items));
            }
            return items;
          }
        }
      }
    } catch (e) {
      logger.log('[GLOBAL_CHARTS] Apple Music RSS fetch failed for $effectiveCode: $e');
    }

    return _memoryCache[cacheKey] ?? const [];
  }

  /// Resolves an external chart track into an official YouTube Music track for immediate audio playback.
  Future<Map<String, dynamic>?> resolveToYtSong(Map<String, dynamic> chartTrack) async {
    final title = chartTrack['title']?.toString() ?? '';
    final artist = chartTrack['artist']?.toString() ?? '';
    if (title.isEmpty) return null;

    final query = '$title $artist';
    try {
      final results = await ytMusicClient.music
          .searchSongs(query, limit: 3)
          .timeout(const Duration(seconds: 4))
          .catchError((_) => <Video>[]);

      for (final (index, video) in results.indexed) {
        final songMap = returnSongLayout(index, video);
        if (isOfficialSquareArtwork(songMap['image']?.toString())) {
          songMap['chartRank'] = chartTrack['chartRank'];
          return songMap;
        }
      }
    } catch (_) {}

    return null;
  }
}
