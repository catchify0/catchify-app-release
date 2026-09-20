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
    tempDir = await Directory.systemTemp.createTemp('catchify_race_test_');
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

  test('Race condition validation: Newer language request protects against stale overwrites', () async {
    final cacheBox = Hive.box('cache');
    await cacheBox.clear();

    // Fire Tamil request
    setContentLanguagePreference('ta');
    final taFuture = getUnifiedHomeFeed(forceRefresh: true);

    // Immediately switch to Hindi and fire Hindi request
    setContentLanguagePreference('hi');
    final hiFuture = getUnifiedHomeFeed(forceRefresh: true);

    // Wait for both to complete
    final results = await Future.wait([taFuture, hiFuture]);
    final taFeed = results[0];
    final hiFeed = results[1];

    expect(taFeed, isNotEmpty);
    expect(hiFeed, isNotEmpty);

    // Current preference should be Hindi
    expect(contentLanguagePreference, equals('hi'));

    // Fetching again without forceRefresh should yield Hindi feed, NOT Tamil
    final currentFeed = await getUnifiedHomeFeed(forceRefresh: false);
    expect(currentFeed, isNotEmpty);

    final hiTopItem = hiFeed.first.contents.isNotEmpty ? hiFeed.first.contents.first['id'] : null;
    final currentTopItem = currentFeed.first.contents.isNotEmpty ? currentFeed.first.contents.first['id'] : null;

    if (hiTopItem != null && currentTopItem != null) {
      expect(
        currentTopItem,
        equals(hiTopItem),
        reason: 'Current cached feed must match Hindi (the latest requested language), not superseded Tamil',
      );
    }
  }, timeout: const Timeout(Duration(seconds: 120)));
}
