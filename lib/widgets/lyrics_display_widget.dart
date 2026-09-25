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

import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:catchify/main.dart' show audioHandler;
import 'package:catchify/models/lyric_line.dart';
import 'package:catchify/models/position_data.dart';

/// Displays synced lyrics using flutter_lyric — Youtify-style.
///
/// Uses [LyricController] to handle auto-scroll, line highlighting, tap-to-seek,
/// and auto-resume after manual scroll — exactly matching the Youtify UX.
class SyncedLyricsWidget extends StatefulWidget {
  const SyncedLyricsWidget({
    super.key,
    required this.lyrics,
    required this.positionDataStream,
    this.songId,
  });

  /// Raw LRC format lyrics string
  final String lyrics;

  /// Stream providing current playback position
  final Stream<PositionData> positionDataStream;

  /// Optional song identifier (e.g. ytid) — reserved for future use
  final String? songId;

  @override
  State<SyncedLyricsWidget> createState() => _SyncedLyricsWidgetState();
}

class _SyncedLyricsWidgetState extends State<SyncedLyricsWidget> {
  late final LyricController _controller;
  StreamSubscription<PositionData>? _positionSub;

  @override
  void initState() {
    super.initState();
    _controller = LyricController()..loadLyric(widget.lyrics);

    // Wire seek-on-tap
    _controller.setOnTapLineCallback((position) => audioHandler.seek(position));

    _subscribe();

    // Snap to current position once the first frame is laid out
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _controller.setProgress(audioHandler.playbackState.value.position);
      } catch (_) {}
    });
  }

  void _subscribe() {
    _positionSub = widget.positionDataStream.listen(
      (data) => _controller.setProgress(data.position),
    );
  }

  @override
  void didUpdateWidget(SyncedLyricsWidget old) {
    super.didUpdateWidget(old);
    if (old.lyrics != widget.lyrics) {
      _controller.loadLyric(widget.lyrics);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          _controller.setProgress(audioHandler.playbackState.value.position);
        } catch (_) {}
      });
    }
    if (old.positionDataStream != widget.positionDataStream) {
      _positionSub?.cancel();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final activeColor = colorScheme.onSurface;
    final inactiveColor = colorScheme.onSurface.withValues(
      alpha: isDark ? 0.38 : 0.48,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // The active line is anchored at 38 % from the top.
        // Without bottom padding the last lyric line scrolls UP to that
        // anchor, leaving ~62 % of the viewport empty.
        // We fill that dead zone with virtual padding so the last line
        // stays at the bottom and never over-scrolls.
        final bottomPadding = constraints.maxHeight * 0.62;

        final lyricView = LyricView(
          controller: _controller,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          style: LyricStyle(
            // Inactive line — dimmed
            textStyle: TextStyle(
              fontFamilyFallback: const ['AnekTamil'],
              fontSize: 21,
              fontWeight: FontWeight.w600,
              color: inactiveColor,
              height: 1.45,
            ),
            // Active / playing line — full opacity, bolder, larger with tight tracking
            activeStyle: TextStyle(
              fontFamilyFallback: const ['AnekTamil'],
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: activeColor,
              height: 1.45,
              letterSpacing: -0.25,
            ),
            // Translation style (not used, but required param)
            translationStyle: TextStyle(
              fontFamilyFallback: const ['AnekTamil'],
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: inactiveColor,
              height: 1.4,
            ),
            lineGap: 24,
            translationLineGap: 8,
            lineTextAlign: TextAlign.left,
            contentAlignment: CrossAxisAlignment.start,
            contentPadding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 20,
              // Key fix: virtual space so the last line doesn't float up.
              bottom: bottomPadding,
            ),
            // Active line sits at 38 % from top
            selectionAnchorPosition: 0.38,
            activeAnchorPosition: 0.38,
            selectionAlignment: MainAxisAlignment.start,
            selectedColor: activeColor,
            selectedTranslationColor: inactiveColor,
            // Smooth scroll
            scrollDuration: const Duration(milliseconds: 350),
            scrollDurations: {
              500: const Duration(milliseconds: 500),
              1000: const Duration(milliseconds: 800),
            },
            // Switch animation when active line changes
            switchEnterDuration: const Duration(milliseconds: 280),
            switchExitDuration: const Duration(milliseconds: 280),
            switchEnterCurve: Curves.easeOut,
            switchExitCurve: Curves.easeIn,
            // Auto-resume: selectionAuto MUST be < activeAuto (assert)
            selectionAutoResumeDuration: const Duration(seconds: 3),
            activeAutoResumeDuration: const Duration(seconds: 5),
            selectionAutoResumeMode: SelectionAutoResumeMode.afterSelecting,
          ),
        );

        // Top + bottom fade so lyrics dissolve gracefully into the
        // header above and the controls below in both Light & Dark modes.
        final fadeBaseColor = isDark ? Colors.black : colorScheme.surface;

        return Stack(
          children: [
            lyricView,
            // Top fade
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 36,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        fadeBaseColor.withValues(alpha: isDark ? 0.35 : 0.45),
                        fadeBaseColor.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Bottom fade
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 56,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        fadeBaseColor.withValues(alpha: isDark ? 0.45 : 0.60),
                        fadeBaseColor.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Displays plain (non-synced) lyrics as scrollable text
class PlainLyricsWidget extends StatelessWidget {
  const PlainLyricsWidget({super.key, required this.lyrics});

  final String lyrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final textColor = colorScheme.onSurface;
    final cleanLyricsText = LrcParser.cleanLyrics(lyrics);
    final fadeBaseColor = isDark ? Colors.black : colorScheme.surface;

    final content = SingleChildScrollView(
      padding: const EdgeInsets.only(top: 28, bottom: 50, left: 24, right: 24),
      physics: const BouncingScrollPhysics(),
      child: Text(
        cleanLyricsText.isNotEmpty ? cleanLyricsText : lyrics,
        style: TextStyle(
          fontFamilyFallback: const ['AnekTamil'],
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textColor.withValues(alpha: isDark ? 0.88 : 0.92),
          height: 1.75,
        ),
        textAlign: TextAlign.left,
      ),
    );

    return Stack(
      children: [
        content,
        // Top fade
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 36,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    fadeBaseColor.withValues(alpha: isDark ? 0.35 : 0.45),
                    fadeBaseColor.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Bottom fade
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 56,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    fadeBaseColor.withValues(alpha: isDark ? 0.45 : 0.60),
                    fadeBaseColor.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Subtle attribution badge for lyrics provided by LRCLIB, fixed at bottom-right
class _LrcLibAttribution extends StatelessWidget {
  const _LrcLibAttribution();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final textColor = colorScheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(
          alpha: isDark ? 0.70 : 0.85,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lyrics_outlined,
            size: 9,
            color: textColor.withValues(alpha: 0.55),
          ),
          const SizedBox(width: 3.5),
          Text(
            'powered by lrclib',
            style: TextStyle(
              fontFamilyFallback: const ['AnekTamil'],
              fontSize: 8,
              fontWeight: FontWeight.w400,
              color: textColor.withValues(alpha: 0.55),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Automatically selects between synced and plain lyrics display,
/// with a fixed 'powered by LRCLIB' badge pinned at the bottom-right.
class LyricsDisplayWidget extends StatelessWidget {
  const LyricsDisplayWidget({
    super.key,
    required this.lyrics,
    required this.positionDataStream,
    this.songId,
    this.showAttribution = true,
  });

  final String lyrics;
  final Stream<PositionData> positionDataStream;
  final String? songId;
  final bool showAttribution;

  @override
  Widget build(BuildContext context) {
    final lyricsContent = LrcParser.isSynced(lyrics)
        ? SyncedLyricsWidget(
            lyrics: lyrics,
            positionDataStream: positionDataStream,
            songId: songId,
          )
        : PlainLyricsWidget(lyrics: lyrics);

    final content = Stack(
      children: [
        Positioned.fill(child: lyricsContent),
        if (showAttribution)
          const Positioned(
            right: 10,
            bottom: 8,
            child: IgnorePointer(child: _LrcLibAttribution()),
          ),
      ],
    );
    return content;
  }
}
