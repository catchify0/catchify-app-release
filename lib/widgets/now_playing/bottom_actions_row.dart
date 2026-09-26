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

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:catchify/constants/app_tokens.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart';
import 'package:catchify/services/common_services.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/flutter_bottom_sheet.dart';
import 'package:catchify/utilities/flutter_toast.dart';
import 'package:catchify/utilities/mediaitem.dart';
import 'package:catchify/utilities/playlist_dialogs.dart';
import 'package:catchify/widgets/queue_list_view.dart';

class BottomActionsRow extends StatefulWidget {
  const BottomActionsRow({
    super.key,
    required this.audioId,
    required this.metadata,
    required this.iconSize,
    required this.isLargeScreen,
    required this.onLyricsTap,
  });
  final dynamic audioId;
  final MediaItem metadata;
  final double iconSize;
  final bool isLargeScreen;

  /// Called when the lyrics icon is tapped — parent handles the view switch.
  final VoidCallback onLyricsTap;

  @override
  State<BottomActionsRow> createState() => _BottomActionsRowState();
}

class _BottomActionsRowState extends State<BottomActionsRow> {
  late final ValueNotifier<bool> _songLikeStatus;
  late final ValueNotifier<bool> _songOfflineStatus;

  @override
  void initState() {
    super.initState();
    _songLikeStatus = ValueNotifier<bool>(isSongAlreadyLiked(widget.audioId));
    _songOfflineStatus = ValueNotifier<bool>(
      isSongAlreadyOffline(widget.audioId),
    );
    userLikedSongsList.addListener(_syncLikeStatus);
    userOfflineSongs.addListener(_syncOfflineStatus);
  }

  void _syncLikeStatus() {
    final newStatus = isSongAlreadyLiked(widget.audioId);
    if (_songLikeStatus.value != newStatus) {
      _songLikeStatus.value = newStatus;
    }
  }

  void _syncOfflineStatus() {
    final newStatus = isSongAlreadyOffline(widget.audioId);
    if (_songOfflineStatus.value != newStatus) {
      _songOfflineStatus.value = newStatus;
    }
  }

