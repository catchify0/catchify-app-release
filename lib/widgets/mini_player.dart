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

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:catchify/constants/app_tokens.dart';
import 'package:catchify/main.dart';
import 'package:catchify/models/full_player_state.dart';
import 'package:catchify/models/position_data.dart';
import 'package:catchify/screens/now_playing_page.dart';
import 'package:catchify/services/artwork_service.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/theme/app_text_styles.dart';
import 'package:catchify/widgets/glass_surface.dart';
import 'package:catchify/widgets/marquee.dart';
import 'package:catchify/widgets/song_artwork.dart';
import 'package:rxdart/rxdart.dart';

final Stream<FullPlayerState> _fullPlayerStateStream =
    Rx.combineLatest2(
          audioHandler.playbackStateStream,
          audioHandler.queue.distinct(),
          (PlaybackState state, List<MediaItem> queue) => FullPlayerState(
            playbackState: state,
            queue: queue,
            position: PositionData(Duration.zero, Duration.zero, Duration.zero),
          ),
        )
        .distinct(
          (prev, curr) =>
              prev.playbackState.playing == curr.playbackState.playing &&
              prev.playbackState.processingState ==
                  curr.playbackState.processingState &&
              prev.playbackState.queueIndex == curr.playbackState.queueIndex &&
              prev.queue.length == curr.queue.length,
        )
        .asBroadcastStream();

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  static const double playerHeight = AppTokens.miniPlayerHeight;
  static const double _borderRadius = 22;
  static const double _artworkSize = AppTokens.miniPlayerArtworkSize;
  static const double _artworkRadius = 14;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final transitionDuration =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false
        ? Duration.zero
        : AppTokens.motionStandard;

    return AnimatedSize(
      duration: transitionDuration,
      curve: Curves.easeOutCubic,
      child: StreamBuilder<MediaItem?>(
        stream: audioHandler.mediaItem,
        builder: (context, mediaSnapshot) {
          final metadata = mediaSnapshot.data;
          if (metadata == null) return const SizedBox.shrink();

          return StreamBuilder<FullPlayerState>(
            stream: _fullPlayerStateStream,
            builder: (context, stateSnapshot) {
              final state = stateSnapshot.data;
              if (state == null) return const SizedBox.shrink();

              final hasNext =
                  state.queue.length > 1 &&
                  (state.playbackState.queueIndex ?? 0) <
                      state.queue.length - 1;

              return _MiniPlayerBody(
                colorScheme: colorScheme,
                metadata: metadata,
                state: state,
                hasNext: hasNext,
              );
            },
          );
        },
      ),
    );
  }
}

class _MiniPlayerBody extends StatefulWidget {
  const _MiniPlayerBody({
    required this.colorScheme,
    required this.metadata,
    required this.state,
    required this.hasNext,
  });

  final ColorScheme colorScheme;
  final MediaItem metadata;
  final FullPlayerState state;
  final bool hasNext;

  @override
  State<_MiniPlayerBody> createState() => _MiniPlayerBodyState();
}

