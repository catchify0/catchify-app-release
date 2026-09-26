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
 *     For more information about Catchify, including how to contribute,
 *     please visit: https://github.com/catchify0/catchify0.github.io
 */

import 'dart:async';
import 'dart:math' as math;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart';
import 'package:catchify/services/data_manager.dart';
import 'package:catchify/services/playlists_manager.dart';
import 'package:catchify/services/router_service.dart';
import 'package:catchify/services/search_service.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/app_utils.dart';
import 'package:catchify/constants/app_tokens.dart';
import 'package:catchify/widgets/artist_bar.dart';
import 'package:catchify/widgets/confirmation_dialog.dart';
import 'package:catchify/widgets/custom_bar.dart';
import 'package:catchify/widgets/custom_search_bar.dart';
import 'package:catchify/widgets/empty_state.dart';
import 'package:catchify/widgets/mini_player_bottom_space.dart';
import 'package:catchify/widgets/playlist_bar.dart';
import 'package:catchify/widgets/section_header.dart';
import 'package:catchify/widgets/song_bar.dart';
import 'package:catchify/widgets/spinner.dart';
import 'package:catchify/widgets/top_result_card.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

// Global ValueNotifier for search history to make it reactive
final ValueNotifier<List> searchHistoryNotifier = ValueNotifier<List>(
  (Hive.box('user').toMap()['searchHistory'] is List)
      ? List.from(Hive.box('user').toMap()['searchHistory'] as List)
      : [],
);

// Backward compatibility - keep the global variable for existing code
List get searchHistory => searchHistoryNotifier.value;
set searchHistory(List value) {
  searchHistoryNotifier.value = value;
}