  @override
  void didUpdateWidget(BottomActionsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioId != widget.audioId) {
      _songLikeStatus.value = isSongAlreadyLiked(widget.audioId);
      _songOfflineStatus.value = isSongAlreadyOffline(widget.audioId);
    }
  }

  @override
  void dispose() {
    userLikedSongsList.removeListener(_syncLikeStatus);
    userOfflineSongs.removeListener(_syncOfflineStatus);
    _songLikeStatus.dispose();
    _songOfflineStatus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n!;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final responsiveIconSize = screenWidth < 360
        ? widget.iconSize * 0.85
        : widget.iconSize;

    return StreamBuilder<List<Map>>(
      initialData: audioHandler.queueList,
      stream: audioHandler.queueAsMapStream,
      builder: (context, snapshot) {
        final queue = snapshot.data ?? [];

        final actions = <Widget>[
          _buildActionButton(
            context: context,
            icon: FluentIcons.cloud_arrow_down_24_regular,
            activeIcon: FluentIcons.cloud_off_24_filled,
            colorScheme: colorScheme,
            size: responsiveIconSize,
            statusNotifier: _songOfflineStatus,
            onPressed: widget.audioId == null
                ? null
                : () => _toggleOffline(
                    _songOfflineStatus,
                    widget.audioId,
                    widget.metadata,
                  ),
            tooltip: l10n.makeOffline,
          ),
          _buildSleepTimerButton(context, colorScheme, responsiveIconSize),
          if (!offlineMode.value)
            _buildSimpleActionButton(
              context: context,
              icon: FluentIcons.album_add_24_regular,
              colorScheme: colorScheme,
              size: responsiveIconSize,
              onPressed: () => showAddToPlaylistDialog(
                context,
                song: mediaItemToMap(widget.metadata),
              ),
              tooltip: l10n.addToPlaylist,
            ),
          if (queue.isNotEmpty && !widget.isLargeScreen)
            _buildSimpleActionButton(
              context: context,
              icon: FluentIcons.apps_list_24_filled,
              colorScheme: colorScheme,
              size: responsiveIconSize,
              onPressed: () => showCustomBottomSheet(
                context,
                const QueueWidget(isBottomSheet: true),
              ),
              tooltip: l10n.queue,
            ),
          if (!offlineMode.value) ...[
            _buildSimpleActionButton(
              context: context,
              icon: FluentIcons.text_quote_24_regular,
              colorScheme: colorScheme,
              size: responsiveIconSize,
              onPressed: widget.onLyricsTap,
              tooltip: l10n.lyrics,
            ),
          ],
          _buildActionButton(
            context: context,
            icon: FluentIcons.heart_24_regular,
            activeIcon: FluentIcons.heart_24_filled,
            colorScheme: colorScheme,
            size: responsiveIconSize,
            statusNotifier: _songLikeStatus,
            activeColor: colorScheme.primary,
            onPressed: widget.audioId == null
                ? null
                : () {
                    final newStatus = !_songLikeStatus.value;
                    _songLikeStatus.value = newStatus;
                    updateSongLikeStatus(
                      widget.audioId,
                      newStatus,
                      songData: mediaItemToMap(widget.metadata),
                    );
                    showToast(
                      context,
                      newStatus
                          ? l10n.addedToLikedSongs
                          : l10n.removedFromLikedSongs,
                    );
                  },
            tooltip: l10n.likedSongs,
          ),
        ];

        return DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: actions,
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required ColorScheme colorScheme,
    required double size,
    required ValueNotifier<bool> statusNotifier,
    required VoidCallback? onPressed,
    Color? activeColor,
    String? tooltip,
  }) {
    return ValueListenableBuilder<bool>(
      valueListenable: statusNotifier,
      builder: (_, isActive, __) {
        return IconButton(
          icon: Icon(
            isActive ? activeIcon : icon,
            color: isActive
                ? (activeColor ?? colorScheme.primary)
                : colorScheme.onSurfaceVariant,
          ),
          iconSize: size,
          tooltip: tooltip,
          style: IconButton.styleFrom(
            backgroundColor: isActive
                ? (activeColor ?? colorScheme.primary).withValues(alpha: 0.15)
                : colorScheme.surfaceContainerLow.withValues(alpha: 0.8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.all(10),
            minimumSize: const Size(
              AppTokens.minInteractiveSize,
              AppTokens.minInteractiveSize,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: onPressed,
        );
      },
    );
  }

  Widget _buildSimpleActionButton({
    required BuildContext context,
    required IconData icon,
    required ColorScheme colorScheme,
    required double size,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return IconButton(
      icon: Icon(icon, color: colorScheme.onSurfaceVariant),
      iconSize: size,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.surfaceContainerLow.withValues(alpha: 0.8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.all(10),
        minimumSize: const Size(
          AppTokens.minInteractiveSize,
          AppTokens.minInteractiveSize,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
    );
  }

  Widget _buildSleepTimerButton(
    BuildContext context,
    ColorScheme colorScheme,
    double size,
  ) {
    return ValueListenableBuilder<Duration?>(
      valueListenable: sleepTimerNotifier,
      builder: (_, value, __) {
        final isActive = value != null && value != Duration.zero;
        var tooltip = context.l10n!.sleepTimer;
        if (isActive) {
          if (value.inMilliseconds < 0) {
            final count = -value.inMilliseconds;
            tooltip = count == 1
                ? 'Sleep: End of song'
                : 'Sleep: $count songs left';
          } else {
            final mins = value.inMinutes;
            tooltip = mins > 0
                ? 'Sleep: $mins min'
                : 'Sleep: ${value.inSeconds}s';
          }
        }

        return IconButton(
          icon: Icon(
            isActive
                ? FluentIcons.timer_24_filled
                : FluentIcons.timer_24_regular,
            color: isActive
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
          iconSize: size,
          tooltip: tooltip,
          style: IconButton.styleFrom(
            backgroundColor: isActive
                ? colorScheme.primary.withValues(alpha: 0.15)
                : colorScheme.surfaceContainerLow.withValues(alpha: 0.8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.all(10),
            minimumSize: const Size(
              AppTokens.minInteractiveSize,
              AppTokens.minInteractiveSize,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            if (isActive) {
              _showActiveTimerActions(context, value);
            } else {
              _showSleepTimerDialog(context);
            }
          },
        );
      },
    );
  }
}

void _showActiveTimerActions(BuildContext context, Duration currentTimer) {
  final colorScheme = Theme.of(context).colorScheme;
  var info = '';
  if (currentTimer.inMilliseconds < 0) {
    final count = -currentTimer.inMilliseconds;
    info = count == 1
        ? 'Music will stop at the end of this song.'
        : 'Music will stop after $count songs.';
  } else {
    final mins = currentTimer.inMinutes;
    info = mins > 0
        ? 'Music will stop in $mins minutes.'
        : 'Music will stop in ${currentTimer.inSeconds} seconds.';
  }

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(FluentIcons.timer_24_filled, color: colorScheme.primary),
            const SizedBox(width: 12),
            const Text(
              'Sleep Timer Active',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(info),
        actions: [
          TextButton(
            onPressed: () {
              audioHandler.cancelSleepTimer();
              Navigator.pop(context);
              showToast(
                context,
                context.l10n!.sleepTimerCancelled,
                duration: const Duration(seconds: 1, milliseconds: 500),
              );
            },
            child: const Text(
              'Cancel Timer',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _showSleepTimerDialog(context);
            },
            child: const Text('Change'),
          ),
        ],
      );
    },
  );
}

Future<void> _toggleOffline(
  ValueNotifier<bool> status,
  dynamic audioId,
  MediaItem metadata,
) async {
  final originalValue = status.value;
  status.value = !originalValue;

  try {
    final bool success;
    if (originalValue) {
      success = await removeSongFromOffline(audioId);
    } else {
      success = await makeSongOffline(mediaItemToMap(metadata));
    }
    if (!success) {
      status.value = originalValue;
    }
  } catch (e) {
    status.value = originalValue;
    logger.log('Error toggling offline status', error: e);
  }
}

void _showSleepTimerDialog(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;

  showDialog(
    context: context,
    builder: (context) {
      final current = sleepTimerNotifier.value ?? Duration.zero;
      var selectedMode = current.inMilliseconds < 0 ? 1 : 0;
      var hours = current.inMilliseconds > 0 ? (current.inMinutes ~/ 60) : 0;
      var minutes = current.inMilliseconds > 0 ? (current.inMinutes % 60) : 30;
      var songCount = current.inMilliseconds < 0
          ? (-current.inMilliseconds)
          : 1;

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(FluentIcons.timer_24_regular, color: colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  context.l10n!.sleepTimer,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        label: Text('Duration'),
                        icon: Icon(FluentIcons.clock_24_regular, size: 16),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text('Song Count'),
                        icon: Icon(
                          FluentIcons.music_note_2_24_regular,
                          size: 16,
                        ),
                      ),
                    ],
                    selected: {selectedMode},
                    onSelectionChanged: (set) {
                      setState(() => selectedMode = set.first);
                    },
                  ),
                  const SizedBox(height: 20),
                  if (selectedMode == 0) ...[
                    Text(
                      'Music will stop after selected duration',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTimeSelector(
                      context: context,
                      label: context.l10n!.hours,
                      value: hours,
                      colorScheme: colorScheme,
                      onDecrement: () {
                        if (hours > 0) setState(() => hours--);
                      },
                      onIncrement: () {
                        if (hours < 23) setState(() => hours++);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTimeSelector(
                      context: context,
                      label: context.l10n!.minutes,
                      value: minutes,
                      colorScheme: colorScheme,
                      onDecrement: () {
                        if (minutes > 0) setState(() => minutes--);
                      },
                      onIncrement: () {
                        if (minutes < 59) setState(() => minutes++);
                      },
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [15, 30, 45, 60].map((mins) {
                        return ActionChip(
                          label: Text('$mins min'),
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          labelStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onPressed: () {
                            setState(() {
                              hours = mins ~/ 60;
                              minutes = mins % 60;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ] else ...[
                    Text(
                      'Music will stop after playing selected number of songs',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTimeSelector(
                      context: context,
                      label: 'Songs',
                      value: songCount,
                      colorScheme: colorScheme,
                      onDecrement: () {
                        if (songCount > 1) setState(() => songCount--);
                      },
                      onIncrement: () {
                        if (songCount < 99) setState(() => songCount++);
                      },
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        ActionChip(
                          label: const Text('End of current song'),
                          backgroundColor: songCount == 1
                              ? colorScheme.primaryContainer
                              : colorScheme.surfaceContainerHighest,
                          labelStyle: TextStyle(
                            color: songCount == 1
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: songCount == 1
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onPressed: () => setState(() => songCount = 1),
                        ),
                        ...[2, 3, 5, 10].map((count) {
                          return ActionChip(
                            label: Text('$count songs'),
                            backgroundColor: songCount == count
                                ? colorScheme.primaryContainer
                                : colorScheme.surfaceContainerHighest,
                            labelStyle: TextStyle(
                              color: songCount == count
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: songCount == count
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            onPressed: () => setState(() => songCount = count),
                          );
                        }),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(context.l10n!.cancel),
              ),
              FilledButton(
                onPressed: () {
                  if (selectedMode == 0) {
                    final duration = Duration(hours: hours, minutes: minutes);
                    if (duration.inSeconds > 0) {
                      audioHandler.setSleepTimer(duration);
                      showToast(
                        context,
                        context.l10n!.sleepTimerSet,
                        duration: const Duration(seconds: 1, milliseconds: 500),
                      );
                    }
                  } else {
                    audioHandler.setSleepTimerSongCount(songCount);
                    showToast(
                      context,
                      songCount == 1
                          ? 'Sleep timer set: Stop at end of song'
                          : 'Sleep timer set: Stop after $songCount songs',
                      duration: const Duration(seconds: 1, milliseconds: 500),
                    );
                  }
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(context.l10n!.setTimer),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _buildTimeSelector({
  required BuildContext context,
  required String label,
  required int value,
  required ColorScheme colorScheme,
  required VoidCallback onDecrement,
  required VoidCallback onIncrement,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(
                FluentIcons.line_horizontal_1_24_regular,
                color: colorScheme.onSurfaceVariant,
              ),
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: onDecrement,
            ),
            Container(
              width: 48,
              alignment: Alignment.center,
              child: Text(
                '$value',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                FluentIcons.add_24_regular,
                color: colorScheme.onSurfaceVariant,
              ),
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: onIncrement,
            ),
          ],
        ),
      ],
    ),
  );
}
