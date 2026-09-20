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
    tempDir = await Directory.systemTemp.createTemp('catchify_lang_diff_');
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

  test(
    'Runtime Home Feed content meaningfully differs between Tamil, Hindi, and Telugu',
    () async {
      final languagesToTest = ['ta', 'hi', 'te'];
      final results = <String, Map<String, dynamic>>{};

      for (final lang in languagesToTest) {
        setContentLanguagePreference(lang);
        expect(contentLanguagePreference, equals(lang));
        expect(contentLanguagePreferenceNotifier.value, equals(lang));

        // Fetch fresh feed bypassing any cache
        final feed = await getUnifiedHomeFeed(forceRefresh: true);

        expect(feed, isNotEmpty, reason: 'Feed should not be empty for $lang');

        final allItemIds = <String>[];
        final sectionSummary = <String>[];

        for (var i = 0; i < feed.length; i++) {
          final section = feed[i];
          sectionSummary.add(
            '${section.title} (${section.contents.length} items)',
          );
          for (final item in section.contents) {
            final id =
                item['ytid']?.toString() ??
                item['id']?.toString() ??
                item['browseId']?.toString() ??
                '';
            if (id.isNotEmpty) {
              allItemIds.add(id);
            }
          }
        }

        final uniqueIds = allItemIds.toSet();
        final first20Ids = allItemIds.take(20).toList();

        results[lang] = {
          'sectionCount': feed.length,
          'sections': sectionSummary,
          'totalItems': allItemIds.length,
          'uniqueIds': uniqueIds.length,
          'first20Ids': first20Ids,
          'firstSectionTitle': feed.first.title,
          'secondSectionTitle': feed.length > 1 ? feed[1].title : '',
        };

        print('\n========================================');
        print('=== RUNTIME FEED REPORT FOR [$lang] ===');
        print('========================================');
        print('Total sections: ${feed.length}');
        print('Top sections:');
        for (var i = 0; i < feed.take(5).length; i++) {
          print(
            '  [$i] ${feed[i].title} (${feed[i].type.name}): ${feed[i].contents.length} items',
          );
          if (feed[i].contents.isNotEmpty) {
            final topItem = feed[i].contents.first;
            print(
              '       Top item: "${topItem['title']}" by "${topItem['artist']}" [id=${topItem['ytid'] ?? topItem['id']}]',
            );
          }
        }
        print('Total unique item IDs: ${uniqueIds.length}');
        print('First 10 item IDs: ${first20Ids.take(10).toList()}');
      }

      final taData = results['ta']!;
      final hiData = results['hi']!;
      final teData = results['te']!;

      final taFirst20 = (taData['first20Ids'] as List<String>).toSet();
      final hiFirst20 = (hiData['first20Ids'] as List<String>).toSet();
      final teFirst20 = (teData['first20Ids'] as List<String>).toSet();

      // Calculate overlap between top items
      final taHiOverlap = taFirst20.intersection(hiFirst20).length;
      final taTeOverlap = taFirst20.intersection(teFirst20).length;
      final hiTeOverlap = hiFirst20.intersection(teFirst20).length;

      print('\n========================================');
      print('=== CONTENT OVERLAP / DIVERGENCE AUDIT ===');
      print('========================================');
      print('Tamil vs Hindi top 20 overlap: $taHiOverlap / 20 items');
      print('Tamil vs Telugu top 20 overlap: $taTeOverlap / 20 items');
      print('Hindi vs Telugu top 20 overlap: $hiTeOverlap / 20 items');

      // CRITICAL ACCEPTANCE CRITERION:
      // The top 20 items between distinct regional languages MUST be meaningfully different!
      // Overlap should be less than 6 items (i.e. at least 70% different).
      expect(
        taHiOverlap,
        lessThan(6),
        reason: 'Tamil and Hindi top items must be overwhelmingly different',
      );
      expect(
        taTeOverlap,
        lessThan(6),
        reason: 'Tamil and Telugu top items must be overwhelmingly different',
      );
      expect(
        hiTeOverlap,
        lessThan(6),
        reason: 'Hindi and Telugu top items must be overwhelmingly different',
      );

      // Verify UI/Shelf titles remain clean English (no regional transliterations)
      for (final lang in languagesToTest) {
        final feedSections = results[lang]!['sections'] as List<String>;
        final hasTamilTransliteration = feedSections.any(
          (s) => s.contains('தமி') || s.contains('தமிழ்'),
        );
        final hasHindiTransliteration = feedSections.any(
          (s) => s.contains('हिन्दी') || s.contains('हिंदी'),
        );
        expect(
          hasTamilTransliteration,
          isFalse,
          reason: 'Shelf titles must not use regional scripts',
        );
        expect(
          hasHindiTransliteration,
          isFalse,
          reason: 'Shelf titles must not use regional scripts',
        );
      }
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
