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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:catchify/constants/clients.dart';
import 'package:catchify/main.dart' show isNetworkError, logger;
import 'package:catchify/models/lyric_line.dart';
import 'package:catchify/models/proxy_model.dart';
import 'package:catchify/services/artist_service.dart' show ytMusicClient;
import 'package:catchify/services/data_manager.dart';
import 'package:catchify/services/download_manager.dart';
import 'package:catchify/services/lyrics_manager.dart';
import 'package:catchify/services/playlists_manager.dart';
import 'package:catchify/services/proxy_manager.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/app_utils.dart';
import 'package:catchify/utilities/formatter.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

List globalSongs = [];

List _readStoredList(Box box, String key) {
  final value = box.toMap()[key];
  return value is List ? List.from(value) : [];
}

ValueNotifier<List> userLikedSongsList = ValueNotifier<List>(
  _readStoredList(Hive.box('user'), 'likedSongs'),
);

ValueNotifier<List> userRecentlyPlayed = ValueNotifier<List>(
  _readStoredList(Hive.box('user'), 'recentlyPlayedSongs'),
);
ValueNotifier<List> userOfflineSongs = ValueNotifier<List>(
  _readStoredList(Hive.box('userNoBackup'), 'offlineSongs'),
);
ValueNotifier<List> userLocalSongs = ValueNotifier<List>(
  _readStoredList(Hive.box('userNoBackup'), 'localSongs'),
);
List<String> localMusicFolders = List<String>.from(
  _readStoredList(
    Hive.box('userNoBackup'),
    'localMusicFolders',
  ).whereType<String>(),
);

dynamic nextRecommendedSong;

var _songLikeUpdateToken = 0;
final _latestSongLikeUpdateTokens = <String, int>{};

final lyrics = ValueNotifier<String?>(null);
String? lastFetchedLyrics;
String? _latestLyricsRequest;
int _latestLyricsRequestId = 0;
final Map<String, Future<String?>> _lyricsInFlight = {};
final Map<String, Future<String?>> _streamUrlInFlight = {};

void reloadSongLibraryStateFromStorage() {
  final userBox = Hive.box('user');
  final values = userBox.toMap();
  final dynamic likedSongs = values['likedSongs'];
  final dynamic recentlyPlayed = values['recentlyPlayedSongs'];
  userLikedSongsList.value = likedSongs is List ? List.from(likedSongs) : [];
  userRecentlyPlayed.value = recentlyPlayed is List
      ? List.from(recentlyPlayed)
      : [];
}

// Timeouts and durations used across manifest fetching and cache validation.
const Duration _manifestTimeout = Duration(seconds: 30);
const Duration _cacheValidationDuration = Duration(hours: 1);

