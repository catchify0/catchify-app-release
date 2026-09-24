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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:catchify/constants/version.dart';
import 'package:catchify/screens/about_page.dart';
import 'package:catchify/screens/artist_page.dart';
import 'package:catchify/screens/bottom_navigation_page.dart';
import 'package:catchify/screens/equalizer_page.dart';
import 'package:catchify/screens/home_page.dart';
import 'package:catchify/screens/import_spotify_playlist_page.dart';
import 'package:catchify/screens/language_onboarding_page.dart';
import 'package:catchify/screens/library_page.dart';
import 'package:catchify/screens/playlist_folder_page.dart';
import 'package:catchify/screens/playlist_page.dart';
import 'package:catchify/screens/search_page.dart';
import 'package:catchify/screens/settings_page.dart';
import 'package:catchify/screens/settings/backup_restore_page.dart';
import 'package:catchify/screens/settings/playback_settings_page.dart';
import 'package:catchify/screens/settings/player_settings_page.dart';
import 'package:catchify/screens/settings/storage_cache_page.dart';
import 'package:catchify/screens/settings/theme_settings_page.dart';
import 'package:catchify/screens/time_machine_page.dart';
import 'package:catchify/screens/top_charts_page.dart';
import 'package:catchify/screens/user_songs_page.dart';
import 'package:catchify/services/playlist_download_service.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/widgets/offline_search_placeholder.dart';

class NavigationManager {
  factory NavigationManager() {
    return _instance;
  }

  NavigationManager._internal() {
    _setupRouter();
  }

  void _setupRouter() {
    final routes = [
      GoRoute(
        parentNavigatorKey: parentNavigatorKey,
        path: languageOnboardingPath,
        pageBuilder: (context, state) =>
            getPage(child: const LanguageOnboardingPage(), state: state),
      ),
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: parentNavigatorKey,
        branches: _getRouteBranches(),
        pageBuilder: (context, state, navigationShell) {
          return getPage(
            child: BottomNavigationPage(child: navigationShell),
            state: state,
          );
        },
      ),
    ];

