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

import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:catchify/constants/app_constants.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart';
import 'package:catchify/screens/search_page.dart';
import 'package:catchify/services/audio_permission_service.dart';
import 'package:catchify/services/common_services.dart';
import 'package:catchify/services/data_manager.dart';
import 'package:catchify/services/listening_stats_service.dart';
import 'package:catchify/services/playlists_manager.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/flutter_toast.dart';
import 'package:catchify/widgets/custom_bar.dart';
import 'package:catchify/widgets/mini_player_bottom_space.dart';

class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key});

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  Future<void> _backupUserData(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;

    try {
      if (Platform.isAndroid) {
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              icon: Icon(
                FluentIcons.info_24_regular,
                color: colorScheme.primary,
                size: 32,
              ),
              content: Text(
                context.l10n!.folderRestrictions,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: <Widget>[
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n!.understand),
                ),
              ],
            );
          },
        );
      }
      final result = await backupData(context);
      if (mounted) {
        showToast(
          context,
          result.message,
          icon: result.success ? null : FluentIcons.error_circle_24_regular,
        );
      }
    } catch (e, stackTrace) {
      logger.log('Error backing up data', error: e, stackTrace: stackTrace);
      if (mounted) {
        showToast(
          context,
          context.l10n!.error,
          icon: FluentIcons.error_circle_24_regular,
        );
      }
    }
  }

  Future<void> _restoreUserData(BuildContext context) async {
    try {
      final result = await restoreData(context);
      if (result.success) {
        reloadSongLibraryStateFromStorage();
        reloadPlaylistLibraryStateFromStorage();
        reloadSearchHistoryFromStorage();
        reloadSettingsFromStorage();
        listeningStatsService.reload();
        if (mounted) {
          showToast(context, result.message);
        }
      }
    } catch (e, str) {
      logger.log('Error restoring data', error: e, stackTrace: str);
      if (mounted) {
        showToast(
          context,
          context.l10n!.error,
          icon: FluentIcons.error_circle_24_regular,
        );
      }
    }
  }

  void _showLocalMusicFoldersDialog(BuildContext context) {
    final folders = List<String>.from(localMusicFolders);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isTa = Localizations.localeOf(context).languageCode == 'ta';
            return AlertDialog(
              title: Text(isTa ? 'உள்ளக இசை கோப்புறைகள்' : 'Local music folders'),
              content: SizedBox(
                width: double.maxFinite,
                child: folders.isEmpty
                    ? Text(
                        isTa
                            ? 'கோப்புறைகள் எதுவும் தேர்ந்தெடுக்கப்படவில்லை. கோப்புறையைச் சேர்க்கவும்.'
                            : 'No folders selected yet. Add a folder to scan.',
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: folders.length,
                        itemBuilder: (context, index) {
                          final path = folders[index];
                          return ListTile(
                            dense: true,
                            title: Text(_folderName(path)),
                            subtitle: Text(path),
                            trailing: IconButton(
                              icon: const Icon(FluentIcons.delete_24_regular),
                              onPressed: () async {
                                setState(() {
                                  folders.removeAt(index);
                                });
                                await _saveLocalMusicFolders(folders);
                              },
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    final hasPermission = await _ensureAudioPermission(context);
                    if (!hasPermission) return;
                    final path = await FilePicker.getDirectoryPath();
                    if (path == null || path.isEmpty) return;
                    if (path.startsWith('content://')) {
                      if (context.mounted) {
                        showToast(
                          context,
                          'Folder access is restricted on Android. Choose a local storage folder.',
                        );
                      }
                      return;
                    }
                    if (!folders.contains(path)) {
                      setState(() {
                        folders.add(path);
                      });
                      await _saveLocalMusicFolders(folders);
                    }
                  },
                  child: Text(isTa ? 'கோப்புறையைச் சேர்' : 'Add folder'),
                ),
                TextButton(
                  onPressed: folders.isEmpty
                      ? null
                      : () async {
                          final hasPermission = await _ensureAudioPermission(context);
                          if (!hasPermission) return;
                          await _rescanLocalMusicFolders(context, folders);
                        },
                  child: Text(isTa ? 'மீண்டும் ஸ்கேன் செய்' : 'Rescan'),
                ),
                TextButton(
                  onPressed: folders.isEmpty
                      ? null
                      : () async {
                          await _clearLocalMusicFolders(context);
                          setState(folders.clear);
                        },
                  child: Text(context.l10n!.clear),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n!.cancel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveLocalMusicFolders(List<String> folders) async {
    localMusicFolders = List<String>.from(folders);
    await addOrUpdateData('userNoBackup', 'localMusicFolders', localMusicFolders);
  }

  Future<void> _rescanLocalMusicFolders(
    BuildContext context,
    List<String> folders,
  ) async {
    final report = await refreshLocalSongsFromFolders(folders);
    if (context.mounted) {
      showToast(context, _localScanMessage(report, context));
    }
  }

  Future<bool> _ensureAudioPermission(BuildContext context) async {
    final hasPermission = await AudioPermissionService.hasAudioPermission();
    if (hasPermission) return true;
    final granted = await AudioPermissionService.requestAudioPermission();
    if (!granted && context.mounted) {
      showToast(context, 'Audio permission is required to scan local music.');
    }
    return granted;
  }

  Future<void> _clearLocalMusicFolders(BuildContext context) async {
    localMusicFolders = [];
    userLocalSongs.value = [];
    await addOrUpdateData('userNoBackup', 'localMusicFolders', []);
    await addOrUpdateData('userNoBackup', 'localSongs', userLocalSongs.value);
    if (context.mounted) {
      showToast(context, context.l10n!.settingChangedMsg);
    }
  }

  String _folderName(String path) {
    final clean = path.replaceAll(RegExp(r'[/\\]+$'), '');
    final parts = clean.split(RegExp(r'[/\\]'));
    return parts.isNotEmpty ? parts.last : path;
  }

  String _localScanMessage(LocalScanReport report, BuildContext context) {
    if (report.found > 0) return context.l10n!.playlistUpdated;
    if (report.contentUriFolders > 0) {
      return Platform.isAndroid
          ? 'Folder access is restricted on Android. Choose a local storage folder.'
          : 'Folder access is restricted. Choose an accessible folder.';
    }
    if (report.missingFolders > 0) {
      return 'Selected folder is not available. Please choose another.';
    }
    if (report.errorFolders > 0) {
      return 'Unable to scan folders. Check storage permissions.';
    }
    return 'No supported audio files found in the selected folders.';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n?.backupAndRestore ?? 'Backup & Restore'),
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
                'DATA BACKUP',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: colorScheme.primary,
                ),
              ),
            ),
            CustomBar(
              context.l10n!.backupUserData,
              FluentIcons.cloud_sync_24_regular,
              description: 'Export all playlists, favorites, and settings to a file',
              borderRadius: commonCustomBarRadiusFirst,
              onTap: () => _backupUserData(context),
            ),
            CustomBar(
              context.l10n!.restoreUserData,
              FluentIcons.cloud_add_24_regular,
              description: 'Import and restore your data from an existing backup',
              borderRadius: commonCustomBarRadiusLast,
              onTap: () => _restoreUserData(context),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                'IMPORT & LOCAL MEDIA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: colorScheme.primary,
                ),
              ),
            ),
            CustomBar(
              'Import from Spotify',
              FluentIcons.music_note_2_24_filled,
              borderRadius: commonCustomBarRadiusFirst,
              onTap: () => context.push('/settings/importSpotifyPlaylist'),
            ),
            CustomBar(
              'Import from File',
              FluentIcons.document_24_regular,
              borderRadius: commonCustomBarRadiusLast,
              onTap: () => _showLocalMusicFoldersDialog(context),
            ),

            const SizedBox(height: 24),
            const MiniPlayerBottomSpace(),
          ],
        ),
      ),
    );
  }
}
