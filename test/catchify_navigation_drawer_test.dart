import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catchify/widgets/catchify_navigation_drawer.dart';
import 'package:catchify/widgets/pill_navigation_bar.dart';

void main() {
  final testItems = [
    const PillNavigationItem(
      icon: FluentIcons.home_24_regular,
      selectedIcon: FluentIcons.home_24_filled,
      label: 'Home',
    ),
    const PillNavigationItem(
      icon: FluentIcons.arrow_trending_24_regular,
      selectedIcon: FluentIcons.arrow_trending_24_filled,
      label: 'Charts',
    ),
    const PillNavigationItem(
      icon: FluentIcons.search_24_regular,
      selectedIcon: FluentIcons.search_24_filled,
      label: 'Search',
    ),
    const PillNavigationItem(
      icon: FluentIcons.library_24_regular,
      selectedIcon: FluentIcons.library_24_filled,
      label: 'Library',
    ),
    const PillNavigationItem(
      icon: FluentIcons.settings_24_regular,
      selectedIcon: FluentIcons.settings_24_filled,
      label: 'Settings',
    ),
  ];

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
          items: testItems,
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
    expect(find.text('Free Music Streaming'), findsOneWidget);
    expect(find.text('MAIN MENU'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Charts'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('DISCOVER & TOOLS'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Theme & Appearance'),
      50,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Theme & Appearance'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('About Catchify'),
      50,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('About Catchify'), findsOneWidget);
  });

  testWidgets('Selecting a navigation item calls callback and closes drawer', (
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

    // Tap 'Library' tab (index 3)
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();

    // Callback was invoked with index 3
    expect(selectedTab, 3);

    // Drawer should now be closed
    expect(find.text('MAIN MENU'), findsNothing);
  });

  testWidgets('Dismiss button closes the drawer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestScaffold());

    // Open drawer
    await tester.tap(find.text('Open Menu'));
    await tester.pumpAndSettle();
    expect(find.text('Catchify'), findsOneWidget);

    // Tap dismiss button
    await tester.tap(find.byTooltip('Close sidebar'));
    await tester.pumpAndSettle();

    // Drawer is closed
    expect(find.text('Catchify'), findsNothing);
  });

  testWidgets('Offline mode renders offline banner', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestScaffold(isOfflineMode: true));

    // Open drawer
    await tester.tap(find.text('Open Menu'));
    await tester.pumpAndSettle();

    // Check offline banner is shown
    expect(
      find.text('Offline mode active — local & downloaded content only.'),
      findsOneWidget,
    );
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

    // Tap 'Settings' tab (index 4)
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // Callback was invoked with index 4
    expect(selectedTab, 4);

    // Drawer should now be closed
    expect(find.text('MAIN MENU'), findsNothing);
  });
}
