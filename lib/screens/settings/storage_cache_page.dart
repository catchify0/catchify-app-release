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
import 'package:path_provider/path_provider.dart';
import 'package:catchify/constants/app_constants.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart';
import 'package:catchify/services/common_services.dart';
import 'package:catchify/services/data_manager.dart';
import 'package:catchify/services/download_manager.dart';
import 'package:catchify/services/listening_stats_service.dart';
import 'package:catchify/services/playlist_download_service.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/artwork_provider.dart';
import 'package:catchify/utilities/flutter_toast.dart';
import 'package:catchify/widgets/confirmation_dialog.dart';
import 'package:catchify/widgets/custom_bar.dart';
import 'package:catchify/widgets/mini_player_bottom_space.dart';

class StorageCachePage extends StatefulWidget {
  const StorageCachePage({super.key});

  @override
  State<StorageCachePage> createState() => _StorageCachePageState();
}

class _StorageCachePageState extends State<StorageCachePage> {
  String _cacheSizeFormatted = 'Calculating...';
  bool _isCalculating = true;
  StorageAccounting? _downloadsAccounting;

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
  }

  Future<void> _calculateCacheSize() async {
    if (!mounted) return;
    setState(() => _isCalculating = true);
    try {
      var totalBytes = 0;
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        totalBytes += await _getDirSize(tempDir);
      }

      final accounting = await DownloadManager.instance.getStorageAccounting();

      final mb = totalBytes / (1024 * 1024);
      if (mounted) {
        setState(() {
          _downloadsAccounting = accounting;
          _cacheSizeFormatted = mb >= 1024
              ? '${(mb / 1024).toStringAsFixed(2)} GB'
              : '${mb.toStringAsFixed(1)} MB';
          _isCalculating = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cacheSizeFormatted = '0.0 MB';
          _isCalculating = false;
        });
      }
    }
  }

  Future<int> _getDirSize(Directory dir) async {
    var bytes = 0;
    try {
      await for (final file in dir.list(recursive: true, followLinks: false)) {
        if (file is File) {
          bytes += await file.length();
        }
      }
    } catch (_) {}
    return bytes;
  }

  Future<void> _clearDiskAndMemoryCache() async {
    try {
      ArtworkProvider.clearCache();
      await clearCache();

      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await for (final file in tempDir.list()) {
          try {
            await file.delete(recursive: true);
          } catch (_) {}
        }
      }

      await _calculateCacheSize();
      if (mounted) {
        showToast(context, 'Cache cleared!');
      }
    } catch (e) {
      if (mounted) {
        showToast(context, context.l10n!.error);
      }
    }
  }

  void _showConfirmationDialog({
    required BuildContext context,
    required String confirmationMessage,
    required VoidCallback onSubmit,
    String? submitMessage,
    bool isDangerous = false,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ConfirmationDialog(
          submitMessage: submitMessage ?? context.l10n!.clear,
          confirmationMessage: confirmationMessage,
          isDangerous: isDangerous,
          onCancel: () => Navigator.of(context).pop(),
          onSubmit: () {
            Navigator.of(context).pop();
            onSubmit();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Storage & Cache')),
      body: SingleChildScrollView(
        padding: commonSingleChildScrollViewPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Section 1: Cache
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                'CACHE & MEMORY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: colorScheme.primary,
                ),
              ),
            ),
            CustomBar(
              context.l10n!.clearCache,
              FluentIcons.broom_24_regular,
              description:
                  'Clear cached song artwork and temporary streaming chunks',
              borderRadius: commonCustomBarRadiusFirst,
              trailing: Text(
                _isCalculating ? 'Calculating...' : _cacheSizeFormatted,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => _showConfirmationDialog(
                context: context,
                confirmationMessage:
                    'Are you sure you want to clear the cache?',
                onSubmit: _clearDiskAndMemoryCache,
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: autoCacheSongs,
              builder: (_, value, __) {
                return CustomBar(
                  'Auto-Cache Streamed Songs',
                  FluentIcons.arrow_download_24_regular,
                  description:
                      'Cache audio chunks during playback for instant replay',
                  borderRadius: commonCustomBarRadiusLast,
                  trailing: SettingSwitch(
                    semanticLabel: 'Auto-Cache Streamed Songs',
                    value: value,
                    onChanged: (v) {
                      addOrUpdateData<bool>('settings', 'autoCacheSongs', v);
                      autoCacheSongs.value = v;
                      showToast(context, context.l10n!.settingChangedMsg);
                    },
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Section 2: Data Cleanup
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                'DATA MANAGEMENT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: colorScheme.primary,
                ),
              ),
            ),
            CustomBar(
              context.l10n!.clearRecentlyPlayed,
              FluentIcons.receipt_play_24_regular,
              borderRadius: commonCustomBarRadiusFirst,
              onTap: () => _showConfirmationDialog(
                context: context,
                confirmationMessage: context.l10n!.clearRecentlyPlayedQuestion,
                onSubmit: () {
                  userRecentlyPlayed.value = [];
                  deleteData('user', 'recentlyPlayedSongs');
                  showToast(context, '${context.l10n!.recentlyPlayedMsg}!');
                },
              ),
            ),
            CustomBar(
              context.l10n!.clearListeningStats,
              FluentIcons.clock_24_regular,
              onTap: () => _showConfirmationDialog(
                context: context,
                confirmationMessage: context.l10n!.clearListeningStatsQuestion,
                submitMessage: context.l10n!.delete,
                isDangerous: true,
                onSubmit: () async {
                  audioHandler.resetListeningStatsSession(flushStats: false);
                  await listeningStatsService.clearStats();
                  audioHandler.startListeningStatsSessionIfNeeded();
                  if (mounted) {
                    showToast(
                      context,
                      '${context.l10n!.listeningStatsCleared}!',
                    );
                  }
                },
              ),
            ),
            CustomBar(
              context.l10n!.deleteDownloads,
              FluentIcons.delete_24_regular,
              description: _downloadsAccounting != null
                  ? '${_downloadsAccounting!.downloadedSongsCount} tracks • ${_downloadsAccounting!.formattedStorageSize}'
                  : null,
              borderRadius: commonCustomBarRadiusLast,
              onTap: () => _showConfirmationDialog(
                context: context,
                confirmationMessage: context.l10n!.deleteDownloadsQuestion,
                submitMessage: context.l10n!.delete,
                isDangerous: true,
                onSubmit: () async {
                  try {
                    await offlinePlaylistService.deleteAllDownloads();
                    await _calculateCacheSize();
                    if (mounted) {
                      showToast(context, context.l10n!.downloadsDeleted);
                    }
                  } catch (e) {
                    if (mounted) {
                      showToast(context, context.l10n!.error);
                    }
                  }
                },
              ),
            ),

            const SizedBox(height: 24),
            const MiniPlayerBottomSpace(),
          ],
        ),
      ),
    );
  }
}
