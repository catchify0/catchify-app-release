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
import 'package:flutter/services.dart';
import 'package:catchify/constants/app_tokens.dart';
import 'package:go_router/go_router.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart';
import 'package:catchify/services/router_service.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/app_utils.dart';
import 'package:catchify/widgets/now_playing/marquee_text_widget.dart';
import 'package:catchify/widgets/playback_icon_button.dart';
import 'package:catchify/widgets/position_slider.dart';

class NowPlayingControls extends StatelessWidget {
  const NowPlayingControls({
    super.key,
    required this.size,
    required this.audioId,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
    required this.metadata,
  });

  final Size size;
  final dynamic audioId;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDesktop = size.width > 800;

    final titleFontSize = getResponsiveTitleFontSize(size);
    final artistFontSize = getResponsiveArtistFontSize(size);
    final canOpenArtist = _canOpenArtist(metadata);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final isCompact = availableHeight < 280;
        final isVeryCompact = availableHeight < 200;

        final spacing = isVeryCompact
            ? 2.0
            : isCompact
            ? 4.0
            : 8.0;
        final iconScale = isVeryCompact
            ? 0.65
            : isCompact
            ? 0.75
            : 1.0;
        final fontScale = isCompact ? 0.9 : 1.0;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isCompact) const Spacer(),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 16 : 24,
                vertical: spacing,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MarqueeTextWidget(
                    text: metadata.title,
                    fontColor: colorScheme.onSurface,
                    fontSize: titleFontSize * fontScale,
                    fontWeight: FontWeight.bold,
                  ),
                  SizedBox(height: spacing),
                  if (metadata.artist != null)
                    Semantics(
                      link: canOpenArtist,
                      label: canOpenArtist
                          ? '${metadata.artist}, artist'
                          : metadata.artist,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: canOpenArtist
                              ? () => _openArtistPage(context, metadata)
                              : null,
                          borderRadius: AppTokens.borderRadiusSmall,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: AppTokens.minInteractiveSize,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: MarqueeTextWidget(
                                text: metadata.artist!,
                                fontColor: colorScheme.onSurfaceVariant,
                                fontSize: artistFontSize * fontScale,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (!isCompact) const Spacer(),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 400 : constraints.maxWidth,
              ),
              child: const PositionSlider(),
            ),
            SizedBox(height: spacing),
            PlayerControlButtons(
              metadata: metadata,
              iconSize: adjustedIconSize * iconScale,
              miniIconSize: adjustedMiniIconSize * iconScale,
            ),
            if (!isCompact) const Spacer(),
          ],
        );
      },
    );
  }

  bool _canOpenArtist(MediaItem metadata) {
    final artist = metadata.artist?.trim() ?? '';
    final artistId = metadata.extras?['artistId']?.toString().trim() ?? '';
    final sourceSongId = metadata.extras?['ytid']?.toString().trim() ?? '';

    return !offlineMode.value &&
        (artist.isNotEmpty || artistId.isNotEmpty || sourceSongId.isNotEmpty);
  }

  void _openArtistPage(BuildContext context, MediaItem metadata) {
    final artist = metadata.artist?.trim() ?? '';
    final artistId = metadata.extras?['artistId']?.toString().trim() ?? '';
    final sourceSongId = metadata.extras?['ytid']?.toString().trim() ?? '';
    final videoAuthor =
        metadata.extras?['videoAuthor']?.toString().trim() ?? '';
    final lookup = artistId.isNotEmpty
        ? artistId
        : artist.isNotEmpty
        ? artist
        : sourceSongId;

    if (lookup.isEmpty) return;

    final router = GoRouter.of(context);
    final basePath = _artistRouteBasePath(context);
    final artistData = {
      'ytid': artistId.isNotEmpty ? artistId : lookup,
      if (artist.isNotEmpty) 'title': artist,
      if (sourceSongId.isNotEmpty) 'sourceSongId': sourceSongId,
      if (videoAuthor.isNotEmpty) 'videoAuthor': videoAuthor,
      'source': 'youtube-artist',
      'isArtist': true,
      'list': [],
    };

    Navigator.of(context).pop();
    unawaited(
      router.push(
        '$basePath/artist/${Uri.encodeComponent(lookup)}',
        extra: artistData,
      ),
    );
  }

  String _artistRouteBasePath(BuildContext context) {
    try {
      final currentPath = GoRouterState.of(context).uri.path;
      if (currentPath.startsWith(NavigationManager.searchPath)) {
        return NavigationManager.searchPath;
      }
      if (currentPath.startsWith(NavigationManager.libraryPath)) {
        return NavigationManager.libraryPath;
      }
    } catch (_) {}

    return NavigationManager.homePath;
  }
}

