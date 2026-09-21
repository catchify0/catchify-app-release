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
 *     For more information about Catchify, including how to contribute,
 *     please visit: https://github.com/catchify0/catchify0.github.io
 */

import 'package:flutter/material.dart';
import 'package:catchify/constants/app_tokens.dart';
import 'package:catchify/theme/app_text_styles.dart';
import 'package:catchify/utilities/app_utils.dart';
import 'package:catchify/widgets/playlist_artwork.dart';

/// Standardized music-first Playlist card.
/// Artwork is the hero, followed by title and optional creator/subtitle.
class PlaylistCard extends StatelessWidget {
  const PlaylistCard({
    super.key,
    required this.playlist,
    required this.onTap,
    this.size = AppTokens.playlistCardSize,
  });

  final Map playlist;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = playlist['title']?.toString() ?? '';
    final creator = getDisplayArtist(playlist);

    final semanticLabel = creator.isNotEmpty
        ? '$title, playlist by $creator'
        : '$title, playlist';

    return Semantics(
      label: semanticLabel,
      button: true,
      child: SizedBox(
        width: size,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTokens.radiusCard),
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
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.14),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusCard,
                          ),
                          child: PlaylistArtwork(
                            playlistArtwork:
                                playlist['highResImage'] ?? playlist['image'],
                            playlistTitle: title,
                            songs: playlist['list'] as List<dynamic>?,
                            size: size,
                          ),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusCard,
                              ),
                              border: Border.all(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: AppTextStyles.cardTitle.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (creator.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      creator,
                      style: AppTextStyles.cardSubtitle.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
