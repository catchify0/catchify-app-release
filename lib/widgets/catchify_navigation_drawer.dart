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

import 'dart:async';
import 'dart:math' as math;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:catchify/utilities/url_launcher.dart';
import 'package:catchify/widgets/pill_navigation_bar.dart';

/// A sleek, themed left navigation drawer for Catchify.
///
/// Perfectly styled to match Catchify's design system:
/// - Official Catchify brand logo (`assets/icons/catchify-brand.png`) and title
/// - Clean, surface-matched background adapting to Dark, Light, and OLED themes
/// - Fluent navigation destinations (Home, My Music, Playlists, Settings, Rating)
/// - Catchify Premium perks action button
class CatchifyNavigationDrawer extends StatelessWidget {
  const CatchifyNavigationDrawer({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.items = const [],
    this.isOfflineMode = false,
    this.offlineNotifier,
  });

  /// Global key to open or close the drawer from anywhere in the app hierarchy.
  static final GlobalKey<ScaffoldState> scaffoldKey =
      GlobalKey<ScaffoldState>();

  /// Helper to open the navigation drawer programmatically.
  static void open([BuildContext? context]) {
    final state = scaffoldKey.currentState;
    if (state != null) {
      state.openDrawer();
    } else if (context != null) {
      final localScaffold = Scaffold.maybeOf(context);
      if (localScaffold != null && localScaffold.hasDrawer) {
        localScaffold.openDrawer();
      }
    }
  }

  /// Helper to close the navigation drawer programmatically.
  static void close([BuildContext? context]) {
    final state = scaffoldKey.currentState;
    if (state != null && state.isDrawerOpen) {
      state.closeDrawer();
    } else if (context != null) {
      final localScaffold = Scaffold.maybeOf(context);
      if (localScaffold != null && localScaffold.isDrawerOpen) {
        localScaffold.closeDrawer();
      }
    }
  }

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<PillNavigationItem> items;
  final bool isOfflineMode;
  final ValueNotifier<bool>? offlineNotifier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isOled = isDark && colorScheme.surface == Colors.black;

    final drawerBackground = isOled
        ? Colors.black
        : (isDark ? const Color(0xFF121216) : colorScheme.surface);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final drawerWidth = math.min<double>(300, screenWidth * 0.78);
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Drawer(
      width: drawerWidth,
      elevation: 0,
      backgroundColor: drawerBackground,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.horizontal(
          right: Radius.circular(20),
        ),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : colorScheme.outlineVariant.withValues(alpha: 0.28),
          width: 0.8,
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(
            top: topPadding + 24,
            bottom: math.max(16, bottomPadding + 14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. App Brand Header with Catchify Logo
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/icons/catchify-brand.png',
                          width: 38,
                          height: 38,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Catchify',
                      style: TextStyle(
                        fontFamily: 'paytoneOne',
                        color: colorScheme.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),

              if (isOfflineMode) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          FluentIcons.cloud_off_24_filled,
                          color: Colors.amber,
                          size: 14,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Offline Mode',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              SizedBox(height: isOfflineMode ? 20 : 28),

              // 2. Main Navigation Items
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _DrawerItem(
                      icon: FluentIcons.home_24_regular,
                      selectedIcon: FluentIcons.home_24_filled,
                      label: 'Home',
                      isSelected: selectedIndex == 0,
                      onTap: () {
                        Navigator.of(context).pop();
                        onDestinationSelected(0);
                      },
                    ),
                    const SizedBox(height: 8),
                    _DrawerItem(
                      icon: FluentIcons.folder_24_regular,
                      selectedIcon: FluentIcons.folder_24_filled,
                      label: 'My Music',
                      isSelected: selectedIndex == 3,
                      onTap: () {
                        Navigator.of(context).pop();
                        onDestinationSelected(3);
                      },
                    ),
                    const SizedBox(height: 8),
                    _DrawerItem(
                      icon: FluentIcons.apps_list_detail_24_regular,
                      selectedIcon: FluentIcons.apps_list_detail_24_filled,
                      label: 'Playlists',
                      onTap: () {
                        Navigator.of(context).pop();
                        onDestinationSelected(3);
                      },
                    ),

                    // Divider
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Divider(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : colorScheme.outlineVariant.withValues(alpha: 0.3),
                        height: 1,
                        thickness: 0.8,
                      ),
                    ),

                    _DrawerItem(
                      icon: FluentIcons.settings_24_regular,
                      selectedIcon: FluentIcons.settings_24_filled,
                      label: 'Settings',
                      isSelected: selectedIndex == 4,
                      onTap: () {
                        Navigator.of(context).pop();
                        onDestinationSelected(4);
                      },
                    ),
                    const SizedBox(height: 8),
                    _DrawerItem(
                      icon: FluentIcons.star_24_regular,
                      selectedIcon: FluentIcons.star_24_filled,
                      label: 'Help us by rating',
                      onTap: () {
                        Navigator.of(context).pop();
                        _openRating(context);
                      },
                    ),
                  ],
                ),
              ),

              // 3. Catchify Premium Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Material(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                  elevation: 2,
                  shadowColor: colorScheme.primary.withValues(alpha: 0.35),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _showPremiumSheet(context),
                    child: Container(
                      height: 50,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.military_tech_rounded,
                            color: colorScheme.onPrimary,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Go Premium',
                            style: TextStyle(
                              color: colorScheme.onPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openRating(BuildContext context) async {
    await HapticFeedback.selectionClick();
    final url = Uri.parse(
      'https://github.com/catchify0/catchify0.github.io/releases/latest',
    );
    try {
      await launchURL(url);
    } catch (_) {}
  }

  void _showPremiumSheet(BuildContext context) {
    unawaited(HapticFeedback.mediumImpact());
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isOled = isDark && colorScheme.surface == Colors.black;

    final sheetBackground = isOled
        ? const Color(0xFF0F0F12)
        : (isDark ? const Color(0xFF16161C) : colorScheme.surface);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.military_tech_rounded,
                    color: colorScheme.primary,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "You're on Catchify Premium!",
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Catchify is 100% Free & Open-Source. You already enjoy unlimited music, ad-free streaming & full offline listening forever!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                _buildPerkRow(
                  colorScheme,
                  Icons.block_rounded,
                  'Zero Advertisements Forever',
                ),
                _buildPerkRow(
                  colorScheme,
                  Icons.music_note_rounded,
                  'High Quality Audio Streaming',
                ),
                _buildPerkRow(
                  colorScheme,
                  Icons.download_done_rounded,
                  'Unlimited Offline Downloads',
                ),
                _buildPerkRow(
                  colorScheme,
                  Icons.all_inclusive_rounded,
                  'Unlimited Skips & Background Play',
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text(
                      'Awesome, Enjoy!',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPerkRow(ColorScheme colorScheme, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final activeColor = colorScheme.primary;
    final inactiveIconColor = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : colorScheme.onSurfaceVariant;
    final inactiveTextColor =
        isDark ? Colors.white : colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Material(
        color: isSelected
            ? activeColor.withValues(alpha: isDark ? 0.16 : 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          splashColor: activeColor.withValues(alpha: 0.12),
          highlightColor: activeColor.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  size: 24,
                  color: isSelected ? activeColor : inactiveIconColor,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? activeColor : inactiveTextColor,
                      fontSize: 15.5,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: -0.1,
                    ),
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
