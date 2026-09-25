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

/// Semantic color tokens for Catchify.
/// Organizes surfaces, text, overlays, and status indicators across dark, light, and OLED themes.
abstract final class AppColors {
  // ── Dark Surfaces ──
  static const Color darkBackground = Color(0xFF0D0D10);
  static const Color darkSurface = Color(0xFF141418);
  static const Color darkSurfaceElevated = Color(0xFF1C1C22);
  static const Color darkSurfaceHighlight = Color(0xFF25252D);
  static const Color darkSurfaceMuted = Color(0xFF18181E);

  // ── Pure Black / OLED Surfaces ──
  static const Color pureBlack = Color(0xFF000000);
  static const Color pureBlackElevated = Color(0xFF0A0A0A);
  static const Color pureBlackContainer = Color(0xFF121212);
  static const Color pureBlackContainerHigh = Color(0xFF1A1A1A);

  // ── Light Surfaces ──
  static const Color lightBackground = Color(0xFFF7F8FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFEFF1F4);
  static const Color lightSurfaceHighlight = Color(0xFFE4E7EC);

  // ── Dark Text Colors ──
  static const Color darkTextPrimary = Color(0xFFF4F4F6);
  static const Color darkTextSecondary = Color(0xFFA0A0AB);
  static const Color darkTextMuted = Color(0xFF71717A);

  // ── Light Text Colors ──
  static const Color lightTextPrimary = Color(0xFF18181B);
  static const Color lightTextSecondary = Color(0xFF52525B);
  static const Color lightTextMuted = Color(0xFFA1A1AA);

  // ── Semantic Feedback ──
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ── Dividers & Outlines ──
  static const Color darkDivider = Color(0xFF272730);
  static const Color lightDivider = Color(0xFFE4E4E7);

  // ── Glassmorphic & Optical Surface Tokens ──
  static const Color glassSurfaceDark = Color(0xCC18181E);
  static const Color glassBorderDark = Color(0x26FFFFFF);
  static const Color glassSurfaceOled = Color(0xD9121216);
  static const Color glassBorderOled = Color(0x33FFFFFF);
  static const Color glassSurfaceLight = Color(0xD9FFFFFF);
  static const Color glassBorderLight = Color(0x1A000000);
}

class AccentColorItem {
  const AccentColorItem({required this.name, required this.color});

  final String name;
  final Color color;
}

/// Exactly 12 curated premier music accent colors
const List<AccentColorItem> curatedAccentColors = [
  AccentColorItem(name: 'Catchify Purple', color: Color(0xFF9948EF)),
  AccentColorItem(name: 'Electric Violet', color: Color(0xFF8A2BE2)),
  AccentColorItem(name: 'Hyper Blue', color: Color(0xFF0066FF)),
  AccentColorItem(name: 'Tidal Cyan', color: Color(0xFF00E5FF)),
  AccentColorItem(name: 'Spotify Green', color: Color(0xFF1DB954)),
  AccentColorItem(name: 'Neon Lime', color: Color(0xFF39FF14)),
  AccentColorItem(name: 'Solar Amber', color: Color(0xFFFF9100)),
  AccentColorItem(name: 'SoundCloud Orange', color: Color(0xFFFF5500)),
  AccentColorItem(name: 'Ruby Red', color: Color(0xFFFF0000)),
  AccentColorItem(name: 'Apple Red', color: Color(0xFFFC3C44)),
  AccentColorItem(name: 'Cyberpunk Pink', color: Color(0xFFFF007F)),
  AccentColorItem(name: 'Sakura Pink', color: Color(0xFFF48FB1)),
];

/// Backwards compatibility for existing code references
final availableColors = curatedAccentColors.map((e) => e.color).toList();
