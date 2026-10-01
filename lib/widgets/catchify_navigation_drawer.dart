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

import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:catchify/constants/app_tokens.dart';
import 'package:catchify/constants/version.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/services/data_manager.dart';
import 'package:catchify/services/router_service.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/flutter_toast.dart';
import 'package:catchify/widgets/catchify_brand_icon.dart';
import 'package:catchify/widgets/pill_navigation_bar.dart';

/// A sleek, modern left slide-out navigation drawer for Catchify.
///
/// Provides quick access to primary navigation destinations, audio tools,
/// Spotify playlist import, theme personalization, offline mode, and about info.
class CatchifyNavigationDrawer extends StatelessWidget {
  const CatchifyNavigationDrawer({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.items,
    required this.isOfflineMode,
    this.offlineNotifier,
  });

  /// Global key to control the drawer state from anywhere in the app hierarchy.
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
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final surfaceColor = isDark
        ? (theme.colorScheme.surface == Colors.black
              ? Colors.black
              : const Color(0xFF131318))
        : theme.colorScheme.surface;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final drawerWidth = math.min<double>(320, screenWidth * 0.82);

    final showEqualizer = !kIsWeb && Platform.isAndroid;

    return Drawer(
      width: drawerWidth,
      elevation: 0,
      backgroundColor: surfaceColor,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(AppTokens.radiusSheet),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Drawer Header ──
            _buildHeader(context, isDark, primary, surfaceColor),

            // ── Offline Banner (when offline) ──
            if (isOfflineMode) _buildOfflineBanner(context, isDark, primary),

            // ── Scrollable Body ──
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                children: [
                  // Main Navigation Items
                  _buildSectionTitle(
                    title: 'MAIN MENU',
                    isDark: isDark,
                    theme: theme,
                  ),
                  for (int i = 0; i < items.length; i++)
                    _buildNavItem(
                      context: context,
                      index: i,
                      item: items[i],
                      isSelected: selectedIndex == i,
                      isDark: isDark,
                      primary: primary,
                      surfaceColor: surfaceColor,
                      theme: theme,
                    ),

                  const SizedBox(height: 12),
                  _buildDivider(isDark, theme),

                  // Discover & Tools
                  _buildSectionTitle(
                    title: 'DISCOVER & TOOLS',
                    isDark: isDark,
                    theme: theme,
                  ),

                  if (showEqualizer)
                    _buildActionItem(
                      context: context,
                      icon: FluentIcons.data_histogram_24_regular,
                      title: context.l10n?.equalizer ?? 'Equalizer',
                      subtitle: 'Audio enhancement & bands',
                      isDark: isDark,
                      primary: primary,
                      theme: theme,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).pop();
                        context.push('/settings/equalizer');
                      },
                    ),

