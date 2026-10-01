import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/widgets/catchify_navigation_drawer.dart';

void main() {
  Widget buildTestScaffold({
    int selectedIndex = 0,
    bool isOfflineMode = false,
    ValueChanged<int>? onDestinationSelected,
  }) {
    return MaterialApp(
      home: Scaffold(
        key: CatchifyNavigationDrawer.scaffoldKey,
        drawer: CatchifyNavigationDrawer(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected ?? (_) {},
          isOfflineMode: isOfflineMode,
          offlineNotifier: ValueNotifier<bool>(isOfflineMode),
        ),
        body: Center(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => CatchifyNavigationDrawer.open(context),
                child: const Text('Open Menu'),
              );
            },
          ),
        ),
      ),
    );
  }

  testWidgets('CatchifyNavigationDrawer opens and renders branding and destinations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestScaffold());

    // Initially drawer is closed
    expect(find.text('Catchify'), findsNothing);

    // Tap to open drawer
    await tester.tap(find.text('Open Menu'));
    await tester.pumpAndSettle();

    // Now drawer is open
    expect(find.text('Catchify'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('My Music'), findsOneWidget);
    expect(find.text('Playlists'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Help us by rating'), findsOneWidget);
    expect(find.text('InkStudio'), findsOneWidget);
    expect(find.text('Go Premium'), findsOneWidget);
  });

  testWidgets('Selecting Home calls callback and closes drawer', (
    WidgetTester tester,
  ) async {
    int? selectedTab;

    await tester.pumpWidget(
      buildTestScaffold(
        selectedIndex: 4,
        onDestinationSelected: (index) {
          selectedTab = index;
        },
      ),
    );

    // Open drawer
    await tester.tap(find.text('Open Menu'));
    await tester.pumpAndSettle();

    // Tap 'Home' tab (shell branch 0)
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    // Callback was invoked with index 0
    expect(selectedTab, 0);

    // Drawer should now be closed
    expect(find.text('Catchify'), findsNothing);
  });

  testWidgets('Selecting My Music calls callback and closes drawer', (
    WidgetTester tester,
  ) async {
    int? selectedTab;

    await tester.pumpWidget(
      buildTestScaffold(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          selectedTab = index;
        },
      ),
    );

    // Open drawer
    await tester.tap(find.text('Open Menu'));
    await tester.pumpAndSettle();

    // Tap 'My Music' tab (shell branch 3)
    await tester.tap(find.text('My Music'));
    await tester.pumpAndSettle();

    // Callback was invoked with index 3
    expect(selectedTab, 3);

    // Drawer should now be closed
    expect(find.text('Catchify'), findsNothing);
  });

  testWidgets('Selecting Playlists calls callback and closes drawer', (
    WidgetTester tester,
  ) async {
    int? selectedTab;

    await tester.pumpWidget(
      buildTestScaffold(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          selectedTab = index;
        },
      ),
    );

    // Open drawer
    await tester.tap(find.text('Open Menu'));
    await tester.pumpAndSettle();

    // Tap 'Playlists' tab (shell branch 3)
    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();

    // Callback was invoked with index 3
    expect(selectedTab, 3);

    // Drawer should now be closed
    expect(find.text('Catchify'), findsNothing);
  });

  testWidgets('Selecting Settings from the drawer calls callback and closes drawer', (
    WidgetTester tester,
  ) async {
    int? selectedTab;

    await tester.pumpWidget(
      buildTestScaffold(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          selectedTab = index;
        },
      ),
    );

    // Open drawer
    await tester.tap(find.text('Open Menu'));
    await tester.pumpAndSettle();

    // Tap 'Settings' tab (shell branch 4)
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // Callback was invoked with index 4
    expect(selectedTab, 4);

    // Drawer should now be closed
    expect(find.text('Catchify'), findsNothing);
  });

  testWidgets('CatchifyNavigationDrawer.close closes the open drawer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestScaffold());

    // Open drawer
    await tester.tap(find.text('Open Menu'));
    await tester.pumpAndSettle();
    expect(find.text('Catchify'), findsOneWidget);

    // Close via static helper
    CatchifyNavigationDrawer.close();
    await tester.pumpAndSettle();

    // Drawer is closed
    expect(find.text('Catchify'), findsNothing);
  });

  testWidgets('Offline mode renders offline badge', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestScaffold(isOfflineMode: true));

    // Open drawer
    await tester.tap(find.text('Open Menu'));
    await tester.pumpAndSettle();

    // Check offline badge is shown
    expect(find.text('Offline Mode'), findsOneWidget);
  });

  testWidgets('Tapping Go Premium opens the premium perks bottom sheet', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestScaffold());

    // Open drawer
    await tester.tap(find.text('Open Menu'));
    await tester.pumpAndSettle();

    // Tap Go Premium
    await tester.tap(find.text('Go Premium'));
    await tester.pumpAndSettle();

    // Verify sheet contents
    expect(find.text("You're on Catchify Premium!"), findsOneWidget);
    expect(find.text('Awesome, Enjoy!'), findsOneWidget);

    // Dismiss sheet
    await tester.tap(find.text('Awesome, Enjoy!'));
    await tester.pumpAndSettle();

    expect(find.text("You're on Catchify Premium!"), findsNothing);
  });
}
