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

import 'dart:math' as math;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:catchify/constants/app_tokens.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart';
import 'package:catchify/models/home_section.dart';
import 'package:catchify/services/playlists_manager.dart';
import 'package:catchify/utilities/app_utils.dart';
import 'package:catchify/widgets/album_card.dart';
import 'package:catchify/widgets/artist_card.dart';
import 'package:catchify/widgets/playlist_card.dart';
import 'package:catchify/widgets/section_header.dart';
import 'package:catchify/widgets/song_bar.dart';
import 'package:catchify/widgets/song_card.dart';

/// Renders a dynamic home feed section using consistent, modern music shelves.
/// Eliminates distorted/squashed carousels and excessive decoration.
class HomeSectionRenderer extends StatelessWidget {
  const HomeSectionRenderer({
    super.key,
    required this.section,
    this.playlistHeight,
  });

  final HomeSection section;
  final double? playlistHeight;

  static const double kHomeHorizontalPadding = AppTokens.pagePadding;
  static const double kHomeCardSpacing = AppTokens.cardGap;
  static const double kHomeSectionSpacing = AppTokens.sectionGap;

  String _localizedTitle(BuildContext context) {
    final l10n = context.l10n;
    return switch (section.title.trim().toLowerCase()) {
      'quick picks' => l10n?.quickPicks ?? section.title,
      'trending songs for you' => l10n?.trendingSongsForYou ?? section.title,
      'featured playlists' => l10n?.featuredPlaylists ?? section.title,
      'trending community playlists' =>
        l10n?.trendingCommunityPlaylists ?? section.title,
      'new releases' => l10n?.newReleases ?? section.title,
      'artists for you' => l10n?.artistsForYou ?? section.title,
      _ => section.title,
    };
  }

  void _openPlaylist(BuildContext context, Map playlist) {
    final playlistId =
        playlist['ytid']?.toString() ?? playlist['id']?.toString();
    if (playlistId == null || playlistId.isEmpty || playlistId == 'null') {
      return;
    }
    if (isArtistPlaylist(playlist)) {
      context.push(
        '/home/artist/${Uri.encodeComponent(playlistId)}',
        extra: playlist,
      );
      return;
    }
    context.push(
      '/home/playlist/${Uri.encodeComponent(playlistId)}',
      extra: playlist,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (section.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.sizeOf(context).width;
    final showPlayAll =
        section.type == HomeContentType.songs && section.contents.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: _localizedTitle(context),
          subtitle: section.subtitle,
          padding: const EdgeInsets.fromLTRB(
            AppTokens.pagePadding,
            0,
            AppTokens.pagePadding,
            AppTokens.titleBottomGap,
          ),
          actionButton: showPlayAll
              ? IconButton(
                  onPressed: () async {
                    await audioHandler.playPlaylistSong(
                      playlist: {
                        'title': section.title,
                        'list': section.contents,
                      },
                      songIndex: 0,
                    );
                  },
                  tooltip: 'Play all',
                  icon: Icon(
                    FluentIcons.play_circle_24_filled,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                )
              : null,
        ),
        if (section.isChunkedSongs)
          _buildChunkedSongs(context, screenWidth)
        else
          switch (section.type) {
            HomeContentType.songs => _buildSongCards(context),
            HomeContentType.albums => _buildAlbumCards(context),
            HomeContentType.artists => _buildArtistCards(context),
            HomeContentType.playlists => _buildPlaylistCards(context),
            HomeContentType.mixed ||
            HomeContentType.unknown => _buildMixedCards(context),
          },
        const SizedBox(height: AppTokens.sectionGap),
      ],
    );
  }

  Widget _buildChunkedSongs(BuildContext context, double screenWidth) {
    final columnWidth = (screenWidth > 600)
        ? 380.0
        : (screenWidth - 44).clamp(280.0, 390.0);
    final chunkedSongs = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < section.contents.length; i += 4) {
      chunkedSongs.add(
        section.contents.sublist(i, math.min(i + 4, section.contents.length)),
      );
    }

