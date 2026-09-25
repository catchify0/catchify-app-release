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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:catchify/constants/app_constants.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/services/data_manager.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/flutter_bottom_sheet.dart';
import 'package:catchify/utilities/flutter_toast.dart';
import 'package:catchify/widgets/bottom_sheet_bar.dart';
import 'package:catchify/widgets/custom_bar.dart';
import 'package:catchify/widgets/mini_player_bottom_space.dart';

class PlayerSettingsPage extends StatefulWidget {
  const PlayerSettingsPage({super.key});

  @override
  State<PlayerSettingsPage> createState() => _PlayerSettingsPageState();
}

class _PlayerSettingsPageState extends State<PlayerSettingsPage> {
  void _showGradientPicker(BuildContext context) {
    final styles = ['dynamic', 'pure_black', 'blurred'];
    final labels = [
      'Dynamic Artwork Gradient',
      'AMOLED Pure Black Minimal',
      'Blurred Frosted Glass',
    ];
    final icons = [
      FluentIcons.color_line_24_regular,
      FluentIcons.color_background_24_regular,
      FluentIcons.blur_24_regular,
    ];

    showCustomBottomSheet(
      context,
      ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: commonListViewBottomPadding,
        itemCount: styles.length,
        itemBuilder: (context, index) {
          final s = styles[index];
          return BottomSheetBar(
            labels[index],
            () {
              addOrUpdateData<String>('settings', 'playerGradientStyle', s);
              playerGradientStyle.value = s;
              setState(() {});
              showToast(context, context.l10n!.settingChangedMsg);
              Navigator.pop(context);
            },
            playerGradientStyle.value == s,
            icon: icons[index],
          );
        },
      ),
    );
  }

  void _showLyricsOffsetDialog(BuildContext context) {
    var currentOffset = lyricsOffsetNotifier.value;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Lyrics Sync Offset'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Adjust global lyrics synchronization offset in milliseconds (+/- ms).',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${currentOffset > 0 ? "+$currentOffset" : currentOffset} ms',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(FluentIcons.subtract_24_regular),
                        onPressed: () {
                          setDialogState(() {
                            currentOffset -= 250;
                          });
                        },
                      ),
                      const SizedBox(width: 16),
                      FilledButton.tonal(
                        onPressed: () {
                          setDialogState(() {
                            currentOffset = 0;
                          });
                        },
                        child: const Text('Reset'),
                      ),
                      const SizedBox(width: 16),
                      IconButton.filledTonal(
                        icon: const Icon(FluentIcons.add_24_regular),
                        onPressed: () {
                          setDialogState(() {
                            currentOffset += 250;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n!.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    addOrUpdateData<int>('settings', 'lyricsOffsetMs', currentOffset);
                    lyricsOffsetNotifier.value = currentOffset;
                    activeSongLyricsOffsetNotifier.value = currentOffset;
                    setState(() {});
                    Navigator.pop(context);
                    showToast(context, context.l10n!.settingChangedMsg);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    var currentStyleLabel = 'Dynamic Gradient';
    if (playerGradientStyle.value == 'pure_black') {
      currentStyleLabel = 'Pure Black';
    } else if (playerGradientStyle.value == 'blurred') {
      currentStyleLabel = 'Frosted Glass';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing & Visuals'),
      ),
      body: SingleChildScrollView(
        padding: commonSingleChildScrollViewPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                'NOW PLAYING STYLE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: colorScheme.primary,
                ),
              ),
            ),
            CustomBar(
              'Player Background Style',
              FluentIcons.color_line_24_regular,
              description: 'Customize background style of the active music player',
              borderRadius: commonCustomBarRadiusFirst,
              trailing: Text(
                currentStyleLabel,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => _showGradientPicker(context),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: volumeGestureEnabled,
              builder: (context, enabled, _) {
                return CustomBar(
                  'Artwork Volume Gesture',
                  FluentIcons.speaker_2_24_regular,
                  description:
                      'Vertical swipe on Artwork in Player to control volume',
                  trailing: SettingSwitch(
                    semanticLabel: 'Artwork Volume Gesture',
                    value: enabled,
                    onChanged: (val) {
                      addOrUpdateData<bool>(
                        'settings',
                        'volumeGestureEnabled',
                        val,
                      );
                      volumeGestureEnabled.value = val;
                      showToast(context, context.l10n!.settingChangedMsg);
                    },
                  ),
                );
              },
            ),
            CustomBar(
              'Global Lyrics Sync Offset',
              FluentIcons.text_bullet_list_square_24_regular,
              description: 'Default time shift applied to time-synced lyrics',
              borderRadius: commonCustomBarRadiusLast,
              trailing: Text(
                '${lyricsOffsetNotifier.value} ms',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => _showLyricsOffsetDialog(context),
            ),

            const SizedBox(height: 24),
            const MiniPlayerBottomSpace(),
          ],
        ),
      ),
    );
  }
}
