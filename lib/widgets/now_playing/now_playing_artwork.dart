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
import 'package:volume_controller/volume_controller.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/widgets/song_artwork.dart';

/// Displays the now-playing artwork with volume gesture support.
/// Lyrics mode is hosted in NowPlayingPage.
class NowPlayingArtwork extends StatefulWidget {
  const NowPlayingArtwork({
    super.key,
    required this.size,
    required this.metadata,
    this.artworkKey,
  });

  final Size size;
  final MediaItem metadata;
  final Key? artworkKey;

  @override
  State<NowPlayingArtwork> createState() => _NowPlayingArtworkState();
}

class _NowPlayingArtworkState extends State<NowPlayingArtwork> {
  double _currentVolume = 0.5;
  bool _showVolumeHUD = false;
  Timer? _volumeHUDTimer;

  @override
  void dispose() {
    _volumeHUDTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const borderRadius = 16.0;
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = widget.size.width;
    final screenHeight = widget.size.height;
    final isLandscape = screenWidth > screenHeight;
    final isDesktop = screenWidth > 800;
    final imageSize = isDesktop
        ? screenHeight * 0.38
        : isLandscape
            ? screenHeight * 0.45
            : screenWidth < 360
                ? screenWidth * 0.75
                : screenWidth < 600
                    ? screenWidth * 0.80
                    : screenWidth * 0.65;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: (details) async {
        if (!volumeGestureEnabled.value) return;
        try {
          _currentVolume = await VolumeController.instance.getVolume();
          VolumeController.instance.showSystemUI = false;
          _volumeHUDTimer?.cancel();
          setState(() => _showVolumeHUD = true);
        } catch (_) {}
      },
      onVerticalDragUpdate: (details) {
        if (!volumeGestureEnabled.value) return;
        try {
          final delta = -details.primaryDelta! / 220.0;
          _currentVolume = (_currentVolume + delta).clamp(0.0, 1.0);
          VolumeController.instance.setVolume(_currentVolume);
          setState(() => _showVolumeHUD = true);
        } catch (_) {}
      },
      onVerticalDragEnd: (details) {
        if (!volumeGestureEnabled.value) return;
        _volumeHUDTimer?.cancel();
        _volumeHUDTimer = Timer(const Duration(milliseconds: 1200), () {
          if (mounted) setState(() => _showVolumeHUD = false);
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            key: widget.artworkKey,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.28),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.32),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: SongArtworkWidget(
                metadata: widget.metadata,
                size: imageSize,
                errorWidgetIconSize: widget.size.width / 8,
                borderRadius: borderRadius,
              ),
            ),
          ),
          if (_showVolumeHUD)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _currentVolume <= 0.01
                          ? FluentIcons.speaker_mute_24_filled
                          : _currentVolume < 0.4
                              ? FluentIcons.speaker_0_24_filled
                              : _currentVolume < 0.7
                                  ? FluentIcons.speaker_1_24_filled
                                  : FluentIcons.speaker_2_24_filled,
                      size: 42,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${(_currentVolume * 100).round()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: imageSize * 0.55,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _currentVolume,
                          minHeight: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
