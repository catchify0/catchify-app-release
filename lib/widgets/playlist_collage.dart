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
 */

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:catchify/utilities/artwork_provider.dart';

class PlaylistCollage extends StatelessWidget {
  const PlaylistCollage({
    super.key,
    required this.imageUrls,
    required this.size,
    required this.fallback,
  });

  final List<String> imageUrls;
  final double size;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final placeholderBg = colorScheme.surfaceContainerHigh;
    final placeholderIcon = colorScheme.onSurfaceVariant;
    final validUrls = imageUrls.where((url) => url.isNotEmpty).take(4).toList();

    if (validUrls.isEmpty) {
      return fallback;
    }

    if (validUrls.length < 4) {
      // 1 to 3 songs: display first song artwork full size
      return _buildImage(
        validUrls.first,
        size,
        size,
        placeholderBg,
        placeholderIcon,
      );
    }

    // Exactly 4 artworks in a clean 2x2 grid (Youtify collage concept)
    final halfSize = size / 2;
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        children: [
          Row(
            children: [
              _buildImage(
                validUrls[0],
                halfSize,
                halfSize,
                placeholderBg,
                placeholderIcon,
              ),
              _buildImage(
                validUrls[1],
                halfSize,
                halfSize,
                placeholderBg,
                placeholderIcon,
              ),
            ],
          ),
          Row(
            children: [
              _buildImage(
                validUrls[2],
                halfSize,
                halfSize,
                placeholderBg,
                placeholderIcon,
              ),
              _buildImage(
                validUrls[3],
                halfSize,
                halfSize,
                placeholderBg,
                placeholderIcon,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImage(
    String url,
    double width,
    double height,
    Color placeholderBg,
    Color placeholderIcon,
  ) {
    try {
      final img = Image(
        image: ArtworkProvider.get(url),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: width,
          height: height,
          color: placeholderBg,
          child: Icon(
            FluentIcons.music_note_2_24_regular,
            color: placeholderIcon,
            size: 16,
          ),
        ),
      );

      return SizedBox(width: width, height: height, child: img);
    } catch (_) {
      return Container(width: width, height: height, color: placeholderBg);
    }
  }
}
