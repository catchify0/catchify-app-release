import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/services/playlist_sharing.dart';

void main() {
  test('rejects a non-map shared playlist payload', () async {
    final encoded = base64Url.encode(
      utf8.encode(jsonEncode(['not', 'a', 'map'])),
    );

    expect(
      await PlaylistSharingService.decodeAndExpandPlaylist(encoded),
      isNull,
    );
  });

  test('rejects a shared playlist with too many song ids', () async {
    final encoded = base64Url.encode(
      utf8.encode(
        jsonEncode({
          'title': 'Oversized',
          'list': List<String>.filled(501, 'validSongId'),
        }),
      ),
    );

    expect(
      await PlaylistSharingService.decodeAndExpandPlaylist(encoded),
      isNull,
    );
  });

  test('rejects a shared playlist without valid song ids', () async {
    final encoded = base64Url.encode(
      utf8.encode(
        jsonEncode({
          'title': 'Invalid',
          'list': [
            null,
            '',
            42,
            <String, String>{'id': 'wrong-field'},
          ],
        }),
      ),
    );

    expect(
      await PlaylistSharingService.decodeAndExpandPlaylist(encoded),
      isNull,
    );
  });
}
