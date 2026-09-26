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

import 'package:hive/hive.dart';
import 'package:catchify/main.dart' show logger;
import 'package:catchify/models/home_section.dart';
import 'package:catchify/services/common_services.dart';
import 'package:catchify/services/listening_stats_service.dart';
import 'package:catchify/services/playlists_manager.dart';
import 'package:catchify/services/radio_service.dart';
import 'package:catchify/utilities/app_utils.dart' show getDisplayArtist;
import 'package:catchify/utilities/playlist_utils.dart';

/// Centralized weights and time-decay functions for the Catchify Personalization Engine.
class PersonalizationWeights {
  const PersonalizationWeights._();

  static const double likedSongWeight = 100;
  static const double recentPlayWeight = 60;
  static const double playCountMultiplier = 15;
  static const double artistAffinityBonus = 25;
  static const double searchMatchBonus = 20;
  static const double radioSeedBonus = 40;

  /// Time-decay function: older listening interactions decay in relevance.
  static double calculateTimeDecay(int recentsIndex) {
    if (recentsIndex <= 0) return 1;
    if (recentsIndex < 5) return 0.85;
    if (recentsIndex < 15) return 0.65;
    if (recentsIndex < 30) return 0.45;
    return 0.25;
  }
}

/// Normalized snapshot of the user's active behavioral signals.
class UserSignals {
  const UserSignals({
    required this.likedSongs,
    required this.recentSongs,
    required this.likedPlaylists,
    required this.customPlaylists,
    required this.searchQueries,
    this.activeRadioSeed,
    required this.playCounts,
  });

  final List<Map<String, dynamic>> likedSongs;
  final List<Map<String, dynamic>> recentSongs;
  final List<Map<String, dynamic>> likedPlaylists;
  final List<Map<String, dynamic>> customPlaylists;
  final List<String> searchQueries;
  final String? activeRadioSeed;
  final Map<String, int> playCounts;

  bool get hasSufficientData =>
      likedSongs.isNotEmpty ||
      recentSongs.isNotEmpty ||
      likedPlaylists.isNotEmpty ||
      customPlaylists.isNotEmpty;

  int get distinctArtistsCount {
    final seen = <String>{};
    for (final s in likedSongs) {
      final a = getDisplayArtist(s).trim();
      if (a.isNotEmpty) seen.add(a.toLowerCase());
    }
    for (final s in recentSongs) {
      final a = getDisplayArtist(s).trim();
      if (a.isNotEmpty) seen.add(a.toLowerCase());
    }
    return seen.length;
  }
}

/// Deterministic, local-first Personalization Engine for Catchify.
///
/// Responsibilities:
/// 1. Collect user behavior signals from existing Hive storage and notifiers.
/// 2. Deterministically rank songs, artists, and playlists based on transparent weights and time-decay.
/// 3. Produce localized [HomeSection] candidates to enrich the dynamic Home Feed.
/// 4. Respect cold start: never invent recommendations when data is insufficient.
///
/// Does NOT own playback, network fetching, or Hive initialization.
class PersonalizationService {
  PersonalizationService._();
  static final PersonalizationService instance = PersonalizationService._();

