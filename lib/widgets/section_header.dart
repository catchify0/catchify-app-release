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
import 'package:catchify/theme/app_text_styles.dart';

/// Clean, standardized section shelf header.
/// Title prominently on top, optional subtle subtitle below, clean action on right.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.actionButton,
    this.onTap,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? actionButton;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;

    final headerContent = Padding(
      padding: padding ?? AppTokens.headerPadding,
      child: Row(
        crossAxisAlignment: hasSubtitle
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (icon != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(icon, size: 20, color: colorScheme.primary),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.sectionTitle.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                if (hasSubtitle) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.categoryHeader.copyWith(
                      color: colorScheme.primary.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionButton != null) ...[
            const SizedBox(width: 8),
            Align(
              alignment: Alignment.topCenter,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: AppTokens.borderRadiusControl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: AppTokens.minInteractiveSize,
                    minHeight: AppTokens.minInteractiveSize,
                  ),
                  child: actionButton,
                ),
              ),
            ),
          ] else if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(
              FluentIcons.chevron_right_20_regular,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );

    if (onTap != null && actionButton == null) {
      return Semantics(
        button: true,
        label: title,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppTokens.borderRadiusMedium,
            child: headerContent,
          ),
        ),
      );
    }

    return headerContent;
  }
}
