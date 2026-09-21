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

/// Applies one shared shimmer animation to a complete loading fixture.
///
/// Keeping the controller at the fixture level avoids starting a ticker for
/// every placeholder box in a scrolling list.
class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppTokens.shimmerCycle,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final child = ExcludeSemantics(child: widget.child);

    if (reduceMotion) {
      return child;
    }

    return AnimatedBuilder(
      animation: _controller,
      child: child,
      builder: (context, child) {
        final progress = _controller.value;
        final shimmerStart = progress * 2 - 1;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final colorScheme = Theme.of(context).colorScheme;
            final baseColor = colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.52,
            );
            final highlightColor = colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.9);
            return LinearGradient(
              begin: Alignment(shimmerStart - 0.45, 0),
              end: Alignment(shimmerStart + 0.45, 0),
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.25, 0.5, 0.75],
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

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
    final color = colorScheme.surfaceContainerHighest.withValues(alpha: 0.52);

    if (isCircle) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius:
            borderRadius ?? BorderRadius.circular(AppTokens.radiusSmall),
      ),
    );
  }
}

/// Standard song card skeleton placeholder.
class SongCardSkeleton extends StatelessWidget {
  const SongCardSkeleton({super.key, this.size = AppTokens.songCardSize});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: SizedBox(
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
    return SkeletonShimmer(
      child: SizedBox(
        width: cardWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SkeletonBox(width: avatarSize, height: avatarSize, isCircle: true),
            const SizedBox(height: 8),
            SkeletonBox(
              width: cardWidth * 0.7,
              height: 13,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.pagePadding,
          ),
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
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.pagePadding,
            ),
            itemCount: cardCount,
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppTokens.cardGap),
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
    return SkeletonShimmer(
      child: Padding(
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
      ),
    );
  }
}
