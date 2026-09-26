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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:catchify/constants/app_tokens.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/flutter_bottom_sheet.dart'
    show closeCurrentBottomSheet;
import 'package:catchify/widgets/mini_player.dart';
import 'package:catchify/widgets/pill_navigation_bar.dart';

class BottomNavigationPage extends StatefulWidget {
  const BottomNavigationPage({required this.child, super.key});

  final StatefulNavigationShell child;

  @override
  State<BottomNavigationPage> createState() => _BottomNavigationPageState();
}

class _BottomNavigationPageState extends State<BottomNavigationPage> {
  late final _miniPlayerVisibilityStream = audioHandler.mediaItem
      .map((mediaItem) => mediaItem != null)
      .distinct();

  bool? _previousOfflineMode;

  /// Track the previously selected tab index to detect double-taps on the same tab.
  int? _previousTabIndex;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.child.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        final currentIndex = widget.child.currentIndex;
        if (currentIndex != 0) {
          widget.child.goBranch(0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: ValueListenableBuilder<bool>(
        valueListenable: offlineMode,
        builder: (context, isOfflineMode, _) {
          if (_previousOfflineMode != null &&
              _previousOfflineMode != isOfflineMode) {
            SchedulerBinding.instance.addPostFrameCallback((_) {
              _handleOfflineModeChange(isOfflineMode);
            });
          }
          _previousOfflineMode = isOfflineMode;

          return LayoutBuilder(
            builder: (context, constraints) {
              final isLargeScreen =
                  constraints.maxWidth >= AppTokens.railBreakpoint;
              final items = _getNavigationItems(isOfflineMode);

              return Scaffold(
                body: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      if (isLargeScreen)
                        SafeArea(
                          child: NavigationRail(
                            labelType: NavigationRailLabelType.selected,
                            destinations: items
                                .map(
                                  (item) => NavigationRailDestination(
                                    icon: Icon(item.icon),
                                    selectedIcon: Icon(item.selectedIcon),
                                    label: Text(item.label),
                                  ),
                                )
                                .toList(),
                            selectedIndex: _getCurrentIndex(
                              items,
                              isOfflineMode,
                            ),
                            onDestinationSelected: (index) =>
                                _onTabTapped(index, items),
                          ),
                        ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: AppTokens.wideContentMaxWidth,
                            ),
                            child: StreamBuilder<bool>(
                              initialData: audioHandler.mediaItem.value != null,
                              stream: _miniPlayerVisibilityStream,
                              builder: (context, snapshot) {
                                final mediaQuery = MediaQuery.of(context);
                                final isMiniPlayerVisible =
                                    snapshot.data ??
                                    (audioHandler.mediaItem.value != null);
                                final bottomPadding = !isMiniPlayerVisible
                                    ? mediaQuery.padding.bottom
                                    : mediaQuery.padding.bottom +
                                          AppTokens.miniPlayerTotalHeight;

                                return Stack(
                                  alignment: Alignment.bottomCenter,
                                  children: [
                                    MediaQuery(
                                      data: mediaQuery.copyWith(
                                        padding: mediaQuery.padding.copyWith(
                                          bottom: bottomPadding,
                                        ),
                                      ),
                                      child: widget.child,
                                    ),
                                    AnimatedSlide(
                                      offset: isMiniPlayerVisible
                                          ? Offset.zero
                                          : const Offset(0, 1.2),
                                      duration: AppTokens.motionStandard,
                                      curve: Curves.easeOutCubic,
                                      child: AnimatedOpacity(
                                        opacity: isMiniPlayerVisible
                                            ? 1.0
                                            : 0.0,
                                        duration: AppTokens.motionStandard,
                                        curve: Curves.easeOutCubic,
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: AppTokens.pagePadding,
                                            vertical: 8,
                                          ),
                                          child: MiniPlayer(),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                bottomNavigationBar: !isLargeScreen
                    ? PillNavigationBar(
                        selectedIndex: _getCurrentIndex(items, isOfflineMode),
                        onDestinationSelected: (index) =>
                            _onTabTapped(index, items),
                        items: items,
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  List<_NavigationItem> _getNavigationItems(bool isOfflineMode) {
    final items = <_NavigationItem>[
      _NavigationItem(
        icon: FluentIcons.home_24_regular,
        selectedIcon: FluentIcons.home_24_filled,
        label: context.l10n?.home ?? 'Home',
        route: '/home',
        shellIndex: 0,
      ),
    ];

    // Only add search and charts tabs in online mode
    if (!isOfflineMode) {
      items.addAll([
        const _NavigationItem(
          icon: FluentIcons.arrow_trending_24_regular,
          selectedIcon: FluentIcons.arrow_trending_24_filled,
          label: 'Charts',
          route: '/charts',
          shellIndex: 1,
        ),
        _NavigationItem(
          icon: FluentIcons.search_24_regular,
          selectedIcon: FluentIcons.search_24_filled,
          label: context.l10n?.search ?? 'Search',
          route: '/search',
          shellIndex: 2,
        ),
      ]);
    }

    items.addAll([
      _NavigationItem(
        icon: FluentIcons.library_24_regular,
        selectedIcon: FluentIcons.library_24_filled,
        label: context.l10n?.library ?? 'Library',
        route: '/library',
        shellIndex: 3,
      ),
      _NavigationItem(
        icon: FluentIcons.settings_24_regular,
        selectedIcon: FluentIcons.settings_24_filled,
        label: context.l10n?.settings ?? 'Settings',
        route: '/settings',
        shellIndex: 4,
      ),
    ]);

    return items;
  }

  void _handleOfflineModeChange(bool isOfflineMode) {
    if (!mounted) return;

    final currentRoute = GoRouterState.of(context).matchedLocation;

    // If we're switching to offline mode and currently on search or charts tab
    if (isOfflineMode &&
        (currentRoute.startsWith('/search') ||
            currentRoute.startsWith('/charts'))) {
      // Navigate to home
      widget.child.goBranch(0);
    }
  }

  void _onTabTapped(int index, List<_NavigationItem> items) {
    if (index < items.length) {
      final item = items[index];
      final isReselect = _previousTabIndex == index;

      HapticFeedback.selectionClick();

      // Close any open bottom sheet before switching tabs
      closeCurrentBottomSheet();

      // If user taps the same tab again, reset it to initial state.
      // Otherwise, preserve the branch state.
      if (isReselect) {
        widget.child.goBranch(item.shellIndex, initialLocation: true);
      } else {
        widget.child.goBranch(item.shellIndex);
      }

      _previousTabIndex = index;
    }
  }

  int _getCurrentIndex(List<_NavigationItem> items, bool isOfflineMode) {
    final currentShellIndex = widget.child.currentIndex;

    if (items.isEmpty) return 0;

    // Try to find the current shell index in the available items
    final matchedIndex = items.indexWhere(
      (item) => item.shellIndex == currentShellIndex,
    );
    if (matchedIndex != -1) return matchedIndex;

    // If the Charts (1) or Search (2) branch is active but hidden in offline mode,
    // fall back to the Home tab.
    if (isOfflineMode && (currentShellIndex == 1 || currentShellIndex == 2)) {
      return 0;
    }

    // Final fallback: return the first tab to keep UI in a valid state.
    return 0;
  }
}

class _NavigationItem extends PillNavigationItem {
  const _NavigationItem({
    required super.icon,
    required super.selectedIcon,
    required super.label,
    required this.route,
    required this.shellIndex,
  });

  final String route;
  final int shellIndex;
}