/// Fetches a stream manifest for a song, honoring proxy settings.
Future<StreamManifest?> _fetchStreamManifest(String songId) async {
  final mode = proxyModeNotifier.value;

  // In Country Match or Custom mode, use proxy directly
  if (mode == ProxyMode.countryMatch || mode == ProxyMode.custom) {
    try {
      final proxyManifest = await ProxyManager()
          .getSongManifest(songId)
          .timeout(_manifestTimeout);
      if (proxyManifest != null) return proxyManifest;
    } catch (e, stackTrace) {
      if (isNetworkError(e)) {
        logger.log('Proxy manifest fetch failed for $songId: network offline');
        return null;
      }
      logger.log(
        'Proxy failed to fetch manifest for $songId, falling back to direct connection',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // Direct connection first (used by default in Off and Smart Auto modes)
  try {
    return await ytClient.videos.streams
        .getManifest(songId, ytClients: customClients)
        .timeout(_manifestTimeout);
  } catch (e, stackTrace) {
    if (isNetworkError(e)) {
      logger.log('Network offline or host lookup failed for $songId');
      return null;
    }
    logger.log(
      'Failed to fetch manifest with customClients for $songId, retrying with default client fallback',
      error: e,
      stackTrace: stackTrace,
    );
    try {
      return await ytClient.videos.streams
          .getManifest(songId)
          .timeout(_manifestTimeout);
    } catch (directErr, directSt) {
      if (isNetworkError(directErr)) {
        return null;
      }
      // Smart Auto-Proxy failover:
      // If direct connection fails (geo-blocked or 403) and auto mode is enabled:
      if (mode == ProxyMode.auto || useProxy.value) {
        logger.log(
          '[SMART_AUTO_PROXY] Direct stream failed for $songId. Auto-engaging proxy fallback...',
          error: directErr,
          stackTrace: directSt,
        );
        try {
          final autoManifest = await ProxyManager()
              .getSongManifest(songId)
              .timeout(_manifestTimeout);
          if (autoManifest != null) {
            logger.log(
              '[SMART_AUTO_PROXY] Successfully resolved stream manifest via proxy for $songId!',
            );
            return autoManifest;
          }
        } catch (proxyErr) {
          logger.log('[SMART_AUTO_PROXY] Proxy fallback failed: $proxyErr');
        }
      }
      rethrow;
    }
  }
}

/// Returns a cached song URL if present and still valid.
Future<String?> _getCachedSongUrl(
  String cacheKey,
  Duration cacheDuration,
) async {
  final cachedUrl = await getData(
    'cache',
    cacheKey,
    cachingDuration: cacheDuration,
  );

  if (cachedUrl is! String || cachedUrl.isEmpty) {
    return null;
  }

  final cacheBox = await Hive.openBox('cache');
  final cacheDate = cacheBox.get('${cacheKey}_date') as DateTime?;
  final now = DateTime.now();
  final isOld =
      cacheDate != null && now.difference(cacheDate) > _cacheValidationDuration;

  if (!isOld) {
    return cachedUrl;
  }

  if (await _validateCachedUrl(cachedUrl)) {
    return cachedUrl;
  }

  await deleteData('cache', cacheKey);
  await deleteData('cache', '${cacheKey}_date');
  return null;
}

/// Checks if a cached URL still responds successfully.
Future<bool> _validateCachedUrl(String cachedUrl) async {
  try {
    final response = await http
        .get(Uri.parse(cachedUrl), headers: {'Range': 'bytes=0-0'})
        .timeout(const Duration(seconds: 5));
    return response.statusCode == 200 || response.statusCode == 206;
  } catch (_) {
    return false;
  }
}

String _cleanTitleForDedup(String title) {
  return title
      .replaceAll(RegExp(r'\[.*?\]'), '')
      .replaceAll(RegExp(r'\(.*?\)'), '')
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .toLowerCase()
      .trim();
}

String _cleanArtistForDedup(String artist) {
  final first = artist
      .split(RegExp(r'[,&]|\bfeat\b|\bft\b', caseSensitive: false))
      .first;
  return first
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .toLowerCase()
      .trim();
}

Future<List> fetchSongsList(String searchQuery) async {
  try {
    // 1. YouTube Music "Songs" search: returns official audio releases/Topic tracks only
    // (strictly excludes videos, fan covers, lyric videos, teasers, and dialogue clips)
    var searchResults = <Video>[];
    try {
      searchResults = await ytMusicClient.music.searchSongs(searchQuery);
    } catch (e, stackTrace) {
      if (!isNetworkError(e)) {
        logger.log(
          'Error in ytMusicClient.searchSongs for "$searchQuery"',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    // 2. If empty, retry with formatted/sanitized title
    if (searchResults.isEmpty) {
      final cleaned = formatSongTitle(searchQuery);
      if (cleaned.isNotEmpty &&
          cleaned.toLowerCase() != searchQuery.toLowerCase()) {
        try {
          searchResults = await ytMusicClient.music.searchSongs(cleaned);
        } catch (_) {}
      }
    }

    // 3. Deduplicate by video ID and (normalized title + primary artist)
    final seenIds = <String>{};
    final seenKeys = <String>{};
    final songsList = <Map<String, dynamic>>[];

    for (final video in searchResults) {
      final ytid = video.id.value;
      if (!seenIds.add(ytid)) continue;

      // Filter out obvious ringtones / promos (< 30s)
      if (video.duration != null &&
          video.duration!.inSeconds > 0 &&
          video.duration!.inSeconds < 30) {
        continue;
      }

      final layout = returnSongLayout(songsList.length, video);
      final rawTitle = layout['title']?.toString() ?? video.title;
      final rawArtist = layout['artist']?.toString() ?? video.author;

      final normTitle = _cleanTitleForDedup(rawTitle);
      final normArtist = _cleanArtistForDedup(rawArtist);
      final normKey = '$normTitle|$normArtist';

      if (normTitle.isNotEmpty && !seenKeys.add(normKey)) {
        // Skip duplicate version of the same song by the same artist
        continue;
      }

      songsList.add(layout);
    }

    return songsList;
  } catch (e, stackTrace) {
    logger.log('Error in fetchSongsList', error: e, stackTrace: stackTrace);
    return [];
  }
}

Future<List> getRecommendedSongs({bool forceRefresh = false}) async {
  try {
    if (externalRecommendations.value && userRecentlyPlayed.value.isNotEmpty) {
      final recs = await _getRecommendationsFromRecentlyPlayed(
        forceRefresh: forceRefresh,
      );
      if (recs.isNotEmpty) return recs;
    }
    return await _getRecommendationsFromMixedSources(
      forceRefresh: forceRefresh,
    );
  } catch (e, stackTrace) {
    logger.log(
      'Error in getRecommendedSongs',
      error: e,
      stackTrace: stackTrace,
    );
    return [];
  }
}

Future<List> _getRecommendationsFromRecentlyPlayed({
  bool forceRefresh = false,
}) async {
  String? rawLang;
  try {
    rawLang = contentLanguagePreference;
  } catch (_) {}
  rawLang ??= 'en';
  final prefLang = artistLanguageCodeToName[rawLang] ?? rawLang;
  final cacheKey = 'dynamic_home_recent_recommendations_v2_$prefLang';

  if (!forceRefresh && Hive.isBoxOpen('cache')) {
    try {
      final cached = await getData('cache', cacheKey);
      if (cached is List && cached.isNotEmpty) {
        return cached.whereType<Map>().toList();
      }
    } catch (_) {}
  }

  final recent = (List.from(
    userRecentlyPlayed.value,
  )..shuffle()).take(4).toList();

  final futures = recent.map((songData) async {
    try {
      final ytid = songData['ytid']?.toString() ?? '';
      if (ytid.isNotEmpty) {
        try {
          final radioSongs = await ytMusicClient.music
              .getRadioSongs(ytid, limit: 5)
              .timeout(const Duration(seconds: 6));
          if (radioSongs.isNotEmpty) {
            return radioSongs.map((s) => returnSongLayout(0, s)).toList();
          }
        } catch (_) {}
      }

      // If radio for ytid was empty, search YouTube Music audio songs by artist/title
      final artist = songData['artist']?.toString() ?? '';
      final title = songData['title']?.toString() ?? '';
      if (artist.isNotEmpty || title.isNotEmpty) {
        try {
          final searchFallback = await ytMusicClient.music
              .searchSongs('$artist $title', limit: 5)
              .timeout(const Duration(seconds: 6));
          if (searchFallback.isNotEmpty) {
            return searchFallback
                .where((s) => s.id.value != ytid)
                .map((s) => returnSongLayout(0, s))
                .toList();
          }
        } catch (_) {}
      }
      return <Map>[];
    } catch (e, stackTrace) {
      logger.log(
        'Error getting recommendations for ${songData['ytid']}',
        error: e,
        stackTrace: stackTrace,
      );
      return <Map>[];
    }
  }).toList();

  final results = await Future.wait(futures);
  final playlistSongs = results.expand((list) => list).take(20).toList()
    ..shuffle();

  if (playlistSongs.isNotEmpty && Hive.isBoxOpen('cache')) {
    unawaited(addOrUpdateData('cache', cacheKey, playlistSongs));
  }

  return playlistSongs;
}

Future<List> _getRecommendationsFromMixedSources({
  bool forceRefresh = false,
}) async {
  String? rawLang;
  try {
    rawLang = contentLanguagePreference;
  } catch (_) {}
  rawLang ??= 'en';
  final prefLang = artistLanguageCodeToName[rawLang] ?? rawLang;

  final cacheKey = 'dynamic_home_recommended_songs_v4_$prefLang';
  var liveSongs = <Map>[];

  if (!forceRefresh && Hive.isBoxOpen('cache')) {
    try {
      final cached = await getData('cache', cacheKey);
      if (cached is List && cached.isNotEmpty) {
        liveSongs = cached.whereType<Map>().toList();
      }
    } catch (_) {}
  }

  if (liveSongs.isEmpty) {
    try {
      // 1. If non-English, prioritize official YouTube Music Language Category featured hitlist and songs shelf
      if (prefLang.toLowerCase() != 'english') {
        final catShelves = await getLanguageCategoryShelves(
          prefLang,
          forceRefresh: forceRefresh,
        );

        // A. Primary: Fetch tracks from official Language Hitlist / Hot Hits playlist
        final featured = catShelves['featuredPlaylists'] ?? const [];
        final hitlist = featured.firstWhere(
          (pl) {
            final t = pl['title']?.toString().toLowerCase() ?? '';
            return t.contains('hitlist') ||
                t.contains('hot hits') ||
                t.contains('top') ||
                t.contains('hits') ||
                t.contains('best');
          },
          orElse: () =>
              featured.isNotEmpty ? featured.first : const <String, dynamic>{},
        );

        final hitlistId = hitlist['ytid']?.toString();
        if (hitlistId != null && hitlistId.isNotEmpty) {
          try {
            final plData = await ytMusicClient.music
                .getPlaylist(hitlistId)
                .timeout(const Duration(seconds: 8));
            for (final (index, track) in plData.tracks.indexed) {
              liveSongs.add(returnSongLayout(index, track));
              if (liveSongs.length >= 20) break;
            }
          } catch (_) {}
        }

        // B. Secondary: Supplement with official Songs shelf from the category page
        if (liveSongs.length < 20) {
          final catSongs = catShelves['songs'] ?? const [];
          for (final s in catSongs) {
            final ytid = s['ytid']?.toString() ?? '';
            if (ytid.isEmpty || liveSongs.any((item) => item['ytid'] == ytid)) {
              continue;
            }
            final rawThumb = s['image']?.toString();
            final highRes = rawThumb != null
                ? formatArtworkResolution(rawThumb, 1080)
                : null;
            final lowRes = rawThumb != null
                ? formatArtworkResolution(rawThumb, 544)
                : null;
            liveSongs.add({
              'id': liveSongs.length,
              'ytid': ytid,
              'title': formatSongTitle(s['title']?.toString() ?? ''),
              'artist': s['artist']?.toString() ?? '',
              'artistId': s['artistId']?.toString() ?? '',
              'videoAuthor': s['artist']?.toString() ?? '',
              'image':
                  highRes ?? 'https://i.ytimg.com/vi/$ytid/maxresdefault.jpg',
              'lowResImage':
                  lowRes ?? 'https://i.ytimg.com/vi/$ytid/mqdefault.jpg',
              'highResImage':
                  highRes ?? 'https://i.ytimg.com/vi/$ytid/maxresdefault.jpg',
              'duration': s['duration'],
              'isLive': false,
            });
            if (liveSongs.length >= 20) break;
          }
        }
      }

      // 2. Pure YouTube Music audio search for language top hits
      if (liveSongs.length < 20) {
        final searchQueries = prefLang.toLowerCase() == 'english'
            ? const ['Today Hits', 'Top Hits']
            : ['$prefLang Hits', '$prefLang Top Songs', 'Trending $prefLang'];

        for (final query in searchQueries) {
          if (liveSongs.length >= 20) break;
          try {
            final songs = await ytMusicClient.music
                .searchSongs(query, limit: 20)
                .timeout(const Duration(seconds: 8));
            for (final song in songs) {
              if (!liveSongs.any((s) => s['ytid'] == song.id.value)) {
                liveSongs.add(returnSongLayout(liveSongs.length, song));
                if (liveSongs.length >= 20) break;
              }
            }
          } catch (_) {}
        }
      }

      if (liveSongs.isNotEmpty && Hive.isBoxOpen('cache')) {
        unawaited(addOrUpdateData('cache', cacheKey, liveSongs));
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error fetching dynamic recommended songs for $prefLang:',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // Live curated language songs are the primary recommendations
  final recommendedSongs = <Map>[...liveSongs];

  if (recommendedSongs.isEmpty) {
    // Offline / network failure fallback: Use user liked songs and custom playlists
    if (userLikedSongsList.value.isNotEmpty) {
      recommendedSongs.addAll(userLikedSongsList.value.whereType<Map>());
    }
    if (userCustomPlaylists.value.isNotEmpty) {
      for (final userPlaylist in userCustomPlaylists.value) {
        final list = List.from(userPlaylist['list'] as List? ?? const [])
          ..shuffle();
        recommendedSongs.addAll(list.take(5).whereType<Map>());
      }
    }
  }

  return _deduplicateAndShuffle(recommendedSongs);
}

List _deduplicateAndShuffle(List playlistSongs) {
  final seenYtIds = <String>{};
  final uniqueSongs = <Map>[];

  playlistSongs.shuffle();

  for (final song in playlistSongs) {
    if (song['ytid'] != null && seenYtIds.add(song['ytid'])) {
      uniqueSongs.add(song);
      // Early exit when we have enough songs for 5 columns of 4 songs (20 total)
      if (uniqueSongs.length >= 20) break;
    }
  }

  return uniqueSongs;
}

Timer? _likedSongsDebounceTimer;

void _saveLikedSongsDebounced() {
  _likedSongsDebounceTimer?.cancel();
  _likedSongsDebounceTimer = Timer(const Duration(milliseconds: 350), () {
    unawaited(
      addOrUpdateData<List>('user', 'likedSongs', userLikedSongsList.value),
    );
  });
}

Future<void> updateSongLikeStatus(
  dynamic songId,
  bool add, {
  Map? songData,
}) async {
  try {
    final normalizedSongId = songId?.toString().trim() ?? '';
    if (normalizedSongId.isEmpty || normalizedSongId == 'null') return;

    final updateToken = ++_songLikeUpdateToken;
    _latestSongLikeUpdateTokens[normalizedSongId] = updateToken;

    final songToAdd = add
        ? await _resolveSongForLikedStatus(normalizedSongId, songData)
        : null;

    if (_latestSongLikeUpdateTokens[normalizedSongId] != updateToken) {
      return;
    }

    final updatedLikedSongs = _deduplicateLikedSongs(userLikedSongsList.value);

    if (add) {
      if (songToAdd != null &&
          !updatedLikedSongs.any(
            (song) =>
                (song['ytid']?.toString() ?? song['id']?.toString()) ==
                normalizedSongId,
          )) {
        updatedLikedSongs.insert(0, songToAdd);
      }
    } else {
      updatedLikedSongs.removeWhere(
        (song) =>
            (song['ytid']?.toString() ?? song['id']?.toString()) ==
            normalizedSongId,
      );
    }

    if (_likedSongIdsAreEqual(userLikedSongsList.value, updatedLikedSongs)) {
      return;
    }

    userLikedSongsList.value = updatedLikedSongs;
    _saveLikedSongsDebounced();
  } catch (e, stackTrace) {
    logger.log(
      'Error updating song like status',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

Future<Map?> _resolveSongForLikedStatus(String songId, Map? songData) async {
  if (songData != null) {
    final sYtid = songData['ytid']?.toString();
    final sId = songData['id']?.toString();
    if (sYtid == songId || sId == songId) {
      final map = Map<String, dynamic>.from(songData);
      map['ytid'] ??= songId;
      return map;
    }
  }

  final cachedSong = _findSongById(userLikedSongsList.value, songId);
  if (cachedSong != null) return Map<String, dynamic>.from(cachedSong);

  final recentsSong = _findSongById(userRecentlyPlayed.value, songId);
  if (recentsSong != null) return Map<String, dynamic>.from(recentsSong);

  final offlineSong = _findSongById(userOfflineSongs.value, songId);
  if (offlineSong != null) return Map<String, dynamic>.from(offlineSong);

  final localSong = _findSongById(userLocalSongs.value, songId);
  if (localSong != null) return Map<String, dynamic>.from(localSong);

  try {
    return await getSongDetails(userLikedSongsList.value.length, songId);
  } catch (_) {
    if (songData != null) {
      final fallback = Map<String, dynamic>.from(songData);
      fallback['ytid'] ??= songId;
      return fallback;
    }
    return null;
  }
}

Map? _findSongById(Iterable<dynamic> songs, String songId) {
  for (final song in songs) {
    if (song is Map) {
      final id = song['ytid']?.toString() ?? song['id']?.toString();
      if (id == songId) return song;
    }
  }

  return null;
}

List _deduplicateLikedSongs(Iterable<dynamic> likedSongs) {
  final seenSongIds = <String>{};
  final deduplicatedSongs = [];

  for (final song in likedSongs) {
    if (song is! Map) {
      deduplicatedSongs.add(song);
      continue;
    }

    final songId = song['ytid']?.toString() ?? song['id']?.toString();
    if (songId == null || songId.isEmpty) {
      deduplicatedSongs.add(song);
      continue;
    }

    if (seenSongIds.add(songId)) {
      deduplicatedSongs.add(song);
    }
  }

  return deduplicatedSongs;
}

bool _likedSongIdsAreEqual(List previous, List updated) {
  if (previous.length != updated.length) return false;

  for (var i = 0; i < previous.length; i++) {
    final previousSong = previous[i];
    final updatedSong = updated[i];
    if (previousSong is! Map || updatedSong is! Map) {
      if (previousSong != updatedSong) return false;
      continue;
    }

    final prevId =
        previousSong['ytid']?.toString() ?? previousSong['id']?.toString();
    final updatedId =
        updatedSong['ytid']?.toString() ?? updatedSong['id']?.toString();
    if (prevId != updatedId) {
      return false;
    }
  }

  return true;
}

Future<void> renameSongInLikedSongs(
  dynamic songId,
  String newTitle,
  String newArtist,
) async {
  try {
    final targetId = songId?.toString();
    final songIndex = userLikedSongsList.value.indexWhere((song) {
      if (song is! Map) return false;
      final id = song['ytid']?.toString() ?? song['id']?.toString();
      return id == targetId;
    });

    if (songIndex != -1) {
      final updatedList = List.from(userLikedSongsList.value);
      updatedList[songIndex] = Map.from(updatedList[songIndex] as Map)
        ..['title'] = newTitle
        ..['artist'] = newArtist;
      userLikedSongsList.value = updatedList;

      unawaited(
        addOrUpdateData<List>('user', 'likedSongs', userLikedSongsList.value),
      );
    }
  } catch (e, stackTrace) {
    logger.log(
      'Error renaming song in liked songs',
      error: e,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

bool isSongAlreadyLiked(dynamic songIdToCheck) {
  final songId = songIdToCheck?.toString().trim();
  if (songId == null || songId.isEmpty || songId == 'null') return false;
  return userLikedSongsList.value.any((song) {
    if (song is! Map) return false;
    final id = song['ytid']?.toString() ?? song['id']?.toString();
    return id == songId;
  });
}

bool isPlaylistAlreadyLiked(dynamic playlistIdToCheck) {
  final playlistId = playlistIdToCheck?.toString().trim();
  if (playlistId == null || playlistId.isEmpty || playlistId == 'null') {
    return false;
  }
  return userLikedPlaylists.value.any((playlist) {
    final id = playlist['ytid']?.toString() ?? playlist['id']?.toString();
    return id == playlistId;
  });
}

bool isSongAlreadyOffline(dynamic songIdToCheck) {
  final id = songIdToCheck?.toString();
  if (id == null || id.isEmpty) return false;
  if (userLocalSongs.value.any((song) => song['ytid'] == id)) return true;
  return userOfflineSongs.value.any((song) {
    if (song is! Map || song['ytid']?.toString() != id) return false;
    final path = song['audioPath'] ?? song['localPath'];
    if (path == null) return false;
    return File(path.toString()).existsSync();
  });
}

bool isPlaylistFullyOffline(List songs) {
  if (songs.isEmpty) return false;
  final offlineIds = {
    ...userOfflineSongs.value.map((s) => s['ytid']),
    ...userLocalSongs.value.map((s) => s['ytid']),
  };
  return songs.every((s) => offlineIds.contains(s['ytid']));
}

Map<String, dynamic> getOfflineSongByYtid(String ytid) {
  try {
    final song = userOfflineSongs.value.firstWhere(
      (s) => s['ytid'] == ytid,
      orElse: () => userLocalSongs.value.firstWhere(
        (s) => s['ytid'] == ytid,
        orElse: () => <String, dynamic>{},
      ),
    );
    return Map<String, dynamic>.from(song);
  } catch (_) {
    return <String, dynamic>{};
  }
}

Future<List<String>> getSearchSuggestions(String query) async {
  try {
    final ytmSuggestions = await ytMusicClient.music
        .getSearchSuggestions(query)
        .timeout(const Duration(seconds: 4));
    return ytmSuggestions;
  } catch (e, stackTrace) {
    if (!isNetworkError(e)) {
      logger.log(
        'Error in getSearchSuggestions',
        error: e,
        stackTrace: stackTrace,
      );
    }
    return <String>[];
  }
}

Future<List<Map<String, int>>> getSkipSegments(String id) async {
  try {
    final res = await ProxyManager()
        .getProxiedResponse(
          Uri(
            scheme: 'https',
            host: 'sponsor.ajay.app',
            path: '/api/skipSegments',
            queryParameters: {
              'videoID': id,
              'category': [
                'sponsor',
                'selfpromo',
                'interaction',
                'intro',
                'outro',
                'music_offtopic',
              ],
              'actionType': 'skip',
            },
          ),
          // SponsorBlock is optional metadata and must not delay playback startup.
          // Fall back to the unmodified source when the service is slow or unavailable.
        )
        .timeout(const Duration(seconds: 2));
    if (res.statusCode == 200 && res.body != 'Not Found') {
      final data = jsonDecode(res.body);
      final segments = data.map((obj) {
        return Map.castFrom<String, dynamic, String, int>({
          'start': obj['segment'].first.toInt(),
          'end': obj['segment'].last.toInt(),
        });
      }).toList();
      return List.castFrom<dynamic, Map<String, int>>(segments);
    } else {
      return [];
    }
  } on TimeoutException {
    logger.log(
      '[SPONSORBLOCK] skip segment request timed out; continuing without skips',
    );
    return <Map<String, int>>[];
  } catch (e, stackTrace) {
    logger.log('Error in getSkipSegments', error: e, stackTrace: stackTrace);
    return [];
  }
}

Future<void> getSimilarSong(String songYtId) async {
  try {
    var radioSongs = <Video>[];
    try {
      radioSongs = await ytMusicClient.music
          .getRadioSongs(songYtId, limit: 10)
          .timeout(const Duration(seconds: 6));
    } catch (e, stackTrace) {
      logger.log(
        'Error in ytMusicClient.getRadioSongs for $songYtId',
        error: e,
        stackTrace: stackTrace,
      );
    }

    if (radioSongs.isNotEmpty) {
      nextRecommendedSong = returnSongLayout(0, radioSongs[0]);
      return;
    }

    // Exclusively query YouTube Music audio songs if radio is empty
    // (strictly avoid ytClient.videos.getRelatedVideos)
    try {
      final currentSong = getOfflineSongByYtid(songYtId);
      final artist = currentSong['artist']?.toString() ?? '';
      final title = currentSong['title']?.toString() ?? '';
      final query = artist.isNotEmpty ? artist : title;
      if (query.isNotEmpty) {
        final fallbackSongs = await ytMusicClient.music
            .searchSongs(query, limit: 5)
            .timeout(const Duration(seconds: 5));
        if (fallbackSongs.isNotEmpty) {
          final candidate = fallbackSongs.firstWhere(
            (s) => s.id.value != songYtId,
            orElse: () => fallbackSongs.first,
          );
          nextRecommendedSong = returnSongLayout(0, candidate);
          return;
        }
      }
    } catch (_) {}

    logger.log('No similar YouTube Music audio songs found for $songYtId');
  } catch (e, stackTrace) {
    logger.log(
      'Error while fetching next similar song:',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

/// Fetches the best available audio stream for a song.
Future<AudioOnlyStreamInfo?> fetchBestAudioStream(String? songId) async {
  try {
    if (songId == null || songId.isEmpty) {
      logger.log('fetchBestAudioStream: songId is null or empty');
      return null;
    }

    final manifest = await _fetchStreamManifest(songId);
    final audioStream = manifest?.audioOnly;
    if (audioStream == null || audioStream.isEmpty) {
      logger.log('fetchBestAudioStream: no audio streams for $songId');
      return null;
    }
    return selectAudioOnlyStreamForQuality(audioStream.sortByBitrate());
  } on TimeoutException catch (_) {
    logger.log('fetchBestAudioStream request timed out for $songId');
    return null;
  } catch (e, stackTrace) {
    logger.log(
      'Error while fetching best audio stream',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  }
}

/// Checks if a song or video title represents a video upload rather than an official audio release.
bool isVideoTrackTitle(String title) {
  final lower = title.toLowerCase();
  return lower.contains('official video') ||
      lower.contains('lyric video') ||
      lower.contains('music video') ||
      lower.contains('video song') ||
      lower.contains('full video') ||
      lower.contains('4k video') ||
      lower.contains('1080p') ||
      lower.contains('video') ||
      lower.contains('teaser') ||
      lower.contains('trailer') ||
      lower.contains('promo') ||
      lower.contains('mashup') ||
      lower.contains('jukebox');
}

/// Resolves a video ID or track to the official YouTube Music studio audio track ID.
Future<String> resolveOfficialAudioYtId(
  String ytid, {
  String? title,
  String? artist,
}) async {
  if (ytid.isEmpty) return ytid;

  // 1. Check persistent cache
  // Version the mapping because older releases accepted the first search
  // result, which could point a common title at the wrong recording.
  final cacheKey = 'official_audio_ytid_v2_$ytid';
  if (Hive.isBoxOpen('cache')) {
    try {
      final cached = await getData('cache', cacheKey);
      if (cached is String && cached.isNotEmpty) {
        return cached;
      }
    } catch (_) {}
  }

  // 2. If title or artist is empty, fetch video details from client
  var songTitle = title ?? '';
  var songArtist = artist ?? '';

  if (songTitle.isEmpty || songArtist.isEmpty) {
    try {
      final video = await ProxyManager()
          .getClientSync()
          .videos
          .get(ytid)
          .timeout(const Duration(seconds: 4));
      if (video.musicData.isNotEmpty) {
        // Already an official YouTube Music track!
        if (Hive.isBoxOpen('cache')) {
          unawaited(addOrUpdateData<String>('cache', cacheKey, ytid));
        }
        return ytid;
      }
      songTitle = video.title;
      songArtist = video.author;
    } catch (_) {
      return ytid;
    }
  }

  // 3. Search YouTube Music's official Songs shelf
  try {
    final cleanTitle = formatSongTitle(songTitle);
    final cleanArtist = songArtist
        .replaceAll(RegExp('[,&|/].*'), '')
        .replaceAll(RegExp('vevo', caseSensitive: false), '')
        .replaceAll(
          RegExp(
            r'\b(channel|music|records|audio|official)\b',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    final query =
        cleanArtist.isNotEmpty &&
            !cleanTitle.toLowerCase().contains(cleanArtist.toLowerCase())
        ? '$cleanTitle $cleanArtist'
        : cleanTitle;

    if (query.isNotEmpty) {
      final officialSong = await ytMusicClient.music
          .searchSong(
            query,
            expectedArtist: cleanArtist.isNotEmpty ? cleanArtist : null,
            expectedTitle: cleanTitle.isNotEmpty ? cleanTitle : null,
          )
          .timeout(const Duration(seconds: 5));

      if (officialSong != null) {
        final officialId = officialSong.id.value;
        if (Hive.isBoxOpen('cache')) {
          unawaited(addOrUpdateData<String>('cache', cacheKey, officialId));
        }
        return officialId;
      }
    }
  } catch (_) {}

  // Fallback to original ytid
  if (Hive.isBoxOpen('cache')) {
    unawaited(addOrUpdateData<String>('cache', cacheKey, ytid));
  }
  return ytid;
}

/// Resolves a playable stream URL for a song (cached when possible).
Future<String?> fetchSongStreamUrl(
  String songId,
  bool isLive, {
  String? title,
  String? artist,
}) async {
  final requestKey = [
    songId,
    if (isLive) 'live' else 'audio',
    title?.trim().toLowerCase() ?? '',
    artist?.trim().toLowerCase() ?? '',
    audioQualitySetting.value,
  ].join('|');
  final existing = _streamUrlInFlight[requestKey];
  if (existing != null) {
    logger.log('[PLAYER_STREAM] coalesced=true ytid=$songId');
    return existing;
  }

  late final Future<String?> request;
  request = _fetchSongStreamUrl(songId, isLive, title: title, artist: artist)
      .whenComplete(() {
        if (identical(_streamUrlInFlight[requestKey], request)) {
          _streamUrlInFlight.remove(requestKey);
        }
      });
  _streamUrlInFlight[requestKey] = request;
  return request;
}

Future<String?> _fetchSongStreamUrl(
  String songId,
  bool isLive, {
  String? title,
  String? artist,
}) async {
  final stopwatch = Stopwatch()..start();
  try {
    if (songId.isEmpty) {
      logger.log('fetchSongStreamUrl: songId is empty');
      return null;
    }

    final targetSongId = isLive
        ? songId
        : await resolveOfficialAudioYtId(songId, title: title, artist: artist);
    final officialResolveMs = stopwatch.elapsedMilliseconds;

    if (isLive) {
      final streamInfo = await ytClient.videos.streamsClient
          .getHttpLiveStreamUrl(VideoId(targetSongId));
      logger.log(
        '[PLAYER_STREAM] ytid=$songId mode=live resolve_ms=$officialResolveMs total_ms=${stopwatch.elapsedMilliseconds}',
      );
      return streamInfo;
    }

    const _cacheDuration = Duration(hours: 3);
    final cacheKey = 'song_${targetSongId}_${audioQualitySetting.value}_url';

    // Try to get from cache
    final cachedUrl = await _getCachedSongUrl(cacheKey, _cacheDuration);
    if (cachedUrl != null) {
      logger.log(
        '[PLAYER_STREAM] ytid=$songId mode=audio cache_hit=true resolve_ms=$officialResolveMs total_ms=${stopwatch.elapsedMilliseconds}',
      );
      return cachedUrl;
    }

    // Get fresh URL
    final manifest = await _fetchStreamManifest(targetSongId);
    final audioStreams = manifest?.audioOnly;
    if (audioStreams == null || audioStreams.isEmpty) {
      logger.log('fetchSongStreamUrl: no audio streams for $targetSongId');
      return null;
    }

    final selectedStream = selectAudioOnlyStreamForQuality(
      audioStreams.sortByBitrate(),
    );
    final url = selectedStream.url.toString();

    unawaited(addOrUpdateData<String>('cache', cacheKey, url));

    logger.log(
      '[PLAYER_STREAM] ytid=$songId mode=audio cache_hit=false resolve_ms=$officialResolveMs manifest_ms=${stopwatch.elapsedMilliseconds - officialResolveMs} total_ms=${stopwatch.elapsedMilliseconds}',
    );
    return url;
  } on TimeoutException catch (_) {
    logger.log('fetchSongStreamUrl request timed out for $songId');
    return null;
  } catch (e, stackTrace) {
    logger.log(
      'Error in fetchSongStreamUrl for $songId:',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  }
}

Future<Map<String, dynamic>> getSongDetails(
  int songIndex,
  String songId,
) async {
  try {
    try {
      final ytmSong = await ytMusicClient.music
          .getSong(songId)
          .timeout(const Duration(seconds: 5));
      if (ytmSong != null) {
        return returnSongLayout(songIndex, ytmSong);
      }
    } catch (_) {}

    final song = await ytClient.videos.get(songId);
    if (song.musicData.isNotEmpty) {
      return returnSongLayout(songIndex, song);
    }

    // If it's a video without official musicData, resolve to the official YouTube Music audio song
    try {
      final cleanTitle = formatSongTitle(song.title);
      final query = cleanTitle.isNotEmpty
          ? '$cleanTitle ${song.author}'
          : song.title;
      final officialSongs = await ytMusicClient.music
          .searchSongs(query, limit: 3)
          .timeout(const Duration(seconds: 5));
      if (officialSongs.isNotEmpty) {
        return returnSongLayout(songIndex, officialSongs.first);
      }
    } catch (_) {}

    return returnSongLayout(songIndex, song);
  } catch (e, stackTrace) {
    logger.log(
      'Error while getting song details',
      error: e,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

Future<String?> _fetchLyricsFromManager(
  String artist,
  String title, {
  int? duration,
  String? ytid,
}) {
  return LyricsManager().fetchLyrics(
    artist,
    title,
    duration: duration,
    ytid: ytid,
  );
}

Future<String?> getSongLyrics(
  String? artist,
  String title, {
  int? duration,
  String? ytid,
}) async {
  final currentRequestId = ++_latestLyricsRequestId;
  final safeArtist = artist ?? '';
  final effectiveDuration = (duration != null && duration > 0)
      ? duration
      : null;
  final effectiveYtid = (ytid != null && ytid.isNotEmpty) ? ytid : null;
  final requestKey = effectiveYtid != null
      ? 'ytid_$effectiveYtid'
      : '$safeArtist - $title - ${effectiveDuration ?? 0}';

  // --- Hive persistent cache ---
  // Prefer canonical ytid key when available, fallback to artist|title|duration
  final ytidCacheKey = effectiveYtid != null
      ? 'lyrics_ytid_$effectiveYtid'
      : null;
  final fallbackCacheKey =
      'lyricsData_${safeArtist}_${title}_${effectiveDuration ?? 0}'.replaceAll(
        RegExp(r'[^\w]'),
        '_',
      );
  final lyricsBox = Hive.isBoxOpen('lyricsCache')
      ? Hive.box('lyricsCache')
      : await Hive.openBox('lyricsCache');
  dynamic cached = ytidCacheKey != null ? lyricsBox.get(ytidCacheKey) : null;
  cached ??= lyricsBox.get(fallbackCacheKey);

  String? plainFallback;
  if (cached is String && cached.isNotEmpty) {
    // Only permanently accept cached lyrics if they are synchronized.
    // If plain lyrics were previously cached (e.g. from an earlier network drop
    // or unrefined search), use them as fallback but attempt to fetch fresh
    // synced lyrics so songs are not permanently stuck without highlighting.
    if (LrcParser.isSynced(cached)) {
      lyrics.value = cached;
      lastFetchedLyrics = requestKey;
      return cached;
    }
    plainFallback = cached;
  }

  if (lastFetchedLyrics != requestKey) {
    _latestLyricsRequest = requestKey;
    lyrics.value = plainFallback;
    final inFlight = _lyricsInFlight[requestKey];
    late final Future<String?> lyricsFuture;
    if (inFlight != null) {
      lyricsFuture = inFlight;
    } else {
      lyricsFuture = _fetchLyricsFromManager(
        safeArtist,
        title,
        duration: effectiveDuration,
        ytid: effectiveYtid,
      );
      // The pending future is intentionally retained for request coalescing.
      // ignore: unawaited_futures
      _lyricsInFlight[requestKey] = lyricsFuture;
    }
    String? _lyrics;
    try {
      _lyrics = await lyricsFuture;
    } finally {
      if (identical(_lyricsInFlight[requestKey], lyricsFuture)) {
        unawaited(_lyricsInFlight.remove(requestKey));
      }
    }

    // A newer lyrics request superseded this one (e.g. user skipped
    // tracks while this fetch was in flight) - discard the stale result.
    if (_latestLyricsRequestId != currentRequestId ||
        _latestLyricsRequest != requestKey) {
      return null;
    }

    if (_lyrics != null) {
      if (!LrcParser.isSynced(_lyrics)) {
        _lyrics = _lyrics.replaceAll(RegExp(r'\n{4}'), '\n\n');
        _lyrics = _lyrics.replaceAll(RegExp(r'\n{2}'), '\n');
      }
      lyrics.value = _lyrics;
      // Persist to Hive cache — always save synced lyrics or new plain fallback
      if (ytidCacheKey != null) {
        unawaited(lyricsBox.put(ytidCacheKey, _lyrics));
      }
      unawaited(lyricsBox.put(fallbackCacheKey, _lyrics));
    } else if (plainFallback != null) {
      lyrics.value = plainFallback;
      lastFetchedLyrics = requestKey;
      return plainFallback;
    } else {
      return null;
    }

    lastFetchedLyrics = requestKey;
    return _lyrics;
  }

  return lyrics.value ?? plainFallback;
}

Future<bool> makeSongOffline(dynamic song) async {
  return DownloadManager.instance.downloadSong(song);
}

Future<bool> removeSongFromOffline(dynamic songId) async {
  if (songId == null) return false;
  return DownloadManager.instance.deleteSongDownload(songId.toString());
}

const recentlyPlayedSongsLimit = 100;

/// Updates the recently played list and listening count for [songId].
///
/// When [songFallback] is provided, its metadata is used to seed the history
/// entry if the song has never been played before. This avoids a network
/// request when registering offline songs whose metadata is already available
/// locally (e.g. from [userOfflineSongs]).
Future<void> updateRecentlyPlayed(dynamic songId, {Map? songFallback}) async {
  try {
    if (userRecentlyPlayed.value.isNotEmpty &&
        userRecentlyPlayed.value[0]['ytid'] == songId) {
      final updatedList = List.from(userRecentlyPlayed.value);
      final existing = Map.from(updatedList[0] as Map);
      existing['listeningCount'] = (existing['listeningCount'] ?? 0) + 1;
      existing['lastPlayed'] = DateTime.now();
      updatedList[0] = existing;
      userRecentlyPlayed.value = updatedList;
      unawaited(
        addOrUpdateData<List>(
          'user',
          'recentlyPlayedSongs',
          userRecentlyPlayed.value,
        ),
      );
      return;
    }

    final existingIndex = userRecentlyPlayed.value.indexWhere(
      (song) => song['ytid'] == songId,
    );

    final updatedList = List.from(userRecentlyPlayed.value);

    if (existingIndex == -1 && updatedList.length >= recentlyPlayedSongsLimit) {
      updatedList.removeLast();
    }

    if (existingIndex != -1) {
      final song = Map.from(updatedList.removeAt(existingIndex) as Map);
      song['listeningCount'] = (song['listeningCount'] ?? 0) + 1;
      song['lastPlayed'] = DateTime.now();
      updatedList.insert(0, song);
    } else {
      final newSongDetails = songFallback != null
          ? Map<String, dynamic>.from(songFallback)
          : await getSongDetails(0, songId);
      newSongDetails['listeningCount'] = 1;
      newSongDetails['lastPlayed'] = DateTime.now();
      updatedList.insert(0, newSongDetails);
    }

    userRecentlyPlayed.value = updatedList;
    unawaited(
      addOrUpdateData<List>(
        'user',
        'recentlyPlayedSongs',
        userRecentlyPlayed.value,
      ),
    );
  } catch (e, stackTrace) {
    logger.log(
      'Error updating recently played',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

Future<void> removeFromRecentlyPlayed(dynamic songId) async {
  if (userRecentlyPlayed.value.any((song) => song['ytid'] == songId)) {
    userRecentlyPlayed.value = List.from(userRecentlyPlayed.value)
      ..removeWhere((song) => song['ytid'] == songId);
    unawaited(
      addOrUpdateData<List>(
        'user',
        'recentlyPlayedSongs',
        userRecentlyPlayed.value,
      ),
    );
  }
}

const Set<String> _localAudioExtensions = {
  'mp3',
  'm4a',
  'aac',
  'flac',
  'wav',
  'ogg',
  'opus',
};

class LocalScanReport {
  LocalScanReport({
    required this.paths,
    required this.missingFolders,
    required this.contentUriFolders,
    required this.errorFolders,
  });

  final List<String> paths;
  final int missingFolders;
  final int contentUriFolders;
  final int errorFolders;

  int get found => paths.length;
}

bool _isSupportedLocalAudio(String path) {
  final lower = path.toLowerCase();
  final dotIndex = lower.lastIndexOf('.');
  if (dotIndex == -1 || dotIndex == lower.length - 1) {
    return false;
  }
  final ext = lower.substring(dotIndex + 1);
  return _localAudioExtensions.contains(ext);
}

Map<String, dynamic> buildLocalSongFromPath(String path) {
  final fileName = _localBasename(path);
  final baseName = _stripAudioExtension(fileName);
  final parsed = _splitArtistTitle(baseName);

  return {
    'id': path,
    'ytid': path,
    'title': parsed.title,
    'artist': parsed.artist.isEmpty ? 'Local Audio' : parsed.artist,
    'lowResImage': '',
    'highResImage': '',
    'audioPath': path,
    'artworkPath': null,
    'isOffline': true,
    'isLocal': true,
    'source': 'local',
    'dateAdded': DateTime.now().millisecondsSinceEpoch,
  };
}

Future<LocalScanReport> refreshLocalSongsFromFolders(
  List<String> folders,
) async {
  final report = await scanLocalMusicFolders(folders);
  final updatedSongs = report.paths.map(buildLocalSongFromPath).toList();

  userLocalSongs.value = updatedSongs;
  await addOrUpdateData('userNoBackup', 'localSongs', userLocalSongs.value);
  logger.log(
    'Local scan complete: found=${report.found}, missing=${report.missingFolders}, contentUri=${report.contentUriFolders}, errors=${report.errorFolders}',
  );
  return report;
}

Future<LocalScanReport> scanLocalMusicFolders(List<String> folders) async {
  final seen = <String>{};
  var missingFolders = 0;
  var contentUriFolders = 0;
  var errorFolders = 0;

  for (final folder in folders) {
    try {
      if (folder.trim().isEmpty) {
        continue;
      }
      if (folder.startsWith('content://')) {
        contentUriFolders++;
        logger.log(
          'Local music folder is content:// uri; cannot scan with dart:io',
        );
        continue;
      }
      final dir = Directory(folder);
      if (!await dir.exists()) {
        missingFolders++;
        logger.log('Local music folder not found: $folder');
        continue;
      }

      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) {
          continue;
        }
        final path = entity.path;
        if (_isSupportedLocalAudio(path)) {
          seen.add(path);
        }
      }
    } catch (e, stackTrace) {
      errorFolders++;
      logger.log(
        'Error scanning local folder $folder',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  final results = seen.toList()..sort();
  return LocalScanReport(
    paths: results,
    missingFolders: missingFolders,
    contentUriFolders: contentUriFolders,
    errorFolders: errorFolders,
  );
}

String _localBasename(String path) {
  final separator = Platform.pathSeparator;
  final parts = path.split(separator);
  return parts.isNotEmpty ? parts.last : path;
}

String _stripAudioExtension(String fileName) {
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex <= 0) return fileName;
  return fileName.substring(0, dotIndex);
}

({String title, String artist}) _splitArtistTitle(String fileName) {
  final parts = fileName.split(' - ');
  if (parts.length >= 2) {
    final artist = parts.first.trim();
    final title = parts.sublist(1).join(' - ').trim();
    return (title: title, artist: artist);
  }
  return (title: fileName.trim(), artist: '');
}
