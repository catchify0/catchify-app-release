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
import 'package:catchify/utilities/app_utils.dart';
import 'package:catchify/utilities/artwork_provider.dart';

class TopResultCard extends StatelessWidget {
  const TopResultCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onPlay,
  });

  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final category =
        item['topResultCategory']?.toString() ??
        (item['isArtist'] == true
            ? 'Artist'
            : (item['isAlbum'] == true
                  ? 'Album'
                  : (item['isVideo'] == true ? 'Video' : 'Song')));

    final isArtist = category.toLowerCase() == 'artist';
    final title = item['title']?.toString() ?? item['name']?.toString() ?? '';
    final subtitle = getDisplayArtist(item, fallback: isArtist ? 'Artist' : '');

    final artwork =
        item['highResImage']?.toString() ??
        item['image']?.toString() ??
        item['lowResImage']?.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withValues(alpha: 0.1),
              colorScheme.surfaceContainerLow,
            ],
          ),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOP RESULT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: colorScheme.primary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _buildArtwork(artwork, isArtist, colorScheme),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            if (onPlay != null)
                              FilledButton.tonalIcon(
                                onPressed: onPlay,
                                icon: const Icon(
                                  FluentIcons.play_20_filled,
                                  size: 18,
                                ),
                                label: const Text('Play'),
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                ),
                              )
                            else
                              FilledButton.tonalIcon(
                                onPressed: onTap,
                                icon: Icon(
                                  isArtist
                                      ? FluentIcons.person_20_regular
                                      : FluentIcons.arrow_right_20_regular,
                                  size: 18,
                                ),
                                label: Text(isArtist ? 'View Artist' : 'Open'),
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtwork(
    String? artwork,
    bool isArtist,
    ColorScheme colorScheme,
  ) {
    const size = 86.0;
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(
          isArtist
              ? FluentIcons.person_24_filled
              : FluentIcons.music_note_2_24_filled,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );

    if (artwork == null || artwork.trim().isEmpty) {
      return isArtist
          ? ClipOval(child: placeholder)
          : ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: placeholder,
            );
    }

    try {
      final imageWidget = Image(
        image: ArtworkProvider.get(artwork),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      );

      return isArtist
          ? ClipOval(child: imageWidget)
          : ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: imageWidget,
            );
    } catch (_) {
      return isArtist
          ? ClipOval(child: placeholder)
          : ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: placeholder,
            );
    }
  }
}
