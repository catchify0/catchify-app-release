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

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:catchify/constants/app_tokens.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart';
import 'package:catchify/screens/lyrics_full_screen_page.dart';
import 'package:catchify/utilities/flutter_toast.dart';
import 'package:catchify/utilities/mediaitem.dart';
import 'package:catchify/widgets/now_playing/bottom_actions_row.dart';
import 'package:catchify/widgets/now_playing/now_playing_artwork.dart';
import 'package:catchify/widgets/now_playing/now_playing_controls.dart';
import 'package:catchify/widgets/queue_list_view.dart';

/// Now Playing page — hosts both the normal artwork/controls view and the
/// inline full-screen lyrics view. Switching between the two is animated
/// with a cross-fade so it feels like a seamless in-page transition rather
/// than a separate route push.
class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  bool _showLyrics = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLargeScreen = size.width > 800 && size.height > 600;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = size.width;
    final baseIconSize = screenWidth < 360
        ? 36.0
        : screenWidth < 400
        ? 40.0
        : 44.0;
    final miniIconSize = screenWidth < 360 ? 18.0 : 22.0;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: StreamBuilder<MediaItem?>(
          stream: audioHandler.mediaItem,
          builder: (context, snapshot) {
            if (snapshot.data == null || !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final metadata = snapshot.data!;

            return Stack(
              children: [
                // Background radial gradient — always visible
                Positioned(
                  top: -size.height * 0.12,
                  left: -size.width * 0.2,
                  right: -size.width * 0.2,
                  height: size.height * 0.7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          colorScheme.primary.withValues(alpha: 0.22),
                          colorScheme.primary.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                        radius: 0.85,
                      ),
                    ),
                  ),
                ),

                // Cross-fade switcher between normal view and lyrics view
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                  child: _showLyrics
                      ? LyricsFullScreenPage(
                          key: const ValueKey('lyrics'),
                          metadata: metadata,
                          onClose: () =>
                              setState(() => _showLyrics = false),
                        )
                      : Column(
                          key: const ValueKey('normal'),
                          children: [
                            _buildAppBar(context, colorScheme, metadata),
                            Expanded(
                              child: isLargeScreen
                                  ? _DesktopLayout(
                                      metadata: metadata,
                                      size: size,
                                      adjustedIconSize: baseIconSize,
                                      adjustedMiniIconSize: miniIconSize,
                                      onLyricsTap: () => setState(
                                            () => _showLyrics = true,
                                          ),
                                    )
                                  : _MobileLayout(
                                      metadata: metadata,
                                      size: size,
                                      adjustedIconSize: baseIconSize,
                                      adjustedMiniIconSize: miniIconSize,
                                      isLargeScreen: isLargeScreen,
                                      onLyricsTap: () => setState(
                                            () => _showLyrics = true,
                                          ),
                                    ),
                            ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    ColorScheme colorScheme,
    MediaItem metadata,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            iconSize: 24,
            icon: const Icon(FluentIcons.chevron_down_24_regular),
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHigh.withValues(
                alpha: 0.8,
              ),
              foregroundColor: colorScheme.onSurfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(10),
              minimumSize: const Size(
                AppTokens.minInteractiveSize,
                AppTokens.minInteractiveSize,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'NOW PLAYING',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          IconButton(
            iconSize: 22,
            icon: const Icon(Icons.radio),
            tooltip: context.l10n?.startRadio ?? 'Start Radio',
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHigh.withValues(
                alpha: 0.8,
              ),
              foregroundColor: colorScheme.onSurfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(10),
              minimumSize: const Size(
                AppTokens.minInteractiveSize,
                AppTokens.minInteractiveSize,
              ),
            ),
            onPressed: () {
              final song = mediaItemToMap(metadata);
              showToast(
                context,
                context.l10n?.startingRadio ?? 'Starting radio...',
                duration: const Duration(seconds: 1),
              );
              unawaited(audioHandler.startSongRadio(song));
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop layout
// ---------------------------------------------------------------------------

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.metadata,
    required this.size,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
    required this.onLyricsTap,
  });
  final MediaItem metadata;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final VoidCallback onLyricsTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Expanded(
                  flex: 5,
                  child: Center(
                    child: NowPlayingArtwork(
                      size: size,
                      metadata: metadata,
                    ),
                  ),
                ),
                if (!(metadata.extras?['isLive'] ?? false))
                  Expanded(
                    flex: 4,
                    child: NowPlayingControls(
                      size: size,
                      audioId: metadata.extras?['ytid'],
                      adjustedIconSize: adjustedIconSize,
                      adjustedMiniIconSize: adjustedMiniIconSize,
                      metadata: metadata,
                    ),
                  ),
                BottomActionsRow(
                  audioId: metadata.extras?['ytid'],
                  metadata: metadata,
                  iconSize: adjustedMiniIconSize,
                  isLargeScreen: true,
                  onLyricsTap: onLyricsTap,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        const Expanded(child: QueueWidget()),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Mobile layout
// ---------------------------------------------------------------------------

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.metadata,
    required this.size,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
    required this.isLargeScreen,
    required this.onLyricsTap,
  });
  final MediaItem metadata;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final bool isLargeScreen;
  final VoidCallback onLyricsTap;

  @override
  Widget build(BuildContext context) {
    final isLandscape = size.width > size.height;

    if (isLandscape) {
      return _buildLandscapeLayout(context);
    }
    return _buildPortraitLayout(context);
  }

  Widget _buildPortraitLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Expanded(
            flex: 5,
            child: Center(
              child: NowPlayingArtwork(
                size: size,
                metadata: metadata,
              ),
            ),
          ),
          if (!(metadata.extras?['isLive'] ?? false))
            Expanded(
              flex: 4,
              child: NowPlayingControls(
                size: size,
                audioId: metadata.extras?['ytid'],
                adjustedIconSize: adjustedIconSize,
                adjustedMiniIconSize: adjustedMiniIconSize,
                metadata: metadata,
              ),
            ),
          BottomActionsRow(
            audioId: metadata.extras?['ytid'],
            metadata: metadata,
            iconSize: adjustedMiniIconSize,
            isLargeScreen: isLargeScreen,
            onLyricsTap: onLyricsTap,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Center(
              child: NowPlayingArtwork(
                size: size,
                metadata: metadata,
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!(metadata.extras?['isLive'] ?? false))
                  Expanded(
                    child: NowPlayingControls(
                      size: size,
                      audioId: metadata.extras?['ytid'],
                      adjustedIconSize: adjustedIconSize,
                      adjustedMiniIconSize: adjustedMiniIconSize,
                      metadata: metadata,
                    ),
                  ),
                BottomActionsRow(
                  audioId: metadata.extras?['ytid'],
                  metadata: metadata,
                  iconSize: adjustedMiniIconSize,
                  isLargeScreen: isLargeScreen,
                  onLyricsTap: onLyricsTap,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
