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
import 'package:flutter/material.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart';
import 'package:catchify/services/artwork_service.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/mediaitem.dart';
import 'package:catchify/utilities/queue_entry_utils.dart';
import 'package:catchify/widgets/confirmation_dialog.dart';
import 'package:catchify/widgets/no_artwork_cube.dart';
import 'package:hive/hive.dart';

class QueueWidget extends StatefulWidget {
  const QueueWidget({super.key, this.isBottomSheet = false});

  final bool isBottomSheet;

  @override
  State<QueueWidget> createState() => _QueueWidgetState();
}

class _QueueWidgetState extends State<QueueWidget> {
  List<Map> _queue = [];
  late StreamSubscription<List<Map>> _subscription;
  late StreamSubscription<MediaItem?> _mediaSubscription;
  bool _isDismissing = false;
  bool _hasScrolledToInitial = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _queue = List<Map>.from(audioHandler.queueList);
    if (_queue.isNotEmpty) {
      _hasScrolledToInitial = true;
      _scrollToCurrentSong();
    }
    _subscription = audioHandler.queueAsMapStream.listen((queue) {
      if (mounted && !_isDismissing) {
        setState(() {
          _queue = List<Map>.from(queue);
        });
        if (!_hasScrolledToInitial && queue.isNotEmpty) {
          _hasScrolledToInitial = true;
          _scrollToCurrentSong();
        }
      }
    });
    // listen to mediaItem changes UI reflects current song accurately.
    _mediaSubscription = audioHandler.mediaItem
        .distinct((prev, next) => prev?.id == next?.id)
        .listen((_) {
          if (mounted && !_isDismissing) setState(() {});
        });
  }

  void _scrollToCurrentSong() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final currentIndex = audioHandler.currentQueueIndex;
      if (currentIndex <= 0) return;
      const estimatedItemHeight = 68.0;
      const topPadding = 4.0;
      final targetOffset = currentIndex * estimatedItemHeight + topPadding;
      final clampedOffset = targetOffset.clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    _mediaSubscription.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentIndex = audioHandler.currentQueueIndex;

    if (widget.isBottomSheet) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context, colorScheme, textTheme, compact: true),
          _buildBottomSheetContent(context, colorScheme, currentIndex),
        ],
      );
    }

    return Column(
      children: [
        _buildHeader(context, colorScheme, textTheme, compact: false),
        Divider(
          height: 1,
          thickness: 1,
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          indent: 8,
          endIndent: 8,
        ),
        Expanded(
          child: _queue.isEmpty
              ? _buildEmptyState(context, colorScheme, textTheme)
              : _buildList(context, colorScheme, currentIndex),
        ),
      ],
    );
  }

  void _confirmClearQueue(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => ConfirmationDialog(
        confirmationMessage: context.l10n!.clearQueueQuestion,
        submitMessage: context.l10n!.clear,
        isDangerous: true,
        onCancel: () => Navigator.pop(context),
        onSubmit: () {
          Navigator.pop(context);
          audioHandler.clearQueue();
          if (widget.isBottomSheet) Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme, {
    required bool compact,
  }) {
    return Padding(
      padding: compact
          ? const EdgeInsets.only(left: 10, right: 8, bottom: 12)
          : const EdgeInsets.fromLTRB(8, 8, 8, 16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(compact ? 8 : 10),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              FluentIcons.apps_list_24_regular,
              color: colorScheme.onPrimaryContainer,
              size: compact ? 20.0 : 22.0,
            ),
          ),
          SizedBox(width: compact ? 12 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n!.queue,
                  style: compact
                      ? TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        )
                      : textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                ),
                if (_queue.isNotEmpty)
                  Text(
                    '${_queue.length} ${context.l10n!.songs.toLowerCase()}',
                    style: compact
                        ? TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          )
                        : textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                  ),
              ],
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: playNextSongAutomatically,
            builder: (context, autoPlay, _) {
              return IconButton.filledTonal(
                onPressed: () {
                  final nextValue = !autoPlay;
                  playNextSongAutomatically.value = nextValue;
                  unawaited(
                    Hive.box(
                      'settings',
                    ).put('playNextSongAutomatically', nextValue),
                  );
                },
                icon: Icon(
                  Icons.all_inclusive,
                  size: compact ? 18 : 20,
                  color: autoPlay
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),

                tooltip: 'Autoplay: ${autoPlay ? 'ON' : 'OFF'}',
                style: IconButton.styleFrom(
                  backgroundColor: autoPlay
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  visualDensity: VisualDensity.compact,
                ),
              );
            },
          ),
          if (_queue.isNotEmpty) ...[
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: () => _confirmClearQueue(context),
              icon: const Icon(FluentIcons.dismiss_24_regular, size: 18),
              label: Text(context.l10n!.clear),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomSheetContent(
    BuildContext context,
    ColorScheme colorScheme,
    int currentIndex,
  ) {
    if (_queue.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          context.l10n!.noSongsInQueue,
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
        ),
      );
    }
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.52,
      child: _buildList(context, colorScheme, currentIndex, closeOnTap: true),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                FluentIcons.music_note_1_24_regular,
                color: colorScheme.onSurfaceVariant,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n!.noSongsInQueue,
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _queueEntryKey(Map song, int index) {
    return song['queueEntryId']?.toString() ?? 'legacy_${song['ytid']}_$index';
  }

  Widget _buildList(
    BuildContext context,
    ColorScheme colorScheme,
    int currentIndex, {
    bool closeOnTap = false,
  }) {
    return ReorderableListView.builder(
      scrollController: _scrollController,
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(top: 4, bottom: 24, left: 8, right: 8),
      itemCount: _queue.length,
      onReorderItem: (oldIndex, newIndex) {
        final movingId =
            _queue[oldIndex]['queueEntryId']?.toString() ??
            'legacy_${_queue[oldIndex]['ytid']}_$oldIndex';

        setState(() {
          final item = _queue.removeAt(oldIndex);
          var insertIndex = newIndex;
          if (insertIndex < 0) insertIndex = 0;
          if (insertIndex > _queue.length) insertIndex = _queue.length;
          _queue.insert(insertIndex, item);
        });

        final actualIndex = _queue.indexWhere(
          (item) => item['queueEntryId']?.toString() == movingId,
        );
        audioHandler.reorderQueueById(movingId, actualIndex);
      },
      proxyDecorator: (child, index, animation) => Material(
        elevation: 8,
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        shadowColor: colorScheme.shadow.withValues(alpha: 0.35),
        child: child,
      ),
      itemBuilder: (context, index) {
        final song = _queue[index];
        final isCurrentSong = index == currentIndex;
        final queueEntryId = _queueEntryKey(song, index);
        return QueueTile(
          key: ValueKey(queueEntryId),
          song: song,
          index: index,
          queueEntryId: queueEntryId,
          isCurrentSong: isCurrentSong,
          colorScheme: colorScheme,
          onTap: () {
            audioHandler.skipToSong(index);
            if (closeOnTap) Navigator.pop(context);
          },
          confirmDismiss: (_) async {
            _isDismissing = true;
            return true;
          },
          onDismissed: () {
            final actualIndex = _queue.indexWhere(
              (item) =>
                  _queueEntryKey(item, _queue.indexOf(item)) == queueEntryId,
            );
            if (actualIndex == -1) return;
            setState(() {
              _isDismissing = false;
              _queue.removeAt(actualIndex);
            });
            audioHandler.removeFromQueue(actualIndex);
          },
        );
      },
    );
  }
}

