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

import 'package:hive/hive.dart';
import 'package:catchify/main.dart' show isNetworkError, logger;
import 'package:catchify/services/artist_service.dart' show ytMusicClient;
import 'package:catchify/utilities/formatter.dart' show returnSongLayout;
import 'package:catchify/services/common_services.dart';
import 'package:catchify/services/data_manager.dart';
import 'package:catchify/services/playlists_manager.dart';

/// Available search category filters.
enum SearchFilter { all, songs, albums, artists, playlists, videos }

/// Normalized payload containing all categorized results and optional Top Result.
class SearchResultPayload {
  const SearchResultPayload({
    required this.query,
    this.filter = SearchFilter.all,
    this.topResult,
    this.songs = const [],
    this.albums = const [],
    this.artists = const [],
    this.playlists = const [],
    this.videos = const [],
    required this.timestamp,
  });

  factory SearchResultPayload.fromJson(Map<dynamic, dynamic> json) {
    return SearchResultPayload(
      query: json['query']?.toString() ?? '',
      filter: SearchFilter.values.firstWhere(
        (f) => f.name == json['filter'],
        orElse: () => SearchFilter.all,
      ),
      topResult: json['topResult'] is Map
          ? Map<String, dynamic>.from(json['topResult'] as Map)
          : null,
      songs:
          (json['songs'] as List?)
              ?.whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList() ??
          const [],
      albums:
          (json['albums'] as List?)
              ?.whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList() ??
          const [],
      artists:
          (json['artists'] as List?)
              ?.whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList() ??
          const [],
      playlists:
          (json['playlists'] as List?)
              ?.whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList() ??
          const [],
      videos:
          (json['videos'] as List?)
              ?.whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList() ??
          const [],
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  final String query;
  final SearchFilter filter;
  final Map<String, dynamic>? topResult;
  final List<Map<String, dynamic>> songs;
  final List<Map<String, dynamic>> albums;
  final List<Map<String, dynamic>> artists;
  final List<Map<String, dynamic>> playlists;
  final List<Map<String, dynamic>> videos;
  final DateTime timestamp;

  bool get isEmpty =>
      topResult == null &&
      songs.isEmpty &&
      albums.isEmpty &&
      artists.isEmpty &&
      playlists.isEmpty &&
      videos.isEmpty;

  bool get isNotEmpty => !isEmpty;

  Map<String, dynamic> toJson() => {
    'query': query,
    'filter': filter.name,
    if (topResult != null) 'topResult': topResult,
    'songs': songs,
    'albums': albums,
    'artists': artists,
    'playlists': playlists,
    'videos': videos,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };
}

/// Robust Search Service managing query execution, categorization, caching, and suggestions.
class SearchService {
  SearchService._();
  static final SearchService instance = SearchService._();

  static const Duration _cacheDuration = Duration(minutes: 20);
  final Map<String, List<String>> _suggestionMemoryCache = {};

  /// Fetches query suggestions with in-memory caching.
  Future<List<String>> getSuggestions(String query) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return const [];

    if (_suggestionMemoryCache.containsKey(clean)) {
      return _suggestionMemoryCache[clean]!;
    }

    try {
      final suggestions = await getSearchSuggestions(query);
      final personalizedList = <String>[];
      final seen = <String>{};

      // 1. Boost matching recent searches from local history
      if (Hive.isBoxOpen('user')) {
        final rawHistory = Hive.box(
          'user',
        ).get('searchHistory', defaultValue: []);
        if (rawHistory is List) {
          for (final item in rawHistory) {
            final str = item?.toString().trim();
            if (str != null &&
                str.isNotEmpty &&
                str.toLowerCase().contains(clean)) {
              if (seen.add(str.toLowerCase())) {
                personalizedList.add(str);
              }
            }
          }
        }
      }

      // 2. Append remote suggestions
      for (final s in suggestions) {
        final str = s.trim();
        if (str.isNotEmpty && seen.add(str.toLowerCase())) {
          personalizedList.add(str);
        }
      }

      final result = personalizedList.isNotEmpty
          ? personalizedList
          : suggestions;

      if (result.isNotEmpty) {
        if (_suggestionMemoryCache.length > 80) {
          _suggestionMemoryCache.remove(_suggestionMemoryCache.keys.first);
        }
        _suggestionMemoryCache[clean] = result;
      }
      return result;
    } catch (_) {
      return const [];
    }
  }

  /// Executes search with smart category-level lazy querying and Hive caching.
  Future<SearchResultPayload> search(
    String query, {
    SearchFilter filter = SearchFilter.all,
    bool forceRefresh = false,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return SearchResultPayload(
        query: '',
        filter: filter,
        timestamp: DateTime.now(),
      );
    }

    final searchStopwatch = Stopwatch()..start();
    final cacheKey = 'search_v2_${filter.name}_${trimmedQuery.toLowerCase()}';

    // 1. Check Cache
    if (!forceRefresh && Hive.isBoxOpen('cache')) {
      try {
        final cached = await getData(
          'cache',
          cacheKey,
          cachingDuration: _cacheDuration,
        );
        if (cached is Map) {
          final payload = SearchResultPayload.fromJson(cached);
          if (payload.isNotEmpty) {
            logger.log(
              '[SEARCH] query="$trimmedQuery" filter=${filter.name} latency_ms=${searchStopwatch.elapsedMilliseconds} cache_hit=true',
            );
            return payload;
          }
        }
      } catch (_) {}
    }

    // 2. Execute on-demand category queries
    SearchResultPayload result;
    switch (filter) {
      case SearchFilter.songs:
        final songs = await _safeFetchSongs(trimmedQuery);
        result = SearchResultPayload(
          query: trimmedQuery,
          filter: filter,
          songs: songs,
          timestamp: DateTime.now(),
        );
        break;

      case SearchFilter.albums:
        final albums = await _safeFetchAlbums(trimmedQuery);
        result = SearchResultPayload(
          query: trimmedQuery,
          filter: filter,
          albums: albums,
          timestamp: DateTime.now(),
        );
        break;

      case SearchFilter.artists:
        final artists = await _safeFetchArtists(trimmedQuery);
        result = SearchResultPayload(
          query: trimmedQuery,
          filter: filter,
          artists: artists,
          timestamp: DateTime.now(),
        );
        break;

      case SearchFilter.playlists:
        final playlists = await _safeFetchPlaylists(trimmedQuery);
        result = SearchResultPayload(
          query: trimmedQuery,
          filter: filter,
          playlists: playlists,
          timestamp: DateTime.now(),
        );
        break;

      case SearchFilter.videos:
        final videos = await _safeFetchVideos(trimmedQuery);
        result = SearchResultPayload(
          query: trimmedQuery,
          filter: filter,
          videos: videos,
          timestamp: DateTime.now(),
        );
        break;

      case SearchFilter.all:
        result = await _fetchAll(trimmedQuery);
        break;
    }

    final totalItems =
        result.songs.length +
        result.albums.length +
        result.artists.length +
        result.playlists.length +
        result.videos.length +
        (result.topResult != null ? 1 : 0);

    logger.log(
      '[SEARCH] query="$trimmedQuery" filter=${filter.name} latency_ms=${searchStopwatch.elapsedMilliseconds} cache_hit=false items=$totalItems',
    );

    // 3. Cache valid non-empty result
    if (result.isNotEmpty && Hive.isBoxOpen('cache')) {
      unawaited(addOrUpdateData('cache', cacheKey, result.toJson()));
    }

    return result;
  }

  /// Queries all categories concurrently and derives Top Result.
  Future<SearchResultPayload> _fetchAll(String query) async {
    final futures = await Future.wait([
      _safeFetchSongs(query),
      _safeFetchArtists(query),
      _safeFetchAlbums(query),
      _safeFetchPlaylists(query),
      _safeFetchVideos(query),
    ]);

    var songs = futures[0];
    final artists = futures[1];
    final albums = futures[2];
    final playlists = futures[3];
    final videos = futures[4];

    // If songs are empty but artist matched, fallback query for artist tracks
    if (songs.isEmpty && artists.isNotEmpty) {
      final artistName =
          artists.first['title']?.toString() ??
          artists.first['name']?.toString();
      if (artistName != null && artistName.isNotEmpty) {
        songs = await _safeFetchSongs('$artistName songs');
      }
    }

    // Determine Top Result
    final topResult = _deriveTopResult(
      query: query,
      artists: artists,
      songs: songs,
      albums: albums,
      playlists: playlists,
      videos: videos,
    );

    return SearchResultPayload(
      query: query,
      topResult: topResult,
      songs: songs,
      artists: artists,
      albums: albums,
      playlists: playlists,
      videos: videos,
      timestamp: DateTime.now(),
    );
  }

  /// Determines the most relevant item to feature as Top Result.
  Map<String, dynamic>? _deriveTopResult({
    required String query,
    required List<Map<String, dynamic>> artists,
    required List<Map<String, dynamic>> songs,
    required List<Map<String, dynamic>> albums,
    required List<Map<String, dynamic>> playlists,
    required List<Map<String, dynamic>> videos,
  }) {
    final normQuery = query.trim().toLowerCase();

    // 1. If artist name matches closely, prioritize Artist
    if (artists.isNotEmpty) {
      final firstArtist = artists.first;
      final artistName = (firstArtist['title'] ?? firstArtist['name'] ?? '')
          .toString()
          .toLowerCase();
      if (artistName == normQuery ||
          artistName.contains(normQuery) ||
          normQuery.contains(artistName)) {
        return {
          ...firstArtist,
          'topResultCategory': 'Artist',
          'topResultType': 'artist',
        };
      }
    }

    // 2. If song title matches closely, prioritize Song
    if (songs.isNotEmpty) {
      final firstSong = songs.first;
      final songTitle = (firstSong['title'] ?? '').toString().toLowerCase();
      if (songTitle == normQuery ||
          songTitle.contains(normQuery) ||
          normQuery.contains(songTitle)) {
        return {
          ...firstSong,
          'topResultCategory': 'Song',
          'topResultType': 'song',
        };
      }
    }

    // 3. If album matches closely
    if (albums.isNotEmpty) {
      final firstAlbum = albums.first;
      final albumTitle = (firstAlbum['title'] ?? '').toString().toLowerCase();
      if (albumTitle == normQuery || normQuery.contains(albumTitle)) {
        return {
          ...firstAlbum,
          'topResultCategory': 'Album',
          'topResultType': 'album',
        };
      }
    }

    // 4. Default to first song or first artist if available
    if (songs.isNotEmpty) {
      return {
        ...songs.first,
        'topResultCategory': 'Song',
        'topResultType': 'song',
      };
    }

    if (artists.isNotEmpty) {
      return {
        ...artists.first,
        'topResultCategory': 'Artist',
        'topResultType': 'artist',
      };
    }

    if (albums.isNotEmpty) {
      return {
        ...albums.first,
        'topResultCategory': 'Album',
        'topResultType': 'album',
      };
    }

    if (playlists.isNotEmpty) {
      return {
        ...playlists.first,
        'topResultCategory': 'Playlist',
        'topResultType': 'playlist',
      };
    }

    return null;
  }

  Future<List<Map<String, dynamic>>> _safeFetchSongs(String query) async {
    try {
      final raw = await fetchSongsList(
        query,
      ).timeout(const Duration(seconds: 7));
      final items = raw
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
      return _deduplicateTracks(items);
    } catch (e, st) {
      if (!isNetworkError(e)) {
        logger.log('Error in _safeFetchSongs', error: e, stackTrace: st);
      }
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _safeFetchArtists(String query) async {
    try {
      final raw = await searchArtists(
        query,
      ).timeout(const Duration(seconds: 7));
      return raw.whereType<Map>().map(Map<String, dynamic>.from).toList();
    } catch (e, st) {
      if (!isNetworkError(e)) {
        logger.log('Error in _safeFetchArtists', error: e, stackTrace: st);
      }
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _safeFetchAlbums(String query) async {
    try {
      final raw = await getPlaylists(
        query: query,
        type: 'album',
      ).timeout(const Duration(seconds: 7));
      return raw.whereType<Map>().map(Map<String, dynamic>.from).toList();
    } catch (e, st) {
      if (!isNetworkError(e)) {
        logger.log('Error in _safeFetchAlbums', error: e, stackTrace: st);
      }
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _safeFetchPlaylists(String query) async {
    try {
      final raw = await getPlaylists(
        query: query,
        type: 'playlist',
      ).timeout(const Duration(seconds: 7));
      return raw.whereType<Map>().map(Map<String, dynamic>.from).toList();
    } catch (e, st) {
      if (!isNetworkError(e)) {
        logger.log('Error in _safeFetchPlaylists', error: e, stackTrace: st);
      }
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _safeFetchVideos(String query) async {
    try {
      final raw = await ytMusicClient.music
          .searchVideos(query)
          .timeout(const Duration(seconds: 7));
      final videos = <Map<String, dynamic>>[];
      for (var i = 0; i < raw.length; i++) {
        final video = raw[i];
        final layout = returnSongLayout(i, video);
        layout['isVideo'] = true;
        videos.add(layout);
      }
      return _deduplicateTracks(videos);
    } catch (e, st) {
      if (!isNetworkError(e)) {
        logger.log('Error in _safeFetchVideos', error: e, stackTrace: st);
      }
      return [];
    }
  }

  List<Map<String, dynamic>> _deduplicateTracks(
    List<Map<String, dynamic>> items,
  ) {
    final seenIds = <String>{};
    final seenKeys = <String>{};
    final deduplicated = <Map<String, dynamic>>[];

    for (final item in items) {
      final ytid = (item['ytid'] ?? item['id'])?.toString() ?? '';
      if (ytid.isNotEmpty && !seenIds.add(ytid)) {
        continue;
      }

      final rawTitle = (item['title'] ?? '').toString().toLowerCase().trim();
      final rawArtist = (item['artist'] ?? '').toString().toLowerCase().trim();

      final cleanTitle = rawTitle
          .replaceAll(
            RegExp(
              r'\s*\(.*?(?:official|audio|video|lyrics|lyrical|hd|4k|from).*?\)',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(
            RegExp(
              r'\s*\[.*?(?:official|audio|video|lyrics|lyrical|hd|4k|from).*?\]',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();

      if (cleanTitle.isNotEmpty && rawArtist.isNotEmpty) {
        final key = '$cleanTitle::$rawArtist';
        if (!seenKeys.add(key)) {
          continue;
        }
      }

      deduplicated.add(item);
    }
    return deduplicated;
  }
}
