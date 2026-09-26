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
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:catchify/constants/app_tokens.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart';
import 'package:catchify/services/artwork_service.dart';
import 'package:catchify/services/common_services.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/flutter_toast.dart';
import 'package:catchify/utilities/mediaitem.dart';
import 'package:catchify/utilities/async_loader.dart';
import 'package:catchify/widgets/lyrics_display_widget.dart';
import 'package:catchify/widgets/now_playing/bottom_actions_row.dart';
import 'package:catchify/widgets/now_playing/now_playing_artwork.dart';
import 'package:catchify/widgets/now_playing/now_playing_controls.dart';
import 'package:catchify/widgets/now_playing_ambient_background.dart';
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
  final GlobalKey _artworkKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey();
  Rect? _normalArtworkRect;

  @override
  void initState() {
    super.initState();
    _lyricsTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 280),
    );
    _artworkCurve = CurvedAnimation(
      parent: _lyricsTransitionController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _artworkCurve.dispose();
    _lyricsTransitionController.dispose();
    super.dispose();
  }

  String _songKey(MediaItem metadata) => metadata.id.isNotEmpty
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

    return StreamBuilder<MediaItem?>(
      initialData: audioHandler.mediaItem.valueOrNull,
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final metadata = snapshot.data ?? audioHandler.mediaItem.valueOrNull;
        if (metadata == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return ValueListenableBuilder<String>(
          valueListenable: playerGradientStyle,
          builder: (context, gradientStyle, _) {
            final isDark = theme.brightness == Brightness.dark;
            final isPureBlackStyle = isDark && gradientStyle == 'pure_black';

            return Scaffold(
              backgroundColor: isPureBlackStyle
                  ? Colors.black
                  : colorScheme.surface,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  // Dynamic Apple Music-style ambient blurred artwork background
                  AnimatedBuilder(
                    animation: _artworkCurve,
                    builder: (context, _) {
                      return NowPlayingAmbientBackground(
                        metadata: metadata,
                        isPureBlack: isPureBlackStyle,
                        lyricsProgress: _artworkCurve.value,
                      );
                    },
                  ),

                  // Foreground content
                  SafeArea(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final uriStr =
                            metadata.artUri?.toString() ??
                            metadata.extras?['highResImage']?.toString() ??
                            metadata.extras?['image']?.toString() ??
                            '';
                        final isHorizontal =
                            ArtworkService.isYouTubeThumbnailUrl(uriStr);

                        final double maxW;
                        final double maxH;
                        final isLandscape = size.width > size.height;
                        final isDesktop = size.width > 800;

                        if (isDesktop) {
                          maxH = size.height * 0.45;
                          maxW = size.width * 0.50;
                        } else if (isLandscape) {
                          maxH = size.height * 0.50;
                          maxW = size.width * 0.45;
                        } else if (size.width < 360) {
                          maxW = size.width * 0.85;
                          maxH = size.height * 0.38;
                        } else if (size.width < 600) {
                          maxW = size.width * 0.88;
                          maxH = size.height * 0.40;
                        } else {
                          maxW = size.width * 0.70;
                          maxH = size.height * 0.42;
                        }

                        final double naturalArtworkWidth;
                        final double naturalArtworkHeight;
                        if (isHorizontal) {
                          var w = maxW;
                          var h = w * 9.0 / 16.0;
                          if (h > maxH) {
                            h = maxH;
                            w = h * 16.0 / 9.0;
                          }
                          naturalArtworkWidth = w;
                          naturalArtworkHeight = h;
                        } else {
                          final s = math.min(maxW, maxH);
                          naturalArtworkWidth = s;
                          naturalArtworkHeight = s;
                        }

                        final artworkLeft =
                            (constraints.maxWidth - naturalArtworkWidth) / 2;
                        final artworkTop = _artworkTop(size);
                        const compactLeft = 18.0;
                        final compactW = isHorizontal ? 76.0 : 54.0;
                        final compactH = isHorizontal ? 42.0 : 54.0;
                        final compactTop = isHorizontal ? 14.0 : 8.0;

                        return Stack(
                          key: _stackKey,
                          fit: StackFit.expand,
                          clipBehavior: Clip.none,
                          children: [
                            // Normal Now Playing view (fades out as lyrics open, fades in as lyrics close)
                            AnimatedBuilder(
                              animation: _artworkCurve,
                              builder: (context, child) {
                                final progress = _artworkCurve.value;
                                final opacity = (1.0 - progress).clamp(
                                  0.0,
                                  1.0,
                                );
                                if (opacity <= 0.0)
                                  return const SizedBox.shrink();
                                return IgnorePointer(
                                  ignoring: progress > 0.5,
                                  child: Opacity(
                                    opacity: opacity,
                                    child: child,
                                  ),
                                );
                              },
                              child: Column(
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
                                            onLyricsTap: _openLyrics,
                                            artworkVisible:
                                                !_artworkOverlayVisible,
                                            artworkKey: _artworkKey,
                                          )
                                        : _MobileLayout(
                                            metadata: metadata,
                                            size: size,
                                            adjustedIconSize: baseIconSize,
                                            adjustedMiniIconSize: miniIconSize,
                                            isLargeScreen: isLargeScreen,
                                            onLyricsTap: _openLyrics,
                                            artworkVisible:
                                                !_artworkOverlayVisible,
                                            artworkKey: _artworkKey,
                                          ),
                                  ),
                                ],
                              ),
                            ),

                            // Lyrics view (fades in as lyrics open, fades out as lyrics close)
                            if (_showLyrics)
                              AnimatedBuilder(
                                animation: _artworkCurve,
                                builder: (context, child) {
                                  final progress = _artworkCurve.value;
                                  final opacity = progress.clamp(0.0, 1.0);
                                  if (opacity <= 0.0)
                                    return const SizedBox.shrink();
                                  return IgnorePointer(
                                    ignoring: progress < 0.5,
                                    child: Opacity(
                                      opacity: opacity,
                                      child: child,
                                    ),
                                  );
                                },
                                child: _buildLyricsView(
                                  key: const ValueKey('lyrics'),
                                  metadata: metadata,
                                ),
                              ),

                            // Floating artwork animation (smoothly flies between center and compact slot)
                            if (_artworkOverlayVisible)
                              AnimatedBuilder(
                                animation: _artworkCurve,
                                child: SongArtworkWidget(
                                  metadata: metadata,
                                  width: naturalArtworkWidth,
                                  height: naturalArtworkHeight,
                                  size: math.max(
                                    naturalArtworkWidth,
                                    naturalArtworkHeight,
                                  ),
                                  borderRadius: 16,
                                ),
                                builder: (context, staticArtwork) {
                                  final targetRect =
                                      _normalArtworkRect ??
                                      Rect.fromLTWH(
                                        artworkLeft,
                                        artworkTop,
                                        naturalArtworkWidth,
                                        naturalArtworkHeight,
                                      );
                                  final initialLeft = targetRect.left;
                                  final initialTop = targetRect.top;
                                  final initialWidth = targetRect.width;
                                  final initialHeight = targetRect.height;

                                  final progress = _artworkCurve.value;
                                  final currentWidth = lerpDouble(
                                    initialWidth,
                                    compactW,
                                    progress,
                                  )!;
                                  final currentHeight = lerpDouble(
                                    initialHeight,
                                    compactH,
                                    progress,
                                  )!;
                                  final currentLeft = lerpDouble(
                                    initialLeft,
                                    compactLeft,
                                    progress,
                                  )!;
                                  final currentTop = lerpDouble(
                                    initialTop,
                                    compactTop,
                                    progress,
                                  )!;
                                  final currentRadius = lerpDouble(
                                    16,
                                    10,
                                    progress,
                                  )!;
                                  final shadowAlpha = (1.0 - progress).clamp(
                                    0.0,
                                    1.0,
                                  );

                                  return Positioned(
                                    left: currentLeft,
                                    top: currentTop,
                                    width: currentWidth,
                                    height: currentHeight,
                                    child: IgnorePointer(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            currentRadius,
                                          ),
                                          boxShadow: shadowAlpha > 0.02
                                              ? [
                                                  BoxShadow(
                                                    color: colorScheme.primary
                                                        .withValues(
                                                          alpha:
                                                              0.28 *
                                                              shadowAlpha,
                                                        ),
                                                    blurRadius:
                                                        32 * shadowAlpha,
                                                    offset: Offset(
                                                      0,
                                                      12 * shadowAlpha,
                                                    ),
                                                    spreadRadius:
                                                        2 * shadowAlpha,
                                                  ),
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                          alpha:
                                                              0.32 *
                                                              shadowAlpha,
                                                        ),
                                                    blurRadius:
                                                        20 * shadowAlpha,
                                                    offset: Offset(
                                                      0,
                                                      8 * shadowAlpha,
                                                    ),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            currentRadius,
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.cover,
                                            child: SizedBox(
                                              width: initialWidth,
                                              height: initialHeight,
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
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
    final artworkSize = _artworkSize(size);
    final isLandscape = size.width > size.height;
    if (isLandscape) {
      return (size.height - artworkSize) / 2;
    }
    // Mobile portrait: artwork is centered in Expanded(flex: 5) out of total flex 9,
    // between AppBar (~56px) and BottomActions (~60px).
    const appBarHeight = 56.0;
    const bottomBarHeight = 60.0;
    final availableFlexHeight = (size.height - appBarHeight - bottomBarHeight)
        .clamp(0.0, double.infinity);
    final flex5CenterY =
        appBarHeight + (availableFlexHeight * (5.0 / 9.0)) / 2.0;
    return (flex5CenterY - artworkSize / 2.0).clamp(16.0, size.height);
  }

  void _updateArtworkRect() {
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final artworkBox =
        _artworkKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox != null && artworkBox != null && artworkBox.hasSize) {
      final offset = stackBox.globalToLocal(
        artworkBox.localToGlobal(Offset.zero),
      );
      _normalArtworkRect = offset & artworkBox.size;
    }
  }

  void _openLyrics() {
    _updateArtworkRect();
    setState(() {
      _showLyrics = true;
      _artworkOverlayVisible = true;
    });
    _lyricsTransitionController.forward();
  }

  void _closeLyrics() {
    _updateArtworkRect();
    // Both views smoothly cross-fade while the artwork flies back to center.
    // When the reverse animation finishes at progress 0.0, clean up overlay.
    _lyricsTransitionController.reverse().whenCompleteOrCancel(() {
      if (mounted && _lyricsTransitionController.value == 0.0) {
        setState(() {
          _showLyrics = false;
          _artworkOverlayVisible = false;
        });
      }
    });
  }

  Widget _buildLyricsView({required Key key, required MediaItem metadata}) {
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
    final uriStr =
        metadata.artUri?.toString() ??
        metadata.extras?['highResImage']?.toString() ??
        metadata.extras?['image']?.toString() ??
        '';
    final isHorizontal = ArtworkService.isYouTubeThumbnailUrl(uriStr);
    final compactW = isHorizontal ? 76.0 : 54.0;
    final compactH = isHorizontal ? 42.0 : 54.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 14, 6),
      child: Row(
        children: [
          // Placeholder slot — actual artwork is rendered by the parent
          // Stack via AnimatedBuilder (see _artworkOverlayVisible block).
          // If overlay is not visible, render artwork directly as fallback.
          SizedBox(
            width: compactW,
            height: compactH,
            child: _artworkOverlayVisible
                ? const SizedBox.shrink()
                : ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SongArtworkWidget(
                      metadata: metadata,
                      width: compactW,
                      height: compactH,
                      size: math.max(compactW, compactH),
                    ),
                  ),
          ),
          const SizedBox(width: 14),
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
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                if (metadata.artist != null && metadata.artist!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    metadata.artist!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Lyrics pill badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'LYRICS',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Circular dismiss button
          IconButton(
            icon: Icon(
              FluentIcons.dismiss_24_regular,
              color: colorScheme.onSurfaceVariant,
            ),
            iconSize: 18,
            tooltip: 'Close lyrics',
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.65,
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(38, 38),
              shape: const CircleBorder(),
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Attribution row — minimal lrclib chip + copy/share
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.6,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lyrics_outlined,
                        size: 11,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.65,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'powered by lrclib',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.70,
                          ),
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
                const SizedBox(width: 6),
                _buildMiniActionButton(
                  colorScheme: colorScheme,
                  icon: FluentIcons.share_24_regular,
                  tooltip: 'Share lyrics',
                  onPressed: _shareLyrics,
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
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
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.all(7),
        minimumSize: const Size(32, 32),
        shape: const CircleBorder(),
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
    this.artworkKey,
  });
  final MediaItem metadata;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final VoidCallback onLyricsTap;
  final bool artworkVisible;
  final Key? artworkKey;

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
                        artworkKey: artworkKey,
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
    this.artworkKey,
  });
  final MediaItem metadata;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final bool isLargeScreen;
  final VoidCallback onLyricsTap;
  final bool artworkVisible;
  final Key? artworkKey;

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
                  artworkKey: artworkKey,
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
                  artworkKey: artworkKey,
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
