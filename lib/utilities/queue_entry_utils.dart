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

class QueueEntryIdManager {
  int _counter = 0;

  String nextId() {
    return 'queue-${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
  }

  String ensureId(Map song) {
    final existingId = song['queueEntryId']?.toString();
    if (existingId != null && existingId.isNotEmpty) {
      return existingId;
    }

    final generatedId = nextId();
    song['queueEntryId'] = generatedId;
    return generatedId;
  }

  Map<String, dynamic> createSong(Map song) {
    final queueSong = Map<String, dynamic>.from(song);
    queueSong['queueEntryId'] = nextId();
    return queueSong;
  }

  void ensureIds(Iterable<Map> songs) {
    for (final song in songs) {
      ensureId(song);
    }
  }
}

/// Returns the stable YouTube video identifier used across queue and radio
/// state. The legacy `id` field is accepted for restored/older entries.
String? canonicalSongId(Map song) {
  final value = song['ytid'] ?? song['id'];
  final id = value?.toString().trim();
  return id == null || id.isEmpty ? null : id;
}
