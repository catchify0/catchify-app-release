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
import 'package:catchify/services/search_service.dart';

void main() {
  group('SearchService & Payload Unit Tests', () {
    test('SearchResultPayload JSON serialization and deserialization', () {
      final original = SearchResultPayload(
        query: 'test query',
        filter: SearchFilter.songs,
        topResult: {
          'id': 'top1',
          'title': 'Top Match',
          'topResultCategory': 'Song',
          'topResultType': 'song',
        },
        songs: [
          {'id': 's1', 'title': 'Song One', 'artist': 'Artist One'}
        ],
        albums: [
          {'id': 'a1', 'title': 'Album One'}
        ],
        artists: [
          {'id': 'art1', 'name': 'Artist One'}
        ],
        playlists: [
          {'id': 'p1', 'title': 'Playlist One'}
        ],
        videos: [
          {'id': 'v1', 'title': 'Video One', 'isVideo': true}
        ],
        timestamp: DateTime(2026, 9, 17, 12, 0, 0),
      );

      final json = original.toJson();
      expect(json['query'], equals('test query'));
      expect(json['filter'], equals('songs'));
      expect(json['topResult'], isNotNull);
      expect(json['songs'], isA<List>());

      final restored = SearchResultPayload.fromJson(json);
      expect(restored.query, equals(original.query));
      expect(restored.filter, equals(SearchFilter.songs));
      expect(restored.topResult?['id'], equals('top1'));
      expect(restored.songs.length, equals(1));
      expect(restored.albums.length, equals(1));
      expect(restored.artists.length, equals(1));
      expect(restored.playlists.length, equals(1));
      expect(restored.videos.length, equals(1));
      expect(restored.isNotEmpty, isTrue);
      expect(restored.isEmpty, isFalse);
    });

    test('Empty SearchResultPayload handles checks correctly', () {
      final empty = SearchResultPayload(
        query: '',
        timestamp: DateTime.now(),
      );

      expect(empty.isEmpty, isTrue);
      expect(empty.isNotEmpty, isFalse);
    });

    test('SearchFilter enum values are correctly resolved', () {
      expect(SearchFilter.values.length, equals(6));
      expect(SearchFilter.values, contains(SearchFilter.all));
      expect(SearchFilter.values, contains(SearchFilter.songs));
      expect(SearchFilter.values, contains(SearchFilter.albums));
      expect(SearchFilter.values, contains(SearchFilter.artists));
      expect(SearchFilter.values, contains(SearchFilter.playlists));
      expect(SearchFilter.values, contains(SearchFilter.videos));
    });

    test('Search history capping at 25 items', () {
      final history = <String>[];
      for (var i = 0; i < 30; i++) {
        history.remove('Query $i');
        history.insert(0, 'Query $i');
        if (history.length > 25) {
          history.removeRange(25, history.length);
        }
      }

      expect(history.length, equals(25));
      expect(history.first, equals('Query 29'));
    });
  });
}
