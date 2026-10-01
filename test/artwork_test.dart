import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/services/artwork_service.dart';
import 'package:catchify/utilities/formatter.dart';
import 'package:catchify/utilities/mediaitem.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('formatArtworkResolution tests', () {
    test('upgrades googleusercontent.com width and height to target size', () {
      const url =
          'https://yt3.googleusercontent.com/uAJmhJjnQ_Fw=w120-h120-l90-rj';
      expect(
        formatArtworkResolution(url, 1080),
        'https://yt3.googleusercontent.com/uAJmhJjnQ_Fw=w1080-h1080-l90-rj',
      );
      expect(
        formatArtworkResolution(url, 544),
        'https://yt3.googleusercontent.com/uAJmhJjnQ_Fw=w544-h544-l90-rj',
      );
    });

    test('upgrades ggpht.com s parameters', () {
      const url = 'https://lh3.ggpht.com/abc=s120';
      expect(
        formatArtworkResolution(url, 544),
        'https://lh3.ggpht.com/abc=w544-h544-l90-rj',
      );
    });

    test('leaves non-google URLs untouched', () {
      const ytUrl = 'https://i.ytimg.com/vi/12345/maxresdefault.jpg';
      expect(formatArtworkResolution(ytUrl, 1080), ytUrl);
    });

    test('upgrades YouTube thumbnails to maxresdefault.jpg for 1080p', () {
      const hq = 'https://i.ytimg.com/vi/12345/hqdefault.jpg';
      expect(
        formatArtworkResolution(hq, 1080),
        'https://i.ytimg.com/vi/12345/maxresdefault.jpg',
      );

      const sd = 'https://i.ytimg.com/vi/12345/sddefault.jpg';
      expect(
        formatArtworkResolution(sd, 1080),
        'https://i.ytimg.com/vi/12345/maxresdefault.jpg',
      );

      const def = 'https://i.ytimg.com/vi/12345/default.jpg?sqp=xxx';
      expect(
        formatArtworkResolution(def, 1080),
        'https://i.ytimg.com/vi/12345/maxresdefault.jpg',
      );
    });

    test('appends 1080p parameters to unsized googleusercontent URLs', () {
      const url = 'https://lh3.googleusercontent.com/sample';
      expect(
        formatArtworkResolution(url, 1080),
        'https://lh3.googleusercontent.com/sample=w1080-h1080-l90-rj',
      );
    });
  });

  group('ArtworkService URL classification tests', () {
    test('identifies Google artwork URLs', () {
      expect(
        ArtworkService.isGoogleArtworkUrl(
          'https://yt3.googleusercontent.com/sample',
        ),
        isTrue,
      );
      expect(
        ArtworkService.isGoogleArtworkUrl('https://lh3.ggpht.com/sample'),
        isTrue,
      );
      expect(
        ArtworkService.isGoogleArtworkUrl(
          'https://i.ytimg.com/vi/123/maxresdefault.jpg',
        ),
        isFalse,
      );
    });

    test('identifies YouTube thumbnail URLs', () {
      expect(
        ArtworkService.isYouTubeThumbnailUrl(
          'https://i.ytimg.com/vi/123/maxresdefault.jpg',
        ),
        isTrue,
      );
      expect(
        ArtworkService.isYouTubeThumbnailUrl(
          'https://img.youtube.com/vi/123/default.jpg',
        ),
        isTrue,
      );
      expect(
        ArtworkService.isYouTubeThumbnailUrl(
          'https://yt3.googleusercontent.com/sample',
        ),
        isFalse,
      );
    });
  });

  group('ArtworkService center crop tests', () {
    Future<Uint8List> createTestPng(int width, int height) async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()..color = const ui.Color(0xFFFF0000);
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        paint,
      );
      final picture = recorder.endRecording();
      final img = await picture.toImage(width, height);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      return bytes!.buffer.asUint8List();
    }

    test('cropCenterSquare converts 16:9 image to 1:1 square', () async {
      final widescreenBytes = await createTestPng(160, 90);
      final squareBytes = await ArtworkService.cropCenterSquare(
        widescreenBytes,
      );

      final codec = await ui.instantiateImageCodec(squareBytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 90);
      expect(frame.image.height, 90);
      expect(frame.image.width, frame.image.height);
    });

    test('cropCenterSquare preserves already-square image', () async {
      final squareSourceBytes = await createTestPng(100, 100);
      final result = await ArtworkService.cropCenterSquare(squareSourceBytes);
      expect(result, squareSourceBytes);
    });

    test(
      'cropCenterSquare crops out black bars from 4:3 YouTube thumbnails',
      () async {
        final letterboxedBytes = await createTestPng(480, 360);
        final squareBytes = await ArtworkService.cropCenterSquare(
          letterboxedBytes,
        );

        final codec = await ui.instantiateImageCodec(squareBytes);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 270);
        expect(frame.image.height, 270);
      },
    );
  });

  group('ArtworkService resolveArtUri & mapToMediaItem integration', () {
    test('Google artwork URL resolves directly to high-res square URL', () {
      final song = {
        'id': 'test1',
        'ytid': 'test1',
        'title': 'Test Song',
        'artist': 'Test Artist',
        'highResImage':
            'https://yt3.googleusercontent.com/sample=w120-h120-l90-rj',
      };

      final mediaItem = mapToMediaItem(song);
      expect(
        mediaItem.artUri.toString(),
        'https://yt3.googleusercontent.com/sample=w1080-h1080-l90-rj',
      );
    });

    test('YouTube thumbnail triggers non-blocking URI and passes callback', () {
      final song = {
        'id': 'test2',
        'ytid': 'test2',
        'title': 'Test Song 2',
        'artist': 'Test Artist 2',
        'highResImage': 'https://i.ytimg.com/vi/test2/maxresdefault.jpg',
      };

      var callbackInvoked = false;
      final mediaItem = mapToMediaItem(
        song,
        onSquareArtworkReady: (uri) {
          callbackInvoked = true;
        },
      );

      // Initially provides remote URL unblocked
      expect(
        mediaItem.artUri.toString(),
        'https://i.ytimg.com/vi/test2/maxresdefault.jpg',
      );
      expect(callbackInvoked, isFalse);
    });
  });
}
