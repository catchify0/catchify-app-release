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
import 'package:catchify/constants/app_tokens.dart';

class OverflowMenuButton<T> extends StatelessWidget {
  const OverflowMenuButton({
    super.key,
    required this.onSelected,
    required this.itemBuilder,
    this.icon,
    this.borderRadius,
    this.iconSize = 24,
    this.color,
  });

  final void Function(T value) onSelected;
  final List<PopupMenuEntry<T>> Function(BuildContext context) itemBuilder;

  final IconData? icon;
  final double iconSize;
  final Color? color;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(12);

    return PopupMenuButton<T>(
      borderRadius: effectiveBorderRadius,
      padding: EdgeInsets.zero,
      onSelected: onSelected,
      itemBuilder: itemBuilder,
      icon: Container(
        width: AppTokens.minInteractiveSize,
        height: AppTokens.minInteractiveSize,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow.withValues(alpha: 0.9),
          borderRadius: effectiveBorderRadius,
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.42),
          ),
        ),
        child: Icon(
          icon ?? FluentIcons.more_vertical_24_regular,
          size: iconSize,
          color: color ?? colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
