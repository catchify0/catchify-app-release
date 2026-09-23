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
import 'dart:ui' show lerpDouble;

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:catchify/widgets/position_slider.dart';
import 'package:catchify/widgets/queue_list_view.dart';
import 'package:catchify/widgets/song_artwork.dart';
import 'package:share_plus/share_plus.dart';

/// Now Playing page — hosts the normal artwork/controls view and the
/// compact in-page lyrics mode without pushing a separate route.
class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage>
    with SingleTickerProviderStateMixin {
  bool _showLyrics = false;
  // Tracks whether the floating artwork overlay should be in the tree.
  // Stays true throughout the close animation (after _showLyrics becomes false)
  // so the artwork doesn't pop-out before the normal view has finished sliding in.
  bool _artworkOverlayVisible = false;
  late final AnimationController _lyricsTransitionController;
  // Cached CurvedAnimation — avoids allocating a new instance every
  // AnimatedBuilder frame (which would never be disposed).
  late final CurvedAnimation _artworkCurve;
  Future<String?>? _lyricsFuture;
  String? _lyricsKey;

  @override
  void initState() {
    super.initState();
    _lyricsTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _artworkCurve = CurvedAnimation(
      parent: _lyricsTransitionController,
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.fastOutSlowIn.flipped,
    );
  }

  @override
  void dispose() {
    _artworkCurve.dispose();
    _lyricsTransitionController.dispose();
    super.dispose();
  }

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

            return LayoutBuilder(
              builder: (context, constraints) {
                final artworkSize = _artworkSize(size);
                final artworkLeft = (constraints.maxWidth - artworkSize) / 2;
                final artworkTop = _artworkTop(size);
                const compactLeft = 18.0;
                // Must match the top padding of _buildLyricsHeader (fromLTRB(18,8,18,4))
                // so the animated artwork lands exactly on the 58×58 SizedBox slot.
                const compactTop = 8.0;

                return Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: [
                    // Keep lyrics inside NowPlayingPage and switch cleanly
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      layoutBuilder: (currentChild, _) =>
                          currentChild ?? const SizedBox.shrink(),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(
                            opacity: animation,
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
                                _buildAppBar(
                                  context,
                                  colorScheme,
                                  metadata,
                                ),
                                Expanded(
                                  child: isLargeScreen
                                      ? _DesktopLayout(
                                          metadata: metadata,
                                          size: size,
                                          adjustedIconSize: baseIconSize,
                                          adjustedMiniIconSize: miniIconSize,
                                          onLyricsTap: _openLyrics,
                                          artworkVisible: !_artworkOverlayVisible,
                                        )
                                      : _MobileLayout(
                                          metadata: metadata,
                                          size: size,
                                          adjustedIconSize: baseIconSize,
                                          adjustedMiniIconSize: miniIconSize,
                                          isLargeScreen: isLargeScreen,
                                          onLyricsTap: _openLyrics,
                                          artworkVisible: !_artworkOverlayVisible,
                                        ),
                                ),
                              ],
                            ),
                    ),
                    if (_artworkOverlayVisible)
                      AnimatedBuilder(
                        animation: _artworkCurve,
                        child: SongArtworkWidget(
                          metadata: metadata,
                          size: artworkSize,
                          borderRadius: 16,
                        ),
                        builder: (context, staticArtwork) {
                          final progress = _artworkCurve.value;
                          final currentSize =
                              lerpDouble(artworkSize, 58, progress)!;
                          final currentLeft =
                              lerpDouble(artworkLeft, compactLeft, progress)!;
                          final currentTop =
                              lerpDouble(artworkTop, compactTop, progress)!;
                          final currentRadius =
                              lerpDouble(16, 10, progress)!;
                          final shadowAlpha =
                              (1.0 - progress).clamp(0.0, 1.0);

                          return Positioned(
                            left: currentLeft,
                            top: currentTop,
                            width: currentSize,
                            height: currentSize,
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(currentRadius),
                                  boxShadow: shadowAlpha > 0.05
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.22 * shadowAlpha,
                                            ),
                                            blurRadius: 16 * shadowAlpha,
                                            offset: Offset(
                                              0,
                                              6 * shadowAlpha,
                                            ),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(currentRadius),
                                  child: FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                      width: artworkSize,
                                      height: artworkSize,
                                      child: staticArtwork,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  double _artworkSize(Size size) {
    final isLandscape = size.width > size.height;
    if (size.width > 800) return size.height * 0.38;
    if (isLandscape) return size.height * 0.45;
    if (size.width < 360) return size.width * 0.75;
    if (size.width < 600) return size.width * 0.80;
    return size.width * 0.65;
  }

  double _artworkTop(Size size) {
    const appBarHeight = 78.0;
    return appBarHeight + ((size.height - appBarHeight) * 0.18);
  }

  void _openLyrics() {
    setState(() {
      _showLyrics = true;
      _artworkOverlayVisible = true;
    });
    _lyricsTransitionController.forward(from: 0);
  }

  void _closeLyrics() {
    // Parallel close: switch views immediately while reversing the
    // floating artwork. Eliminates the previous 860ms serial delay.
    setState(() {
      _showLyrics = false;
    });
    _lyricsTransitionController.reverse().whenCompleteOrCancel(() {
      if (mounted && !_showLyrics) {
        setState(() {
          _artworkOverlayVisible = false;
        });
      }
    });
  }

  Widget _buildLyricsView({
    required Key key,
    required MediaItem metadata,
  }) {
    _loadLyrics(metadata);
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final screenWidth = size.width;
    // Use the same icon-size logic as the normal NowPlaying build() method
    // so the PlayerControlButtons look pixel-identical in lyrics mode.
    final baseIconSize = screenWidth < 360
        ? 36.0
        : screenWidth < 400
        ? 40.0
        : 44.0;
    final miniIconSize = screenWidth < 360 ? 18.0 : 22.0;
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
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Fetching lyrics…',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                )
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
                      showAttribution: false,
                    );
                  },
                ),
        ),
        _buildLyricsMiniControls(
          colorScheme: colorScheme,
          metadata: metadata,
          baseIconSize: baseIconSize,
          miniIconSize: miniIconSize,
        ),
      ],
    );
  }

  Widget _buildLyricsHeader(
    BuildContext context,
    ColorScheme colorScheme,
    MediaItem metadata,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 12, 4),
      child: Row(
        children: [
          // Placeholder slot — actual artwork is rendered by the parent
          // Stack via AnimatedBuilder (see _artworkOverlayVisible block).
          const SizedBox(width: 58, height: 58),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  metadata.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.1,
                  ),
                ),
                if (metadata.artist != null && metadata.artist!.isNotEmpty) ...
                  [
                    const SizedBox(height: 2),
                    Text(
                      metadata.artist!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.55),
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
              ],
            ),
          ),
          // Lyrics label chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'LYRICS',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: colorScheme.primary,
              ),
            ),
          ),
          // Close button — styled
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              FluentIcons.dismiss_24_regular,
              color: colorScheme.onSurfaceVariant,
            ),
            iconSize: 20,
            tooltip: 'Close lyrics',
            style: IconButton.styleFrom(
              backgroundColor:
                  colorScheme.surfaceContainerHigh.withValues(alpha: 0.8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(36, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _closeLyrics,
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsUnavailable(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FluentIcons.music_note_2_24_regular,
              size: 44,
              color: colorScheme.onSurface.withValues(alpha: 0.22),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n?.lyricsNotAvailable ?? 'Lyrics not available',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Synced lyrics could not be found for this track.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLyricsMiniControls({
    required ColorScheme colorScheme,
    required MediaItem metadata,
    required double baseIconSize,
    required double miniIconSize,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Attribution row — minimal lrclib chip + copy/share
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lyrics_outlined,
                        size: 9,
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.55),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'lrclib',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _buildMiniActionButton(
                  colorScheme: colorScheme,
                  icon: Icons.copy_rounded,
                  tooltip: 'Copy lyrics',
                  onPressed: _copyLyrics,
                ),
                const SizedBox(width: 4),
                _buildMiniActionButton(
                  colorScheme: colorScheme,
                  icon: Icons.share_rounded,
                  tooltip: 'Share lyrics',
                  onPressed: _shareLyrics,
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Position slider — identical to NowPlayingControls
            const PositionSlider(),
            const SizedBox(height: 4),
            // Prev / Play / Next — reuse the exact same widget used in
            // normal Now Playing so the buttons are pixel-identical.
            PlayerControlButtons(
              metadata: metadata,
              iconSize: baseIconSize,
              miniIconSize: miniIconSize,
            ),
          ],
        ),
      ),
    );
  }

  /// Tiny icon-only action button (copy / share) for lyrics mode.
  Widget _buildMiniActionButton({
    required ColorScheme colorScheme,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon),
      iconSize: 16,
      tooltip: tooltip,
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.all(6),
        minimumSize: const Size(30, 30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onPressed: onPressed,
    );
  }

  Future<void> _copyLyrics() async {
    final lyrics = await _lyricsFuture;
    if (!mounted || lyrics == null || lyrics.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: lyrics));
    if (mounted) {
      showToast(context, 'Lyrics copied');
    }
  }

  Future<void> _shareLyrics() async {
    final lyrics = await _lyricsFuture;
    if (lyrics == null || lyrics.isEmpty) return;
    await Share.share(lyrics);
  }

  Widget _buildAppBar(
    BuildContext context,
    ColorScheme colorScheme,
    MediaItem metadata,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            iconSize: 24,
            icon: const Icon(FluentIcons.chevron_down_24_regular),
            color: colorScheme.onSurfaceVariant,
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(
              minWidth: AppTokens.minInteractiveSize,
              minHeight: AppTokens.minInteractiveSize,
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
            color: colorScheme.onSurfaceVariant,
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(
              minWidth: AppTokens.minInteractiveSize,
              minHeight: AppTokens.minInteractiveSize,
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
    this.artworkVisible = true,
  });
  final MediaItem metadata;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final VoidCallback onLyricsTap;
  final bool artworkVisible;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                    child: Visibility(
                      visible: artworkVisible,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: NowPlayingArtwork(
                        size: size,
                        metadata: metadata,
                      ),
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
    this.artworkVisible = true,
  });
  final MediaItem metadata;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final bool isLargeScreen;
  final VoidCallback onLyricsTap;
  final bool artworkVisible;

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
              child: Visibility(
                visible: artworkVisible,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: NowPlayingArtwork(
                  size: size,
                  metadata: metadata,
                ),
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
              child: Visibility(
                visible: artworkVisible,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: NowPlayingArtwork(
                  size: size,
                  metadata: metadata,
                ),
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
