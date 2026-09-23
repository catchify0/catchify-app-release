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

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:catchify/constants/app_tokens.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart';
import 'package:catchify/services/common_services.dart';
import 'package:catchify/utilities/flutter_toast.dart';
import 'package:catchify/utilities/mediaitem.dart';
import 'package:catchify/utilities/async_loader.dart';
import 'package:catchify/widgets/lyrics_display_widget.dart';
import 'package:catchify/widgets/now_playing/bottom_actions_row.dart';
import 'package:catchify/widgets/now_playing/now_playing_artwork.dart';
import 'package:catchify/widgets/now_playing/now_playing_controls.dart';
import 'package:catchify/widgets/playback_icon_button.dart';
import 'package:catchify/widgets/position_slider.dart';
import 'package:catchify/widgets/queue_list_view.dart';
import 'package:catchify/widgets/song_artwork.dart';

/// Now Playing page — hosts the normal artwork/controls view and the
/// compact in-page lyrics mode without pushing a separate route.
class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  bool _showLyrics = false;
  Future<String?>? _lyricsFuture;
  String? _lyricsKey;

  String _songKey(MediaItem metadata) =>
      metadata.id.isNotEmpty
          ? metadata.id
          : '${metadata.artist ?? ''} - ${metadata.title}';

  void _loadLyrics(MediaItem metadata) {
    final key = _songKey(metadata);
    if (key == _lyricsKey) return;

    _lyricsKey = key;
    final ytid =
        metadata.extras?['ytid']?.toString() ??
        (metadata.id.isNotEmpty ? metadata.id : null);
    _lyricsFuture = getSongLyrics(
      metadata.artist,
      metadata.title,
      duration: metadata.duration?.inSeconds,
      ytid: ytid,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLargeScreen = size.width > 800 && size.height > 600;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = size.width;
    final baseIconSize = screenWidth < 360
        ? 36.0
        : screenWidth < 400
        ? 40.0
        : 44.0;
    final miniIconSize = screenWidth < 360 ? 18.0 : 22.0;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: StreamBuilder<MediaItem?>(
          stream: audioHandler.mediaItem,
          builder: (context, snapshot) {
            if (snapshot.data == null || !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final metadata = snapshot.data!;

            return Stack(
              children: [
                // Keep the lyrics mode inside NowPlayingPage and slide it
                // into place instead of fading between separate surfaces.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.035),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                    child: child,
                  ),
                  child: _showLyrics
                      ? _buildLyricsView(
                          key: const ValueKey('lyrics'),
                          metadata: metadata,
                        )
                      : Column(
                          key: const ValueKey('normal'),
                          children: [
                            _buildAppBar(context, colorScheme, metadata),
                            Expanded(
                              child: isLargeScreen
                                  ? _DesktopLayout(
                                      metadata: metadata,
                                      size: size,
                                      adjustedIconSize: baseIconSize,
                                      adjustedMiniIconSize: miniIconSize,
                                      onLyricsTap: () => setState(
                                            () => _showLyrics = true,
                                          ),
                                    )
                                  : _MobileLayout(
                                      metadata: metadata,
                                      size: size,
                                      adjustedIconSize: baseIconSize,
                                      adjustedMiniIconSize: miniIconSize,
                                      isLargeScreen: isLargeScreen,
                                      onLyricsTap: () => setState(
                                            () => _showLyrics = true,
                                          ),
                                    ),
                            ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLyricsView({
    required Key key,
    required MediaItem metadata,
  }) {
    _loadLyrics(metadata);
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final future = _lyricsFuture;
    final songId =
        metadata.extras?['ytid']?.toString() ??
        (metadata.id.isNotEmpty ? metadata.id : null);

    return Column(
      key: key,
      children: [
        _buildLyricsHeader(context, colorScheme, metadata),
        Expanded(
          child: future == null
              ? const Center(child: CircularProgressIndicator())
              : AsyncLoader<String?>(
                  key: ValueKey(_lyricsKey),
                  future: future,
                  emptyWidget: _buildLyricsUnavailable(colorScheme),
                  errorBuilder: (_, __, ___) =>
                      _buildLyricsUnavailable(colorScheme),
                  builder: (context, lyrics) {
                    if (lyrics == null || lyrics.isEmpty) {
                      return _buildLyricsUnavailable(colorScheme);
                    }
                    return LyricsDisplayWidget(
                      key: ValueKey(songId ?? metadata.id),
                      lyrics: lyrics,
                      positionDataStream: audioHandler.positionDataStream,
                      songId: songId,
                    );
                  },
                ),
        ),
        _buildLyricsMiniControls(colorScheme, size),
      ],
    );
  }

  Widget _buildLyricsHeader(
    BuildContext context,
    ColorScheme colorScheme,
    MediaItem metadata,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(FluentIcons.chevron_down_24_regular),
                tooltip: 'Close lyrics',
                onPressed: () => setState(() => _showLyrics = false),
              ),
              const SizedBox(width: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SongArtworkWidget(
                  metadata: metadata,
                  size: 58,
                  borderRadius: 10,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metadata.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (metadata.artist != null && metadata.artist!.isNotEmpty)
                      Text(
                        metadata.artist!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsUnavailable(ColorScheme colorScheme) {
    return Center(
      child: Text(
        context.l10n?.lyricsNotAvailable ?? 'Lyrics not available',
        style: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.55),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildLyricsMiniControls(ColorScheme colorScheme, Size size) {
    final miniSize = size.width < 360 ? 20.0 : 22.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.94),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PositionSlider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: miniSize,
                icon: const Icon(FluentIcons.previous_24_filled),
                onPressed: audioHandler.skipToPrevious,
              ),
              const SizedBox(width: 16),
              buildPlaybackIconButton(
                size.width < 360 ? 36 : 40,
                colorScheme.onPrimaryContainer,
                colorScheme.primaryContainer,
              ),
              const SizedBox(width: 16),
              IconButton(
                iconSize: miniSize,
                icon: const Icon(FluentIcons.next_24_filled),
                onPressed: audioHandler.skipToNext,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    ColorScheme colorScheme,
    MediaItem metadata,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.42),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
          IconButton(
            iconSize: 24,
            icon: const Icon(FluentIcons.chevron_down_24_regular),
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHigh.withValues(
                alpha: 0.8,
              ),
              foregroundColor: colorScheme.onSurfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(10),
              minimumSize: const Size(
                AppTokens.minInteractiveSize,
                AppTokens.minInteractiveSize,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'NOW PLAYING',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          IconButton(
            iconSize: 22,
            icon: const Icon(Icons.radio),
            tooltip: context.l10n?.startRadio ?? 'Start Radio',
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHigh.withValues(
                alpha: 0.8,
              ),
              foregroundColor: colorScheme.onSurfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(10),
              minimumSize: const Size(
                AppTokens.minInteractiveSize,
                AppTokens.minInteractiveSize,
              ),
            ),
            onPressed: () {
              final song = mediaItemToMap(metadata);
              showToast(
                context,
                context.l10n?.startingRadio ?? 'Starting radio...',
                duration: const Duration(seconds: 1),
              );
              unawaited(audioHandler.startSongRadio(song));
            },
          ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop layout
// ---------------------------------------------------------------------------

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.metadata,
    required this.size,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
    required this.onLyricsTap,
  });
  final MediaItem metadata;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final VoidCallback onLyricsTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Expanded(
                  flex: 5,
                  child: Center(
                    child: NowPlayingArtwork(
                      size: size,
                      metadata: metadata,
                    ),
                  ),
                ),
                if (!(metadata.extras?['isLive'] ?? false))
                  Expanded(
                    flex: 4,
                    child: NowPlayingControls(
                      size: size,
                      audioId: metadata.extras?['ytid'],
                      adjustedIconSize: adjustedIconSize,
                      adjustedMiniIconSize: adjustedMiniIconSize,
                      metadata: metadata,
                    ),
                  ),
                BottomActionsRow(
                  audioId: metadata.extras?['ytid'],
                  metadata: metadata,
                  iconSize: adjustedMiniIconSize,
                  isLargeScreen: true,
                  onLyricsTap: onLyricsTap,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow.withValues(alpha: 0.72),
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(28),
              ),
              border: Border(
                left: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
            ),
            child: const QueueWidget(),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Mobile layout
// ---------------------------------------------------------------------------

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.metadata,
    required this.size,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
    required this.isLargeScreen,
    required this.onLyricsTap,
  });
  final MediaItem metadata;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final bool isLargeScreen;
  final VoidCallback onLyricsTap;

  @override
  Widget build(BuildContext context) {
    final isLandscape = size.width > size.height;

    if (isLandscape) {
      return _buildLandscapeLayout(context);
    }
    return _buildPortraitLayout(context);
  }

  Widget _buildPortraitLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 4),
          Expanded(
            flex: 5,
            child: Center(
              child: NowPlayingArtwork(
                size: size,
                metadata: metadata,
              ),
            ),
          ),
          if (!(metadata.extras?['isLive'] ?? false))
            Expanded(
              flex: 4,
              child: NowPlayingControls(
                size: size,
                audioId: metadata.extras?['ytid'],
                adjustedIconSize: adjustedIconSize,
                adjustedMiniIconSize: adjustedMiniIconSize,
                metadata: metadata,
              ),
            ),
          BottomActionsRow(
            audioId: metadata.extras?['ytid'],
            metadata: metadata,
            iconSize: adjustedMiniIconSize,
            isLargeScreen: isLargeScreen,
            onLyricsTap: onLyricsTap,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Center(
              child: NowPlayingArtwork(
                size: size,
                metadata: metadata,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!(metadata.extras?['isLive'] ?? false))
                  Expanded(
                    child: NowPlayingControls(
                      size: size,
                      audioId: metadata.extras?['ytid'],
                      adjustedIconSize: adjustedIconSize,
                      adjustedMiniIconSize: adjustedMiniIconSize,
                      metadata: metadata,
                    ),
                  ),
                BottomActionsRow(
                  audioId: metadata.extras?['ytid'],
                  metadata: metadata,
                  iconSize: adjustedMiniIconSize,
                  isLargeScreen: isLargeScreen,
                  onLyricsTap: onLyricsTap,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
