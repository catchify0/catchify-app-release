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
import 'package:go_router/go_router.dart';
import 'package:catchify/utilities/url_launcher.dart';
import 'package:catchify/widgets/pill_navigation_bar.dart';

/// A sleek, atmospheric left slide-out navigation drawer for Catchify.
///
/// Implements a minimal, dark celestial design with:
/// - Atmospheric starry nebula background header
/// - Bold 'Catchify' title
/// - Home, My Music, Playlists, Settings, Help us by rating, and InkStudio shortcuts
/// - Vibrant green 'Go Premium' button
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final drawerWidth = math.min<double>(300, screenWidth * 0.78);
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Drawer(
      width: drawerWidth,
      elevation: 0,
      backgroundColor: const Color(0xFF0B0C0E),
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
      child: Stack(
        children: [
          // ── Atmospheric Cosmic Nebula Header ──
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 220,
            child: CustomPaint(
              painter: _CosmicNebulaPainter(),
            ),
          ),

          // ── Drawer Content ──
          SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(
                top: topPadding + 28,
                bottom: math.max(16, bottomPadding + 14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. App Title
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Catchify',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),

                  if (isOfflineMode) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
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

                  SizedBox(height: isOfflineMode ? 24 : 36),

                  // 2. Main Navigation Items
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _DrawerItem(
                          icon: FluentIcons.home_24_filled,
                          label: 'Home',
                          isSelected: selectedIndex == 0,
                          onTap: () {
                            Navigator.of(context).pop();
                            onDestinationSelected(0);
                          },
                        ),
                        const SizedBox(height: 14),
                        _DrawerItem(
                          icon: Icons.library_music_rounded,
                          label: 'My Music',
                          isSelected: selectedIndex == 3,
                          onTap: () {
                            Navigator.of(context).pop();
                            onDestinationSelected(3);
                          },
                        ),
                        const SizedBox(height: 14),
                        _DrawerItem(
                          icon: Icons.queue_music_rounded,
                          label: 'Playlists',
                          onTap: () {
                            Navigator.of(context).pop();
                            onDestinationSelected(3);
                          },
                        ),

                        // Divider
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 18,
                          ),
                          child: Divider(
                            color: Color(0x1FFFFFFF),
                            height: 1,
                            thickness: 0.8,
                          ),
                        ),

                        _DrawerItem(
                          icon: FluentIcons.settings_24_filled,
                          label: 'Settings',
                          isSelected: selectedIndex == 4,
                          onTap: () {
                            Navigator.of(context).pop();
                            onDestinationSelected(4);
                          },
                        ),
                        const SizedBox(height: 14),
                        _DrawerItem(
                          icon: FluentIcons.star_24_filled,
                          label: 'Help us by rating',
                          onTap: () {
                            Navigator.of(context).pop();
                            _openRating(context);
                          },
                        ),
                        const SizedBox(height: 14),
                        _DrawerItem(
                          icon: Icons.bubble_chart_outlined,
                          label: 'InkStudio',
                          trailing: const Icon(
                            Icons.north_east_rounded,
                            size: 16,
                            color: Colors.white38,
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            _openInkStudio(context);
                          },
                        ),
                      ],
                    ),
                  ),

                  // 3. Vibrant Green 'Go Premium' Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Material(
                      color: const Color(0xFF00D15B),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _showPremiumSheet(context),
                        child: Container(
                          height: 52,
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.military_tech_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Go Premium',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.1,
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
        ],
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

  Future<void> _openInkStudio(BuildContext context) async {
    await HapticFeedback.selectionClick();
    final url = Uri.parse('https://github.com/catchify0');
    try {
      await launchURL(url);
    } catch (_) {
      if (context.mounted) {
        unawaited(context.push('/settings/about'));
      }
    }
  }

  void _showPremiumSheet(BuildContext context) {
    unawaited(HapticFeedback.mediumImpact());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14151B),
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
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF00D15B).withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.military_tech_rounded,
                  color: Color(0xFF00D15B),
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "You're on Catchify Premium!",
                style: TextStyle(
                  color: Colors.white,
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
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              _buildPerkRow(Icons.block_rounded, 'Zero Advertisements Forever'),
              _buildPerkRow(
                Icons.music_note_rounded,
                'High Quality Audio Streaming',
              ),
              _buildPerkRow(
                Icons.download_done_rounded,
                'Unlimited Offline Downloads',
              ),
              _buildPerkRow(
                Icons.all_inclusive_rounded,
                'Unlimited Skips & Background Play',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D15B),
                    foregroundColor: Colors.white,
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

  Widget _buildPerkRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: const Color(0xFF00D15B),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
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
    required this.label,
    required this.onTap,
    this.isSelected = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSelected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: isSelected ? const Color(0x14FFFFFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          splashColor: Colors.white.withValues(alpha: 0.1),
          highlightColor: Colors.white.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isSelected ? const Color(0xFF00D15B) : Colors.white,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF00D15B)
                          : Colors.white,
                      fontSize: 16,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter to recreate the exact cosmic constellation nebula effect
/// seen in the top header of the drawer.
class _CosmicNebulaPainter extends CustomPainter {
  const _CosmicNebulaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Soft radial glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.4),
        radius: 0.95,
        colors: [
          const Color(0xFF6E8CA0).withValues(alpha: 0.28),
          const Color(0xFF384A5C).withValues(alpha: 0.14),
          const Color(0xFF141922).withValues(alpha: 0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glowPaint);

    // 2. Cosmic starry particles and constellation lines
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final starGlowPaint = Paint()..style = PaintingStyle.fill;

    // Fixed constellation points for clean rendering
    const points = [
      Offset(36, 26),
      Offset(72, 44),
      Offset(108, 22),
      Offset(148, 52),
      Offset(188, 32),
      Offset(228, 56),
      Offset(58, 86),
      Offset(98, 106),
      Offset(138, 82),
      Offset(178, 110),
      Offset(218, 90),
      Offset(248, 126),
      Offset(28, 116),
      Offset(82, 136),
      Offset(128, 146),
      Offset(168, 136),
      Offset(208, 156),
    ];

    // Constellation lines
    const connections = [
      [0, 1],
      [1, 2],
      [1, 6],
      [2, 3],
      [3, 4],
      [3, 8],
      [4, 5],
      [5, 10],
      [6, 7],
      [7, 8],
      [7, 13],
      [8, 9],
      [9, 10],
      [9, 15],
      [10, 11],
      [12, 6],
      [13, 14],
      [14, 15],
      [15, 16],
    ];

    for (final conn in connections) {
      if (conn[0] < points.length && conn[1] < points.length) {
        canvas.drawLine(points[conn[0]], points[conn[1]], linePaint);
      }
    }

    // Draw stars and glowing halos
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final isLarge = i % 3 == 0;
      final radius = isLarge ? 2.2 : 1.2;

      // Soft glow
      if (isLarge) {
        starGlowPaint.color = Colors.white.withValues(alpha: 0.22);
        canvas.drawCircle(p, 5, starGlowPaint);
      }

      // Star point
      starGlowPaint.color =
          Colors.white.withValues(alpha: isLarge ? 0.9 : 0.65);
      canvas.drawCircle(p, radius, starGlowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
