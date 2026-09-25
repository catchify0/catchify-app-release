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

import 'dart:async';

import 'package:intl/intl.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:catchify/constants/app_constants.dart';
import 'package:catchify/constants/app_tokens.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart';
import 'package:catchify/models/home_section.dart';
import 'package:catchify/services/listening_stats_service.dart';
import 'package:catchify/services/playlists_manager.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/app_utils.dart';
import 'package:catchify/utilities/async_loader.dart';
import 'package:catchify/utilities/listening_stats_utils.dart';
import 'package:catchify/theme/app_text_styles.dart';
import 'package:catchify/widgets/announcement_box.dart';
import 'package:catchify/widgets/empty_state.dart';
import 'package:catchify/widgets/error_state.dart';
import 'package:catchify/widgets/home_section_renderer.dart';
import 'package:catchify/widgets/listening_recap_card.dart';
import 'package:catchify/widgets/loading_skeleton.dart';
import 'package:catchify/widgets/mini_player_bottom_space.dart';
import 'package:catchify/widgets/section_header.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<HomeSection>> _homeFeedFuture;

  String _selectedMood = 'All';
  static const _moods = [
    'All',
    'Romance',
    'Party',
    'Workout',
    'Chill',
    'Feel good',
    'Energy',
    'Focus',
  ];

  /// Guard flag: ensures the initial load is launched once after route
  /// dependencies are available.
  bool _loadStarted = false;

  /// Guard flag: ensures the freshLoad from language onboarding is only
  /// consumed once, even if didChangeDependencies is called multiple times.
  bool _freshLoadConsumed = false;

  /// Tracks current content language code to log language transitions.
  String? _currentContentLanguageCode;
  int _feedGeneration = 0;
  Timer? _languageRefreshDebounce;

  void _initFutures({
    bool forceRefresh = false,
    bool bypassRefreshDeduplication = false,
    String source = 'automatic',
  }) {
    _feedGeneration++;
    if (forceRefresh) {
      logger.log(
        '[HOME_REFRESH_REQUEST] source=$source bypass=$bypassRefreshDeduplication',
      );
    }
    _homeFeedFuture = getUnifiedHomeFeed(
      forceRefresh: forceRefresh,
      mood: _selectedMood,
      bypassRefreshDeduplication: bypassRefreshDeduplication,
    );
  }

  void _onMoodSelected(String mood) {
    if (_selectedMood == mood) return;
    HapticFeedback.lightImpact();
    setState(() {
      _selectedMood = mood;
      _initFutures(source: 'mood');
    });
  }

  @override
  void initState() {
    super.initState();
    _currentContentLanguageCode = contentLanguagePreferenceNotifier.value;
    externalRecommendations.addListener(_refreshHomeFeed);
    contentLanguagePreferenceNotifier.addListener(_onLanguagePreferenceChanged);
    contentCountryPreferenceNotifier.addListener(_onCountryPreferenceChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadStarted) {
      _loadStarted = true;
      final extra = GoRouterState.of(context).extra;
      if (extra is Map && extra['freshLoad'] == true) {
        _freshLoadConsumed = true;
        // A language change already namespaces the cache key. Let the normal
        // cache lookup serve an existing feed when the page is recreated.
        _initFutures();
        return;
      }
      _initFutures();
    }

    // When navigating here from language onboarding, GoRouter passes
    // extra: {'freshLoad': true}. Detect it and do one clean reload so
    // the correct language's content is shown — without a second spinner.
    // _freshLoadConsumed guards against firing on every subsequent
    // didChangeDependencies call (e.g. on Locale / Theme changes).
    if (_freshLoadConsumed) return;
    final extra = GoRouterState.of(context).extra;
    if (extra is Map && extra['freshLoad'] == true) {
      _freshLoadConsumed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedMood = 'All';
          _initFutures();
        });
      });
    }
  }

  @override
  void dispose() {
    externalRecommendations.removeListener(_refreshHomeFeed);
    contentLanguagePreferenceNotifier.removeListener(
      _onLanguagePreferenceChanged,
    );
    contentCountryPreferenceNotifier.removeListener(
      _onCountryPreferenceChanged,
    );
    _languageRefreshDebounce?.cancel();
    super.dispose();
  }

  void _onLanguagePreferenceChanged() {
    final oldLang = _currentContentLanguageCode;
    final newLang = contentLanguagePreferenceNotifier.value;
    _currentContentLanguageCode = newLang;

    logger.log(
      '[HOME_LANGUAGE_REFRESH] old=$oldLang new=$newLang forceRefresh=true',
    );

    // Invalidate any older refresh immediately. The debounced request below
    // will create the next generation once the latest language settles.
    _feedGeneration++;
    _languageRefreshDebounce?.cancel();
    _languageRefreshDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || contentLanguagePreferenceNotifier.value != newLang) {
        return;
      }
      setState(() {
        _selectedMood = 'All';
        _initFutures(forceRefresh: true, source: 'language_change');
      });
    });
  }

  void _onCountryPreferenceChanged() {
    _feedGeneration++;
    _languageRefreshDebounce?.cancel();
    _languageRefreshDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _selectedMood = 'All';
        _initFutures(forceRefresh: true, source: 'country_change');
      });
    });
  }

  void _refreshHomeFeed() {
    if (!mounted) return;
    // This setting only changes local personalization sections.
    setState(_initFutures);
  }

  void _retryHomeFeed() {
    if (!mounted) return;
    setState(() {
      _initFutures(forceRefresh: true, source: 'retry');
    });
  }

  bool _isRefreshing = false;

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    final refreshGeneration = ++_feedGeneration;
    logger.log(
      '[HOME_REFRESH_REQUEST] source=pull_to_refresh bypass=true mode=sync',
    );

    try {
      await HapticFeedback.mediumImpact();
      final refreshedSections = await getUnifiedHomeFeed(
        forceRefresh: true,
        mood: _selectedMood,
        bypassRefreshDeduplication: true,
      );

      if (mounted && refreshGeneration == _feedGeneration) {
        setState(() {
          _homeFeedFuture = Future.value(refreshedSections);
        });
      }
    } catch (error, stackTrace) {
      logger.log(
        'Home feed pull-to-refresh failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted && refreshGeneration == _feedGeneration) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to refresh home feed')),
        );
      }
    } finally {
      _isRefreshing = false;
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _getGreetingAsset() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'assets/icons/Good-morning.svg';
    if (hour < 17) return 'assets/icons/Good-afternoon.svg';
    return 'assets/icons/Good-evening.svg';
  }

  @override
  Widget build(BuildContext context) {
    final playlistHeight = MediaQuery.sizeOf(context).height * 0.25 / 1.1;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 84,
        titleSpacing: AppTokens.pagePadding,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Catchify',
              style: TextStyle(
                fontFamily: 'paytoneOne',
                fontSize: 18,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.1,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              DateFormat('EEEE, d MMMM').format(DateTime.now()).toUpperCase(),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _getGreeting(),
              style: AppTextStyles.pageTitle.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Semantics(
              label: _getGreeting(),
              image: true,
              child: SvgPicture.asset(
                _getGreetingAsset(),
                width: 42,
                height: 42,
                colorFilter: ColorFilter.mode(
                  colorScheme.primary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ],
        centerTitle: false,
      ),

      body: RefreshIndicator.adaptive(
        onRefresh: _onRefresh,
        color: Theme.of(context).colorScheme.primary,
        notificationPredicate: (notification) =>
            notification.depth == 0 &&
            notification.metrics.axis == Axis.vertical,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<String?>(
                  valueListenable: announcementURL,
                  builder: (_, _url, __) {
                    if (_url == null) return const SizedBox.shrink();
                    final isSponsorshipAnnouncement =
                        isSponsorshipAnnouncementUrl(_url);
                    final message = isSponsorshipAnnouncement
                        ? (context.l10n?.sponsorProject ?? 'Sponsor Project')
                        : (context.l10n?.newAnnouncement ?? 'New Announcement');
                    final icon = isSponsorshipAnnouncement
                        ? FluentIcons.heart_24_filled
                        : FluentIcons.megaphone_24_filled;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: AnnouncementBox(
                        message: message,
                        url: _url,
                        icon: icon,
                        onDismiss: () async {
                          announcementURL.value = null;
                        },
                      ),
                    );
                  },
                ),
                _buildMoodChipsSection(context),
                AsyncLoader<List<HomeSection>>(
                  key: ValueKey(_feedGeneration),
                  future: _homeFeedFuture,
                  loadingWidget: _buildFeedSkeleton(context, playlistHeight),
                  errorBuilder: (context, error, stackTrace) =>
                      _buildFeedError(context, _retryHomeFeed),
                  builder: (context, sections) {
                    if (homeContentMs == null &&
                        appStartupStopwatch.isRunning) {
                      homeContentMs = appStartupStopwatch.elapsedMilliseconds;
                      checkAndLogColdStartPerf();
                    }
                    if (sections.isEmpty) {
                      return _buildFeedEmpty(context);
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final section in sections)
                          RepaintBoundary(
                            child: HomeSectionRenderer(
                              section: section,
                              playlistHeight: playlistHeight,
                            ),
                          ),
                        RepaintBoundary(
                          child: _buildFavoritesSection(playlistHeight),
                        ),
                        RepaintBoundary(
                          child: _buildCurrentMonthRecapSection(),
                        ),
                      ],
                    );
                  },
                ),
                const MiniPlayerBottomSpace(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoodChipsSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: AppTokens.itemSpacing),
      child: SizedBox(
        height: AppTokens.minInteractiveSize,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.pagePadding,
          ),
          itemCount: _moods.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppTokens.chipGap),
          itemBuilder: (context, index) {
            final mood = _moods[index];
            final isSelected = mood == _selectedMood;
            return Semantics(
              button: true,
              selected: isSelected,
              label: '$mood mood',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _onMoodSelected(mood),
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  child: AnimatedContainer(
                    duration: AppTokens.motionStandard,
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                colorScheme.primary,
                                colorScheme.primary.withValues(alpha: 0.82),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSelected
                          ? null
                          : colorScheme.surfaceContainerHighest.withValues(
                              alpha: 0.42,
                            ),
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary.withValues(alpha: 0.9)
                            : colorScheme.onSurface.withValues(alpha: 0.1),
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.28,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        mood,
                        style: AppTextStyles.chip.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeedSkeleton(BuildContext context, double playlistHeight) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShelfSkeleton(cardCount: 3),
          SizedBox(height: AppTokens.sectionGap),
          ShelfSkeleton(),
        ],
      ),
    );
  }

  Widget _buildFeedError(BuildContext context, VoidCallback? retry) {
    return ErrorState(title: 'Something went wrong', onRetry: retry);
  }

  Widget _buildFeedEmpty(BuildContext context) {
    return EmptyState(
      title: 'No music found',
      description: 'Explore or try selecting a different mood.',
      actionLabel: 'Refresh',
      onAction: _retryHomeFeed,
    );
  }

  Widget _buildFavoritesSection(double playlistHeight) {
    return ValueListenableBuilder<List<Map>>(
      valueListenable: userLikedPlaylists,
      builder: (_, likedPlaylists, __) {
        final filtered = likedPlaylists
            .where((playlist) => !isArtistPlaylist(playlist))
            .take(recommendedCubesNumber)
            .toList();
        if (filtered.isEmpty) return const SizedBox.shrink();

        final section = HomeSection(
          title: context.l10n?.backToFavorites ?? 'Back to favorites',
          subtitle: 'YOUR LIKED PLAYLISTS',
          type: HomeContentType.playlists,
          contents: filtered.map(Map<String, dynamic>.from).toList(),
        );

        return HomeSectionRenderer(
          section: section,
          playlistHeight: playlistHeight,
        );
      },
    );
  }

  Widget _buildCurrentMonthRecapSection() {
    return ValueListenableBuilder<bool>(
      valueListenable: wrappedEnabled,
      builder: (_, isEnabled, __) {
        if (!isEnabled) return const SizedBox.shrink();

        final currentMonthKey = listeningStatsMonthKey(DateTime.now());
        final monthStats = listeningStatsService.monthStats(currentMonthKey);
        final songs = listeningStatsService.monthTopSongs(currentMonthKey);
        final displayMinutes = monthDisplayMinutes(monthStats);
        if (displayMinutes <= 0 && songs.isEmpty) {
          return const SizedBox.shrink();
        }

        final previewSongs = songs.take(wrappedShareSongsLimit).toList();
        final periodLabel = formatMonthPeriodLabel(
          Localizations.localeOf(context),
          currentMonthKey,
        );

        return Column(
          children: [
            SectionHeader(
              title: context.l10n?.timeMachine ?? 'Time Machine',
              subtitle: 'LISTENING RECAP',
              icon: FluentIcons.data_trending_24_filled,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListeningRecapCard(
                periodLabel: periodLabel,
                minutes: displayMinutes,
                songs: previewSongs,
                onSongTap: (index) => _playRecapSongs(previewSongs, index),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => context.push('/home/timeMachine'),
                  icon: const Icon(FluentIcons.arrow_right_24_regular),
                  label: Text(
                    context.l10n?.listeningStats ?? 'Listening stats',
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _playRecapSongs(
    List<Map<String, dynamic>> songs,
    int index,
  ) async {
    if (songs.isEmpty) return;
    await audioHandler.playPlaylistSong(
      playlist: {
        'title': context.l10n?.timeMachine ?? 'Time Machine',
        'list': songs,
      },
      songIndex: index,
    );
  }
}
