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

import 'package:flutter/material.dart';
import 'package:catchify/main.dart';
import 'package:catchify/models/position_data.dart';
import 'package:catchify/utilities/formatter.dart';

class PositionSlider extends StatefulWidget {
  const PositionSlider({super.key});

  @override
  State<PositionSlider> createState() => _PositionSliderState();
}

class _PositionSliderState extends State<PositionSlider> {
  bool _isDragging = false;
  double _dragValue = 0;
  double? _dragEndValue;
  DateTime? _dragEndTime;
  Object? _currentMediaId;
  PositionData _positionData = PositionData(
    Duration.zero,
    Duration.zero,
    Duration.zero,
  );

  @override
  void initState() {
    super.initState();
    _currentMediaId = audioHandler.mediaItem.valueOrNull?.id;
    _positionData = PositionData(
      audioHandler.playbackState.value.position,
      audioHandler.playbackState.value.bufferedPosition,
      audioHandler.mediaItem.valueOrNull?.duration ?? Duration.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PositionData>(
      initialData: _positionData,
      stream: audioHandler.positionDataStream,
      builder: (context, snapshot) {
        final mediaId = audioHandler.mediaItem.valueOrNull?.id;
        if (mediaId != _currentMediaId) {
          _currentMediaId = mediaId;
          _isDragging = false;
          _dragEndValue = null;
          _positionData = PositionData(
            Duration.zero,
            Duration.zero,
            Duration.zero,
          );
        }

        if (snapshot.data != null) {
          _positionData = snapshot.data!;
        }

        // If user recently seeked, hold the target position until the stream catches up
        if (_dragEndValue != null) {
          final diff = (_positionData.position.inSeconds - _dragEndValue!)
              .abs();
          final elapsed = _dragEndTime != null
              ? DateTime.now().difference(_dragEndTime!).inMilliseconds
              : 1000;
          if (diff <= 1 || elapsed > 800) {
            _dragEndValue = null;
          }
        }

        final maxDuration = _positionData.duration.inSeconds > 0
            ? _positionData.duration.inSeconds.toDouble()
            : 1.0;

        final currentValue = _isDragging
            ? _dragValue
            : (_dragEndValue ?? _positionData.position.inSeconds.toDouble());

        final colorScheme = Theme.of(context).colorScheme;

        return RepaintBoundary(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: colorScheme.primary,
                  inactiveTrackColor: colorScheme.surfaceContainerHighest,
                  secondaryActiveTrackColor: colorScheme.primary.withValues(
                    alpha: 0.75,
                  ),
                  thumbColor: colorScheme.primary,
                  overlayColor: colorScheme.primary.withValues(alpha: 0.14),
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16,
                  ),
                  valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
                ),
                child: Slider(
                  value: currentValue.clamp(0.0, maxDuration),
                  onChanged: (value) {
                    setState(() {
                      _isDragging = true;
                      _dragValue = value;
                      _dragEndValue = null;
                    });
                  },
                  onChangeEnd: (value) {
                    _dragEndValue = value;
                    _dragEndTime = DateTime.now();
                    audioHandler.seek(Duration(seconds: value.toInt()));
                    setState(() {
                      _isDragging = false;
                    });
                  },
                  max: maxDuration,
                  semanticFormatterCallback: (value) =>
                      formatDuration(value.toInt()),
                ),
              ),
              _buildPositionRow(context, _positionData),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPositionRow(BuildContext context, PositionData positionData) {
    final currentSeconds = _isDragging
        ? _dragValue.toInt()
        : (_dragEndValue?.toInt() ?? positionData.position.inSeconds);
    final maxSeconds = positionData.duration.inSeconds;
    final displaySeconds = (maxSeconds > 0 && currentSeconds > maxSeconds)
        ? maxSeconds
        : (currentSeconds < 0 ? 0 : currentSeconds);

    final positionText = formatDuration(displaySeconds);
    final durationText = formatDuration(maxSeconds);
    final timeStyle = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: Theme.of(
        context,
      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
      letterSpacing: 0.2,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(positionText, style: timeStyle),
          Text(durationText, style: timeStyle),
        ],
      ),
    );
  }
}
