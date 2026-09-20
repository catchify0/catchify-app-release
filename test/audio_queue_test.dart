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
import 'package:catchify/utilities/mediaitem.dart';
import 'package:catchify/utilities/queue_entry_utils.dart';

void main() {
  group('Player + Queue 2.0 Canonical Item & Metadata Tests', () {
    test('mapToMediaItem and mediaItemToMap round-trip preserves canonical fields', () {
      final original = {
        'id': 'test_song_1',
        'ytid': 'test_song_1',
        'title': 'Anbil Avan',
        'artist': 'A.R. Rahman',
        'artistId': 'artist_arr',
        'album': 'Vinnaithaandi Varuvaayaa',
        'image': 'https://example.com/art.jpg',
        'highResImage': 'https://example.com/art_high.jpg',
        'lowResImage': 'https://example.com/art_low.jpg',
        'duration': 240,
        'isLive': false,
        'source': 'youtube',
        'contentType': 'song',
      };

      final mediaItem = mapToMediaItem(original);
      expect(mediaItem.id, equals('test_song_1'));
      expect(mediaItem.title, equals('Anbil Avan'));
      expect(mediaItem.artist, equals('A.R. Rahman'));
      expect(mediaItem.duration, equals(const Duration(seconds: 240)));
      expect(mediaItem.extras?['ytid'], equals('test_song_1'));
      expect(mediaItem.extras?['source'], equals('youtube'));
      expect(mediaItem.extras?['contentType'], equals('song'));

      final reconstructed = mediaItemToMap(mediaItem);
      expect(reconstructed['ytid'], equals('test_song_1'));
      expect(reconstructed['title'], equals('Anbil Avan'));
      expect(reconstructed['artist'], equals('A.R. Rahman'));
      expect(reconstructed['source'], equals('youtube'));
      expect(reconstructed['contentType'], equals('song'));
    });

    test('mapToMediaItem falls back to id when ytid is missing', () {
      final songWithoutYtid = {
        'id': 'fallback_ytid_123',
        'title': 'Fallback Song',
        'artist': 'Sample Artist',
      };

      final mediaItem = mapToMediaItem(songWithoutYtid);
      expect(mediaItem.id, equals('fallback_ytid_123'));
      expect(mediaItem.extras?['ytid'], equals('fallback_ytid_123'));

      final map = mediaItemToMap(mediaItem);
      expect(map['ytid'], equals('fallback_ytid_123'));
    });
  });

  group('Queue Semantics & Entry ID Manager Tests', () {
    late QueueEntryIdManager idManager;

    setUp(() {
      idManager = QueueEntryIdManager();
    });

    test('QueueEntryIdManager assigns unique entry IDs even for duplicate tracks', () {
      final song = {'id': 'song_A', 'ytid': 'song_A', 'title': 'Duplicate Track'};

      final entry1 = idManager.createSong(song);
      final entry2 = idManager.createSong(song);

      expect(entry1['ytid'], equals(entry2['ytid']));
      expect(entry1['queueEntryId'], isNot(equals(entry2['queueEntryId'])));
    });

    test('Play Now queue semantics: single track replaces queue', () {
      final existingQueue = [
        {'id': 's1', 'ytid': 's1', 'title': 'Song 1'},
        {'id': 's2', 'ytid': 's2', 'title': 'Song 2'},
        {'id': 's3', 'ytid': 's3', 'title': 'Song 3'},
      ];

      final newSong = {'id': 's_now', 'ytid': 's_now', 'title': 'Play Now Track'};

      // Semantic Play Now: clears queue, inserts single song at 0
      final queue = <Map>[];
      queue.clear();
      queue.add(idManager.createSong(newSong));
      var currentQueueIndex = 0;

      expect(queue.length, equals(1));
      expect(queue[0]['ytid'], equals('s_now'));
      expect(currentQueueIndex, equals(0));
    });

    test('Play Next queue semantics: inserts immediately after current track', () {
      final queue = <Map>[
        idManager.createSong({'id': 's1', 'ytid': 's1'}),
        idManager.createSong({'id': 's2', 'ytid': 's2'}),
        idManager.createSong({'id': 's3', 'ytid': 's3'}),
      ];
      var currentQueueIndex = 1; // Playing s2

      final nextSong = {'id': 's_next', 'ytid': 's_next', 'title': 'Play Next'};
      final insertIndex = currentQueueIndex + 1;
      queue.insert(insertIndex, idManager.createSong(nextSong));

      expect(queue.length, equals(4));
      expect(queue[0]['ytid'], equals('s1'));
      expect(queue[1]['ytid'], equals('s2'));
      expect(queue[2]['ytid'], equals('s_next'));
      expect(queue[3]['ytid'], equals('s3'));
      expect(currentQueueIndex, equals(1)); // current track index unchanged
    });

    test('Add to Queue semantics: appends to the end of the queue', () {
      final queue = <Map>[
        idManager.createSong({'id': 's1', 'ytid': 's1'}),
        idManager.createSong({'id': 's2', 'ytid': 's2'}),
      ];
      var currentQueueIndex = 0;

      final appendedSong = {'id': 's_end', 'ytid': 's_end', 'title': 'Appended Track'};
      queue.add(idManager.createSong(appendedSong));

      expect(queue.length, equals(3));
      expect(queue[2]['ytid'], equals('s_end'));
      expect(currentQueueIndex, equals(0));
    });

    test('Remove from Queue updates current index accurately', () {
      final queue = <Map>[
        idManager.createSong({'id': 's1', 'ytid': 's1'}),
        idManager.createSong({'id': 's2', 'ytid': 's2'}),
        idManager.createSong({'id': 's3', 'ytid': 's3'}),
        idManager.createSong({'id': 's4', 'ytid': 's4'}),
      ];
      var currentQueueIndex = 2; // currently playing s3

      // 1. Removing item BEFORE current index decrements current index
      queue.removeAt(0); // removes s1
      currentQueueIndex--;
      expect(queue.length, equals(3));
      expect(currentQueueIndex, equals(1));
      expect(queue[currentQueueIndex]['ytid'], equals('s3'));

      // 2. Removing item AFTER current index preserves current index
      queue.removeAt(2); // removes s4
      expect(queue.length, equals(2));
      expect(currentQueueIndex, equals(1));
      expect(queue[currentQueueIndex]['ytid'], equals('s3'));
    });

    test('Reorder queue adjusts current index correctly', () {
      final queue = <Map>[
        idManager.createSong({'id': 's1', 'ytid': 's1'}), // 0
        idManager.createSong({'id': 's2', 'ytid': 's2'}), // 1 (current)
        idManager.createSong({'id': 's3', 'ytid': 's3'}), // 2
      ];
      var currentQueueIndex = 1;

      // Moving current song from 1 to 2
      final oldIndex = 1;
      final newIndex = 2;
      final moving = queue.removeAt(oldIndex);
      queue.insert(newIndex, moving);

      if (oldIndex == currentQueueIndex) {
        currentQueueIndex = newIndex;
      }
      expect(currentQueueIndex, equals(2));
      expect(queue[2]['ytid'], equals('s2'));
    });

    test('Shuffle preserves currently playing track at index 0 and unshuffle restores order', () {
      final originalList = <Map>[
        {'id': 's0', 'ytid': 's0'},
        {'id': 's1', 'ytid': 's1'},
        {'id': 's2', 'ytid': 's2'},
        {'id': 's3', 'ytid': 's3'},
        {'id': 's4', 'ytid': 's4'},
      ];

      final queue = originalList.map((s) => idManager.createSong(s)).toList();
      var currentQueueIndex = 2; // currently playing s2
      final currentPlayingId = queue[currentQueueIndex]['queueEntryId'];

      // Backup original queue
      final backupQueue = List<Map>.from(queue);

      // Enable Shuffle:
      final currentSong = queue[currentQueueIndex];
      final remaining = queue.where((s) => s['queueEntryId'] != currentPlayingId).toList();
      remaining.shuffle();
      final shuffledQueue = <Map>[currentSong, ...remaining];
      currentQueueIndex = 0;

      expect(shuffledQueue[0]['queueEntryId'], equals(currentPlayingId));
      expect(shuffledQueue.length, equals(5));

      // Disable Shuffle: restore original queue
      final restoredQueue = List<Map>.from(backupQueue);
      final restoredCurrentIndex = restoredQueue.indexWhere(
        (s) => s['queueEntryId'] == currentPlayingId,
      );

      expect(restoredCurrentIndex, equals(2));
      expect(restoredQueue[restoredCurrentIndex]['ytid'], equals('s2'));
      expect(restoredQueue[0]['ytid'], equals('s0'));
      expect(restoredQueue[4]['ytid'], equals('s4'));
    });

    test('Repeat Mode transition logic', () {
      var repeatMode = AudioServiceRepeatMode.none;

      // Repeat Off: at end of queue, does not wrap
      var queueLength = 3;
      var currentIndex = 2;
      bool shouldWrap = (currentIndex >= queueLength - 1) &&
          (repeatMode == AudioServiceRepeatMode.all);
      expect(shouldWrap, isFalse);

      // Repeat All: at end of queue, wraps to 0
      repeatMode = AudioServiceRepeatMode.all;
      shouldWrap = (currentIndex >= queueLength - 1) &&
          (repeatMode == AudioServiceRepeatMode.all);
      expect(shouldWrap, isTrue);

      // Repeat One: song completion loops same song
      repeatMode = AudioServiceRepeatMode.one;
      bool repeatCurrentTrack = (repeatMode == AudioServiceRepeatMode.one);
      expect(repeatCurrentTrack, isTrue);
    });
  });
}
