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
import 'package:flutter/services.dart';
import 'package:catchify/widgets/catchify_navigation_drawer.dart';

/// A bold, attractive hamburger menu button designed for Catchify.
///
/// Features:
/// - Staggered 3-bar pill hamburger icon with rounded caps
/// - Micro-haptic feedback on tap
/// - Circular ink ripple on press
class CatchifyMenuButton extends StatelessWidget {
  const CatchifyMenuButton({
    super.key,
    this.size = 38,
    this.margin = const EdgeInsets.only(left: 12),
  });

  /// Touch-target size of the button. Defaults to 38.0.
  final double size;

  /// External margin around the button. Defaults to `EdgeInsets.only(left: 12)`.
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: 'Open Navigation Menu',
      child: Tooltip(
        message: 'Navigation Menu',
        child: Center(
          child: Padding(
            padding: margin,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                splashColor: colorScheme.primary.withValues(alpha: 0.20),
                highlightColor: colorScheme.primary.withValues(alpha: 0.10),
                onTap: () {
                  HapticFeedback.lightImpact();
                  CatchifyNavigationDrawer.open(context);
                },
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Center(
                    child: CatchifyHamburgerIcon(
                      color: colorScheme.primary,
                      size: size * 0.50,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A bold, modern 3-bar hamburger icon with stylish staggered pill bars and rhythm dot.
class CatchifyHamburgerIcon extends StatelessWidget {
  const CatchifyHamburgerIcon({
    super.key,
    this.color,
    this.size = 18,
  });

  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final barColor = color ?? Theme.of(context).colorScheme.primary;
    const barHeight = 2.6;
    const barRadius = BorderRadius.all(Radius.circular(2));

    return SizedBox(
      width: size,
      height: size * 0.72,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar: full width bold pill
          Container(
            height: barHeight,
            width: size,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: barRadius,
            ),
          ),
          // Middle bar: artistic music-beat bar (pill + rhythm dot)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: barHeight,
                width: size * 0.58,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: barRadius,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: barHeight + 0.4,
                height: barHeight + 0.4,
                decoration: BoxDecoration(
                  color: barColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          // Bottom bar: 82% width bold pill
          Container(
            height: barHeight,
            width: size * 0.82,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: barRadius,
            ),
          ),
        ],
      ),
    );
  }
}
