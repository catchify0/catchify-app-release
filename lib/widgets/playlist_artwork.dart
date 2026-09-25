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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:catchify/utilities/artwork_provider.dart';
import 'package:catchify/widgets/no_artwork_cube.dart';
import 'package:catchify/widgets/playlist_collage.dart';

class PlaylistArtwork extends StatelessWidget {
  const PlaylistArtwork({
    super.key,
    required this.playlistArtwork,
    this.playlistTitle,
    this.songs,
    this.cubeIcon = FluentIcons.text_bullet_list_24_filled,
    this.iconSize,
    this.size = 220,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String? playlistArtwork;
  final String? playlistTitle;
  final List<dynamic>? songs;
  final IconData cubeIcon;
  final double? iconSize;
  final double size;
  final double? width;
  final double? height;
  final BoxFit fit;

  Widget _nullArtwork([double? effectiveWidth, double? effectiveHeight]) {
    final w = effectiveWidth ?? width ?? size;
    final h = effectiveHeight ?? height ?? size;
    return NullArtworkWidget(
      icon: cubeIcon,
      iconSize: iconSize ?? (h * 0.3),
      size: size,
      width: w,
      height: h,
      title: playlistTitle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width ?? size;
    final effectiveHeight = height ?? size;
    final image = playlistArtwork;
    if (image == null || image.isEmpty) {
      if (songs != null && songs!.isNotEmpty) {
        final songArtworks = songs!
            .map(
              (s) =>
                  (s is Map
                      ? (s['highResImage'] ?? s['image'])?.toString()
                      : null) ??
                  '',
            )
            .where((u) => u.isNotEmpty)
            .toSet()
            .toList();
        if (songArtworks.isNotEmpty) {
          return PlaylistCollage(
            imageUrls: songArtworks,
            size: size,
            fallback: _nullArtwork(effectiveWidth, effectiveHeight),
          );
        }
      }
      return _nullArtwork(effectiveWidth, effectiveHeight);
    }

    try {
      final provider = ArtworkProvider.get(image);

      final imageWidget = Image(
        image: provider,
        height: effectiveHeight,
        width: effectiveWidth,
        fit: fit,
        errorBuilder: (_, __, ___) =>
            _nullArtwork(effectiveWidth, effectiveHeight),
      );

      return SizedBox(
        width: effectiveWidth,
        height: effectiveHeight,
        child: imageWidget,
      );
    } catch (_) {
      return _nullArtwork(effectiveWidth, effectiveHeight);
    }
  }
}
