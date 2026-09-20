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
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:catchify/services/common_services.dart';
import 'package:catchify/services/library_service.dart';
import 'package:catchify/services/playlists_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_library_test');
    Hive.init(tempDir.path);
    await Hive.openBox('user');
    await Hive.openBox('userNoBackup');
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('LibraryService Tests', () {
    setUp(() {
      userLikedSongsList.value = [];
      userRecentlyPlayed.value = [];
      userOfflineSongs.value = [];
      userLocalSongs.value = [];
      userLikedPlaylists.value = [];
      userCustomPlaylists.value = [];
      userPlaylistFolders.value = [];
    });

    test('loadLikedSongs loads current liked songs list', () {
      userLikedSongsList.value = [
        {'ytid': 'song1', 'title': 'First Song', 'artist': 'Artist One'},
        {'ytid': 'song2', 'title': 'Second Song', 'artist': 'Artist Two'},
      ];

      final songs = LibraryService.instance.loadLikedSongs();
      expect(songs.length, 2);
      expect(songs[0]['ytid'], 'song1');
      expect(songs[1]['title'], 'Second Song');
    });

    test('loadAlbums derives album cards from liked playlists and liked songs with deduplication', () {
      userLikedPlaylists.value = [
        {
          'ytid': 'alb_playlist_1',
          'title': 'Anirudh Hits Album',
          'artist': 'Anirudh',
          'isAlbum': true,
          'image': 'https://example.com/img1.jpg',
        },
        {
          'ytid': 'normal_playlist',
          'title': 'Workout Mix',
          'isAlbum': false,
        },
      ];

      userLikedSongsList.value = [
        {
          'ytid': 's1',
          'title': 'Hukum',
          'artist': 'Anirudh',
          'album': 'Jailer',
          'albumId': 'jailer_album_id',
          'image': 'https://example.com/jailer.jpg',
        },
        // Duplicate song from same album
        {
          'ytid': 's2',
          'title': 'Kaavaalaa',
          'artist': 'Anirudh',
          'album': 'Jailer',
          'albumId': 'jailer_album_id',
          'image': 'https://example.com/jailer.jpg',
        },
      ];

      final albums = LibraryService.instance.loadAlbums();
      expect(albums.length, 2);

      expect(albums[0]['title'], 'Anirudh Hits Album');
      expect(albums[0]['isAlbum'], true);

      expect(albums[1]['title'], 'Jailer');
      expect(albums[1]['ytid'], 'jailer_album_id');
      expect(albums[1]['artist'], 'Anirudh');
    });

    test('loadArtists derives artists from liked artists and liked songs', () {
      userLikedPlaylists.value = [
        {
          'ytid': 'artist_anirudh',
          'title': 'Anirudh Ravichander',
          'source': 'youtube-artist',
          'image': 'https://example.com/anirudh.jpg',
        },
      ];

      userLikedSongsList.value = [
        {
          'ytid': 's1',
          'title': 'Song A',
          'artist': 'AR Rahman',
          'image': 'https://example.com/arr.jpg',
        },
        {
          'ytid': 's2',
          'title': 'Song B',
          'artist': 'AR Rahman',
          'image': 'https://example.com/arr.jpg',
        },
      ];

      final artists = LibraryService.instance.loadArtists(offlineOnly: false);
      expect(artists.length, 2);
      expect(artists.any((a) => a['title'] == 'Anirudh Ravichander'), true);
      expect(artists.any((a) => a['title'] == 'AR Rahman'), true);
    });

    test('loadRecentlyPlayed returns songs latest first with deduplication', () {
      userRecentlyPlayed.value = [
        {'ytid': 'songA', 'title': 'Song A'},
        {'ytid': 'songB', 'title': 'Song B'},
        {'ytid': 'songA', 'title': 'Song A'}, // repeat listen
      ];

      final deduped = LibraryService.instance.loadRecentlyPlayed(deduplicate: true);
      expect(deduped.length, 2);
      expect(deduped[0]['ytid'], 'songA');
      expect(deduped[1]['ytid'], 'songB');

      final raw = LibraryService.instance.loadRecentlyPlayed(deduplicate: false);
      expect(raw.length, 3);
    });

    test('loadDownloads returns offline songs, local songs, and offline playlists', () {
      userOfflineSongs.value = [
        {'ytid': 'off1', 'title': 'Downloaded Song'},
      ];
      userLocalSongs.value = [
        {'title': 'Local Audio File', 'path': '/storage/music.mp3'},
      ];

      final downloads = LibraryService.instance.loadDownloads();
      expect((downloads['offlineSongs'] as List).length, 1);
      expect((downloads['localSongs'] as List).length, 1);
    });
  });
}
