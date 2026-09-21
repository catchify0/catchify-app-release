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
import 'package:go_router/go_router.dart';
import 'package:catchify/constants/app_tokens.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/theme/app_text_styles.dart';
import 'package:catchify/utilities/artwork_provider.dart';

class ArtistCard extends StatelessWidget {
  const ArtistCard({
    super.key,
    required this.artist,
    this.avatarSize = AppTokens.artistAvatarSize,
    this.cardWidth = AppTokens.artistCardWidth,
  });

  final Map<String, dynamic> artist;
  final double avatarSize;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = artist['title']?.toString() ?? context.l10n!.artist;
    final image = artist['image']?.toString();
    final artistId =
        artist['ytid']?.toString() ?? artist['title']?.toString() ?? '';

    return Semantics(
      label: '$title, ${context.l10n?.artist ?? 'Artist'}',
      button: true,
      child: SizedBox(
        width: cardWidth,
        child: Material(
          color: Colors.transparent,
          borderRadius: AppTokens.borderRadiusLarge,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: AppTokens.borderRadiusLarge,
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
            onTap: () {
              if (artistId.isEmpty) return;
              context.push(
                '/home/artist/${Uri.encodeComponent(artistId)}',
                extra: artist,
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: image != null && image.isNotEmpty
                          ? Image(
                              image: ArtworkProvider.get(image),
                              width: avatarSize,
                              height: avatarSize,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildFallback(colorScheme),
                            )
                          : _buildFallback(colorScheme),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: AppTextStyles.cardTitle.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n!.artist,
                    style: AppTextStyles.captionMedium.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
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

  Widget _buildFallback(ColorScheme colorScheme) {
    return Container(
      width: avatarSize,
      height: avatarSize,
      color: colorScheme.surfaceContainerHigh,
      child: Center(
        child: Icon(
          FluentIcons.person_24_filled,
          size: avatarSize * 0.45,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
