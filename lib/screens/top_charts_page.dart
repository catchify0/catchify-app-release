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

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:catchify/constants/app_tokens.dart';
import 'package:catchify/main.dart';
import 'package:catchify/services/artwork_service.dart';
import 'package:catchify/services/playlists_manager.dart';
import 'package:catchify/services/router_service.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/theme/app_text_styles.dart';
import 'package:catchify/utilities/language_utils.dart';
import 'package:catchify/widgets/artist_card.dart';
import 'package:catchify/widgets/error_state.dart';
import 'package:catchify/widgets/loading_skeleton.dart';
import 'package:catchify/widgets/mini_player_bottom_space.dart';
import 'package:catchify/widgets/playlist_card.dart';
import 'package:catchify/widgets/section_header.dart';
import 'package:catchify/widgets/song_bar.dart';

class TopChartsPage extends StatefulWidget {
  const TopChartsPage({super.key});

  @override
  State<TopChartsPage> createState() => _TopChartsPageState();
}

class _TopChartsPageState extends State<TopChartsPage> {
  late Future<_ChartsData> _chartsDataFuture;
  String _selectedCategory = 'All';
  static const _categories = ['All', 'Top Songs', 'Playlists', 'Artists'];

  @override
  void initState() {
    super.initState();
    _loadCharts();
  }

  void _loadCharts({bool forceRefresh = false}) {
    _chartsDataFuture = _fetchChartsData(forceRefresh: forceRefresh);
  }

  Future<_ChartsData> _fetchChartsData({bool forceRefresh = false}) async {
    final results = await Future.wait([
      getTrendingSongsForYou(
        limit: 50,
        forceRefresh: forceRefresh,
      ).catchError((_) => <Map<String, dynamic>>[]),
      getTrendingCommunityPlaylists(
        forceRefresh: forceRefresh,
      ).catchError((_) => <Map<String, dynamic>>[]),
      getSuggestedArtists(
        forceRefresh: forceRefresh,
      ).catchError((_) => <Map<String, dynamic>>[]),
    ]);

    return _ChartsData(
      trendingSongs: results[0],
      trendingPlaylists: results[1],
      topArtists: results[2],
    );
  }

