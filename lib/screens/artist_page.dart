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
import 'package:catchify/main.dart' show logger;
import 'package:catchify/screens/playlist_page.dart';
import 'package:catchify/services/artist_service.dart';
import 'package:catchify/services/playlists_manager.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/widgets/mini_player_bottom_space.dart';
import 'package:catchify/widgets/playlist_page/empty_playlist_state.dart';
import 'package:catchify/widgets/spinner.dart';

class ArtistPage extends StatefulWidget {
  const ArtistPage({super.key, required this.artistId, this.artistData});

  final String artistId;
  final Map? artistData;

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  late Future<Map<String, dynamic>?> _artistFuture;

  @override
  void initState() {
    super.initState();
    _artistFuture = _loadArtist();
  }

  @override
  void didUpdateWidget(covariant ArtistPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artistId != widget.artistId ||
        oldWidget.artistData != widget.artistData) {
      _artistFuture = _loadArtist();
    }
  }

  Future<Map<String, dynamic>?> _loadArtist() async {
    final artistData = widget.artistData;
    try {
      if (offlineMode.value) {
        final offlineArtist = await getPlaylistInfoForWidget(
          widget.artistId,
          isArtist: true,
          artistName: artistData?['title']?.toString(),
          artistImage: artistData?['image']?.toString(),
          sourceSongId: artistData?['sourceSongId']?.toString(),
          sourceVideoAuthor: artistData?['videoAuthor']?.toString(),
          preferredVerified: artistData?['isVerifiedArtist'] == true,
        );
        if (offlineArtist != null) {
          return Map<String, dynamic>.from(offlineArtist);
        }
      }

      final artist = await resolveArtist(
        widget.artistId,
        preferredName: artistData?['title']?.toString(),
        preferredImage: artistData?['image']?.toString(),
        sourceSongId: artistData?['sourceSongId']?.toString(),
        sourceVideoAuthor: artistData?['videoAuthor']?.toString(),
        preferredVerified: artistData?['isVerifiedArtist'] == true,
      );
      if (artist == null) {
        _logNotFound();
        return null;
      }

      return {
        ...artist,
        'source': 'youtube-artist',
        'isArtist': true,
        'isVerifiedArtist': true,
        'catalogStatus': 'loading',
        'isCatalogComplete': false,
        'sourceSongId': artistData?['sourceSongId']?.toString(),
        'videoAuthor': artistData?['videoAuthor']?.toString(),
        'list': null,
      };
    } catch (e, stackTrace) {
      logger.log(
        'ArtistPage load failed: lookup=${widget.artistId}',
        error: e,
        stackTrace: stackTrace,
      );
      _logNotFound(reason: 'artist load failed');
      return null;
    }
  }

  void _logNotFound({String reason = 'no canonical YouTube Music artist'}) {
    final artistData = widget.artistData;
    logger.log(
      'ArtistPage Not found: lookup=${widget.artistId}; '
      'sourceSongId=${artistData?['sourceSongId']}; '
      'preferredName=${artistData?['title']}; reason=$reason',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _artistFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(),
            body: SizedBox(
              height: MediaQuery.sizeOf(context).height - 100,
              child: const Spinner(),
            ),
          );
        }

        final artist = snapshot.data;
        if (artist == null) {
          return _buildNotFoundPage();
        }

        return PlaylistPage(
          key: ValueKey('artist_${artist['ytid']}_${artist['catalogStatus']}'),
          playlistId: artist['ytid']?.toString() ?? widget.artistId,
          playlistData: artist,
          cubeIcon: FluentIcons.person_24_filled,
          isArtist: true,
        );
      },
    );
  }

  Widget _buildNotFoundPage() {
    return Scaffold(
      appBar: AppBar(),
      body: const CustomScrollView(
        slivers: [
          EmptyPlaylistState(
            icon: FluentIcons.person_24_filled,
            message: 'Not found',
          ),
          SliverMiniPlayerBottomSpace(),
        ],
      ),
    );
  }
}
