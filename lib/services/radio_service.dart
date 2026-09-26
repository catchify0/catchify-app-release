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

import 'package:catchify/main.dart' show logger;
import 'package:catchify/services/artist_service.dart' show ytMusicClient;
import 'package:catchify/utilities/formatter.dart' show returnSongLayout;
import 'package:catchify/utilities/queue_entry_utils.dart' show canonicalSongId;
import 'package:youtube_music_explode_dart/youtube_music_explode_dart.dart';

enum RadioType { song, artist, album }

/// Holds memory-scoped state for an active radio / automix session.
class RadioSession {
  RadioSession({
    required this.seedId,
    required this.seedTitle,
    required this.type,
    this.playlistId,
    this.continuationToken,
    Set<String>? seenTrackIds,
  }) : seenTrackIds = seenTrackIds ?? <String>{};

  final String seedId;
  final String seedTitle;
  final RadioType type;
  final String? playlistId;
  String? continuationToken;
  final Set<String> seenTrackIds;

  @override
  String toString() =>
      'RadioSession(seedId: $seedId, seedTitle: "$seedTitle", type: $type, playlistId: $playlistId, hasContinuation: ${continuationToken != null})';
}

/// Service supplying YouTube Music radio and automix data.
///
/// Pure data provider: fetches tracks, tracks continuation tokens,
/// and deduplicates. Does NOT own playback or audio player state.
class RadioService {
  RadioSession? _currentSession;

  RadioSession? get currentSession => _currentSession;

  /// Resets the memory-scoped radio session.
  void resetSession() {
    _currentSession = null;
  }

  /// Sets an explicit active radio session (e.g. for testing).
  void setSession(RadioSession? session) {
    _currentSession = session;
  }

