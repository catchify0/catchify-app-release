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
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:catchify/constants/app_constants.dart';
import 'package:catchify/constants/app_tokens.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/models/proxy_model.dart';
import 'package:catchify/services/data_manager.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/flutter_bottom_sheet.dart';
import 'package:catchify/utilities/flutter_toast.dart';
import 'package:catchify/utilities/language_utils.dart';
import 'package:catchify/widgets/bottom_sheet_bar.dart';
import 'package:catchify/widgets/custom_bar.dart';
import 'package:catchify/widgets/mini_player_bottom_space.dart';
import 'package:catchify/widgets/proxy_settings_sheet.dart';

class PlaybackSettingsPage extends StatefulWidget {
  const PlaybackSettingsPage({super.key});

  @override
  State<PlaybackSettingsPage> createState() => _PlaybackSettingsPageState();
}

class _PlaybackSettingsPageState extends State<PlaybackSettingsPage> {
  void _showBitratePicker(
    BuildContext context, {
    required String title,
    required ValueNotifier<String> notifier,
    required String storageKey,
  }) {
    final qualities = ['high', 'medium', 'low'];
    final labels = [
      'High (256/320 kbps)',
      'Medium (128 kbps)',
      'Low (64 kbps)',
    ];

    showCustomBottomSheet(
      context,
      ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: commonListViewBottomPadding,
        itemCount: qualities.length,
        itemBuilder: (context, index) {
          final q = qualities[index];
          return BottomSheetBar(
            labels[index],
            () {
              addOrUpdateData<String>('settings', storageKey, q);
              notifier.value = q;
              setState(() {});
              showToast(context, context.l10n!.settingChangedMsg);
              Navigator.pop(context);
            },
            notifier.value == q,
            icon: FluentIcons.music_note_1_24_regular,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showEqualizer = Platform.isAndroid;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n?.musicAndPlayback ?? 'Music & Playback'),
      ),
      body: SingleChildScrollView(
        padding: commonSingleChildScrollViewPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Section 1: Audio Quality
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                'AUDIO QUALITY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: colorScheme.primary,
                ),
              ),
            ),
            CustomBar(
              '${context.l10n!.audioQuality} (Wi-Fi)',
              FluentIcons.wifi_1_24_regular,
              borderRadius: commonCustomBarRadiusFirst,
              trailing: Text(
                streamingQualityWifi.value.toUpperCase(),
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => _showBitratePicker(
                context,
                title: 'Wi-Fi Streaming Quality',
                notifier: streamingQualityWifi,
                storageKey: 'streamingQualityWifi',
              ),
            ),
            CustomBar(
              '${context.l10n!.audioQuality} (Mobile Data)',
              FluentIcons.cellular_data_1_24_regular,
              borderRadius: !showEqualizer
                  ? commonCustomBarRadiusLast
                  : BorderRadius.zero,
              trailing: Text(
                streamingQualityMobile.value.toUpperCase(),
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => _showBitratePicker(
                context,
                title: 'Mobile Data Streaming Quality',
                notifier: streamingQualityMobile,
                storageKey: 'streamingQualityMobile',
              ),
            ),
            CustomBar(
              context.l10n!.equalizer,
              FluentIcons.data_histogram_24_regular,
              description: showEqualizer ? null : 'Available on Android only',
              enabled: showEqualizer,
              borderRadius: commonCustomBarRadiusLast,
              onTap: showEqualizer
                  ? () => context.push('/settings/equalizer')
                  : null,
            ),

            const SizedBox(height: 16),

            // Section 2: Playback Features
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                'PLAYBACK EXPERIENCE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: colorScheme.primary,
                ),
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: playNextSongAutomatically,
              builder: (_, value, __) {
                return CustomBar(
                  'Auto-Play Next Song',
                  FluentIcons.arrow_right_24_regular,
                  description:
                      'Automatically add related songs to the queue when current queue ends',
                  borderRadius: commonCustomBarRadiusFirst,
                  trailing: SettingSwitch(
                    semanticLabel: 'Auto-Play Next Song',
                    value: value,
                    onChanged: (v) {
                      addOrUpdateData<bool>(
                        'settings',
                        'playNextSongAutomatically',
                        v,
                      );
                      playNextSongAutomatically.value = v;
                      showToast(context, context.l10n!.settingChangedMsg);
                    },
                  ),
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: offlineMode,
              builder: (_, isOffline, __) {
                return Column(
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: sponsorBlockSupport,
                      builder: (_, value, __) {
                        return CustomBar(
                          'SponsorBlock',
                          FluentIcons.cut_24_regular,
                          description: isOffline
                              ? 'Available when Offline Mode is disabled'
                              : context.l10n!.sponsorBlockDescription,
                          enabled: !isOffline,
                          trailing: SettingSwitch(
                            semanticLabel: 'SponsorBlock',
                            value: value,
                            onChanged: isOffline
                                ? null
                                : (v) {
                                    addOrUpdateData<bool>(
                                      'settings',
                                      'sponsorBlockSupport',
                                      v,
                                    );
                                    sponsorBlockSupport.value = v;
                                    showToast(
                                      context,
                                      context.l10n!.settingChangedMsg,
                                    );
                                  },
                          ),
                        );
                      },
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: externalRecommendations,
                      builder: (_, value, __) {
                        return CustomBar(
                          context.l10n!.externalRecommendations,
                          FluentIcons.star_24_regular,
                          description: isOffline
                              ? 'Available when Offline Mode is disabled'
                              : context
                                    .l10n!
                                    .externalRecommendationsDescription,
                          enabled: !isOffline,
                          trailing: SettingSwitch(
                            semanticLabel:
                                context.l10n!.externalRecommendations,
                            value: value,
                            onChanged: isOffline
                                ? null
                                : (v) {
                                    addOrUpdateData<bool>(
                                      'settings',
                                      'externalRecommendations',
                                      v,
                                    );
                                    externalRecommendations.value = v;
                                    showToast(
                                      context,
                                      context.l10n!.settingChangedMsg,
                                    );
                                  },
                          ),
                        );
                      },
                    ),
                    ValueListenableBuilder<ProxyMode>(
                      valueListenable: proxyModeNotifier,
                      builder: (context, mode, _) {
                        return CustomBar(
                          'Proxy & Regional Routing',
                          FluentIcons.shield_keyhole_24_regular,
                          description: isOffline
                              ? 'Available when Offline Mode is disabled'
                              : mode == ProxyMode.off
                              ? 'Disabled • Tap to configure'
                              : mode == ProxyMode.auto
                              ? 'Smart Auto • Auto-failover on geo-blocks'
                              : mode == ProxyMode.countryMatch
                              ? 'Country Match • ${getCountryByCode(contentCountryPreference).name}'
                              : 'Custom Proxy • ${customProxyNotifier.value.isNotEmpty ? customProxyNotifier.value : "Configured"}',
                          enabled: !isOffline,
                          borderRadius: commonCustomBarRadiusLast,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: mode == ProxyMode.off
                                      ? colorScheme.surfaceContainerHighest
                                      : colorScheme.primary.withValues(
                                          alpha: 0.15,
                                        ),
                                  borderRadius: BorderRadius.circular(
                                    AppTokens.radiusPill,
                                  ),
                                ),
                                child: Text(
                                  mode.displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: mode == ProxyMode.off
                                        ? colorScheme.onSurfaceVariant
                                        : colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                FluentIcons.chevron_right_24_regular,
                                size: 18,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                          onTap: isOffline
                              ? null
                              : () {
                                  showCustomBottomSheet(
                                    context,
                                    const ProxySettingsSheet(),
                                  );
                                },
                        );
                      },
                    ),
                  ],
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
