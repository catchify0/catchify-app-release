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
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:catchify/constants/app_tokens.dart';
import 'package:catchify/theme/app_text_styles.dart';
import 'package:catchify/utilities/app_utils.dart';
import 'package:catchify/widgets/playlist_cube.dart';

class AlbumCard extends StatelessWidget {
  const AlbumCard({
    super.key,
    required this.album,
    required this.onTap,
    this.size = AppTokens.albumCardSize,
  });

  final Map album;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fullTitle = album['title']?.toString() ?? '';

    final isSingle = album['isSingle'] == true;
    final rawArtist = getDisplayArtist(album);
    final rawYear = album['year']?.toString().trim() ?? '';

    var displayTitle = fullTitle;
    var subtitle = '';

    if (fullTitle.contains(' - ')) {
      final parts = fullTitle.split(' - ');
      displayTitle = parts[0].replaceAll('(Single)', '').trim();
      final artistPart = parts.sublist(1).join(' - ').trim();
      subtitle = isSingle ? '$artistPart • Single' : artistPart;
    } else {
      displayTitle = fullTitle;
      if (rawArtist.isNotEmpty) {
        if (rawYear.isNotEmpty) {
          subtitle = '$rawArtist • $rawYear';
        } else {
          subtitle = isSingle ? '$rawArtist • Single' : '$rawArtist • Album';
        }
      } else {
        subtitle = isSingle ? 'Single' : 'Album';
      }
    }

    final semanticLabel = rawArtist.isNotEmpty
        ? '$displayTitle, by $rawArtist'
        : displayTitle;

    return Semantics(
      label: semanticLabel,
      button: true,
      child: SizedBox(
        width: size,
        child: Material(
          color: Colors.transparent,
          borderRadius: AppTokens.borderRadiusCard,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: AppTokens.borderRadiusCard,
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) {
                return colorScheme.primary.withValues(alpha: 0.08);
              }
              if (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused)) {
                return colorScheme.primary.withValues(alpha: 0.05);
              }
              return null;
            }),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  PlaylistCube(
                    album,
                    size: size,
                    cubeIcon: FluentIcons.album_24_filled,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    displayTitle,
                    style: AppTextStyles.cardTitle.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.cardSubtitle.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
