import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/utilities/formatter.dart';
import 'package:catchify/utilities/mediaitem.dart';
import 'package:audio_service/audio_service.dart';

void main() {
  group('formatDuration tests', () {
    test('formats standard seconds correctly', () {
      expect(formatDuration(0), '00:00');
      expect(formatDuration(5), '00:05');
      expect(formatDuration(65), '01:05');
      expect(formatDuration(3600), '01:00:00');
      expect(formatDuration(3665), '01:01:05');
    });

    test('handles negative values safely', () {
      expect(formatDuration(-10), '00:00');
    });

    test('handles Duration objects', () {
      expect(formatDuration(const Duration(seconds: 125)), '02:05');
      expect(
        formatDuration(const Duration(hours: 2, minutes: 3, seconds: 4)),
        '02:03:04',
      );
    });

    test('handles String representations safely', () {
      expect(formatDuration('150'), '02:30');
      expect(formatDuration('invalid'), '00:00');
      expect(formatDuration(null), '00:00');
    });

    test('handles double and num representations', () {
      expect(formatDuration(120.4), '02:00');
      expect(formatDuration(120.6), '02:01');
    });
  });

  group('MediaItem mapping duration preservation', () {
    test('mediaItemToMap preserves duration in seconds', () {
      final item = MediaItem(
        id: '123',
        title: 'Test Title',
        duration: const Duration(seconds: 215),
      );

      final map = mediaItemToMap(item);
      expect(map['duration'], 215);
      expect(map['title'], 'Test Title');
    });

    test('mediaItemToMap handles null duration', () {
      final item = MediaItem(id: '123', title: 'Test Title');

      final map = mediaItemToMap(item);
      expect(map['duration'], isNull);
    });

    test('durationEquals tolerates minor differences', () {
      expect(
        durationEquals(
          const Duration(seconds: 100),
          const Duration(milliseconds: 100500),
        ),
        isTrue,
      );
      expect(
        durationEquals(
          const Duration(seconds: 100),
          const Duration(seconds: 105),
        ),
        isFalse,
      );
    });

    test('Spotify duration parsing handles ms and mm:ss formats', () {
      int? parseDurationSeconds(String raw) {
        final clean = raw.trim();
        if (clean.isEmpty) return null;
        if (clean.contains(':')) {
          final parts = clean.split(':');
          var s = 0;
          for (final p in parts) {
            final n = int.tryParse(p.trim());
            if (n == null) return null;
            s = s * 60 + n;
          }
          return s > 0 ? s : null;
        }
        final n = int.tryParse(clean) ?? double.tryParse(clean)?.round();
        if (n != null && n > 0) {
          if (n > 10000) {
            return (n / 1000).round();
          }
          return n;
        }
        return null;
      }

      expect(parseDurationSeconds('215430'), 215);
      expect(formatDuration(parseDurationSeconds('215430')), '03:35');
      expect(parseDurationSeconds('3:35'), 215);
      expect(formatDuration(parseDurationSeconds('3:35')), '03:35');
      expect(parseDurationSeconds('215'), 215);
    });
  });
}
