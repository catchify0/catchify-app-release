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

import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:catchify/constants/app_tokens.dart';
import 'package:catchify/theme/app_colors.dart';

/// A bounded, high-performance frosted glass surface for Catchify.
///
/// Implements layered glass optics according to the Catchify design system:
/// 1. Bounded clipping to the specified [borderRadius].
/// 2. Sampled backdrop blur via [BackdropFilter].
/// 3. Translucent optical tint derived from the active surface role.
/// 4. Subtle directional edge highlight border for contrast on deep backgrounds.
/// 5. Graceful fallback when reduced transparency or high contrast is enabled.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.blur = 18,
    this.surfaceColor,
    this.borderColor,
    this.borderWidth = 0.8,
    this.padding,
    this.margin,
    this.elevation = 0,
    this.shadowColor,
    this.disableBlur = false,
  });

  /// The child content placed above the optical layers.
  final Widget child;

  /// Corner radius of the glass boundary. Defaults to [AppTokens.borderRadiusMedium].
  final BorderRadius? borderRadius;

  /// Blur intensity (sigma). Defaults to 18.0.
  final double blur;

  /// Custom translucent tint color. Defaults to semantic glass tokens.
  final Color? surfaceColor;

  /// Custom edge highlight color. Defaults to subtle translucent outline.
  final Color? borderColor;

  /// Width of the glass edge highlight.
  final double borderWidth;

  /// Internal padding for the content.
  final EdgeInsetsGeometry? padding;

  /// Margin surrounding the glass boundary.
  final EdgeInsetsGeometry? margin;

  /// Optional shadow elevation behind the glass surface.
  final double elevation;

  /// Optional shadow color.
  final Color? shadowColor;

  /// Whether to force bypass backdrop blur (e.g. for low-power or high-contrast modes).
  final bool disableBlur;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? AppTokens.borderRadiusMedium;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.maybeOf(context);
    final highContrast = mediaQuery?.highContrast ?? false;

    // High-contrast or explicit disable fallback to solid elevated surface
    final shouldBypassBlur = disableBlur || highContrast;

    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final isOled = isDark && scaffoldBg == AppColors.pureBlack;

    final effectiveSurfaceColor =
        surfaceColor ??
        (isDark
            ? (isOled
                  ? (shouldBypassBlur
                        ? AppColors.pureBlackElevated
                        : AppColors.glassSurfaceOled)
                  : (shouldBypassBlur
                        ? AppColors.darkSurfaceElevated
                        : AppColors.glassSurfaceDark))
            : (shouldBypassBlur
                  ? AppColors.lightSurfaceElevated
                  : AppColors.glassSurfaceLight));

    final effectiveBorderColor =
        borderColor ??
        (isDark
            ? (isOled ? AppColors.glassBorderOled : AppColors.glassBorderDark)
            : AppColors.glassBorderLight);

    final surface = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveSurfaceColor,
        borderRadius: effectiveRadius,
      ),
      child: child,
    );

    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            effectiveBorderColor,
            effectiveBorderColor.withValues(alpha: 0.35),
            effectiveBorderColor.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Padding(padding: EdgeInsets.all(borderWidth), child: surface),
    );

    if (!shouldBypassBlur && blur > 0) {
      content = ClipRRect(
        borderRadius: effectiveRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        ),
      );
    } else {
      content = ClipRRect(borderRadius: effectiveRadius, child: content);
    }

    if (elevation > 0) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: effectiveRadius,
          boxShadow: [
            BoxShadow(
              color: shadowColor ?? (isDark ? Colors.black45 : Colors.black12),
              blurRadius: elevation * 2.5,
              offset: Offset(0, elevation * 0.75),
            ),
          ],
        ),
        child: content,
      );
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return content;
  }
}
