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

import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/models/home_section.dart';
import 'package:catchify/services/home_feed_composer.dart';
import 'package:catchify/services/personalization_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PersonalizationWeights and Time Decay Tests', () {
    test('calculateTimeDecay decreases monotonically with recents index', () {
      expect(PersonalizationWeights.calculateTimeDecay(0), 1.0);
      expect(PersonalizationWeights.calculateTimeDecay(2), 0.85);
      expect(PersonalizationWeights.calculateTimeDecay(8), 0.65);
      expect(PersonalizationWeights.calculateTimeDecay(20), 0.45);
      expect(PersonalizationWeights.calculateTimeDecay(40), 0.25);

      // Verify strict downward decay
      expect(
        PersonalizationWeights.calculateTimeDecay(0) >
            PersonalizationWeights.calculateTimeDecay(3),
        true,
      );
      expect(
        PersonalizationWeights.calculateTimeDecay(3) >
            PersonalizationWeights.calculateTimeDecay(10),
        true,
      );
      expect(
        PersonalizationWeights.calculateTimeDecay(10) >
            PersonalizationWeights.calculateTimeDecay(25),
        true,
      );
    });
  });

  group('PersonalizationService Core Ranking Tests', () {
    test(
      'rankSongs places liked and frequently played tracks above ordinary tracks',
      () {
        final signals = UserSignals(
          likedSongs: [
            {'ytid': 'liked_1', 'title': 'Hukum', 'artist': 'Anirudh'},
          ],
          recentSongs: [
            {'ytid': 'recent_1', 'title': 'Recent Hit', 'artist': 'Sid Sriram'},
            {'ytid': 'recent_old', 'title': 'Old Track', 'artist': 'Artist'},
          ],
          likedPlaylists: const [],
          customPlaylists: const [],
          searchQueries: const ['Hukum'],
          playCounts: {'liked_1': 10},
        );

        final ranked = PersonalizationService.instance.rankSongs(signals);
        expect(ranked.isNotEmpty, true);
        // 'liked_1' gets likedSongWeight (100) + playCount (100) + searchBonus (20) = 220
        expect(ranked.first['ytid'], 'liked_1');
      },
    );

    test('rankSongs deduplicates candidates by canonical ytid', () {
      final signals = UserSignals(
        likedSongs: [
          {'ytid': 'dup_1', 'title': 'Song One', 'artist': 'Artist A'},
        ],
        recentSongs: [
          {
            'ytid': 'dup_1',
            'title': 'Song One (Duplicate)',
            'artist': 'Artist A',
          },
          {'ytid': 'unique_2', 'title': 'Song Two', 'artist': 'Artist B'},
        ],
        likedPlaylists: const [],
        customPlaylists: const [],
        searchQueries: const [],
        playCounts: const {},
      );

      final ranked = PersonalizationService.instance.rankSongs(signals);
      expect(ranked.length, 2);
      expect(ranked.where((s) => s['ytid'] == 'dup_1').length, 1);
      expect(ranked.where((s) => s['ytid'] == 'unique_2').length, 1);
    });

    test(
      'rankArtists ranks top artists based on likes, recents, and searches',
      () {
        final signals = UserSignals(
          likedSongs: [
            {'ytid': 's1', 'title': 'Track 1', 'artist': 'Anirudh Ravichander'},
            {'ytid': 's2', 'title': 'Track 2', 'artist': 'Anirudh Ravichander'},
            {'ytid': 's3', 'title': 'Track 3', 'artist': 'AR Rahman'},
          ],
          recentSongs: [
            {'ytid': 's4', 'title': 'Track 4', 'artist': 'Anirudh Ravichander'},
          ],
          likedPlaylists: [
            {
              'ytid': 'art_anirudh',
              'title': 'Anirudh Ravichander',
              'source': 'youtube-artist',
            },
          ],
          customPlaylists: const [],
          searchQueries: const ['Anirudh'],
          playCounts: const {},
        );

        final artists = PersonalizationService.instance.rankArtists(signals);
        expect(artists.isNotEmpty, true);
        expect(artists.first['title'], 'Anirudh Ravichander');
      },
    );

    test('rankPlaylists ranks user custom playlists and liked playlists', () {
      final signals = UserSignals(
        likedSongs: const [],
        recentSongs: const [],
        likedPlaylists: [
          {'ytid': 'pl_liked', 'title': 'Tamil Hits', 'isAlbum': false},
        ],
        customPlaylists: [
          {'ytid': 'pl_custom', 'title': 'My Favorites'},
        ],
        searchQueries: const [],
        playCounts: const {},
      );

      final playlists = PersonalizationService.instance.rankPlaylists(signals);
      expect(playlists.length, 2);
      // Custom playlist gets base 90.0, liked gets 80.0
      expect(playlists[0]['ytid'], 'pl_custom');
      expect(playlists[1]['ytid'], 'pl_liked');
    });
  });

  group('Cold Start and Section Generation Tests', () {
    test(
      'buildPersonalizedSections returns empty list on cold start (no data)',
      () {
        const emptySignals = UserSignals(
          likedSongs: [],
          recentSongs: [],
          likedPlaylists: [],
          customPlaylists: [],
          searchQueries: [],
          playCounts: {},
        );

        final sections = PersonalizationService.instance
            .buildPersonalizedSections(signalsOverride: emptySignals);

        expect(sections.isEmpty, true);
      },
    );

    test(
      'buildPersonalizedSections generates "Because you listened" and "Continue listening" for active listener',
      () {
        final signals = UserSignals(
          likedSongs: [
            {'ytid': 's1', 'title': 'Badass', 'artist': 'Anirudh Ravichander'},
            {
              'ytid': 's2',
              'title': 'Naa Ready',
              'artist': 'Anirudh Ravichander',
            },
            {'ytid': 's3', 'title': 'Hukum', 'artist': 'Anirudh Ravichander'},
            {
              'ytid': 's4',
              'title': 'Ordinary Person',
              'artist': 'Anirudh Ravichander',
            },
          ],
          recentSongs: [
            {'ytid': 's1', 'title': 'Badass', 'artist': 'Anirudh Ravichander'},
            {
              'ytid': 's5',
              'title': 'Arabic Kuthu',
              'artist': 'Anirudh Ravichander',
            },
          ],
          likedPlaylists: const [],
          customPlaylists: const [],
          searchQueries: const ['Anirudh'],
          playCounts: {'s1': 15, 's2': 8},
        );

        final sections = PersonalizationService.instance
            .buildPersonalizedSections(signalsOverride: signals);

        expect(sections.isNotEmpty, true);

        final hasMadeForYou = sections.any((s) => s.title == 'Made for you');
        expect(hasMadeForYou, false);

        final hasBecauseYouListened = sections.any(
          (s) => s.title.startsWith('Because you listened to'),
        );
        expect(hasBecauseYouListened, true);

        final hasContinueListening = sections.any(
          (s) => s.title == 'Continue listening',
        );
        expect(hasContinueListening, true);

        final hasYourTopArtists = sections.any(
          (s) => s.title == 'Your top artists',
        );
        expect(hasYourTopArtists, false);
      },
    );

    test(
      'buildPersonalizedSections prioritizes fresh relevant candidates for "Made for you" and excludes played history',
      () {
        final signals = UserSignals(
          likedSongs: [
            {'ytid': 's1', 'title': 'Badass', 'artist': 'Anirudh Ravichander'},
          ],
          recentSongs: [
            {'ytid': 's1', 'title': 'Badass', 'artist': 'Anirudh Ravichander'},
            {'ytid': 's2', 'title': 'Hukum', 'artist': 'Anirudh Ravichander'},
          ],
          likedPlaylists: const [],
          customPlaylists: const [],
          searchQueries: const [],
          playCounts: const {},
        );

        final freshCandidates = [
          {'ytid': 's1', 'title': 'Badass (Played)', 'artist': 'Anirudh'},
          {'ytid': 'cand_1', 'title': 'Leo Das Entry', 'artist': 'Anirudh'},
          {'ytid': 'cand_2', 'title': 'Jailer Theme', 'artist': 'Anirudh'},
          {
            'ytid': 'cand_3',
            'title': 'Vikram Title Track',
            'artist': 'Anirudh',
          },
        ];

        final sections = PersonalizationService.instance
            .buildPersonalizedSections(
              signalsOverride: signals,
              relevantCandidates: freshCandidates,
            );

        final madeForYou = sections.firstWhere(
          (s) => s.title == 'Made for you',
        );
        expect(madeForYou.subtitle, 'RECOMMENDED FOR YOU');
        // 's1' is in recentSongs, so it must be filtered out of fresh recommendations
        expect(
          madeForYou.contents.any((track) => track['ytid'] == 's1'),
          false,
        );
        // 'cand_1', 'cand_2', 'cand_3' should be present
        expect(
          madeForYou.contents.any((track) => track['ytid'] == 'cand_1'),
          true,
        );
      },
    );

    test(
      'Because you listened adds fresh artist recommendations before favorites',
      () {
        const signals = UserSignals(
          likedSongs: [
            {'ytid': 'liked_1', 'title': 'Liked One', 'artist': 'Artist'},
            {'ytid': 'liked_2', 'title': 'Liked Two', 'artist': 'Artist'},
          ],
          recentSongs: [
            {'ytid': 'recent_1', 'title': 'Recent One', 'artist': 'Artist'},
          ],
          likedPlaylists: [],
          customPlaylists: [],
          searchQueries: [],
          playCounts: {},
        );

        final sections = PersonalizationService.instance
            .buildPersonalizedSections(
              signalsOverride: signals,
              relevantCandidates: const [
                {'ytid': 'fresh_1', 'title': 'Fresh One', 'artist': 'Artist'},
                {'ytid': 'fresh_2', 'title': 'Fresh Two', 'artist': 'Artist'},
                {'ytid': 'other_1', 'title': 'Other Artist', 'artist': 'Other'},
              ],
            );

        final because = sections.firstWhere(
          (section) => section.title == 'Because you listened to Artist',
        );
        expect(because.subtitle, 'MORE FROM THIS ARTIST');
        expect(because.contents.take(2).map((song) => song['ytid']), [
          'fresh_1',
          'fresh_2',
        ]);
        expect(because.contents.any((song) => song['ytid'] == 'liked_1'), true);
      },
    );

    test(
      'buildPersonalizedSections omits Made for you when only played candidates remain',
      () {
        const signals = UserSignals(
          likedSongs: [
            {'ytid': 'recent_1', 'title': 'Played Song', 'artist': 'Artist'},
          ],
          recentSongs: [
            {'ytid': 'recent_1', 'title': 'Played Song', 'artist': 'Artist'},
            {'ytid': 'recent_2', 'title': 'Another Song', 'artist': 'Artist'},
          ],
          likedPlaylists: [],
          customPlaylists: [],
          searchQueries: [],
          playCounts: {},
        );

        final sections = PersonalizationService.instance
            .buildPersonalizedSections(
              signalsOverride: signals,
              relevantCandidates: const [
                {
                  'ytid': 'recent_1',
                  'title': 'Played Song',
                  'artist': 'Artist',
                },
                {
                  'ytid': 'recent_2',
                  'title': 'Another Song',
                  'artist': 'Artist',
                },
              ],
            );

        expect(sections.any((s) => s.title == 'Made for you'), false);
        final continueListening = sections.firstWhere(
          (s) => s.title == 'Continue listening',
        );
        expect(
          continueListening.contents.map((song) => song['ytid']),
          containsAll(['recent_1', 'recent_2']),
        );
      },
    );

    test(
      'getCandidateArtists extracts artists from various metadata formats and splits credits',
      () {
        const signals = UserSignals(
          likedSongs: [
            {
              'ytid': 'l1',
              'title': 'Track 1',
              'artists': [
                {'name': 'Sid Sriram'},
              ],
            },
          ],
          recentSongs: [
            {
              'ytid': 'r1',
              'title': 'Track 2',
              'artist': 'Anirudh Ravichander, Jonita Gandhi',
            },
            {
              'ytid': 'r2',
              'title': 'Track 3',
              'author': 'Various Artists', // Generic: should be ignored
            },
          ],
          likedPlaylists: [],
          customPlaylists: [],
          searchQueries: [],
          playCounts: {},
        );

        final candidates = PersonalizationService.instance.getCandidateArtists(
          signals,
        );
        expect(candidates.contains('Anirudh Ravichander'), true);
        expect(candidates.contains('Jonita Gandhi'), true);
        expect(candidates.contains('Sid Sriram'), true);
        expect(
          candidates.any((c) => c.toLowerCase().contains('various artists')),
          false,
        );
      },
    );

    test(
      'Because you listened creates section with 1 played song if fresh recommendations exist',
      () {
        const signals = UserSignals(
          likedSongs: [],
          recentSongs: [
            {'ytid': 'single_play', 'title': 'Fear Song', 'artist': 'Anirudh'},
          ],
          likedPlaylists: [],
          customPlaylists: [],
          searchQueries: [],
          playCounts: {},
        );

        final sections = PersonalizationService.instance
            .buildPersonalizedSections(
              signalsOverride: signals,
              relevantCandidates: const [
                {
                  'ytid': 'rec_1',
                  'title': 'Badass',
                  'artist': 'Anirudh Ravichander',
                },
                {'ytid': 'rec_2', 'title': 'Hukum', 'artist': 'Anirudh'},
              ],
            );

        final because = sections.firstWhere(
          (s) => s.title.startsWith('Because you listened to'),
        );
        expect(because.subtitle, 'MORE FROM THIS ARTIST');
        expect(because.contents.any((song) => song['ytid'] == 'rec_1'), true);
        expect(
          because.contents.any((song) => song['ytid'] == 'single_play'),
          true,
        );
      },
    );
  });

  group('HomeFeedComposer Integration Tests', () {
    test(
      'HomeFeedComposer blends remote and personalized sections in correct semantic order',
      () {
        final remoteSections = [
          HomeSection(
            title: 'Trending songs for you',
            subtitle: 'TOP CHARTS',
            type: HomeContentType.songs,
            contents: [
              {'ytid': 'rem_1', 'title': 'Remote Hit 1'},
            ],
          ),
          HomeSection(
            title: 'India’s biggest hits',
            subtitle: 'PLAYLISTS',
            type: HomeContentType.playlists,
            contents: [
              {'ytid': 'rem_pl_1', 'title': 'Remote Playlist 1'},
            ],
          ),
        ];

        final personalizedSections = [
          HomeSection(
            title: 'Made for you',
            subtitle: 'RECOMMENDED',
            type: HomeContentType.songs,
            contents: [
              {'ytid': 'pers_1', 'title': 'Personalized 1'},
            ],
          ),
          HomeSection(
            title: 'Continue listening',
            subtitle: 'RECENTLY PLAYED',
            type: HomeContentType.songs,
            contents: [
              {'ytid': 'pers_2', 'title': 'Personalized 2'},
            ],
          ),
        ];

        final composed = HomeFeedComposer.compose(
          remoteSections: remoteSections,
          personalizedSections: personalizedSections,
        );

        expect(composed.length, 4);

        expect(composed[0].title, 'Continue listening');
        expect(composed[1].title, 'Trending songs for you');
        expect(composed[2].title, 'Made for you');
        expect(composed[3].title, 'India’s biggest hits');
      },
    );
  });
}
