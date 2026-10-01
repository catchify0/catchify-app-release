import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/utilities/formatter.dart';

void main() {
  group('YouTube Music Audio-Only Sanitization & Layout Tests', () {
    test('formatSongTitle strips video, teaser, and promo suffixes', () {
      expect(formatSongTitle('Radhimaa (Music Video)'), 'Radhimaa');
      expect(
        formatSongTitle('Pavazha Malli (Official Music Video)'),
        'Pavazha Malli',
      );
      expect(
        formatSongTitle('Hukum - Alappara Theme (Lyric Video)'),
        'Hukum - Alappara Theme',
      );
      expect(formatSongTitle('Aasa Kooda [Official Video]'), 'Aasa Kooda');
      expect(formatSongTitle('Song Title [Official 4K Video]'), 'Song Title');
      expect(formatSongTitle('Track Name (Official Audio)'), 'Track Name');
    });

    test(
      'formatArtworkResolution produces 1080p square Google User Content URL',
      () {
        const googleThumb =
            'https://yt3.googleusercontent.com/YpHZO1DBcGPbgywaeckHbkkiI-b4OetQDJnQtCM--usqBrKljB-9uXax23i3hHI-PiTlyyHLBdYScSeGRQ=w120-h120-l90-rj';
        final res = formatArtworkResolution(googleThumb, 1080);
        expect(res, contains('=w1080-h1080-l90-rj'));
        expect(res, startsWith('https://yt3.googleusercontent.com/'));
      },
    );

    test(
      'cleanArtworkUrl handles ggpht and googleusercontent appropriately',
      () {
        const googleThumb =
            'https://lh3.googleusercontent.com/abc=w544-h544-l90-rj';
        expect(cleanArtworkUrl(googleThumb), googleThumb);
      },
    );
  });
}
