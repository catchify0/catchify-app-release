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

import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:audio_service/audio_service.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/localization/app_localizations.dart';
import 'package:catchify/services/audio_service.dart';
import 'package:catchify/services/data_manager.dart';
import 'package:catchify/services/download_manager.dart';
import 'package:catchify/services/io_service.dart';
import 'package:catchify/services/listening_stats_service.dart';
import 'package:catchify/services/logger_service.dart';
export 'package:catchify/services/logger_service.dart' show isNetworkError;
import 'package:catchify/services/playlist_sharing.dart';
import 'package:catchify/services/playlists_manager.dart';
import 'package:catchify/services/router_service.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/services/update_manager.dart';
import 'package:catchify/theme/app_themes.dart';
import 'package:catchify/utilities/flutter_toast.dart';
import 'package:catchify/utilities/language_utils.dart';
import 'package:catchify/utilities/playlist_utils.dart';
import 'package:catchify/utilities/sharing_intent.dart';
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

late CatchifyAudioHandler audioHandler;
StreamSubscription<String?>? sharingIntentSubscription;
StreamSubscription<Uri?>? deepLinkSubscription;

final logger = Logger();
final appLinks = AppLinks();

bool isFdroidBuild = false;
bool isUpdateChecked = false;

class Catchify extends StatefulWidget {
  const Catchify({super.key});

  static Future<void> updateAppState(
    BuildContext context, {
    ThemeMode? newThemeMode,
    Locale? newLocale,
    Color? newAccentColor,
    bool? useSystemColor,
  }) async {
    context.findAncestorStateOfType<_CatchifyState>()?.changeSettings(
      newThemeMode: newThemeMode,
      newLocale: newLocale,
      newAccentColor: newAccentColor,
      systemColorStatus: useSystemColor,
    );
  }

  @override
  _CatchifyState createState() => _CatchifyState();
}

class _CatchifyState extends State<Catchify> with WidgetsBindingObserver {
  void changeSettings({
    ThemeMode? newThemeMode,
    Locale? newLocale,
    Color? newAccentColor,
    bool? systemColorStatus,
  }) {
    setState(() {
      if (newThemeMode != null) {
        themeMode = newThemeMode;
        brightness = getBrightnessFromThemeMode(newThemeMode);
      }
      if (newLocale != null) {
        languageSetting = newLocale;
      }
      if (newAccentColor != null) {
        if (systemColorStatus != null &&
            useSystemColor.value != systemColorStatus) {
          useSystemColor.value = systemColorStatus;
          addOrUpdateData<bool>(
            'settings',
            'useSystemColor',
            systemColorStatus,
          );
        }
        primaryColorSetting = newAccentColor;
      }
    });
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    offlineMode.addListener(_onOfflineModeChanged);

    sharingIntentSubscription = ReceiveSharingIntent.getTextStream().listen(
      (String? value) async {
        await consumeYoutubeSharedTextIntent(
          value,
          audioHandler: audioHandler,
          onError: (error, stackTrace) {
            logger.log(
              'Error while playing shared song:',
              error: error,
              stackTrace: stackTrace,
            );
          },
        );
      },
      onError: (err) {
        logger.log('getTextStream error:', error: err);
      },
    );

    try {
      LicenseRegistry.addLicense(() async* {
        final license = await rootBundle.loadString(
          'assets/licenses/paytone.txt',
        );
        yield LicenseEntryWithLineBreaks(['paytoneOne'], license);
      });
    } catch (e, stackTrace) {
      logger.log(
        'License Registration Error',
        error: e,
        stackTrace: stackTrace,
      );
    }

    if (Platform.isAndroid && !isFdroidBuild) {
      if (shouldWeCheckUpdates.value == true) {
        if (!isUpdateChecked && kReleaseMode) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (!offlineMode.value) {
              checkAppUpdates();
            }
            isUpdateChecked = true;
          });
        }
      } else {
        if (shouldWeCheckUpdates.value == null) {
          // show dialog that asks user if they want to enable update checks
          SchedulerBinding.instance.addPostFrameCallback((_) {
            showUpdateCheckDialog(NavigationManager().context);
          });
        } else {
          SchedulerBinding.instance.addPostFrameCallback((_) async {
            if (!offlineMode.value) {
              await fetchAnnouncementOnly();
            }
          });
        }
      }
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) async {
        if (!offlineMode.value) {
          await fetchAnnouncementOnly();
        }
      });
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 5), compactAllBoxes);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Persist listening stats when the app leaves the foreground. This is the
    // reliable moment to snapshot and flush: unlike widget dispose, these
    // callbacks are delivered before the OS suspends or terminates the process.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      audioHandler.saveCurrentPlaybackState();
      listeningStatsService.recordListeningSessionProgress(
        wasPlaying: audioHandler.audioPlayer.playing,
      );
      unawaited(listeningStatsService.flush());
    }
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    if (!mounted || themeMode != ThemeMode.system) return;

    final nextBrightness = getBrightnessFromThemeMode(ThemeMode.system);
    if (brightness != nextBrightness) {
      setState(() => brightness = nextBrightness);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    offlineMode.removeListener(_onOfflineModeChanged);

    unawaited(sharingIntentSubscription?.cancel());
    sharingIntentSubscription = null;
    unawaited(deepLinkSubscription?.cancel());
    deepLinkSubscription = null;
    unawaited(Hive.close());
    super.dispose();
  }

  void _onOfflineModeChanged() {
    // Force rebuild when offline mode changes
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightColorScheme, darkColorScheme) {
        final (lightScheme, darkScheme) = getAppColorSchemes(
          lightColorScheme,
          darkColorScheme,
        );

        final isDarkActive = brightness == Brightness.dark;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarContrastEnforced: true,
            statusBarBrightness: isDarkActive
                ? Brightness.dark
                : Brightness.light,
            statusBarIconBrightness: isDarkActive
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarIconBrightness: isDarkActive
                ? Brightness.light
                : Brightness.dark,
          ),
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            themeMode: themeMode,
            darkTheme: getAppTheme(darkScheme),
            theme: getAppTheme(lightScheme),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: appSupportedLocales,
            locale: languageSetting,
            routerConfig: NavigationManager.router,
          ),
        );
      },
    );
  }
}

