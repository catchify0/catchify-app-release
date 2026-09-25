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

/// Represents a single line of lyrics with its timestamp
class LyricLine {
  LyricLine({required this.timeInMs, required this.text, this.endTimeInMs});

  /// Timestamp in milliseconds
  final int timeInMs;

  /// Lyric text for this line
  final String text;

  /// Optional end timestamp in milliseconds (e.g. vocal pause or instrumental break)
  final int? endTimeInMs;

  @override
  String toString() => 'LyricLine($timeInMs, $text, end: $endTimeInMs)';
}

/// Parser for LRC format lyrics
class LrcParser {
  static final RegExp _timestampPattern = RegExp(
    r'\[\s*\d{1,3}:\d{2}(?:[.:]\d+)?\s*\]',
  );
  static final RegExp _wordSyncPattern = RegExp(
    r'<\s*\d{1,3}:\d{2}(?:[.:]\d+)?\s*>',
  );
  static final RegExp _metadataPattern = RegExp(r'\[[a-zA-Z]+:[^\]]*\]');

  /// Cleans any LRC timestamps, word-level sync tags, and metadata tags from raw lyrics,
  /// returning clean human-readable text for plain lyrics display.
  static String cleanLyrics(String raw) {
    if (raw.isEmpty) return '';
    return raw
        .replaceAll(_timestampPattern, '')
        .replaceAll(_wordSyncPattern, '')
        .replaceAll(_metadataPattern, '')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n');
  }

  /// Parses LRC format lyrics into a list of [LyricLine]
  ///
  /// LRC format example:
  /// ```
  /// [00:12.34]First line
  /// [00:15.67]Second line
  /// [01:23.45]Third line
  /// ```
  static List<LyricLine> parse(String lyrics) {
    if (lyrics.isEmpty) return <LyricLine>[];

    // Check for standard LRC metadata [offset:+/-xxx] in milliseconds
    final offsetPattern = RegExp(
      r'\[offset:\s*([+-]?\d+)\s*\]',
      caseSensitive: false,
    );
    final offsetMatch = offsetPattern.firstMatch(lyrics);
    final lrcOffset = offsetMatch != null
        ? (int.tryParse(offsetMatch.group(1) ?? '0') ?? 0)
        : 0;

    final tagPattern = RegExp(r'\[\s*(\d{1,3}):(\d{2})(?:[.:](\d+))?\s*\]');

    final rawLines = <LyricLine>[];
    final breakTimes = <int>[];

    // Process line-by-line to prevent whitespace regex from bridging newlines
    // across empty break tags and subsequent lyric lines.
    for (final rawLine in lyrics.split(RegExp(r'\r?\n'))) {
      final trimmedLine = rawLine.trim();
      if (trimmedLine.isEmpty) continue;

      final tagMatches = tagPattern.allMatches(trimmedLine).toList();
      if (tagMatches.isEmpty) continue;

      final text = trimmedLine
          .replaceAll(_timestampPattern, '')
          .replaceAll(_wordSyncPattern, '')
          .replaceAll(_metadataPattern, '')
          .trim();

      for (final tagMatch in tagMatches) {
        try {
          final minutes = int.parse(tagMatch.group(1)!);
          final seconds = int.parse(tagMatch.group(2)!);
          final msStr = tagMatch.group(3);

          var ms = 0;
          if (msStr != null) {
            if (msStr.length == 1) {
              ms = int.parse(msStr) * 100;
            } else if (msStr.length == 2) {
              ms = int.parse(msStr) * 10;
            } else if (msStr.length == 3) {
              ms = int.parse(msStr);
            } else if (msStr.length > 3) {
              ms = int.parse(msStr.substring(0, 3));
            }
          }

          final rawTimeInMs = (minutes * 60 + seconds) * 1000 + ms;
          final timeInMs = rawTimeInMs - lrcOffset;
          final safeTimeInMs = timeInMs >= 0 ? timeInMs : 0;

          if (text.isNotEmpty) {
            rawLines.add(LyricLine(timeInMs: safeTimeInMs, text: text));
          } else {
            // An empty timestamp line marks the vocal end/pause of the preceding lyric
            breakTimes.add(safeTimeInMs);
          }
        } catch (_) {
          continue;
        }
      }
    }

    // Deduplicate lines with identical timestamp and text, then sort chronologically
    final seen = <String>{};
    final lines = <LyricLine>[];
    for (final line in rawLines) {
      if (seen.add('${line.timeInMs}:${line.text}')) {
        lines.add(line);
      }
    }
    lines.sort((a, b) => a.timeInMs.compareTo(b.timeInMs));
    breakTimes.sort();

    // Attach end-of-vocal timestamps for instrumental breaks and long pauses
    final result = <LyricLine>[];
    for (var i = 0; i < lines.length; i++) {
      final current = lines[i];
      final nextTime = i + 1 < lines.length ? lines[i + 1].timeInMs : null;

      int? endTime;
      // 1. Look for explicit break/empty tag between this line and the next
      for (final bt in breakTimes) {
        if (bt > current.timeInMs && (nextTime == null || bt < nextTime)) {
          endTime = bt;
          break;
        }
      }

      // 2. If no explicit end tag, but gap to next line > 8 seconds, estimate vocal pause
      if (endTime == null &&
          nextTime != null &&
          (nextTime - current.timeInMs > 8000)) {
        final estimatedSingingMs = (current.text.length * 120).clamp(
          4000,
          8000,
        );
        endTime = current.timeInMs + estimatedSingingMs;
      }

      result.add(
        LyricLine(
          timeInMs: current.timeInMs,
          text: current.text,
          endTimeInMs: endTime,
        ),
      );
    }

    return result;
  }

  /// Checks if the lyrics are in LRC format (synced)
  static bool isSynced(String lyrics) {
    return RegExp(r'\[\s*\d{1,3}:\d{2}(?:[.:]\d+)?\s*\]').hasMatch(lyrics);
  }

  /// Finds the current line index based on playback position and optional user offset.
  /// Returns the matching index, or -1 if the playback position is before the first line
  /// or during an instrumental pause where vocals have stopped.
  static int findCurrentLineIndex(
    List<LyricLine> lines,
    int positionMs, {
    int userOffsetMs = 0,
  }) {
    if (lines.isEmpty) return -1;
    final adjustedMs = positionMs + userOffsetMs;

    for (var i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      if (line.timeInMs <= adjustedMs) {
        if (line.endTimeInMs != null && adjustedMs >= line.endTimeInMs!) {
          return -1;
        }
        return i;
      }
    }

    return -1;
  }
}
