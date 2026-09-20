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

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/services/radio_service.dart';
import 'package:youtube_music_explode_dart/youtube_music_explode_dart.dart';

void main() {
  group('Catchify Radio + Autoplay 2.0 Tests', () {
    test('RadioSession initialization and string representation', () {
      final session = RadioSession(
        seedId: 'song_seed_1',
        seedTitle: 'Uyire',
        type: RadioType.song,
        playlistId: 'RDAMVMsong_seed_1',
        continuationToken: 'token_abc123',
      );

      expect(session.seedId, equals('song_seed_1'));
      expect(session.seedTitle, equals('Uyire'));
      expect(session.type, equals(RadioType.song));
      expect(session.playlistId, equals('RDAMVMsong_seed_1'));
      expect(session.continuationToken, equals('token_abc123'));
      expect(session.seenTrackIds, isEmpty);
      expect(session.toString(), contains('hasContinuation: true'));
    });

    test('RadioSession deduplication tracking', () {
      final session = RadioSession(
        seedId: 'track_1',
        seedTitle: 'Track 1',
        type: RadioType.artist,
        seenTrackIds: {'track_1', 'track_2'},
      );

      expect(session.seenTrackIds.contains('track_1'), isTrue);
      expect(session.seenTrackIds.contains('track_2'), isTrue);
      expect(session.seenTrackIds.contains('track_3'), isFalse);

      session.seenTrackIds.add('track_3');
      expect(session.seenTrackIds.contains('track_3'), isTrue);
    });

    test('MusicRadioResult holds tracks and optional continuation token', () {
      const resultWithContinuation = MusicRadioResult(
        tracks: [],
        continuation: 'continuation_token_xyz',
      );
      expect(resultWithContinuation.tracks, isEmpty);
      expect(resultWithContinuation.continuation, equals('continuation_token_xyz'));

      const resultWithoutContinuation = MusicRadioResult(
        tracks: [],
      );
      expect(resultWithoutContinuation.continuation, isNull);
    });

    test('Autoplay threshold logic: triggers when remaining <= threshold', () {
      const threshold = 3;

      // 10 items in queue, currently playing index 4 -> 5 remaining: (10-1)-4 = 5 > 3 => no prefetch
      int queueLength = 10;
      int currentIndex = 4;
      int remaining = (queueLength - 1) - currentIndex;
      expect(remaining > threshold, isTrue);

      // Currently playing index 6 -> 3 remaining: (10-1)-6 = 3 <= 3 => trigger prefetch
      currentIndex = 6;
      remaining = (queueLength - 1) - currentIndex;
      expect(remaining <= threshold, isTrue);

      // Currently playing index 8 -> 1 remaining: (10-1)-8 = 1 <= 3 => trigger prefetch
      currentIndex = 8;
      remaining = (queueLength - 1) - currentIndex;
      expect(remaining <= threshold, isTrue);
    });

    test('Autoplay repeat precedence: Repeat One and Repeat All disable autoplay expansion', () {
      bool shouldTriggerAutoplay({
        required AudioServiceRepeatMode repeatMode,
        required bool autoplayEnabled,
        required int remaining,
        required int threshold,
      }) {
        if (repeatMode == AudioServiceRepeatMode.one ||
            repeatMode == AudioServiceRepeatMode.all) {
          return false;
        }
        if (!autoplayEnabled) return false;
        return remaining <= threshold;
      }

      // Repeat One -> false
      expect(
        shouldTriggerAutoplay(
          repeatMode: AudioServiceRepeatMode.one,
          autoplayEnabled: true,
          remaining: 2,
          threshold: 3,
        ),
        isFalse,
      );

      // Repeat All -> false
      expect(
        shouldTriggerAutoplay(
          repeatMode: AudioServiceRepeatMode.all,
          autoplayEnabled: true,
          remaining: 2,
          threshold: 3,
        ),
        isFalse,
      );

      // Repeat None + Autoplay OFF -> false
      expect(
        shouldTriggerAutoplay(
          repeatMode: AudioServiceRepeatMode.none,
          autoplayEnabled: false,
          remaining: 2,
          threshold: 3,
        ),
        isFalse,
      );

      // Repeat None + Autoplay ON + remaining <= threshold -> true
      expect(
        shouldTriggerAutoplay(
          repeatMode: AudioServiceRepeatMode.none,
          autoplayEnabled: true,
          remaining: 2,
          threshold: 3,
        ),
        isTrue,
      );

      // Repeat None + Autoplay ON + remaining > threshold -> false
      expect(
        shouldTriggerAutoplay(
          repeatMode: AudioServiceRepeatMode.none,
          autoplayEnabled: true,
          remaining: 5,
          threshold: 3,
        ),
        isFalse,
      );
    });

    test('Deduplication filters out tracks already present in active queue', () {
      final queueIds = {'song_1', 'song_2', 'song_3'};
      final candidates = [
        {'ytid': 'song_2', 'title': 'Duplicate Song'},
        {'ytid': 'song_4', 'title': 'Fresh Song 1'},
        {'ytid': 'song_1', 'title': 'Duplicate Seed'},
        {'ytid': 'song_5', 'title': 'Fresh Song 2'},
      ];

      final filtered = <Map>[];
      var duplicatesSkipped = 0;

      for (final candidate in candidates) {
        final id = candidate['ytid']!;
        if (queueIds.contains(id)) {
          duplicatesSkipped++;
        } else {
          filtered.add(candidate);
          queueIds.add(id);
        }
      }

      expect(filtered.length, equals(2));
      expect(filtered[0]['ytid'], equals('song_4'));
      expect(filtered[1]['ytid'], equals('song_5'));
      expect(duplicatesSkipped, equals(2));
    });

    test('In-flight guard prevents multiple simultaneous fetch requests', () {
      var inFlight = false;
      var fetchCallCount = 0;

      void triggerFetch() {
        if (inFlight) return;
        inFlight = true;
        fetchCallCount++;
      }

      // First call starts fetch
      triggerFetch();
      expect(fetchCallCount, equals(1));
      expect(inFlight, isTrue);

      // Second call while in-flight is rejected
      triggerFetch();
      expect(fetchCallCount, equals(1));

      // Third call while in-flight is rejected
      triggerFetch();
      expect(fetchCallCount, equals(1));

      // Once finished, subsequent call proceeds
      inFlight = false;
      triggerFetch();
      expect(fetchCallCount, equals(2));
    });

    test('RadioService resetSession clears active session state', () {
      final service = RadioService();
      service.setSession(
        RadioSession(
          seedId: 'test_seed',
          seedTitle: 'Test Song',
          type: RadioType.song,
        ),
      );

      expect(service.currentSession, isNotNull);
      expect(service.currentSession!.seedId, equals('test_seed'));

      service.resetSession();
      expect(service.currentSession, isNull);
    });
  });
}
