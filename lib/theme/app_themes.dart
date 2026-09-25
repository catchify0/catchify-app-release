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

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:catchify/constants/app_tokens.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/theme/app_colors.dart';
import 'package:catchify/theme/app_text_styles.dart';
import 'package:catchify/theme/dynamic_color_compat.dart';

ThemeMode themeMode = getThemeMode(themeModeSetting);
Brightness brightness = getBrightnessFromThemeMode(themeMode);

PageTransitionsBuilder transitionsBuilder = predictiveBack.value
    ? const PredictiveBackPageTransitionsBuilder()
    : const CupertinoPageTransitionsBuilder();

Brightness getBrightnessFromThemeMode(ThemeMode themeMode) {
  final themeBrightnessMapping = {
    ThemeMode.light: Brightness.light,
    ThemeMode.dark: Brightness.dark,
    ThemeMode.system:
        SchedulerBinding.instance.platformDispatcher.platformBrightness,
  };

  return themeBrightnessMapping[themeMode] ?? Brightness.dark;
}

ThemeMode getThemeMode(int themeModeIndex) {
  const themeModes = ThemeMode.values;
  if (themeModeIndex >= 0 && themeModeIndex < themeModes.length) {
    return themeModes[themeModeIndex];
  }
  return ThemeMode.system;
}