class QueueTile extends StatelessWidget {
  const QueueTile({
    super.key,
    required this.song,
    required this.index,
    required this.queueEntryId,
    required this.isCurrentSong,
    required this.colorScheme,
    required this.onTap,
    required this.onDismissed,
    this.confirmDismiss,
  });

  final Map song;
  final int index;
  final String queueEntryId;
  final bool isCurrentSong;
  final ColorScheme colorScheme;
  final VoidCallback onTap;
  final VoidCallback onDismissed;
  final Future<bool?> Function(DismissDirection)? confirmDismiss;

  static const double _artSize = 46;
  static const double _artRadius = 10;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(queueEntryId),
      confirmDismiss: confirmDismiss,
      onDismissed: (_) => onDismissed(),
      background: _DismissBackground(
        alignment: Alignment.centerLeft,
        colorScheme: colorScheme,
      ),
      secondaryBackground: _DismissBackground(
        alignment: Alignment.centerRight,
        colorScheme: colorScheme,
      ),
      child: Material(
        color: isCurrentSong
            ? colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: isCurrentSong
              ? BorderSide(color: colorScheme.primary.withValues(alpha: 0.28))
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: Colors.transparent,
          highlightColor: colorScheme.onSurface.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _ArtworkThumbnail(
                  song: song,
                  size: _artSize,
                  radius: _artRadius,
                  colorScheme: colorScheme,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song['title']?.toString() ?? '',
                        style: TextStyle(
                          color: isCurrentSong
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: isCurrentSong
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song['artist']?.toString() ?? '',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isCurrentSong) ...[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        FluentIcons.speaker_2_24_filled,
                        color: colorScheme.primary,
                        size: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 14,
                    ),
                    child: Icon(
                      FluentIcons.re_order_24_regular,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtworkThumbnail extends StatelessWidget {
  const _ArtworkThumbnail({
    required this.song,
    required this.size,
    required this.radius,
    required this.colorScheme,
  });

  final Map song;
  final double size;
  final double radius;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final ytid = canonicalSongId(song);
    final artworkPath = resolveOfflineArtworkPath(
      ytid,
      song['artworkPath']?.toString() ?? song['artWorkPath']?.toString(),
    );
    final imageUrl =
        song['lowResImage']?.toString() ??
        song['image']?.toString() ??
        song['highResImage']?.toString() ??
        '';

    final isHorizontal =
        ArtworkService.isYouTubeThumbnailUrl(imageUrl) ||
        (artworkPath != null &&
            ArtworkService.isYouTubeThumbnailUrl(
              song['highResImage']?.toString() ?? '',
            ));
    final thumbWidth = isHorizontal ? 72.0 : size;
    final thumbHeight = isHorizontal ? 40.0 : size;

    if (artworkPath != null && artworkPath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.file(
          File(artworkPath),
          width: thumbWidth,
          height: thumbHeight,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(thumbWidth, thumbHeight),
        ),
      );
    }

    if (imageUrl.isEmpty) return _fallback(thumbWidth, thumbHeight);

    final cachePx = (math.max(thumbWidth, thumbHeight) * 2).round().clamp(
      64,
      256,
    );

    return CachedNetworkImage(
      width: thumbWidth,
      height: thumbHeight,
      memCacheWidth: cachePx,
      memCacheHeight: cachePx,
      imageUrl: imageUrl,
      imageBuilder: (_, imageProvider) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image(
            image: imageProvider,
            width: thumbWidth,
            height: thumbHeight,
            fit: BoxFit.cover,
          ),
        );
      },
      placeholder: (_, __) => _loading(thumbWidth, thumbHeight),
      errorWidget: (_, __, ___) => _fallback(thumbWidth, thumbHeight),
    );
  }

  Widget _fallback(double w, double h) => NullArtworkWidget(
    size: size,
    width: w,
    height: h,
    borderRadius: radius,
    iconSize: h * 0.45,
  );

  Widget _loading(double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

class _DismissBackground extends StatelessWidget {
  const _DismissBackground({
    required this.alignment,
    required this.colorScheme,
  });

  final Alignment alignment;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        FluentIcons.delete_24_regular,
        color: colorScheme.onErrorContainer,
        size: 22,
      ),
    );
  }
}