    return SizedBox(
      height: chunkedSongs.map((c) => c.length).fold<int>(0, math.max) * 68.0,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        cacheExtent: 350,
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.pagePadding),
        itemCount: chunkedSongs.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppTokens.cardGap),
        itemBuilder: (context, colIndex) {
          final chunk = chunkedSongs[colIndex];
          return SizedBox(
            width: columnWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(chunk.length, (rowIndex) {
                final song = chunk[rowIndex];
                final globalIndex = colIndex * 4 + rowIndex;
                final ytid = song['ytid'];
                return RepaintBoundary(
                  key: listItemKey('home_dyn_chunk', globalIndex, song),
                  child: SongBar(
                    song,
                    true,
                    key: ValueKey(ytid ?? globalIndex),
                    backgroundColor: Colors.transparent,
                    barPadding: const EdgeInsetsDirectional.symmetric(
                      vertical: 7,
                      horizontal: 4,
                    ),
                    borderRadius: AppTokens.borderRadiusMedium,
                    onPlay: () async {
                      await audioHandler.playPlaylistSong(
                        playlist: {
                          'title': section.title,
                          'list': section.contents,
                        },
                        songIndex: globalIndex,
                      );
                    },
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }

  double _getCardShelfHeight(BuildContext context, double cardSize) {
    final textScaler = MediaQuery.textScalerOf(context);
    final titleHeight = textScaler.scale(19);
    final subtitleHeight = textScaler.scale(17);
    return math.max(206, cardSize + 18 + titleHeight + subtitleHeight);
  }

  double _getArtistShelfHeight(BuildContext context, double avatarSize) {
    final textScaler = MediaQuery.textScalerOf(context);
    final titleHeight = textScaler.scale(19);
    final subtitleHeight = textScaler.scale(16);
    return math.max(148, avatarSize + 26 + titleHeight + subtitleHeight);
  }

  Widget _buildSongCards(BuildContext context) {
    final shelfHeight = _getCardShelfHeight(context, AppTokens.songCardSize);
    return SizedBox(
      height: shelfHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        cacheExtent: 300,
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.pagePadding),
        itemCount: section.contents.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppTokens.cardGap),
        itemBuilder: (context, index) {
          final song = section.contents[index];
          final rank = song['chartRank'] as int?;
          return RepaintBoundary(
            key: listItemKey('home_dyn_song', index, song),
            child: SongCard(
              song: song,
              rank: rank,
              onTap: () async {
                await audioHandler.playPlaylistSong(
                  playlist: {'title': section.title, 'list': section.contents},
                  songIndex: index,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlbumCards(BuildContext context) {
    final shelfHeight = _getCardShelfHeight(context, AppTokens.albumCardSize);
    return SizedBox(
      height: shelfHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        cacheExtent: 300,
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.pagePadding),
        itemCount: section.contents.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppTokens.cardGap),
        itemBuilder: (context, index) {
          final album = section.contents[index];
          return RepaintBoundary(
            key: listItemKey('home_dyn_album', index, album),
            child: AlbumCard(
              album: album,
              onTap: () => _openPlaylist(context, album),
            ),
          );
        },
      ),
    );
  }

  Widget _buildArtistCards(BuildContext context) {
    final shelfHeight = _getArtistShelfHeight(
      context,
      AppTokens.artistAvatarSize,
    );
    return SizedBox(
      height: shelfHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        cacheExtent: 300,
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.pagePadding),
        itemCount: section.contents.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppTokens.cardGap),
        itemBuilder: (context, index) {
          final artist = section.contents[index];
          return RepaintBoundary(
            key: listItemKey('home_dyn_artist', index, artist),
            child: ArtistCard(artist: artist),
          );
        },
      ),
    );
  }

  Widget _buildPlaylistCards(BuildContext context) {
    final items = section.contents;
    final shelfHeight = _getCardShelfHeight(
      context,
      AppTokens.playlistCardSize,
    );

    return SizedBox(
      height: shelfHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        cacheExtent: 300,
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.pagePadding),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppTokens.cardGap),
        itemBuilder: (context, index) {
          final item = items[index];
          return RepaintBoundary(
            key: listItemKey('home_dyn_pl_item', index, item),
            child: PlaylistCard(
              playlist: item,
              onTap: () => _openPlaylist(context, item),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMixedCards(BuildContext context) {
    final shelfHeight = _getCardShelfHeight(
      context,
      AppTokens.playlistCardSize,
    );
    return SizedBox(
      height: shelfHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        cacheExtent: 300,
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.pagePadding),
        itemCount: section.contents.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppTokens.cardGap),
        itemBuilder: (context, index) {
          final item = section.contents[index];
          final contentType = item['contentType'] as String? ?? '';

          if (contentType == 'artist' || item['isArtist'] == true) {
            return RepaintBoundary(
              key: listItemKey('home_dyn_mix_art', index, item),
              child: Center(child: ArtistCard(artist: item)),
            );
          } else if (contentType == 'album' || item['isAlbum'] == true) {
            return RepaintBoundary(
              key: listItemKey('home_dyn_mix_alb', index, item),
              child: AlbumCard(
                album: item,
                onTap: () => _openPlaylist(context, item),
              ),
            );
          } else if (contentType == 'playlist' ||
              item['source'] == 'youtube-music-playlist') {
            return RepaintBoundary(
              key: listItemKey('home_dyn_mix_pl', index, item),
              child: PlaylistCard(
                playlist: item,
                onTap: () => _openPlaylist(context, item),
              ),
            );
          } else {
            return RepaintBoundary(
              key: listItemKey('home_dyn_mix_sng', index, item),
              child: SongCard(
                song: item,
                onTap: () async {
                  await audioHandler.playPlaylistSong(
                    playlist: {
                      'title': section.title,
                      'list': section.contents,
                    },
                    songIndex: index,
                  );
                },
              ),
            );
          }
        },
      ),
    );
  }
}
