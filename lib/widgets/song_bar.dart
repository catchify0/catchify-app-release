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

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:catchify/constants/app_tokens.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart';
import 'package:catchify/services/artwork_service.dart';
import 'package:catchify/services/common_services.dart';
import 'package:catchify/services/io_service.dart';
import 'package:catchify/services/playlists_manager.dart';
import 'package:catchify/services/router_service.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/app_utils.dart';
import 'package:catchify/utilities/flutter_toast.dart';
import 'package:catchify/utilities/formatter.dart';
import 'package:catchify/utilities/playlist_dialogs.dart';
import 'package:catchify/widgets/no_artwork_cube.dart';
import 'package:catchify/widgets/overflow_menu_button.dart';
import 'package:catchify/widgets/rename_song_dialog.dart';

List<PopupMenuEntry<String>> _buildSongMenuItems({
  required BuildContext context,
  required ColorScheme colorScheme,
  required ValueListenable<bool> songLikeStatus,
  required ValueListenable<bool> songOfflineStatus,
  required bool showQueueActions,
  bool isRecentSong = false,
  bool canRename = false,
  bool canRemove = false,
  bool showGoToArtist = false,
}) {
  final l10n = context.l10n!;
  final playNextText = l10n.playNext;
  final addToQueueText = l10n.addToQueue;
  final removeFromLikedSongsText = l10n.removeFromLikedSongs;
  final addToLikedSongsText = l10n.addToLikedSongs;
  final removeFromPlaylistText = l10n.removeFromPlaylist;
  final addToPlaylistText = l10n.addToPlaylist;
  final removeFromRecentlyPlayedText = l10n.removeFromRecentlyPlayed;
  final removeOfflineText = l10n.removeOffline;
  final makeOfflineText = l10n.makeOffline;
  final renameSongText = l10n.renameSong;

  return [
    if (showQueueActions)
      PopupMenuItem<String>(
        value: 'start_radio',
        child: Row(
          children: [
            Icon(Icons.radio, color: colorScheme.onSurfaceVariant),

            const SizedBox(width: 8),
            Text(
              context.l10n?.startRadio ?? 'Start Radio',
              style: TextStyle(color: colorScheme.onSurface),
            ),
          ],
        ),
      ),
    if (showQueueActions)
      PopupMenuItem<String>(
        value: 'play_next',
        child: Row(
          children: [
            Icon(
              FluentIcons.receipt_play_24_regular,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(playNextText, style: TextStyle(color: colorScheme.onSurface)),
          ],
        ),
      ),
    if (showGoToArtist)
      PopupMenuItem<String>(
        value: 'go_to_artist',
        child: Row(
          children: [
            Icon(
              FluentIcons.person_24_regular,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.goToArtist,
              style: TextStyle(color: colorScheme.onSurface),
            ),
          ],
        ),
      ),
    if (showQueueActions)
      PopupMenuItem<String>(
        value: 'add_to_queue',
        child: Row(
          children: [
            Icon(
              FluentIcons.text_bullet_list_add_24_regular,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              addToQueueText,
              style: TextStyle(color: colorScheme.onSurface),
            ),
          ],
        ),
      ),
    PopupMenuItem<String>(
      value: 'like',
      child: ValueListenableBuilder<bool>(
        valueListenable: songLikeStatus,
        builder: (_, value, __) {
          return Row(
            children: [
              Icon(
                _SongBarState.likeStatusToIconMapper[value],
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                value ? removeFromLikedSongsText : addToLikedSongsText,
                style: TextStyle(color: colorScheme.onSurface),
              ),
            ],
          );
        },
      ),
    ),
    if (canRename)
      PopupMenuItem<String>(
        value: 'rename',
        child: Row(
          children: [
            Icon(
              FluentIcons.edit_24_regular,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              renameSongText,
              style: TextStyle(color: colorScheme.onSurface),
            ),
          ],
        ),
      ),
    if (canRemove)
      PopupMenuItem<String>(
        value: 'remove',
        child: Row(
          children: [
            Icon(
              FluentIcons.delete_24_regular,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              removeFromPlaylistText,
              style: TextStyle(color: colorScheme.onSurface),
            ),
          ],
        ),
      ),
    if (!offlineMode.value)
      PopupMenuItem<String>(
        value: 'add_to_playlist',
        child: Row(
          children: [
            Icon(
              FluentIcons.album_add_24_regular,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              addToPlaylistText,
              style: TextStyle(color: colorScheme.onSurface),
            ),
          ],
        ),
      ),
    if (isRecentSong)
      PopupMenuItem<String>(
        value: 'remove_from_recents',
        child: Row(
          children: [
            Icon(
              FluentIcons.delete_24_regular,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              removeFromRecentlyPlayedText,
              style: TextStyle(color: colorScheme.onSurface),
            ),
          ],
        ),
      ),
    if (!offlineMode.value || songOfflineStatus.value)
      PopupMenuItem<String>(
        value: 'offline',
        child: ValueListenableBuilder<bool>(
          valueListenable: songOfflineStatus,
          builder: (_, value, __) {
            return Row(
              children: [
                Icon(
                  value
                      ? FluentIcons.cloud_dismiss_24_regular
                      : FluentIcons.cloud_arrow_down_24_regular,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  value ? removeOfflineText : makeOfflineText,
                  style: TextStyle(color: colorScheme.onSurface),
                ),
              ],
            );
          },
        ),
      ),
  ];
}

Future<void> _handleSongMenuAction({
  required BuildContext context,
  required String value,
  required dynamic song,
  required String ytid,
  required ValueNotifier<bool> songLikeStatus,
  required ValueNotifier<bool> songOfflineStatus,
  required ValueNotifier<bool> songDownloadStatus,
  VoidCallback? onRemove,
  FutureOr<void> Function()? onRename,
}) async {
  switch (value) {
    case 'start_radio':
      if (song is Map) {
        showToast(
          context,
          context.l10n?.startingRadio ?? 'Starting radio...',
          duration: const Duration(seconds: 1),
        );
        unawaited(audioHandler.startSongRadio(song));
      }
      break;
    case 'play_next':
      await audioHandler.playNext(song);
      showToast(
        context,
        context.l10n!.songAdded,
        duration: const Duration(seconds: 1),
      );
      break;
    case 'go_to_artist':
      final artistName = song is Map ? getDisplayArtist(song) : '';
      if (artistName.isEmpty) return;
      unawaited(
        context.push(
          '${NavigationManager.searchPath}/artist/${Uri.encodeComponent(artistName)}',
          extra: {'title': artistName, 'ytid': artistName},
        ),
      );
      break;
    case 'add_to_queue':
      await audioHandler.addToQueue(song);
      showToast(
        context,
        context.l10n!.songAdded,
        duration: const Duration(seconds: 1),
      );
      break;
    case 'like':
      final newValue = !songLikeStatus.value;
      songLikeStatus.value = newValue;
      showToast(
        context,
        newValue
            ? context.l10n!.addedToLikedSongs
            : context.l10n!.removedFromLikedSongs,
        duration: const Duration(seconds: 1),
      );
      try {
        await updateSongLikeStatus(ytid, newValue, songData: song);
      } catch (e) {
        logger.log('Error updating song like status', error: e);
        songLikeStatus.value = !newValue;
      }
      break;
    case 'remove':
      onRemove?.call();
      break;
    case 'rename':
      await onRename?.call();
      break;
    case 'add_to_playlist':
      showAddToPlaylistDialog(context, song: song);
      break;
    case 'remove_from_recents':
      try {
        await removeFromRecentlyPlayed(ytid);
      } catch (e) {
        logger.log('Error removing from recently played', error: e);
      }
      break;
    case 'offline':
      await _toggleSongOfflineStatus(
        context,
        song,
        ytid,
        songOfflineStatus,
        songDownloadStatus,
      );
      break;
  }
}

Future<void> _toggleSongOfflineStatus(
  BuildContext context,
  dynamic song,
  String ytid,
  ValueNotifier<bool> songOfflineStatus,
  ValueNotifier<bool> songDownloadStatus,
) async {
  final originalValue = songOfflineStatus.value;

  try {
    final bool success;
    if (originalValue) {
      songOfflineStatus.value = false;
      success = await removeSongFromOffline(ytid);
      if (success && context.mounted) {
        showToast(context, context.l10n!.songRemovedFromOffline);
      }
    } else {
      songDownloadStatus.value = true;
      success = await makeSongOffline(song);
      if (success && context.mounted) {
        showToast(context, context.l10n!.songAddedToOffline);
      }
      songDownloadStatus.value = false;
    }

    if (!success) {
      songOfflineStatus.value = originalValue;
    }
  } catch (e) {
    songDownloadStatus.value = false;
    songOfflineStatus.value = originalValue;
    logger.log('Error toggling offline status', error: e);
    if (context.mounted) {
      showToast(context, context.l10n!.error);
    }
  }
}

class SongBar extends StatefulWidget {
  const SongBar(
    this.song,
    this.clearPlaylist, {
    this.backgroundColor,
    this.showMusicDuration = false,
    this.onPlay,
    this.isRecentSong,
    this.onRemove,
    this.borderRadius = BorderRadius.zero,
    this.isFromLikedSongs = false,
    this.showQueueActions = true,
    this.showPlayTime = false,
    this.playlistId,
    this.onRenamed,
    this.rank,
    this.barPadding,
    super.key,
  });

  final dynamic song;
  final bool clearPlaylist;
  final Color? backgroundColor;
  final VoidCallback? onRemove;
  final VoidCallback? onPlay;
  final bool? isRecentSong;
  final bool showMusicDuration;
  final bool showPlayTime;
  final BorderRadius borderRadius;
  final bool isFromLikedSongs;
  final bool showQueueActions;
  final String? playlistId;
  final VoidCallback? onRenamed;
  final EdgeInsetsGeometry? barPadding;
  final int? rank;
  @override
  State<SongBar> createState() => _SongBarState();
}

class _SongBarState extends State<SongBar> {
  static const likeStatusToIconMapper = {
    true: FluentIcons.heart_off_24_regular,
    false: FluentIcons.heart_24_regular,
  };

  late final ValueNotifier<bool> _songLikeStatus;
  late final ValueNotifier<bool> _songOfflineStatus;
  late final ValueNotifier<bool> _songDownloadStatus;
  late String _songTitle;
  late String _songArtist;
  String? _artworkPath;
  late String _lowResImageUrl;
  late String _ytid;

  @override
  void initState() {
    super.initState();

    // Cache frequently accessed values
    _songTitle = widget.song['title'] ?? '';
    _songArtist = widget.song is Map ? getDisplayArtist(widget.song) : '';
    _artworkPath = _resolveArtworkPath(
      _firstNonEmptyString([
        widget.song['artworkPath'],
        widget.song['artWorkPath'],
      ]),
      widget.song['ytid']?.toString() ?? '',
    );
    _lowResImageUrl =
        _firstNonEmptyString([
          widget.song['highResImage'],
          widget.song['image'],
          widget.song['lowResImage'],
        ]) ??
        '';
    if (_lowResImageUrl.isNotEmpty) {
      _lowResImageUrl = formatArtworkResolution(_lowResImageUrl, 240);
    }
    _ytid = widget.song['ytid'] ?? '';

    // Initialize ValueNotifiers only once
    _songLikeStatus = ValueNotifier(isSongAlreadyLiked(_ytid));
    final isOffline = isSongAlreadyOffline(_ytid);
    _songOfflineStatus = ValueNotifier(isOffline);
    _songDownloadStatus = ValueNotifier(false);
    userLikedSongsList.addListener(_syncLikeStatus);
    userOfflineSongs.addListener(_syncOfflineStatus);
  }

  void _syncLikeStatus() {
    final newStatus = isSongAlreadyLiked(_ytid);
    if (_songLikeStatus.value != newStatus) {
      _songLikeStatus.value = newStatus;
    }
  }

  void _syncOfflineStatus() {
    final newStatus = isSongAlreadyOffline(_ytid);
    if (_songOfflineStatus.value != newStatus) {
      _songOfflineStatus.value = newStatus;
    }
  }

  @override
  void didUpdateWidget(SongBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newTitle = widget.song['title'] ?? '';
    final newArtist = widget.song is Map ? getDisplayArtist(widget.song) : '';
    final newYtid = widget.song['ytid'] ?? '';
    final newArtworkPath = _firstNonEmptyString([
      widget.song['artworkPath'],
      widget.song['artWorkPath'],
    ]);
    final rawNewImageUrl =
        _firstNonEmptyString([
          widget.song['highResImage'],
          widget.song['image'],
          widget.song['lowResImage'],
        ]) ??
        '';
    final newLowResImageUrl = rawNewImageUrl.isNotEmpty
        ? formatArtworkResolution(rawNewImageUrl, 240)
        : '';

    final songChanged = _ytid != newYtid;
    if (songChanged) {
      _ytid = newYtid;
      _songLikeStatus.value = isSongAlreadyLiked(_ytid);
      _songOfflineStatus.value = isSongAlreadyOffline(_ytid);
    }

    if (_songTitle != newTitle ||
        _songArtist != newArtist ||
        _artworkPath != _resolveArtworkPath(newArtworkPath, newYtid) ||
        _lowResImageUrl != newLowResImageUrl ||
        songChanged) {
      setState(() {
        _songTitle = newTitle;
        _songArtist = newArtist;
        _artworkPath = _resolveArtworkPath(newArtworkPath, newYtid);
        _lowResImageUrl = newLowResImageUrl;
      });
    }
  }

  String? _resolveArtworkPath(String? metadataPath, String ytid) {
    if (metadataPath != null &&
        metadataPath.isNotEmpty &&
        File(metadataPath).existsSync()) {
      return metadataPath;
    }
    if (ytid.isEmpty || !isSongAlreadyOffline(ytid)) return metadataPath;

    try {
      final canonicalPath = FilePaths.getArtworkPath(ytid);
      if (File(canonicalPath).existsSync()) return canonicalPath;
    } catch (_) {}
    return metadataPath;
  }

  @override
  void dispose() {
    userLikedSongsList.removeListener(_syncLikeStatus);
    userOfflineSongs.removeListener(_syncOfflineStatus);
    _songLikeStatus.dispose();
    _songOfflineStatus.dispose();
    _songDownloadStatus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final _plays = widget.showPlayTime
        ? (widget.song['listeningCount'] is int)
              ? widget.song['listeningCount'] as int
              : int.tryParse(widget.song['listeningCount']?.toString() ?? '') ??
                    0
        : null;

    final activeRadius = widget.borderRadius == BorderRadius.zero
        ? BorderRadius.circular(AppTokens.radiusControl)
        : widget.borderRadius;

    return StreamBuilder<MediaItem?>(
      initialData: audioHandler.mediaItem.valueOrNull,
      stream: audioHandler.mediaItem,
      builder: (context, mediaSnapshot) {
        final currentId =
            (mediaSnapshot.data ?? audioHandler.mediaItem.valueOrNull)?.id;
        final isCurrentSong =
            currentId != null && currentId.isNotEmpty && currentId == _ytid;

        return Material(
          color:
              widget.backgroundColor ??
              (isCurrentSong
                  ? colorScheme.primary.withValues(alpha: 0.08)
                  : colorScheme.surfaceContainerLow),
          borderRadius: activeRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _handleSongTap,
            borderRadius: activeRadius,
            splashColor: colorScheme.primary.withValues(alpha: 0.12),
            highlightColor: colorScheme.primary.withValues(alpha: 0.06),
            child: Padding(
              padding:
                  widget.barPadding ??
                  const EdgeInsetsDirectional.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
              child: Row(
                children: [
                  if (widget.rank != null) ...[
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${widget.rank}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],

                  _buildAlbumArt(colorScheme),
                  const SizedBox(width: 14),

                  Expanded(
                    child: _SongInfo(
                      title: _songTitle,
                      artist: _songArtist,
                      plays: _plays,
                      colorScheme: colorScheme,
                      isCurrentSong: isCurrentSong,
                    ),
                  ),

                  OverflowMenuButton<String>(
                    onSelected: (value) => _handleSongMenuAction(
                      context: context,
                      value: value,
                      song: widget.song,
                      ytid: _ytid,
                      songLikeStatus: _songLikeStatus,
                      songOfflineStatus: _songOfflineStatus,
                      songDownloadStatus: _songDownloadStatus,
                      onRemove: widget.onRemove,
                      onRename: () => _handleRenameSong(context),
                    ),
                    itemBuilder: (context) =>
                        _buildMenuItems(context, colorScheme),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleSongTap() {
    if (widget.onPlay != null) {
      widget.onPlay!();
      return;
    }

    audioHandler.playNow(widget.song);
  }

  Widget _buildAlbumArt(ColorScheme colorScheme) {
    final rawUrl =
        _firstNonEmptyString([
          _lowResImageUrl,
          widget.song['image'],
          widget.song['highResImage'],
        ]) ??
        '';
    final isHorizontal = ArtworkService.isYouTubeThumbnailUrl(rawUrl);
    final artWidth = isHorizontal ? 76.0 : 52.0;
    final artHeight = isHorizontal ? 44.0 : 52.0;

    final songDuration = widget.song['duration'];
    final isDurationAvailable =
        widget.showMusicDuration &&
        songDuration != null &&
        (songDuration is! num || songDuration > 0);

    return ValueListenableBuilder<bool>(
      valueListenable: _songDownloadStatus,
      builder: (context, isDownloading, _) => Stack(
        alignment: Alignment.center,
        children: [
          _ArtworkDisplay(
            lowResImageUrl: _lowResImageUrl,
            artworkPath: _artworkPath,
            width: artWidth,
            height: artHeight,
            size: 52,
            isDurationAvailable: isDurationAvailable,
            colorScheme: colorScheme,
            offlineStatus: _songOfflineStatus,
            likeStatus: _songLikeStatus,
            duration: widget.song['duration'],
          ),
          if (isDownloading)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ColoredBox(
                  color: colorScheme.scrim.withValues(alpha: 0.42),
                  child: Center(
                    child: Material(
                      color: colorScheme.primaryContainer,
                      elevation: 2,
                      shape: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: colorScheme.onPrimaryContainer,
                            backgroundColor: colorScheme.primaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleRenameSong(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => RenameSongDialog(
        currentTitle: _songTitle,
        currentArtist: _songArtist,
        onRename: (newTitle, newArtist) {
          _renameSong(newTitle, newArtist, context);
        },
      ),
    );
  }

  Future<void> _renameSong(
    String newTitle,
    String newArtist,
    BuildContext context,
  ) async {
    try {
      if (widget.isFromLikedSongs) {
        await renameSongInLikedSongs(_ytid, newTitle, newArtist);
        widget.song['title'] = newTitle;
        widget.song['artist'] = newArtist;
        if (!mounted) return;
        setState(() {
          _songTitle = newTitle;
          _songArtist = newArtist;
        });
        if (context.mounted) {
          showToast(context, context.l10n!.settingChangedMsg);
        }
      } else if (widget.playlistId != null) {
        await renameSongInPlaylist(
          widget.playlistId,
          _ytid,
          newTitle,
          newArtist,
        );
        widget.song['title'] = newTitle;
        widget.song['artist'] = newArtist;
        if (!mounted) return;
        setState(() {
          _songTitle = newTitle;
          _songArtist = newArtist;
        });
        if (context.mounted) {
          showToast(context, context.l10n!.settingChangedMsg);
          widget.onRenamed?.call();
        }
      }
    } catch (e, stackTrace) {
      logger.log('Error renaming song', error: e, stackTrace: stackTrace);
      if (context.mounted) {
        showToast(context, context.l10n!.error);
      }
    }
  }

  List<PopupMenuEntry<String>> _buildMenuItems(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    final canRename = widget.isFromLikedSongs || widget.playlistId != null;

    return _buildSongMenuItems(
      context: context,
      colorScheme: colorScheme,
      songLikeStatus: _songLikeStatus,
      songOfflineStatus: _songOfflineStatus,
      showQueueActions: widget.showQueueActions,
      isRecentSong: widget.isRecentSong == true,
      canRename: canRename,
      canRemove: widget.onRemove != null,
      showGoToArtist: _songArtist.isNotEmpty,
    );
  }
}

class _SongInfo extends StatelessWidget {
  const _SongInfo({
    required this.title,
    required this.artist,
    this.plays,
    required this.colorScheme,
    this.isCurrentSong = false,
  });

  final String title;
  final String artist;
  final int? plays;
  final ColorScheme colorScheme;
  final bool isCurrentSong;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: [
            if (isCurrentSong) ...[
              Icon(
                FluentIcons.speaker_2_24_filled,
                size: 14,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 5),
            ],
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: isCurrentSong ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 15,
                  color: isCurrentSong
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Flexible(
              child: Text(
                artist,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (plays != null && plays! > 0) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '•',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(
                FluentIcons.headphones_20_filled,
                size: 12,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 3),
              Text(
                '$plays',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

String? _firstNonEmptyString(Iterable<Object?> values) {
  for (final value in values) {
    final stringValue = value?.toString().trim();
    if (stringValue != null && stringValue.isNotEmpty) return stringValue;
  }
  return null;
}

class _ArtworkDisplay extends StatelessWidget {
  const _ArtworkDisplay({
    required this.lowResImageUrl,
    required this.artworkPath,
    required this.width,
    required this.height,
    required this.size,
    required this.isDurationAvailable,
    required this.colorScheme,
    required this.offlineStatus,
    required this.likeStatus,
    required this.duration,
  });

  final String lowResImageUrl;
  final String? artworkPath;
  final double width;
  final double height;
  final double size;
  final bool isDurationAvailable;
  final ColorScheme colorScheme;
  final ValueListenable<bool> offlineStatus;
  final ValueListenable<bool> likeStatus;
  final dynamic duration;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: offlineStatus,
      builder: (_, isOffline, __) {
        if (isOffline && artworkPath != null) {
          return _OfflineArtwork(
            artworkPath: artworkPath!,
            width: width,
            height: height,
            colorScheme: colorScheme,
          );
        }

        return ValueListenableBuilder<bool>(
          valueListenable: likeStatus,
          builder: (_, isLiked, __) {
            return _OnlineArtwork(
              lowResImageUrl: lowResImageUrl,
              width: width,
              height: height,
              size: size,
              isDurationAvailable: isDurationAvailable,
              colorScheme: colorScheme,
              duration: duration,
              isOffline: isOffline,
              isLiked: isLiked,
            );
          },
        );
      },
    );
  }
}

class _OfflineArtwork extends StatelessWidget {
  const _OfflineArtwork({
    required this.artworkPath,
    required this.width,
    required this.height,
    required this.colorScheme,
  });

  final String artworkPath;
  final double width;
  final double height;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Image.file(
              File(artworkPath),
              width: width,
              height: height,
              cacheWidth: (width * 2).round().clamp(120, 240),
              cacheHeight: (height * 2).round().clamp(120, 240),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  NullArtworkWidget(iconSize: 24, width: width, height: height),
            ),
            Positioned(
              top: 3,
              right: 3,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  FluentIcons.cloud_off_24_filled,
                  size: 11,
                  color: colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnlineArtwork extends StatelessWidget {
  const _OnlineArtwork({
    required this.lowResImageUrl,
    required this.width,
    required this.height,
    required this.size,
    required this.isDurationAvailable,
    required this.colorScheme,
    required this.duration,
    required this.isOffline,
    required this.isLiked,
  });

  final String lowResImageUrl;
  final double width;
  final double height;
  final double size;
  final bool isDurationAvailable;
  final ColorScheme colorScheme;
  final dynamic duration;
  final bool isOffline;
  final bool isLiked;

  @override
  Widget build(BuildContext context) {
    final cachePx = (math.max(width, height) * 3).toInt().clamp(120, 240);

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CachedNetworkImage(
            imageUrl: lowResImageUrl,
            width: width,
            height: height,
            fit: BoxFit.cover,
            memCacheWidth: cachePx,
            memCacheHeight: cachePx,
            placeholder: (_, __) => NullArtworkWidget(
              iconSize: 22,
              width: width,
              height: height,
              borderRadius: 10,
            ),
            imageBuilder: (context, imageProvider) {
              final imageWidget = Image(
                image: imageProvider,
                fit: BoxFit.cover,
                width: width,
                height: height,
              );

              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    imageWidget,
                    if (isOffline)
                      Positioned(
                        top: 3,
                        right: 3,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: colorScheme.tertiaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            FluentIcons.cloud_off_24_filled,
                            size: 11,
                            color: colorScheme.onTertiaryContainer,
                          ),
                        ),
                      )
                    else if (isLiked)
                      Positioned(
                        top: 3,
                        right: 3,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            FluentIcons.heart_24_filled,
                            size: 11,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
            errorWidget: (context, url, error) {
              if (url.contains('maxresdefault.jpg')) {
                return CachedNetworkImage(
                  imageUrl: url.replaceFirst(
                    'maxresdefault.jpg',
                    'mqdefault.jpg',
                  ),
                  width: width,
                  height: height,
                  fit: BoxFit.cover,
                  memCacheWidth: 512,
                  memCacheHeight: 512,
                  errorWidget: (_, __, ___) => NullArtworkWidget(
                    iconSize: 24,
                    width: width,
                    height: height,
                  ),
                );
              }
              return NullArtworkWidget(
                iconSize: 24,
                width: width,
                height: height,
              );
            },
          ),
          if (isDurationAvailable)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.85,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  formatDuration(duration),
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
