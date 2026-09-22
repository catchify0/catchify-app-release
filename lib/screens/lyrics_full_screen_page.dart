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
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart' show audioHandler;
import 'package:catchify/services/common_services.dart';
import 'package:catchify/utilities/async_loader.dart';
import 'package:catchify/widgets/lyrics_display_widget.dart';
import 'package:catchify/widgets/playback_icon_button.dart';
import 'package:catchify/widgets/position_slider.dart';
import 'package:catchify/widgets/song_artwork.dart';

/// Full-screen lyrics page — Youtify style.
///
/// Layout:
///  - Top    : back chevron + small artwork thumbnail + title + artist
///  - Middle : full-height [LyricsDisplayWidget] (synced or plain)
///  - Bottom : seek bar + prev / play-pause / next
class LyricsFullScreenPage extends StatefulWidget {
  const LyricsFullScreenPage({super.key, required this.metadata});

  final MediaItem metadata;

  @override
  State<LyricsFullScreenPage> createState() => _LyricsFullScreenPageState();
}

class _LyricsFullScreenPageState extends State<LyricsFullScreenPage> {
  Future<String?>? _lyricsFuture;
  String? _cachedKey;

  String _songKey(MediaItem m) =>
      m.id.isNotEmpty ? m.id : '${m.artist ?? ""} - ${m.title}';

  void _fetchIfNeeded(MediaItem m) {
    final key = _songKey(m);
    if (key == _cachedKey) return;
    _cachedKey = key;
    final ytid =
        m.extras?['ytid']?.toString() ?? (m.id.isNotEmpty ? m.id : null);
    _lyricsFuture = getSongLyrics(
      m.artist,
      m.title,
      duration: m.duration?.inSeconds,
      ytid: ytid,
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchIfNeeded(widget.metadata);
  }

  @override
  void didUpdateWidget(LyricsFullScreenPage old) {
    super.didUpdateWidget(old);
    _fetchIfNeeded(widget.metadata);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: StreamBuilder<MediaItem?>(
          stream: audioHandler.mediaItem,
          builder: (context, snap) {
            final metadata = snap.data ?? widget.metadata;
            // Schedule fetch after build to avoid side-effects in build().
            // Only triggers a real re-fetch when song changes.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _fetchIfNeeded(metadata);
            });

            final future = _lyricsFuture;
            if (future == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return Column(
              children: [
                _TopBar(metadata: metadata),
                Expanded(
                  child: AsyncLoader<String?>(
                    key: ValueKey(_cachedKey),
                    future: future,
                    emptyWidget: _emptyLyrics(context, colorScheme),
                    errorBuilder: (_, __, ___) =>
                        _emptyLyrics(context, colorScheme),
                    builder: (context, lyrics) {
                      if (lyrics == null || lyrics.isEmpty) {
                        return _emptyLyrics(context, colorScheme);
                      }
                      final songId =
                          metadata.extras?['ytid']?.toString() ??
                          (metadata.id.isNotEmpty ? metadata.id : null);
                      return LyricsDisplayWidget(
                        key: ValueKey(songId ?? metadata.id),
                        lyrics: lyrics,
                        positionDataStream: audioHandler.positionDataStream,
                        songId: songId,
                      );
                    },
                  ),
                ),
                _BottomControls(colorScheme: colorScheme, size: size),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _emptyLyrics(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FluentIcons.text_quote_24_regular,
            size: 52,
            color: colorScheme.onSurface.withValues(alpha: 0.30),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n?.lyricsNotAvailable ?? 'Lyrics not available',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface.withValues(alpha: 0.50),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({required this.metadata});
  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(FluentIcons.chevron_down_24_regular),
            iconSize: 22,
            style: IconButton.styleFrom(
              backgroundColor:
                  colorScheme.surfaceContainerHigh.withValues(alpha: 0.8),
              foregroundColor: colorScheme.onSurfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SongArtworkWidget(
              metadata: metadata,
              size: 46,
              borderRadius: 8,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  metadata.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamilyFallback: const ['AnekTamil'],
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                if (metadata.artist != null &&
                    metadata.artist!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    metadata.artist!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamilyFallback: const ['AnekTamil'],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom mini controls
// ---------------------------------------------------------------------------

class _BottomControls extends StatelessWidget {
  const _BottomControls({required this.colorScheme, required this.size});
  final ColorScheme colorScheme;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final iconColor = colorScheme.onSurface;
    final iconSize = size.width < 360 ? 36.0 : 40.0;
    final miniSize = size.width < 360 ? 20.0 : 22.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PositionSlider(),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StreamBuilder<PlaybackState>(
                stream: audioHandler.playbackState,
                builder: (context, _) => IconButton(
                  iconSize: miniSize,
                  icon: const Icon(FluentIcons.previous_24_filled),
                  color: iconColor,
                  onPressed: () => audioHandler.skipToPrevious(),
                ),
              ),
              const SizedBox(width: 16),
              buildPlaybackIconButton(
                iconSize,
                colorScheme.onPrimaryContainer,
                colorScheme.primaryContainer,
              ),
              const SizedBox(width: 16),
              StreamBuilder<PlaybackState>(
                stream: audioHandler.playbackState,
                builder: (context, _) => IconButton(
                  iconSize: miniSize,
                  icon: const Icon(FluentIcons.next_24_filled),
                  color: iconColor,
                  onPressed: () => audioHandler.skipToNext(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