                  if (!isOfflineMode) ...[
                    _buildActionItem(
                      context: context,
                      icon: FluentIcons.history_24_regular,
                      title: 'Time Machine',
                      subtitle: 'Your listening recap & journey',
                      isDark: isDark,
                      primary: primary,
                      theme: theme,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).pop();
                        context.push('/home/timeMachine');
                      },
                    ),
                    _buildActionItem(
                      context: context,
                      icon: FluentIcons.arrow_import_24_regular,
                      title: context.l10n?.importSpotifyPlaylist ??
                          'Import from Spotify',
                      subtitle: 'Transfer playlists via CSV',
                      isDark: isDark,
                      primary: primary,
                      theme: theme,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).pop();
                        context.push('/settings/importSpotifyPlaylist');
                      },
                    ),
                  ],

                  _buildActionItem(
                    context: context,
                    icon: FluentIcons.paint_brush_24_regular,
                    title: context.l10n?.themeAndAppUI ?? 'Theme & Appearance',
                    subtitle: 'Accent colors & OLED black',
                    isDark: isDark,
                    primary: primary,
                    theme: theme,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop();
                      context.push('/settings/theme');
                    },
                  ),

                  const SizedBox(height: 12),
                  _buildDivider(isDark, theme),

                  // Quick Settings & Offline Mode
                  _buildSectionTitle(
                    title: 'PREFERENCES',
                    isDark: isDark,
                    theme: theme,
                  ),

                  ValueListenableBuilder<bool>(
                    valueListenable: offlineNotifier ?? offlineMode,
                    builder: (context, offline, _) {
                      return _buildSwitchItem(
                        context: context,
                        icon: offline
                            ? FluentIcons.cloud_off_24_regular
                            : FluentIcons.cloud_24_regular,
                        title: context.l10n?.offlineMode ?? 'Offline Mode',
                        subtitle: offline
                            ? 'Playing saved downloads only'
                            : 'Online streaming enabled',
                        value: offline,
                        isDark: isDark,
                        primary: primary,
                        theme: theme,
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          if (offlineNotifier != null) {
                            offlineNotifier!.value = val;
                          } else {
                            addOrUpdateData<bool>(
                              'settings',
                              'offlineMode',
                              val,
                            );
                            offlineMode.value = val;
                            NavigationManager.refreshRouter();
                          }
                          showToast(
                            context,
                            val
                                ? 'Offline mode enabled'
                                : 'Offline mode disabled',
                          );
                        },
                      );
                    },
                  ),

                  _buildActionItem(
                    context: context,
                    icon: FluentIcons.info_24_regular,
                    title: context.l10n?.about ?? 'About Catchify',
                    subtitle: 'Licenses, source code & credits',
                    isDark: isDark,
                    primary: primary,
                    theme: theme,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop();
                      context.push('/settings/about');
                    },
                  ),
                ],
              ),
            ),

            // ── Footer ──
            _buildFooter(context, isDark, theme, primary),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    Color primary,
    Color surfaceColor,
  ) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Container(
      padding: EdgeInsets.fromLTRB(16, topPadding + 16, 12, 16),
      decoration: BoxDecoration(
        color: isDark
            ? Color.alphaBlend(primary.withValues(alpha: 0.08), surfaceColor)
            : Color.alphaBlend(primary.withValues(alpha: 0.04), surfaceColor),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          const CatchifyBrandIcon(size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(
                      'Catchify',
                      style: TextStyle(
                        fontFamily: 'paytoneOne',
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.2,
                        color: primary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.16),
                        borderRadius: AppTokens.borderRadiusSmall,
                      ),
                      child: Text(
                        'v$appVersion',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: primary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Free Music Streaming',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.black.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(FluentIcons.dismiss_20_regular),
            tooltip: 'Close sidebar',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner(BuildContext context, bool isDark, Color primary) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF261D10)
            : const Color(0xFFFFF7ED),
        borderRadius: AppTokens.borderRadiusControl,
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            FluentIcons.cloud_off_24_filled,
            color: Color(0xFFF59E0B),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Offline mode active — local & downloaded content only.',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? const Color(0xFFFDE68A)
                    : const Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required bool isDark,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: isDark
              ? Colors.white.withValues(alpha: 0.42)
              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark, ThemeData theme) {
    return Divider(
      height: 1,
      thickness: 0.8,
      indent: 16,
      endIndent: 16,
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required PillNavigationItem item,
    required bool isSelected,
    required bool isDark,
    required Color primary,
    required Color surfaceColor,
    required ThemeData theme,
  }) {
    final activeBg = isDark
        ? Color.alphaBlend(primary.withValues(alpha: 0.18), surfaceColor)
        : Color.alphaBlend(primary.withValues(alpha: 0.12), surfaceColor);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2.5),
      child: Material(
        color: isSelected ? activeBg : Colors.transparent,
        borderRadius: AppTokens.borderRadiusMedium,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pop();
            onDestinationSelected(index);
          },
          splashColor: primary.withValues(alpha: 0.15),
          highlightColor: primary.withValues(alpha: 0.08),
          borderRadius: AppTokens.borderRadiusMedium,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(
                  isSelected ? item.selectedIcon : item.icon,
                  size: 22,
                  color: isSelected
                      ? primary
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.78)
                          : theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? primary
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.95)
                              : theme.colorScheme.onSurface),
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required Color primary,
    required ThemeData theme,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppTokens.borderRadiusMedium,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: primary.withValues(alpha: 0.12),
          highlightColor: primary.withValues(alpha: 0.06),
          borderRadius: AppTokens.borderRadiusMedium,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.72)
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.92)
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.45)
                              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  FluentIcons.chevron_right_20_regular,
                  size: 16,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.3)
                      : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool isDark,
    required Color primary,
    required ThemeData theme,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppTokens.borderRadiusMedium,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: value
                    ? const Color(0xFFF59E0B)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.72)
                        : theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.92)
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.45)
                            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.85,
                child: Switch.adaptive(
                  value: value,
                  activeColor: primary,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    bool isDark,
    ThemeData theme,
    Color primary,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Catchify Music',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.6)
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            'v$appVersion',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),
        ],
      ),
    );
  }
}
