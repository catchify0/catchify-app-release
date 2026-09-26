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

import 'package:catchify/main.dart' show audioHandler;
import 'package:catchify/services/common_services.dart';
import 'package:catchify/services/playlist_download_service.dart';
import 'package:catchify/services/playlists_manager.dart';
import 'package:catchify/utilities/app_utils.dart';
import 'package:catchify/utilities/playlist_utils.dart';

/// Single Library Composer responsible for aggregating and normalizing local data
/// from Hive storage for Catchify Library 2.0.
///
/// It does NOT own playback state — all audio operations delegate directly
/// to [audioHandler] (CatchifyAudioHandler).
class LibraryService {
  LibraryService._();
  static final LibraryService instance = LibraryService._();

  /// Loads the canonical list of liked songs from local storage.
  List<dynamic> loadLikedSongs() {
    return List<dynamic>.from(userLikedSongsList.value);
  }

  /// Loads all user and saved playlists separated into folders, custom, and liked.
  Map<String, List<dynamic>> loadPlaylists({bool isOffline = false}) {
    final rawOfflinePlaylists = offlinePlaylistService.offlinePlaylists.value;
    final visibleOffline = rawOfflinePlaylists
        .where((p) => p is Map && !PlaylistUtils.isArtistPlaylist(p))
        .toList();

    final folders = isOffline
        ? userPlaylistFolders.value
              .where(PlaylistUtils.folderHasOfflinePlaylists)
              .toList()
        : userPlaylistFolders.value;

    final offlineNotInFolders =
        PlaylistUtils.filterOfflinePlaylistsNotInFolders(
          visibleOffline,
          folders,
        );

    final offlineIdsNotInFolders = PlaylistUtils.offlinePlaylistIdsNotInFolders(
      visibleOffline,
      folders,
    );

    final allNotInFolders = getPlaylistsNotInFolders();
    final customNotInFolders = PlaylistUtils.excludePlaylistsWithIds(
      allNotInFolders,
      offlineIdsNotInFolders,
    );

    final likedPlaylists = isOffline ? <Map>[] : getLikedPlaylistItems();

    return {
      'folders': folders,
      'customPlaylists': customNotInFolders,
      'offlinePlaylists': offlineNotInFolders,
      'likedPlaylists': likedPlaylists,
      'allPlaylistsNotInFolders': allNotInFolders,
    };
  }

  int _lastAlbumsLikedLength = -1;
  int _lastAlbumsPlaylistsLength = -1;
  int _lastAlbumsRecentLength = -1;
  List<Map<String, dynamic>> _cachedAlbums = const [];

  /// Derives album cards locally from liked playlists (marked as albums)
  /// and songs containing album metadata without making external API requests.
  List<Map<String, dynamic>> loadAlbums() {
    final likedLen = userLikedSongsList.value.length;
    final playlistsLen = userLikedPlaylists.value.length;
    final recentLen = userRecentlyPlayed.value.length;

    if (_lastAlbumsLikedLength == likedLen &&
        _lastAlbumsPlaylistsLength == playlistsLen &&
        _lastAlbumsRecentLength == recentLen &&
        _cachedAlbums.isNotEmpty) {
      return _cachedAlbums;
    }

    final seen = <String>{};
    final albums = <Map<String, dynamic>>[];

    // 1. Liked playlists that are tagged as albums
    for (final playlist in userLikedPlaylists.value) {
      if (playlist['isAlbum'] == true || playlist['type'] == 'album') {
        final title = playlist['title']?.toString().trim() ?? '';
        final id =
            playlist['ytid']?.toString().trim() ??
            playlist['id']?.toString().trim() ??
            '';
        final key = (id.isNotEmpty ? id : title).toLowerCase();
        if (title.isNotEmpty && seen.add(key)) {
          albums.add({
            'ytid': id,
            'title': title,
            'artist': getDisplayArtist(playlist),
            'image': playlist['highResImage'] ?? playlist['image'],
            'isAlbum': true,
            'isSingle': false,
            'year': playlist['year']?.toString() ?? '',
            'source': 'playlist-album',
          });
        }
      }
    }

    // 2. Songs in likedSongs that have explicit album information
    for (final song in userLikedSongsList.value) {
      if (song is Map) {
        final albumTitle = song['album']?.toString().trim() ?? '';
        final albumId = song['albumId']?.toString().trim() ?? '';
        final key = (albumId.isNotEmpty ? albumId : albumTitle).toLowerCase();
        if (albumTitle.isNotEmpty && seen.add(key)) {
          albums.add({
            'ytid': albumId,
            'title': albumTitle,
            'artist': getDisplayArtist(song),
            'image': song['highResImage'] ?? song['image'],
            'isAlbum': true,
            'isSingle': false,
            'year': song['year']?.toString() ?? '',
            'source': 'song-album',
          });
        }
      }
    }

    // 3. Songs in recentlyPlayed that have explicit album information
    for (final song in userRecentlyPlayed.value) {
      if (song is Map) {
        final albumTitle = song['album']?.toString().trim() ?? '';
        final albumId = song['albumId']?.toString().trim() ?? '';
        final key = (albumId.isNotEmpty ? albumId : albumTitle).toLowerCase();
        if (albumTitle.isNotEmpty && seen.add(key)) {
          albums.add({
            'ytid': albumId,
            'title': albumTitle,
            'artist': song['artist']?.toString() ?? '',
            'image': song['highResImage'] ?? song['image'],
            'isAlbum': true,
            'isSingle': false,
            'year': song['year']?.toString() ?? '',
            'source': 'song-album',
          });
        }
      }
    }

    _lastAlbumsLikedLength = likedLen;
    _lastAlbumsPlaylistsLength = playlistsLen;
    _lastAlbumsRecentLength = recentLen;
    _cachedAlbums = albums;
    return albums;
  }