  Future<void> _onRefresh() async {
    setState(() {
      _loadCharts(forceRefresh: true);
    });
    await _chartsDataFuture;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentCountryCode = contentCountryPreference;
    final countryName = getCountryByCode(currentCountryCode).name;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppTokens.pagePadding,
        title: Row(
          children: [
            Icon(
              FluentIcons.arrow_trending_24_filled,
              color: colorScheme.primary,
              size: 26,
            ),
            const SizedBox(width: 10),
            Text(
              'Top Charts',
              style: AppTextStyles.pageTitle.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ActionChip(
              avatar: Icon(
                FluentIcons.globe_20_regular,
                size: 16,
                color: colorScheme.primary,
              ),
              label: Text(
                countryName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
              backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
              side: BorderSide(
                color: colorScheme.primary.withValues(alpha: 0.25),
                width: 0.8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              ),
              onPressed: () {
                context.push('/settings');
              },
            ),
          ),
        ],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: _onRefresh,
        color: colorScheme.primary,
        child: FutureBuilder<_ChartsData>(
          future: _chartsDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SingleChildScrollView(
                padding: EdgeInsets.symmetric(vertical: AppTokens.pagePadding),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTokens.pagePadding,
                      ),
                      child: SkeletonBox(
                        width: double.infinity,
                        height: 180,
                        borderRadius: BorderRadius.all(
                          Radius.circular(AppTokens.radiusCard),
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    SongRowSkeleton(),
                    SongRowSkeleton(),
                    SongRowSkeleton(),
                    SongRowSkeleton(),
                    SongRowSkeleton(),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: ErrorState(
                  message: 'Unable to load charts right now.',
                  onRetry: () =>
                      setState(() => _loadCharts(forceRefresh: true)),
                ),
              );
            }

            final data = snapshot.data;
            if (data == null ||
                (data.trendingSongs.isEmpty &&
                    data.trendingPlaylists.isEmpty &&
                    data.topArtists.isEmpty)) {
              return Center(
                child: ErrorState(
                  message: 'No charts data available for this region.',
                  onRetry: () =>
                      setState(() => _loadCharts(forceRefresh: true)),
                ),
              );
            }

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // Category Filter Chips
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.pagePadding,
                      vertical: 10,
                    ),
                    child: Row(
                      children: _categories.map((category) {
                        final isSelected = category == _selectedCategory;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(category),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedCategory = category;
                                });
                              }
                            },
                            labelStyle: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? colorScheme.onPrimary
                                  : colorScheme.onSurface,
                            ),
                            selectedColor: colorScheme.primary,
                            backgroundColor: colorScheme.surfaceContainerHigh,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusPill,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Featured #1 Trending Banner
                if ((_selectedCategory == 'All' ||
                        _selectedCategory == 'Top Songs') &&
                    data.trendingSongs.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.pagePadding,
                        vertical: 12,
                      ),
                      child: _HeroTrendingBanner(
                        topSong: data.trendingSongs.first,
                        allSongs: data.trendingSongs,
                        countryName: countryName,
                      ),
                    ),
                  ),

                // Top Songs Section
                if ((_selectedCategory == 'All' ||
                        _selectedCategory == 'Top Songs') &&
                    data.trendingSongs.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'Top 50 Songs',
                      subtitle: 'MOST STREAMED TODAY IN $countryName',
                      actionButton: TextButton.icon(
                        icon: const Icon(FluentIcons.play_20_filled, size: 18),
                        label: const Text('Play All'),
                        onPressed: () async {
                          await audioHandler.playPlaylistSong(
                            playlist: {
                              'title': 'Top Charts - $countryName',
                              'list': data.trendingSongs,
                            },
                            songIndex: 0,
                          );
                        },
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.pagePadding,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final song = data.trendingSongs[index];
                          final rank = index + 1;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                _RankBadge(rank: rank),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SongBar(
                                    song,
                                    true,
                                    key: ValueKey(song['ytid'] ?? index),
                                    backgroundColor: Colors.transparent,
                                    borderRadius: AppTokens.borderRadiusMedium,
                                    onPlay: () async {
                                      await audioHandler.playPlaylistSong(
                                        playlist: {
                                          'title': 'Top Charts - $countryName',
                                          'list': data.trendingSongs,
                                        },
                                        songIndex: index,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: _selectedCategory == 'All'
                            ? math.min(15, data.trendingSongs.length)
                            : data.trendingSongs.length,
                      ),
                    ),
                  ),
                ],

                // Trending Community Playlists Section
                if ((_selectedCategory == 'All' ||
                        _selectedCategory == 'Playlists') &&
                    data.trendingPlaylists.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppTokens.sectionGap),
                  ),
                  const SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'Trending Playlists',
                      subtitle: 'CURATED COMMUNITY CHARTS',
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: _getCardShelfHeight(
                        context,
                        AppTokens.playlistCardSize,
                      ),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.pagePadding,
                        ),
                        itemCount: data.trendingPlaylists.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: AppTokens.cardGap),
                        itemBuilder: (context, index) {
                          final playlist = data.trendingPlaylists[index];
                          return PlaylistCard(
                            playlist: playlist,
                            onTap: () => _openPlaylist(context, playlist),
                          );
                        },
                      ),
                    ),
                  ),
                ],

                // Top Artists Section
                if ((_selectedCategory == 'All' ||
                        _selectedCategory == 'Artists') &&
                    data.topArtists.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppTokens.sectionGap),
                  ),
                  const SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'Top Chart Artists',
                      subtitle: 'CHART-TOPPING CREATORS',
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: AppTokens.artistAvatarSize + 48,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.pagePadding,
                        ),
                        itemCount: data.topArtists.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: AppTokens.cardGap),
                        itemBuilder: (context, index) {
                          final artist = data.topArtists[index];
                          return ArtistCard(artist: artist);
                        },
                      ),
                    ),
                  ),
                ],

                const SliverToBoxAdapter(child: MiniPlayerBottomSpace()),
              ],
            );
          },
        ),
      ),
    );
  }

  double _getCardShelfHeight(BuildContext context, double cardSize) {
    final textScaler = MediaQuery.textScalerOf(context);
    final titleHeight = textScaler.scale(19);
    final subtitleHeight = textScaler.scale(17);
    return math.max(206, cardSize + 18 + titleHeight + subtitleHeight);
  }

  void _openPlaylist(BuildContext context, Map playlist) {
    final playlistId =
        playlist['ytid']?.toString() ?? playlist['id']?.toString();
    if (playlistId == null || playlistId.isEmpty || playlistId == 'null') {
      return;
    }
    if (isArtistPlaylist(playlist)) {
      context.push(
        '${NavigationManager.chartsPath}/artist/${Uri.encodeComponent(playlistId)}',
        extra: playlist,
      );
      return;
    }
    context.push(
      '${NavigationManager.chartsPath}/playlist/${Uri.encodeComponent(playlistId)}',
      extra: playlist,
    );
  }
}

class _ChartsData {
  const _ChartsData({
    required this.trendingSongs,
    required this.trendingPlaylists,
    required this.topArtists,
  });

  final List<Map<String, dynamic>> trendingSongs;
  final List<Map<String, dynamic>> trendingPlaylists;
  final List<Map<String, dynamic>> topArtists;
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color badgeColor;
    Color textColor;