class PlayerControlButtons extends StatelessWidget {
  const PlayerControlButtons({
    super.key,
    required this.metadata,
    required this.iconSize,
    required this.miniIconSize,
  });
  final MediaItem metadata;
  final double iconSize;
  final double miniIconSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final responsiveIconSize = screenWidth < 360 ? iconSize * 0.85 : iconSize;
    final responsiveMiniIconSize = screenWidth < 360
        ? miniIconSize * 0.85
        : miniIconSize;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final isTight = maxWidth < 360;
        final isUltraTight = maxWidth < 320;

        final horizontalPadding = isUltraTight
            ? 10.0
            : isTight
            ? 14.0
            : 20.0;
        final buttonSpacing = isUltraTight
            ? 6.0
            : isTight
            ? 10.0
            : screenWidth < 360
            ? 8.0
            : 16.0;
        const minButtonSize = AppTokens.minInteractiveSize;
        final buttonPadding = EdgeInsets.all(
          isUltraTight
              ? 6.0
              : isTight
              ? 8.0
              : 10.0,
        );

        const buttonConstraints = BoxConstraints(
          minWidth: minButtonSize,
          minHeight: minButtonSize,
        );

        final controlIconSize =
            responsiveIconSize *
            (isUltraTight
                ? 0.75
                : isTight
                ? 0.85
                : 0.92);
        final miniControlSize =
            responsiveMiniIconSize *
            (isUltraTight
                ? 0.8
                : isTight
                ? 0.9
                : 1.0);
        final playPadding = EdgeInsets.all(
          responsiveIconSize *
              (isUltraTight
                  ? 0.30
                  : isTight
                  ? 0.36
                  : 0.45),
        );

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            children: <Widget>[
              _buildShuffleButton(
                context,
                colorScheme,
                miniControlSize,
                buttonConstraints,
                buttonPadding,
              ),
              SizedBox(width: buttonSpacing),
              Expanded(
                child: Center(
                  child: StreamBuilder<List<MediaItem>>(
                    initialData:
                        audioHandler.queue.valueOrNull ??
                        audioHandler.queue.value,
                    stream: audioHandler.queue,
                    builder: (context, snapshot) {
                      return ValueListenableBuilder<AudioServiceRepeatMode>(
                        valueListenable: repeatNotifier,
                        builder: (_, repeatMode, __) {
                          return FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    FluentIcons.previous_24_regular,
                                    color: colorScheme.onSurface,
                                  ),
                                  tooltip: context.l10n!.skipToPrevious,
                                  constraints: buttonConstraints,
                                  iconSize: controlIconSize * 0.65,
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    audioHandler.skipToPrevious();
                                  },
                                  style: IconButton.styleFrom(
                                    backgroundColor:
                                        colorScheme.surfaceContainerHighest,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    padding: buttonPadding,
                                    minimumSize: const Size(
                                      AppTokens.minInteractiveSize,
                                      AppTokens.minInteractiveSize,
                                    ),
                                  ),
                                ),
                                SizedBox(width: buttonSpacing),
                                PlaybackIconButton(
                                  iconColor: colorScheme.onPrimary,
                                  backgroundColor: colorScheme.primary,
                                  iconSize: controlIconSize,
                                  padding: playPadding,
                                ),
                                SizedBox(width: buttonSpacing),
                                ValueListenableBuilder<bool>(
                                  valueListenable: playNextSongAutomatically,
                                  builder: (_, autoPlay, __) {
                                    final canGoNext =
                                        audioHandler.hasNext ||
                                        repeatMode !=
                                            AudioServiceRepeatMode.none ||
                                        autoPlay;
                                    return IconButton(
                                      icon: Icon(
                                        FluentIcons.next_24_regular,
                                        color: canGoNext
                                            ? colorScheme.onSurface
                                            : colorScheme.onSurface.withValues(
                                                alpha: 0.3,
                                              ),
                                      ),
                                      tooltip: context.l10n!.skipToNext,
                                      constraints: buttonConstraints,
                                      iconSize: controlIconSize * 0.65,
                                      onPressed: canGoNext
                                          ? () {
                                              HapticFeedback.lightImpact();
                                              audioHandler.skipToNext();
                                            }
                                          : null,
                                      style: IconButton.styleFrom(
                                        backgroundColor:
                                            colorScheme.surfaceContainerHighest,
                                        disabledBackgroundColor:
                                            colorScheme.surfaceContainerHighest,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        padding: buttonPadding,
                                        minimumSize: const Size(
                                          AppTokens.minInteractiveSize,
                                          AppTokens.minInteractiveSize,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              SizedBox(width: buttonSpacing),
              _buildRepeatButton(
                context,
                colorScheme,
                miniControlSize,
                buttonConstraints,
                buttonPadding,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShuffleButton(
    BuildContext context,
    ColorScheme colorScheme,
    double size,
    BoxConstraints buttonConstraints,
    EdgeInsets buttonPadding,
  ) {
    return ValueListenableBuilder<bool>(
      valueListenable: shuffleNotifier,
      builder: (_, value, __) {
        return IconButton(
          icon: Icon(
            value
                ? FluentIcons.arrow_shuffle_24_filled
                : FluentIcons.arrow_shuffle_24_regular,
            color: value ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
          ),
          tooltip: context.l10n!.shuffle,
          iconSize: size,
          constraints: buttonConstraints,
          padding: buttonPadding,
          style: IconButton.styleFrom(
            backgroundColor: value
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            audioHandler.setShuffleMode(
              value
                  ? AudioServiceShuffleMode.none
                  : AudioServiceShuffleMode.all,
            );
          },
        );
      },
    );
  }

  Widget _buildRepeatButton(
    BuildContext context,
    ColorScheme colorScheme,
    double size,
    BoxConstraints buttonConstraints,
    EdgeInsets buttonPadding,
  ) {
    return StreamBuilder<List<MediaItem>>(
      initialData: audioHandler.queue.valueOrNull ?? audioHandler.queue.value,
      stream: audioHandler.queue,
      builder: (context, snapshot) {
        final queue = snapshot.data ?? [];
        return ValueListenableBuilder<AudioServiceRepeatMode>(
          valueListenable: repeatNotifier,
          builder: (_, repeatMode, __) {
            final isActive = repeatMode != AudioServiceRepeatMode.none;

            return IconButton(
              icon: Icon(
                repeatMode == AudioServiceRepeatMode.one
                    ? FluentIcons.arrow_repeat_1_24_filled
                    : isActive
                    ? FluentIcons.arrow_repeat_all_24_filled
                    : FluentIcons.arrow_repeat_all_24_regular,
                color: isActive
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
              tooltip: context.l10n!.repeat,
              iconSize: size,
              constraints: buttonConstraints,
              padding: buttonPadding,
              style: IconButton.styleFrom(
                backgroundColor: isActive
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                final AudioServiceRepeatMode newMode;
                if (repeatMode == AudioServiceRepeatMode.none) {
                  newMode = queue.length <= 1
                      ? AudioServiceRepeatMode.one
                      : AudioServiceRepeatMode.all;
                } else if (repeatMode == AudioServiceRepeatMode.all) {
                  newMode = AudioServiceRepeatMode.one;
                } else {
                  newMode = AudioServiceRepeatMode.none;
                }
                repeatNotifier.value = newMode;
                audioHandler.setRepeatMode(newMode);
              },
            );
          },
        );
      },
    );
  }
}
