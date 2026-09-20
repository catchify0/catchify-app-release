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
import 'package:flutter/rendering.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart' show audioHandler;
import 'package:catchify/models/lyric_line.dart';
import 'package:catchify/models/position_data.dart';

/// Displays synced lyrics with real-time highlighting and auto-scrolling.
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
  late List<LyricLine> _lines;
  final ScrollController _scrollController = ScrollController();
  int _currentLineIndex = -1;
  StreamSubscription<PositionData>? _positionSub;
  bool _isUserScrolling = false;
  Timer? _scrollPauseTimer;

  // Each lyric row: a generous fixed height so multi-line text doesn't overflow.
  static const double _rowHeight = 64;
  static const double _verticalPadding = 28;

  @override
  void initState() {
    super.initState();
    _lines = LrcParser.parse(widget.lyrics);
    _subscribe();

    // Snap to the correct line immediately when lyrics first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final currentPos = audioHandler.playbackState.value.position;
        _onPositionMs(currentPos.inMilliseconds);
      } catch (_) {
        // audioHandler may not be available in unit tests; ignore silently.
      }
    });
  }

  @override
  void didUpdateWidget(SyncedLyricsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lyrics != widget.lyrics) {
      _lines = LrcParser.parse(widget.lyrics);
      _currentLineIndex = -1;
      _scrollPauseTimer?.cancel();
      _isUserScrolling = false;
      // Re-snap to correct position for the new lyrics set.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          final currentPos = audioHandler.playbackState.value.position;
          _onPositionMs(currentPos.inMilliseconds);
        } catch (_) {}
      });
    }
    if (oldWidget.positionDataStream != widget.positionDataStream) {
      _unsubscribe();
      _subscribe();
    }
  }

  void _subscribe() {
    _positionSub = widget.positionDataStream.listen(_onPositionUpdate);
  }

  void _unsubscribe() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  /// Called on every position-stream tick.
  void _onPositionUpdate(PositionData data) {
    _onPositionMs(data.position.inMilliseconds);
  }

  /// Core highlight logic — works with raw milliseconds.
  void _onPositionMs(int posMs) {
    if (!mounted) return;
    final newIndex = LrcParser.findCurrentLineIndex(_lines, posMs);

    if (newIndex != _currentLineIndex) {
      setState(() {
        _currentLineIndex = newIndex;
      });
      if (newIndex >= 0) {
        _scrollToLine(newIndex);
      }
    }
  }

  void _onScrollNotification(ScrollNotification notification) {
    if (notification is UserScrollNotification) {
      if (notification.direction != ScrollDirection.idle) {
        _scrollPauseTimer?.cancel();
        if (!_isUserScrolling) {
          setState(() {
            _isUserScrolling = true;
          });
        }
      } else {
        _startScrollResumeTimer();
      }
    } else if (notification is ScrollEndNotification) {
      _startScrollResumeTimer();
    }
  }

  void _startScrollResumeTimer() {
    _scrollPauseTimer?.cancel();
    _scrollPauseTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() {
        _isUserScrolling = false;
      });
      if (_currentLineIndex >= 0) {
        _scrollToLine(_currentLineIndex, force: true);
      }
    });
  }

  void _resumeAutoScroll() {
    _scrollPauseTimer?.cancel();
    if (_isUserScrolling) {
      setState(() {
        _isUserScrolling = false;
      });
    }
    if (_currentLineIndex >= 0) {
      _scrollToLine(_currentLineIndex, force: true);
    }
  }

  void _scrollToLine(int index, {bool force = false}) {
    if (!force && _isUserScrolling) return;
    if (index < 0 || !_scrollController.hasClients) return;
    final position = _scrollController.position;

    // Target: precisely center the active line in the visible area accounting for vertical padding
    final viewportHeight = position.viewportDimension;
    final target = _verticalPadding +
        (index * _rowHeight) -
        (viewportHeight / 2) +
        (_rowHeight / 2);
    final safeTarget = target.clamp(0.0, position.maxScrollExtent);

    if ((safeTarget - position.pixels).abs() > 2) {
      _scrollController.animateTo(
        safeTarget,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollPauseTimer?.cancel();
    _unsubscribe();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_lines.isEmpty) return _buildEmpty(context);
    return _buildList(context);
  }

  Widget _buildEmpty(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSecondaryContainer;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FluentIcons.music_note_2_24_regular, size: 48, color: color.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            context.l10n!.lyricsNotAvailable,
            style: TextStyle(
              fontFamilyFallback: const ['AnekTamil'],
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSecondaryContainer;
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            _onScrollNotification(notification);
            return false;
          },
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(
              top: _verticalPadding,
              bottom: _verticalPadding + 32,
              left: 20,
              right: 20,
            ),
            physics: const BouncingScrollPhysics(),
            itemCount: _lines.length,
            itemExtent: _rowHeight,
            itemBuilder: (context, index) {
              final isCurrent = index == _currentLineIndex;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final ms = _lines[index].timeInMs;
                  _scrollPauseTimer?.cancel();
                  setState(() {
                    _currentLineIndex = index;
                    _isUserScrolling = false;
                  });
                  _scrollToLine(index, force: true);
                  audioHandler.seek(Duration(milliseconds: ms));
                },
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    style: isCurrent
                        ? TextStyle(
                            fontFamilyFallback: const ['AnekTamil'],
                            fontSize: 18.5,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            height: 1.4,
                            letterSpacing: -0.2,
                          )
                        : TextStyle(
                            fontFamilyFallback: const ['AnekTamil'],
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: textColor.withValues(alpha: 0.40),
                            height: 1.4,
                          ),
                    child: Text(
                      _lines[index].text,
                      textAlign: TextAlign.left,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_isUserScrolling)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _resumeAutoScroll,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.sync,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Sync paused • Tap to resume',
                        style: TextStyle(
                          fontFamilyFallback: const ['AnekTamil'],
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
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

/// Displays plain (non-synced) lyrics as scrollable text
class PlainLyricsWidget extends StatelessWidget {
  const PlainLyricsWidget({super.key, required this.lyrics});

  final String lyrics;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSecondaryContainer;
    final cleanLyricsText = LrcParser.cleanLyrics(lyrics);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(
        top: 28,
        bottom: 50,
        left: 20,
        right: 20,
      ),
      physics: const BouncingScrollPhysics(),
      child: Text(
        cleanLyricsText.isNotEmpty ? cleanLyricsText : lyrics,
        style: TextStyle(
          fontFamilyFallback: const ['AnekTamil'],
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textColor.withValues(alpha: 0.90),
          height: 1.8,
        ),
        textAlign: TextAlign.left,
      ),
    );
  }
}

/// Subtle attribution badge for lyrics provided by LRCLIB, fixed at bottom-right
class _LrcLibAttribution extends StatelessWidget {
  const _LrcLibAttribution();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = colorScheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lyrics_outlined,
            size: 9,
            color: textColor.withValues(alpha: 0.40),
          ),
          const SizedBox(width: 3.5),
          Text(
            'powered by lrclib',
            style: TextStyle(
              fontFamilyFallback: const ['AnekTamil'],
              fontSize: 8,
              fontWeight: FontWeight.w400,
              color: textColor.withValues(alpha: 0.40),
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
  });

  final String lyrics;
  final Stream<PositionData> positionDataStream;
  final String? songId;

  @override
  Widget build(BuildContext context) {
    final lyricsContent = LrcParser.isSynced(lyrics)
        ? SyncedLyricsWidget(
            lyrics: lyrics,
            positionDataStream: positionDataStream,
            songId: songId,
          )
        : PlainLyricsWidget(lyrics: lyrics);

    return Stack(
      children: [
        Positioned.fill(child: lyricsContent),
        const Positioned(
          right: 10,
          bottom: 8,
          child: IgnorePointer(
            child: _LrcLibAttribution(),
          ),
        ),
      ],
    );
  }
}
