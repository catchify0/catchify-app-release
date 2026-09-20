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

import 'dart:convert';

import 'package:catchify/main.dart';
import 'package:catchify/services/proxy_manager.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/formatter.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class PlaylistSharingService {
  static const _maxSharedSongs = 500;

  static bool _isValidSongId(Object? value) {
    if (value is! String) return false;
    final id = value.trim();
    return id.isNotEmpty && id.length <= 64;
  }

  static Map createCompactPlaylist(Map fullPlaylist) {
    final songs = fullPlaylist['list'];
    if (songs is! List) {
      throw const FormatException('Shared playlist list is invalid');
    }

    return {
      'title': fullPlaylist['title']?.toString() ?? 'Shared playlist',
      if (fullPlaylist['image'] != null) 'image': fullPlaylist['image'],
      'source': 'user-created',
      'list': songs
          .map((song) => song is Map ? song['ytid'] : null)
          .where(_isValidSongId)
          .take(_maxSharedSongs)
          .toList(),
    };
  }

  static Future<Map> expandCompactPlaylist(Map compactPlaylist) async {
    final rawSongIds = compactPlaylist['list'];
    if (rawSongIds is! List || rawSongIds.length > _maxSharedSongs) {
      throw const FormatException('Shared playlist list is invalid');
    }
    final songIds = rawSongIds
        .where(_isValidSongId)
        .map((id) => (id as String).trim())
        .toList(growable: false);
    if (songIds.isEmpty) {
      throw const FormatException('Shared playlist has no valid songs');
    }

    YoutubeExplode? ytClient;
    try {
      if (useProxy.value) {
        ytClient = await ProxyManager().getYoutubeExplodeClient();
      } else {
        ytClient = ProxyManager().getClientSync();
      }

      final expandedSongs = await Future.wait(
        songIds.indexed.map((entry) async {
          final (index, ytid) = entry;
          try {
            final video = await ytClient!.videos.get(ytid);
            return returnSongLayout(index, video);
          } catch (e, stackTrace) {
            logger.log(
              'Error expanding song: $ytid',
              error: e,
              stackTrace: stackTrace,
            );
            return null;
          }
        }),
      );

      return {
        ...compactPlaylist,
        'list': expandedSongs.where((song) => song != null).toList(),
      };
    } finally {
      try {
        if (useProxy.value) {
          ytClient?.close();
        }
      } catch (_) {}
    }
  }

  static String encodePlaylist(Map playlist) {
    final compactPlaylist = createCompactPlaylist(playlist);
    return base64Url.encode(utf8.encode(json.encode(compactPlaylist)));
  }

  static Future<Map?> decodeAndExpandPlaylist(String encodedPlaylist) async {
    try {
      final jsonString = utf8.decode(base64Url.decode(encodedPlaylist));
      final decoded = json.decode(jsonString);
      if (decoded is! Map) {
        throw const FormatException('Shared playlist payload is invalid');
      }
      final compactPlaylist = decoded;
      return await expandCompactPlaylist(compactPlaylist);
    } catch (e, stackTrace) {
      logger.log('Failed to decode playlist', error: e, stackTrace: stackTrace);
      return null;
    }
  }
}
