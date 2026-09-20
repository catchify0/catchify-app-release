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

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/services/data_manager.dart';
import 'package:catchify/services/playlists_manager.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:hive_flutter/hive_flutter.dart';

class _AllowAllHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

void main() {
  HttpOverrides.global = _AllowAllHttpOverrides();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('catchify_cache_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
    await Hive.openBox('cache');
    await Hive.openBox('user');
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  test('Cache validation: keys are language-namespaced and isolated', () async {
    final cacheBox = Hive.box('cache');
    await cacheBox.clear();

    // 1. Load Tamil
    setContentLanguagePreference('ta');
    expect(contentLanguagePreference, equals('ta'));
    final taFeed1 = await getUnifiedHomeFeed(forceRefresh: true);
    expect(taFeed1, isNotEmpty);

    // Verify cache key format
    final expectedTaKey = 'ytm_home_feed_v9_ta_en_IN_All';
    final taCachedData = await getData('cache', expectedTaKey);
    expect(
      taCachedData,
      isNotNull,
      reason: 'Tamil cache key must exist in cache',
    );

    // 2. Load Hindi
    setContentLanguagePreference('hi');
    expect(contentLanguagePreference, equals('hi'));
    final hiFeed = await getUnifiedHomeFeed(forceRefresh: true);
    expect(hiFeed, isNotEmpty);

    final expectedHiKey = 'ytm_home_feed_v9_hi_en_IN_All';
    final hiCachedData = await getData('cache', expectedHiKey);
    expect(
      hiCachedData,
      isNotNull,
      reason: 'Hindi cache key must exist in cache',
    );

    // 3. Return to Tamil with forceRefresh: false (cached retrieval)
    setContentLanguagePreference('ta');
    expect(contentLanguagePreference, equals('ta'));
    final taFeedCached = await getUnifiedHomeFeed(forceRefresh: false);
    expect(taFeedCached, isNotEmpty);

    // Confirm that returning to Tamil reuses Tamil cached feed
    final ta1FirstItem = taFeed1.first.contents.isNotEmpty ? (taFeed1.first.contents.first['ytid'] ?? taFeed1.first.contents.first['id'] ?? taFeed1.first.contents.first['title']) : null;
    final taCachedFirstItem = taFeedCached.first.contents.isNotEmpty ? (taFeedCached.first.contents.first['ytid'] ?? taFeedCached.first.contents.first['id'] ?? taFeedCached.first.contents.first['title']) : null;
    final hiFirstItem = hiFeed.first.contents.isNotEmpty ? (hiFeed.first.contents.first['ytid'] ?? hiFeed.first.contents.first['id'] ?? hiFeed.first.contents.first['title']) : null;

    print('DEBUG ta1: $ta1FirstItem');
    print('DEBUG taCached: $taCachedFirstItem');
    print('DEBUG hi: $hiFirstItem');

    if (ta1FirstItem != null && taCachedFirstItem != null) {
      expect(
        taCachedFirstItem,
        equals(ta1FirstItem),
        reason: 'Cached Tamil feed should return the same top item',
      );
      if (hiFirstItem != null) {
        expect(
          taCachedFirstItem,
          isNot(equals(hiFirstItem)),
          reason: 'Cached Tamil feed must NOT match Hindi feed item',
        );
      }
    }
  }, timeout: const Timeout(Duration(seconds: 120)));
}