/// Resolves both light and dark [ColorScheme]s adhering to Catchify's semantic tokens.
(ColorScheme light, ColorScheme dark) getAppColorSchemes(
  ColorScheme? lightColorScheme,
  ColorScheme? darkColorScheme,
) {
  if (useSystemColor.value &&
      lightColorScheme != null &&
      darkColorScheme != null) {
    (lightColorScheme, darkColorScheme) = tempGenerateDynamicColourSchemes(
      lightColorScheme,
      darkColorScheme,
    );
  }

  final ColorScheme resolvedLight;
  final ColorScheme resolvedDark;

  if (useSystemColor.value &&
      lightColorScheme != null &&
      darkColorScheme != null) {
    final systemLightAccent = lightColorScheme.primary;
    final systemDarkAccent = darkColorScheme.primary;

    resolvedLight = lightColorScheme.copyWith(
      surface: AppColors.lightBackground,
      surfaceContainerLowest: AppColors.lightSurface,
      surfaceContainerLow: Color.alphaBlend(
        systemLightAccent.withValues(alpha: 0.02),
        AppColors.lightSurfaceElevated,
      ),
      surfaceContainer: Color.alphaBlend(
        systemLightAccent.withValues(alpha: 0.04),
        AppColors.lightSurfaceElevated,
      ),
      surfaceContainerHigh: Color.alphaBlend(
        systemLightAccent.withValues(alpha: 0.06),
        AppColors.lightSurfaceHighlight,
      ),
      surfaceContainerHighest: Color.alphaBlend(
        systemLightAccent.withValues(alpha: 0.08),
        AppColors.lightSurfaceHighlight,
      ),
      outline: AppColors.lightDivider,
      outlineVariant: Color.alphaBlend(
        systemLightAccent.withValues(alpha: 0.12),
        const Color(0xFFE4E4E7),
      ),
    );

    if (usePureBlackColor.value) {
      resolvedDark = darkColorScheme.copyWith(
        surface: AppColors.pureBlack,
        surfaceContainerLowest: AppColors.pureBlack,
        surfaceContainerLow: Color.alphaBlend(
          systemDarkAccent.withValues(alpha: 0.025),
          AppColors.pureBlackElevated,
        ),
        surfaceContainer: Color.alphaBlend(
          systemDarkAccent.withValues(alpha: 0.045),
          AppColors.pureBlackContainer,
        ),
        surfaceContainerHigh: Color.alphaBlend(
          systemDarkAccent.withValues(alpha: 0.07),
          AppColors.pureBlackContainerHigh,
        ),
        surfaceContainerHighest: Color.alphaBlend(
          systemDarkAccent.withValues(alpha: 0.095),
          AppColors.pureBlackContainerHigh,
        ),
        outline: Color.alphaBlend(
          systemDarkAccent.withValues(alpha: 0.10),
          AppColors.darkDivider,
        ),
        outlineVariant: Color.alphaBlend(
          systemDarkAccent.withValues(alpha: 0.14),
          const Color(0xFF272730),
        ),
      );
    } else {
      resolvedDark = darkColorScheme.copyWith(
        surface: Color.alphaBlend(
          systemDarkAccent.withValues(alpha: 0.015),
          AppColors.darkBackground,
        ),
        surfaceContainerLowest: Color.alphaBlend(
          systemDarkAccent.withValues(alpha: 0.018),
          AppColors.darkBackground,
        ),
        surfaceContainerLow: Color.alphaBlend(
          systemDarkAccent.withValues(alpha: 0.035),
          AppColors.darkSurface,
        ),
        surfaceContainer: Color.alphaBlend(
          systemDarkAccent.withValues(alpha: 0.055),
          AppColors.darkSurfaceElevated,
        ),
        surfaceContainerHigh: Color.alphaBlend(
          systemDarkAccent.withValues(alpha: 0.075),
          AppColors.darkSurfaceHighlight,
        ),
        surfaceContainerHighest: Color.alphaBlend(
          systemDarkAccent.withValues(alpha: 0.10),
          AppColors.darkSurfaceHighlight,
        ),
        outline: Color.alphaBlend(
          systemDarkAccent.withValues(alpha: 0.10),
          AppColors.darkDivider,
        ),
        outlineVariant: Color.alphaBlend(
          systemDarkAccent.withValues(alpha: 0.15),
          const Color(0xFF272730),
        ),
      );
    }
  } else {
    final accent = primaryColorSetting;
    final onAccent = accent.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;

    final lightBase = ColorScheme.fromSeed(seedColor: accent).harmonized();
    resolvedLight = lightBase.copyWith(
      primary: accent,
      onPrimary: onAccent,
      primaryContainer: Color.alphaBlend(
        accent.withValues(alpha: 0.14),
        Colors.white,
      ),
      onPrimaryContainer: accent.computeLuminance() < 0.3
          ? accent
          : Color.alphaBlend(Colors.black.withValues(alpha: 0.35), accent),
      surface: AppColors.lightBackground,
      surfaceContainerLowest: AppColors.lightSurface,
      surfaceContainerLow: Color.alphaBlend(
        accent.withValues(alpha: 0.02),
        AppColors.lightSurfaceElevated,
      ),
      surfaceContainer: Color.alphaBlend(
        accent.withValues(alpha: 0.04),
        AppColors.lightSurfaceElevated,
      ),
      surfaceContainerHigh: Color.alphaBlend(
        accent.withValues(alpha: 0.06),
        AppColors.lightSurfaceHighlight,
      ),
      surfaceContainerHighest: Color.alphaBlend(
        accent.withValues(alpha: 0.08),
        AppColors.lightSurfaceHighlight,
      ),
      outline: Color.alphaBlend(
        accent.withValues(alpha: 0.06),
        AppColors.lightDivider,
      ),
      outlineVariant: Color.alphaBlend(
        accent.withValues(alpha: 0.12),
        const Color(0xFFE4E4E7),
      ),
    );

    final darkBase = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).harmonized();

    if (usePureBlackColor.value) {
      resolvedDark = darkBase.copyWith(
        primary: accent,
        onPrimary: onAccent,
        primaryContainer: Color.alphaBlend(
          accent.withValues(alpha: 0.22),
          AppColors.pureBlackContainer,
        ),
        onPrimaryContainer: Color.alphaBlend(
          accent.withValues(alpha: 0.90),
          Colors.white,
        ),
        surface: AppColors.pureBlack,
        surfaceContainerLowest: AppColors.pureBlack,
        surfaceContainerLow: Color.alphaBlend(
          accent.withValues(alpha: 0.025),
          AppColors.pureBlackElevated,
        ),
        surfaceContainer: Color.alphaBlend(
          accent.withValues(alpha: 0.045),
          AppColors.pureBlackContainer,
        ),
        surfaceContainerHigh: Color.alphaBlend(
          accent.withValues(alpha: 0.07),
          AppColors.pureBlackContainerHigh,
        ),
        surfaceContainerHighest: Color.alphaBlend(
          accent.withValues(alpha: 0.095),
          AppColors.pureBlackContainerHigh,
        ),
        outline: Color.alphaBlend(
          accent.withValues(alpha: 0.10),
          AppColors.darkDivider,
        ),
        outlineVariant: Color.alphaBlend(
          accent.withValues(alpha: 0.14),
          const Color(0xFF272730),
        ),
      );
    } else {
      resolvedDark = darkBase.copyWith(
        primary: accent,
        onPrimary: onAccent,
        primaryContainer: Color.alphaBlend(
          accent.withValues(alpha: 0.22),
          AppColors.darkSurfaceElevated,
        ),
        onPrimaryContainer: Color.alphaBlend(
          accent.withValues(alpha: 0.90),
          Colors.white,
        ),
        surface: Color.alphaBlend(
          accent.withValues(alpha: 0.015),
          AppColors.darkBackground,
        ),
        surfaceContainerLowest: Color.alphaBlend(
          accent.withValues(alpha: 0.018),
          AppColors.darkBackground,
        ),
        surfaceContainerLow: Color.alphaBlend(
          accent.withValues(alpha: 0.035),
          AppColors.darkSurface,
        ),
        surfaceContainer: Color.alphaBlend(
          accent.withValues(alpha: 0.055),
          AppColors.darkSurfaceElevated,
        ),
        surfaceContainerHigh: Color.alphaBlend(
          accent.withValues(alpha: 0.075),
          AppColors.darkSurfaceHighlight,
        ),
        surfaceContainerHighest: Color.alphaBlend(
          accent.withValues(alpha: 0.10),
          AppColors.darkSurfaceHighlight,
        ),
        outline: Color.alphaBlend(
          accent.withValues(alpha: 0.10),
          AppColors.darkDivider,
        ),
        outlineVariant: Color.alphaBlend(
          accent.withValues(alpha: 0.15),
          const Color(0xFF272730),
        ),
      );
    }
  }

  return (resolvedLight, resolvedDark);
}

