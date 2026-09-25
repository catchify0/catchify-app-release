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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:catchify/constants/app_constants.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart' show logger, audioHandler;
import 'package:catchify/services/audio_permission_service.dart';
import 'package:catchify/services/common_services.dart';
import 'package:catchify/services/data_manager.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/app_utils.dart';
import 'package:catchify/utilities/flutter_toast.dart';
import 'package:catchify/utilities/playlist_utils.dart';
import 'package:catchify/utilities/song_filtering.dart';
import 'package:catchify/widgets/confirmation_dialog.dart';
import 'package:catchify/widgets/mini_player_bottom_space.dart';
import 'package:catchify/widgets/playlist_cube.dart';
import 'package:catchify/widgets/playlist_page/empty_playlist_state.dart';
import 'package:catchify/widgets/playlist_page/playlist_header.dart';
import 'package:catchify/widgets/playlist_page/search_bar_section.dart';
import 'package:catchify/widgets/song_bar.dart';
import 'package:catchify/widgets/sort_chips.dart';

enum OfflineSortType { default_, title, artist, dateAdded }

class UserSongsPage extends StatefulWidget {
  const UserSongsPage({super.key, required this.page});

  final String page;

  @override
  State<UserSongsPage> createState() => _UserSongsPageState();
}

class _UserSongsPageState extends State<UserSongsPage> {
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier('');
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  bool _isRefreshingLocalSongs = false;

  List get _currentSongsList {
    return switch (widget.page) {
      'liked' => userLikedSongsList.value,
      'offline' => userOfflineSongs.value,
      'local' => userLocalSongs.value,
      _ => userRecentlyPlayed.value,
    };
  }

  List _getDisplayList(List songsList) {
    var list = filterSongsByQuery(songsList, _searchQueryNotifier.value);
    if (widget.page == 'offline') {
      list = _sortOfflineSongsLocal(list, _getCurrentOfflineSortType());
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchQueryNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = getTitle(widget.page, context);
    final icon = getIcon(widget.page);
    final isOfflineSongs = title == context.l10n!.offlineSongs;
    final isLocalSongs = widget.page == 'local';

    return Scaffold(
      appBar: AppBar(
        title: offlineMode.value ? Text(title) : null,
        actions: [
          if (isLocalSongs)
            IconButton(
              onPressed: _isRefreshingLocalSongs ? null : _refreshLocalSongs,
              icon: _isRefreshingLocalSongs
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      FluentIcons.arrow_clockwise_24_regular,
                      color: Theme.of(context).colorScheme.primary,
                    ),
            ),
        ],
      ),
      body: Padding(
        padding: commonSingleChildScrollViewPadding,
        child: ValueListenableBuilder(
          valueListenable: widget.page == 'liked'
              ? userLikedSongsList
              : widget.page == 'offline'
              ? userOfflineSongs
              : widget.page == 'local'
              ? userLocalSongs
              : userRecentlyPlayed,
          builder: (_, songsList, __) => _buildCustomScrollView(
            title,
            icon,
            songsList.length,
            isOfflineSongs,
          ),
        ),
      ),
    );
  }

  OfflineSortType _getCurrentOfflineSortType() {
    return OfflineSortType.values.firstWhere(
      (e) => e.name == offlineSortSetting,
      orElse: () => OfflineSortType.default_,
    );
  }