    if (rank == 1) {
      badgeColor = const Color(0xFFFFD700); // Gold
      textColor = Colors.black;
    } else if (rank == 2) {
      badgeColor = const Color(0xFFC0C0C0); // Silver
      textColor = Colors.black;
    } else if (rank == 3) {
      badgeColor = const Color(0xFFCD7F32); // Bronze
      textColor = Colors.white;
    } else {
      badgeColor = theme.colorScheme.surfaceContainerHighest;
      textColor = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: rank <= 3 ? badgeColor : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: rank > 3
            ? Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                width: 0.8,
              )
            : null,
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          fontSize: 13,
          fontWeight: rank <= 3 ? FontWeight.w800 : FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _HeroTrendingBanner extends StatelessWidget {
  const _HeroTrendingBanner({
    required this.topSong,
    required this.allSongs,
    required this.countryName,
  });

  final Map<String, dynamic> topSong;
  final List<Map<String, dynamic>> allSongs;
  final String countryName;

  Future<void> _playTrack(BuildContext context, {bool shuffle = false}) async {
    final list = shuffle
        ? (List<Map<String, dynamic>>.from(allSongs)..shuffle())
        : allSongs;
    await audioHandler.playPlaylistSong(
      playlist: {'title': 'Top Charts - $countryName', 'list': list},
      songIndex: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final imageUrl = topSong['highResImage'] ?? topSong['image'];
    final rawUrl = (imageUrl ?? topSong['lowResImage'] ?? '').toString();
    final isHorizontal = ArtworkService.isYouTubeThumbnailUrl(rawUrl);
    final title = topSong['title']?.toString() ?? 'Trending Hit';
    final artist = topSong['artist']?.toString() ?? 'Top Artist';

    if (isHorizontal) {
      return _buildHorizontalBanner(
        context,
        colorScheme,
        imageUrl?.toString(),
        title,
        artist,
      );
    }
    return _buildSquareBanner(
      context,
      colorScheme,
      imageUrl?.toString(),
      title,
      artist,
    );
  }

  Widget _buildHorizontalBanner(
    BuildContext context,
    ColorScheme colorScheme,
    String? imageUrl,
    String title,
    String artist,
  ) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          color: colorScheme.surfaceContainerHigh,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image (16:9 widescreen)
            if (imageUrl != null && imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),

            // Deep gradient overlay for text legibility
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.88),
                  ],
                  stops: const [0.35, 1.0],
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildTrophyBadge(),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildButtonsRow(context, colorScheme, isCompact: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSquareBanner(
    BuildContext context,
    ColorScheme colorScheme,
    String? imageUrl,
    String title,
    String artist,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        color: colorScheme.surfaceContainerHigh,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Ambient blurred background from the square artwork
          if (imageUrl != null && imageUrl.isNotEmpty)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                child: Transform.scale(
                  scale: 1.15,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),

          // Dark wash overlay for contrast
          Positioned.fill(
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.62)),
          ),

          // Foreground Content: True 1:1 Square artwork + details
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // 1:1 Square Artwork
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 124,
                      height: 124,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (imageUrl != null && imageUrl.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => ColoredBox(
                                color: colorScheme.surfaceContainerHighest,
                                child: const Icon(
                                  FluentIcons.music_note_2_24_filled,
                                  size: 32,
                                  color: Colors.white70,
                                ),
                              ),
                            )
                          else
                            ColoredBox(
                              color: colorScheme.surfaceContainerHighest,
                              child: const Icon(
                                FluentIcons.music_note_2_24_filled,
                                size: 32,
                                color: Colors.white70,
                              ),
                            ),
                          // Subtle border highlight
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Info & Action Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTrophyBadge(),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildButtonsRow(context, colorScheme, isCompact: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrophyBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FluentIcons.trophy_16_filled, size: 13, color: Colors.black),
          SizedBox(width: 4),
          Text(
            '#1 IN TRENDING TODAY',
            style: TextStyle(
              color: Colors.black,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtonsRow(
    BuildContext context,
    ColorScheme colorScheme, {
    required bool isCompact,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 14 : 18,
              vertical: isCompact ? 8 : 10,
            ),
            minimumSize: Size(0, isCompact ? 34 : 38),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
            ),
          ),
          icon: const Icon(FluentIcons.play_20_filled, size: 16),
          label: Text(
            isCompact ? 'Play #1 Track' : 'Play #1 Track',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          onPressed: () => _playTrack(context),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white38),
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 10 : 14,
              vertical: isCompact ? 8 : 10,
            ),
            minimumSize: Size(0, isCompact ? 34 : 38),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
            ),
          ),
          icon: const Icon(FluentIcons.arrow_shuffle_20_regular, size: 16),
          label: const Text(
            'Shuffle',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          onPressed: () => _playTrack(context, shuffle: true),
        ),
      ],
    );
  }
}
