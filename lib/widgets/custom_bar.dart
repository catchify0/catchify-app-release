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

import 'package:catchify/constants/app_tokens.dart';
import 'package:catchify/theme/app_text_styles.dart';

class CustomBar extends StatelessWidget {
  const CustomBar(
    this.tileName,
    this.tileIcon, {
    this.description,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.backgroundColor,
    this.iconColor,
    this.textColor,
    this.enabled = true,
    this.borderRadius = BorderRadius.zero,
    super.key,
  });

  final String tileName;
  final IconData tileIcon;
  final String? description;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? textColor;
  final bool enabled;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveIconColor = iconColor ?? colorScheme.primary;
    final disabledContentColor = colorScheme.onSurface.withValues(alpha: 0.45);
    final effectiveBackground =
        backgroundColor ??
        colorScheme.surfaceContainerLow.withValues(alpha: 0.92);

    return SizedBox(
      width: double.infinity,
      child: Semantics(
        container: true,
        button: onTap != null || onLongPress != null,
        enabled: enabled,
        label: description == null ? tileName : '$tileName, $description',
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: effectiveBackground,
            borderRadius: borderRadius,
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? onTap : null,
              onLongPress: enabled ? onLongPress : null,
              splashColor: colorScheme.primary.withValues(alpha: 0.12),
              highlightColor: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: borderRadius,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppTokens.minInteractiveSize,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: AppTokens.settingIconContainerSize,
                        height: AppTokens.settingIconContainerSize,
                        decoration: BoxDecoration(
                          color: enabled
                              ? effectiveIconColor.withValues(alpha: 0.12)
                              : colorScheme.surfaceContainerHighest.withValues(
                                  alpha: 0.5,
                                ),
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusControl,
                          ),
                          border: Border.all(
                            color: enabled
                                ? effectiveIconColor.withValues(alpha: 0.2)
                                : colorScheme.outlineVariant.withValues(
                                    alpha: 0.3,
                                  ),
                            width: 0.8,
                          ),
                        ),
                        child: Icon(
                          tileIcon,
                          size: AppTokens.iconInline,
                          color: enabled
                              ? effectiveIconColor
                              : disabledContentColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tileName,
                              style: AppTextStyles.rowTitle.copyWith(
                                color: enabled
                                    ? (textColor ?? colorScheme.onSurface)
                                    : disabledContentColor,
                              ),
                            ),
                            if (description != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                description!,
                                style: AppTextStyles.caption.copyWith(
                                  color: enabled
                                      ? (textColor?.withValues(alpha: 0.75) ??
                                            colorScheme.onSurfaceVariant)
                                      : disabledContentColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: trailing,
                          ),
                        ),
                      ],
                    ],
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

class SettingSwitch extends StatelessWidget {
  const SettingSwitch({
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEnabled = onChanged != null;
    final disabledThumbColor = colorScheme.onSurface.withValues(alpha: 0.38);
    final disabledTrackColor = colorScheme.onSurface.withValues(alpha: 0.12);

    return Semantics(
      container: true,
      label: semanticLabel,
      toggled: value,
      child: Switch(
        value: value,
        onChanged: onChanged,
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (!isEnabled) return disabledThumbColor;
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (!isEnabled) return disabledTrackColor;
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (!isEnabled) {
            return colorScheme.outlineVariant.withValues(alpha: 0.45);
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withValues(alpha: 0.65);
          }
          return colorScheme.outline.withValues(alpha: 0.85);
        }),
        trackOutlineWidth: WidgetStateProperty.resolveWith((states) {
          if (!isEnabled) return 1;
          return states.contains(WidgetState.selected) ? 1 : 1.5;
        }),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return colorScheme.primary.withValues(alpha: 0.12);
          }
          return Colors.transparent;
        }),
      ),
    );
  }
}
