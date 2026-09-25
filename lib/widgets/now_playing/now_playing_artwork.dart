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
import 'dart:io';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:catchify/services/artwork_service.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/widgets/song_artwork.dart';

/// Displays the now-playing artwork with volume gesture support.
/// Adapts dynamically to square (1:1) and horizontal (16:9) artwork aspect ratios.
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
  double? _artworkAspectRatio;
  String? _lastResolvedUri;

  @override
  void initState() {
    super.initState();
    _checkAspectRatio();
  }

  @override
  void didUpdateWidget(NowPlayingArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metadata.artUri != widget.metadata.artUri ||
        oldWidget.metadata.id != widget.metadata.id) {
      _checkAspectRatio();
    }
  }

  @override
  void dispose() {
    _volumeHUDTimer?.cancel();
    super.dispose();
  }

  void _checkAspectRatio() {
    final uriStr =
        widget.metadata.artUri?.toString() ??
        widget.metadata.extras?['highResImage']?.toString() ??
        widget.metadata.extras?['image']?.toString() ??
        '';

    if (uriStr == _lastResolvedUri && _artworkAspectRatio != null) return;
    _lastResolvedUri = uriStr;

    if (uriStr.isEmpty) {
      _artworkAspectRatio = 1;
      return;
    }

    // Google User Content artwork is always 1:1 square
    if (ArtworkService.isGoogleArtworkUrl(uriStr)) {
      _artworkAspectRatio = 1;
      return;
    }

    // YouTube thumbnails are standard 16:9 horizontal
    if (ArtworkService.isYouTubeThumbnailUrl(uriStr)) {
      _artworkAspectRatio = 16 / 9;
      return;
    }

    // For local files or other image sources, inspect the decoded frame aspect ratio
    ImageProvider? provider;
    if (widget.metadata.artUri?.scheme == 'file') {
      try {
        final filePath = widget.metadata.artUri!.toFilePath();
        final file = File(filePath);
        if (file.existsSync()) {
          provider = FileImage(file);
        }
      } catch (_) {}
    } else if (uriStr.startsWith('http')) {
      provider = CachedNetworkImageProvider(uriStr);
    }

    if (provider != null) {
      provider
          .resolve(ImageConfiguration.empty)
          .addListener(
            ImageStreamListener((ImageInfo info, bool _) {
              if (!mounted) return;
              final w = info.image.width;
              final h = info.image.height;
              if (w > 0 && h > 0) {
                final ratio = w / h;
                if (_artworkAspectRatio == null ||
                    (_artworkAspectRatio! - ratio).abs() > 0.05) {
                  setState(() {
                    _artworkAspectRatio = ratio;
                  });
                }
              }
            }),
          );
    } else {
      _artworkAspectRatio = 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    const borderRadius = 16.0;
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = widget.size.width;
    final screenHeight = widget.size.height;
    final isLandscape = screenWidth > screenHeight;
    final isDesktop = screenWidth > 800;

    final ratio = _artworkAspectRatio ?? 1.0;
    final isHorizontal = ratio > 1.15;

    final double maxW;
    final double maxH;

    if (isDesktop) {
      maxH = screenHeight * 0.45;
      maxW = screenWidth * 0.50;
    } else if (isLandscape) {
      maxH = screenHeight * 0.50;
      maxW = screenWidth * 0.45;
    } else if (screenWidth < 360) {
      maxW = screenWidth * 0.85;
      maxH = screenHeight * 0.38;
    } else if (screenWidth < 600) {
      maxW = screenWidth * 0.88;
      maxH = screenHeight * 0.40;
    } else {
      maxW = screenWidth * 0.70;
      maxH = screenHeight * 0.42;
    }

    double artworkWidth;
    double artworkHeight;

    if (isHorizontal) {
      artworkWidth = maxW;
      artworkHeight = artworkWidth / ratio;
      if (artworkHeight > maxH) {
        artworkHeight = maxH;
        artworkWidth = artworkHeight * ratio;
      }
    } else {
      final size = math.min(maxW, maxH);
      artworkWidth = size;
      artworkHeight = size;
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: (details) async {
        if (!volumeGestureEnabled.value) return;
        try {
          final vol = await VolumeController.instance.getVolume();
          if (!mounted) return;
          _currentVolume = vol;
          VolumeController.instance.showSystemUI = false;
          _volumeHUDTimer?.cancel();
          setState(() => _showVolumeHUD = true);
        } catch (_) {}
      },
      onVerticalDragUpdate: (details) {
        if (!volumeGestureEnabled.value) return;
        try {
          final delta = -details.primaryDelta! / 220;
          _currentVolume = (_currentVolume + delta).clamp(0, 1);
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
              child: SizedBox(
                width: artworkWidth,
                height: artworkHeight,
                child: SongArtworkWidget(
                  metadata: widget.metadata,
                  width: artworkWidth,
                  height: artworkHeight,
                  size: math.max(artworkWidth, artworkHeight),
                  errorWidgetIconSize: widget.size.width / 8,
                  borderRadius: borderRadius,
                ),
              ),
            ),
          ),
          if (_showVolumeHUD)
            Positioned(
              width: artworkWidth,
              height: artworkHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
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
                        width: artworkWidth * 0.55,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _currentVolume,
                            minHeight: 6,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.3,
                            ),
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
            ),
        ],
      ),
    );
  }
}