void reloadSearchHistoryFromStorage() {
  final dynamic history = Hive.box('user').toMap()['searchHistory'];
  searchHistoryNotifier.value = history is List ? List.from(history) : [];
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchBar = TextEditingController();
  final FocusNode _inputNode = FocusNode();
  final ValueNotifier<bool> _fetchingResults = ValueNotifier(false);

  SearchFilter _selectedFilter = SearchFilter.all;
  SearchResultPayload? _searchResult;
  List<String> _suggestionsList = [];
  Timer? _debounce;
  int _latestSuggestionRequest = 0;
  int _searchSessionId = 0;
  bool _hasSearched = false;

  static const _filters = [
    SearchFilter.all,
    SearchFilter.songs,
    SearchFilter.albums,
    SearchFilter.artists,
    SearchFilter.playlists,
    SearchFilter.videos,
  ];

  String _filterLabel(SearchFilter filter) {
    switch (filter) {
      case SearchFilter.all:
        return 'All';
      case SearchFilter.songs:
        return context.l10n?.songs ?? 'Songs';
      case SearchFilter.albums:
        return context.l10n?.albums ?? 'Albums';
      case SearchFilter.artists:
        return context.l10n?.artists ?? 'Artists';
      case SearchFilter.playlists:
        return context.l10n?.playlists ?? 'Playlists';
      case SearchFilter.videos:
        return 'Videos';
    }
  }

  Future<void> _submitSearch([String? query, SearchFilter? filter]) async {
    if (query != null) {
      _searchBar.text = query;
      _searchBar.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchBar.text.length),
      );
    }

    if (filter != null) {
      _selectedFilter = filter;
    }

    _latestSuggestionRequest++;
    _debounce?.cancel();
    _suggestionsList = [];
    if (mounted) _inputNode.unfocus();
    if (mounted) setState(() {});

    await search();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final query = value;
    final requestId = ++_latestSuggestionRequest;

    if (query.trim().isEmpty) {
      _suggestionsList = [];
      _hasSearched = false;
      _searchResult = null;
      _fetchingResults.value = false;
      if (mounted) setState(() {});
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 280), () async {
      try {
        final suggestions = await SearchService.instance.getSuggestions(query);

        if (!mounted ||
            requestId != _latestSuggestionRequest ||
            _searchBar.text != query) {
          return;
        }

        _suggestionsList = suggestions;
        _hasSearched = false;
        if (mounted) setState(() {});
      } catch (_) {}
    });
  }

  void _onFilterSelected(SearchFilter filter) {
    if (_selectedFilter == filter) return;
    setState(() {
      _selectedFilter = filter;
    });

    if (_searchBar.text.trim().isNotEmpty) {
      search();
    }
  }

  Future<void> search({bool forceRefresh = false}) async {
    final query = _searchBar.text.trim();
    if (query.isEmpty) {
      _hasSearched = false;
      _searchResult = null;
      _suggestionsList = [];
      _fetchingResults.value = false;
      if (mounted) setState(() {});
      return;
    }
    if (!mounted) return;

    final currentSession = ++_searchSessionId;
    _fetchingResults.value = true;
    _hasSearched = true;
    if (mounted) setState(() {});

    // Update Recent Searches in Hive
    final updatedHistory = List.from(searchHistory)
      ..remove(query)
      ..insert(0, query);
    if (updatedHistory.length > 25) {
      updatedHistory.removeRange(25, updatedHistory.length);
    }
    searchHistoryNotifier.value = updatedHistory;
    unawaited(addOrUpdateData<List>('user', 'searchHistory', updatedHistory));

    try {
      final payload = await SearchService.instance.search(
        query,
        filter: _selectedFilter,
        forceRefresh: forceRefresh,
      );

      if (!mounted ||
          currentSession != _searchSessionId ||
          _searchBar.text.trim() != query) {
        return;
      }

      _searchResult = payload;
    } catch (e, st) {
      logger.log(
        'Error executing search for "$query":',
        error: e,
        stackTrace: st,
      );
    } finally {
      if (mounted && currentSession == _searchSessionId) {
        _fetchingResults.value = false;
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchBar.dispose();
    _inputNode.dispose();
    _fetchingResults.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n!.search,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: colorScheme.surface,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _buildSearchBar(context),
          ),
          _buildFilterChips(context),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _buildBody(context),
                  ),
                  const MiniPlayerBottomSpace(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: CustomSearchBar(
            controller: _searchBar,
            focusNode: _inputNode,
            labelText: '${context.l10n!.search}...',
            onChanged: _onSearchChanged,
            onSubmitted: (String value) {
              _submitSearch();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scaledChipHeight = MediaQuery.textScalerOf(context).scale(34);
    final chipStripHeight = math.max(
      AppTokens.minInteractiveSize,
      scaledChipHeight,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: SizedBox(
        height: chipStripHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final filter = _filters[index];
            final isSelected = filter == _selectedFilter;

            return Semantics(
              button: true,
              selected: isSelected,
              label: _filterLabel(filter),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _onFilterSelected(filter),
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                colorScheme.primary,
                                colorScheme.primary.withValues(alpha: 0.82),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSelected
                          ? null
                          : colorScheme.surfaceContainerHighest.withValues(
                              alpha: 0.45,
                            ),
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary.withValues(alpha: 0.9)
                            : colorScheme.onSurface.withValues(alpha: 0.1),
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.28,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        _filterLabel(filter),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          letterSpacing: -0.2,
                          color: isSelected
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _fetchingResults,
      builder: (context, isFetching, _) {
        if (isFetching) {
          return const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: Spinner()),
          );
        }

        if (_searchBar.text.trim().isEmpty) {
          return _buildSearchHistory(context);
        }

        if (_suggestionsList.isNotEmpty && !_hasSearched) {
          return _buildSuggestions(context);
        }

        if (_hasSearched) {
          if (_searchResult == null || _searchResult!.isEmpty) {
            return _buildNoResultsFound(context);
          }

          return _buildSearchResults(context, _searchResult!);
        }

        return _buildSearchHistory(context);
      },
    );
  }

  Widget _buildSearchHistory(BuildContext context) {
    return ValueListenableBuilder<List>(
      valueListenable: searchHistoryNotifier,
      builder: (context, searchHistory, _) {
        if (searchHistory.isEmpty) {
          return _buildBrowseCategories(context);
        }

        return Column(
          key: ValueKey('search-history-${searchHistory.length}'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent searches',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final confirm =
                          await _showClearAllConfirmationDialog(context) ??
                          false;
                      if (confirm) {
                        searchHistoryNotifier.value = [];
                        unawaited(
                          addOrUpdateData<List>('user', 'searchHistory', []),
                        );
                      }
                    },
                    child: Text(
                      context.l10n!.clearSearchHistory,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: <Widget>[
                  for (int index = 0; index < searchHistory.length; index++)
                    Builder(
                      builder: (context) {
                        final query = searchHistory[index];
                        final borderRadius = getItemBorderRadius(
                          index,
                          searchHistory.length,
                        );

                        return CustomBar(
                          query.toString(),
                          FluentIcons.history_24_regular,
                          borderRadius: borderRadius,
                          onTap: () async {
                            await _submitSearch(query.toString());
                          },
                          trailing: IconButton(
                            icon: Icon(
                              FluentIcons.dismiss_20_regular,
                              size: 18,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.6),
                            ),
                            onPressed: () {
                              final updatedHistory = List.from(searchHistory)
                                ..remove(query);
                              searchHistoryNotifier.value = updatedHistory;
                              unawaited(
                                addOrUpdateData<List>(
                                  'user',
                                  'searchHistory',
                                  updatedHistory,
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildBrowseCategories(context),
          ],
        );
      },
    );
  }

  Widget _buildBrowseCategories(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: contentLanguagePreferenceNotifier,
      builder: (context, languageCode, _) {
        final languageName =
            artistLanguageCodeToName[languageCode ?? 'en'] ?? 'English';
        final categories = [
          (
            '$languageName Hits',
            '$languageName hits songs',
            [const Color(0xFFE52D27), const Color(0xFFB31217)],
            FluentIcons.music_note_2_24_filled,
          ),
          (
            'Trending Now',
            '$languageName trending songs',
            [const Color(0xFF8A2387), const Color(0xFFE94057)],
            FluentIcons.arrow_trending_24_filled,
          ),
          (
            'Romance',
            '$languageName romance songs',
            [const Color(0xFFFF512F), const Color(0xFFDD2476)],
            FluentIcons.heart_24_filled,
          ),
          (
            'Workout',
            '$languageName workout songs',
            [const Color(0xFF11998E), const Color(0xFF38EF7D)],
            FluentIcons.run_24_filled,
          ),
          (
            'Chill Vibes',
            '$languageName chill songs',
            [const Color(0xFF2193B0), const Color(0xFF6DD5ED)],
            FluentIcons.weather_sunny_24_filled,
          ),
          (
            'Party Beats',
            '$languageName party songs',
            [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
            FluentIcons.speaker_2_24_filled,
          ),
          (
            'Devotional',
            '$languageName devotional songs',
            [const Color(0xFFFF8008), const Color(0xFFFFC837)],
            FluentIcons.sparkle_24_filled,
          ),
          (
            'Indie & Acoustic',
            '$languageName indie acoustic songs',
            [const Color(0xFF3A6073), const Color(0xFF3A7BD5)],
            FluentIcons.guitar_24_filled,
          ),
        ];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 12, top: 4),
                child: Text(
                  'Browse all',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: categories.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.8,
                ),
                itemBuilder: (context, index) {
                  final item = categories[index];
                  final title = item.$1;
                  final query = item.$2;
                  final colors = item.$3;
                  final icon = item.$4;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _submitSearch(query),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: colors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.first.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: <Widget>[
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: Transform.rotate(
                                angle: 0.2,
                                child: Icon(
                                  icon,
                                  size: 38,
                                  color: Colors.white.withValues(alpha: 0.28),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuggestions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        key: ValueKey(
          'suggestions-${_suggestionsList.length}-${_searchBar.text}',
        ),
        children: <Widget>[
          for (int index = 0; index < _suggestionsList.length; index++)
            Builder(
              builder: (context) {
                final query = _suggestionsList[index];
                final borderRadius = getItemBorderRadius(
                  index,
                  _suggestionsList.length,
                );

                return CustomBar(
                  query,
                  FluentIcons.search_24_regular,
                  borderRadius: borderRadius,
                  onTap: () async {
                    await _submitSearch(query);
                  },
                  trailing: IconButton(
                    icon: Icon(
                      FluentIcons.arrow_up_left_24_regular,
                      size: 18,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    onPressed: () {
                      _searchBar.text = query;
                      _searchBar.selection = TextSelection.fromPosition(
                        TextPosition(offset: _searchBar.text.length),
                      );
                      _onSearchChanged(query);
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildNoResultsFound(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: EmptyState(
        icon: FluentIcons.search_24_regular,
        title: 'No results found',
        description:
            'No matches found for "${_searchBar.text.trim()}". Try different keywords or filters.',
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, SearchResultPayload result) {
    final widgets = <Widget>[];

    // 1. Top Result (only if 'all' filter and topResult exists)
    if (_selectedFilter == SearchFilter.all && result.topResult != null) {
      widgets.add(
        TopResultCard(
          item: result.topResult!,
          onTap: () => _openTopResult(context, result.topResult!),
          onPlay:
              (result.topResult!['topResultType'] == 'song' ||
                  result.topResult!['topResultType'] == 'video')
              ? () => _playTopResult(result.topResult!)
              : null,
        ),
      );
    }

    // 2. Songs Shelf
    if (result.songs.isNotEmpty) {
      widgets.add(_buildSongsSection(context, result.songs));
    }

    // 3. Albums Shelf
    if (result.albums.isNotEmpty) {
      widgets.add(_buildAlbumsSection(context, result.albums));
    }

    // 4. Artists Shelf
    if (result.artists.isNotEmpty) {
      widgets.add(_buildArtistsSection(context, result.artists));
    }

    // 5. Playlists Shelf
    if (result.playlists.isNotEmpty) {
      widgets.add(_buildPlaylistsSection(context, result.playlists));
    }

    // 6. Videos Shelf
    if (result.videos.isNotEmpty) {
      widgets.add(_buildVideosSection(context, result.videos));
    }

    return Column(
      key: ValueKey(
        'results-${result.query}-${result.filter.name}-${result.songs.length}-${result.albums.length}-${result.artists.length}',
      ),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildSongsSection(
    BuildContext context,
    List<Map<String, dynamic>> songs,
  ) {
    final songsTitle = context.l10n?.songs ?? 'Songs';
    final screenWidth = MediaQuery.sizeOf(context).width;
    final columnWidth = (screenWidth > 600)
        ? 380.0
        : (screenWidth - 44).clamp(280.0, 390.0);

    final chunkedSongs = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < songs.length; i += 4) {
      chunkedSongs.add(songs.sublist(i, math.min(i + 4, songs.length)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: songsTitle,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          actionButton: IconButton(
            onPressed: () async {
              if (songs.isEmpty) return;
              await audioHandler.playPlaylistSong(
                playlist: {
                  'title': _searchBar.text.trim().isNotEmpty
                      ? _searchBar.text.trim()
                      : songsTitle,
                  'list': songs,
                },
                songIndex: 0,
              );
            },
            tooltip: 'Play all',
            icon: Icon(
              FluentIcons.play_circle_24_filled,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
          ),
        ),
        SizedBox(
          height:
              chunkedSongs.map((c) => c.length).fold<int>(0, math.max) * 68.0,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: chunkedSongs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, colIndex) {
              final chunk = chunkedSongs[colIndex];
              return SizedBox(
                width: columnWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(chunk.length, (rowIndex) {
                    final song = chunk[rowIndex];
                    final globalIndex = colIndex * 4 + rowIndex;
                    final ytid = song['ytid'];
                    return RepaintBoundary(
                      key: listItemKey('search_song', globalIndex, song),
                      child: SongBar(
                        song,
                        true,
                        key: ValueKey(ytid ?? globalIndex),
                        showMusicDuration: true,
                        backgroundColor: Colors.transparent,
                        barPadding: const EdgeInsetsDirectional.symmetric(
                          vertical: 7,
                          horizontal: 4,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        onPlay: () async {
                          await audioHandler.playPlaylistSong(
                            playlist: {
                              'title': _searchBar.text.trim().isNotEmpty
                                  ? _searchBar.text.trim()
                                  : songsTitle,
                              'list': songs,
                            },
                            songIndex: globalIndex,
                          );
                        },
                      ),
                    );
                  }),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAlbumsSection(
    BuildContext context,
    List<Map<String, dynamic>> albums,
  ) {
    final albumsTitle = context.l10n?.albums ?? 'Albums';
    final screenWidth = MediaQuery.sizeOf(context).width;
    final columnWidth = (screenWidth > 600)
        ? 380.0
        : (screenWidth - 44).clamp(280.0, 390.0);

    final chunkedAlbums = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < albums.length; i += 4) {
      chunkedAlbums.add(albums.sublist(i, math.min(i + 4, albums.length)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: albumsTitle,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        ),
        SizedBox(
          height:
              chunkedAlbums.map((c) => c.length).fold<int>(0, math.max) * 72.0,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: chunkedAlbums.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, colIndex) {
              final chunk = chunkedAlbums[colIndex];
              return SizedBox(
                width: columnWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(chunk.length, (rowIndex) {
                    final album = chunk[rowIndex];
                    final globalIndex = colIndex * 4 + rowIndex;
                    return RepaintBoundary(
                      key: listItemKey('search_album', globalIndex, album),
                      child: PlaylistBar(
                        album['title'],
                        playlistData: album,
                        playlistId: album['ytid'],
                        playlistArtwork:
                            album['highResImage'] ?? album['image'],
                        cubeIcon: FluentIcons.cd_16_filled,
                        isAlbum: true,
                        backgroundColor: Colors.transparent,
                        barPadding: const EdgeInsetsDirectional.symmetric(
                          vertical: 7,
                          horizontal: 4,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    );
                  }),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildArtistsSection(
    BuildContext context,
    List<Map<String, dynamic>> artists,
  ) {
    final artistsTitle = context.l10n?.artists ?? 'Artists';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: artistsTitle,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: <Widget>[
              for (var index = 0; index < artists.length.clamp(0, 4); index++)
                Builder(
                  builder: (context) {
                    final artist = artists[index];
                    final artistId =
                        artist['ytid']?.toString() ??
                        artist['id']?.toString() ??
                        artist['title']?.toString() ??
                        '';
                    if (artistId.isEmpty) return const SizedBox.shrink();

                    final borderRadius = getItemBorderRadius(
                      index,
                      artists.length.clamp(0, 4),
                    );

                    return ArtistBar(
                      key: listItemKey('search_artist', index, artist),
                      artist: artist,
                      borderRadius: borderRadius,
                      onTap: () {
                        context.push(
                          '${NavigationManager.searchPath}/artist/${Uri.encodeComponent(artistId)}',
                          extra: artist,
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPlaylistsSection(
    BuildContext context,
    List<Map<String, dynamic>> playlists,
  ) {
    final playlistsTitle = context.l10n?.playlists ?? 'Playlists';
    final screenWidth = MediaQuery.sizeOf(context).width;
    final columnWidth = (screenWidth > 600)
        ? 380.0
        : (screenWidth - 44).clamp(280.0, 390.0);

    final chunkedPlaylists = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < playlists.length; i += 4) {
      chunkedPlaylists.add(
        playlists.sublist(i, math.min(i + 4, playlists.length)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: playlistsTitle,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        ),
        SizedBox(
          height:
              chunkedPlaylists.map((c) => c.length).fold<int>(0, math.max) *
              72.0,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: chunkedPlaylists.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, colIndex) {
              final chunk = chunkedPlaylists[colIndex];
              return SizedBox(
                width: columnWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(chunk.length, (rowIndex) {
                    final playlist = chunk[rowIndex];
                    final globalIndex = colIndex * 4 + rowIndex;
                    return RepaintBoundary(
                      key: listItemKey(
                        'search_playlist',
                        globalIndex,
                        playlist,
                      ),
                      child: PlaylistBar(
                        playlist['title'],
                        playlistData: playlist,
                        playlistId: playlist['ytid'],
                        playlistArtwork:
                            playlist['highResImage'] ?? playlist['image'],
                        cubeIcon: FluentIcons.apps_list_24_filled,
                        backgroundColor: Colors.transparent,
                        barPadding: const EdgeInsetsDirectional.symmetric(
                          vertical: 7,
                          horizontal: 4,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    );
                  }),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildVideosSection(
    BuildContext context,
    List<Map<String, dynamic>> videos,
  ) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final columnWidth = (screenWidth > 600)
        ? 380.0
        : (screenWidth - 44).clamp(280.0, 390.0);

    final chunkedVideos = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < videos.length; i += 4) {
      chunkedVideos.add(videos.sublist(i, math.min(i + 4, videos.length)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Videos',
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
        ),
        SizedBox(
          height:
              chunkedVideos.map((c) => c.length).fold<int>(0, math.max) * 68.0,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: chunkedVideos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, colIndex) {
              final chunk = chunkedVideos[colIndex];
              return SizedBox(
                width: columnWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(chunk.length, (rowIndex) {
                    final video = chunk[rowIndex];
                    final globalIndex = colIndex * 4 + rowIndex;
                    final ytid = video['ytid'];
                    return RepaintBoundary(
                      key: listItemKey('search_video', globalIndex, video),
                      child: SongBar(
                        video,
                        true,
                        key: ValueKey(ytid ?? globalIndex),
                        showMusicDuration: true,
                        backgroundColor: Colors.transparent,
                        barPadding: const EdgeInsetsDirectional.symmetric(
                          vertical: 7,
                          horizontal: 4,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        onPlay: () async {
                          await audioHandler.playPlaylistSong(
                            playlist: {
                              'title': _searchBar.text.trim().isNotEmpty
                                  ? _searchBar.text.trim()
                                  : 'Videos',
                              'list': videos,
                            },
                            songIndex: globalIndex,
                          );
                        },
                      ),
                    );
                  }),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _openTopResult(BuildContext context, Map<String, dynamic> item) {
    final type = item['topResultType']?.toString().toLowerCase();
    final ytid = item['ytid']?.toString() ?? item['id']?.toString() ?? '';

    if (type == 'artist') {
      if (ytid.isNotEmpty) {
        context.push(
          '${NavigationManager.searchPath}/artist/${Uri.encodeComponent(ytid)}',
          extra: item,
        );
      }
    } else if (type == 'album' || type == 'playlist') {
      if (ytid.isNotEmpty) {
        context.push(
          '${NavigationManager.searchPath}/playlist/${Uri.encodeComponent(ytid)}',
          extra: item,
        );
      }
    } else {
      _playTopResult(item);
    }
  }

  Future<void> _playTopResult(Map<String, dynamic> item) async {
    await audioHandler.playPlaylistSong(
      playlist: {
        'title': item['title'] ?? 'Top Result',
        'list': [item],
      },
      songIndex: 0,
    );
  }

  Future<bool?> _showClearAllConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return ConfirmationDialog(
          confirmationMessage: context.l10n!.clearSearchHistoryQuestion,
          submitMessage: context.l10n!.confirm,
          onCancel: () {
            Navigator.of(context).pop(false);
          },
          onSubmit: () {
            Navigator.of(context).pop(true);
          },
        );
      },
    );
  }
}
