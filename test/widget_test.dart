import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/widgets/section_header.dart';
import 'package:catchify/widgets/no_artwork_cube.dart';
import 'package:catchify/widgets/custom_search_bar.dart';
import 'package:catchify/widgets/empty_state.dart';
import 'package:catchify/widgets/loading_skeleton.dart';
import 'package:catchify/widgets/marquee.dart';
import 'package:catchify/widgets/catchify_brand_icon.dart';

void main() {
  testWidgets('SectionHeader renders title correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SectionHeader(title: 'Recommended For You')),
      ),
    );

    expect(find.text('Recommended For You'), findsOneWidget);
  });

  testWidgets('SectionHeader keeps long titles and actions visible', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.8)),
        child: MaterialApp(
          home: Scaffold(
            body: SectionHeader(
              title: 'Recommended music for your evening listening session',
              subtitle: 'PERSONALISED PICKS',
              actionButton: IconButton(
                onPressed: null,
                tooltip: 'Play all',
                icon: Icon(Icons.play_arrow),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find.text('Recommended music for your evening listening session'),
      findsOneWidget,
    );
    expect(find.byTooltip('Play all'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SectionHeader preserves an icon with long localized title', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
        child: MaterialApp(
          home: Scaffold(
            body: SectionHeader(
              icon: Icons.library_music,
              title: 'பரிந்துரைக்கப்பட்ட இசை மற்றும் புதிய வெளியீடுகள்',
              subtitle: 'உங்கள் தனிப்பட்ட தேர்வுகள்',
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.library_music), findsOneWidget);
    expect(find.text('பரிந்துரைக்கப்பட்ட இசை மற்றும் புதிய வெளியீடுகள்'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('NullArtworkWidget renders placeholder title', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: NullArtworkWidget(title: 'My Playlist')),
      ),
    );

    expect(find.text('My Playlist'), findsOneWidget);
  });

  testWidgets('CatchifyBrandIcon renders note fill over the original outline', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CatchifyBrandIcon(size: 64)),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(CatchifyBrandIcon), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'CustomSearchBar renders and dismiss button clears input without duplicate spinner',
    (WidgetTester tester) async {
      final controller = TextEditingController(text: 'Anirudh');
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomSearchBar(
              controller: controller,
              focusNode: focusNode,
              labelText: 'Search...',
              onSubmitted: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Anirudh'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Tap dismiss button
      final clearButton = find.byType(IconButton);
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pump();

      expect(controller.text, isEmpty);
    },
  );

  testWidgets('EmptyState remains readable at enlarged text scale', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: Scaffold(
            body: EmptyState(
              title: 'Your library is waiting',
              description:
                  'Add music to build a personal collection and listen offline.',
              actionLabel: 'Browse music',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Your library is waiting'), findsOneWidget);
    expect(
      find.text('Add music to build a personal collection and listen offline.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('SkeletonShimmer disables animation for reduced motion', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: SkeletonShimmer(child: SkeletonBox(width: 120, height: 48)),
          ),
        ),
      ),
    );

    expect(find.byType(ShaderMask), findsNothing);
    expect(find.byType(SkeletonBox), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SkeletonShimmer animates one fixture when motion is enabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SkeletonShimmer(child: SkeletonBox(width: 120, height: 48)),
        ),
      ),
    );

    expect(find.byType(ShaderMask), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('MarqueeWidget respects reduced-motion preference', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 120,
              child: MarqueeWidget(
                child: SizedBox(
                  width: 360,
                  child: Text('A long track title that can scroll'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
