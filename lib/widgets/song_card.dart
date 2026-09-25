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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:catchify/constants/app_tokens.dart';
import 'package:catchify/services/artwork_service.dart';
import 'package:catchify/theme/app_text_styles.dart';
import 'package:catchify/utilities/app_utils.dart';
import 'package:catchify/widgets/playlist_artwork.dart';

/// Clean, music-first Song card.
/// Artwork is the hero without unnecessary floating overlays.
class SongCard extends StatelessWidget {
  const SongCard({
    super.key,
    required this.song,
    required this.onTap,
    this.size = AppTokens.songCardSize,
    this.rank,
  });

  final Map song;
  final VoidCallback onTap;
  final double size;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = song['title']?.toString() ?? '';
    final artist = getDisplayArtist(song);

    final rawUrl =
        (song['highResImage'] ?? song['image'] ?? song['lowResImage'] ?? '')
            .toString();
    final isHorizontal = ArtworkService.isYouTubeThumbnailUrl(rawUrl);
    final cardWidth = isHorizontal ? 180.0 : size;
    final artworkHeight = isHorizontal
        ? (180.0 * 9 / 16).roundToDouble()
        : size;

    final semanticLabel = artist.isNotEmpty ? '$title, by $artist' : title;

    return Semantics(
      label: semanticLabel,
      button: true,
      child: SizedBox(
        width: cardWidth,
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
                                song['highResImage'] ?? song['image'],
                            playlistTitle: title,
                            size: size,
                            width: cardWidth,
                            height: artworkHeight,
                            cubeIcon: FluentIcons.music_note_2_24_filled,
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
                        if (rank != null)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: rank! <= 3
                                    ? colorScheme.primary
                                    : colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#$rank',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: rank! <= 3
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurface,
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
                  const SizedBox(height: 2),
                  Text(
                    artist,
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