  int _lastArtistsLikedLength = -1;
  int _lastArtistsPlaylistsLength = -1;
  bool _lastArtistsOffline = false;
  List<Map<String, dynamic>> _cachedArtists = const [];

  /// Derives distinct artists locally from liked artists and liked/recent songs.
  List<Map<String, dynamic>> loadArtists({bool offlineOnly = false}) {
    final likedLen = userLikedSongsList.value.length;
    final playlistsLen = userLikedPlaylists.value.length;
    if (_lastArtistsLikedLength == likedLen &&
        _lastArtistsPlaylistsLength == playlistsLen &&
        _lastArtistsOffline == offlineOnly &&
        _cachedArtists.isNotEmpty) {
      return _cachedArtists;
    }

    final seen = <String>{};
    final artists = <Map<String, dynamic>>[];

    // 1. Explicitly liked artists
    final likedArtists = getLikedArtistItems(offlineOnly: offlineOnly);
    for (final a in likedArtists) {
      final name = a['title']?.toString().trim() ?? '';
      final ytid = a['ytid']?.toString().trim() ?? '';
      final key = name.toLowerCase();
      if (name.isNotEmpty && seen.add(key)) {
        artists.add({
          'title': name,
          'ytid': ytid,
          'image': a['highResImage'] ?? a['image'],
        });
      }
    }

    // 2. Derive prominent artists from liked songs if not in offline-only mode
    if (!offlineOnly) {
      final artistCounts = <String, int>{};
      final artistImages = <String, String?>{};
      final artistIds = <String, String?>{};

      for (final song in userLikedSongsList.value) {
        if (song is Map) {
          final artistStr = song['artist']?.toString().trim() ?? '';
          if (artistStr.isEmpty) continue;

          // Split composite artists like "Anirudh, Dhanush"
          final parts = artistStr
              .split(RegExp('[,&]'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty);

          for (final p in parts) {
            artistCounts[p] = (artistCounts[p] ?? 0) + 1;
            artistImages[p] ??= song['image']?.toString();
            artistIds[p] ??= song['artistId']?.toString();
          }
        }
      }

      // Sort by frequency of appearance in liked songs
      final sortedEntries = artistCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (final entry in sortedEntries) {
        final name = entry.key;
        final key = name.toLowerCase();
        if (seen.add(key)) {
          artists.add({
            'title': name,
            'ytid': artistIds[name] ?? name,
            'image': artistImages[name],
          });
        }
      }
    }

    _lastArtistsLikedLength = likedLen;
    _lastArtistsPlaylistsLength = playlistsLen;
    _lastArtistsOffline = offlineOnly;
    _cachedArtists = artists;
    return artists;
  }

  /// Loads listening history with latest items first and optional deduplication.
  List<dynamic> loadRecentlyPlayed({bool deduplicate = true}) {
    final list = userRecentlyPlayed.value;
    if (!deduplicate) return List<dynamic>.from(list);

    final seenIds = <String>{};
    final result = <dynamic>[];
    for (final song in list) {
      if (song is Map) {
        final id = song['ytid']?.toString() ?? song['id']?.toString() ?? '';
        if (id.isNotEmpty && !seenIds.add(id)) {
          continue;
        }
      }
      result.add(song);
    }
    return result;
  }

  /// Loads downloaded and local songs and playlists from offline storage.
  Map<String, dynamic> loadDownloads() {
    return {
      'offlineSongs': List<dynamic>.from(userOfflineSongs.value),
      'localSongs': List<dynamic>.from(userLocalSongs.value),
      'offlinePlaylists': List<dynamic>.from(
        offlinePlaylistService.offlinePlaylists.value,
      ),
    };
  }

  /// Plays a single song directly through CatchifyAudioHandler.
  void playSong(dynamic song) {
    if (song is! Map) return;
    final playlist = {
      'ytid': '',
      'title': song['title'] ?? 'Song',
      'source': 'user-created',
      'list': [song],
    };
    audioHandler.playPlaylistSong(playlist: playlist, songIndex: 0);
  }

  /// Plays a list of songs through CatchifyAudioHandler with optional shuffle.
  void playAll(
    List<dynamic> songs, {
    String title = 'Queue',
    bool shuffle = false,
  }) {
    if (songs.isEmpty) return;
    final playlist = {
      'ytid': '',
      'title': title,
      'source': 'user-created',
      'list': songs,
    };
    audioHandler.playPlaylistSong(
      playlist: playlist,
      songIndex: 0,
      shuffle: shuffle,
    );
  }
}
