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

import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart'
    show
        appStartupStopwatch,
        checkAndLogColdStartPerf,
        homeCacheMs,
        isNetworkError,
        logger;
import 'package:catchify/services/artist_service.dart';
import 'package:catchify/services/data_manager.dart';
import 'package:catchify/services/home_feed_composer.dart';
import 'package:catchify/services/personalization_service.dart';
import 'package:catchify/services/playlist_download_service.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/app_utils.dart';
import 'package:catchify/utilities/flutter_toast.dart';
import 'package:catchify/utilities/formatter.dart';
import 'package:catchify/utilities/language_utils.dart';
import 'package:catchify/utilities/playlist_utils.dart';
import 'package:youtube_music_explode_dart/youtube_music_explode_dart.dart';

List<Map> playlists = [];

List<String> _readStoredStringList(String key) {
  final value = Hive.box('user').toMap()[key];
  return value is List ? value.whereType<String>().toList() : [];
}

Map<String, dynamic> _normalizeStoredMap(Map item) {
  return <String, dynamic>{
    for (final entry in item.entries)
      if (entry.key != null) entry.key.toString(): entry.value,
  };
}

List<Map> _readStoredMapList(String key) {
  final value = Hive.box('user').toMap()[key];
  if (value is! List) return [];
  return value.whereType<Map>().map(_normalizeStoredMap).toList();
}

final userPlaylists = ValueNotifier<List<String>>(
  _readStoredStringList('playlists'),
);
final userCustomPlaylists = ValueNotifier<List<Map>>(
  _readStoredMapList('customPlaylists'),
);
final userLikedPlaylists = ValueNotifier<List<Map>>(
  _readStoredMapList('likedPlaylists'),
);
final userPlaylistFolders = ValueNotifier<List<Map>>(
  _readStoredMapList('playlistFolders'),
);

Map<String, ({Map playlist, bool isFromFolder})>? _customPlaylistIndexCache;
bool _customPlaylistListenersAttached = false;

final pinnedPlaylistIds = ValueNotifier<List<String>>(
  _readStoredStringList('pinnedPlaylistIds'),
);
final onlinePlaylists = ValueNotifier<List<Map>>([]);

bool isArtistPlaylist(dynamic playlist) =>
    PlaylistUtils.isArtistPlaylist(playlist);

List<Map> getLikedPlaylistItems({bool includeArtists = false}) {
  return userLikedPlaylists.value
      .where((playlist) => includeArtists || !isArtistPlaylist(playlist))
      .toList();
}

List<Map> getLikedArtistItems({bool offlineOnly = false}) {
  final artists = <Map>[];
  for (final playlist in userLikedPlaylists.value.where(isArtistPlaylist)) {
    if (!offlineOnly) {
      artists.add(playlist);
      continue;
    }

    final offlineArtist = _findOfflinePlaylist(
      playlist['ytid']?.toString() ?? '',
    );
    if (offlineArtist != null) {
      artists.add(offlineArtist);
    }
  }
  return artists;
}

void reloadPlaylistLibraryStateFromStorage() {
  final userBox = Hive.box('user');
  final values = userBox.toMap();
  final dynamic rawPlaylists = values['playlists'];
  final dynamic rawCustomPlaylists = values['customPlaylists'];
  final dynamic rawLikedPlaylists = values['likedPlaylists'];
  final dynamic rawPlaylistFolders = values['playlistFolders'];
  final dynamic rawPinnedPlaylistIds = values['pinnedPlaylistIds'];
  userPlaylists.value = rawPlaylists is List
      ? rawPlaylists.whereType<String>().toList()
      : [];
  userCustomPlaylists.value = rawCustomPlaylists is List
      ? rawCustomPlaylists.whereType<Map>().map(_normalizeStoredMap).toList()
      : [];
  userLikedPlaylists.value = rawLikedPlaylists is List
      ? rawLikedPlaylists.whereType<Map>().map(_normalizeStoredMap).toList()
      : [];
  userPlaylistFolders.value = rawPlaylistFolders is List
      ? rawPlaylistFolders.whereType<Map>().map(_normalizeStoredMap).toList()
      : [];
  pinnedPlaylistIds.value = rawPinnedPlaylistIds is List
      ? rawPinnedPlaylistIds.whereType<String>().toList()
      : [];
}

void _updateOnlineCache(Map? p) {
  if (p != null && !onlinePlaylists.value.any((x) => x['ytid'] == p['ytid'])) {
    onlinePlaylists.value = [...onlinePlaylists.value, p];
  }
}

Map? _searchAppPlaylistsById(String id) {
  for (final p in userCustomPlaylists.value) {
    if (p['ytid']?.toString() == id) return p;
  }
  for (final f in userPlaylistFolders.value) {
    for (final p in (f['playlists'] as List? ?? [])) {
      if (p['ytid']?.toString() == id) return p as Map;
    }
  }
  for (final p in userLikedPlaylists.value) {
    if (p['ytid']?.toString() == id) return p;
  }
  for (final p in onlinePlaylists.value) {
    if (p['ytid']?.toString() == id) return p;
  }
  for (final p in offlinePlaylistService.offlinePlaylists.value) {
    if (p['ytid']?.toString() == id) return p as Map;
  }
  for (final p in playlists) {
    if (p['ytid']?.toString() == id) return p;
  }
  return null;
}

List<Map> resolvePinnedPlaylists(List<String> ids) {
  if (ids.isEmpty) return [];
  final result = <Map>[];
  for (final id in ids) {
    final match = _searchAppPlaylistsById(id);
    if (match != null) result.add(match);
  }
  return result;
}

const pinnedPlaylistsLimit = 5;

var _playlistLikeUpdateToken = 0;
final _latestPlaylistLikeUpdateTokens = <String, int>{};

Future<List<dynamic>> getUserPlaylists() async {
  final futures = userPlaylists.value.map((playlistID) async {
    try {
      final plist = await ytMusicClient.music.getPlaylist(playlistID);
      return {
        'ytid': plist.id,
        'title': plist.title,
        'image': plist.thumbnailUrl,
        'source': 'youtube-music-playlist',
        'list': [],
      };
    } catch (e, stackTrace) {
      logger.log(
        'Error occurred while fetching the playlist:',
        error: e,
        stackTrace: stackTrace,
      );
      return {
        'ytid': playlistID,
        'title': 'Failed playlist',
        'image': null,
        'source': 'youtube-music-playlist',
        'list': [],
      };
    }
  });

  final results = await Future.wait(futures);
  for (final result in results) {
    _updateOnlineCache(result);
  }
  return results.toList();
}

Future<String> addUserPlaylist(String input, BuildContext context) async {
  String? playlistId = input;

  if (input.startsWith('http://') || input.startsWith('https://')) {
    playlistId = extractYoutubePlaylistId(input);

    if (playlistId == null) {
      return '${context.l10n!.notYTlist}!';
    }
  }

  try {
    if (playlistExistsAnywhere(playlistId)) {
      return '${context.l10n!.playlistAlreadyExists}!';
    }

    final playlist = await ytMusicClient.music.getPlaylist(playlistId);
    if (playlist.title.isEmpty) {
      return '${context.l10n!.invalidYouTubePlaylist}!';
    }

    userPlaylists.value = [...userPlaylists.value, playlistId];
    unawaited(addOrUpdateData<List>('user', 'playlists', userPlaylists.value));
    return '${context.l10n!.addedSuccess}!';
  } catch (e, stackTrace) {
    logger.log('Error adding user playlist', error: e, stackTrace: stackTrace);
    return '${context.l10n!.error}: $e';
  }
}

(String message, String playlistId) createCustomPlaylist(
  String playlistName,
  String? image,
  BuildContext context,
) {
  final newPlaylistId = PlaylistUtils.generateCustomPlaylistId();
  final creationTime = DateTime.now().millisecondsSinceEpoch;
  final customPlaylist = {
    'ytid': newPlaylistId,
    'title': playlistName,
    'source': 'user-created',
    if (image != null) 'image': image,
    'list': [],
    'createdAt': creationTime,
  };
  userCustomPlaylists.value = [...userCustomPlaylists.value, customPlaylist];
  unawaited(
    addOrUpdateData<List>('user', 'customPlaylists', userCustomPlaylists.value),
  );
  return ('${context.l10n!.addedSuccess}!', newPlaylistId);
}

(String message, String playlistId) createCustomPlaylistWithSongs(
  String playlistName,
  List<Map> songs, {
  String? image,
}) {
  final newPlaylistId = PlaylistUtils.generateCustomPlaylistId();
  final creationTime = DateTime.now().millisecondsSinceEpoch;
  final customPlaylist = {
    'ytid': newPlaylistId,
    'title': playlistName,
    'source': 'user-created',
    if (image != null) 'image': image,
    'list': songs,
    'createdAt': creationTime,
  };
  userCustomPlaylists.value = [...userCustomPlaylists.value, customPlaylist];
  unawaited(
    addOrUpdateData<List>('user', 'customPlaylists', userCustomPlaylists.value),
  );
  return ('Playlist created', newPlaylistId);
}

String addSongInCustomPlaylist(
  BuildContext context,
  String playlistId,
  Map song, {
  int? indexToInsert,
}) {
  final found = _findCustomPlaylist(playlistId);
  final customPlaylist = found?.playlist;
  final isFromFolder = found?.isFromFolder ?? false;

  if (customPlaylist != null) {
    final playlistSongs = (customPlaylist['list'] is List)
        ? (customPlaylist['list'] as List)
        : (customPlaylist['list'] = <dynamic>[]);
    if (playlistSongs.any(
      (playlistElement) => playlistElement['ytid'] == song['ytid'],
    )) {
      return context.l10n!.songAlreadyInPlaylist;
    }
    if (indexToInsert != null) {
      final safeIndex = indexToInsert.clamp(0, playlistSongs.length);
      playlistSongs.insert(safeIndex, song);
    } else {
      playlistSongs.add(song);
    }
    if (isFromFolder) {
      userPlaylistFolders.value = List<Map>.from(userPlaylistFolders.value);
      unawaited(
        addOrUpdateData<List>(
          'user',
          'playlistFolders',
          userPlaylistFolders.value,
        ),
      );
    } else {
      userCustomPlaylists.value = List<Map>.from(userCustomPlaylists.value);
      unawaited(
        addOrUpdateData<List>(
          'user',
          'customPlaylists',
          userCustomPlaylists.value,
        ),
      );
    }

    return context.l10n!.songAdded;
  } else {
    logger.log('Custom playlist not found for ytid: $playlistId');
    return context.l10n!.error;
  }
}

List<Map> getUserCustomPlaylists() {
  final result = <Map>[];
  for (final p in userCustomPlaylists.value) {
    if (p['source'] == 'user-created') {
      result.add(p);
    }
  }
  for (final folder in userPlaylistFolders.value) {
    final folderPlaylists = folder['playlists'] as List<dynamic>?;
    if (folderPlaylists != null) {
      for (final p in folderPlaylists) {
        if (p is Map && p['source'] == 'user-created') {
          result.add(p);
        }
      }
    }
  }
  return result;
}

String addSongsInCustomPlaylist(
  BuildContext context,
  String playlistId,
  List<dynamic> songs,
) {
  final found = _findCustomPlaylist(playlistId);
  final customPlaylist = found?.playlist;
  final isFromFolder = found?.isFromFolder ?? false;

  if (customPlaylist != null) {
    final playlistSongs = (customPlaylist['list'] is List)
        ? (customPlaylist['list'] as List)
        : (customPlaylist['list'] = <dynamic>[]);

    final existingYtids = <dynamic>{
      for (final item in playlistSongs)
        if (item is Map && item['ytid'] != null) item['ytid'],
    };

    final newSongs = <dynamic>[];
    for (final song in songs) {
      final ytid = (song is Map) ? song['ytid'] : null;
      if (ytid != null && !existingYtids.contains(ytid)) {
        playlistSongs.add(song);
        newSongs.add(song);
        existingYtids.add(ytid);
      }
    }

    if (newSongs.isNotEmpty) {
      if (isFromFolder) {
        userPlaylistFolders.value = List<Map>.from(userPlaylistFolders.value);
        unawaited(
          addOrUpdateData<List>(
            'user',
            'playlistFolders',
            userPlaylistFolders.value,
          ),
        );
      } else {
        userCustomPlaylists.value = List<Map>.from(userCustomPlaylists.value);
        unawaited(
          addOrUpdateData<List>(
            'user',
            'customPlaylists',
            userCustomPlaylists.value,
          ),
        );
      }
      offlinePlaylistService.checkAndAutoMarkOffline(customPlaylist);
      return context.l10n!.addedSuccess;
    } else {
      return context.l10n!.songAlreadyInPlaylist;
    }
  } else {
    logger.log('Custom playlist not found for ytid: $playlistId');
    return context.l10n!.error;
  }
}

