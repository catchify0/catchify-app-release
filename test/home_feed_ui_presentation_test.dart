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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:catchify/localization/app_localizations.dart';
import 'package:catchify/models/home_section.dart';
import 'package:catchify/widgets/album_card.dart';
import 'package:catchify/widgets/empty_state.dart';
import 'package:catchify/widgets/error_state.dart';
import 'package:catchify/widgets/home_section_renderer.dart';
import 'package:catchify/widgets/loading_skeleton.dart';
import 'package:catchify/widgets/mini_player_bottom_space.dart';
import 'package:catchify/widgets/playlist_card.dart';
import 'package:catchify/widgets/section_header.dart';
import 'package:catchify/widgets/song_card.dart';

void main() {
  Widget createTestApp(
    Widget child, {
    Size surfaceSize = const Size(390, 844),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: surfaceSize,
          padding: const EdgeInsets.only(top: 47, bottom: 34),
        ),
        child: Scaffold(body: child),
      ),
    );
  }

  group('Home Feed UI Presentation & Widget Tests', () {
    testWidgets(
      '1. Home loading skeleton renders without error or layout jump',
      (tester) async {
        await tester.pumpWidget(
          createTestApp(
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  ShelfSkeleton(cardCount: 3),
                  SizedBox(height: 28),
                  ShelfSkeleton(),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(ShelfSkeleton), findsNWidgets(2));
        expect(find.byType(SongCardSkeleton), findsNWidgets(7));
      },
    );

    testWidgets(
      '2. Home empty state renders with clean typography and refresh action',
      (tester) async {
        var refreshed = false;
        await tester.pumpWidget(
          createTestApp(
            EmptyState(
              title: 'No music found',
              description: 'Explore or try selecting a different mood.',
              actionLabel: 'Refresh',
              onAction: () => refreshed = true,
            ),
          ),
        );

        expect(find.text('No music found'), findsOneWidget);
        expect(
          find.text('Explore or try selecting a different mood.'),
          findsOneWidget,
        );
        expect(find.text('Refresh'), findsOneWidget);

        await tester.tap(find.text('Refresh'));
        expect(refreshed, isTrue);
      },
    );

    testWidgets(
      '3. Home error state displays "Something went wrong" with "Try again" retry button',
      (tester) async {
        var retried = false;
        await tester.pumpWidget(
          createTestApp(
            ErrorState(
              title: 'Something went wrong',
              onRetry: () => retried = true,
            ),
          ),
        );

        expect(find.text('Something went wrong'), findsOneWidget);
        expect(
          find.text('Check your connection and try again.'),
          findsOneWidget,
        );
        expect(find.text('Try again'), findsOneWidget);

        await tester.tap(find.text('Try again'));
        expect(retried, isTrue);
      },
    );

    testWidgets(
      '4. SectionHeader renders title, optional subtitle, and action button',
      (tester) async {
        var actionTapped = false;
        await tester.pumpWidget(
          createTestApp(
            SectionHeader(
              title: 'Trending songs for you',
              subtitle: 'POPULAR NOW',
              actionButton: IconButton(
                icon: const Icon(FluentIcons.play_circle_24_filled),
                onPressed: () => actionTapped = true,
              ),
            ),
          ),
        );

        expect(find.text('Trending songs for you'), findsOneWidget);
        expect(find.text('POPULAR NOW'), findsOneWidget);
        expect(find.byIcon(FluentIcons.play_circle_24_filled), findsOneWidget);

        await tester.tap(find.byIcon(FluentIcons.play_circle_24_filled));
        expect(actionTapped, isTrue);
      },
    );

    testWidgets(
      '5. SongCard exposes semantic accessibility labels and handles taps',
      (tester) async {
        var tapped = false;
        final testSong = {
          'id': 's1',
          'title': 'Pavazha Malli',
          'artist': 'Anirudh Ravichander',
        };

        await tester.pumpWidget(
          createTestApp(SongCard(song: testSong, onTap: () => tapped = true)),
        );

        expect(find.byType(SongCard), findsOneWidget);
        expect(find.text('Pavazha Malli'), findsAtLeastNWidgets(1));
        expect(find.text('Anirudh Ravichander'), findsOneWidget);

        // Verify Semantics label
        final semanticsFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  'Pavazha Malli, by Anirudh Ravichander',
        );
        expect(semanticsFinder, findsOneWidget);

        await tester.tap(find.byType(SongCard));
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      '6. AlbumCard and PlaylistCard expose semantic accessibility labels',
      (tester) async {
        final testAlbum = {'id': 'a1', 'title': 'Leo', 'artist': 'Anirudh'};
        final testPlaylist = {
          'id': 'p1',
          'title': 'Kollywood Hitlist',
          'artist': 'Spotify',
        };

        await tester.pumpWidget(
          createTestApp(
            Column(
              children: [
                AlbumCard(album: testAlbum, onTap: () {}),
                PlaylistCard(playlist: testPlaylist, onTap: () {}),
              ],
            ),
          ),
        );

        expect(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == 'Leo, by Anirudh',
          ),
          findsOneWidget,
        );

        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                w.properties.label == 'Kollywood Hitlist, playlist by Spotify',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '7. HomeSectionRenderer renders shelf and adapts height dynamically without overflow',
      (tester) async {
        const section = HomeSection(
          title: 'Trending songs for you',
          type: HomeContentType.songs,
          contents: [
            {'id': '1', 'title': 'Song 1', 'artist': 'Artist 1'},
            {'id': '2', 'title': 'Song 2', 'artist': 'Artist 2'},
          ],
        );

        await tester.pumpWidget(
          createTestApp(
            const HomeSectionRenderer(section: section),
            // Test on small screen width (e.g. iPhone SE: 375x667)
            surfaceSize: const Size(375, 667),
          ),
        );

        expect(find.text('Trending songs for you'), findsOneWidget);
        expect(find.byType(SongCard), findsNWidgets(2));
        expect(find.text('Song 1'), findsAtLeastNWidgets(1));
        expect(find.text('Song 2'), findsAtLeastNWidgets(1));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('8. HomeSectionRenderer localizes canonical shelf titles', (
      tester,
    ) async {
      const section = HomeSection(
        title: 'Quick picks',
        type: HomeContentType.songs,
        contents: [
          {'id': '1', 'title': 'Song 1', 'artist': 'Artist 1'},
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ta'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: const HomeSectionRenderer(section: section)),
        ),
      );

      expect(find.text('விரைவுத் தேர்வுகள்'), findsOneWidget);
      expect(find.text('Quick picks'), findsNothing);
    });

    testWidgets('9. MiniPlayerBottomSpace provides safe scrollable space', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          const Column(
            children: [Text('End of Feed'), MiniPlayerBottomSpace()],
          ),
        ),
      );

      expect(find.text('End of Feed'), findsOneWidget);
      expect(find.byType(MiniPlayerBottomSpace), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