  Widget _buildCustomScrollView(
    String title,
    IconData icon,
    int songsLength,
    bool isOfflineSongs,
  ) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _buildHeaderSection(title, icon, songsLength, isOfflineSongs),
        ),
        buildSongList(title),
        const SliverMiniPlayerBottomSpace(),
      ],
    );
  }

  String getTitle(String page, BuildContext context) {
    return switch (page) {
      'liked' => context.l10n!.likedSongs,
      'local' => 'Local songs',
      'offline' => context.l10n!.offlineSongs,
      'recents' => context.l10n!.recentlyPlayed,
      _ => context.l10n!.playlist,
    };
  }

  IconData getIcon(String page) {
    return switch (page) {
      'liked' => FluentIcons.heart_24_regular,
      'local' => FluentIcons.music_note_2_24_regular,
      'offline' => FluentIcons.cloud_off_24_regular,
      'recents' => FluentIcons.history_24_regular,
      _ => FluentIcons.heart_24_regular,
    };
  }

  Widget _buildHeaderSection(
    String title,
    IconData icon,
    int songsLength,
    bool isOfflineSongs,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isRecentlyPlayed = title == context.l10n!.recentlyPlayed;

    return Column(
      children: [
        PlaylistHeader(_buildPlaylistImage(title, icon), title, songsLength),
        if (songsLength > 0) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(FluentIcons.play_24_filled),
                    label: Text(context.l10n!.play),
                    onPressed: () {
                      final songsList = _currentSongsList;
                      var sortedList = songsList;
                      if (isOfflineSongs) {
                        sortedList = _sortOfflineSongsLocal(
                          songsList,
                          _getCurrentOfflineSortType(),
                        );
                      }
                      final playlist = {
                        'ytid': '',
                        'title': title,
                        'source': 'user-created',
                        'list': sortedList,
                      };
                      audioHandler.playPlaylistSong(
                        playlist: playlist,
                        songIndex: 0,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.secondaryContainer,
                      foregroundColor: colorScheme.onSecondaryContainer,
                    ),
                    icon: const Icon(FluentIcons.arrow_shuffle_24_filled),
                    label: Text(context.l10n!.shuffle),
                    onPressed: () async {
                      final songsList = _currentSongsList;
                      if (songsList.isEmpty) return;
                      var sortedList = songsList;
                      if (isOfflineSongs) {
                        sortedList = _sortOfflineSongsLocal(
                          songsList,
                          _getCurrentOfflineSortType(),
                        );
                      }
                      final playlist = {
                        'ytid': '',
                        'title': title,
                        'source': 'user-created',
                        'list': sortedList,
                      };
                      await audioHandler.playPlaylistSong(
                        playlist: playlist,
                        songIndex: 0,
                        shuffle: true,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (isRecentlyPlayed) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [_buildClearRecentsButton(colorScheme.primary)],
            ),
          ],
        ],
        if (isOfflineSongs && songsLength > 1) ...[
          const SizedBox(height: 20),
          SortChips<OfflineSortType>(
            currentSortType: _getCurrentOfflineSortType(),
            sortTypes: OfflineSortType.values,
            sortTypeToString: _getSortTypeDisplayText,
            onSelected: (type) {
              setState(() {
                addOrUpdateData<String>(
                  'settings',
                  'offlineSortType',
                  type.name,
                );
                offlineSortSetting = type.name;
              });
            },
          ),
        ],
        if (songsLength > 0) ...[
          const SizedBox(height: 16),
          SearchBarSection(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onSearchChanged: (value) => _searchQueryNotifier.value = value,
            labelText: context.l10n!.search,
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPlaylistImage(String title, IconData icon) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isLandscape = screenWidth > MediaQuery.sizeOf(context).height;
    return PlaylistCube(
      {'title': title},
      size: isLandscape ? 250 : screenWidth / commonPlaylistArtworkDivision,
      cubeIcon: icon,
    );
  }

  Widget _buildClearRecentsButton(Color primaryColor) {
    return IconButton.filledTonal(
      icon: Icon(FluentIcons.delete_24_regular, color: primaryColor),
      iconSize: 24,
      onPressed: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return ConfirmationDialog(
              confirmationMessage: context.l10n!.clearRecentlyPlayedQuestion,
              submitMessage: context.l10n!.clear,
              isDangerous: true,
              onCancel: () => Navigator.pop(context),
              onSubmit: () {
                Navigator.pop(context);
                userRecentlyPlayed.value = [];
                addOrUpdateData<List>('user', 'recentlyPlayedSongs', []);
                showToast(context, context.l10n!.recentlyPlayedMsg);
              },
            );
          },
        );
      },
    );
  }

  Widget buildSongList(String title) {
    final isLikedSongs = title == context.l10n!.likedSongs;
    final isRecentlyPlayed = title == context.l10n!.recentlyPlayed;
    final isOfflineSongs = title == context.l10n!.offlineSongs;

    return ValueListenableBuilder<String>(
      valueListenable: _searchQueryNotifier,
      builder: (_, searchQuery, __) {
        final songsList = _currentSongsList;
        final listKeyScope = 'user_song_${widget.page}';
        final isSearching = searchQuery.isNotEmpty;
        final displayList = _getDisplayList(songsList);
        var sortedList = songsList;
        if (isOfflineSongs) {
          sortedList = _sortOfflineSongsLocal(
            songsList,
            _getCurrentOfflineSortType(),
          );
        }
        final playlist = {
          'ytid': '',
          'title': title,
          'source': 'user-created',
          'list': sortedList,
        };

        if (displayList.isEmpty) {
          final emptyIcon = isLikedSongs
              ? FluentIcons.heart_24_regular
              : FluentIcons.text_bullet_list_24_filled;
          return EmptyPlaylistState(
            icon: emptyIcon,
            message: context.l10n!.playlistEmpty,
          );
        }

        return SliverList(
          key: isOfflineSongs && !isSearching
              ? ValueKey(_getCurrentOfflineSortType())
              : null,
          delegate: SliverChildBuilderDelegate((context, index) {
            final song = displayList[index];
            final borderRadius = getItemBorderRadius(index, displayList.length);
            return RepaintBoundary(
              key: listItemKey(listKeyScope, index, song),
              child: _buildSongBar(
                song,
                index,
                borderRadius,
                playlist,
                isRecentSong: isRecentlyPlayed,
              ),
            );
          }, childCount: displayList.length),
        );
      },
    );
  }

  Widget _buildSongBar(
    Map song,
    int index,
    BorderRadius borderRadius,
    Map playlist, {
    bool isRecentSong = false,
  }) {
    final isLikedSongs = playlist['title'] == context.l10n!.likedSongs;

    return SongBar(
      key: listItemKey('user_song', index, song),
      song,
      true,
      onPlay: () {
        final songId = song['ytid']?.toString() ?? song['id']?.toString() ?? '';
        final fullIndex = songId.isNotEmpty
            ? PlaylistUtils.findSongIndexByYtid(playlist, songId)
            : -1;
        if (fullIndex == -1) {
          logger.log('Warning: Song $songId not found in full song list');
        }
        audioHandler.playPlaylistSong(
          playlist: playlist,
          songIndex: fullIndex != -1 ? fullIndex : index,
        );
      },
      borderRadius: borderRadius,
      isRecentSong: isRecentSong,
      isFromLikedSongs: isLikedSongs,
    );
  }

  String _getSortTypeDisplayText(OfflineSortType type) {
    return switch (type) {
      OfflineSortType.default_ => context.l10n!.default_,
      OfflineSortType.title => context.l10n!.name,
      OfflineSortType.artist => context.l10n!.artist,
      OfflineSortType.dateAdded => context.l10n!.dateAdded,
    };
  }

  List _sortOfflineSongsLocal(List list, OfflineSortType type) {
    final sortedList = List<dynamic>.from(list);
    switch (type) {
      case OfflineSortType.default_:
        return sortedList;
      case OfflineSortType.title:
        sortedList.sort((a, b) {
          final titleA = (a['title'] ?? '').toString().toLowerCase();
          final titleB = (b['title'] ?? '').toString().toLowerCase();
          return titleA.compareTo(titleB);
        });
        break;
      case OfflineSortType.artist:
        sortedList.sort((a, b) {
          final artistA = (a['artist'] ?? '').toString().toLowerCase();
          final artistB = (b['artist'] ?? '').toString().toLowerCase();
          return artistA.compareTo(artistB);
        });
        break;
      case OfflineSortType.dateAdded:
        sortedList.sort((a, b) {
          final dateA = a['dateAdded'] as int? ?? 0;
          final dateB = b['dateAdded'] as int? ?? 0;
          return dateB.compareTo(dateA);
        });
        break;
    }
    return sortedList;
  }

  Future<void> _refreshLocalSongs() async {
    if (_isRefreshingLocalSongs) return;

    setState(() {
      _isRefreshingLocalSongs = true;
    });

    try {
      final hasPermission = await _ensureAudioPermission();
      if (!hasPermission) {
        return;
      }
      if (localMusicFolders.isEmpty) {
        if (mounted) {
          showToast(context, 'Choose music folders in Settings first.');
        }
        return;
      }

      final report = await refreshLocalSongsFromFolders(localMusicFolders);

      if (mounted) {
        showToast(context, _localScanMessage(report));
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error refreshing local songs',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        showToast(context, context.l10n!.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingLocalSongs = false;
        });
      }
    }
  }

  String _localScanMessage(LocalScanReport report) {
    if (report.found > 0) {
      return context.l10n!.playlistUpdated;
    }
    if (report.contentUriFolders > 0) {
      return 'Folder access is restricted on Android. Choose a local storage folder.';
    }
    if (report.missingFolders > 0) {
      return 'Selected folder is not available. Please choose another.';
    }
    if (report.errorFolders > 0) {
      return 'Unable to scan folders. Check storage permissions.';
    }
    return 'No supported audio files found in the selected folders.';
  }

  Future<bool> _ensureAudioPermission() async {
    final hasPermission = await AudioPermissionService.hasAudioPermission();
    if (hasPermission) {
      return true;
    }

    final granted = await AudioPermissionService.requestAudioPermission();
    if (!granted && mounted) {
      showToast(context, 'Audio permission is required to scan local music.');
    }
    return granted;
  }
}
