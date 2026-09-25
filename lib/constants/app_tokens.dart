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

/// Centralized Catchify Design System Tokens.
/// Defines consistent spacing, radii, dimensions, and typography metrics.
abstract final class AppTokens {
  // ── Spacing ──
  static const double pagePadding = 16;
  static const double wideContentMaxWidth = 1180;
  static const double railBreakpoint = 720;
  static const double spaciousBreakpoint = 960;
  static const double cardGap = 12;
  static const double sectionGap = 28;
  static const double chipGap = 8;
  static const double titleBottomGap = 10;
  static const double rowGap = 8;
  static const double itemSpacing = 12;

  // ── Motion ──
  static const Duration motionFast = Duration(milliseconds: 160);
  static const Duration motionStandard = Duration(milliseconds: 240);
  static const Duration shimmerCycle = Duration(milliseconds: 1450);

  // ── Optics & Glass ──
  static const double blurSubtle = 12;
  static const double blurStandard = 18;
  static const double blurProminent = 28;
  static const double borderSubtle = 0.5;
  static const double borderRegular = 1;

  // ── Radii ──
  static const double radiusSmall = 8;
  static const double radiusControl = 10;
  static const double radiusMedium = 12;
  static const double radiusCard = 14;
  static const double radiusLarge = 16;
  static const double radiusSheet = 20;
  static const double radiusPill = 999;

  static final BorderRadius borderRadiusSmall = BorderRadius.circular(
    radiusSmall,
  );
  static final BorderRadius borderRadiusControl = BorderRadius.circular(
    radiusControl,
  );
  static final BorderRadius borderRadiusMedium = BorderRadius.circular(
    radiusMedium,
  );
  static final BorderRadius borderRadiusCard = BorderRadius.circular(
    radiusCard,
  );
  static final BorderRadius borderRadiusLarge = BorderRadius.circular(
    radiusLarge,
  );
  static final BorderRadius borderRadiusSheet = BorderRadius.circular(
    radiusSheet,
  );
  static final BorderRadius borderRadiusPill = BorderRadius.circular(
    radiusPill,
  );

  // ── Card Dimensions ──
  static const double songCardSize = 140;
  static const double albumCardSize = 140;
  static const double playlistCardSize = 150;
  static const double artistAvatarSize = 88;
  static const double artistCardWidth = 104;
  static const double songRowArtworkSize = 52;
  static const double miniPlayerHeight = 66;
  static const double miniPlayerTotalHeight = 84;
  static const double miniPlayerArtworkSize = 48;

  // ── Control & Button Dimensions ──
  static const double chipHeight = 34;
  static const double buttonHeight = 44;
  static const double buttonHeightSmall = 36;
  static const double iconButtonSize = 40;
  static const double settingIconContainerSize = 40;

  // ── Icon Sizes ──
  static const double iconToolbar = 24;
  static const double iconNav = 24;
  static const double iconInline = 20;
  static const double iconSmall = 16;
  static const double iconLarge = 28;
  static const double minInteractiveSize = 44;
  static const double focusRingWidth = 2;

  // ── Edge Insets ──
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: pagePadding,
  );
  static const EdgeInsets shelfPadding = EdgeInsets.symmetric(
    horizontal: pagePadding,
  );
  static const EdgeInsets chipListPadding = EdgeInsets.symmetric(
    horizontal: pagePadding,
  );
  static const EdgeInsets headerPadding = EdgeInsets.fromLTRB(
    pagePadding,
    12,
    pagePadding,
    titleBottomGap,
  );
  static const EdgeInsets cardPadding = EdgeInsets.all(12);
}