/// Backwards compatibility helper returning single ColorScheme for current brightness.
ColorScheme getAppColorScheme(
  ColorScheme? lightColorScheme,
  ColorScheme? darkColorScheme, {
  Brightness? overrideBrightness,
}) {
  final target = overrideBrightness ?? brightness;
  final (light, dark) = getAppColorSchemes(lightColorScheme, darkColorScheme);
  return target == Brightness.light ? light : dark;
}

ThemeData getAppTheme(ColorScheme colorScheme) {
  final base = colorScheme.brightness == Brightness.light
      ? ThemeData.light()
      : ThemeData.dark();

  final isLight = colorScheme.brightness == Brightness.light;
  final isPureBlack =
      colorScheme.brightness == Brightness.dark && usePureBlackColor.value;

  final bgColor = colorScheme.surface;
  final cardBgColor = colorScheme.surfaceContainerLow;
  final effectiveColorScheme = colorScheme;

  return ThemeData(
    fontFamily: 'AnekTamil',
    scaffoldBackgroundColor: bgColor,
    colorScheme: effectiveColorScheme,
    cardColor: cardBgColor,
    textTheme: AppTextStyles.toTextTheme(effectiveColorScheme),
    cardTheme: base.cardTheme.copyWith(
      elevation: 0,
      color: cardBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
        side: BorderSide(
          color: effectiveColorScheme.outlineVariant.withValues(
            alpha: isLight ? 0.45 : (isPureBlack ? 0.32 : 0.25),
          ),
          width: isLight ? AppTokens.borderSubtle : 0.8,
        ),
      ),
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: bgColor,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
        statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
      ),
      foregroundColor: effectiveColorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'AnekTamil',
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: effectiveColorScheme.onSurface,
        letterSpacing: -0.2,
      ),
      toolbarHeight: 50,
      iconTheme: IconThemeData(
        color: effectiveColorScheme.onSurfaceVariant,
        size: 24,
      ),
      actionsIconTheme: IconThemeData(
        color: effectiveColorScheme.onSurfaceVariant,
        size: 24,
      ),
    ),
    listTileTheme: base.listTileTheme.copyWith(
      textColor: effectiveColorScheme.onSurface,
      iconColor: effectiveColorScheme.onSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      minVerticalPadding: 8,
    ),
    sliderTheme: base.sliderTheme.copyWith(
      year2023: false,
      trackHeight: 12,
      thumbSize: WidgetStateProperty.all(const Size(6, 30)),
      activeTrackColor: effectiveColorScheme.primary,
      inactiveTrackColor: effectiveColorScheme.primary.withValues(alpha: 0.20),
      thumbColor: effectiveColorScheme.primary,
    ),
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      backgroundColor: effectiveColorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusSheet),
        ),
      ),
      showDragHandle: false,
      dragHandleColor: effectiveColorScheme.onSurfaceVariant.withValues(
        alpha: 0.4,
      ),
      dragHandleSize: const Size(36, 4.5),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      isDense: true,
      fillColor: isLight
          ? colorScheme.surfaceContainerHighest
          : (isPureBlack
                ? AppColors.pureBlackContainerHigh
                : colorScheme.surfaceContainerHigh),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        borderSide: BorderSide(
          color: effectiveColorScheme.outlineVariant.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        borderSide: BorderSide(
          color: effectiveColorScheme.outlineVariant.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        borderSide: BorderSide(color: effectiveColorScheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: effectiveColorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
      ),
      titleTextStyle: AppTextStyles.sectionTitle.copyWith(
        color: effectiveColorScheme.onSurface,
      ),
      contentTextStyle: AppTextStyles.body.copyWith(
        color: effectiveColorScheme.onSurfaceVariant,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
      side: BorderSide.none,
      labelStyle: AppTextStyles.chip,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, AppTokens.buttonHeight),
        backgroundColor: effectiveColorScheme.primary,
        foregroundColor: effectiveColorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        ),
        textStyle: AppTextStyles.button,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, AppTokens.buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        ),
        textStyle: AppTextStyles.button,
      ),
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      backgroundColor: isLight
          ? effectiveColorScheme.surfaceContainerLowest
          : effectiveColorScheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 76,
      indicatorColor: effectiveColorScheme.primary.withValues(alpha: 0.18),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(
            color: effectiveColorScheme.primary,
            size: AppTokens.iconNav,
          );
        }
        return IconThemeData(
          color: effectiveColorScheme.onSurfaceVariant.withValues(alpha: 0.72),
          size: AppTokens.iconNav,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(
            fontFamily: 'AnekTamil',
            color: effectiveColorScheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          );
        }
        return TextStyle(
          fontFamily: 'AnekTamil',
          color: effectiveColorScheme.onSurfaceVariant.withValues(alpha: 0.72),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        );
      }),
    ),
    navigationRailTheme: base.navigationRailTheme.copyWith(
      backgroundColor: bgColor,
      elevation: 0,
      indicatorColor: effectiveColorScheme.primary.withValues(alpha: 0.18),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
      selectedIconTheme: IconThemeData(
        color: effectiveColorScheme.primary,
        size: AppTokens.iconNav,
      ),
      unselectedIconTheme: IconThemeData(
        color: effectiveColorScheme.onSurfaceVariant.withValues(alpha: 0.72),
        size: AppTokens.iconNav,
      ),
      selectedLabelTextStyle: TextStyle(
        fontFamily: 'AnekTamil',
        color: effectiveColorScheme.primary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontFamily: 'AnekTamil',
        color: effectiveColorScheme.onSurfaceVariant.withValues(alpha: 0.72),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
    popupMenuTheme: base.popupMenuTheme.copyWith(
      color: isLight
          ? colorScheme.surfaceContainerLow
          : (isPureBlack ? AppColors.pureBlackContainer : null),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
      ),
      elevation: 4,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return effectiveColorScheme.onPrimary;
        }
        return effectiveColorScheme.onSurfaceVariant;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return effectiveColorScheme.primary;
        }
        return effectiveColorScheme.surfaceContainerHighest.withValues(
          alpha: isLight ? 0.95 : 0.9,
        );
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return effectiveColorScheme.primary.withValues(alpha: 0.55);
        }
        return effectiveColorScheme.outlineVariant.withValues(alpha: 0.7);
      }),
      trackOutlineWidth: WidgetStateProperty.all(1),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return effectiveColorScheme.primary;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(effectiveColorScheme.onPrimary),
      side: BorderSide(
        color: effectiveColorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        width: 1.5,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusSmall / 2),
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return effectiveColorScheme.primary;
        }
        return effectiveColorScheme.onSurfaceVariant.withValues(alpha: 0.6);
      }),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: effectiveColorScheme.primary,
      linearTrackColor: effectiveColorScheme.surfaceContainerHighest,
      circularTrackColor: effectiveColorScheme.surfaceContainerHighest,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: isLight
            ? AppColors.darkSurfaceElevated
            : AppColors.lightSurfaceElevated,
        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      textStyle: AppTextStyles.captionMedium.copyWith(
        color: isLight ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      waitDuration: const Duration(milliseconds: 500),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(
          AppTokens.iconButtonSize,
          AppTokens.iconButtonSize,
        ),
        foregroundColor: effectiveColorScheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusControl),
        ),
      ),
    ),
    dividerTheme: base.dividerTheme.copyWith(
      color: isLight ? AppColors.lightDivider : AppColors.darkDivider,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: effectiveColorScheme.secondaryContainer,
      contentTextStyle: TextStyle(
        color: effectiveColorScheme.onSecondaryContainer,
        fontWeight: FontWeight.w500,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
      ),
      elevation: 6,
      actionTextColor: effectiveColorScheme.secondary,
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    useMaterial3: true,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: transitionsBuilder,
      },
    ),
  );
}
