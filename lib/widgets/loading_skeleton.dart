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

/// Base placeholder box with rounded corners and consistent placeholder color.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
    this.isCircle = false,
  });

  final double width;
  final double height;
  final BorderRadiusGeometry? borderRadius;
  final bool isCircle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);

    if (isCircle) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius ?? BorderRadius.circular(AppTokens.radiusSmall),
      ),
    );
  }
}

/// Standard song card skeleton placeholder.
class SongCardSkeleton extends StatelessWidget {
  const SongCardSkeleton({
    super.key,
    this.size = AppTokens.songCardSize,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SkeletonBox(
            width: size,
            height: size,
            borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          ),
          const SizedBox(height: 8),
          SkeletonBox(
            width: size * 0.85,
            height: 14,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 5),
          SkeletonBox(
            width: size * 0.55,
            height: 12,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}

/// Standard artist avatar skeleton placeholder.
class ArtistCardSkeleton extends StatelessWidget {
  const ArtistCardSkeleton({
    super.key,
    this.avatarSize = AppTokens.artistAvatarSize,
    this.cardWidth = AppTokens.artistCardWidth,
  });

  final double avatarSize;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: cardWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SkeletonBox(
            width: avatarSize,
            height: avatarSize,
            isCircle: true,
          ),
          const SizedBox(height: 8),
          SkeletonBox(
            width: cardWidth * 0.7,
            height: 13,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}

/// Standard horizontal shelf skeleton with header and cards.
class ShelfSkeleton extends StatelessWidget {
  const ShelfSkeleton({
    super.key,
    this.cardCount = 4,
    this.cardSize = AppTokens.songCardSize,
    this.isArtist = false,
  });

  final int cardCount;
  final double cardSize;
  final bool isArtist;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.pagePadding),
          child: SkeletonBox(
            width: 130,
            height: 20,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: AppTokens.titleBottomGap),
        SizedBox(
          height: isArtist ? 130 : cardSize + 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.pagePadding),
            itemCount: cardCount,
            separatorBuilder: (_, __) => const SizedBox(width: AppTokens.cardGap),
            itemBuilder: (_, __) => isArtist
                ? const ArtistCardSkeleton()
                : SongCardSkeleton(size: cardSize),
          ),
        ),
      ],
    );
  }
}

/// Standard song row skeleton for track lists.
class SongRowSkeleton extends StatelessWidget {
  const SongRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.pagePadding,
        vertical: 6,
      ),
      child: Row(
        children: [
          SkeletonBox(
            width: AppTokens.songRowArtworkSize,
            height: AppTokens.songRowArtworkSize,
            borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SkeletonBox(
                  width: double.infinity,
                  height: 14,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 6),
                SkeletonBox(
                  width: 140,
                  height: 12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SkeletonBox(
            width: 24,
            height: 24,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      ),
    );
  }
}
