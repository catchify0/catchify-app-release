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
import 'package:catchify/services/artist_service.dart';
import 'package:catchify/services/playlists_manager.dart';
import 'package:catchify/utilities/formatter.dart';

void main() {
  group('Artists Dynamic & Functional Tests', () {
    test('artistLanguageCodeToName maps names correctly', () {
      expect(artistLanguageCodeToName['ta'], 'Tamil');
      expect(artistLanguageCodeToName['hi'], 'Hindi');
      expect(artistLanguageCodeToName['te'], 'Telugu');
      expect(artistLanguageCodeToName['en'], 'English');
    });

    test('looksUnofficialArtistName identifies unofficial or parody channels', () {
      expect(looksUnofficialArtistName('A.R. Rahman'), isFalse);
      expect(looksUnofficialArtistName('Anirudh Ravichander'), isFalse);
      expect(looksUnofficialArtistName('Taylor Swift Cover Band'), isTrue);
      expect(looksUnofficialArtistName('Best Lyrics Channel'), isTrue);
      expect(looksUnofficialArtistName('Song Reaction Video'), isTrue);
      expect(looksUnofficialArtistName('Fan Made Tribute'), isTrue);
      expect(looksUnofficialArtistName('Karaoke Track Official'), isTrue);
      expect(looksUnofficialArtistName('Funny Parody Songs'), isTrue);
      expect(looksUnofficialArtistName('Nightcore Mixes'), isTrue);
      expect(looksUnofficialArtistName('Sped Up Version 2026'), isTrue);
      expect(looksUnofficialArtistName('Slowed and Reverb'), isTrue);
    });

    test('normalizeArtistDisplayTitle cleans suffixes and extra spaces', () {
      expect(
        normalizeArtistDisplayTitle('Anirudh Ravichander - Topic'),
        'Anirudh Ravichander',
      );
      expect(
        normalizeArtistDisplayTitle('A.R. Rahman Vevo'),
        'A.R. Rahman',
      );
      expect(
        normalizeArtistDisplayTitle('Sid   Sriram   Official Artist Channel'),
        'Sid Sriram',
      );
      expect(
        normalizeArtistDisplayTitle('Harris Jayaraj  Topic Channel'),
        'Harris Jayaraj',
      );
    });

    test('isSingleOrEpRelease properly identifies singles and EPs', () {
      expect(isSingleOrEpRelease({'releaseType': 'single'}), isTrue);
      expect(isSingleOrEpRelease({'releaseType': 'ep'}), isTrue);
      expect(isSingleOrEpRelease({'releaseType': 'album'}), isFalse);
      expect(isSingleOrEpRelease({'releaseType': null}), isFalse);
      expect(isSingleOrEpRelease({}), isFalse);
    });

    test('normalizeArtistThumbnailUrl cleans protocol and upgrades resolution', () {
      expect(
        normalizeArtistThumbnailUrl('//lh3.googleusercontent.com/photo=w120'),
        contains('https://lh3.googleusercontent.com'),
      );
      expect(
        normalizeArtistThumbnailUrl('http://lh3.googleusercontent.com/photo=w120'),
        contains('http://lh3.googleusercontent.com'),
      );
      expect(
        normalizeArtistThumbnailUrl('https://lh3.googleusercontent.com/photo=s120'),
        contains('1080'),
      );
      expect(normalizeArtistThumbnailUrl(null), isNull);
      expect(normalizeArtistThumbnailUrl('   '), isNull);
    });

    test('dedupeArtistCatalogSongs removes duplicates and assigns clean sequential indices', () {
      final inputSongs = [
        {'ytid': 'song_1', 'title': 'Arabic Kuthu', 'artist': 'Anirudh Ravichander'},
        {'ytid': 'song_2', 'title': 'Hukum', 'artist': 'Anirudh Ravichander'},
        // Duplicate ytid
        {'ytid': 'song_1', 'title': 'Arabic Kuthu', 'artist': 'Anirudh Ravichander'},
        // Duplicate canonical title under same artist
        {'ytid': 'song_3', 'title': 'Hukum (Official Audio)', 'artist': 'Anirudh Ravichander'},
        // Different song
        {'ytid': 'song_4', 'title': 'Badass', 'artist': 'Anirudh Ravichander'},
        // Empty title
        {'ytid': 'song_5', 'title': '', 'artist': 'Anirudh Ravichander'},
      ];

      final deduped = dedupeArtistCatalogSongs(inputSongs);
      expect(deduped.length, 3);
      expect(deduped[0]['ytid'], 'song_1');
      expect(deduped[0]['id'], 0);
      expect(deduped[1]['ytid'], 'song_2');
      expect(deduped[1]['id'], 1);
      expect(deduped[2]['ytid'], 'song_4');
      expect(deduped[2]['id'], 2);
    });

    test('artistPlaylistData preserves input metadata and marks isArtist true', () {
      final input = {
        'ytid': 'UC_artist_123',
        'title': 'Anirudh Ravichander',
        'image': 'https://lh3.googleusercontent.com/photo',
        'monthlyListeners': '15M',
        'description': 'Famous composer and singer',
      };
      final songs = [
        {'ytid': 's1', 'title': 'Song 1'},
      ];

      final result = artistPlaylistData(input, songs: songs);
      expect(result['ytid'], 'UC_artist_123');
      expect(result['title'], 'Anirudh Ravichander');
      expect(result['isArtist'], isTrue);
      expect(result['isVerifiedArtist'], isTrue);
      expect(result['source'], 'youtube-artist');
      expect(result['monthlyListeners'], '15M');
      expect(result['description'], 'Famous composer and singer');
      expect(result['list'], songs);
    });

    test('isOfficialSquareArtwork accepts Google/YouTube Music 1:1 artwork and blocks 16:9 thumbnails', () {
      // 1:1 official square album art
      expect(
        isOfficialSquareArtwork('https://lh3.googleusercontent.com/photo=w1080-h1080-l90-rj'),
        isTrue,
      );
      expect(
        isOfficialSquareArtwork('https://yt3.ggpht.com/avatar=s800-c-k-c0x00ffffff-no-rj'),
        isTrue,
      );

      // 16:9 YouTube video thumbnails (must be blocked)
      expect(
        isOfficialSquareArtwork('https://i.ytimg.com/vi/video123/maxresdefault.jpg'),
        isFalse,
      );
      expect(
        isOfficialSquareArtwork('https://i.ytimg.com/vi/video123/mqdefault.jpg'),
        isFalse,
      );
      expect(
        isOfficialSquareArtwork('https://i.ytimg.com/vi/video123/hqdefault.jpg'),
        isFalse,
      );
      expect(
        isOfficialSquareArtwork('https://img.youtube.com/vi/video123/0.jpg'),
        isFalse,
      );

      // Null or empty
      expect(isOfficialSquareArtwork(null), isFalse);
      expect(isOfficialSquareArtwork(''), isFalse);
      expect(isOfficialSquareArtwork('   '), isFalse);
    });

    test('isOfficialMusicSong identifies songs with official 1:1 artwork', () {
      final officialSong = {
        'ytid': 'song_1',
        'title': 'Hukum',
        'image': 'https://lh3.googleusercontent.com/song_art=w1080-h1080-l90-rj',
      };
      final videoUpload = {
        'ytid': 'song_2',
        'title': 'Hukum (Lyrics Video)',
        'image': 'https://i.ytimg.com/vi/song_2/maxresdefault.jpg',
      };

      expect(isOfficialMusicSong(officialSong), isTrue);
      expect(isOfficialMusicSong(videoUpload), isFalse);
    });
  });
}