  /// Collects active user signals from existing local storage without duplication.
  UserSignals getUserSignals() {
    final liked = userLikedSongsList.value
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();

    final recents = userRecentlyPlayed.value
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();

    final likedPlaylists = userLikedPlaylists.value
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();

    final customPlaylists = userCustomPlaylists.value
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();

    var searches = const <String>[];
    if (Hive.isBoxOpen('user')) {
      final rawSearches = Hive.box(
        'user',
      ).get('searchHistory', defaultValue: []);
      if (rawSearches is List) {
        searches = rawSearches.whereType<String>().toList();
      }
    }

    final activeSeed = radioService.currentSession?.seedId;

    // Collect play counts from monthly stats if available
    final playCounts = <String, int>{};
    try {
      final now = DateTime.now();
      final currentMonthKey =
          '${now.year}-${now.month.toString().padLeft(2, "0")}';
      final topSongs = listeningStatsService.monthTopSongs(
        currentMonthKey,
        limit: 50,
      );
      for (final song in topSongs) {
        final id = song['ytid']?.toString() ?? song['id']?.toString();
        final count =
            song['playCount'] as int? ??
            song['listeningCount'] as int? ??
            int.tryParse(song['playCount']?.toString() ?? '') ??
            0;
        if (id != null && id.isNotEmpty && count > 0) {
          playCounts[id] = count;
        }
      }
    } catch (_) {}

    final signals = UserSignals(
      likedSongs: liked,
      recentSongs: recents,
      likedPlaylists: likedPlaylists,
      customPlaylists: customPlaylists,
      searchQueries: searches,
      activeRadioSeed: activeSeed,
      playCounts: playCounts,
    );

    logger.log(
      '[PERSONALIZATION] signals: recent=${signals.recentSongs.length} '
      'liked=${signals.likedSongs.length} '
      'artists=${signals.distinctArtistsCount} '
      'searches=${signals.searchQueries.length}',
    );

    return signals;
  }

  /// Ranks songs deterministically based on liked status, recent playback decay,
  /// play frequency, artist affinity, search match, and radio seed match.
  List<Map<String, dynamic>> rankSongs(
    UserSignals signals, {
    List<Map<String, dynamic>>? candidates,
    int limit = 20,
  }) {
    final candidatePool =
        candidates ?? [...signals.likedSongs, ...signals.recentSongs];

    if (candidatePool.isEmpty) return const [];

    final likedIds = <String>{};
    for (final s in signals.likedSongs) {
      final id = _extractSongId(s);
      if (id.isNotEmpty) likedIds.add(id);
    }

    final recentIndices = <String, int>{};
    for (var i = 0; i < signals.recentSongs.length; i++) {
      final id = _extractSongId(signals.recentSongs[i]);
      if (id.isNotEmpty) {
        recentIndices.putIfAbsent(id, () => i);
      }
    }

    final searchTokens = signals.searchQueries
        .map((q) => q.toLowerCase().trim())
        .where((q) => q.isNotEmpty)
        .toList();

    final scoredMap = <String, _ScoredItem<Map<String, dynamic>>>{};

    for (final song in candidatePool) {
      final id = _extractSongId(song);
      if (id.isEmpty) continue;

      var score = 0.0;

      // 1. Liked item weight
      if (likedIds.contains(id)) {
        score += PersonalizationWeights.likedSongWeight;
      }

      // 2. Recent playback with time decay
      final recentIdx = recentIndices[id];
      if (recentIdx != null) {
        score +=
            PersonalizationWeights.recentPlayWeight *
            PersonalizationWeights.calculateTimeDecay(recentIdx);
      }

      // 3. Play count frequency bonus
      final playCount = signals.playCounts[id] ?? 0;
      if (playCount > 0) {
        score += (playCount * PersonalizationWeights.playCountMultiplier).clamp(
          0.0,
          100.0,
        );
      }

      // 4. Radio seed bonus
      if (signals.activeRadioSeed != null && signals.activeRadioSeed == id) {
        score += PersonalizationWeights.radioSeedBonus;
      }

      // 5. Search query affinity bonus
      final title = song['title']?.toString().toLowerCase() ?? '';
      final artist = song['artist']?.toString().toLowerCase() ?? '';
      for (final query in searchTokens) {
        if (title.contains(query) ||
            (artist.isNotEmpty && query.contains(artist))) {
          score += PersonalizationWeights.searchMatchBonus;
          break;
        }
      }

      if (!scoredMap.containsKey(id) || score > scoredMap[id]!.score) {
        scoredMap[id] = _ScoredItem(item: song, score: score, id: id);
      }
    }

    final sorted = scoredMap.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return sorted.take(limit).map((e) => e.item).toList();
  }

