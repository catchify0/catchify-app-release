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

import 'dart:io';
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// An immersive, Apple Music / iOS-style ambient blurred artwork background.
///
/// Dynamically extracts and blurs the current song's album artwork colors into a rich,
/// fluid background for both the Now Playing page and Lyrics mode.
class NowPlayingAmbientBackground extends StatelessWidget {
  const NowPlayingAmbientBackground({
    super.key,
    required this.metadata,
    this.isPureBlack = false,
    this.lyricsProgress = 0.0,
  });

  final MediaItem? metadata;
  final bool isPureBlack;
  final double lyricsProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // OLED pure black is strictly a Dark Mode feature
    if (isPureBlack && isDark) {
      return const ColoredBox(color: Colors.black);
    }

    final colorScheme = theme.colorScheme;

    final imageProvider = _resolveImageProvider(metadata);
    final songKey = metadata != null
        ? (metadata!.id.isNotEmpty
              ? metadata!.id
              : '${metadata!.artist ?? ''}-${metadata!.title}')
        : 'none';

    // Gradients tailored for Apple Music style contrast:
    // In Dark Mode: dark vignette overlay so light controls pop.
    // In Light Mode: frosted luminous white/surface overlay so dark controls pop.
    final List<Color> gradientColors;
    if (isDark) {
      final topAlpha = lerpDouble(0.35, 0.48, lyricsProgress) ?? 0.35;
      final midAlpha = lerpDouble(0.55, 0.68, lyricsProgress) ?? 0.55;
      final bottomAlpha = lerpDouble(0.85, 0.94, lyricsProgress) ?? 0.85;
      gradientColors = [
        Colors.black.withValues(alpha: topAlpha),
        Colors.black.withValues(alpha: midAlpha),
        Colors.black.withValues(alpha: bottomAlpha),
      ];
    } else {
      // Light Mode: Apple Music frosted luminous white & surface wash
      final topAlpha = lerpDouble(0.38, 0.52, lyricsProgress) ?? 0.38;
      final midAlpha = lerpDouble(0.60, 0.74, lyricsProgress) ?? 0.60;
      final bottomAlpha = lerpDouble(0.88, 0.96, lyricsProgress) ?? 0.88;
      gradientColors = [
        Colors.white.withValues(alpha: topAlpha),
        Colors.white.withValues(alpha: midAlpha),
        colorScheme.surface.withValues(alpha: bottomAlpha),
      ];
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Base tone matching theme surface
        ColoredBox(color: colorScheme.surface),

        // Blurred artwork layer with smooth crossfade between songs
        RepaintBoundary(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 700),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: imageProvider != null
                ? ClipRect(
                    key: ValueKey<String>('art_$songKey'),
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: 70,
                        sigmaY: 70,
                        tileMode: TileMode.mirror,
                      ),
                      child: Transform.scale(
                        scale: 1.35,
                        child: Image(
                          image: imageProvider,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) =>
                              _fallbackGradient(colorScheme, isDark),
                        ),
                      ),
                    ),
                  )
                : _fallbackGradient(
                    colorScheme,
                    isDark,
                    key: const ValueKey('fallback'),
                  ),
          ),
        ),

        // Apple Music contrast vignette overlay (adapts to light / dark)
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientColors,
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  ImageProvider? _resolveImageProvider(MediaItem? item) {
    if (item == null) return null;

    if (item.artUri?.scheme == 'file') {
      try {
        final filePath = item.artUri?.toFilePath();
        if (filePath != null && File(filePath).existsSync()) {
          return ResizeImage(
            FileImage(File(filePath)),
            width: 180,
            height: 180,
          );
        }
      } catch (_) {}
    }

    final imageUrl =
        item.artUri?.toString() ??
        item.extras?['image']?.toString() ??
        item.extras?['highResImage']?.toString();

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CachedNetworkImageProvider(
        imageUrl,
        maxWidth: 180,
        maxHeight: 180,
      );
    }

    return null;
  }

  Widget _fallbackGradient(ColorScheme colorScheme, bool isDark, {Key? key}) {
    return Container(
      key: key,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [
            colorScheme.primary.withValues(alpha: isDark ? 0.35 : 0.22),
            colorScheme.surface,
          ],
        ),
      ),
    );
  }
}
