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
import 'package:catchify/constants/app_tokens.dart';
import 'package:catchify/widgets/glass_surface.dart';

/// Data class representing an item in the [PillNavigationBar].
class PillNavigationItem {
  const PillNavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// A sleek, animated pill-style bottom navigation bar.
///
/// When an item is selected, it expands into a capsule pill containing both the
/// vibrant accent-colored icon and label with a subtle dark tinted pill background.
/// Unselected items display only their clean icons without labels.
class PillNavigationBar extends StatelessWidget {
  const PillNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.items,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<PillNavigationItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final surfaceColor = isDark
        ? (theme.colorScheme.surface == Colors.black
              ? Colors.black
              : const Color(0xFF0A0A0C))
        : theme.colorScheme.surface;

    final pillBackgroundColor = isDark
        ? Color.alphaBlend(primary.withValues(alpha: 0.22), surfaceColor)
        : primary.withValues(alpha: 0.14);

    final unselectedIconColor = isDark
        ? Colors.white
        : theme.colorScheme.onSurfaceVariant;

    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        bottom: bottomPadding > 0 ? bottomPadding : 10,
        top: 2,
      ),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(32),
        blur: 24,
        surfaceColor: isDark
            ? (theme.colorScheme.surface == Colors.black
                  ? Colors.black.withValues(alpha: 0.78)
                  : const Color(0xFF101016).withValues(alpha: 0.82))
            : theme.colorScheme.surface.withValues(alpha: 0.86),
        borderColor: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : theme.colorScheme.outlineVariant.withValues(alpha: 0.28),
        elevation: 18,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.38 : 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final isSelected = index == selectedIndex;
              final item = items[index];

              return _PillNavigationItemWidget(
                item: item,
                isSelected: isSelected,
                activeColor: primary,
                unselectedColor: unselectedIconColor,
                pillBackgroundColor: pillBackgroundColor,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onDestinationSelected(index);
                },
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _PillNavigationItemWidget extends StatelessWidget {
  const _PillNavigationItemWidget({
    required this.item,
    required this.isSelected,
    required this.activeColor,
    required this.unselectedColor,
    required this.pillBackgroundColor,
    required this.onTap,
  });

  final PillNavigationItem item;
  final bool isSelected;
  final Color activeColor;
  final Color unselectedColor;
  final Color pillBackgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          splashColor: activeColor.withValues(alpha: 0.12),
          highlightColor: Colors.transparent,
          child: AnimatedContainer(
            duration: AppTokens.motionStandard,
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: isSelected ? 16 : 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isSelected ? pillBackgroundColor : Colors.transparent,
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              border: isSelected
                  ? Border.all(
                      color: activeColor.withValues(alpha: 0.32),
                      width: 0.8,
                    )
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: AppTokens.motionFast,
                  child: Icon(
                    isSelected ? item.selectedIcon : item.icon,
                    key: ValueKey<bool>(isSelected),
                    color: isSelected ? activeColor : unselectedColor,
                    size: 26,
                  ),
                ),
                ClipRect(
                  child: AnimatedSize(
                    duration: AppTokens.motionStandard,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.centerLeft,
                    child: isSelected
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 8),
                              Text(
                                item.label,
                                style: TextStyle(
                                  color: activeColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