  /// Calculates artist affinity deterministically from explicit artist follows,
  /// liked songs by artist, recent listening counts, and search activity.
  List<Map<String, dynamic>> rankArtists(
    UserSignals signals, {
    int limit = 10,
  }) {
    final artistScores = <String, double>{};
    final artistImages = <String, String?>{};
    final artistIds = <String, String?>{};
    final artistDisplayNames = <String, String>{};

    // 1. Liked artists (highest explicit signal)
    for (final p in signals.likedPlaylists) {
      if (PlaylistUtils.isArtistPlaylist(p)) {
        final name = p['title']?.toString().trim() ?? '';
        final key = name.toLowerCase();
        if (name.isNotEmpty) {
          artistScores[key] = (artistScores[key] ?? 0) + 100.0;
          artistImages[key] ??= p['highResImage'] ?? p['image'];
          artistIds[key] ??= p['ytid']?.toString();
          artistDisplayNames[key] ??= name;
        }
      }
    }

    // 2. Liked songs by artist
    for (final s in signals.likedSongs) {
      final artistStr = getDisplayArtist(s).trim();
      if (artistStr.isEmpty) continue;

      final parts = artistStr
          .split(
            RegExp(
              r'[,&/]|(?:\s+(?:feat\.?|ft\.?|vs\.?|with)\s+)',
              caseSensitive: false,
            ),
          )
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty);

      for (final part in parts) {
        final key = part.toLowerCase();
        artistScores[key] =
            (artistScores[key] ?? 0) +
            PersonalizationWeights.artistAffinityBonus;
        artistImages[key] ??= s['image']?.toString();
        artistIds[key] ??= s['artistId']?.toString();
        artistDisplayNames[key] ??= part;
      }
    }

    // 3. Recent plays by artist with time decay
    for (var i = 0; i < signals.recentSongs.length; i++) {
      final s = signals.recentSongs[i];
      final artistStr = getDisplayArtist(s).trim();
      if (artistStr.isEmpty) continue;

      final decay = PersonalizationWeights.calculateTimeDecay(i);
      final parts = artistStr
          .split(
            RegExp(
              r'[,&/]|(?:\s+(?:feat\.?|ft\.?|vs\.?|with)\s+)',
              caseSensitive: false,
            ),
          )
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty);

