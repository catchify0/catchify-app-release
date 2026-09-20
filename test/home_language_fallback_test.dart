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

import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/models/home_section.dart';
import 'package:catchify/services/home_feed_composer.dart';

void main() {
  group('Home Language Fallback & Failure Handling', () {
    const remoteShelves = [
      HomeSection(
        title: 'Mixed for you',
        type: HomeContentType.playlists,
        contents: [
          {'id': 'rem1', 'title': 'Remote Song 1'},
          {'id': 'rem2', 'title': 'Remote Song 2'},
        ],
      ),
      HomeSection(
        title: 'Featured albums',
        type: HomeContentType.albums,
        contents: [
          {'id': 'rem3', 'title': 'Remote Album 1'},
        ],
      ),
    ];

    const languageShelves = [
      HomeSection(
        title: 'Trending songs for you',
        type: HomeContentType.songs,
        contents: [
          {'id': 'lang1', 'title': 'Language Trending 1'},
          {'id': 'lang2', 'title': 'Language Trending 2'},
        ],
      ),
      HomeSection(
        title: 'Featured playlists',
        type: HomeContentType.playlists,
        contents: [
          {'id': 'lang3', 'title': 'Language Playlist 1'},
        ],
      ),
    ];

    const personalShelves = [
      HomeSection(
        title: 'Made for you',
        type: HomeContentType.playlists,
        contents: [
          {'id': 'user1', 'title': 'Personal 1'},
        ],
      ),
    ];

    test('Case 1: Remote succeeds + language succeeds -> remote + language + personalization', () {
      final feed = HomeFeedComposer.compose(
        remoteSections: remoteShelves,
        languageSections: languageShelves,
        personalizedSections: personalShelves,
      );

      expect(feed, isNotEmpty);
      expect(feed.any((s) => s.title == 'Trending songs for you'), isTrue);
      expect(feed.any((s) => s.title == 'Featured playlists'), isTrue);
      expect(feed.any((s) => s.title == 'Made for you'), isTrue);
      expect(feed.any((s) => s.title == 'Mixed for you'), isTrue);

      // Verify language shelf is in top slot
      expect(feed.first.title, equals('Trending songs for you'));
      expect(feed[1].title, equals('Featured playlists'));
    });

    test('Case 2: Remote succeeds + language fails (empty) -> remote + personalization without crash', () {
      final feed = HomeFeedComposer.compose(
        remoteSections: remoteShelves,
        languageSections: [], // language failed / empty
        personalizedSections: personalShelves,
      );

      expect(feed, isNotEmpty);
      expect(feed.any((s) => s.title == 'Trending songs for you'), isFalse);
      expect(feed.any((s) => s.title == 'Made for you'), isTrue);
      expect(feed.any((s) => s.title == 'Mixed for you'), isTrue);
    });

    test('Case 3: Remote fails (empty) + language succeeds -> language + personalization without crash', () {
      final feed = HomeFeedComposer.compose(
        remoteSections: [], // remote failed / empty
        languageSections: languageShelves,
        personalizedSections: personalShelves,
      );

      expect(feed, isNotEmpty);
      expect(feed.any((s) => s.title == 'Trending songs for you'), isTrue);
      expect(feed.any((s) => s.title == 'Featured playlists'), isTrue);
      expect(feed.any((s) => s.title == 'Made for you'), isTrue);
      expect(feed.first.title, equals('Trending songs for you'));
    });

    test('Case 4: Both fail (empty) -> empty list returned safely without exception', () {
      final feed = HomeFeedComposer.compose(
        remoteSections: [],
        languageSections: [],
        personalizedSections: [],
      );

      expect(feed, isEmpty);
    });

    test('Accidental duplicate titles between remote and language sections are pruned', () {
      const remoteWithDuplicate = [
        HomeSection(
          title: 'Trending songs for you', // duplicate title with language shelf
          type: HomeContentType.songs,
          contents: [
            {'id': 'dup1', 'title': 'Duplicate Song'},
          ],
        ),
        HomeSection(
          title: 'Recommended albums',
          type: HomeContentType.albums,
          contents: [
            {'id': 'rem4', 'title': 'Remote Album'},
          ],
        ),
      ];

      final feed = HomeFeedComposer.compose(
        remoteSections: remoteWithDuplicate,
        languageSections: languageShelves,
        personalizedSections: [],
      );

      // Only one 'Trending songs for you' shelf should exist
      final trendingShelves = feed.where((s) => s.title.toLowerCase().contains('trending songs'));
      expect(trendingShelves.length, equals(1));
      // And it must be the language shelf (id lang1)
      expect(trendingShelves.first.contents.first['id'], equals('lang1'));
    });
  });
}