class _MiniPlayerBodyState extends State<_MiniPlayerBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;
  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.98).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_disableAnimations == disableAnimations) return;

    _disableAnimations = disableAnimations;
    if (_disableAnimations && _animationController.isAnimating) {
      _animationController
        ..stop()
        ..value = 0;
    }
  }

  static const double _dragThresholdForNavigation = 10;

  void _handleVerticalDrag(DragUpdateDetails details) {
    if ((details.primaryDelta ?? 0) < -_dragThresholdForNavigation) {
      _navigateToNowPlaying();
    }
  }

  void _navigateToNowPlaying() {
    Navigator.of(context).push(_createSlideTransition());
  }

  PageRoute<void> _createSlideTransition() {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, _) => const NowPlayingPage(),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeInOut));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.colorScheme;
    final metadata = widget.metadata;
    final state = widget.state;
    final transitionDuration = _disableAnimations
        ? Duration.zero
        : AppTokens.motionStandard;

    return Semantics(
      button: true,
      label: metadata.artist == null || metadata.artist!.isEmpty
          ? metadata.title
          : '${metadata.title}, by ${metadata.artist}',
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: GestureDetector(
              onTapDown: _disableAnimations
                  ? null
                  : (_) => _animationController.forward(),
              onTapUp: _disableAnimations
                  ? null
                  : (_) => _animationController.reverse(),
              onTapCancel: _disableAnimations
                  ? null
                  : () => _animationController.reverse(),
              onVerticalDragUpdate: _handleVerticalDrag,
              onTap: _navigateToNowPlaying,
              child: SizedBox(
                height: MiniPlayer.playerHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      MiniPlayer._borderRadius,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.14),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.06),
                        blurRadius: 14,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: GlassSurface(
                    borderRadius: BorderRadius.circular(
                      MiniPlayer._borderRadius,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    surfaceColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.78),
                    borderColor: colorScheme.outlineVariant.withValues(
                      alpha: 0.46,
                    ),
                    child: Row(
                      children: [
                        _ArtworkWidget(metadata: metadata),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: transitionDuration,
                            switchInCurve: Curves.easeIn,
                            switchOutCurve: Curves.easeOut,
                            layoutBuilder: (currentChild, previousChildren) =>
                                Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    ...previousChildren,
                                    if (currentChild != null) currentChild,
                                  ],
                                ),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                            child: KeyedSubtree(
                              key: ValueKey(metadata.id),
                              child: _MetadataWidget(
                                title: metadata.title,
                                artist: metadata.artist,
                                colorScheme: colorScheme,
                              ),
                            ),
                          ),
                        ),
                        _ControlsWidget(
                          colorScheme: colorScheme,
                          playbackState: state.playbackState,
                          metadata: metadata,
                          hasNext: widget.hasNext,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ArtworkWidget extends StatelessWidget {
  const _ArtworkWidget({required this.metadata});
  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    final uriStr = metadata.artUri?.toString() ??
        metadata.extras?['highResImage']?.toString() ??
        metadata.extras?['image']?.toString() ??
        '';
    final isHorizontal = ArtworkService.isYouTubeThumbnailUrl(uriStr);
    final artWidth = isHorizontal ? 72.0 : MiniPlayer._artworkSize;
    final artHeight = isHorizontal ? 40.0 : MiniPlayer._artworkSize;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Hero(
        tag: 'now_playing_artwork',
        child: SizedBox(
          width: artWidth,
          height: artHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MiniPlayer._artworkRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 0.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(MiniPlayer._artworkRadius),
              child: SongArtworkWidget(
                metadata: metadata,
                width: artWidth,
                height: artHeight,
                size: MiniPlayer._artworkSize,
                errorWidgetIconSize: 24,
                borderRadius: MiniPlayer._artworkRadius,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetadataWidget extends StatelessWidget {
  const _MetadataWidget({
    required this.title,
    required this.artist,
    required this.colorScheme,
  });

  final String title;
  final String? artist;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarqueeWidget(
            manualScrollEnabled: false,
            animationDuration: const Duration(seconds: 8),
            backDuration: const Duration(seconds: 2),
            pauseDuration: const Duration(seconds: 2),
            child: Text(
              title,
              style: AppTextStyles.rowTitle.copyWith(
                color: colorScheme.onSurface,
                fontSize: 14.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (artist != null && artist!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              artist!,
              style: AppTextStyles.rowSubtitle.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _ControlsWidget extends StatelessWidget {
  const _ControlsWidget({
    required this.colorScheme,
    required this.playbackState,
    required this.metadata,
    required this.hasNext,
  });

  final ColorScheme colorScheme;
  final PlaybackState playbackState;
  final MediaItem metadata;
  final bool hasNext;

  @override
  Widget build(BuildContext context) {
    final canGoNext =
        hasNext ||
        repeatNotifier.value != AudioServiceRepeatMode.none ||
        playNextSongAutomatically.value;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircularPlayButton(
          colorScheme: colorScheme,
          playbackState: playbackState,
          metadata: metadata,
        ),
        if (canGoNext) ...[
          const SizedBox(width: 4),
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              audioHandler.skipToNext();
            },
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            icon: Icon(
              FluentIcons.next_24_filled,
              color: colorScheme.primary,
              size: 20,
            ),
            style: IconButton.styleFrom(
              foregroundColor: colorScheme.primary,
              padding: const EdgeInsets.all(4),
              minimumSize: const Size(
                AppTokens.minInteractiveSize,
                AppTokens.minInteractiveSize,
              ),
              maximumSize: const Size(
                AppTokens.minInteractiveSize,
                AppTokens.minInteractiveSize,
              ),
              shape: const CircleBorder(),
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ],
    );
  }
}

class _CircularPlayButton extends StatelessWidget {
  const _CircularPlayButton({
    required this.colorScheme,
    required this.playbackState,
    required this.metadata,
  });

  final ColorScheme colorScheme;
  final PlaybackState playbackState;
  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    final processingState = playbackState.processingState;
    final isPlaying = playbackState.playing;
    final isLoading =
        processingState == AudioProcessingState.loading ||
        processingState == AudioProcessingState.buffering;
    final isCompleted = processingState == AudioProcessingState.completed;

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          StreamBuilder<PositionData>(
            stream: audioHandler.positionDataStream,
            builder: (context, snapshot) {
              final posData = snapshot.data;
              final totalDuration =
                  (posData != null && posData.duration > Duration.zero)
                  ? posData.duration
                  : (metadata.duration ?? Duration.zero);
              final progress =
                  (posData == null || totalDuration.inMilliseconds == 0)
                  ? 0.0
                  : (posData.position.inMilliseconds /
                            totalDuration.inMilliseconds)
                        .clamp(0.0, 1.0);

              return RepaintBoundary(
                child: CustomPaint(
                  size: const Size(48, 48),
                  painter: _CircularProgressPainter(
                    progress: progress,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    progressColor: colorScheme.primary,
                    strokeWidth: 3,
                  ),
                ),
              );
            },
          ),
          if (isLoading)
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            )
          else
            IconButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                if (isCompleted) {
                  audioHandler.playAgain();
                } else if (isPlaying) {
                  audioHandler.pause();
                } else {
                  audioHandler.play();
                }
              },
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              icon: Icon(
                isCompleted
                    ? FluentIcons.arrow_counterclockwise_24_filled
                    : (isPlaying
                          ? FluentIcons.pause_16_filled
                          : FluentIcons.play_16_filled),
                color: colorScheme.primary,
                size: 22,
              ),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  _CircularProgressPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color backgroundColor;
  final Color progressColor;
  final double strokeWidth;

  final waveAmplitude = 1.5;
  final waveFrequency = 12.0;
  final animationValue = 0.0;

  Path _buildWavyArcPath(Size size, double startAngle, double sweepAngle) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final baseRadius = (size.width - strokeWidth) / 2;
    final steps = (sweepAngle.abs() * 180 / math.pi).round().clamp(4, 720);
    final path = Path();

    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final angle = startAngle + sweepAngle * t;
      final wave =
          waveAmplitude * math.sin(waveFrequency * angle + animationValue);
      final r = baseRadius + wave;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(
      _buildWavyArcPath(size, -math.pi / 2, 2 * math.pi),
      trackPaint,
    );

    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(
        _buildWavyArcPath(size, -math.pi / 2, 2 * math.pi * progress),
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CircularProgressPainter old) =>
      old.progress != progress ||
      old.backgroundColor != backgroundColor ||
      old.progressColor != progressColor ||
      old.animationValue != animationValue;
}
