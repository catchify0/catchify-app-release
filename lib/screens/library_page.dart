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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:catchify/constants/app_constants.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart' show logger;
import 'package:catchify/services/common_services.dart';
import 'package:catchify/services/library_service.dart';
import 'package:catchify/services/playlist_download_service.dart';
import 'package:catchify/services/playlists_manager.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/app_utils.dart';
import 'package:catchify/utilities/flutter_toast.dart';
import 'package:catchify/utilities/offline_playlist_dialogs.dart';
import 'package:catchify/utilities/playlist_dialogs.dart';
import 'package:catchify/constants/app_tokens.dart';
import 'package:catchify/widgets/confirmation_dialog.dart';
import 'package:catchify/widgets/empty_state.dart';
import 'package:catchify/widgets/mini_player_bottom_space.dart';
import 'package:catchify/widgets/playlist_bar.dart';
import 'package:catchify/widgets/section_header.dart';
import 'package:catchify/widgets/song_bar.dart';

enum LibraryFilter { all, likedSongs, playlists, recent, downloads }

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  LibraryFilter _selectedFilter = LibraryFilter.all;

  String _filterLabel(LibraryFilter filter, BuildContext context) {
    return switch (filter) {
      LibraryFilter.all => 'All',
      LibraryFilter.likedSongs => context.l10n?.likedSongs ?? 'Liked Songs',
      LibraryFilter.playlists => context.l10n?.customPlaylists ?? 'Playlists',
      LibraryFilter.recent => context.l10n?.recentlyPlayed ?? 'Recent',
      LibraryFilter.downloads => context.l10n?.offlineSongs ?? 'Downloads',
    };
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = offlineMode.value;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n?.library ?? 'Library')),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          userLikedSongsList,
          userRecentlyPlayed,
          userOfflineSongs,
          userLocalSongs,
          userPlaylists,
          userCustomPlaylists,
          userLikedPlaylists,
          userPlaylistFolders,
          offlinePlaylistService.offlinePlaylists,
          pinnedPlaylistIds,
          offlineMode,
        ]),
        builder: (context, _) {
          final likedSongs = LibraryService.instance.loadLikedSongs();
          final playlistsData = LibraryService.instance.loadPlaylists(
            isOffline: isOffline,
          );
          final folders = playlistsData['folders'] ?? [];
          final customPlaylists = playlistsData['customPlaylists'] ?? [];
          final likedPlaylists = playlistsData['likedPlaylists'] ?? [];
          final offlinePlaylists = playlistsData['offlinePlaylists'] ?? [];
          final recents = LibraryService.instance.loadRecentlyPlayed();
          final downloads = LibraryService.instance.loadDownloads();
          final offlineSongs = downloads['offlineSongs'] as List? ?? [];
          final localSongs = downloads['localSongs'] as List? ?? [];

          // Offline mode screen when no local content exists
          if (isOffline) {
            final hasLocalContent =
                offlineSongs.isNotEmpty ||
                localSongs.isNotEmpty ||
                offlinePlaylists.isNotEmpty ||
                customPlaylists.isNotEmpty ||
                folders.isNotEmpty;

            if (!hasLocalContent) {
              return _buildOfflineEmptyState(context);
            }
          }

          final hasLiked = likedSongs.isNotEmpty;
          final hasPlaylists =
              folders.isNotEmpty ||
              customPlaylists.isNotEmpty ||
              likedPlaylists.isNotEmpty ||
              offlinePlaylists.isNotEmpty;
          final hasRecents = recents.isNotEmpty;
          final hasDownloads =
              offlineSongs.isNotEmpty ||
              localSongs.isNotEmpty ||
              offlinePlaylists.isNotEmpty;

          final totalLibraryItems =
              (hasLiked ? 1 : 0) +
              (hasPlaylists ? 1 : 0) +
              (hasRecents ? 1 : 0) +
              (hasDownloads ? 1 : 0);

          return Column(
            children: [
              _buildFilterChips(context),
              Expanded(
                child: Padding(
                  padding: commonSingleChildScrollViewPadding,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      if (totalLibraryItems == 0 &&
                          _selectedFilter == LibraryFilter.all)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyState(
                            context,
                            icon: FluentIcons.library_24_regular,
                            title: 'Your library is empty',
                            subtitle:
                                'Songs and playlists you like will appear here.',
                          ),
                        )
                      else ...[
                        // Pinned playlists section (only in All or Playlists mode)
                        if (_selectedFilter == LibraryFilter.all ||
                            _selectedFilter == LibraryFilter.playlists)
                          ..._buildPinnedSlivers(),

                        // Liked songs section
                        if (_selectedFilter == LibraryFilter.all && hasLiked)
                          ..._buildLikedSongsPreviewSlivers(context, likedSongs)
                        else if (_selectedFilter == LibraryFilter.likedSongs)
                          if (hasLiked)
                            ..._buildLikedSongsFullSlivers(context, likedSongs)
                          else
                            _buildSingleEmptySliver(
                              context,
                              icon: FluentIcons.heart_24_regular,
                              title: 'No liked songs yet',
                              subtitle:
                                  'Tap the heart on any song to save it to your library.',
                            ),

                        // Playlists section
                        if (_selectedFilter == LibraryFilter.all &&
                            hasPlaylists)
                          ..._buildPlaylistsPreviewSlivers(
                            context,
                            folders: folders,
                            customPlaylists: customPlaylists,
                            likedPlaylists: likedPlaylists,
                            offlinePlaylists: offlinePlaylists,
                          )
                        else if (_selectedFilter == LibraryFilter.playlists)
                          if (hasPlaylists)
                            ..._buildPlaylistsFullSlivers(
                              context,
                              folders: folders,
                              customPlaylists: customPlaylists,
                              likedPlaylists: likedPlaylists,
                              offlinePlaylists: offlinePlaylists,
                            )
                          else
                            _buildSingleEmptySliver(
                              context,
                              icon: FluentIcons.text_bullet_list_24_regular,
                              title: 'No playlists created yet',
                              subtitle:
                                  'Create a playlist or like playlists to organize your music.',
                            ),

                        // Recently Played section
                        if (_selectedFilter == LibraryFilter.all && hasRecents)
                          ..._buildRecentlyPlayedPreviewSlivers(
                            context,
                            recents,
                          )
                        else if (_selectedFilter == LibraryFilter.recent)
                          if (hasRecents)
                            ..._buildRecentlyPlayedFullSlivers(context, recents)
                          else
                            _buildSingleEmptySliver(
                              context,
                              icon: FluentIcons.history_24_regular,
                              title: 'No listening history',
                              subtitle:
                                  'Tracks you play will be saved in your listening history.',
                            ),

                        // Downloads / Offline section
                        if (_selectedFilter == LibraryFilter.all &&
                            hasDownloads)
                          ..._buildDownloadsPreviewSlivers(
                            context,
                            offlineSongs: offlineSongs,
                            localSongs: localSongs,
                            offlinePlaylists: offlinePlaylists,
                          )
                        else if (_selectedFilter == LibraryFilter.downloads)
                          if (hasDownloads)
                            ..._buildDownloadsFullSlivers(
                              context,
                              offlineSongs: offlineSongs,
                              localSongs: localSongs,
                              offlinePlaylists: offlinePlaylists,
                            )
                          else
                            _buildSingleEmptySliver(
                              context,
                              icon: FluentIcons.cloud_off_24_regular,
                              title: 'No downloaded content',
                              subtitle:
                                  'Download songs or playlists to listen without an internet connection.',
                            ),
                      ],
                      const SliverMiniPlayerBottomSpace(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const filters = LibraryFilter.values;
    final scaledChipHeight = MediaQuery.textScalerOf(
      context,
    ).scale(AppTokens.chipHeight);
    final chipStripHeight = scaledChipHeight.clamp(
      AppTokens.minInteractiveSize,
      64.0,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      child: SizedBox(
        height: chipStripHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final filter = filters[index];
            final isSelected = filter == _selectedFilter;
            return Semantics(
              button: true,
              selected: isSelected,
              label: _filterLabel(filter, context),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (_selectedFilter != filter) {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedFilter = filter;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
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
                        _filterLabel(filter, context),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          letterSpacing: -0.2,
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

  // --- PINNED PLAYLISTS ---
  List<Widget> _buildPinnedSlivers() {
    final ids = pinnedPlaylistIds.value;
    if (ids.isEmpty) return [];

    final isOff = offlineMode.value;
    final items = resolvePinnedPlaylists(ids).where((p) {
      return !isOff ||
          offlinePlaylistService.isPlaylistDownloaded(
            p['ytid']?.toString() ?? '',
          );
    }).toList();

    if (items.isEmpty) return [];

    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          title: context.l10n?.pinnedPlaylists ?? 'Pinned Playlists',
          icon: FluentIcons.pin_24_filled,
        ),
      ),
      _buildSliverPlaylistList(items),
    ];
  }

  // --- LIKED SONGS ---
  List<Widget> _buildLikedSongsPreviewSlivers(
    BuildContext context,
    List<dynamic> likedSongs,
  ) {
    return [
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: context.l10n?.likedSongs ?? 'Liked Songs',
              icon: FluentIcons.heart_24_filled,
              actionButton: TextButton(
                onPressed: () => context.push('/library/userSongs/liked'),
                child: const Text('See all'),
              ),
            ),
            _buildLikedSongsHeroCard(context, likedSongs),
            const SizedBox(height: 8),
          ],
        ),
      ),
      SliverList.builder(
        itemCount: likedSongs.length > 3 ? 3 : likedSongs.length,
        itemBuilder: (context, index) {
          final song = likedSongs[index];
          final borderRadius = getItemBorderRadius(
            index,
            likedSongs.length > 3 ? 3 : likedSongs.length,
          );
          return SongBar(
            song,
            false,
            key: listItemKey('lib_liked', index, song),
            isFromLikedSongs: true,
            showMusicDuration: true,
            borderRadius: borderRadius,
            onPlay: () => LibraryService.instance.playSong(song),
          );
        },
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
    ];
  }

  List<Widget> _buildLikedSongsFullSlivers(
    BuildContext context,
    List<dynamic> likedSongs,
  ) {
    return [
      SliverToBoxAdapter(
        child: Column(
          children: [
            SectionHeader(
              title: context.l10n?.likedSongs ?? 'Liked Songs',
              icon: FluentIcons.heart_24_filled,
            ),
            _buildLikedSongsHeroCard(context, likedSongs),
            const SizedBox(height: 12),
          ],
        ),
      ),
      SliverList.builder(
        itemCount: likedSongs.length,
        itemBuilder: (context, index) {
          final song = likedSongs[index];
          final borderRadius = getItemBorderRadius(index, likedSongs.length);
          return SongBar(
            song,
            false,
            key: listItemKey('lib_liked_full', index, song),
            isFromLikedSongs: true,
            showMusicDuration: true,
            borderRadius: borderRadius,
            onPlay: () => LibraryService.instance.playSong(song),
          );
        },
      ),
    ];
  }

  Widget _buildLikedSongsHeroCard(BuildContext context, List<dynamic> songs) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.2),
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary,
                  colorScheme.primary.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              FluentIcons.heart_24_filled,
              color: colorScheme.onPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n?.likedSongs ?? 'Liked Songs',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${songs.length} ${songs.length == 1 ? "song" : "songs"}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            icon: const Icon(FluentIcons.arrow_shuffle_20_filled),
            iconSize: 20,
            tooltip: context.l10n?.shuffle ?? 'Shuffle',
            onPressed: () => LibraryService.instance.playAll(
              songs,
              title: context.l10n?.likedSongs ?? 'Liked Songs',
              shuffle: true,
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            icon: const Icon(FluentIcons.play_20_filled),
            iconSize: 20,
            tooltip: context.l10n?.play ?? 'Play',
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              disabledBackgroundColor: colorScheme.surfaceContainerHighest,
              disabledForegroundColor: colorScheme.onSurfaceVariant,
            ),
            onPressed: () => LibraryService.instance.playAll(
              songs,
              title: context.l10n?.likedSongs ?? 'Liked Songs',
            ),
          ),
        ],
      ),
    );
  }

  // --- PLAYLISTS ---
  List<Widget> _buildPlaylistsPreviewSlivers(
    BuildContext context, {
    required List folders,
    required List customPlaylists,
    required List likedPlaylists,
    required List offlinePlaylists,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOff = offlineMode.value;

    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          title: context.l10n?.customPlaylists ?? 'Playlists',
          icon: FluentIcons.library_24_filled,
          actionButton: isOff
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      onPressed: _showCreateFolderDialog,
                      icon: Icon(
                        FluentIcons.folder_add_24_regular,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      tooltip: context.l10n?.createFolder ?? 'Create folder',
                    ),
                    IconButton(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      onPressed: () => showCreatePlaylistDialog(context),
                      icon: Icon(
                        FluentIcons.add_24_regular,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      tooltip: 'Create playlist',
                    ),
                  ],
                ),
        ),
      ),
      if (folders.isNotEmpty)
        _buildFolderSliverList(folders, customPlaylists.isNotEmpty),
      if (customPlaylists.isNotEmpty)
        _buildSliverPlaylistList(
          customPlaylists,
          hasItemsBefore: folders.isNotEmpty,
          hasItemsAfter:
              likedPlaylists.isNotEmpty || offlinePlaylists.isNotEmpty,
        ),
      if (!isOff && likedPlaylists.isNotEmpty)
        _buildSliverPlaylistList(
          likedPlaylists,
          hasItemsBefore: folders.isNotEmpty || customPlaylists.isNotEmpty,
          hasItemsAfter: offlinePlaylists.isNotEmpty,
        ),
      if (offlinePlaylists.isNotEmpty)
        _buildSliverPlaylistList(
          offlinePlaylists,
          isOfflinePlaylists: true,
          hasItemsBefore:
              folders.isNotEmpty ||
              customPlaylists.isNotEmpty ||
              likedPlaylists.isNotEmpty,
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
    ];
  }

  List<Widget> _buildPlaylistsFullSlivers(
    BuildContext context, {
    required List folders,
    required List customPlaylists,
    required List likedPlaylists,
    required List offlinePlaylists,
  }) {
    return _buildPlaylistsPreviewSlivers(
      context,
      folders: folders,
      customPlaylists: customPlaylists,
      likedPlaylists: likedPlaylists,
      offlinePlaylists: offlinePlaylists,
    );
  }

  // --- RECENTLY PLAYED ---
  List<Widget> _buildRecentlyPlayedPreviewSlivers(
    BuildContext context,
    List<dynamic> recents,
  ) {
    return [
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: context.l10n?.recentlyPlayed ?? 'Recently Played',
              icon: FluentIcons.history_24_regular,
              actionButton: TextButton(
                onPressed: () => context.push('/library/userSongs/recents'),
                child: const Text('See all'),
              ),
            ),
          ],
        ),
      ),
      SliverList.builder(
        itemCount: recents.length > 3 ? 3 : recents.length,
        itemBuilder: (context, index) {
          final song = recents[index];
          final borderRadius = getItemBorderRadius(
            index,
            recents.length > 3 ? 3 : recents.length,
          );
          return SongBar(
            song,
            false,
            key: listItemKey('lib_recent', index, song),
            isRecentSong: true,
            showMusicDuration: true,
            borderRadius: borderRadius,
            onPlay: () => LibraryService.instance.playSong(song),
          );
        },
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
    ];
  }

  List<Widget> _buildRecentlyPlayedFullSlivers(
    BuildContext context,
    List<dynamic> recents,
  ) {
    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          title: context.l10n?.recentlyPlayed ?? 'Recently Played',
          icon: FluentIcons.history_24_regular,
        ),
      ),
      SliverList.builder(
        itemCount: recents.length,
        itemBuilder: (context, index) {
          final song = recents[index];
          final borderRadius = getItemBorderRadius(index, recents.length);
          return SongBar(
            song,
            false,
            key: listItemKey('lib_recent_full', index, song),
            isRecentSong: true,
            showMusicDuration: true,
            borderRadius: borderRadius,
            onPlay: () => LibraryService.instance.playSong(song),
          );
        },
      ),
    ];
  }

  // --- DOWNLOADS & OFFLINE ---
  List<Widget> _buildDownloadsPreviewSlivers(
    BuildContext context, {
    required List offlineSongs,
    required List localSongs,
    required List offlinePlaylists,
  }) {
    return [
      SliverToBoxAdapter(
        child: Column(
          children: [
            SectionHeader(
              title: context.l10n?.offlineSongs ?? 'Downloads & Offline',
              icon: FluentIcons.cloud_off_24_filled,
            ),
            PlaylistBar(
              context.l10n?.offlineSongs ?? 'Offline songs',
              onPressed: () => context.push('/library/userSongs/offline'),
              cubeIcon: FluentIcons.cloud_off_24_regular,
              borderRadius: commonCustomBarRadiusFirst,
              showBuildActions: false,
            ),
            PlaylistBar(
              Localizations.localeOf(context).languageCode == 'ta'
                  ? 'உள்ளகப் பாடல்கள்'
                  : 'Local songs',
              onPressed: () => context.push('/library/userSongs/local'),
              cubeIcon: FluentIcons.music_note_2_24_regular,
              borderRadius: offlinePlaylists.isEmpty
                  ? commonCustomBarRadiusLast
                  : BorderRadius.zero,
              showBuildActions: false,
            ),
          ],
        ),
      ),
      if (offlinePlaylists.isNotEmpty)
        _buildSliverPlaylistList(
          offlinePlaylists,
          isOfflinePlaylists: true,
          hasItemsBefore: true,
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
    ];
  }

  List<Widget> _buildDownloadsFullSlivers(
    BuildContext context, {
    required List offlineSongs,
    required List localSongs,
    required List offlinePlaylists,
  }) {
    return _buildDownloadsPreviewSlivers(
      context,
      offlineSongs: offlineSongs,
      localSongs: localSongs,
      offlinePlaylists: offlinePlaylists,
    );
  }

  // --- PLAYLIST LIST UTILITIES ---
  Widget _buildSliverPlaylistList(
    List playlists, {
    bool isOfflinePlaylists = false,
    bool hasItemsAfter = false,
    bool hasItemsBefore = false,
  }) {
    return SliverPadding(
      padding: hasItemsAfter ? EdgeInsets.zero : commonListViewBottomPadding,
      sliver: SliverList.builder(
        itemCount: playlists.length,
        itemBuilder: (BuildContext context, index) {
          final playlist = playlists[index];
          final isArtist = playlist['source']?.toString() == 'youtube-artist';
          final borderRadius = getItemBorderRadius(
            index,
            playlists.length,
            hasItemsBefore: hasItemsBefore,
            hasItemsAfter: hasItemsAfter,
          );
          return PlaylistBar(
            key: listItemKey('library_playlist', index, playlist),
            playlist['title'],
            playlistId: playlist['ytid'],
            playlistArtwork: playlist['highResImage'] ?? playlist['image'],
            cubeIcon: isArtist
                ? FluentIcons.person_24_filled
                : FluentIcons.text_bullet_list_24_filled,
            isAlbum: isArtist ? false : playlist['isAlbum'],
            playlistData: playlist,
            onDelete:
                playlist['source'] == 'user-created' ||
                    playlist['source'] == 'user-youtube' ||
                    isOfflinePlaylists
                ? () => isOfflinePlaylists
                      ? _showRemoveOfflinePlaylistDialog(playlist)
                      : _showRemovePlaylistDialog(playlist)
                : null,
            borderRadius: borderRadius,
          );
        },
      ),
    );
  }

  Widget _buildFolderSliverList(List folders, bool hasPlaylistsAfter) {
    return SliverList.builder(
      itemCount: folders.length,
      itemBuilder: (BuildContext context, index) {
        final folder = folders[index];
        final isLastFolder = index == folders.length - 1;
        final borderRadius = isLastFolder && !hasPlaylistsAfter
            ? commonCustomBarRadiusLast
            : BorderRadius.zero;
        return PlaylistBar(
          folder['name'],
          playlistData: folder,
          borderRadius: borderRadius,
          onDelete: () => _showDeleteFolderDialog(folder),
        );
      },
    );
  }

  // --- EMPTY STATES ---
  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return EmptyState(icon: icon, title: title, description: subtitle);
  }

  Widget _buildSingleEmptySliver(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return SliverEmptyState(icon: icon, title: title, description: subtitle);
  }

  Widget _buildOfflineEmptyState(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n?.library ?? 'Library')),
      body: Center(
        child: EmptyState(
          icon: FluentIcons.cloud_off_24_regular,
          title: context.l10n!.offlineMode,
          description: context.l10n!.noOfflineLibraryContent,
        ),
      ),
    );
  }

  // --- DIALOGS ---
  void _showRemoveOfflinePlaylistDialog(Map playlist) {
    final playlistId = playlist['ytid']?.toString() ?? '';
    if (playlistId.isEmpty) return;
    showRemoveOfflinePlaylistDialog(context, playlistId);
  }

  void _showRemovePlaylistDialog(Map playlist) => showDialog(
    context: context,
    builder: (BuildContext context) {
      return ConfirmationDialog(
        confirmationMessage: context.l10n!.removePlaylistQuestion,
        submitMessage: context.l10n!.remove,
        onCancel: () {
          Navigator.of(context).pop();
        },
        onSubmit: () {
          Navigator.of(context).pop();

          final playlistId = playlist['ytid']?.toString() ?? '';

          if (playlistId.isEmpty) {
            logger.log('Playlist ID is missing, cannot remove playlist.');
            showToast(context, context.l10n!.error);
            return;
          }

          removeUserPlaylistEntry(playlist);
          if (offlinePlaylistService.isPlaylistDownloaded(playlistId)) {
            unawaited(offlinePlaylistService.removeOfflinePlaylist(playlistId));
          }
        },
      );
    },
  );

  void _showCreateFolderDialog() => showDialog(
    context: context,
    builder: (BuildContext context) {
      var folderName = '';
      final colorScheme = Theme.of(context).colorScheme;

      return AlertDialog(
        icon: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            FluentIcons.folder_add_24_regular,
            color: colorScheme.primary,
            size: 32,
          ),
        ),
        title: Text(
          context.l10n!.createFolder,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          decoration: InputDecoration(
            labelText: context.l10n!.folderName,
            hintText: context.l10n!.newFolder,
            prefixIcon: Icon(
              FluentIcons.folder_20_regular,
              color: colorScheme.onSurfaceVariant,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: colorScheme.surfaceContainerLow,
          ),
          onChanged: (value) {
            folderName = value;
          },
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: <Widget>[
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: colorScheme.outline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(context.l10n!.cancel),
          ),
          FilledButton.icon(
            onPressed: () {
              if (folderName.trim().isNotEmpty) {
                final result = createPlaylistFolder(folderName.trim(), context);
                showToast(context, result);
              } else {
                showToast(context, context.l10n!.enterFolderName);
              }
              Navigator.pop(context);
            },
            icon: const Icon(FluentIcons.add_20_regular),
            label: Text(context.l10n!.create),
          ),
        ],
      );
    },
  );

  void _showDeleteFolderDialog(Map folder) => showDialog(
    context: context,
    builder: (BuildContext context) {
      return ConfirmationDialog(
        confirmationMessage: context.l10n!.deleteFolderQuestion,
        submitMessage: context.l10n!.delete,
        onCancel: () {
          Navigator.of(context).pop();
        },
        onSubmit: () {
          final result = deletePlaylistFolder(folder['id'], context);
          Navigator.of(context).pop();
          showToast(context, result);
        },
      );
    },
  );
}
