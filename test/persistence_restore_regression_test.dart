/*
 *     Copyright (C) 2026 Thamodharan Ganesan
 *
 *     Catchify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:catchify/services/common_services.dart';
import 'package:catchify/services/data_manager.dart';
import 'package:catchify/services/playlists_manager.dart';
import 'package:catchify/services/settings_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'catchify_persistence_regression_',
    );
    Hive.init(tempDir.path);
    await Hive.openBox('user');
    await Hive.openBox('userNoBackup');
    await Hive.openBox('settings');
    await Hive.openBox('cache');
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('reload normalizes malformed restored library and settings values', () async {
    await Hive.box('user').put('likedSongs', {'not': 'a list'});
    await Hive.box('user').put('recentlyPlayedSongs', 42);
    await Hive.box('user').put('playlists', ['valid', 99]);
    await Hive.box('user').put('customPlaylists', ['not a map']);
    await Hive.box('user').put('likedPlaylists', [42]);
    await Hive.box('user').put('playlistFolders', [null]);
    await Hive.box('user').put('pinnedPlaylistIds', ['pin', 7]);

    await Hive.box('settings').put('useProxy', 'yes');
    await Hive.box('settings').put('lyricsOffsetMs', 'fast');
    await Hive.box('settings').put('equalizerBandGains', ['bad', 1.5]);
    await Hive.box('settings').put('languageCode', 123);
    await Hive.box('settings').put('contentLanguageCode', []);

    expect(reloadSongLibraryStateFromStorage, returnsNormally);
    expect(reloadPlaylistLibraryStateFromStorage, returnsNormally);
    expect(reloadSettingsFromStorage, returnsNormally);

    expect(userLikedSongsList.value, isEmpty);
    expect(userRecentlyPlayed.value, isEmpty);
    expect(userPlaylists.value, ['valid']);
    expect(userCustomPlaylists.value, isEmpty);
    expect(userLikedPlaylists.value, isEmpty);
    expect(userPlaylistFolders.value, isEmpty);
    expect(pinnedPlaylistIds.value, ['pin']);
    expect(useProxy.value, isFalse);
    expect(lyricsOffsetNotifier.value, 0);
    expect(equalizerBandGains.value, [0.0, 1.5]);
    expect(languageSetting, isNotNull);
    expect(contentLanguagePreference, isNotNull);
  });

  test('malformed cache timestamps are treated as expired instead of crashing', () async {
    await clearCache();
    final cacheBox = Hive.box('cache');
    await cacheBox.put('malformed_cache', ['stale']);
    await cacheBox.put('malformed_cache_date', 'not a timestamp');

    final value = await getData(
      'cache',
      'malformed_cache',
      defaultValue: const <dynamic>[],
    );

    expect(value, isEmpty);
    expect(cacheBox.containsKey('malformed_cache'), isFalse);
    expect(cacheBox.containsKey('malformed_cache_date'), isFalse);
  });
}