    router = GoRouter(
      navigatorKey: parentNavigatorKey,
      initialLocation: hasSeenLanguageOnboarding
          ? homePath
          : languageOnboardingPath,
      routes: routes,
      restorationScopeId: 'router',
      debugLogDiagnostics: kDebugMode,
      routerNeglect: true,
      redirect: (context, state) {
        // Handle offline mode redirects
        final isOffline = offlineMode.value;
        final currentPath = state.matchedLocation;

        if (isOffline &&
            (currentPath == searchPath ||
                currentPath == timeMachinePath ||
                currentPath == chartsPath)) {
          // Redirect unavailable pages to home in offline mode
          return homePath;
        }

        if (isOffline && currentPath.contains('/artist/')) {
          final artistId = _decodePathParameter(
            state.pathParameters['artistId'],
          );
          if (!offlinePlaylistService.isPlaylistDownloaded(artistId)) {
            return homePath;
          }
        }

        return null; // No redirect needed
      },
    );
  }

  static final NavigationManager _instance = NavigationManager._internal();

  static NavigationManager get instance => _instance;

  static late final GoRouter router;

  static final GlobalKey<NavigatorState> parentNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> homeTabNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> chartsTabNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> searchTabNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> libraryTabNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> settingsTabNavigatorKey =
      GlobalKey<NavigatorState>();

  BuildContext get context {
    final ctx = router.routerDelegate.navigatorKey.currentContext;
    if (ctx == null) {
      throw StateError(
        'NavigationManager.context was accessed before the navigator context was available.',
      );
    }
    return ctx;
  }

  GoRouterDelegate get routerDelegate => router.routerDelegate;

  GoRouteInformationParser get routeInformationParser =>
      router.routeInformationParser;

  static const String languageOnboardingPath = '/language-onboarding';
  static const String homePath = '/home';
  static const String chartsPath = '/charts';
  static const String timeMachinePath = '$homePath/timeMachine';
  static const String settingsPath = '/settings';
  static const String searchPath = '/search';
  static const String libraryPath = '/library';

  /// Refresh the router configuration when offline mode changes
  static void refreshRouter() {
    // Force router to re-evaluate redirect logic
    router.refresh();
  }

  List<StatefulShellBranch> _getRouteBranches() {
    // Always return all branches, but handle visibility in the UI
    return [
      // Branch 0: Home
      StatefulShellBranch(
        navigatorKey: homeTabNavigatorKey,
        routes: [
          GoRoute(
            path: homePath,
            pageBuilder: (context, GoRouterState state) {
              return getPage(
                child: ValueListenableBuilder<bool>(
                  valueListenable: offlineMode,
                  builder: (context, isOffline, _) {
                    return isOffline
                        ? const UserSongsPage(page: 'offline')
                        : const HomePage();
                  },
                ),
                state: state,
              );
            },
            routes: [
              GoRoute(
                path: 'timeMachine',
                pageBuilder: (context, state) =>
                    _pushPage(child: const TimeMachinePage(), state: state),
              ),
              GoRoute(
                path: 'library',
                pageBuilder: (context, state) =>
                    _pushPage(child: const LibraryPage(), state: state),
              ),
              GoRoute(
                path: 'playlist/:playlistId',
                pageBuilder: (context, state) => _pushPage(
                  child: PlaylistPage(
                    playlistId: state.pathParameters['playlistId'],
                    playlistData: _extraAsMap(state.extra),
                  ),
                  state: state,
                ),
              ),
              GoRoute(
                path: 'artist/:artistId',
                pageBuilder: (context, state) => _pushPage(
                  child: ArtistPage(
                    artistId: _decodePathParameter(
                      state.pathParameters['artistId'],
                    ),
                    artistData: _extraAsMap(state.extra),
                  ),
                  state: state,
                ),
              ),
              GoRoute(
                path: 'folder/:folderId/:folderName',
                pageBuilder: (context, state) => _pushPage(
                  child: PlaylistFolderPage(
                    folderId: state.pathParameters['folderId'] ?? '',
                    folderName: state.pathParameters['folderName'] ?? '',
                  ),
                  state: state,
                ),
              ),
            ],
          ),
        ],
      ),
      // Branch 1: Top Charts
      StatefulShellBranch(
        navigatorKey: chartsTabNavigatorKey,
        routes: [
          GoRoute(
            path: chartsPath,
            pageBuilder: (context, GoRouterState state) {
              return getPage(
                child: ValueListenableBuilder<bool>(
                  valueListenable: offlineMode,
                  builder: (context, isOffline, _) {
                    return isOffline
                        ? const UserSongsPage(page: 'offline')
                        : const TopChartsPage();
                  },
                ),
                state: state,
              );
            },
            routes: [
              GoRoute(
                path: 'playlist/:playlistId',
                pageBuilder: (context, state) => _pushPage(
                  child: PlaylistPage(
                    playlistId: state.pathParameters['playlistId'],
                    playlistData: _extraAsMap(state.extra),
                  ),
                  state: state,
                ),
              ),
              GoRoute(
                path: 'artist/:artistId',
                pageBuilder: (context, state) => _pushPage(
                  child: ArtistPage(
                    artistId: _decodePathParameter(
                      state.pathParameters['artistId'],
                    ),
                    artistData: _extraAsMap(state.extra),
                  ),
                  state: state,
                ),
              ),
            ],
          ),
        ],
      ),
      // Branch 2: Search
      StatefulShellBranch(
        navigatorKey: searchTabNavigatorKey,
        routes: [
          GoRoute(
            path: searchPath,
            pageBuilder: (context, GoRouterState state) {
              return getPage(
                child: ValueListenableBuilder<bool>(
                  valueListenable: offlineMode,
                  builder: (context, isOffline, _) {
                    return isOffline
                        ? const OfflineSearchPlaceholder()
                        : const SearchPage();
                  },
                ),
                state: state,
              );
            },
            routes: [
              GoRoute(
                path: 'playlist/:playlistId',
                pageBuilder: (context, state) => _pushPage(
                  child: PlaylistPage(
                    playlistId: state.pathParameters['playlistId'],
                    playlistData: _extraAsMap(state.extra),
                  ),
                  state: state,
                ),
              ),
              GoRoute(
                path: 'artist/:artistId',
                pageBuilder: (context, state) => _pushPage(
                  child: ArtistPage(
                    artistId: _decodePathParameter(
                      state.pathParameters['artistId'],
                    ),
                    artistData: _extraAsMap(state.extra),
                  ),
                  state: state,
                ),
              ),
            ],
          ),
        ],
      ),
      // Branch 2: Library
      StatefulShellBranch(
        navigatorKey: libraryTabNavigatorKey,
        routes: [
          GoRoute(
            path: libraryPath,
            pageBuilder: (context, GoRouterState state) {
              return getPage(child: const LibraryPage(), state: state);
            },
            routes: [
              GoRoute(
                path: 'playlist/:playlistId',
                pageBuilder: (context, state) => _pushPage(
                  child: PlaylistPage(
                    playlistId: state.pathParameters['playlistId'],
                    playlistData: _extraAsMap(state.extra),
                  ),
                  state: state,
                ),
              ),
              GoRoute(
                path: 'userSongs/:page',
                pageBuilder: (context, state) => _pushPage(
                  child: UserSongsPage(
                    page: state.pathParameters['page'] ?? 'liked',
                  ),
                  state: state,
                ),
              ),
              GoRoute(
                path: 'folder/:folderId/:folderName',
                pageBuilder: (context, state) => _pushPage(
                  child: PlaylistFolderPage(
                    folderId: state.pathParameters['folderId'] ?? '',
                    folderName: state.pathParameters['folderName'] ?? '',
                  ),
                  state: state,
                ),
              ),
              GoRoute(
                path: 'artist/:artistId',
                pageBuilder: (context, state) => _pushPage(
                  child: ArtistPage(
                    artistId: _decodePathParameter(
                      state.pathParameters['artistId'],
                    ),
                    artistData: _extraAsMap(state.extra),
                  ),
                  state: state,
                ),
              ),
            ],
          ),
        ],
      ),
      // Branch 3: Settings
      StatefulShellBranch(
        navigatorKey: settingsTabNavigatorKey,
        routes: [
          GoRoute(
            path: settingsPath,
            pageBuilder: (context, state) {
              return getPage(child: const SettingsPage(), state: state);
            },
            routes: [
              GoRoute(
                path: 'license',
                pageBuilder: (context, state) => _pushPage(
                  child: LicensePage(
                    applicationName: 'Catchify',
                    applicationVersion: 'v$appVersion',
                    applicationIcon: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        'assets/icons/catchify-brand.png',
                        width: 48,
                        height: 48,
                        fit: BoxFit.contain,
                      ),
                    ),
                    applicationLegalese:
                        'Copyright (C) 2026 Thamodharan Ganesan\nLicensed under GNU General Public License v3.0 (GPL-3.0)\nFree and Open Source Software',
                  ),
                  state: state,
                ),
              ),
              GoRoute(
                path: 'theme',
                pageBuilder: (context, state) =>
                    _pushPage(child: const ThemeSettingsPage(), state: state),
              ),
              GoRoute(
                path: 'playback',
                pageBuilder: (context, state) => _pushPage(
                  child: const PlaybackSettingsPage(),
                  state: state,
                ),
              ),
              GoRoute(
                path: 'player',
                pageBuilder: (context, state) =>
                    _pushPage(child: const PlayerSettingsPage(), state: state),
              ),
              GoRoute(
                path: 'storage',
                pageBuilder: (context, state) =>
                    _pushPage(child: const StorageCachePage(), state: state),
              ),
              GoRoute(
                path: 'backup',
                pageBuilder: (context, state) =>
                    _pushPage(child: const BackupRestorePage(), state: state),
              ),
              GoRoute(
                path: 'about',
                pageBuilder: (context, state) =>
                    _pushPage(child: const AboutPage(), state: state),
              ),
              GoRoute(
                path: 'equalizer',
                pageBuilder: (context, state) =>
                    _pushPage(child: const EqualizerPage(), state: state),
              ),
              GoRoute(
                path: 'importSpotifyPlaylist',
                pageBuilder: (context, state) => _pushPage(
                  child: const ImportSpotifyPlaylistPage(),
                  state: state,
                ),
              ),
            ],
          ),
        ],
      ),
    ];
  }

  /// go_router already URL-decodes path parameters internally (see its
  /// GoRouteMatch.decodedParams), so this only needs to null-coalesce —
  /// decoding again here would throw on a value that legitimately contains
  /// a literal '%' once decoded (e.g. an artist named "50% Off").
  static String _decodePathParameter(String? value) => value ?? '';

  static Map? _extraAsMap(Object? extra) {
    if (extra is Map) return Map<String, dynamic>.from(extra);
    return null;
  }

  static Page<void> getPage({
    required Widget child,
    required GoRouterState state,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
          return child;
        }
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }

  static Page<void> _pushPage({
    required Widget child,
    required GoRouterState state,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
          return child;
        }
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }
}
