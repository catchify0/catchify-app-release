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
import 'package:catchify/models/home_section.dart';
import 'package:catchify/services/home_feed_composer.dart';

void main() {
  group('HomeFeedComposer Tests', () {
    test(
      'Strictly preserves original remote shelf order 1:1 without semantic sorting',
      () {
        final inputShelves = [
          const HomeSection(
            title: 'Dancing on your own',
            subtitle: 'DANCE YOUR STRESS AWAY',
            type: HomeContentType.playlists,
            contents: [
              {'id': 'pl_1', 'title': 'Dance Playlist'},
            ],
          ),
          const HomeSection(
            title: 'Trending community playlists',
            subtitle: 'DISCOVERED PLAYLISTS',
            type: HomeContentType.playlists,
            contents: [
              {'id': 'pl_comm_1', 'title': 'Comm Playlist'},
            ],
          ),
          const HomeSection(
            title: 'Hindi Hits',
            subtitle: 'POPULAR HINDI',
            type: HomeContentType.playlists,
            contents: [
              {'id': 'pl_hindi', 'title': 'Hindi Playlist'},
            ],
          ),
          const HomeSection(
            title: 'New releases',
            subtitle: 'FRESH TRACKS',
            type: HomeContentType.albums,
            contents: [
              {'id': 'alb_1', 'title': 'New Album'},
            ],
          ),
          const HomeSection(
            title: 'Quick picks',
            subtitle: 'START RADIO FROM A SONG',
            type: HomeContentType.songs,
            contents: [
              {'id': 'song_1', 'title': 'Quick Song'},
            ],
            isChunkedSongs: true,
          ),
          const HomeSection(
            title: 'Trending songs for you',
            subtitle: 'POPULAR NOW',
            type: HomeContentType.songs,
            contents: [
              {'id': 'song_2', 'title': 'Trending Track'},
            ],
          ),
        ];

        final composed = HomeFeedComposer.compose(remoteSections: inputShelves);

        // The server produced order must be preserved in exact order:
        expect(composed.length, equals(6));
        expect(composed[0].title, equals('Dancing on your own'));
        expect(composed[1].title, equals('Trending community playlists'));
        expect(composed[2].title, equals('Hindi Hits'));
        expect(composed[3].title, equals('New releases'));
        expect(composed[4].title, equals('Quick picks'));
        expect(composed[5].title, equals('Trending songs for you'));
      },
    );

    test(
      'Injects local personalized sections cleanly without disturbing remote order',
      () {
        final inputShelves = [
          const HomeSection(
            title: 'Dancing on your own',
            type: HomeContentType.playlists,
            contents: [
              {'id': 'pl_1', 'title': 'Dance Playlist'},
            ],
          ),
          const HomeSection(
            title: 'Quick picks',
            type: HomeContentType.songs,
            contents: [
              {'id': 'song_1', 'title': 'Quick Song'},
            ],
          ),
          const HomeSection(
            title: 'Trending songs for you',
            type: HomeContentType.songs,
            contents: [
              {'id': 'song_2', 'title': 'Trending Track'},
            ],
          ),
        ];

        final personalizedShelves = [
          const HomeSection(
            title: 'Made for you',
            type: HomeContentType.songs,
            contents: [
              {'id': 'mfy_1', 'title': 'Personalized Song'},
            ],
          ),
        ];

        final composed = HomeFeedComposer.compose(
          remoteSections: inputShelves,
          personalizedSections: personalizedShelves,
        );

        expect(composed.length, equals(4));
        // First shelf: server hero shelf
        expect(composed[0].title, equals('Dancing on your own'));
        // Second shelf: local personalization inserted
        expect(composed[1].title, equals('Made for you'));
        // Remaining shelves: server order intact
        expect(composed[2].title, equals('Quick picks'));
        expect(composed[3].title, equals('Trending songs for you'));
      },
    );

    test('Deduplicates items within the same shelf by ytid/id', () {
      const shelfWithDuplicates = HomeSection(
        title: 'Quick picks',
        type: HomeContentType.songs,
        contents: [
          {'ytid': 'song_A', 'title': 'Song A'},
          {'ytid': 'song_B', 'title': 'Song B'},
          {'ytid': 'song_A', 'title': 'Song A Duplicate'},
          {'ytid': 'song_C', 'title': 'Song C'},
        ],
      );

      final composed = HomeFeedComposer.compose(
        remoteSections: [shelfWithDuplicates],
      );

      expect(composed.length, equals(1));
      expect(composed.first.contents.length, equals(3));
      expect(
        composed.first.contents.map((c) => c['ytid']).toList(),
        equals(['song_A', 'song_B', 'song_C']),
      );
    });

    test('Allows same item across different meaningful shelves', () {
      const shelf1 = HomeSection(
        title: 'Quick picks',
        type: HomeContentType.songs,
        contents: [
          {'ytid': 'song_shared', 'title': 'Shared Song'},
        ],
      );

      const shelf2 = HomeSection(
        title: 'Trending songs for you',
        type: HomeContentType.songs,
        contents: [
          {'ytid': 'song_shared', 'title': 'Shared Song'},
        ],
      );

      final composed = HomeFeedComposer.compose(
        remoteSections: [shelf1, shelf2],
      );

      expect(composed.length, equals(2));
      expect(composed[0].contents.first['ytid'], equals('song_shared'));
      expect(composed[1].contents.first['ytid'], equals('song_shared'));
    });

    test('Prunes empty sections', () {
      const emptyShelf = HomeSection(
        title: 'Empty Shelf',
        type: HomeContentType.songs,
        contents: [],
      );
      const validShelf = HomeSection(
        title: 'Quick picks',
        type: HomeContentType.songs,
        contents: [
          {'ytid': 'valid_1', 'title': 'Valid'},
        ],
      );

      final composed = HomeFeedComposer.compose(
        remoteSections: [emptyShelf, validShelf],
      );

      expect(composed.length, equals(1));
      expect(composed.first.title, equals('Quick picks'));
    });

    test('Places mood section at the top when provided', () {
      const moodSection = HomeSection(
        title: 'Party playlists',
        type: HomeContentType.playlists,
        contents: [
          {'id': 'pl_party', 'title': 'Party Hits'},
        ],
      );
      const remoteShelf = HomeSection(
        title: 'Quick picks',
        type: HomeContentType.songs,
        contents: [
          {'ytid': 's1', 'title': 'Song 1'},
        ],
      );

      final composed = HomeFeedComposer.compose(
        remoteSections: [remoteShelf],
        moodSection: moodSection,
      );

      expect(composed.length, equals(2));
      expect(composed[0].title, equals('Party playlists'));
      expect(composed[1].title, equals('Quick picks'));
    });

    test(
      'Injects language-curated sections into primary visible slots right after hero shelf',
      () {
        final inputShelves = [
          const HomeSection(
            title: 'Dancing on your own',
            type: HomeContentType.playlists,
            contents: [
              {'id': 'pl_hero', 'title': 'Hero Playlist'},
            ],
          ),
          const HomeSection(
            title: 'Remote Shelf 2',
            type: HomeContentType.songs,
            contents: [
              {'id': 'song_remote_2', 'title': 'Remote Song 2'},
            ],
          ),
        ];

        final languageShelves = [
          const HomeSection(
            title: 'Trending songs for you',
            type: HomeContentType.songs,
            contents: [
              {'id': 'song_ta_1', 'title': 'Tamil Trending'},
            ],
          ),
          const HomeSection(
            title: 'Featured playlists',
            type: HomeContentType.playlists,
            contents: [
              {'id': 'pl_ta_1', 'title': 'Kollywood Hitlist'},
            ],
          ),
          const HomeSection(
            title: 'New releases',
            type: HomeContentType.songs,
            contents: [
              {'id': 'song_ta_new', 'title': 'New Tamil Release'},
            ],
          ),
        ];

        final personalizedShelves = [
          const HomeSection(
            title: 'Made for you',
            type: HomeContentType.songs,
            contents: [
              {'id': 'song_mfy', 'title': 'Personalized'},
            ],
          ),
        ];

        final composed = HomeFeedComposer.compose(
          remoteSections: inputShelves,
          languageSections: languageShelves,
          personalizedSections: personalizedShelves,
        );

        // 1. Primary language discovery at slots 0 & 1
        expect(composed[0].title, equals('Trending songs for you'));
        expect(composed[1].title, equals('Featured playlists'));
        // 2. Local personalization at slot 2
        expect(composed[2].title, equals('Made for you'));
        // 3. First remote server shelf at slot 3
        expect(composed[3].title, equals('Dancing on your own'));
        // 4. Secondary language discovery at slot 4
        expect(composed[4].title, equals('New releases'));
        // 5. Remaining remote shelves at end
        expect(composed[5].title, equals('Remote Shelf 2'));
      },
    );

    test('Suppresses accidental duplicate shelf titles between language sections and remote shelves', () {
      final inputShelves = [
        const HomeSection(
          title: 'Trending songs for you',
          type: HomeContentType.songs,
          contents: [{'id': 'remote_trend_1', 'title': 'Remote Trending'}],
        ),
        const HomeSection(
          title: 'Dancing on your own',
          type: HomeContentType.playlists,
          contents: [{'id': 'pl_hero', 'title': 'Hero Playlist'}],
        ),
        const HomeSection(
          title: 'Featured playlists for you',
          type: HomeContentType.playlists,
          contents: [{'id': 'remote_feat_1', 'title': 'Remote Featured'}],
        ),
        const HomeSection(
          title: 'Remote Chill',
          type: HomeContentType.playlists,
          contents: [{'id': 'pl_chill', 'title': 'Chill'}],
        ),
      ];

      final languageShelves = [
        const HomeSection(
          title: 'Trending songs for you',
          type: HomeContentType.songs,
          contents: [{'id': 'ta_trend_1', 'title': 'Tamil Trending'}],
        ),
        const HomeSection(
          title: 'Featured playlists',
          type: HomeContentType.playlists,
          contents: [{'id': 'ta_feat_1', 'title': 'Kollywood Hitlist'}],
        ),
      ];

      final composed = HomeFeedComposer.compose(
        remoteSections: inputShelves,
        languageSections: languageShelves,
      );

      final titles = composed.map((s) => s.title).toList();
      // "Trending songs for you" appears once (from language)
      expect(titles.where((t) => t.toLowerCase().contains('trending songs')).length, equals(1));
      // "Featured playlists" appears once (from language)
      expect(titles.where((t) => t.toLowerCase().contains('featured playlists')).length, equals(1));
      // Remote's unique shelves are preserved
      expect(titles, contains('Dancing on your own'));
      expect(titles, contains('Remote Chill'));
    });

    test('Properly handles both Featured playlists and Trending community playlists simultaneously', () {
      final languageShelves = [
        const HomeSection(
          title: 'Quick picks',
          type: HomeContentType.songs,
          contents: [{'id': 'qp_1', 'title': 'Language Quick Pick'}],
        ),
        const HomeSection(
          title: 'Trending songs for you',
          type: HomeContentType.songs,
          contents: [{'id': 'ta_1', 'title': 'Tamil Song'}],
        ),
        const HomeSection(
          title: 'Featured playlists',
          subtitle: 'CURATED FOR YOU',
          type: HomeContentType.playlists,
          contents: [{'id': 'pl_feat_1', 'title': 'Kollywood Hitlist'}],
        ),
        const HomeSection(
          title: 'Trending community playlists',
          subtitle: 'COMMUNITY PLAYLISTS',
          type: HomeContentType.playlists,
          contents: [{'id': 'pl_comm_1', 'title': 'Tamil Workout Vibes'}],
        ),
      ];

      final remoteShelves = [
        const HomeSection(
          title: 'Quick picks',
          type: HomeContentType.songs,
          contents: [{'id': 'rem_qp_1', 'title': 'English Song'}],
        ),
        const HomeSection(
          title: 'Community playlists',
          type: HomeContentType.playlists,
          contents: [{'id': 'rem_comm_1', 'title': 'Global Comm'}],
        ),
        const HomeSection(
          title: 'Indie Discoveries',
          type: HomeContentType.playlists,
          contents: [{'id': 'pl_indie', 'title': 'Indie Playlist'}],
        ),
      ];

      final composed = HomeFeedComposer.compose(
        remoteSections: remoteShelves,
        languageSections: languageShelves,
      );

      final titles = composed.map((s) => s.title).toList();
      // Language Quick picks is present, remote English Quick picks is suppressed
      expect(titles.where((t) => t.toLowerCase().contains('quick picks')).length, equals(1));
      expect(composed.first.contents.first['id'], equals('qp_1'));

      // Both Featured playlists and Trending community playlists are present
      expect(titles, contains('Featured playlists'));
      expect(titles, contains('Trending community playlists'));

      // Remote duplicate 'Community playlists' is suppressed because Trending community playlists is present
      expect(titles.where((t) => t.toLowerCase().contains('community playlists')).length, equals(1));

      // Unique remote shelf 'Indie Discoveries' is kept
      expect(titles, contains('Indie Discoveries'));
    });

    test('Places "Continue listening" (Recently played) at slot 0 as the top section', () {
      final remoteShelves = [
        const HomeSection(
          title: 'Dancing on your own',
          type: HomeContentType.playlists,
          contents: [{'id': 'pl_hero'}],
        ),
      ];

      final languageShelves = [
        const HomeSection(
          title: 'Quick picks',
          type: HomeContentType.songs,
          contents: [{'id': 'qp_1'}],
        ),
        const HomeSection(
          title: 'Trending songs for you',
          type: HomeContentType.songs,
          contents: [{'id': 'ta_1'}],
        ),
      ];

      final personalizedShelves = [
        const HomeSection(
          title: 'Continue listening',
          subtitle: 'RECENTLY PLAYED',
          type: HomeContentType.songs,
          contents: [{'id': 'recent_1'}],
        ),
        const HomeSection(
          title: 'Made for you',
          type: HomeContentType.songs,
          contents: [{'id': 'mfy_1'}],
        ),
      ];

      final composed = HomeFeedComposer.compose(
        remoteSections: remoteShelves,
        languageSections: languageShelves,
        personalizedSections: personalizedShelves,
      );

      // Continue listening is placed at slot 0
      expect(composed[0].title, equals('Continue listening'));
      expect(composed[0].subtitle, equals('RECENTLY PLAYED'));
      expect(composed[1].title, equals('Quick picks'));
      expect(composed[2].title, equals('Trending songs for you'));
      expect(composed[3].title, equals('Made for you'));
    });

    test('Formats diagnostic home order string correctly', () {
      final sections = [
        const HomeSection(
          title: 'Quick picks',
          type: HomeContentType.songs,
          contents: [
            {'id': '1'},
          ],
        ),
        const HomeSection(
          title: 'Trending',
          type: HomeContentType.songs,
          contents: [
            {'id': '2'},
            {'id': '3'},
          ],
        ),
      ];

      final log = HomeFeedComposer.formatHomeOrder(sections);
      expect(log, contains('[HOME_ORDER]'));
      expect(log, contains('01. title="Quick picks"'));
      expect(log, contains('type=songs'));
      expect(log, contains('items=1'));
      expect(log, contains('02. title="Trending"'));
      expect(log, contains('items=2'));
    });
  });
}
