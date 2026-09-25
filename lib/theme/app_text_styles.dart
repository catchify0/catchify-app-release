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

import 'package:flutter/material.dart';

/// Centralized typographic scale for Catchify.
/// Uses system font with consistent weights, sizes, and letter spacing.
abstract final class AppTextStyles {
  // ── Display & Headings ──
  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.2,
  );

  static const TextStyle pageTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.25,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
    height: 1.3,
  );

  static const TextStyle sectionSubtitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    height: 1.3,
  );

  // ── Card & Row Typography ──
  static const TextStyle cardTitle = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.25,
  );

  static const TextStyle cardSubtitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.25,
  );

  static const TextStyle rowTitle = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.25,
  );

  static const TextStyle rowSubtitle = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.25,
  );

  // ── Body & Content ──
  static const TextStyle body = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.4,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.4,
  );

  static const TextStyle bodyBold = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.4,
  );

  // ── Metadata, Captions & Controls ──
  static const TextStyle secondary = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.3,
  );

  static const TextStyle secondaryMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.3,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.2,
  );

  static const TextStyle captionMedium = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.2,
  );

  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static const TextStyle chip = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );

  static const TextStyle categoryHeader = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );

  /// Converts the Catchify typographic scale into a standard Flutter [TextTheme].
  static TextTheme toTextTheme(ColorScheme colorScheme) {
    final onSurface = colorScheme.onSurface;
    final onSurfaceVariant = colorScheme.onSurfaceVariant;

    return TextTheme(
      displayLarge: display.copyWith(color: onSurface),
      displayMedium: display.copyWith(fontSize: 28, color: onSurface),
      displaySmall: display.copyWith(fontSize: 24, color: onSurface),
      headlineLarge: pageTitle.copyWith(color: onSurface),
      headlineMedium: pageTitle.copyWith(fontSize: 22, color: onSurface),
      headlineSmall: sectionTitle.copyWith(color: onSurface),
      titleLarge: sectionTitle.copyWith(color: onSurface),
      titleMedium: rowTitle.copyWith(color: onSurface),
      titleSmall: cardTitle.copyWith(color: onSurface),
      bodyLarge: bodyBold.copyWith(color: onSurface),
      bodyMedium: body.copyWith(color: onSurface),
      bodySmall: secondary.copyWith(color: onSurfaceVariant),
      labelLarge: button.copyWith(color: onSurface),
      labelMedium: chip.copyWith(color: onSurfaceVariant),
      labelSmall: caption.copyWith(color: onSurfaceVariant),
    );
  }
}
