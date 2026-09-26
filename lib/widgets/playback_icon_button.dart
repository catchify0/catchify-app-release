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

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:catchify/constants/app_tokens.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart';

Widget buildPlaybackIconButton(
  double iconSize,
  Color iconColor,
  Color backgroundColor, {
  EdgeInsets? padding,
  bool useRoundedMaterialGlyphs = false,
}) {
  return StreamBuilder<PlaybackState>(
    initialData:
        audioHandler.playbackState.valueOrNull ??
        audioHandler.playbackState.value,
    stream: audioHandler.playbackState.distinct((previous, current) {
      // Only rebuild if relevant state changes
      return previous.playing == current.playing &&
          previous.processingState == current.processingState;
    }),
    builder: (context, snapshot) {
      final playbackState = snapshot.data ?? audioHandler.playbackState.value;
      final processingState = playbackState.processingState;
      final isPlaying = playbackState.playing;

      Widget iconWidget;
      VoidCallback? onPressed;
      String? semanticLabel;

      if (processingState == AudioProcessingState.completed) {
        iconWidget = Icon(
          useRoundedMaterialGlyphs
              ? Icons.replay_rounded
              : FluentIcons.arrow_counterclockwise_24_regular,
          color: iconColor,
          size: iconSize,
        );
        onPressed = () {
          HapticFeedback.lightImpact();
          audioHandler.playAgain();
        };
        semanticLabel = context.l10n!.replay;
      } else {
        iconWidget = Icon(
          useRoundedMaterialGlyphs
              ? (isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded)
              : (isPlaying
                    ? FluentIcons.pause_24_regular
                    : FluentIcons.play_24_regular),
          color: iconColor,
          size: iconSize,
        );
        onPressed = () {
          HapticFeedback.lightImpact();
          if (isPlaying) {
            audioHandler.pause();
          } else {
            audioHandler.play();
          }
        };
        semanticLabel = isPlaying ? context.l10n!.pause : context.l10n!.play;
      }

      return DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withValues(alpha: 0.36),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: backgroundColor.withValues(alpha: 0.18),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: RawMaterialButton(
          elevation: 0,
          onPressed: onPressed,
          fillColor: backgroundColor,
          splashColor: Colors.transparent,
          padding: padding ?? EdgeInsets.all(iconSize * 0.35),
          shape: const CircleBorder(),
          constraints: BoxConstraints.tightFor(
            width: iconSize * 2 < AppTokens.minInteractiveSize
                ? AppTokens.minInteractiveSize
                : iconSize * 2,
            height: iconSize * 2 < AppTokens.minInteractiveSize
                ? AppTokens.minInteractiveSize
                : iconSize * 2,
          ),
          materialTapTargetSize: MaterialTapTargetSize.padded,
          child: Semantics(
            label: semanticLabel,
            button: true,
            child: iconWidget,
          ),
        ),
      );
    },
  );
}

class PlaybackIconButton extends StatelessWidget {
  const PlaybackIconButton({
    super.key,
    required this.iconSize,
    required this.iconColor,
    required this.backgroundColor,
    this.padding,
    this.useRoundedMaterialGlyphs = false,
  });

  final double iconSize;
  final Color iconColor;
  final Color backgroundColor;
  final EdgeInsets? padding;
  final bool useRoundedMaterialGlyphs;

  @override
  Widget build(BuildContext context) {
    return buildPlaybackIconButton(
      iconSize,
      iconColor,
      backgroundColor,
      padding: padding,
      useRoundedMaterialGlyphs: useRoundedMaterialGlyphs,
    );
  }
}