final Stopwatch appStartupStopwatch = Stopwatch();
int? appStartupMs;
int? appFirstFrameMs;
int? homeCacheMs;
int? homeContentMs;

void checkAndLogColdStartPerf() {
  if (appStartupMs != null &&
      appFirstFrameMs != null &&
      homeCacheMs != null &&
      homeContentMs != null) {
    logger.log(
      '[PERF] startup_ms=$appStartupMs first_frame_ms=$appFirstFrameMs home_cache_ms=$homeCacheMs home_content_ms=$homeContentMs',
    );
  }
}

void main() async {
  appStartupStopwatch.start();
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    logger.log(
      'Flutter framework error',
      error: details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    logger.log(
      'Unhandled platform error',
      error: error,
      stackTrace: stackTrace,
    );
    return false;
  };

  PaintingBinding.instance.imageCache
    ..maximumSize = 400
    ..maximumSizeBytes = 120 << 20;

  await initialisation();
  appStartupMs = appStartupStopwatch.elapsedMilliseconds;

  runApp(const Catchify());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (appFirstFrameMs == null) {
      appFirstFrameMs = appStartupStopwatch.elapsedMilliseconds;
      checkAndLogColdStartPerf();
    }
  });
}

Future<void> initialisation() async {
  try {
    await logger.initialize();
    await Hive.initFlutter();

    await Future.wait([
      Hive.openBox('settings'),
      Hive.openBox('user'),
      Hive.openBox('userNoBackup'),
      Hive.openBox('cache'),
      Hive.openBox('lyricsCache'),
    ]);

    audioHandler = await AudioService.init(
      builder: CatchifyAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.catchify.app',
        androidNotificationChannelName: 'Catchify',
        androidNotificationIcon: 'drawable/ic_launcher_foreground',
        androidShowNotificationBadge: true,
        androidStopForegroundOnPause: false,
      ),
    );

    // Init router
    NavigationManager.instance;

    try {
      // Listen to incoming links while app is running
      deepLinkSubscription = appLinks.uriLinkStream.listen(
        handleIncomingLink,
        onError: (err) {
          logger.log('URI link error:', error: err);
        },
      );
    } on PlatformException {
      logger.log('Failed to get initial uri');
    }

    if (isFdroidBuild && !offlineMode.value) {
      await fetchAnnouncementOnly();
    }
  } catch (e, stackTrace) {
    logger.log('Initialization Error', error: e, stackTrace: stackTrace);
  }

  applicationDirPath = (await getApplicationDocumentsDirectory()).path;
  await FilePaths.ensureDirectoriesExist();
  await DownloadManager.instance.initialize();
}

void handleIncomingLink(Uri? uri) async {
  if (uri != null && uri.scheme == 'catchify' && uri.host == 'playlist') {
    try {
      if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'custom') {
        final encodedPlaylist = uri.pathSegments[1];

        final playlist = await PlaylistSharingService.decodeAndExpandPlaylist(
          encodedPlaylist,
        );

        if (playlist != null) {
          // Ensure the incoming playlist has a unique id so it can be removed later
          if (playlist['ytid'] == null || playlist['ytid'].toString().isEmpty) {
            playlist['ytid'] = PlaylistUtils.generateCustomPlaylistId();
          }
          // Check for duplicate by title and song ytids
          final incomingList = playlist['list'];
          if (incomingList is! List) {
            return;
          }
          final incomingYtids = incomingList
              .whereType<Map>()
              .map((s) => s['ytid']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toList();

          final exists = userCustomPlaylists.value.any((p) {
            if (p['title'] != playlist['title']) return false;
            final existingList = p['list'] is List ? p['list'] as List : [];
            final existingYtids = existingList
                .map((s) => s['ytid']?.toString())
                .where((e) => e != null)
                .toList();
            if (existingYtids.length != incomingYtids.length) return false;
            for (var i = 0; i < incomingYtids.length; i++) {
              if (existingYtids[i] != incomingYtids[i]) return false;
            }
            return true;
          });

          if (exists) {
            showToast(
              NavigationManager().context,
              NavigationManager().context.l10n!.playlistAlreadyExists,
            );
          } else {
            userCustomPlaylists.value = [
              ...userCustomPlaylists.value,
              playlist,
            ];
            unawaited(
              addOrUpdateData<List>(
                'user',
                'customPlaylists',
                userCustomPlaylists.value,
              ),
            );
            showToast(
              NavigationManager().context,
              '${NavigationManager().context.l10n!.addedSuccess}!',
            );
          }
        } else {
          showToast(
            NavigationManager().context,
            NavigationManager().context.l10n!.failedToLoadPlaylist,
          );
        }
      }
    } catch (e) {
      showToast(
        NavigationManager().context,
        NavigationManager().context.l10n!.failedToLoadPlaylist,
      );
    }
  }
}