bool removeSongFromPlaylist(
  Map playlist,
  Map songToRemove, {
  int? removeOneAtIndex,
}) {
  try {
    if (playlist['list'] == null) return false;

    final playlistSongs = List<dynamic>.from(playlist['list']);
    if (removeOneAtIndex != null) {
      if (removeOneAtIndex < 0 || removeOneAtIndex >= playlistSongs.length) {
        return false;
      }
      playlistSongs.removeAt(removeOneAtIndex);
    } else {
      final initialLength = playlistSongs.length;
      playlistSongs.removeWhere((song) => song['ytid'] == songToRemove['ytid']);
      if (playlistSongs.length == initialLength) return false;
    }

    playlist['list'] = playlistSongs;

    try {
      if (playlist['source'] == 'user-created') {
        final playlistId = playlist['ytid']?.toString();
        final isInFolder =
            playlistId != null &&
            userPlaylistFolders.value.any((folder) {
              final folderPlaylists =
                  folder['playlists'] as List<dynamic>? ?? [];
              return folderPlaylists.any(
                (p) => p['ytid']?.toString() == playlistId,
              );
            });

        if (isInFolder) {
          userPlaylistFolders.value = List<Map>.from(userPlaylistFolders.value);
          unawaited(
            addOrUpdateData<List>(
              'user',
              'playlistFolders',
              userPlaylistFolders.value,
            ),
          );
        } else {
          userCustomPlaylists.value = List<Map>.from(userCustomPlaylists.value);
          unawaited(
            addOrUpdateData<List>(
              'user',
              'customPlaylists',
              userCustomPlaylists.value,
            ),
          );
        }
      } else {
        final playlistId = playlist['ytid']?.toString();

        final likedIndex = userLikedPlaylists.value.indexWhere(
          (p) => p['ytid']?.toString() == playlistId,
        );
        if (likedIndex != -1) {
          final updatedLiked = List<Map>.from(userLikedPlaylists.value);
          updatedLiked[likedIndex] = {
            ...updatedLiked[likedIndex],
            'list': playlistSongs,
          };
          userLikedPlaylists.value = updatedLiked;
          unawaited(
            addOrUpdateData<List>(
              'user',
              'likedPlaylists',
              userLikedPlaylists.value,
            ),
          );
        }

        if (playlistId != null && playlistId.isNotEmpty) {
          unawaited(
            addOrUpdateData<List>(
              'cache',
              'playlistSongs$playlistId',
              playlistSongs,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error saving playlist changes',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }

    return true;
  } catch (e, stackTrace) {
    logger.log(
      'Error while removing song from playlist: ',
      error: e,
      stackTrace: stackTrace,
    );
    return false;
  }
}

void removeUserPlaylist(String playlistId) {
  final normalizedId = playlistId.trim();
  if (normalizedId.isEmpty) return;

  final updatedPlaylists = List<String>.from(userPlaylists.value)
    ..removeWhere((id) => id == normalizedId);
  userPlaylists.value = updatedPlaylists;

  final foldersChanged = _removePlaylistFromFolders(normalizedId);
  final likedChanged = _removePlaylistFromLikedPlaylists(normalizedId);
  _unpinPlaylist(normalizedId);

  unawaited(addOrUpdateData<List>('user', 'playlists', userPlaylists.value));
  if (foldersChanged) {
    unawaited(
      addOrUpdateData<List>(
        'user',
        'playlistFolders',
        userPlaylistFolders.value,
      ),
    );
  }
  if (likedChanged) {
    unawaited(
      addOrUpdateData<List>('user', 'likedPlaylists', userLikedPlaylists.value),
    );
  }
}

void removeUserPlaylistEntry(Map playlist) {
  final playlistId = playlist['ytid']?.toString().trim() ?? '';
  if (playlistId.isEmpty) return;

  final source = playlist['source']?.toString();
  if (PlaylistUtils.isCustomPlaylist(playlist)) {
    removeUserCustomPlaylist(playlistId);
    return;
  }

  if (source == 'user-youtube') {
    removeUserPlaylist(playlistId);
    return;
  }

  final existsInCustom = userCustomPlaylists.value.any(
    (p) => p['ytid']?.toString() == playlistId,
  );

  if (existsInCustom) {
    removeUserCustomPlaylist(playlistId);
  } else {
    removeUserPlaylist(playlistId);
  }
}

void removeUserCustomPlaylist(dynamic playlist) {
  try {
    final playlistId = (playlist is Map ? playlist['ytid'] : playlist)
        ?.toString()
        .trim();
    if (playlistId == null || playlistId.isEmpty) return;

    final updatedPlaylists = List<Map>.from(userCustomPlaylists.value)
      ..removeWhere((p) => p['ytid']?.toString() == playlistId);
    userCustomPlaylists.value = updatedPlaylists;

    final foldersChanged = _removePlaylistFromFolders(playlistId);
    final likedChanged = _removePlaylistFromLikedPlaylists(playlistId);
    _unpinPlaylist(playlistId);

    unawaited(
      addOrUpdateData<List>(
        'user',
        'customPlaylists',
        userCustomPlaylists.value,
      ),
    );
    if (foldersChanged) {
      unawaited(
        addOrUpdateData<List>(
          'user',
          'playlistFolders',
          userPlaylistFolders.value,
        ),
      );
    }
    if (likedChanged) {
      unawaited(
        addOrUpdateData<List>(
          'user',
          'likedPlaylists',
          userLikedPlaylists.value,
        ),
      );
    }
  } catch (e, stackTrace) {
    logger.log(
      'Error removing custom playlist',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

bool _removePlaylistFromFolders(String playlistId) {
  var changed = false;
  final updatedFolders = List<Map>.from(userPlaylistFolders.value);

  for (final folder in updatedFolders) {
    final folderPlaylists = List<Map>.from(folder['playlists'] ?? []);
    final previousLength = folderPlaylists.length;
    folderPlaylists.removeWhere(
      (playlist) => playlist['ytid']?.toString() == playlistId,
    );

    if (folderPlaylists.length != previousLength) {
      folder['playlists'] = folderPlaylists;
      changed = true;
    }
  }

  if (changed) {
    userPlaylistFolders.value = updatedFolders;
  }

  return changed;
}

bool _removePlaylistFromLikedPlaylists(String playlistId) {
  final updatedLikedPlaylists = _deduplicateLikedPlaylists(
    userLikedPlaylists.value,
  )..removeWhere((playlist) => playlist['ytid']?.toString() == playlistId);

  if (_likedPlaylistIdsAreEqual(
    userLikedPlaylists.value,
    updatedLikedPlaylists,
  )) {
    return false;
  }
  userLikedPlaylists.value = List<Map>.from(updatedLikedPlaylists);
  return true;
}

String createPlaylistFolder(String folderName, [BuildContext? context]) {
  if (folderName.trim().isEmpty) {
    return context?.l10n?.enterFolderName ?? 'Please enter a folder name';
  }

  final exists = userPlaylistFolders.value.any(
    (folder) =>
        folder['name'].toString().toLowerCase() ==
        folderName.trim().toLowerCase(),
  );

  if (exists) {
    return context?.l10n?.folderAlreadyExists ?? 'Folder already exists';
  }

  final newFolder = {
    'id': DateTime.now().millisecondsSinceEpoch.toString(),
    'name': folderName.trim(),
    'playlists': <Map>[],
    'createdAt': DateTime.now().millisecondsSinceEpoch,
  };

  userPlaylistFolders.value = [...userPlaylistFolders.value, newFolder];
  unawaited(
    addOrUpdateData<List>('user', 'playlistFolders', userPlaylistFolders.value),
  );
  return context?.l10n?.addedSuccess ?? 'Added successfully';
}

String renamePlaylistFolder(
  String folderId,
  String newName, [
  BuildContext? context,
]) {
  if (newName.trim().isEmpty) {
    return context?.l10n?.enterFolderName ?? 'Please enter a folder name';
  }

  final updatedFolders = List<Map>.from(userPlaylistFolders.value);
  final folderIndex = updatedFolders.indexWhere((f) => f['id'] == folderId);

  if (folderIndex == -1) {
    return context?.l10n?.error ?? 'Error';
  }

  final exists = updatedFolders.any(
    (folder) =>
        folder['id'] != folderId &&
        folder['name'].toString().toLowerCase() == newName.trim().toLowerCase(),
  );

  if (exists) {
    return context?.l10n?.folderAlreadyExists ?? 'Folder already exists';
  }

  updatedFolders[folderIndex]['name'] = newName.trim();
  userPlaylistFolders.value = updatedFolders;

  unawaited(
    addOrUpdateData<List>('user', 'playlistFolders', userPlaylistFolders.value),
  );
  return context?.l10n?.folderUpdated ?? 'Folder updated successfully';
}

String movePlaylistToFolder(
  Map playlist,
  String? folderId,
  BuildContext context,
) {
  try {
    final updatedFolders = List<Map>.from(userPlaylistFolders.value);
    final updatedCustomPlaylists = List<Map>.from(userCustomPlaylists.value);
    final updatedYoutubePlaylists = List<String>.from(userPlaylists.value);

    for (final folder in updatedFolders) {
      final folderPlaylists = List<Map>.from(
        folder['playlists'] ?? [],
      )..removeWhere((p) => p['ytid'] != null && p['ytid'] == playlist['ytid']);
      folder['playlists'] = folderPlaylists;
    }

    if (folderId != null) {
      final targetFolder = updatedFolders.firstWhere(
        (folder) => folder['id'] == folderId,
        orElse: () => {},
      );

      if (targetFolder.isNotEmpty) {
        final folderPlaylists = List<Map>.from(targetFolder['playlists'] ?? [])
          ..add(playlist);
        targetFolder['playlists'] = folderPlaylists;

        if (playlist['source'] == 'user-created') {
          updatedCustomPlaylists.removeWhere(
            (p) => p['ytid'] == playlist['ytid'],
          );
        } else if (playlist['source'] == 'user-youtube') {
          updatedYoutubePlaylists.removeWhere((p) => p == playlist['ytid']);
        }
      } else {
        logger.log(
          'Target folder with id $folderId not found for moving playlist',
        );
        return context.l10n!.error;
      }
    } else {
      if (playlist['source'] == 'user-created') {
        if (!updatedCustomPlaylists.any((p) => p['ytid'] == playlist['ytid'])) {
          updatedCustomPlaylists.add(playlist);
        }
      } else if (playlist['source'] == 'user-youtube') {
        if (!updatedYoutubePlaylists.contains(playlist['ytid'])) {
          updatedYoutubePlaylists.add(playlist['ytid']);
        }
      }
    }

    userPlaylistFolders.value = updatedFolders;
    userCustomPlaylists.value = updatedCustomPlaylists;
    userPlaylists.value = updatedYoutubePlaylists;

    unawaited(
      addOrUpdateData<List>(
        'user',
        'playlistFolders',
        userPlaylistFolders.value,
      ),
    );
    unawaited(
      addOrUpdateData<List>(
        'user',
        'customPlaylists',
        userCustomPlaylists.value,
      ),
    );
    unawaited(addOrUpdateData<List>('user', 'playlists', userPlaylists.value));

    return '${context.l10n!.addedSuccess}!';
  } catch (e, stackTrace) {
    logger.log(
      'Error moving playlist to folder',
      error: e,
      stackTrace: stackTrace,
    );
    return context.l10n!.error;
  }
}

String deletePlaylistFolder(String folderId, [BuildContext? context]) {
  try {
    final updatedFolders = List<Map>.from(userPlaylistFolders.value);
    final folderToDelete = updatedFolders.firstWhere(
      (folder) => folder['id'] == folderId,
      orElse: () => {},
    );

    if (folderToDelete.isNotEmpty) {
      final folderPlaylists = List<Map>.from(folderToDelete['playlists'] ?? []);
      final updatedCustomPlaylists = List<Map>.from(userCustomPlaylists.value);
      final updatedYoutubePlaylists = List<String>.from(userPlaylists.value);

      for (final playlist in folderPlaylists) {
        if (playlist['source'] == 'user-created') {
          if (playlist['ytid'] != null &&
              !updatedCustomPlaylists.any(
                (p) => p['ytid'] == playlist['ytid'],
              )) {
            updatedCustomPlaylists.add(playlist);
          }
        } else if (playlist['source'] == 'user-youtube') {
          if (playlist['ytid'] != null &&
              !updatedYoutubePlaylists.contains(playlist['ytid'])) {
            updatedYoutubePlaylists.add(playlist['ytid']);
          }
        }
      }

      updatedFolders.removeWhere((folder) => folder['id'] == folderId);

      userPlaylistFolders.value = updatedFolders;
      userCustomPlaylists.value = updatedCustomPlaylists;
      userPlaylists.value = updatedYoutubePlaylists;

      unawaited(
        addOrUpdateData<List>(
          'user',
          'playlistFolders',
          userPlaylistFolders.value,
        ),
      );
      unawaited(
        addOrUpdateData<List>(
          'user',
          'customPlaylists',
          userCustomPlaylists.value,
        ),
      );
      unawaited(
        addOrUpdateData<List>('user', 'playlists', userPlaylists.value),
      );

      return context?.l10n?.folderDeleted ?? 'Folder deleted successfully';
    }
    return context?.l10n?.error ?? 'Error';
  } catch (e, stackTrace) {
    logger.log(
      'Error deleting playlist folder',
      error: e,
      stackTrace: stackTrace,
    );
    return context?.l10n?.error ?? 'Error';
  }
}

List<Map> getPlaylistsInFolder(String folderId) {
  try {
    final folder = userPlaylistFolders.value.firstWhere(
      (folder) => folder['id'] == folderId,
      orElse: () => {},
    );
    return List<Map>.from(folder['playlists'] ?? []);
  } catch (e, stackTrace) {
    logger.log(
      'Error getting playlists in folder',
      error: e,
      stackTrace: stackTrace,
    );
    return [];
  }
}

List<Map> getPlaylistsNotInFolders() {
  final playlistsInFolders = <String>{};
  for (final folder in userPlaylistFolders.value) {
    final folderPlaylists = folder['playlists'] as List<dynamic>? ?? [];
    for (final playlist in folderPlaylists) {
      if (playlist['ytid'] != null) {
        playlistsInFolders.add(playlist['ytid']);
      }
    }
  }

  return userCustomPlaylists.value
      .where((playlist) {
        final playlistId = playlist['ytid'];
        return playlistId == null || !playlistsInFolders.contains(playlistId);
      })
      .toList()
      .cast<Map>();
}

Future<List> getPlaylists({
  String? query,
  int? playlistsNum,
  String type = 'all',
  bool forceRefresh = false,
}) async {
  if (playlistsNum == null && query == null) {
    logger.log('No playlists query or limit provided');
    return [];
  }

  if (query != null && playlistsNum == null) {
    final lowercaseQuery = query.toLowerCase();
    final filteredPlaylists = playlists.where((playlist) {
      final title = playlist['title'].toLowerCase();
      final matchesQuery = title.contains(lowercaseQuery);
      final matchesType =
          type == 'all' ||
          (type == 'album' && playlist['isAlbum'] == true) ||
          (type == 'playlist' && playlist['isAlbum'] != true);
      return matchesQuery && matchesType;
    }).toList();

    if (filteredPlaylists.isNotEmpty) {
      return filteredPlaylists;
    }

    if (type == 'album') {
      try {
        final albums = await ytMusicClient.music.searchAlbums(query);
        if (albums.isNotEmpty) return albums;
        final cleanQuery = formatSongTitle(query);
        if (cleanQuery.isNotEmpty &&
            cleanQuery.toLowerCase() != query.toLowerCase()) {
          final retryAlbums = await ytMusicClient.music.searchAlbums(
            cleanQuery,
          );
          if (retryAlbums.isNotEmpty) return retryAlbums;
        }
      } catch (e, st) {
        if (!isNetworkError(e)) {
          logger.log(
            'Error in ytMusicClient.searchAlbums for "$query":',
            error: e,
            stackTrace: st,
          );
        }
      }
      return [];
    } else if (type == 'playlist') {
      try {
        final ytmPlaylists = await ytMusicClient.music.searchPlaylists(query);
        if (ytmPlaylists.isNotEmpty) return ytmPlaylists;
        final cleanQuery = formatSongTitle(query);
        if (cleanQuery.isNotEmpty &&
            cleanQuery.toLowerCase() != query.toLowerCase()) {
          final retryPlaylists = await ytMusicClient.music.searchPlaylists(
            cleanQuery,
          );
          if (retryPlaylists.isNotEmpty) return retryPlaylists;
        }
      } catch (e, st) {
        if (!isNetworkError(e)) {
          logger.log(
            'Error in ytMusicClient.searchPlaylists for "$query":',
            error: e,
            stackTrace: st,
          );
        }
      }
      return [];
    }

    try {
      final ytmPlaylists = await ytMusicClient.music.searchPlaylists(query);
      if (ytmPlaylists.isNotEmpty) return ytmPlaylists;
    } catch (_) {}
    return [];
  }

  if (playlistsNum != null && query == null) {
    return getCommunityPlaylists(
      limit: playlistsNum,
      forceRefresh: forceRefresh,
    );
  }

  if (type != 'all') {
    return playlists.where((playlist) {
      return type == 'album'
          ? playlist['isAlbum'] == true
          : playlist['isAlbum'] != true;
    }).toList();
  }

  return playlists;
}

bool _isForbiddenVideoPlaylist(String title) {
  final lower = title.toLowerCase();
  return lower.contains('video song') ||
      lower.contains('video songs') ||
      lower.contains('1080p') ||
      lower.contains('4k') ||
      lower.contains('hd video') ||
      lower.contains('top weekly videos') ||
      lower.contains('mashup') ||
      lower.contains('status') ||
      lower.contains('whatsapp') ||
      lower.contains('full movie') ||
      lower.contains('short') ||
      lower.contains('reels');
}

Future<List<Map<String, dynamic>>> getCommunityPlaylists({
  int limit = 20,
  bool forceRefresh = false,
}) async {
  String? rawLang;
  try {
    rawLang = contentLanguagePreference;
  } catch (_) {}
  rawLang ??= 'en';
  final prefLang = artistLanguageCodeToName[rawLang] ?? rawLang;

  final cacheKey = 'ytm_home_from_the_community_v4_$prefLang';
  var livePlaylists = <Map<String, dynamic>>[];

  if (!forceRefresh && Hive.isBoxOpen('cache')) {
    try {
      final cached = await getData('cache', cacheKey);
      if (cached is List && cached.isNotEmpty) {
        livePlaylists = cached
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
      }
    } catch (_) {}
  }

  if (livePlaylists.isEmpty) {
    try {
      if (prefLang.toLowerCase() != 'english') {
        // 1. Prioritize official YouTube Music community & featured playlists from category page
        final catShelves = await getLanguageCategoryShelves(
          prefLang,
          forceRefresh: forceRefresh,
        );
        final catCommunity = catShelves['communityPlaylists'] ?? const [];
        for (final pl in catCommunity) {
          final title = pl['title']?.toString() ?? '';
          if (_isForbiddenVideoPlaylist(title)) continue;
          final rawThumb = pl['image']?.toString();
          final highResThumb = rawThumb != null
              ? formatArtworkResolution(rawThumb, 1080)
              : rawThumb;
          livePlaylists.add({
            ...pl,
            if (highResThumb != null) 'image': highResThumb,
            if (highResThumb != null) 'highResImage': highResThumb,
            'source': 'youtube-music-playlist',
          });
        }

        if (livePlaylists.length < limit) {
          final featured = catShelves['featuredPlaylists'] ?? const [];
          for (final pl in featured) {
            final title = pl['title']?.toString() ?? '';
            if (_isForbiddenVideoPlaylist(title)) continue;
            final rawThumb = pl['image']?.toString();
            final highResThumb = rawThumb != null
                ? formatArtworkResolution(rawThumb, 1080)
                : rawThumb;
            livePlaylists.add({
              ...pl,
              if (highResThumb != null) 'image': highResThumb,
              if (highResThumb != null) 'highResImage': highResThumb,
              'source': 'youtube-music-playlist',
            });
          }
        }

        // 2. Language community hit playlists directly from YouTube Music (filtered)
        if (livePlaylists.length < limit) {
          final searchPlaylists = await ytMusicClient.music
              .searchPlaylists('$prefLang hits playlist', limit: limit)
              .timeout(const Duration(seconds: 6))
              .catchError((_) => <Map<String, dynamic>>[]);

          for (final pl in searchPlaylists) {
            final title = pl['title']?.toString() ?? '';
            if (_isForbiddenVideoPlaylist(title)) continue;
            final rawThumb = pl['image']?.toString();
            final highResThumb = rawThumb != null
                ? formatArtworkResolution(rawThumb, 1080)
                : rawThumb;
            livePlaylists.add({
              ...pl,
              if (highResThumb != null) 'image': highResThumb,
              if (highResThumb != null) 'highResImage': highResThumb,
              'source': 'youtube-music-playlist',
            });
          }
        }
      }

      // 3. Supplement with YouTube Music home feed playlists if needed
      if (livePlaylists.length < limit) {
        final homePlaylists = await ytMusicClient.music
            .getHomePlaylists(limit: limit)
            .timeout(const Duration(seconds: 8))
            .catchError((_) => <Map<String, dynamic>>[]);
        for (final pl in homePlaylists) {
          final rawThumb = pl['image']?.toString();
          final highResThumb = rawThumb != null
              ? formatArtworkResolution(rawThumb, 1080)
              : rawThumb;
          livePlaylists.add({
            ...pl,
            if (highResThumb != null) 'image': highResThumb,
            if (highResThumb != null) 'highResImage': highResThumb,
          });
        }
      }

      // Deduplicate playlists by ytid
      final seenIds = <String>{};
      livePlaylists = livePlaylists.where((p) {
        final id = p['ytid']?.toString() ?? '';
        return id.isNotEmpty && seenIds.add(id);
      }).toList();

      if (livePlaylists.isNotEmpty && Hive.isBoxOpen('cache')) {
        unawaited(addOrUpdateData('cache', cacheKey, livePlaylists));
      }
    } catch (e, st) {
      logger.log(
        'Error fetching dynamic YTM community playlists for $prefLang:',
        error: e,
        stackTrace: st,
      );
    }
  }

  if (livePlaylists.isNotEmpty) {
    for (final p in livePlaylists) {
      if (!playlists.any((item) => item['ytid'] == p['ytid'])) {
        playlists.add(p);
      }
    }
    return livePlaylists.take(limit).toList();
  }

  return const [];
}

Future<List<Map<String, dynamic>>> searchArtists(
  String query, {
  int limit = 5,
  bool verifiedOnly = true,
}) async {
  return searchVerifiedArtists(query, limit: limit);
}

const Map<String, String> artistLanguageCodeToName = {
  'ta': 'Tamil',
  'hi': 'Hindi',
  'te': 'Telugu',
  'ml': 'Malayalam',
  'kn': 'Kannada',
  'pa': 'Punjabi',
  'en': 'English',
  'mr': 'Marathi',
  'bn': 'Bengali',
  'gu': 'Gujarati',
  'ur': 'Urdu',
  'or': 'Odia',
  'as': 'Assamese',
  'sa': 'Sanskrit',
  'kok': 'Konkani',
  // Global music languages
  'es': 'Spanish',
  'ko': 'Korean',
  'ja': 'Japanese',
  'fr': 'French',
  'de': 'German',
  'pt': 'Portuguese',
  'id': 'Indonesian',
  'it': 'Italian',
  'tr': 'Turkish',
  'ru': 'Russian',
  'ar': 'Arabic',
};

/// Validates whether a channel/artist name belongs to a legitimate music artist,
/// filtering out media channels, labels, production houses, and movie promotion pages.
bool _isLegitimateMusicArtist(String name) {
  final clean = name.trim().toLowerCase();
  if (clean.isEmpty) return false;

  const nonArtistTokens = [
    'official',
    'music',
    'records',
    'record',
    'entertainment',
    'channel',
    'tv',
    'media',
    'production',
    'productions',
    'movies',
    'movie',
    'cinema',
    'studios',
    'studio',
    'series',
    'audio',
    'trailers',
    'trailer',
    'teasers',
    'teaser',
    'news',
    't-series',
    'saregama',
    'sony',
    'zee',
    'tips',
    'aditya',
    'think music',
    'speed audio',
    'lahari',
    'muzik247',
    'behindwoods',
    'galatta',
    'filmibeat',
    'sun tv',
    'vijay tv',
    'star vijay',
    'tamil cinema',
    'talks',
    'status',
    'clips',
    'vlog',
    'comedy',
    'junction',
    'radio',
    'fm',
    'network',
    'corporation',
    'label',
    'songs',
    'playlist',
  ];

  for (final token in nonArtistTokens) {
    if (clean.contains(token)) {
      return false;
    }
  }

  return true;
}

const Map<String, List<String>> _curatedMusicArtistsPerLanguage = {
  'tamil': [
    'Anirudh Ravichander',
    'A. R. Rahman',
    'Yuvan Shankar Raja',
    'Harris Jayaraj',
    'Sid Sriram',
    'Ilaiyaraaja',
    'Santhosh Narayanan',
    'Pradeep Kumar',
    'D. Imman',
    'Shreya Ghoshal',
    'G. V. Prakash Kumar',
    'Jonita Gandhi',
    'S. P. Balasubrahmanyam',
    'Sean Roldan',
    'Vidyasagar',
    'Vijay Antony',
  ],
  'telugu': [
    'Devi Sri Prasad',
    'S. Thaman',
    'Sid Sriram',
    'Anurag Kulkarni',
    'Ram Miriyala',
    'M. M. Keeravaani',
    'Mickey J. Meyer',
    'Armaan Malik',
    'Shreya Ghoshal',
    'Karthik',
  ],
  'hindi': [
    'Arijit Singh',
    'Pritam',
    'Shreya Ghoshal',
    'A. R. Rahman',
    'Sachin-Jigar',
    'Vishal-Shekhar',
    'Badshah',
    'Neha Kakkar',
    'Sonu Nigam',
    'Sunidhi Chauhan',
    'Atif Aslam',
    'Amit Trivedi',
  ],
  'malayalam': [
    'Sushin Shyam',
    'Hesham Abdul Wahab',
    'Jakes Bejoy',
    'Shaan Rahman',
    'K. S. Chithra',
    'K. J. Yesudas',
    'Job Kurian',
    'Vidyasagar',
  ],
  'kannada': [
    'Ravi Basrur',
    'Charan Raj',
    'Arjun Janya',
    'Vijay Prakash',
    'Sanjith Hegde',
    'B. Ajaneesh Loknath',
  ],
  'punjabi': [
    'Diljit Dosanjh',
    'AP Dhillon',
    'Karan Aujla',
    'Sidhu Moose Wala',
    'Shubh',
    'Amrinder Gill',
    'B Praak',
    'Gurdas Maan',
  ],
};

Future<List<Map<String, dynamic>>> getSuggestedArtists({
  int limit = 20,
  bool forceRefresh = false,
}) async {
  var isOffline = false;
  try {
    isOffline = offlineMode.value;
  } catch (_) {}

  var likedArtists = <Map<String, dynamic>>[];
  try {
    likedArtists = getLikedArtistItems(
      offlineOnly: isOffline,
    ).map(Map<String, dynamic>.from).toList();
  } catch (_) {}

  String? rawLang;
  try {
    rawLang = contentLanguagePreference;
  } catch (_) {}
  rawLang ??= 'en';
  final prefLang = artistLanguageCodeToName[rawLang] ?? rawLang;

  final cacheKey = 'dynamic_home_artists_v4_$prefLang';
  var liveArtists = <Map<String, dynamic>>[];

  if (!forceRefresh && !isOffline && Hive.isBoxOpen('cache')) {
    try {
      final cached = await getData('cache', cacheKey);
      if (cached is List && cached.isNotEmpty) {
        liveArtists = cached
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .where(
              (a) => _isLegitimateMusicArtist(a['title']?.toString() ?? ''),
            )
            .toList();
      }
    } catch (_) {}
  }

  if (liveArtists.isEmpty && !isOffline) {
    try {
      // 1. Fetch language-specific verified music artists
      final cleanLang = prefLang.toLowerCase();
      final curatedNames =
          _curatedMusicArtistsPerLanguage[cleanLang] ?? const [];

      if (curatedNames.isNotEmpty) {
        // Search top music artists for this language
        final searchFutures = curatedNames.take(6).map((name) {
          return ytMusicClient.music
              .searchArtists(name)
              .timeout(const Duration(seconds: 4))
              .catchError((_) => <MusicArtist>[]);
        });

        final searchResults = await Future.wait(searchFutures);
        for (final artistList in searchResults) {
          for (final artist in artistList) {
            if (!_isLegitimateMusicArtist(artist.name)) continue;
            final rawThumb = artist.thumbnailUrl;
            final highResThumb = rawThumb != null
                ? formatArtworkResolution(rawThumb, 512)
                : rawThumb;
            liveArtists.add({
              'ytid': artist.id,
              'title': artist.name,
              'image': highResThumb,
              'lowResImage': rawThumb,
              'highResImage': highResThumb,
              'source': 'youtube-artist',
              'isArtist': true,
              'isVerifiedArtist': true,
            });
            break; // take first exact match per curated name
          }
        }
      }

      // 2. Fetch live Top Artists from YouTube Music Charts (strictly filtered to legitimate music artists)
      if (liveArtists.length < limit) {
        final chartsArtists = await ytMusicClient.music
            .getChartsArtists()
            .timeout(const Duration(seconds: 6))
            .catchError((_) => <Map<String, dynamic>>[]);

        for (final artist in chartsArtists) {
          final name = artist['name']?.toString() ?? '';
          if (!_isLegitimateMusicArtist(name)) continue;

          final rawThumb = artist['image']?.toString();
          final highResThumb = rawThumb != null
              ? formatArtworkResolution(rawThumb, 512)
              : rawThumb;
          liveArtists.add({
            'ytid': artist['id'],
            'title': name,
            'image': highResThumb,
            'lowResImage': artist['image'],
            'highResImage': highResThumb,
            'subscribers': artist['subscribers'],
            'source': 'youtube-artist',
            'isArtist': true,
            'isVerifiedArtist': true,
          });
        }
      }

      // 3. If still needed, search for canonical artists matching language, enforcing music artist checks
      if (liveArtists.length < limit && cleanLang != 'english') {
        try {
          final langArtists = await ytMusicClient.music
              .searchArtists('$prefLang music')
              .timeout(const Duration(seconds: 5))
              .catchError((_) => <MusicArtist>[]);

          for (final artist in langArtists) {
            if (!_isLegitimateMusicArtist(artist.name)) continue;
            final rawThumb = artist.thumbnailUrl;
            final highResThumb = rawThumb != null
                ? formatArtworkResolution(rawThumb, 512)
                : rawThumb;
            liveArtists.add({
              'ytid': artist.id,
              'title': artist.name,
              'image': highResThumb,
              'lowResImage': rawThumb,
              'highResImage': highResThumb,
              'source': 'youtube-artist',
              'isArtist': true,
              'isVerifiedArtist': true,
            });
          }
        } catch (_) {}
      }

      if (liveArtists.isNotEmpty && Hive.isBoxOpen('cache')) {
        unawaited(addOrUpdateData('cache', cacheKey, liveArtists));
      }
    } catch (e, st) {
      logger.log(
        'Error fetching dynamic YTM artists for $prefLang:',
        error: e,
        stackTrace: st,
      );
    }
  }

  final combined = [
    ...likedArtists.where(
      (a) => _isLegitimateMusicArtist(a['title']?.toString() ?? ''),
    ),
    ...liveArtists,
  ];

  final seenIds = <String>{};
  final seenTitles = <String>{};
  final result = <Map<String, dynamic>>[];

  for (final artist in combined) {
    final ytid = artist['ytid']?.toString() ?? '';
    final title = (artist['title']?.toString() ?? '').toLowerCase().trim();
    if (title.isEmpty || !_isLegitimateMusicArtist(title)) continue;
    if (ytid.isNotEmpty && !seenIds.add(ytid)) continue;
    if (!seenTitles.add(title)) continue;
    result.add(artist);
    if (result.length >= limit) break;
  }

  return result;
}

/// Fetches and caches the complete category page shelves (Songs, Featured playlists, Community playlists, Albums)
/// directly from YouTube Music InnerTube (FEmusic_moods_and_genres_category).
Future<Map<String, List<Map<String, dynamic>>>> getLanguageCategoryShelves(
  String language, {
  bool forceRefresh = false,
}) {
  final requestKey =
      '${language.trim().toLowerCase()}|${forceRefresh ? 'refresh' : 'cached'}';
  final existing = _languageCategoryShelvesInFlight[requestKey];
  if (existing != null) {
    return existing;
  }

  late Future<Map<String, List<Map<String, dynamic>>>> tracked;
  tracked = _loadLanguageCategoryShelves(language, forceRefresh: forceRefresh)
      .whenComplete(() {
        if (identical(_languageCategoryShelvesInFlight[requestKey], tracked)) {
          _languageCategoryShelvesInFlight.remove(requestKey);
        }
      });
  _languageCategoryShelvesInFlight[requestKey] = tracked;
  return tracked;
}

final Map<String, Future<Map<String, List<Map<String, dynamic>>>>>
_languageCategoryShelvesInFlight = {};

Future<Map<String, List<Map<String, dynamic>>>> _loadLanguageCategoryShelves(
  String language, {
  required bool forceRefresh,
}) async {
  final cleanLang = language.trim().toLowerCase();
  final cacheKey = 'ytm_cat_shelves_v2_$cleanLang';

  if (!forceRefresh && Hive.isBoxOpen('cache')) {
    try {
      final cached = await getData('cache', cacheKey);
      if (cached is Map && cached.isNotEmpty) {
        final res = <String, List<Map<String, dynamic>>>{};
        cached.forEach((k, v) {
          if (v is List) {
            res[k.toString()] = v
                .whereType<Map>()
                .map(Map<String, dynamic>.from)
                .toList();
          }
        });
        if ((res['songs']?.isNotEmpty ?? false) ||
            (res['featuredPlaylists']?.isNotEmpty ?? false) ||
            (res['communityPlaylists']?.isNotEmpty ?? false) ||
            (res['albums']?.isNotEmpty ?? false)) {
          return res;
        }
      }
    } catch (_) {}
  }

  try {
    final shelves = await ytMusicClient.music
        .getCategoryPageShelves(mood: language)
        .timeout(const Duration(seconds: 8));

    if ((shelves['songs']?.isNotEmpty ?? false) ||
        (shelves['featuredPlaylists']?.isNotEmpty ?? false) ||
        (shelves['communityPlaylists']?.isNotEmpty ?? false) ||
        (shelves['albums']?.isNotEmpty ?? false)) {
      if (Hive.isBoxOpen('cache')) {
        unawaited(addOrUpdateData('cache', cacheKey, shelves));
      }
      return shelves;
    }
  } catch (e, st) {
    logger.log(
      'Error fetching category shelves for $language:',
      error: e,
      stackTrace: st,
    );
  }

  return const {};
}

Future<List<Map<String, dynamic>>> getSuggestedAlbumsAndSingles({
  int limit = 20,
  bool forceRefresh = false,
}) async {
  String? rawLang;
  try {
    rawLang = contentLanguagePreference;
  } catch (_) {}
  rawLang ??= 'en';
  final prefLang = artistLanguageCodeToName[rawLang] ?? rawLang;

  final cacheKey = 'dynamic_home_albums_v5_$prefLang';
  var liveAlbums = <Map<String, dynamic>>[];

  // 1. Try cache if not forcing refresh and cache box is open
  if (!forceRefresh && Hive.isBoxOpen('cache')) {
    try {
      final cached = await getData('cache', cacheKey);
      if (cached is List && cached.isNotEmpty) {
        liveAlbums = cached
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
      }
    } catch (_) {}
  }

  // 2. Fetch live official new album releases from YouTube Music
  if (liveAlbums.isEmpty) {
    try {
      if (prefLang.toLowerCase() != 'english') {
        // 1. Prioritize official albums directly from YouTube Music category page
        final catShelves = await getLanguageCategoryShelves(
          prefLang,
          forceRefresh: forceRefresh,
        );
        final catAlbums = catShelves['albums'] ?? const [];
        for (final album in catAlbums) {
          final rawThumb = album['image']?.toString();
          final highResThumb = rawThumb != null
              ? formatArtworkResolution(rawThumb, 1080)
              : rawThumb;
          liveAlbums.add({
            ...album,
            if (highResThumb != null) 'image': highResThumb,
            if (highResThumb != null) 'highResImage': highResThumb,
          });
        }

        // 2. Supplement with language-specific new albums from YouTube Music search if needed
        if (liveAlbums.length < limit) {
          final langAlbums = await ytMusicClient.music
              .searchAlbums('$prefLang new albums', limit: limit)
              .timeout(const Duration(seconds: 6))
              .catchError((_) => <Map<String, dynamic>>[]);

          for (final album in langAlbums) {
            final rawThumb = album['image']?.toString();
            final highResThumb = rawThumb != null
                ? formatArtworkResolution(rawThumb, 1080)
                : rawThumb;
            liveAlbums.add({
              ...album,
              if (highResThumb != null) 'image': highResThumb,
              if (highResThumb != null) 'highResImage': highResThumb,
            });
          }
        }

        // 2. Supplement with soundtrack / movie albums if space
        if (liveAlbums.length < limit) {
          final langSoundtracks = await ytMusicClient.music
              .searchAlbums('$prefLang soundtrack', limit: limit)
              .timeout(const Duration(seconds: 6))
              .catchError((_) => <Map<String, dynamic>>[]);

          for (final album in langSoundtracks) {
            final rawThumb = album['image']?.toString();
            final highResThumb = rawThumb != null
                ? formatArtworkResolution(rawThumb, 1080)
                : rawThumb;
            liveAlbums.add({
              ...album,
              if (highResThumb != null) 'image': highResThumb,
              if (highResThumb != null) 'highResImage': highResThumb,
            });
          }
        }
      }

      // 3. Supplement with general YouTube Music new releases if needed
      if (liveAlbums.length < limit) {
        final ytmNewReleases = await ytMusicClient.music
            .getNewReleases(limit: limit)
            .timeout(const Duration(seconds: 6))
            .catchError((_) => <Map<String, dynamic>>[]);

        for (final album in ytmNewReleases) {
          final rawThumb = album['image']?.toString();
          final highResThumb = rawThumb != null
              ? formatArtworkResolution(rawThumb, 1080)
              : rawThumb;
          liveAlbums.add({
            ...album,
            if (highResThumb != null) 'image': highResThumb,
            if (highResThumb != null) 'highResImage': highResThumb,
          });
        }
      }

      // Deduplicate
      final seenIds = <String>{};
      liveAlbums = liveAlbums.where((a) {
        final id = a['ytid']?.toString() ?? '';
        return id.isNotEmpty && seenIds.add(id);
      }).toList();

      if (liveAlbums.isNotEmpty && Hive.isBoxOpen('cache')) {
        unawaited(addOrUpdateData('cache', cacheKey, liveAlbums));
      }
    } catch (e, stackTrace) {
      logger.log(
        'Dynamic albums fetch for $prefLang fallback to cache/local',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // 4. Return live albums
  if (liveAlbums.isNotEmpty) {
    return liveAlbums.take(limit).toList();
  }

  return const [];
}

Future<String?> fetchDynamicNewReleasesPlaylistId(String languageName) async {
  try {
    final yt = YoutubeHttpClient();
    final remixContext = {
      'client': {
        'clientName': 'WEB_REMIX',
        'clientVersion': '1.20240101.01.00',
        'hl': 'en',
        'gl': 'IN',
      },
    };

    // 1. Discover language category dynamically from YouTube Music
    final moodsRes = await yt
        .sendPost('browse', {
          'context': remixContext,
          'browseId': 'FEmusic_moods_and_genres',
        }, validate: true)
        .timeout(const Duration(seconds: 8));

    String? categoryParams;
    void findCategory(dynamic node) {
      if (categoryParams != null) return;
      if (node is Map && node.containsKey('musicNavigationButtonRenderer')) {
        final btn = node['musicNavigationButtonRenderer'];
        final text =
            btn['buttonText']?['runs']?[0]?['text']?.toString().toLowerCase() ??
            '';
        if (text == languageName.toLowerCase()) {
          categoryParams = btn['clickCommand']?['browseEndpoint']?['params'];
        }
      }
      if (node is Map) {
        for (final v in node.values) findCategory(v);
      } else if (node is List) {
        for (final v in node) findCategory(v);
      }
    }

    findCategory(moodsRes);

    if (categoryParams != null) {
      final genreRes = await yt
          .sendPost('browse', {
            'context': remixContext,
            'browseId': 'FEmusic_moods_and_genres_category',
            'params': categoryParams,
          }, validate: true)
          .timeout(const Duration(seconds: 8));

      String? newMusicBrowseId;
      void findNewMusic(dynamic node) {
        if (newMusicBrowseId != null) return;
        if (node is Map && node.containsKey('musicTwoRowItemRenderer')) {
          final item = node['musicTwoRowItemRenderer'];
          final title =
              (item['title']?['runs'] as List?)
                  ?.map((r) => r['text'])
                  .join()
                  .toLowerCase() ??
              '';
          if (title.contains('new music') || title.contains('hitlist')) {
            newMusicBrowseId =
                item['navigationEndpoint']?['browseEndpoint']?['browseId'];
          }
        }
        if (node is Map) {
          for (final v in node.values) findNewMusic(v);
        } else if (node is List) {
          for (final v in node) findNewMusic(v);
        }
      }

      findNewMusic(genreRes);

      final musicId = newMusicBrowseId;
      if (musicId != null) {
        return musicId.startsWith('VL') ? musicId.substring(2) : musicId;
      }
    }

    // 2. Fallback dynamically from YouTube Music FEmusic_new_releases
    final releasesRes = await yt
        .sendPost('browse', {
          'context': remixContext,
          'browseId': 'FEmusic_new_releases',
        }, validate: true)
        .timeout(const Duration(seconds: 8));

    String? fallbackPlaylistId;
    void findFallback(dynamic node) {
      if (fallbackPlaylistId != null) return;
      if (node is Map && node.containsKey('musicTwoRowItemRenderer')) {
        final item = node['musicTwoRowItemRenderer'];
        final browseId =
            item['navigationEndpoint']?['browseEndpoint']?['browseId']
                ?.toString();
        if (browseId != null &&
            (browseId.startsWith('VLRDCL') || browseId.startsWith('RDCL'))) {
          fallbackPlaylistId = browseId;
        }
      }
      if (node is Map) {
        for (final v in node.values) findFallback(v);
      } else if (node is List) {
        for (final v in node) findFallback(v);
      }
    }

    findFallback(releasesRes);

    final fbId = fallbackPlaylistId;
    if (fbId != null) {
      return fbId.startsWith('VL') ? fbId.substring(2) : fbId;
    }
  } catch (_) {}
  return null;
}

Future<List<Map<String, dynamic>>> getSuggestedNewReleases({
  int limit = 20,
  bool forceRefresh = false,
}) async {
  String? rawLang;
  try {
    rawLang = contentLanguagePreference;
  } catch (_) {}
  rawLang ??= 'en';
  final prefLang = artistLanguageCodeToName[rawLang] ?? rawLang;
  final country = contentCountryPreference;

  final cacheKey = 'ytm_home_new_releases_v5_${prefLang}_$country';
  var liveSongs = <Map<String, dynamic>>[];

  // 1. Try cache if not forcing refresh and cache box is open
  if (!forceRefresh && Hive.isBoxOpen('cache')) {
    try {
      final cached = await getData('cache', cacheKey);
      if (cached is List && cached.isNotEmpty) {
        liveSongs = cached
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
      }
    } catch (_) {}
  }

  // 2. Fetch fresh official new releases dynamically from YouTube Music Songs shelf
  if (liveSongs.isEmpty) {
    try {
      if (prefLang.toLowerCase() != 'english') {
        // 1. Prioritize official "New Music <Language>" from YouTube Music category page
        final catShelves = await getLanguageCategoryShelves(
          prefLang,
          forceRefresh: forceRefresh,
        );
        final featured = catShelves['featuredPlaylists'] ?? const [];
        final newMusicPl = featured.firstWhere((pl) {
          final t = pl['title']?.toString().toLowerCase() ?? '';
          return t.contains('new music') || t.contains('latest');
        }, orElse: () => <String, dynamic>{});

        if (newMusicPl['ytid'] != null) {
          try {
            final plData = await ytMusicClient.music
                .getPlaylist(newMusicPl['ytid'].toString())
                .timeout(const Duration(seconds: 8));
            for (final (index, track) in plData.tracks.indexed) {
              liveSongs.add(returnSongLayout(index, track));
              if (liveSongs.length >= limit) break;
            }
          } catch (_) {}
        }

        // 2. Supplement with latest language audio songs from YouTube Music Songs shelf
        if (liveSongs.length < limit) {
          final latestSongs = await ytMusicClient.music
              .searchSongs('Latest $prefLang songs', limit: limit)
              .timeout(const Duration(seconds: 6))
              .catchError((_) => <Video>[]);
          for (final (index, song) in latestSongs.indexed) {
            if (!liveSongs.any((s) => s['ytid'] == song.id.value)) {
              liveSongs.add(returnSongLayout(liveSongs.length + index, song));
            }
          }
        }

        // 3. Supplement with language new release audio tracks
        if (liveSongs.length < limit) {
          final releaseSongs = await ytMusicClient.music
              .searchSongs('$prefLang new releases', limit: limit)
              .timeout(const Duration(seconds: 6))
              .catchError((_) => <Video>[]);
          for (final (index, song) in releaseSongs.indexed) {
            if (!liveSongs.any((s) => s['ytid'] == song.id.value)) {
              liveSongs.add(returnSongLayout(liveSongs.length + index, song));
            }
          }
        }
      }

      // 3. Supplement with global latest songs if needed
      if (liveSongs.length < limit) {
        final globalLatest = await ytMusicClient.music
            .searchSongs('Latest songs', limit: limit)
            .timeout(const Duration(seconds: 6))
            .catchError((_) => <Video>[]);
        for (final (index, song) in globalLatest.indexed) {
          if (!liveSongs.any((s) => s['ytid'] == song.id.value)) {
            liveSongs.add(returnSongLayout(liveSongs.length + index, song));
          }
        }
      }

      // Deduplicate
      final seenIds = <String>{};
      liveSongs = liveSongs.where((s) {
        final id = s['ytid']?.toString() ?? '';
        return id.isNotEmpty && seenIds.add(id);
      }).toList();

      if (liveSongs.isNotEmpty && Hive.isBoxOpen('cache')) {
        unawaited(addOrUpdateData('cache', cacheKey, liveSongs));
      }
    } catch (e, stackTrace) {
      logger.log(
        'Dynamic new releases fetch for $prefLang failed:',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // 3. Return fresh new releases
  if (liveSongs.isNotEmpty) {
    return liveSongs.take(limit).toList();
  }

  return const [];
}

const _moodKeywords = <String, List<String>>{
  'romance': ['romance', 'love', 'romantic', 'heartbreak'],
  'party': ['party', 'dance', 'kuthu', 'club', 'dj'],
  'workout': ['workout', 'energy', 'gym', 'motivat'],
  'chill': ['chill', 'dream', 'lounge', 'relax', 'peace', 'traffic'],
  'feel good': ['feel good', 'happy', 'road trip', 'sing-along'],
  'energy': ['energy', 'workout', 'kuthu', 'dance', 'hip hop', 'booster'],
  'focus': ['chill', 'lounge', 'dream', 'peace', 'instrumental'],
};

Future<List<Map<String, dynamic>>> getFeaturedMoodPlaylists({
  String mood = 'All',
  bool forceRefresh = false,
  int limit = 20,
}) async {
  String? rawLang;
  try {
    rawLang = contentLanguagePreference;
  } catch (_) {}
  rawLang ??= 'en';

  final prefLang = artistLanguageCodeToName[rawLang] ?? rawLang;
  final cleanMood = mood.trim().toLowerCase();
  final cacheKey = 'ytm_mood_playlists_v4_${cleanMood}_$prefLang';
  var livePlaylists = <Map<String, dynamic>>[];

  if (!forceRefresh && Hive.isBoxOpen('cache')) {
    try {
      final cached = await getData('cache', cacheKey);
      if (cached is List && cached.isNotEmpty) {
        livePlaylists = cached
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
      }
    } catch (_) {}
  }

  if (livePlaylists.isEmpty) {
    try {
      if (prefLang.toLowerCase() != 'english') {
        // 1. Fetch the official category page shelves for the user's chosen language!
        final catShelves = await getLanguageCategoryShelves(
          prefLang,
          forceRefresh: forceRefresh,
        );
        final featuredPlaylists = catShelves['featuredPlaylists'] ?? const [];

        if (cleanMood == 'all' ||
            cleanMood == 'featured' ||
            cleanMood == prefLang.toLowerCase()) {
          // Show all official featured playlists of the language (e.g. Kollywood Hitlist, New Music Tamil, etc.)
          for (final pl in featuredPlaylists) {
            final title = pl['title']?.toString() ?? '';
            if (_isForbiddenVideoPlaylist(title)) continue;
            final rawThumb = pl['image']?.toString();
            final highResThumb = rawThumb != null
                ? formatArtworkResolution(rawThumb, 1080)
                : rawThumb;
            livePlaylists.add({
              ...pl,
              if (highResThumb != null) 'image': highResThumb,
              if (highResThumb != null) 'highResImage': highResThumb,
            });
          }
        } else {
          // Filter the language's official featured playlists matching this mood
          final keywords = _moodKeywords[cleanMood] ?? [cleanMood];
          for (final pl in featuredPlaylists) {
            final title = (pl['title']?.toString() ?? '').toLowerCase();
            if (keywords.any(title.contains)) {
              if (_isForbiddenVideoPlaylist(pl['title']?.toString() ?? ''))
                continue;
              final rawThumb = pl['image']?.toString();
              final highResThumb = rawThumb != null
                  ? formatArtworkResolution(rawThumb, 1080)
                  : rawThumb;
              livePlaylists.add({
                ...pl,
                if (highResThumb != null) 'image': highResThumb,
                if (highResThumb != null) 'highResImage': highResThumb,
              });
            }
          }

          // Supplement with language-specific mood playlist search
          if (livePlaylists.length < limit) {
            final langMoodPlaylists = await ytMusicClient.music
                .searchPlaylists('$prefLang $mood playlist', limit: limit)
                .timeout(const Duration(seconds: 6))
                .catchError((_) => <Map<String, dynamic>>[]);

            for (final pl in langMoodPlaylists) {
              final title = pl['title']?.toString() ?? '';
              if (_isForbiddenVideoPlaylist(title)) continue;
              if (livePlaylists.any((p) => p['ytid'] == pl['ytid'])) continue;
              final rawThumb = pl['image']?.toString();
              final highResThumb = rawThumb != null
                  ? formatArtworkResolution(rawThumb, 1080)
                  : rawThumb;
              livePlaylists.add({
                ...pl,
                if (highResThumb != null) 'image': highResThumb,
                if (highResThumb != null) 'highResImage': highResThumb,
              });
            }
          }
        }
      }

      // 2. Global mood category fallback (for English users or when language results empty)
      if (livePlaylists.isEmpty) {
        final moodShelves = await getLanguageCategoryShelves(
          cleanMood,
          forceRefresh: forceRefresh,
        );
        final officialMoodPlaylists =
            moodShelves['featuredPlaylists'] ?? const [];
        for (final pl in officialMoodPlaylists) {
          final title = pl['title']?.toString() ?? '';
          if (_isForbiddenVideoPlaylist(title)) continue;
          final rawThumb = pl['image']?.toString();
          final highResThumb = rawThumb != null
              ? formatArtworkResolution(rawThumb, 1080)
              : rawThumb;
          livePlaylists.add({
            ...pl,
            if (highResThumb != null) 'image': highResThumb,
            if (highResThumb != null) 'highResImage': highResThumb,
          });
        }
      }

      if (livePlaylists.isNotEmpty && Hive.isBoxOpen('cache')) {
        unawaited(addOrUpdateData('cache', cacheKey, livePlaylists));
      }
    } catch (e, st) {
      logger.log(
        'Error fetching YTM mood playlists for $mood in $prefLang:',
        error: e,
        stackTrace: st,
      );
    }
  }

  if (livePlaylists.isNotEmpty) {
    for (final p in livePlaylists) {
      if (!playlists.any((item) => item['ytid'] == p['ytid'])) {
        playlists.add(p);
      }
    }
    return livePlaylists.take(limit).toList();
  }

  return const [];
}

Future<List<Map<String, dynamic>>> getTrendingSongsForYou({
  bool forceRefresh = false,
  int limit = 20,
}) async {
  String? rawLang;
  try {
    rawLang = contentLanguagePreference;
  } catch (_) {}
  rawLang ??= 'en';
  final prefLang = artistLanguageCodeToName[rawLang] ?? rawLang;
  final country = contentCountryPreference;

  final cacheKey = 'ytm_pure_audio_trending_v6_${prefLang}_$country';
  var liveSongs = <Map<String, dynamic>>[];

  if (!forceRefresh && Hive.isBoxOpen('cache')) {
    try {
      final cached = await getData('cache', cacheKey);
      if (cached is List && cached.isNotEmpty) {
        liveSongs = cached
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
      }
    } catch (_) {}
  }

  if (liveSongs.isEmpty) {
    try {
      final countryName = getCountryByCode(country).name;
      final query = prefLang.toLowerCase() == 'english'
          ? (country == 'US'
                ? 'Trending songs USA'
                : 'Trending songs $countryName')
          : 'Trending $prefLang';

      // 1. Primary: YouTube Music Official Trending Songs (dedicated Songs search filter)
      final ytmTrending = await ytMusicClient.music
          .searchSongs(query, limit: limit)
          .timeout(const Duration(seconds: 8))
          .catchError((_) => <Video>[]);

      for (final (index, song) in ytmTrending.indexed) {
        final songMap = returnSongLayout(index, song);
        songMap['chartRank'] = index + 1;
        liveSongs.add(songMap);
      }

      // 2. Supplement if needed with $prefLang Trending songs from YouTube Music
      if (liveSongs.length < limit) {
        final moreTrending = await ytMusicClient.music
            .searchSongs('$prefLang Trending', limit: limit)
            .timeout(const Duration(seconds: 6))
            .catchError((_) => <Video>[]);

        for (final song in moreTrending) {
          if (!liveSongs.any((s) => s['ytid'] == song.id.value)) {
            final songMap = returnSongLayout(liveSongs.length, song);
            songMap['chartRank'] = liveSongs.length + 1;
            liveSongs.add(songMap);
            if (liveSongs.length >= limit) break;
          }
        }
      }

      // 3. Fallback to YouTube Music category songs shelf if needed
      if (liveSongs.isEmpty && prefLang.toLowerCase() != 'english') {
        final catShelves = await getLanguageCategoryShelves(
          prefLang,
          forceRefresh: forceRefresh,
        );
        final catSongs = catShelves['songs'] ?? const [];
        for (final (index, s) in catSongs.indexed) {
          final ytid = s['ytid']?.toString() ?? '';
          if (ytid.isEmpty) continue;
          final rawThumb = s['image']?.toString();
          final highRes = rawThumb != null
              ? formatArtworkResolution(rawThumb, 1080)
              : null;
          final lowRes = rawThumb != null
              ? formatArtworkResolution(rawThumb, 544)
              : null;
          liveSongs.add({
            'id': index,
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
            'chartRank': index + 1,
            'isLive': false,
            'source': 'youtube-music',
          });
        }
      }

      // 4. Global YouTube Music Trending fallback
      if (liveSongs.isEmpty) {
        final globalTrending = await ytMusicClient.music
            .searchSongs('Trending songs', limit: limit)
            .timeout(const Duration(seconds: 6))
            .catchError((_) => <Video>[]);

        for (final (index, song) in globalTrending.indexed) {
          final songMap = returnSongLayout(index, song);
          songMap['chartRank'] = index + 1;
          liveSongs.add(songMap);
        }
      }

      // Deduplicate
      final seenIds = <String>{};
      liveSongs = liveSongs.where((s) {
        final id = s['ytid']?.toString() ?? '';
        return id.isNotEmpty && seenIds.add(id);
      }).toList();

      if (liveSongs.isNotEmpty && Hive.isBoxOpen('cache')) {
        unawaited(addOrUpdateData('cache', cacheKey, liveSongs));
      }
    } catch (e, st) {
      logger.log(
        'Error fetching trending songs for $prefLang:',
        error: e,
        stackTrace: st,
      );
    }
  }

  return liveSongs.take(limit).toList();
}

final Map<String, Future<List<Map<String, dynamic>>>> _quickPicksInFlight = {};

Future<List<Map<String, dynamic>>> getQuickPicksSongs({
  bool forceRefresh = false,
  int limit = 16,
}) {
  String? rawLang;
  try {
    rawLang = contentLanguagePreference;
  } catch (_) {}
  rawLang ??= 'en';
  final prefLang = artistLanguageCodeToName[rawLang] ?? rawLang;
  final inFlightKey = '$prefLang|$forceRefresh|$limit';

  final existing = _quickPicksInFlight[inFlightKey];
  if (existing != null) {
    return existing;
  }

  late final Future<List<Map<String, dynamic>>> tracked;
  tracked =
      _loadQuickPicksSongs(
        prefLang: prefLang,
        forceRefresh: forceRefresh,
        limit: limit,
      ).whenComplete(() {
        if (identical(_quickPicksInFlight[inFlightKey], tracked)) {
          _quickPicksInFlight.remove(inFlightKey);
        }
      });

  _quickPicksInFlight[inFlightKey] = tracked;
  return tracked;
}

Future<List<Map<String, dynamic>>> _loadQuickPicksSongs({
  required String prefLang,
  required bool forceRefresh,
  required int limit,
}) async {
  final cacheKey = 'ytm_quick_picks_songs_v3_$prefLang';
  var liveSongs = <Map<String, dynamic>>[];

  if (!forceRefresh && Hive.isBoxOpen('cache')) {
    try {
      final cached = await getData('cache', cacheKey);
      if (cached is List && cached.isNotEmpty) {
        liveSongs = cached
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
      }
    } catch (_) {}
  }

  if (liveSongs.isEmpty) {
    try {
      final isRegional = prefLang.toLowerCase() != 'english';
      String? seedId;

      // 1. For regional language, prioritize language category songs directly
      if (isRegional) {
        try {
          final catShelves = await getLanguageCategoryShelves(
            prefLang,
            forceRefresh: forceRefresh,
          );
          final catSongs = catShelves['songs'] ?? const [];
          if (catSongs.isNotEmpty) {
            for (final s in catSongs) {
              final ytid = s['ytid']?.toString();
              if (seedId == null && ytid != null && ytid.length == 11) {
                seedId = ytid;
              }
              if (liveSongs.length < limit) {
                liveSongs.add(Map<String, dynamic>.from(s));
              }
            }
          }
        } catch (_) {}
      }

      // If category already supplied sufficient songs (e.g. 16), skip expensive radio network call!
      if (liveSongs.length < limit) {
        // 2. If seedId still null, check recent songs or liked songs
        if (seedId == null || seedId.isEmpty) {
          if (Hive.isBoxOpen('user')) {
            try {
              final box = Hive.box('user');
              final recents = box.get('recentSongs', defaultValue: <dynamic>[]);
              if (recents is List && recents.isNotEmpty) {
                for (final item in recents.reversed) {
                  if (item is Map &&
                      item['ytid'] != null &&
                      item['ytid'].toString().length == 11) {
                    seedId = item['ytid'].toString();
                    break;
                  }
                }
              }

              if (seedId == null || seedId.isEmpty) {
                final liked = box.get('likedSongs', defaultValue: <dynamic>[]);
                if (liked is List && liked.isNotEmpty) {
                  final lastLiked = liked.last;
                  if (lastLiked is Map &&
                      lastLiked['ytid'] != null &&
                      lastLiked['ytid'].toString().length == 11) {
                    seedId = lastLiked['ytid'].toString();
                  }
                }
              }
            } catch (_) {}
          }
        }

        // 3. If still null, fetch top trending song of the language
        if (seedId == null || seedId.isEmpty) {
          final trending = await getTrendingSongsForYou(limit: 5);
          if (trending.isNotEmpty && trending.first['ytid'] != null) {
            seedId = trending.first['ytid'].toString();
          }
        }

        // 4. Fetch YouTube Music radio automix tracks only for remaining needed slots
        if (seedId != null && seedId.isNotEmpty) {
          final needed = limit - liveSongs.length;
          final radioTracks = await ytMusicClient.music
              .getRadioSongs(seedId, limit: needed)
              .timeout(const Duration(seconds: 4))
              .catchError((_) => <Video>[]);

          for (var i = 0; i < radioTracks.length; i++) {
            final track = radioTracks[i];
            final layout = returnSongLayout(i, track);
            if (!liveSongs.any((s) => s['ytid'] == layout['ytid'])) {
              liveSongs.add(layout);
            }
            if (liveSongs.length >= limit) break;
          }
        }

        // 5. Fallback: if radio returned fewer, supplement with language trending songs
        if (liveSongs.length < 8) {
          final trending = await getTrendingSongsForYou(
            forceRefresh: forceRefresh,
            limit: limit,
          );
          for (final s in trending) {
            if (!liveSongs.any((x) => x['ytid'] == s['ytid'])) {
              liveSongs.add(Map<String, dynamic>.from(s));
            }
            if (liveSongs.length >= limit) break;
          }
        }
      }

      if (liveSongs.isNotEmpty && Hive.isBoxOpen('cache')) {
        unawaited(addOrUpdateData('cache', cacheKey, liveSongs));
      }
    } catch (e, st) {
      logger.log('Error fetching quick picks songs:', error: e, stackTrace: st);
    }
  }

  return liveSongs.take(limit).toList();
}

/// Fetches official editorial featured playlists for the user's selected language.
Future<List<Map<String, dynamic>>> getFeaturedPlaylists({
  bool forceRefresh = false,
  int limit = 20,
}) async {
  String? rawLang;
  try {
    rawLang = contentLanguagePreference;
  } catch (_) {}
  rawLang ??= 'en';

  final prefLang = artistLanguageCodeToName[rawLang] ?? rawLang;
  final cacheKey = 'ytm_featured_playlists_v2_$prefLang';
  var livePlaylists = <Map<String, dynamic>>[];

  if (!forceRefresh && Hive.isBoxOpen('cache')) {
    try {
      final cached = await getData('cache', cacheKey);
      if (cached is List && cached.isNotEmpty) {
        livePlaylists = cached
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
      }
    } catch (_) {}
  }

  if (livePlaylists.isEmpty) {
    try {
      if (prefLang.toLowerCase() != 'english') {
        // 1. Official YouTube Music featured editorial playlists from category page
        final catShelves = await getLanguageCategoryShelves(
          prefLang,
          forceRefresh: forceRefresh,
        );
        final featured = catShelves['featuredPlaylists'] ?? const [];
        for (final pl in featured) {
          final title = pl['title']?.toString() ?? '';
          if (_isForbiddenVideoPlaylist(title)) continue;

          // Exclude community/activity titles (these belong in Trending Community Playlists)
          final lower = title.toLowerCase();
          if (lower.contains('workout') ||
              lower.contains('car playlist') ||
              lower.contains('gym') ||
              lower.contains('fav') ||
              lower.contains('driving') ||
              lower.contains('vibes')) {
            continue;
          }

          final rawThumb = pl['image']?.toString();
          final highResThumb = rawThumb != null
              ? formatArtworkResolution(rawThumb, 1080)
              : rawThumb;
          livePlaylists.add({
            ...pl,
            if (highResThumb != null) 'image': highResThumb,
            if (highResThumb != null) 'highResImage': highResThumb,
            'source': 'youtube-music-playlist',
          });
        }

        // 2. Supplement with official chart playlists (e.g. Top Weekly Videos $prefLang)
        if (livePlaylists.length < limit) {
          final chartPlaylists = await ytMusicClient.music
              .getLanguageTopWeeklyPlaylists()
              .timeout(const Duration(seconds: 5))
              .catchError((_) => <String, String>{});

          final targetLang = prefLang.toLowerCase();
          for (final entry in chartPlaylists.entries) {
            if (entry.key.contains(targetLang) ||
                targetLang.contains(entry.key)) {
              final plId = entry.value;
              if (plId.isNotEmpty &&
                  !livePlaylists.any((p) => p['ytid'] == plId)) {
                livePlaylists.add({
                  'ytid': plId,
                  'title': 'Top Weekly Videos $prefLang',
                  'artist': 'YouTube Music Charts',
                  'image': null,
                  'source': 'youtube-music-playlist',
                });
              }
            }
          }
        }

        // 3. Official curated search for language flagship hits if still space
        if (livePlaylists.length < limit) {
          final officialSearch = await ytMusicClient.music
              .searchPlaylists('$prefLang Hits official playlist', limit: 8)
              .timeout(const Duration(seconds: 5))
              .catchError((_) => <Map<String, dynamic>>[]);

          for (final pl in officialSearch) {
            final title = pl['title']?.toString() ?? '';
            if (_isForbiddenVideoPlaylist(title)) continue;
            final lower = title.toLowerCase();
            if (lower.contains('workout') ||
                lower.contains('car') ||
                lower.contains('fav') ||
                lower.contains('gym')) {
              continue;
            }

            final rawThumb = pl['image']?.toString();
            final highResThumb = rawThumb != null
                ? formatArtworkResolution(rawThumb, 1080)
                : rawThumb;
            if (!livePlaylists.any((p) => p['ytid'] == pl['ytid'])) {
              livePlaylists.add({
                ...pl,
                if (highResThumb != null) 'image': highResThumb,
                if (highResThumb != null) 'highResImage': highResThumb,
                'source': 'youtube-music-playlist',
              });
            }
            if (livePlaylists.length >= limit) break;
          }
        }
      }

      // 4. English / Global official playlists
      if (livePlaylists.length < limit) {
        final homePlaylists = await ytMusicClient.music
            .getHomePlaylists(limit: limit)
            .timeout(const Duration(seconds: 5))
            .catchError((_) => <Map<String, dynamic>>[]);

        for (final pl in homePlaylists) {
          final title = pl['title']?.toString() ?? '';
          if (_isForbiddenVideoPlaylist(title)) continue;
          final rawThumb = pl['image']?.toString();
          final highResThumb = rawThumb != null
              ? formatArtworkResolution(rawThumb, 1080)
              : rawThumb;
          if (!livePlaylists.any((p) => p['ytid'] == pl['ytid'])) {
            livePlaylists.add({
              ...pl,
              if (highResThumb != null) 'image': highResThumb,
              if (highResThumb != null) 'highResImage': highResThumb,
              'source': 'youtube-music-playlist',
            });
          }
          if (livePlaylists.length >= limit) break;
        }
      }

      if (livePlaylists.isNotEmpty && Hive.isBoxOpen('cache')) {
        unawaited(addOrUpdateData('cache', cacheKey, livePlaylists));
      }
    } catch (e, st) {
      logger.log(
        'Error fetching featured playlists for $prefLang:',
        error: e,
        stackTrace: st,
      );
    }
  }

  return livePlaylists.take(limit).toList();
}

/// Fetches community, mood, and activity playlists (e.g., Tamil fav, Workout, Car playlist, Vibes).
Future<List<Map<String, dynamic>>> getTrendingCommunityPlaylists({
  bool forceRefresh = false,
  int limit = 20,
}) async {
  String? rawLang;
  try {
    rawLang = contentLanguagePreference;
  } catch (_) {}
  rawLang ??= 'en';

  final prefLang = artistLanguageCodeToName[rawLang] ?? rawLang;
  final cacheKey = 'ytm_trending_community_playlists_v4_$prefLang';
  var livePlaylists = <Map<String, dynamic>>[];

  if (!forceRefresh && Hive.isBoxOpen('cache')) {
    try {
      final cached = await getData('cache', cacheKey);
      if (cached is List && cached.isNotEmpty) {
        livePlaylists = cached
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
      }
    } catch (_) {}
  }

  if (livePlaylists.isEmpty) {
    try {
      if (prefLang.toLowerCase() != 'english') {
        // 1. Prioritize exact community playlists directly from YouTube Music category page
        final catShelves = await getLanguageCategoryShelves(
          prefLang,
          forceRefresh: forceRefresh,
        );
        final catCommunity = catShelves['communityPlaylists'] ?? const [];
        for (final pl in catCommunity) {
          final title = pl['title']?.toString() ?? '';
          if (_isForbiddenVideoPlaylist(title)) continue;
          final rawThumb = pl['image']?.toString();
          final highResThumb = rawThumb != null
              ? formatArtworkResolution(rawThumb, 1080)
              : rawThumb;
          livePlaylists.add({
            ...pl,
            if (highResThumb != null) 'image': highResThumb,
            if (highResThumb != null) 'highResImage': highResThumb,
            'source': 'youtube-music-playlist',
          });
        }

        // 2. Discover user/community playlists for the language: e.g. "Tamil fav", "Workout", "Car playlist", "Vibes"
        final searchQueries = [
          '$prefLang favorites playlist',
          '$prefLang workout playlist',
          '$prefLang car driving playlist',
          '$prefLang vibes playlist',
        ];

        for (final query in searchQueries) {
          if (livePlaylists.length >= limit) break;
          try {
            final results = await ytMusicClient.music
                .searchPlaylists(query, limit: 6)
                .timeout(const Duration(seconds: 4))
                .catchError((_) => <Map<String, dynamic>>[]);

            for (final pl in results) {
              final title = pl['title']?.toString() ?? '';
              if (_isForbiddenVideoPlaylist(title)) continue;
              final rawThumb = pl['image']?.toString();
              final highResThumb = rawThumb != null
                  ? formatArtworkResolution(rawThumb, 1080)
                  : rawThumb;
              if (!livePlaylists.any((p) => p['ytid'] == pl['ytid'])) {
                livePlaylists.add({
                  ...pl,
                  if (highResThumb != null) 'image': highResThumb,
                  if (highResThumb != null) 'highResImage': highResThumb,
                  'source': 'youtube-music-playlist',
                });
              }
              if (livePlaylists.length >= limit) break;
            }
          } catch (_) {}
        }
      }

      // 3. Supplement with general community playlists if still space
      if (livePlaylists.length < limit) {
        final generalQueries = [
          'Top Hits playlist',
          'Today Trending Hits playlist',
          'Workout driving favorites playlist',
        ];

        for (final query in generalQueries) {
          if (livePlaylists.length >= limit) break;
          try {
            final generalPlaylists = await ytMusicClient.music
                .searchPlaylists(query, limit: limit)
                .timeout(const Duration(seconds: 5))
                .catchError((_) => <Map<String, dynamic>>[]);

            for (final pl in generalPlaylists) {
              final title = pl['title']?.toString() ?? '';
              if (_isForbiddenVideoPlaylist(title)) continue;
              final rawThumb = pl['image']?.toString();
              final highResThumb = rawThumb != null
                  ? formatArtworkResolution(rawThumb, 1080)
                  : rawThumb;
              if (!livePlaylists.any((p) => p['ytid'] == pl['ytid'])) {
                livePlaylists.add({
                  ...pl,
                  if (highResThumb != null) 'image': highResThumb,
                  if (highResThumb != null) 'highResImage': highResThumb,
                  'source': 'youtube-music-playlist',
                });
              }
              if (livePlaylists.length >= limit) break;
            }
          } catch (_) {}
        }
      }

      if (livePlaylists.isNotEmpty && Hive.isBoxOpen('cache')) {
        unawaited(addOrUpdateData('cache', cacheKey, livePlaylists));
      }
    } catch (e, st) {
      logger.log(
        'Error fetching trending community playlists:',
        error: e,
        stackTrace: st,
      );
    }
  }

  if (livePlaylists.isNotEmpty) {
    for (final p in livePlaylists) {
      if (!playlists.any((item) => item['ytid'] == p['ytid'])) {
        playlists.add(p);
      }
    }
    return livePlaylists.take(limit).toList();
  }

  return getFeaturedPlaylists(forceRefresh: forceRefresh, limit: limit);
}

/// Fetches fresh YouTube Music automix recommendations based on the user's recent & liked tracks.
Future<List<Map<String, dynamic>>> getMadeForYouRecommendations({
  bool forceRefresh = false,
  int limit = 16,
  bool allowNetwork = true,
}) async {
  const cacheKey = 'ytm_made_for_you_recs_v1';
  var liveRecs = <Map<String, dynamic>>[];

  if (!forceRefresh && Hive.isBoxOpen('cache')) {
    try {
      final cached = await getData('cache', cacheKey);
      if (cached is List && cached.isNotEmpty) {
        liveRecs = cached
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
      }
    } catch (_) {}
  }

  // Cached home feeds should be allowed to render immediately. A network
  // recommendation lookup can take several seconds and must not block the
  // cached first frame.
  if (liveRecs.isEmpty && !allowNetwork) {
    return const [];
  }

  if (liveRecs.isEmpty) {
    try {
      final seedIds = <String>[];
      if (Hive.isBoxOpen('user')) {
        try {
          final box = Hive.box('user');
          final recents = box.get('recentSongs', defaultValue: <dynamic>[]);
          if (recents is List && recents.isNotEmpty) {
            for (final item in recents.reversed) {
              if (item is Map &&
                  item['ytid'] != null &&
                  item['ytid'].toString().length == 11) {
                seedIds.add(item['ytid'].toString());
                if (seedIds.length >= 2) break;
              }
            }
          }

          if (seedIds.isEmpty) {
            final liked = box.get('likedSongs', defaultValue: <dynamic>[]);
            if (liked is List && liked.isNotEmpty) {
              for (final item in liked.reversed) {
                if (item is Map &&
                    item['ytid'] != null &&
                    item['ytid'].toString().length == 11) {
                  seedIds.add(item['ytid'].toString());
                  if (seedIds.length >= 2) break;
                }
              }
            }
          }
        } catch (_) {}
      }

      final radioFutures = seedIds.take(2).map((seed) {
        return ytMusicClient.music
            .getRadioSongs(seed, limit: limit)
            .timeout(const Duration(seconds: 4))
            .catchError((_) => <Video>[]);
      }).toList();

      final radioResults = await Future.wait(radioFutures);
      for (final radioTracks in radioResults) {
        for (var i = 0; i < radioTracks.length; i++) {
          final track = radioTracks[i];
          final layout = returnSongLayout(liveRecs.length + i, track);
          if (!liveRecs.any((s) => s['ytid'] == layout['ytid'])) {
            liveRecs.add(layout);
          }
          if (liveRecs.length >= limit) break;
        }
        if (liveRecs.length >= limit) break;
      }

      // Fetch fresh tracks by top listened artist for "Because you listened to <artist> / MORE FROM THIS ARTIST"
      try {
        final signals = PersonalizationService.instance.getUserSignals();
        final candidateArtists = PersonalizationService.instance
            .getCandidateArtists(signals, limit: 2);
        final artistFutures = candidateArtists.map((artistName) {
          if (artistName.isEmpty) return Future.value(<Video>[]);
          return ytMusicClient.music
              .searchSongs(artistName)
              .timeout(const Duration(seconds: 4))
              .catchError((_) => <Video>[]);
        }).toList();

        final artistResults = await Future.wait(artistFutures);
        for (final artistTracks in artistResults) {
          for (var i = 0; i < artistTracks.length; i++) {
            final track = artistTracks[i];
            final layout = returnSongLayout(liveRecs.length + i, track);
            if (!liveRecs.any((s) => s['ytid'] == layout['ytid'])) {
              liveRecs.add(layout);
            }
            if (liveRecs.length >= limit * 2) break;
          }
        }
      } catch (_) {}

      if (liveRecs.isNotEmpty && Hive.isBoxOpen('cache')) {
        unawaited(addOrUpdateData('cache', cacheKey, liveRecs));
      }
    } catch (e, st) {
      logger.log(
        'Error fetching Made for you recommendations:',
        error: e,
        stackTrace: st,
      );
    }
  }

  return liveRecs;
}

/// Fetches fresh songs for a specific artist recommendation.
/// Caches results per artist in Hive 'cache' box.
Future<List<Map<String, dynamic>>> getSongsForArtistRecommendation(
  String artistName, {
  bool forceRefresh = false,
  bool allowNetwork = true,
  int limit = 12,
}) async {
  final cleanName = artistName.trim();
  if (cleanName.isEmpty) return const [];

  final sanitizedKey = cleanName
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]'), '_')
      .replaceAll(RegExp('_+'), '_');
  final cacheKey = 'ytm_artist_rec_v2_$sanitizedKey';
  var liveSongs = <Map<String, dynamic>>[];

  if (!forceRefresh && Hive.isBoxOpen('cache')) {
    try {
      final cached = await getData('cache', cacheKey);
      if (cached is List && cached.isNotEmpty) {
        liveSongs = cached
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
      }
    } catch (_) {}
  }

  if (liveSongs.isEmpty && !allowNetwork) {
    return const [];
  }

  if (liveSongs.isEmpty && !offlineMode.value) {
    try {
      final results = await ytMusicClient.music
          .searchSongs(cleanName)
          .timeout(const Duration(seconds: 4))
          .catchError((_) => <Video>[]);

      for (var i = 0; i < results.length; i++) {
        final video = results[i];
        final layout = returnSongLayout(i, video);
        if (!liveSongs.any((s) => s['ytid'] == layout['ytid'])) {
          liveSongs.add(layout);
        }
        if (liveSongs.length >= limit) break;
      }

      if (liveSongs.isNotEmpty && Hive.isBoxOpen('cache')) {
        unawaited(addOrUpdateData('cache', cacheKey, liveSongs));
      }
    } catch (e, st) {
      logger.log(
        'Error fetching artist recommendation for $cleanName:',
        error: e,
        stackTrace: st,
      );
    }
  }

  return liveSongs;
}

Future<List<dynamic>> getUserPlaylistsNotInFolders() async {
  final playlistsInFolders = <String>{};
  for (final folder in userPlaylistFolders.value) {
    final folderPlaylists = folder['playlists'] as List<dynamic>? ?? [];
    for (final playlist in folderPlaylists) {
      if (playlist['ytid'] != null && playlist['source'] == 'user-youtube') {
        playlistsInFolders.add(playlist['ytid']);
      }
    }
  }

  final allUserPlaylists = await getUserPlaylists();
  return allUserPlaylists.where((playlist) {
    return !playlistsInFolders.contains(playlist['ytid']);
  }).toList();
}

bool playlistExistsAnywhere(String playlistId) {
  final normalizedId = playlistId.trim();
  if (normalizedId.isEmpty) return false;

  if (userPlaylists.value.any((id) => id == normalizedId)) {
    return true;
  }

  if (userCustomPlaylists.value.any(
    (p) => p['ytid']?.toString() == normalizedId,
  )) {
    return true;
  }

  for (final folder in userPlaylistFolders.value) {
    final folderPlaylists = folder['playlists'] as List<dynamic>? ?? [];
    if (folderPlaylists.any((p) => p['ytid']?.toString() == normalizedId)) {
      return true;
    }
  }

  return false;
}

int findPlaylistIndexByYtId(String ytid) {
  for (var i = 0; i < playlists.length; i++) {
    if (playlists[i]['ytid'] == ytid) {
      return i;
    }
  }
  return -1;
}

Future<Map?> getPlaylistInfoForWidget(
  dynamic id, {
  bool isArtist = false,
  String? artistName,
  String? artistImage,
  String? sourceSongId,
  String? sourceVideoAuthor,
  bool preferredVerified = false,
  bool forceRefresh = false,
}) async {
  if (id == null) return null;
  final normalizedId = id.toString().trim();
  if (normalizedId.isEmpty || normalizedId == 'null') return null;
  if (isArtist) {
    final offlineArtist = _findOfflinePlaylist(normalizedId);
    if (offlineArtist != null && (!forceRefresh || offlineMode.value)) {
      return offlineArtist;
    }
    if (offlineMode.value) return null;

    return getArtistCatalog(
      normalizedId,
      preferredName: artistName,
      preferredImage: artistImage,
      sourceSongId: sourceSongId,
      sourceVideoAuthor: sourceVideoAuthor,
      forceRefresh: forceRefresh,
      preferredVerified: preferredVerified,
    );
  }
  if (normalizedId.startsWith('customId-')) {
    return _findCustomPlaylist(normalizedId)?.playlist;
  }

  final offlinePlaylist = _findOfflinePlaylist(normalizedId);
  if (offlinePlaylist != null) return offlinePlaylist;

  return _fetchYouTubePlaylist(normalizedId);
}

Future<Map<String, dynamic>?> resolveArtistInfoForWidget(
  dynamic id, {
  String? artistName,
  String? artistImage,
  String? sourceSongId,
  String? sourceVideoAuthor,
  bool preferredVerified = false,
}) async {
  if (id == null) return null;
  final normalizedId = id.toString().trim();
  if (normalizedId.isEmpty || normalizedId == 'null') return null;

  final offlineArtist = _findOfflinePlaylist(normalizedId);
  if (offlineArtist != null) {
    return Map<String, dynamic>.from(offlineArtist);
  }
  if (offlineMode.value) return null;

  final artist = await resolveArtist(
    normalizedId,
    preferredName: artistName,
    preferredImage: artistImage,
    sourceSongId: sourceSongId,
    sourceVideoAuthor: sourceVideoAuthor,
    preferredVerified: preferredVerified,
  );

  if (artist == null) {
    logger.log(
      'No official artist channel found for "$normalizedId"'
      '${artistName == null ? '' : ' ($artistName)'}',
    );
    return null;
  }

  return {...artist, 'source': 'youtube-artist', 'isArtist': true, 'list': []};
}

({Map playlist, bool isFromFolder})? _findCustomPlaylist(String playlistId) {
  if (!_customPlaylistListenersAttached) {
    _customPlaylistListenersAttached = true;
    userCustomPlaylists.addListener(() => _customPlaylistIndexCache = null);
    userPlaylistFolders.addListener(() => _customPlaylistIndexCache = null);
  }

  if (_customPlaylistIndexCache != null) {
    return _customPlaylistIndexCache![playlistId];
  }

  final index = <String, ({Map playlist, bool isFromFolder})>{};
  for (final playlist in userCustomPlaylists.value) {
    final id = playlist['ytid']?.toString();
    if (id != null) {
      index[id] = (playlist: playlist, isFromFolder: false);
    }
  }
  for (final folder in userPlaylistFolders.value) {
    final folderPlaylists = folder['playlists'] as List<dynamic>? ?? [];
    for (final playlist in folderPlaylists) {
      if (playlist is Map) {
        final id = playlist['ytid']?.toString();
        if (id != null) {
          index[id] = (playlist: playlist, isFromFolder: true);
        }
      }
    }
  }
  _customPlaylistIndexCache = index;
  return index[playlistId];
}

Map? _findOfflinePlaylist(String id) {
  return _findPlaylistById(offlinePlaylistService.offlinePlaylists.value, id);
}

Map? _findPlaylistById(Iterable<dynamic> playlists, String id) {
  for (final playlist in playlists) {
    if (playlist is Map && playlist['ytid']?.toString() == id) {
      return playlist;
    }
  }

  return null;
}

Future<Map?> _fetchYouTubePlaylist(String id) async {
  // 1. Local DB / in-memory caches (no network).
  var playlist = _findPlaylistById(playlists, id);

  // 2. User-added YouTube playlists.
  if (playlist == null) {
    final userPlaylists = await getUserPlaylists();
    playlist = _findPlaylistById(userPlaylists, id);
  }

  // 3. Previously fetched online playlists.
  playlist ??= _findPlaylistById(onlinePlaylists.value, id);

  // 4. Fetch from YouTube as a last resort.
  if (playlist == null) {
    try {
      final strId = id.trim();
      if (strId.startsWith('MPREb_')) {
        final album = await ytMusicClient.music.getAlbum(strId);
        final albumThumb = album.thumbnailUrl != null
            ? formatArtworkResolution(album.thumbnailUrl!, 1080)
            : null;
        playlist = {
          'ytid': album.id,
          'title': album.title,
          'artist': album.artist,
          'year': album.year,
          'image': albumThumb,
          'lowResImage': album.thumbnailUrl,
          'highResImage': albumThumb,
          'isAlbum': true,
          'source': 'youtube-music-album',
          'list': album.tracks
              .map((t) => returnSongLayout(0, t, playlistImage: albumThumb))
              .toList(),
        };
      } else if (id.length == 11) {
        var officialTrack = await ytMusicClient.music.getSong(id);
        officialTrack ??= await ytMusicClient.music.searchSong(id);
        if (officialTrack != null) {
          final layout = returnSongLayout(0, officialTrack);
          final thumb =
              layout['highResImage']?.toString() ?? layout['image']?.toString();

          playlist = {
            'ytid': officialTrack.id.value,
            'title': layout['title'],
            'artist': layout['artist'],
            'image': thumb,
            'lowResImage': layout['lowResImage'],
            'highResImage': thumb,
            'isSingle': true,
            'isAlbum': true,
            'list': [layout],
          };
        }
      } else {
        final cleanId = strId.startsWith('VL') ? strId.substring(2) : strId;
        try {
          final musicPlaylist = await ytMusicClient.music
              .getPlaylist(cleanId)
              .timeout(const Duration(seconds: 10));
          final plThumb = musicPlaylist.thumbnailUrl != null
              ? formatArtworkResolution(musicPlaylist.thumbnailUrl!, 1080)
              : null;
          playlist = {
            'ytid': musicPlaylist.id,
            'title': musicPlaylist.title,
            'artist': musicPlaylist.author,
            'image': plThumb,
            'lowResImage': musicPlaylist.thumbnailUrl,
            'highResImage': plThumb,
            'source': 'youtube-music-playlist',
            'list': musicPlaylist.tracks
                .map((t) => returnSongLayout(0, t))
                .toList(),
          };
        } catch (_) {
          final cachedSongs =
              await getData('cache', 'ytm_playlistSongs_v2_$cleanId') ??
              await getData('cache', 'playlistSongs$cleanId');
          playlist = {
            'ytid': cleanId,
            'title': 'Playlist',
            'image': null,
            'source': 'youtube-music-playlist',
            'list': cachedSongs is List ? cachedSongs : [],
          };
        }
      }
      if (playlist != null && (playlist['list'] as List?)?.isNotEmpty == true) {
        _updateOnlineCache(playlist);
      }
    } catch (e, stackTrace) {
      logger.log(
        'Failed to fetch playlist info for id $id',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  if (playlist == null) return null;

  // 6. Populate the song list if it is absent or empty.
  final list = playlist['list'];
  if (list == null || (list is List && list.isEmpty)) {
    playlist['list'] = await _loadSongsForPlaylist(playlist);
  }

  return playlist;
}

Future<List> _loadSongsForPlaylist(Map playlist) async {
  try {
    final ytid = playlist['ytid']?.toString() ?? '';
    if (ytid.startsWith('MPREb_')) {
      if (playlist['list'] is List && (playlist['list'] as List).isNotEmpty) {
        return playlist['list'] as List;
      }
      final album = await ytMusicClient.music.getAlbum(ytid);
      return album.tracks
          .map((t) => returnSongLayout(0, t, playlistImage: album.thumbnailUrl))
          .toList();
    }
    if (playlist['isSingle'] == true || ytid.length == 11) {
      if (playlist['list'] is List && (playlist['list'] as List).isNotEmpty) {
        return playlist['list'] as List;
      }
      var officialTrack = await ytMusicClient.music.getSong(ytid);
      officialTrack ??= await ytMusicClient.music.searchSong(ytid);
      if (officialTrack != null) {
        final thumb =
            playlist['image']?.toString() ??
            (officialTrack.musicData.isNotEmpty
                ? officialTrack.musicData.first.image?.toString()
                : null);
        return [returnSongLayout(0, officialTrack, playlistImage: thumb)];
      }
      return [];
    }

    final cleanYtid = ytid.startsWith('VL') ? ytid.substring(2) : ytid;
    final playlistImage = playlist['isAlbum'] == true
        ? playlist['image'] as String?
        : null;
    final songs = await getSongsFromPlaylist(
      cleanYtid,
      playlistImage: playlistImage,
    );
    if (!playlists.contains(playlist)) {
      playlists.add(playlist);
    }
    return songs;
  } catch (e, stackTrace) {
    logger.log(
      'Error fetching songs for playlist ${playlist['ytid']}',
      error: e,
      stackTrace: stackTrace,
    );
    return [];
  }
}

Future<List> getSongsFromPlaylist(
  dynamic playlistId, {
  String? playlistImage,
}) async {
  final cleanId = playlistId.toString().trim().startsWith('VL')
      ? playlistId.toString().trim().substring(2)
      : playlistId.toString().trim();
  final cacheKey = 'ytm_playlistSongs_v2_$cleanId';
  final cached = await getData('cache', cacheKey);
  if (cached is List && cached.isNotEmpty) {
    return cached;
  }

  final songList = <Map<String, dynamic>>[];

  // 1. YouTube Music first (official releases, high-res audio, clean album covers)
  try {
    final musicPlaylist = await ytMusicClient.music
        .getPlaylist(cleanId)
        .timeout(const Duration(seconds: 10));
    if (musicPlaylist.tracks.isNotEmpty) {
      for (final track in musicPlaylist.tracks) {
        songList.add(
          returnSongLayout(
            songList.length,
            track,
            playlistImage: playlistImage,
          ),
        );
      }
      unawaited(addOrUpdateData<List>('cache', cacheKey, songList));
      return songList;
    }
  } catch (e, st) {
    if (!isNetworkError(e)) {
      logger.log(
        'Error fetching YTM songs for playlist $cleanId:',
        error: e,
        stackTrace: st,
      );
    } else {
      logger.log('[PLAYLIST] Network unavailable for $cleanId ($e)');
    }
  }

  // 2. Legacy cache fallback if available
  final legacyCache = await getData('cache', 'playlistSongs$cleanId');
  if (legacyCache is List && legacyCache.isNotEmpty) {
    return legacyCache;
  }

  return songList;
}

Future updatePlaylistList(BuildContext context, String playlistId) async {
  final index = findPlaylistIndexByYtId(playlistId);
  if (index == -1) {
    logger.log('Playlist with id $playlistId not found for update');
    return null;
  }

  try {
    final cleanId = playlistId.startsWith('VL')
        ? playlistId.substring(2)
        : playlistId;
    final songList = <Map<String, dynamic>>[];

    try {
      final musicPlaylist = await ytMusicClient.music
          .getPlaylist(cleanId)
          .timeout(const Duration(seconds: 10));
      if (musicPlaylist.tracks.isNotEmpty) {
        for (final track in musicPlaylist.tracks) {
          songList.add(returnSongLayout(songList.length, track));
        }
      }
    } catch (_) {}

    playlists[index]['list'] = songList;
    unawaited(
      addOrUpdateData<List>('cache', 'ytm_playlistSongs_v2_$cleanId', songList),
    );
    showToast(context, context.l10n!.playlistUpdated);
    return playlists[index];
  } catch (e, stackTrace) {
    logger.log(
      'Error updating playlist list for $playlistId',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  }
}

Future<void> renameSongInPlaylist(
  dynamic playlistId,
  dynamic songId,
  String newTitle,
  String newArtist,
) async {
  try {
    final found = _findCustomPlaylist(playlistId.toString());
    final playlist = found?.playlist;
    final isFromFolder = found?.isFromFolder ?? false;

    if (playlist != null && playlist['list'] != null) {
      final songIndex = (playlist['list'] as List).indexWhere(
        (song) => song['ytid'] == songId,
      );

      if (songIndex != -1) {
        final updatedSongs = List<dynamic>.from(playlist['list'] as List);
        updatedSongs[songIndex] =
            Map<String, dynamic>.from(updatedSongs[songIndex] as Map)
              ..['title'] = newTitle
              ..['artist'] = newArtist;

        playlist['list'] = updatedSongs;

        if (isFromFolder) {
          userPlaylistFolders.value = List<Map>.from(userPlaylistFolders.value);
          unawaited(
            addOrUpdateData<List>(
              'user',
              'playlistFolders',
              userPlaylistFolders.value,
            ),
          );
        } else {
          final updatedPlaylists = userCustomPlaylists.value
              .map((p) => p['ytid'] == playlistId ? playlist : p)
              .toList();
          userCustomPlaylists.value = updatedPlaylists;
          unawaited(
            addOrUpdateData<List>('user', 'customPlaylists', updatedPlaylists),
          );
        }
      }
    }
  } catch (e, stackTrace) {
    logger.log(
      'Error renaming song in playlist',
      error: e,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

Future<void> updatePlaylistLikeStatus(
  String playlistId,
  bool add, {
  Map? playlistData,
}) async {
  try {
    final normalizedPlaylistId = playlistId.trim();
    if (normalizedPlaylistId.isEmpty || normalizedPlaylistId == 'null') return;

    final updateToken = ++_playlistLikeUpdateToken;
    _latestPlaylistLikeUpdateTokens[normalizedPlaylistId] = updateToken;

    final playlistToAdd = add
        ? await _resolvePlaylistForLikedStatus(
            normalizedPlaylistId,
            playlistData,
          )
        : null;

    if (_latestPlaylistLikeUpdateTokens[normalizedPlaylistId] != updateToken) {
      return;
    }

    final updatedLikedPlaylists = _deduplicateLikedPlaylists(
      userLikedPlaylists.value,
    );

    if (add) {
      if (playlistToAdd != null &&
          !updatedLikedPlaylists.any((playlist) {
            final id =
                playlist['ytid']?.toString() ?? playlist['id']?.toString();
            return id == normalizedPlaylistId;
          })) {
        updatedLikedPlaylists.add(playlistToAdd);
      }
    } else {
      updatedLikedPlaylists.removeWhere((playlist) {
        final id = playlist['ytid']?.toString() ?? playlist['id']?.toString();
        return id == normalizedPlaylistId;
      });
    }

    if (_likedPlaylistIdsAreEqual(
      userLikedPlaylists.value,
      updatedLikedPlaylists,
    )) {
      return;
    }

    userLikedPlaylists.value = List<Map>.from(updatedLikedPlaylists);
    unawaited(
      addOrUpdateData<List>('user', 'likedPlaylists', userLikedPlaylists.value),
    );
  } catch (e, stackTrace) {
    logger.log(
      'Error updating playlist like status: ',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

List<Map> _deduplicateLikedPlaylists(Iterable<Map> likedPlaylists) {
  final seenPlaylistIds = <String>{};
  final deduplicatedPlaylists = <Map>[];

  for (final playlist in likedPlaylists) {
    final playlistId =
        playlist['ytid']?.toString() ?? playlist['id']?.toString();
    if (playlistId == null || playlistId.isEmpty) {
      deduplicatedPlaylists.add(playlist);
      continue;
    }

    if (seenPlaylistIds.add(playlistId)) {
      deduplicatedPlaylists.add(playlist);
    }
  }

  return deduplicatedPlaylists;
}

bool _likedPlaylistIdsAreEqual(List<Map> previous, List<Map> updated) {
  if (previous.length != updated.length) return false;

  for (var i = 0; i < previous.length; i++) {
    final prevId =
        previous[i]['ytid']?.toString() ?? previous[i]['id']?.toString();
    final updatedId =
        updated[i]['ytid']?.toString() ?? updated[i]['id']?.toString();
    if (prevId != updatedId) {
      return false;
    }
  }

  return true;
}

Future<Map?> _resolvePlaylistForLikedStatus(
  String playlistId,
  Map? playlistData,
) async {
  if (playlistData != null) {
    final pYtid = playlistData['ytid']?.toString();
    final pId = playlistData['id']?.toString();
    if (pYtid == playlistId || pId == playlistId) {
      final map = Map<String, dynamic>.from(playlistData);
      map['ytid'] ??= playlistId;
      return map;
    }
  }

  final cachedPlaylist = _searchAppPlaylistsById(playlistId);
  if (cachedPlaylist != null) {
    return Map<String, dynamic>.from(cachedPlaylist);
  }

  for (final p in userCustomPlaylists.value) {
    final id = p['ytid']?.toString() ?? p['id']?.toString();
    if (id == playlistId) {
      final map = Map<String, dynamic>.from(p);
      map['ytid'] ??= playlistId;
      return map;
    }
  }

  try {
    final playlistInfo = await getPlaylistInfoForWidget(playlistId);
    if (playlistInfo != null) {
      return Map<String, dynamic>.from(playlistInfo);
    }
  } catch (_) {}

  if (playlistData != null) {
    final map = Map<String, dynamic>.from(playlistData);
    map['ytid'] ??= playlistId;
    return map;
  }

  return null;
}

bool isPlaylistPinned(String playlistId) =>
    pinnedPlaylistIds.value.contains(playlistId);

bool togglePinnedPlaylist(String playlistId, BuildContext context) {
  final current = List<String>.from(pinnedPlaylistIds.value);
  if (current.contains(playlistId)) {
    current.remove(playlistId);
    pinnedPlaylistIds.value = current;
    unawaited(addOrUpdateData<List>('user', 'pinnedPlaylistIds', current));
    return false;
  }
  if (current.length >= pinnedPlaylistsLimit) {
    return false;
  }
  current.add(playlistId);
  pinnedPlaylistIds.value = current;
  unawaited(addOrUpdateData<List>('user', 'pinnedPlaylistIds', current));
  return true;
}

void _unpinPlaylist(String playlistId) {
  if (!pinnedPlaylistIds.value.contains(playlistId)) return;
  final updated = List<String>.from(pinnedPlaylistIds.value)
    ..remove(playlistId);
  pinnedPlaylistIds.value = updated;
  unawaited(addOrUpdateData<List>('user', 'pinnedPlaylistIds', updated));
}

/// Updates the offline playlist metadata (title, image, source) when a custom
/// playlist is renamed or modified. This ensures the offline playlist section
/// in the library displays the updated information.
Future<void> syncOfflinePlaylistMetadata(Map updatedPlaylist) async {
  final playlistId = updatedPlaylist['ytid']?.toString();
  if (playlistId == null ||
      !offlinePlaylistService.isPlaylistDownloaded(playlistId)) {
    return;
  }

  final offlinePlaylists = List<dynamic>.from(
    offlinePlaylistService.offlinePlaylists.value,
  );
  final offlineIndex = offlinePlaylists.indexWhere(
    (p) => p['ytid']?.toString() == playlistId,
  );

  if (offlineIndex == -1) return;

  // Update the offline playlist with the new metadata
  offlinePlaylists[offlineIndex] = {
    ...offlinePlaylists[offlineIndex],
    'title': updatedPlaylist['title'],
    'image': updatedPlaylist['image'],
    'source': updatedPlaylist['source'],
  };

  // Create a new list to trigger ValueNotifier listeners
  offlinePlaylistService.offlinePlaylists.value = List<dynamic>.from(
    offlinePlaylists,
  );
  unawaited(
    addOrUpdateData<List>('userNoBackup', 'offlinePlaylists', offlinePlaylists),
  );
}

/// Generates a language-aware, transport-aware, region-aware, and mood-aware cache key for Home Feed.
/// Ensures different music content languages and transport modes never share or collide with each other's cache entries.
String getHomeFeedCacheKey({
  String? contentLanguage,
  String? transportHl,
  String? region,
  String? mood,
}) {
  final contentLang = contentLanguage ?? contentLanguagePreference ?? 'en';
  final resolvedTransport =
      transportHl ?? resolveHomeFeedTransportLanguage(contentLang);
  final reg = (region ?? homeFeedRegion).trim().toUpperCase();
  final m = (mood == null || mood.trim().isEmpty) ? 'All' : mood.trim();
  return 'ytm_home_feed_v9_${contentLang}_${resolvedTransport}_${reg}_$m';
}

/// Fetches the unified dynamic Home Feed.
///
/// Integrates YouTube Music InnerTube `FEmusic_home` shelves (similar to ytmusicapi `get_home()`),
/// caches results in Hive (`ytm_home_feed_v9`), and includes fallback mechanisms to guarantee a rich
/// feed even during network degradation.
int _activeHomeFeedRequestId = 0;

final Map<String, Future<List<HomeSection>>> _homeFeedInFlight = {};
final Map<String, DateTime> _recentHomeFeedRefreshes = {};
final Map<String, List<HomeSection>> _recentHomeFeedResults = {};
final Map<String, int> _latestHomeFeedRequestTokens = {};
const _homeFeedRefreshDeduplicationWindow = Duration(seconds: 60);

Future<List<HomeSection>> getUnifiedHomeFeed({
  bool forceRefresh = false,
  String? mood,
  bool bypassRefreshDeduplication = false,
}) {
  final contentLang = contentLanguagePreference ?? 'en';
  final transportHl = resolveHomeFeedTransportLanguage(contentLang);
  final normalizedMood = mood == null || mood.trim().isEmpty
      ? 'All'
      : mood.trim();
  final cacheRequestKey = [
    contentLang,
    transportHl,
    homeFeedRegion,
    normalizedMood,
  ].join('|');
  var effectiveForceRefresh = forceRefresh;
  if (forceRefresh && bypassRefreshDeduplication) {
    _recentHomeFeedRefreshes.remove(cacheRequestKey);
    _recentHomeFeedResults.remove(cacheRequestKey);
  } else if (forceRefresh && !bypassRefreshDeduplication) {
    final lastRefresh = _recentHomeFeedRefreshes[cacheRequestKey];
    if (lastRefresh != null &&
        DateTime.now().difference(lastRefresh) <
            _homeFeedRefreshDeduplicationWindow) {
      effectiveForceRefresh = false;
      logger.log(
        '[HOME_REFRESH] coalescing repeated force refresh key=$cacheRequestKey',
      );
      final recentResult = _recentHomeFeedResults[cacheRequestKey];
      if (recentResult != null && recentResult.isNotEmpty) {
        return Future.value(recentResult);
      }
    }
  }
  final requestKey = [
    if (effectiveForceRefresh) 'refresh' else 'cached',
    cacheRequestKey,
  ].join('|');

  if (bypassRefreshDeduplication) {
    _homeFeedInFlight.remove(requestKey);
  }

  final existing = _homeFeedInFlight[requestKey];
  if (existing != null) {
    logger.log('[HOME_IN_FLIGHT] reusing key=$requestKey');
    return existing;
  }

  final requestToken = (_latestHomeFeedRequestTokens[cacheRequestKey] ?? 0) + 1;
  _latestHomeFeedRequestTokens[cacheRequestKey] = requestToken;
  final future =
      _loadUnifiedHomeFeed(
        forceRefresh: effectiveForceRefresh,
        mood: mood,
      ).then((result) {
        if (result.isNotEmpty &&
            _latestHomeFeedRequestTokens[cacheRequestKey] == requestToken) {
          _recentHomeFeedResults[cacheRequestKey] = result;
          if (effectiveForceRefresh) {
            _recentHomeFeedRefreshes[cacheRequestKey] = DateTime.now();
          }
        }
        return result;
      });
  late Future<List<HomeSection>> tracked;
  tracked = future.whenComplete(() {
    if (identical(_homeFeedInFlight[requestKey], tracked)) {
      _homeFeedInFlight.remove(requestKey);
    }
  });
  _homeFeedInFlight[requestKey] = tracked;
  return tracked;
}

Future<List<HomeSection>> _loadUnifiedHomeFeed({
  bool forceRefresh = false,
  String? mood,
}) async {
  final requestId = ++_activeHomeFeedRequestId;
  final totalStopwatch = Stopwatch()..start();
  var remoteMs = 0;
  var languageMs = 0;
  var composerMs = 0;
  var isFallback = false;

  final contentLang = contentLanguagePreference ?? 'en';
  final transportHl = resolveHomeFeedTransportLanguage(contentLang);
  final reg = homeFeedRegion;

  logger.log(
    '[HOME_LANGUAGE] requested=$contentLang transport_hl=$transportHl region=$reg',
  );

  final cacheKey = getHomeFeedCacheKey(
    contentLanguage: contentLang,
    transportHl: transportHl,
    region: reg,
    mood: mood,
  );
  logger.log('[HOME_FEED] cache_key=$cacheKey');

  HomeSection? moodSection;

  final cacheStopwatch = Stopwatch()..start();
  if (!forceRefresh && Hive.isBoxOpen('cache')) {
    try {
      final cached = await getData(
        'cache',
        cacheKey,
        cachingDuration: homeFeedCacheDuration,
        allowExpired: true,
      );
      if (homeCacheMs == null && appStartupStopwatch.isRunning) {
        homeCacheMs = cacheStopwatch.elapsedMilliseconds;
        checkAndLogColdStartPerf();
      }
      if (cached is List && cached.isNotEmpty) {
        final cachedSections = <HomeSection>[];
        for (final item in cached) {
          if (item is Map) {
            cachedSections.add(HomeSection.fromJson(item));
          }
        }
        if (cachedSections.isNotEmpty) {
          logger
            ..log('[HOME_LANGUAGE_CACHE] key=$cacheKey hit=true')
            ..log(
              '[HOME_FEED] cache hit key=$cacheKey sections=${cachedSections.length}',
            );
          final cacheIsFresh = isCacheValid(
            Hive.box('cache'),
            cacheKey,
            homeFeedCacheDuration,
          );
          if (!cacheIsFresh && !offlineMode.value) {
            logger.log(
              '[HOME_SWR] stale cache displayed; starting background revalidation '
              'key=$cacheKey',
            );
            unawaited(
              getUnifiedHomeFeed(forceRefresh: true, mood: mood).catchError((
                error,
                stackTrace,
              ) {
                logger.log(
                  '[HOME_SWR] background revalidation failed key=$cacheKey',
                  error: error,
                  stackTrace: stackTrace,
                );
                return <HomeSection>[];
              }),
            );
          }

          var madeForYouRecs = const <Map<String, dynamic>>[];
          var artistRecs = const <Map<String, dynamic>>[];
          try {
            final signals = PersonalizationService.instance.getUserSignals();
            final topCandidateArtists = PersonalizationService.instance
                .getCandidateArtists(signals, limit: 2);
            madeForYouRecs = await getMadeForYouRecommendations(
              forceRefresh: forceRefresh,
              allowNetwork: false,
            );
            if (topCandidateArtists.isNotEmpty) {
              final cachedArtistResults = await Future.wait(
                topCandidateArtists.map(
                  (a) => getSongsForArtistRecommendation(
                    a,
                    allowNetwork: false,
                  ).catchError((_) => <Map<String, dynamic>>[]),
                ),
              );
              artistRecs = cachedArtistResults.expand((x) => x).toList();
            }
          } catch (_) {}

          final combinedCandidates = <Map<String, dynamic>>[
            ...madeForYouRecs,
            ...artistRecs,
            for (final sec in cachedSections)
              if (sec.type == HomeContentType.songs)
                ...sec.contents.whereType<Map<String, dynamic>>(),
          ];

          // Blend cached sections with fresh local personalization
          final personalizedSections = PersonalizationService.instance
              .buildPersonalizedSections(
                mood: mood,
                relevantCandidates: combinedCandidates,
              );

          final composedSections = HomeFeedComposer.compose(
            remoteSections: shouldUseNativeHomeFeed(contentLang)
                ? cachedSections
                : const [],
            moodSection: moodSection,
            languageSections: shouldUseNativeHomeFeed(contentLang)
                ? const []
                : cachedSections,
            personalizedSections: personalizedSections,
          );

          final distinctItems = composedSections
              .expand((s) => s.contents)
              .map(
                (item) =>
                    item['ytid']?.toString() ?? item['id']?.toString() ?? '',
              )
              .where((id) => id.isNotEmpty)
              .toSet()
              .length;

          logger
            ..log(
              '[HOME_LANGUAGE_RESULT] language=$contentLang sections=${composedSections.length} distinct_items=$distinctItems fallback=false',
            )
            ..log(HomeFeedComposer.formatHomeOrder(composedSections));
          return composedSections;
        }
      }
    } catch (_) {}
  }

  logger.log('[HOME_LANGUAGE_CACHE] key=$cacheKey hit=false');

  // 1. If a specific mood is selected (other than 'All'), fetch featured playlists for that mood
  if (mood != null && mood.isNotEmpty && mood != 'All' && !offlineMode.value) {
    try {
      final moodPlaylists = await getFeaturedMoodPlaylists(
        mood: mood,
        forceRefresh: forceRefresh,
      );
      if (moodPlaylists.isNotEmpty) {
        moodSection = HomeSection(
          title: '$mood playlists',
          subtitle: 'Featured for your mood',
          type: HomeContentType.playlists,
          contents: moodPlaylists,
        );
      }
    } catch (_) {}
  }

  final sections = <HomeSection>[];
  final languageSections = <HomeSection>[];
  final signals = PersonalizationService.instance.getUserSignals();
  final topCandidateArtists = PersonalizationService.instance
      .getCandidateArtists(signals, limit: 2);

  final madeForYouFuture = getMadeForYouRecommendations(
    forceRefresh: forceRefresh,
  ).catchError((_) => <Map<String, dynamic>>[]);

  final artistRecFuture = topCandidateArtists.isNotEmpty
      ? Future.wait(
          topCandidateArtists.map(
            (a) => getSongsForArtistRecommendation(
              a,
              forceRefresh: forceRefresh,
            ).catchError((_) => <Map<String, dynamic>>[]),
          ),
        ).then((results) => results.expand((x) => x).toList())
      : Future.value(<Map<String, dynamic>>[]);

  // 2. Fetch the native home shelves only for English. For regional content
  // languages, showing the generic FEmusic_home response would mix unrelated
  // global recommendations into a language-specific feed.
  if (!offlineMode.value) {
    try {
      final isRegionalLanguage = !shouldUseNativeHomeFeed(contentLang);
      if (isRegionalLanguage) {
        logger.log(
          '[HOME_REQUEST] native_home_skipped contentLanguage=$contentLang '
          'reason=regional_language',
        );
      } else {
        logger.log(
          '[HOME_REQUEST] contentLanguage=$contentLang hl=$transportHl '
          'gl=$reg browseId=FEmusic_home',
        );
      }
      final remoteFuture = isRegionalLanguage
          ? Future.value(<HomeSection>[])
          : (() {
              final remoteWatch = Stopwatch()..start();
              return ytMusicClient.music
                  .getHomeFeed(hl: transportHl, gl: reg)
                  .timeout(const Duration(seconds: 8))
                  .then((res) {
                    remoteMs = remoteWatch.elapsedMilliseconds;
                    return res;
                  })
                  .catchError((e, st) {
                    remoteMs = remoteWatch.elapsedMilliseconds;
                    logger.log(
                      'Error fetching dynamic home feed from InnerTube:',
                      error: e,
                      stackTrace: st,
                    );
                    return <HomeSection>[];
                  });
            })();
      final langWatch = Stopwatch()..start();
      final langFuture = isRegionalLanguage
          ? _fetchLanguageCuratedSections(
                  contentLang: contentLang,
                  forceRefresh: forceRefresh,
                )
                .then((res) {
                  languageMs = langWatch.elapsedMilliseconds;
                  return res;
                })
                .catchError((e, st) {
                  languageMs = langWatch.elapsedMilliseconds;
                  logger.log(
                    'Error fetching language curated sections:',
                    error: e,
                    stackTrace: st,
                  );
                  return <HomeSection>[];
                })
          : Future.value(<HomeSection>[]);

      final results = await Future.wait([remoteFuture, langFuture]);
      final remoteShelves = results[0];
      final curatedShelves = results[1];

      logger.log('[HOME_FEED] shelves=${remoteShelves.length}');

      for (final shelf in remoteShelves) {
        if (shelf.isNotEmpty) {
          logger.log(
            '[HOME_SECTION] source=remote title="${shelf.title}" type=${shelf.type.name} items=${shelf.contents.length}',
          );
          sections.add(shelf);
        }
      }

      for (final shelf in curatedShelves) {
        if (shelf.isNotEmpty) {
          languageSections.add(shelf);
        }
      }
    } catch (e, st) {
      logger.log(
        'Error during home feed and language curation fetch:',
        error: e,
        stackTrace: st,
      );
    }
  }

  // 3. If remote and language fetches returned 0 sections (e.g. offline during refresh/SWR),
  // restore cached sections from Hive so the home feed is not wiped out.
  if (sections.isEmpty && languageSections.isEmpty) {
    try {
      final cachedRaw = await getData('cache', cacheKey);
      if (cachedRaw is List && cachedRaw.isNotEmpty) {
        final cachedSections = cachedRaw
            .whereType<Map>()
            .map(
              (item) => HomeSection.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((s) => s.isNotEmpty)
            .toList();
        if (cachedSections.isNotEmpty) {
          logger.log(
            '[HOME_CACHE_FALLBACK] Restored ${cachedSections.length} cached sections due to network fetch producing 0 sections',
          );
          if (shouldUseNativeHomeFeed(contentLang)) {
            sections.addAll(cachedSections);
          } else {
            languageSections.addAll(cachedSections);
          }
        }
      }
    } catch (_) {}
  }

  // 4. Global fallback is English-only. Regional feeds must not fall back to
  // generic songs/playlists because that breaks the selected-language contract.
  if (shouldUseNativeHomeFeed(contentLang) &&
      sections.isEmpty &&
      languageSections.isEmpty &&
      !offlineMode.value) {
    isFallback = true;
    logger.log('[HOME_FEED] using fallback recommendation sections');
    try {
      // Add Quick Picks if not present
      if (!sections.any((s) => s.title.toLowerCase().contains('quick picks'))) {
        final quickPicks = await getQuickPicksSongs(forceRefresh: forceRefresh);
        if (quickPicks.isNotEmpty) {
          sections.insert(
            0,
            HomeSection(
              title: 'Quick picks',
              subtitle: 'START RADIO FROM A SONG',
              type: HomeContentType.songs,
              contents: quickPicks,
              isChunkedSongs: true,
            ),
          );
        }
      }

      // Add Trending songs if not present
      if (!sections.any(
        (s) => s.title.toLowerCase().contains('trending song'),
      )) {
        final trending = await getTrendingSongsForYou(
          forceRefresh: forceRefresh,
        );
        if (trending.isNotEmpty) {
          sections.add(
            HomeSection(
              title: 'Trending songs for you',
              subtitle: 'POPULAR RIGHT NOW',
              type: HomeContentType.songs,
              contents: trending,
            ),
          );
        }
      }

      // Add Featured Playlists if not present
      if (!sections.any((s) => s.title.toLowerCase().contains('featured'))) {
        final featured = await getFeaturedPlaylists(forceRefresh: forceRefresh);
        if (featured.isNotEmpty) {
          sections.add(
            HomeSection(
              title: 'Featured playlists',
              subtitle: 'CURATED FOR YOU',
              type: HomeContentType.playlists,
              contents: featured,
            ),
          );
        }
      }

      // Add Community Playlists if not present
      if (!sections.any((s) => s.title.toLowerCase().contains('community'))) {
        final community = await getTrendingCommunityPlaylists(
          forceRefresh: forceRefresh,
        );
        if (community.isNotEmpty) {
          sections.add(
            HomeSection(
              title: 'Trending community playlists',
              subtitle: 'POPULAR PLAYLISTS',
              type: HomeContentType.playlists,
              contents: community,
            ),
          );
        }
      }

      // Add New releases if not present
      if (!sections.any((s) => s.title.toLowerCase().contains('new release'))) {
        final newReleases = await getSuggestedNewReleases(
          forceRefresh: forceRefresh,
        );
        if (newReleases.isNotEmpty) {
          sections.add(
            HomeSection(
              title: 'New releases',
              subtitle: 'FRESH TRACKS & VIDEOS',
              type: HomeContentType.songs,
              contents: newReleases,
            ),
          );
        }
      }

      // Add Albums if not present
      if (!sections.any((s) => s.title.toLowerCase().contains('album'))) {
        final albums = await getSuggestedAlbumsAndSingles(
          forceRefresh: forceRefresh,
        );
        if (albums.isNotEmpty) {
          sections.add(
            HomeSection(
              title: 'Albums for you',
              subtitle: 'RECOMMENDED ALBUMS',
              type: HomeContentType.albums,
              contents: albums,
            ),
          );
        }
      }
    } catch (_) {}
  }

  // 4. Generate fresh local personalization with relevant recommendations
  final madeForYouRecs = await madeForYouFuture;
  final artistRecs = await artistRecFuture;

  final combinedCandidates = <Map<String, dynamic>>[
    ...madeForYouRecs,
    ...artistRecs,
    for (final sec in languageSections)
      if (sec.type == HomeContentType.songs)
        ...sec.contents.whereType<Map<String, dynamic>>(),
    for (final sec in sections)
      if (sec.type == HomeContentType.songs)
        ...sec.contents.whereType<Map<String, dynamic>>(),
  ];

  final personalizedSections = PersonalizationService.instance
      .buildPersonalizedSections(
        mood: mood,
        relevantCandidates: combinedCandidates,
      );

  // 5. Compose final ordered feed through HomeFeedComposer with language-curated sections
  final compWatch = Stopwatch()..start();
  final composedSections = HomeFeedComposer.compose(
    remoteSections: sections,
    moodSection: moodSection,
    languageSections: languageSections,
    personalizedSections: personalizedSections,
  );
  composerMs = compWatch.elapsedMilliseconds;

  logger
    ..log(
      '[HOME_COMPOSE] remote=${sections.length} language=${languageSections.length} personalized=${personalizedSections.length} final=${composedSections.length}',
    )
    ..log(HomeFeedComposer.formatHomeOrder(composedSections));

  // 6. Cache valid server & language sections in Hive (guarded against stale superseded requests)
  final isStale = requestId != _activeHomeFeedRequestId;
  if (!isStale &&
      (sections.isNotEmpty || languageSections.isNotEmpty) &&
      Hive.isBoxOpen('cache')) {
    final toCache = HomeFeedComposer.compose(
      remoteSections: shouldUseNativeHomeFeed(contentLang)
          ? sections
          : const [],
      moodSection: moodSection,
      languageSections: languageSections,
    );
    final serialized = toCache.map((s) => s.toJson()).toList();
    try {
      await addOrUpdateData('cache', cacheKey, serialized);
    } catch (_) {}
  }

  final totalHomeMs = totalStopwatch.elapsedMilliseconds;
  logger.log(
    '[HOME_PERF] remote_home_ms=$remoteMs language_curation_ms=$languageMs composer_ms=$composerMs total_home_ms=$totalHomeMs',
  );

  final distinctItems = composedSections
      .expand((s) => s.contents)
      .map((item) => item['ytid']?.toString() ?? item['id']?.toString() ?? '')
      .where((id) => id.isNotEmpty)
      .toSet()
      .length;

  logger.log(
    '[HOME_LANGUAGE_RESULT] language=$contentLang sections=${composedSections.length} distinct_items=$distinctItems fallback=$isFallback',
  );

  return composedSections;
}

Future<List<Map<String, dynamic>>> _timedHomeCategory(
  String category,
  Future<List<Map<String, dynamic>>> future, {
  Duration timeout = const Duration(seconds: 7),
}) async {
  final stopwatch = Stopwatch()..start();
  try {
    final result = await future.timeout(
      timeout,
      onTimeout: () {
        logger.log(
          '[HOME_LANGUAGE_CATEGORY_TIMEOUT] category=$category timed out after ${timeout.inSeconds}s',
        );
        return const [];
      },
    );
    logger.log(
      '[HOME_LANGUAGE_CATEGORY] category=$category duration_ms=${stopwatch.elapsedMilliseconds} items=${result.length}',
    );
    return result;
  } catch (e, st) {
    logger.log(
      '[HOME_LANGUAGE_CATEGORY_ERROR] category=$category duration_ms=${stopwatch.elapsedMilliseconds}',
      error: e,
      stackTrace: st,
    );
    return const [];
  }
}

/// Concurrently fetches language-curated sections for the user's selected music language.
Future<List<HomeSection>> _fetchLanguageCuratedSections({
  required String contentLang,
  bool forceRefresh = false,
}) async {
  final curated = <HomeSection>[];
  try {
    final quickPicksFuture = _timedHomeCategory(
      'quick_picks',
      getQuickPicksSongs(forceRefresh: forceRefresh),
    );
    final trendingSongsFuture = _timedHomeCategory(
      'trending_songs',
      getTrendingSongsForYou(forceRefresh: forceRefresh),
    );
    final featuredPlaylistsFuture = _timedHomeCategory(
      'featured_playlists',
      getFeaturedPlaylists(forceRefresh: forceRefresh),
    );
    final communityPlaylistsFuture = _timedHomeCategory(
      'community_playlists',
      getTrendingCommunityPlaylists(forceRefresh: forceRefresh),
    );
    final newReleasesFuture = _timedHomeCategory(
      'new_releases',
      getSuggestedNewReleases(forceRefresh: forceRefresh),
    );

    final results = await Future.wait([
      quickPicksFuture,
      trendingSongsFuture,
      featuredPlaylistsFuture,
      communityPlaylistsFuture,
      newReleasesFuture,
    ]);

    final quickPicks = results[0];
    final trendingSongs = results[1];
    final featuredPlaylists = results[2];
    final communityPlaylists = results[3];
    final newReleases = results[4];

    if (quickPicks.isNotEmpty) {
      curated.add(
        HomeSection(
          title: 'Quick picks',
          subtitle: 'START RADIO FROM A SONG',
          type: HomeContentType.songs,
          contents: quickPicks,
          isChunkedSongs: true,
        ),
      );
    }

    if (trendingSongs.isNotEmpty) {
      curated.add(
        HomeSection(
          title: 'Trending songs for you',
          subtitle: 'POPULAR RIGHT NOW',
          type: HomeContentType.songs,
          contents: trendingSongs,
        ),
      );
    }

    if (featuredPlaylists.isNotEmpty) {
      curated.add(
        HomeSection(
          title: 'Featured playlists',
          subtitle: 'CURATED FOR YOU',
          type: HomeContentType.playlists,
          contents: featuredPlaylists,
        ),
      );
    }

    if (communityPlaylists.isNotEmpty) {
      curated.add(
        HomeSection(
          title: 'Trending community playlists',
          subtitle: 'POPULAR PLAYLISTS',
          type: HomeContentType.playlists,
          contents: communityPlaylists,
        ),
      );
    }

    if (newReleases.isNotEmpty) {
      curated.add(
        HomeSection(
          title: 'New releases',
          subtitle: 'FRESH TRACKS',
          type: HomeContentType.songs,
          contents: newReleases,
        ),
      );
    }
  } catch (e, st) {
    logger.log(
      'Error fetching language curated sections for $contentLang:',
      error: e,
      stackTrace: st,
    );
  }

  final totalItems = curated.fold<int>(0, (sum, s) => sum + s.contents.length);
  logger.log(
    '[HOME_LANGUAGE_CURATED] language=$contentLang sections=${curated.length} items=$totalItems',
  );

  return curated;
}

/// Backwards compatibility alias for [getUnifiedHomeFeed].
Future<List<HomeSection>> getDynamicHomeFeed({
  bool forceRefresh = false,
  String? mood,
}) => getUnifiedHomeFeed(forceRefresh: forceRefresh, mood: mood);
