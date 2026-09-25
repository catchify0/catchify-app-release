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
 */

import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:catchify/constants/app_constants.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart';
import 'package:catchify/services/data_manager.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/theme/app_text_styles.dart';
import 'package:catchify/theme/app_themes.dart';
import 'package:catchify/utilities/flutter_bottom_sheet.dart';
import 'package:catchify/utilities/flutter_toast.dart';
import 'package:catchify/widgets/accent_color_picker.dart';
import 'package:catchify/widgets/bottom_sheet_bar.dart';
import 'package:catchify/widgets/custom_bar.dart';
import 'package:catchify/widgets/mini_player_bottom_space.dart';

class ThemeSettingsPage extends StatefulWidget {
  const ThemeSettingsPage({super.key});

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  void _showAccentColorPicker(BuildContext context) {
    showCustomBottomSheet(
      context,
      AccentColorPickerSheet(
        initialColor: primaryColorSetting,
        onColorSelected: (color) {
          addOrUpdateData<int>('settings', 'accentColor', color.toARGB32());
          Catchify.updateAppState(
            context,
            newAccentColor: color,
            useSystemColor: false,
          );
          setState(() {});
          showToast(context, context.l10n!.accentChangeMsg);
          closeCurrentBottomSheet();
        },
      ),
    );
  }

  void _showThemeModePicker(BuildContext context) {
    final availableModes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
    const modeIcons = [
      FluentIcons.phone_24_regular,
      FluentIcons.weather_sunny_24_regular,
      FluentIcons.weather_moon_24_regular,
    ];

    showCustomBottomSheet(
      context,
      ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: commonListViewBottomPadding,
        itemCount: availableModes.length,
        itemBuilder: (context, index) {
          final mode = availableModes[index];
          final modeNames = [
            context.l10n!.themeModeSystem,
            context.l10n!.themeModeLight,
            context.l10n!.themeModeDark,
          ];

          return BottomSheetBar(
            modeNames[mode.index],
            () {
              addOrUpdateData<int>('settings', 'themeIndex', mode.index);
              Catchify.updateAppState(context, newThemeMode: mode);
              setState(() {});
              Navigator.pop(context);
            },
            themeMode == mode,
            icon: modeIcons[mode.index],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Use the rendered theme so the system option follows OS brightness
    // changes immediately instead of relying on the persisted mode alone.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showDynamicColor = Platform.isAndroid;
    final showPredictiveBack = Platform.isAndroid;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n?.themeAndAppUI ?? 'Theme & Appearance'),
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: commonSingleChildScrollViewPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Section 1: Colors & Theme
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                'APPEARANCE & THEME',
                style: AppTextStyles.categoryHeader.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ),
            CustomBar(
              context.l10n?.accentColor ?? 'Accent Color',
              FluentIcons.color_24_regular,
              borderRadius: commonCustomBarRadiusFirst,
              trailing: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: primaryColorSetting,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColorSetting.withValues(alpha: 0.35),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              onTap: () => _showAccentColorPicker(context),
            ),
            CustomBar(
              context.l10n?.themeMode ?? 'Theme Mode',
              FluentIcons.weather_sunny_28_regular,
              trailing: Text(
                themeMode == ThemeMode.dark
                    ? 'Dark'
                    : (themeMode == ThemeMode.light ? 'Light' : 'System'),
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => _showThemeModePicker(context),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: usePureBlackColor,
              builder: (_, value, __) {
                return CustomBar(
                  context.l10n!.pureBlackTheme,
                  FluentIcons.color_background_24_regular,
                  description: isDark
                      ? 'True #000000 black for OLED battery saving'
                      : 'Available when a dark theme is active',
                  enabled: isDark,
                  trailing: SettingSwitch(
                    semanticLabel: context.l10n!.pureBlackTheme,
                    value: value,
                    onChanged: isDark
                        ? (v) {
                            addOrUpdateData<bool>(
                              'settings',
                              'usePureBlackColor',
                              v,
                            );
                            usePureBlackColor.value = v;
                            Catchify.updateAppState(context);
                            setState(() {});
                            showToast(context, context.l10n!.settingChangedMsg);
                          }
                        : null,
                  ),
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: useSystemColor,
              builder: (_, value, __) {
                return CustomBar(
                  context.l10n!.dynamicColor,
                  FluentIcons.toggle_left_24_regular,
                  description: showDynamicColor
                      ? 'Extract accent colors from system wallpaper'
                      : 'Available on Android only',
                  enabled: showDynamicColor,
                  trailing: SettingSwitch(
                    semanticLabel: context.l10n!.dynamicColor,
                    value: value,
                    onChanged: showDynamicColor
                        ? (v) {
                            addOrUpdateData<bool>(
                              'settings',
                              'useSystemColor',
                              v,
                            );
                            useSystemColor.value = v;
                            Catchify.updateAppState(
                              context,
                              newAccentColor: primaryColorSetting,
                              useSystemColor: v,
                            );
                            setState(() {});
                            showToast(context, context.l10n!.settingChangedMsg);
                          }
                        : null,
                  ),
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: predictiveBack,
              builder: (_, value, __) {
                return CustomBar(
                  context.l10n!.predictiveBack,
                  FluentIcons.position_backward_24_regular,
                  description: showPredictiveBack
                      ? null
                      : 'Available on Android only',
                  enabled: showPredictiveBack,
                  borderRadius: commonCustomBarRadiusLast,
                  trailing: SettingSwitch(
                    semanticLabel: context.l10n!.predictiveBack,
                    value: value,
                    onChanged: showPredictiveBack
                        ? (v) {
                            addOrUpdateData<bool>(
                              'settings',
                              'predictiveBack',
                              v,
                            );
                            predictiveBack.value = v;
                            transitionsBuilder = v
                                ? const PredictiveBackPageTransitionsBuilder()
                                : const CupertinoPageTransitionsBuilder();
                            Catchify.updateAppState(context);
                            showToast(context, context.l10n!.settingChangedMsg);
                          }
                        : null,
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            const MiniPlayerBottomSpace(),
          ],
        ),
      ),
    );
  }
}