  /// Fetches an algorithmic radio playlist for a single [seedSong].
  ///
  /// Uses YouTube Music's dedicated `RDAMVM<seedId>` automix endpoint.
  /// The seed song is always returned as the first track of the resulting list.
  Future<List<Map>> getRadioForSong(Map seedSong, {int limit = 25}) async {
    try {
      final ytid = canonicalSongId(seedSong) ?? '';
      if (ytid.isEmpty) {
        logger.log('[RADIO_ERROR] Cannot start song radio: missing song ID');
        return const [];
      }

      final playlistId = 'RDAMVM$ytid';
      final result = await ytMusicClient.music
          .getRadioTracks(videoId: ytid, playlistId: playlistId, limit: limit)
          .timeout(const Duration(seconds: 10));

      final seen = <String>{ytid};
      final convertedSongs = <Map>[];

      for (var i = 0; i < result.tracks.length; i++) {
        final v = result.tracks[i];
        final songMap = returnSongLayout(i + 1, v);
        final id = canonicalSongId(songMap);
        if (id != null && id.isNotEmpty && seen.add(id)) {
          convertedSongs.add(songMap);
        }
      }

      // Build full radio queue: [seedSong, ...convertedSongs]
      final radioQueue = <Map>[seedSong, ...convertedSongs];

      _currentSession = RadioSession(
        seedId: ytid,
        seedTitle: seedSong['title']?.toString() ?? '',
        type: RadioType.song,
        playlistId: playlistId,
        continuationToken: result.continuation,
        seenTrackIds: seen,
      );

      logger.log(
        '[RADIO] seed="$ytid" type=song initialItems=${radioQueue.length} hasContinuation=${result.continuation != null}',
      );

      return radioQueue;
    } catch (e, stackTrace) {
      logger.log(
        '[RADIO_ERROR] Failed fetching song radio for ${seedSong['title']}',
        error: e,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  /// Fetches an algorithmic radio station for an [artist].
  ///
  /// Uses the artist's `radioId` if provided, or `RDEM<channelId>`, or seeds
  /// from the artist's top tracks.
  Future<List<Map>> getRadioForArtist(
    Map artist, {
    List<Map>? fallbackSongs,
    int limit = 25,
  }) async {
    try {
      final artistName =
          artist['title']?.toString() ?? artist['name']?.toString() ?? '';
      final artistId = canonicalSongId(artist) ?? '';
      final explicitRadioId = artist['radioId']?.toString();

      String? targetPlaylistId;
      String? seedVideoId;

      if (explicitRadioId != null && explicitRadioId.isNotEmpty) {
        targetPlaylistId = explicitRadioId;
      } else if (artistId.startsWith('UC')) {
        targetPlaylistId = 'RDEM$artistId';
      } else if (fallbackSongs != null && fallbackSongs.isNotEmpty) {
        final firstSong = fallbackSongs.first;
        seedVideoId = canonicalSongId(firstSong);
      }

      MusicRadioResult? result;

      // 1. Try with playlistId if available
      if (targetPlaylistId != null) {
        try {
          result = await ytMusicClient.music
              .getRadioTracks(playlistId: targetPlaylistId, limit: limit)
              .timeout(const Duration(seconds: 10));
        } catch (e) {
          logger.log(
            '[RADIO] Artist playlistId ($targetPlaylistId) fetch failed, falling back',
            error: e,
          );
        }
      }

      // 2. Fallback to seed video if playlistId returned empty or failed
      if ((result == null || result.tracks.isEmpty) && seedVideoId != null) {
        try {
          result = await ytMusicClient.music
              .getRadioTracks(
                videoId: seedVideoId,
                playlistId: 'RDAMVM$seedVideoId',
                limit: limit,
              )
              .timeout(const Duration(seconds: 10));
        } catch (e) {
          logger.log(
            '[RADIO_ERROR] Artist seed video ($seedVideoId) fetch failed',
            error: e,
          );
        }
      }

      if (result == null || result.tracks.isEmpty) {
        // Final fallback: if fallbackSongs provided, return them directly
        if (fallbackSongs != null && fallbackSongs.isNotEmpty) {
          logger.log(
            '[RADIO] Using fallback top songs for artist: $artistName',
          );
          _currentSession = RadioSession(
            seedId: artistId.isNotEmpty ? artistId : artistName,
            seedTitle: artistName,
            type: RadioType.artist,
            seenTrackIds: fallbackSongs
                .map(canonicalSongId)
                .whereType<String>()
                .toSet(),
          );
          return List<Map>.from(fallbackSongs);
        }
        logger.log('[RADIO_ERROR] No tracks available for artist $artistName');
        return const [];
      }

      final seen = <String>{};
      final convertedSongs = <Map>[];

      for (var i = 0; i < result.tracks.length; i++) {
        final v = result.tracks[i];
        final songMap = returnSongLayout(i + 1, v);
        final id = canonicalSongId(songMap);
        if (id != null && id.isNotEmpty && seen.add(id)) {
          convertedSongs.add(songMap);
        }
      }

      _currentSession = RadioSession(
        seedId: artistId.isNotEmpty ? artistId : artistName,
        seedTitle: artistName,
        type: RadioType.artist,
        playlistId: targetPlaylistId,
        continuationToken: result.continuation,
        seenTrackIds: seen,
      );

      logger.log(
        '[RADIO] seed="$artistName" type=artist initialItems=${convertedSongs.length} hasContinuation=${result.continuation != null}',
      );

      return convertedSongs;
    } catch (e, stackTrace) {
      logger.log(
        '[RADIO_ERROR] Failed fetching artist radio for ${artist['title'] ?? artist['name']}',
        error: e,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  /// Fetches an algorithmic radio station seeded from an [album].
  ///
  /// Extracts the initial or selected track of the album to seed YouTube Music's
  /// Automix radio endpoint.
  Future<List<Map>> getRadioForAlbum(
    Map album, {
    List<Map>? albumSongs,
    int limit = 25,
  }) async {
    try {
      final albumTitle = album['title']?.toString() ?? 'Album';
      Map? seedSong;

      if (albumSongs != null && albumSongs.isNotEmpty) {
        seedSong = albumSongs.first;
      } else if (album['list'] is List && (album['list'] as List).isNotEmpty) {
        final firstItem = (album['list'] as List).first;
        if (firstItem is Map) {
          seedSong = firstItem;
        }
      }

      if (seedSong == null) {
        logger.log(
          '[RADIO_ERROR] Cannot start album radio: no seed song found in album',
        );
        return const [];
      }

      final radioQueue = await getRadioForSong(seedSong, limit: limit);

      if (_currentSession != null) {
        _currentSession = RadioSession(
          seedId: _currentSession!.seedId,
          seedTitle: albumTitle,
          type: RadioType.album,
          playlistId: _currentSession!.playlistId,
          continuationToken: _currentSession!.continuationToken,
          seenTrackIds: _currentSession!.seenTrackIds,
        );
      }

      logger.log(
        '[RADIO] seed="$albumTitle" type=album initialItems=${radioQueue.length}',
      );

      return radioQueue;
    } catch (e, stackTrace) {
      logger.log(
        '[RADIO_ERROR] Failed fetching album radio for ${album['title']}',
        error: e,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  /// Fetches additional radio tracks for the active radio session.
  ///
  /// Uses continuation tokens when available, falling back to seed-based
  /// recommendations. Automatically deduplicates against [existingQueueIds]
  /// and tracks already seen in this session.
  Future<List<Map>> getMoreRadioSongs({
    Set<String>? existingQueueIds,
    int limit = 15,
  }) async {
    final session = _currentSession;
    if (session == null) {
      logger.log('[AUTOPLAY] No active radio session to extend');
      return const [];
    }

    final songsToAdd = <Map>[];
    var duplicateSkipped = 0;
    final queueIds = existingQueueIds ?? const <String>{};

    try {
      MusicRadioResult? result;

      // 1. Prefer continuation token if present
      if (session.continuationToken != null &&
          session.continuationToken!.isNotEmpty) {
        try {
          result = await ytMusicClient.music
              .getRadioTracks(
                continuation: session.continuationToken,
                limit: limit,
              )
              .timeout(const Duration(seconds: 8));

          session.continuationToken = result.continuation;
        } catch (e) {
          logger.log(
            '[AUTOPLAY] Continuation fetch failed, attempting seed fallback',
            error: e,
          );
        }
      }

      // 2. If continuation produced no tracks, fallback to seed video query
      if ((result == null || result.tracks.isEmpty) &&
          session.seedId.isNotEmpty) {
        try {
          result = await ytMusicClient.music
              .getRadioTracks(
                videoId: session.seedId,
                playlistId: session.playlistId,
                limit: limit + 10,
              )
              .timeout(const Duration(seconds: 8));

          if (result.continuation != null) {
            session.continuationToken = result.continuation;
          }
        } catch (e) {
          logger.log(
            '[RADIO_ERROR] Autoplay seed fallback fetch failed for ${session.seedId}',
            error: e,
          );
        }
      }

      if (result != null && result.tracks.isNotEmpty) {
        for (var i = 0; i < result.tracks.length; i++) {
          final v = result.tracks[i];
          final sMap = returnSongLayout(i + 1, v);
          final sid = canonicalSongId(sMap);

          if (sid == null || sid.isEmpty) continue;

          // Reject if in current queue or already seen
          if (queueIds.contains(sid) || session.seenTrackIds.contains(sid)) {
            duplicateSkipped++;
            continue;
          }

          songsToAdd.add(sMap);
          session.seenTrackIds.add(sid);
          if (songsToAdd.length >= limit) break;
        }
      }

      // 3. If getRadioTracks still produced no tracks, fallback to getRadioSongs
      if (songsToAdd.isEmpty && session.seedId.isNotEmpty) {
        try {
          final fallbackVideos = await ytMusicClient.music
              .getRadioSongs(session.seedId, limit: limit)
              .timeout(const Duration(seconds: 8));
          if (fallbackVideos.isNotEmpty) {
            for (var i = 0; i < fallbackVideos.length; i++) {
              final sMap = returnSongLayout(i + 1, fallbackVideos[i]);
              final sid = canonicalSongId(sMap);
              if (sid == null || sid.isEmpty) continue;
              if (queueIds.contains(sid) ||
                  session.seenTrackIds.contains(sid)) {
                duplicateSkipped++;
                continue;
              }
              songsToAdd.add(sMap);
              session.seenTrackIds.add(sid);
              if (songsToAdd.length >= limit) break;
            }
          }
        } catch (e) {
          logger.log(
            '[RADIO_ERROR] getRadioSongs fallback failed for ${session.seedId}',
            error: e,
          );
        }
      }

      logger.log(
        '[AUTOPLAY] added=${songsToAdd.length} duplicateSkipped=$duplicateSkipped hasContinuation=${session.continuationToken != null}',
      );

      return songsToAdd;
    } catch (e, stackTrace) {
      logger.log(
        '[RADIO_ERROR] Failed extending radio queue',
        error: e,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}

/// Global singleton instance of [RadioService].
final RadioService radioService = RadioService();