      for (final part in parts) {
        final key = part.toLowerCase();
        artistScores[key] = (artistScores[key] ?? 0) + (15.0 * decay);
        artistImages[key] ??= s['image']?.toString();
        artistIds[key] ??= s['artistId']?.toString();
        artistDisplayNames[key] ??= part;
      }
    }

    // 4. Search history matching artists
    for (final q in signals.searchQueries) {
      final lowerQ = q.toLowerCase().trim();
      if (lowerQ.isEmpty) continue;
      for (final key in artistScores.keys.toList()) {
        if (key.contains(lowerQ) || lowerQ.contains(key)) {
          artistScores[key] =
              (artistScores[key] ?? 0) +
              PersonalizationWeights.searchMatchBonus;
        }
      }
    }

    final sortedKeys = artistScores.keys.toList()
      ..sort((a, b) => artistScores[b]!.compareTo(artistScores[a]!));

    final result = <Map<String, dynamic>>[];
    for (final key in sortedKeys.take(limit)) {
      result.add({
        'title': artistDisplayNames[key] ?? key,
        'ytid': artistIds[key] ?? artistDisplayNames[key] ?? key,
        'image': artistImages[key],
      });
    }

    return result;
  }

  /// Prioritizes user and liked playlists based on explicit creation and follows.
  List<Map<String, dynamic>> rankPlaylists(
    UserSignals signals, {
    int limit = 10,
  }) {
    final scored = <String, _ScoredItem<Map<String, dynamic>>>{};

    // User-created playlists (highest intent)
    for (final p in signals.customPlaylists) {
      final id = p['ytid']?.toString() ?? p['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        scored[id] = _ScoredItem(item: p, score: 90, id: id);
      }
    }

    // Liked playlists (excluding artist channels)
    for (final p in signals.likedPlaylists) {
      if (PlaylistUtils.isArtistPlaylist(p)) continue;
      final id = p['ytid']?.toString() ?? p['id']?.toString() ?? '';
      if (id.isNotEmpty && !scored.containsKey(id)) {
        scored[id] = _ScoredItem(item: p, score: 80, id: id);
      }
    }

    final sorted = scored.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return sorted.take(limit).map((e) => e.item).toList();
  }

  /// Extracts high-priority candidate artists based on recently played and liked music.
  List<String> getCandidateArtists(UserSignals signals, {int limit = 5}) {
    final candidateArtists = <String>[];
    const invalidArtists = {
      'various artists',
      'various artist',
      'various',
      'unknown',
      'unknown artist',
      'topic',
    };

    void addCandidate(String raw) {
      final cleaned = raw
          .trim()
          .replaceAll(RegExp(r'^[\s\-_"\[\]]+|[\s\-_"\[\]]+$'), '')
          .replaceAll(RegExp(r"^'+|'+$"), '')
          .trim();
      if (cleaned.length < 2) return;
      if (invalidArtists.contains(cleaned.toLowerCase())) return;
      if (!candidateArtists.any(
        (c) => c.toLowerCase() == cleaned.toLowerCase(),
      )) {
        candidateArtists.add(cleaned);
      }
    }

    // 1. Most recent songs first (immediate listener intent)
    for (final s in signals.recentSongs) {
      final a = getDisplayArtist(s).trim();
      if (a.isNotEmpty) {
        final parts = a
            .split(
              RegExp(
                r'[,&/]|(?:\s+(?:feat\.?|ft\.?|vs\.?|with)\s+)',
                caseSensitive: false,
              ),
            )
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty);
        for (final p in parts) {
          addCandidate(p);
        }
      }
      if (candidateArtists.length >= limit) break;
    }

    // 2. Liked songs if recents didn't yield enough
    if (candidateArtists.length < limit) {
      for (final s in signals.likedSongs) {
        final a = getDisplayArtist(s).trim();
        if (a.isNotEmpty) {
          final parts = a
              .split(
                RegExp(
                  r'[,&/]|(?:\s+(?:feat\.?|ft\.?|vs\.?|with)\s+)',
                  caseSensitive: false,
                ),
              )
              .map((p) => p.trim())
              .where((p) => p.isNotEmpty);
          for (final p in parts) {
            addCandidate(p);
          }
        }
        if (candidateArtists.length >= limit) break;
      }
    }

    // 3. Fallback to ranked top artists
    if (candidateArtists.length < limit) {
      for (final artistEntry in rankArtists(signals, limit: limit)) {
        final a = artistEntry['title']?.toString().trim() ?? '';
        if (a.isNotEmpty) {
          addCandidate(a);
        }
        if (candidateArtists.length >= limit) break;
      }
    }

    return candidateArtists.take(limit).toList();
  }

  /// Builds local personalized [HomeSection]s based on active user signals.
  ///
  /// Respects cold start: if data is insufficient, returns an empty list,
  /// allowing the Home Feed to rely smoothly on remote discovery sections.
  List<HomeSection> buildPersonalizedSections({
    UserSignals? signalsOverride,
    String? mood,
    List<Map<String, dynamic>>? relevantCandidates,
  }) {
    final signals = signalsOverride ?? getUserSignals();

    // Cold start rule: if no meaningful user history exists, emit no personalized sections
    if (!signals.hasSufficientData) {
      return const [];
    }

    final sections = <HomeSection>[];

    // 1. "Continue listening" — recent unique playback (Top Priority for standard continuity)
    if (signals.recentSongs.isNotEmpty) {
      final seenIds = <String>{};
      final recentTracks = <Map<String, dynamic>>[];
      for (final s in signals.recentSongs) {
        final id = _extractSongId(s);
        if (id.isNotEmpty && seenIds.add(id)) {
          recentTracks.add(s);
          if (recentTracks.length >= 8) break;
        }
      }

      if (recentTracks.isNotEmpty) {
        sections.add(
          HomeSection(
            title: 'Continue listening',
            subtitle: 'RECENTLY PLAYED',
            type: HomeContentType.songs,
            contents: recentTracks,
            isChunkedSongs: true,
          ),
        );
        logger.log(
          '[PERSONALIZATION_SECTION] title="Continue listening" items=${recentTracks.length}',
        );
      }
    }

    // 2. "Made for you" — high-relevance recommended tracks based on listening history
    final playedIds = <String>{};
    for (final s in signals.recentSongs) {
      final id = _extractSongId(s);
      if (id.isNotEmpty) playedIds.add(id);
    }

    var madeForYouTracks = <Map<String, dynamic>>[];
    if (relevantCandidates != null && relevantCandidates.isNotEmpty) {
      // Filter out songs already in recent listening history so "Made for you" delivers fresh recommendations
      final freshRecommendations = relevantCandidates
          .where((s) => !playedIds.contains(_extractSongId(s)))
          .toList();
      if (freshRecommendations.isNotEmpty) {
        madeForYouTracks = rankSongs(
          signals,
          candidates: freshRecommendations,
          limit: 12,
        );
      }
    }

    // Do not fall back to recent or liked signals here: those already power
    // "Continue listening" and would make the recommendation shelf duplicate it.
    if (madeForYouTracks.length >= 3) {
      sections.add(
        HomeSection(
          title: 'Made for you',
          subtitle: 'RECOMMENDED FOR YOU',
          type: HomeContentType.songs,
          contents: madeForYouTracks,
          isChunkedSongs: true,
        ),
      );
      logger.log(
        '[PERSONALIZATION_SECTION] title="Made for you" items=${madeForYouTracks.length}',
      );
    }

    // 3. "Because you listened to [Top Artist]"
    final candidateArtists = getCandidateArtists(signals);

    final artistPlayedIds = {
      ...signals.likedSongs.map(_extractSongId),
      ...signals.recentSongs.map(_extractSongId),
    };

    for (final topArtistName in candidateArtists) {
      final artistHistory = _findSongsByArtist([
        ...signals.likedSongs,
        ...signals.recentSongs,
      ], topArtistName);

      final freshArtistRecommendations =
          _findSongsByArtist(relevantCandidates ?? const [], topArtistName)
              .where((song) => !artistPlayedIds.contains(_extractSongId(song)))
              .toList();

      final artistSongs = <Map<String, dynamic>>[
        ...freshArtistRecommendations,
        ...artistHistory.where(
          (song) => !freshArtistRecommendations.any(
            (recommendation) =>
                _extractSongId(recommendation) == _extractSongId(song),
          ),
        ),
      ].take(8).toList();

      if (artistSongs.isNotEmpty &&
          (freshArtistRecommendations.isNotEmpty || artistSongs.length >= 2)) {
        sections.add(
          HomeSection(
            title: 'Because you listened to $topArtistName',
            subtitle: freshArtistRecommendations.isNotEmpty
                ? 'MORE FROM THIS ARTIST'
                : 'YOUR FAVORITES',
            type: HomeContentType.songs,
            contents: artistSongs,
            isChunkedSongs: true,
          ),
        );
        logger.log(
          '[PERSONALIZATION_SECTION] title="Because you listened to $topArtistName" items=${artistSongs.length}',
        );
        break;
      }
    }

    // 4. "Your top artists" (Temporarily commented out per user request)
    /*
    if (topArtists.length >= 2) {
      sections.add(
        HomeSection(
          title: 'Your top artists',
          subtitle: 'ARTISTS YOU LOVE',
          type: HomeContentType.artists,
          contents: topArtists,
        ),
      );
      logger.log(
        '[PERSONALIZATION_SECTION] title="Your top artists" items=${topArtists.length}',
      );
    }
    */

    // 5. "Your playlists" — user-created custom playlists (liked playlists are handled in "Back to favorites")
    if (signals.customPlaylists.isNotEmpty) {
      final userPlaylists = signals.customPlaylists.take(8).toList();
      sections.add(
        HomeSection(
          title: 'Your playlists',
          subtitle: 'CREATED BY YOU',
          type: HomeContentType.playlists,
          contents: userPlaylists,
        ),
      );
      logger.log(
        '[PERSONALIZATION_SECTION] title="Your playlists" items=${userPlaylists.length}',
      );
    }

    return sections;
  }

  /// Extracts canonical song identifier (ytid preferred, then id).
  static String _extractSongId(Map<String, dynamic> song) {
    final ytid = song['ytid']?.toString().trim();
    if (ytid != null && ytid.isNotEmpty && ytid != 'null') return ytid;

    final id = song['id']?.toString().trim();
    if (id != null && id.isNotEmpty && id != 'null') return id;

    return '';
  }

  /// Filters songs by artist name for "Because you listened to..."
  static List<Map<String, dynamic>> _findSongsByArtist(
    List<Map<String, dynamic>> pool,
    String artistName, {
    int limit = 8,
  }) {
    final lowerTarget = artistName.toLowerCase().trim();
    if (lowerTarget.isEmpty) return const [];
    final cleanTarget = lowerTarget.replaceAll(RegExp(r'[\.\s\-]+'), '');
    final seen = <String>{};
    final matched = <Map<String, dynamic>>[];

    bool matchesArtist(String candidate) {
      final lower = candidate.toLowerCase().trim();
      if (lower.isEmpty) return false;
      if (lower == lowerTarget) return true;
      if (lower.contains(lowerTarget) || lowerTarget.contains(lower))
        return true;

      final clean = lower.replaceAll(RegExp(r'[\.\s\-]+'), '');
      if (clean.isNotEmpty && cleanTarget.isNotEmpty) {
        if (clean == cleanTarget) return true;
        if (clean.length >= 3 && cleanTarget.length >= 3) {
          if (clean.contains(cleanTarget) || cleanTarget.contains(clean)) {
            return true;
          }
        }
      }
      return false;
    }

    for (final song in pool) {
      final id = _extractSongId(song);
      if (id.isEmpty || !seen.add(id)) continue;

      var isMatch = false;

      // 1. Check display artist
      final displayArtist = getDisplayArtist(song);
      if (displayArtist.isNotEmpty) {
        if (matchesArtist(displayArtist)) {
          isMatch = true;
        } else {
          final parts = displayArtist
              .split(
                RegExp(
                  r'[,&/]|(?:\s+(?:feat\.?|ft\.?|vs\.?|with)\s+)',
                  caseSensitive: false,
                ),
              )
              .map((p) => p.trim());
          for (final p in parts) {
            if (matchesArtist(p)) {
              isMatch = true;
              break;
            }
          }
        }
      }

      // 2. Direct artist/author/videoAuthor fields
      if (!isMatch) {
        final artist = song['artist']?.toString() ?? '';
        final author = song['author']?.toString() ?? '';
        final videoAuthor = song['videoAuthor']?.toString() ?? '';
        if (matchesArtist(artist) ||
            matchesArtist(author) ||
            matchesArtist(videoAuthor)) {
          isMatch = true;
        }
      }

      // 3. artists array (if any)
      if (!isMatch && song['artists'] is List) {
        for (final a in song['artists'] as List) {
          final aName = (a is Map ? a['name'] : a)?.toString() ?? '';
          if (matchesArtist(aName)) {
            isMatch = true;
            break;
          }
        }
      }

      if (isMatch) {
        matched.add(song);
        if (matched.length >= limit) break;
      }
    }

    return matched;
  }
}

class _ScoredItem<T> {
  const _ScoredItem({
    required this.item,
    required this.score,
    required this.id,
  });

  final T item;
  final double score;
  final String id;
}
