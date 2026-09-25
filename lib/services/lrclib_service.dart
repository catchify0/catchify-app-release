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

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Model class for LrcLib API track response
class Track {
  Track({
    required this.id,
    required this.trackName,
    required this.artistName,
    required this.albumName,
    required this.duration,
    required this.instrumental,
    this.plainLyrics,
    this.syncedLyrics,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as int? ?? 0,
      trackName: json['trackName'] as String? ?? '',
      artistName: json['artistName'] as String? ?? '',
      albumName: json['albumName'] as String? ?? '',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      instrumental: json['instrumental'] as bool? ?? false,
      plainLyrics: json['plainLyrics'] as String?,
      syncedLyrics: json['syncedLyrics'] as String?,
    );
  }

  final int id;
  final String trackName;
  final String artistName;
  final String albumName;
  final int duration;
  final bool instrumental;
  final String? plainLyrics;
  final String? syncedLyrics;
}

/// Service to interact with LrcLib API (https://lrclib.net)
class LrcLibService {
  /// Primary endpoint for exact track lookup
  static const String _getEndpoint = 'https://lrclib.net/api/get';
  static const String _searchEndpoint = 'https://lrclib.net/api/search';

  /// Standard User-Agent compliant with LRCLIB API guidelines
  static const Map<String, String> _headers = {
    'User-Agent':
        'Catchify/1.0 (https://github.com/catchify0/catchify0.github.io)',
  };

  /// In-memory LRU cache for fetched lyrics to prevent repeat network calls
  static final Map<String, String> _lyricsCache = {};
  static const int _maxLyricsCacheSize = 120;

  // Channel and label patterns that shouldn't be used as the artist name
  static final List<RegExp> _channelLabelPatterns = [
    RegExp(r'\bthink\s*(?:music|indie)\b', caseSensitive: false),
    RegExp(r'\bsony\s*music\b', caseSensitive: false),
    RegExp(r'\bt-series\b', caseSensitive: false),
    RegExp(r'\bsaregama\b', caseSensitive: false),
    RegExp(r'\bzee\s*music\b', caseSensitive: false),
    RegExp(r'\baditya\s*music\b', caseSensitive: false),
    RegExp(r'\btips\b', caseSensitive: false),
    RegExp(r'\blahari\b', caseSensitive: false),
    RegExp(r'\bdivo\b', caseSensitive: false),
    RegExp(r'\bmuzik247\b', caseSensitive: false),
    RegExp(r'\bspeed\s*audio\b', caseSensitive: false),
    RegExp(r'\btimes\s*music\b', caseSensitive: false),
    RegExp(r'\beros\s*now\b', caseSensitive: false),
    RegExp(r'\byrf\b|\byash\s*raj\b', caseSensitive: false),
    RegExp(r'\bjunglee\b', caseSensitive: false),
    RegExp(r'\bsun\s*tv\b|\bstar\s*vijay\b', caseSensitive: false),
    RegExp(r'\bvevo\b', caseSensitive: false),
    RegExp(
      r'\brecords\b|\bofficial\b|\btopic\b|\bmusic\s*india\b',
      caseSensitive: false,
    ),
  ];

  static bool isChannelLabel(String artist) {
    if (artist.trim().isEmpty) return true;
    for (final pattern in _channelLabelPatterns) {
      if (pattern.hasMatch(artist)) return true;
    }
    return false;
  }

  // Common title cleanup patterns
  static final List<RegExp> _titleCleanupPatterns = [
    RegExp(
      r'\s*\(.*?(?:official|audio|video|lyrics|lyric|lyrical|feat|ft|remix|hd|4k|from|full song|original|tamil|telugu|hindi|malayalam|kannada).*?\)',
      caseSensitive: false,
    ),
    RegExp(
      r'\s*\[.*?(?:official|audio|video|lyrics|lyric|lyrical|feat|ft|remix|hd|4k|from|full song|original|tamil|telugu|hindi|malayalam|kannada).*?\]',
      caseSensitive: false,
    ),
    RegExp(
      r'\s*-\s*(?:official|audio|video|lyrics|lyric|lyrical|hd|4k|music video|lyric video|video song|full song).*$',
      caseSensitive: false,
    ),
    RegExp(
      r'\s*(?:official video|music video|lyric video|lyrical video|video song|audio song|full video|full song|lyric|lyrics)',
      caseSensitive: false,
    ),
  ];

  // Common artist separation patterns
  static final List<String> _artistSeparators = [
    ' feat.',
    ' ft.',
    ' feat',
    ' ft',
    ' & ',
    ', ',
    ' x ',
  ];

  /// Clean the title for better search results
  static String _cleanTitle(String title) {
    var cleaned = title.trim();

    // If title contains '|', '•', or '~' (common YouTube dividers for cast/label/producer),
    // the song name is almost always the first segment:
    if (cleaned.contains('|') ||
        cleaned.contains('•') ||
        cleaned.contains('~')) {
      final seg = cleaned.split(RegExp('[|•~]')).first.trim();
      if (seg.isNotEmpty) cleaned = seg;
    }

    // Strip leading @handles (e.g. @SaiAbhyankkar - )
    cleaned = cleaned.replaceAll(RegExp(r'^@\w+\s*[-–—:]\s*'), '');
    for (final pattern in _titleCleanupPatterns) {
      cleaned = cleaned.replaceAll(pattern, '');
    }
    cleaned = cleaned.replaceAll(RegExp(r'[()[\]]'), ' ');
    return cleaned.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  /// Extract candidate title strings (e.g. from "Leo - Badass" -> ["Leo - Badass", "Badass", "Leo"])
  static List<String> _extractTitleCandidates(String title) {
    final clean = _cleanTitle(title);
    final candidates = <String>[clean];

    // Normalize common title separators (en-dash, em-dash, colon) to standard hyphen
    final normalized = clean
        .replaceAll(' – ', ' - ')
        .replaceAll(' — ', ' - ')
        .replaceAll(': ', ' - ');

    if (normalized.contains(' - ')) {
      final parts = normalized.split(' - ');
      if (parts.length >= 2) {
        final left = parts[0].trim();
        final right = parts.sublist(1).join(' - ').trim();
        if (right.isNotEmpty && !candidates.contains(right))
          candidates.add(right);
        if (left.isNotEmpty && !candidates.contains(left)) candidates.add(left);
        final merged = '$left $right';
        if (!candidates.contains(merged)) candidates.add(merged);
      }
    }
    return candidates;
  }

  /// Extract primary artist from the given string
  static String _cleanArtist(String artist) {
    var cleaned = artist.trim();
    cleaned = cleaned.replaceAll(RegExp('^@'), '');
    for (final separator in _artistSeparators) {
      final idx = cleaned.toLowerCase().indexOf(separator.toLowerCase());
      if (idx != -1) {
        cleaned = cleaned.substring(0, idx);
        break;
      }
    }
    cleaned = cleaned.replaceAll(
      RegExp(r'\s*-\s*topic$', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\s+topic$', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\s+official$', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(RegExp(r'vevo$', caseSensitive: false), '');
    return cleaned.trim();
  }

  /// Attempt exact lookup using LRCLIB's official GET /api/get endpoint
  static Future<Track?> _getExactTrack({
    required String trackName,
    required String artistName,
    int? duration,
    String? albumName,
  }) async {
    try {
      final uri = Uri.parse(_getEndpoint);
      final queryParams = <String, String>{
        'track_name': trackName.trim(),
        'artist_name': artistName.trim(),
      };
      if (duration != null && duration > 0) {
        queryParams['duration'] = duration.toString();
      }
      if (albumName != null && albumName.trim().isNotEmpty) {
        queryParams['album_name'] = albumName.trim();
      }

      final uriWithQuery = uri.replace(queryParameters: queryParams);
      final response = await http
          .get(uriWithQuery, headers: _headers)
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final dynamic jsonData = jsonDecode(response.body);
        if (jsonData is Map<String, dynamic>) {
          final track = Track.fromJson(jsonData);
          if (track.syncedLyrics != null || track.plainLyrics != null) {
            return track;
          }
        }
      } else if (response.statusCode == 404 &&
          duration != null &&
          duration > 0) {
        // LRCLIB requires duration within +/- 2s. If YouTube audio has video intro/outro silence
        // or slight length variance, retry without duration and verify closeness.
        final retryParams = <String, String>{
          'track_name': trackName.trim(),
          'artist_name': artistName.trim(),
        };
        if (albumName != null && albumName.trim().isNotEmpty) {
          retryParams['album_name'] = albumName.trim();
        }
        final retryUri = uri.replace(queryParameters: retryParams);
        final retryResp = await http
            .get(retryUri, headers: _headers)
            .timeout(const Duration(seconds: 5));

        if (retryResp.statusCode == 200) {
          final dynamic jsonData = jsonDecode(retryResp.body);
          if (jsonData is Map<String, dynamic>) {
            final track = Track.fromJson(jsonData);
            // Verify duration difference is reasonable (<= 18 seconds)
            if (track.duration <= 0 ||
                (track.duration - duration).abs() <= 18) {
              if (track.syncedLyrics != null || track.plainLyrics != null) {
                return track;
              }
            }
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static List<String> _buildSearchQueries(String artist, String title) {
    final cleanT = _cleanTitle(title);
    final cleanA = _cleanArtist(artist);
    final isLabel = isChannelLabel(cleanA);
    final effectiveArtist = isLabel ? '' : cleanA;

    final words = cleanT.split(' ').where((w) => w.trim().isNotEmpty).toList();
    final first1Word = words.isNotEmpty ? words.first : '';
    final first2Words = words.length >= 2 ? '${words[0]} ${words[1]}' : cleanT;
    final first3Words = words.length >= 3
        ? '${words[0]} ${words[1]} ${words[2]}'
        : cleanT;

    final queries = <String>[];

    // 1. Artist + Title if artist is real
    if (effectiveArtist.isNotEmpty && cleanT.isNotEmpty) {
      queries
        ..add('$effectiveArtist $cleanT')
        ..add('$effectiveArtist $first2Words');
    }

    // 2. Title candidates (e.g. from Movie - Song)
    for (final cand in _extractTitleCandidates(title)) {
      if (effectiveArtist.isNotEmpty) {
        queries.add('$effectiveArtist $cand');
      }
      queries.add(cand);
    }

    // 3. First 2-3 words of title
    if (first2Words.isNotEmpty) queries.add(first2Words);
    if (first3Words.isNotEmpty && first3Words != first2Words)
      queries.add(first3Words);

    // 4. First word if single word title
    if (first1Word.length >= 4 && !queries.contains(first1Word)) {
      queries.add(first1Word);
    }

    // Deduplicate preserving order
    final seen = <String>{};
    final dedup = <String>[];
    for (final q in queries) {
      final norm = q.toLowerCase().trim();
      if (norm.length > 1 && seen.add(norm)) {
        dedup.add(q.trim());
      }
    }
    return dedup;
  }

  /// Query LrcLib search API with specific parameters
  static Future<List<Track>> _queryLyricsWithParams({
    String? trackName,
    String? artistName,
    String? albumName,
    String? query,
  }) async {
    try {
      final uri = Uri.parse(_searchEndpoint);
      final queryParams = <String, String>{};

      if (query != null && query.trim().isNotEmpty)
        queryParams['q'] = query.trim();
      if (trackName != null && trackName.trim().isNotEmpty)
        queryParams['track_name'] = trackName.trim();
      if (artistName != null && artistName.trim().isNotEmpty)
        queryParams['artist_name'] = artistName.trim();
      if (albumName != null && albumName.trim().isNotEmpty)
        queryParams['album_name'] = albumName.trim();

      final uriWithQuery = uri.replace(queryParameters: queryParams);
      final response = await http
          .get(uriWithQuery, headers: _headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final dynamic jsonData = jsonDecode(response.body);

        late List<dynamic> jsonList;
        if (jsonData is List) {
          jsonList = jsonData;
        } else if (jsonData is Map && jsonData['tracks'] != null) {
          jsonList = jsonData['tracks'];
        } else if (jsonData is Map) {
          jsonList = [jsonData];
        } else {
          jsonList = [];
        }

        return jsonList
            .whereType<Map<String, dynamic>>()
            .map(Track.fromJson)
            .toList();
      }

      return [];
    } catch (_) {
      return [];
    }
  }

  /// Score how well a track candidate matches the requested song and duration
  static double _scoreTrack(
    Track track,
    String searchTitle,
    String searchArtist,
    int? targetDuration,
  ) {
    var score = 0.0;

    final hasSynced =
        track.syncedLyrics != null && track.syncedLyrics!.isNotEmpty;
    final hasPlain = track.plainLyrics != null && track.plainLyrics!.isNotEmpty;

    // Synced lyrics are overwhelmingly prioritized over plain lyrics
    if (hasSynced) {
      score += 150;
    } else if (hasPlain) {
      score += 10;
    } else {
      return 0;
    }

    // Title similarity
    final tSim = _titleSimilarity(track.trackName, searchTitle);
    score += tSim * 40;

    // Artist similarity
    if (searchArtist.isNotEmpty) {
      final aSim = _titleSimilarity(track.artistName, searchArtist);
      score += aSim * 20;
    }

    // Duration proximity scoring:
    // Video audio on YouTube frequently has 10-25s of intro/outro or dialogue.
    // For synced lyrics, we reward closeness but do not let duration disqualify synced results.
    if (targetDuration != null && targetDuration > 0 && track.duration > 0) {
      final diff = (track.duration - targetDuration).abs();
      if (diff <= 2) {
        score += 35; // Near-identical length
      } else if (diff <= 5) {
        score += 25; // Very close
      } else if (diff <= 10) {
        score += 15;
      } else if (diff <= 20) {
        score += 5;
      } else if (diff > 35) {
        // Severe penalty only for massive length mismatches (e.g. extended versions)
        score -= hasSynced ? 25 : 50;
      }
    }

    return score;
  }

  /// Fetch lyrics for a song - returns synced lyrics if available, otherwise plain lyrics
  static Future<String?> getLyrics({
    required String title,
    required String artist,
    int? duration,
    String? album,
  }) async {
    final cacheKey = '$title::$artist::${duration ?? 0}';
    final cached = _lyricsCache[cacheKey];
    if (cached != null) return cached;

    String? cacheAndReturn(String? lyrics) {
      if (lyrics != null && lyrics.isNotEmpty) {
        if (_lyricsCache.length >= _maxLyricsCacheSize) {
          _lyricsCache.remove(_lyricsCache.keys.first);
        }
        _lyricsCache[cacheKey] = lyrics;
      }
      return lyrics;
    }

    try {
      final cleanA = _cleanArtist(artist);
      final isLabel = isChannelLabel(cleanA);
      final effectiveArtist = isLabel ? '' : cleanA;
      final candidates = _extractTitleCandidates(title);

      // Phase 1: Try exact canonical match via /api/get for each title candidate
      if (effectiveArtist.isNotEmpty) {
        for (final cand in candidates) {
          final exact = await _getExactTrack(
            trackName: cand,
            artistName: effectiveArtist,
            duration: duration,
            albumName: album,
          );
          if (exact != null &&
              exact.syncedLyrics != null &&
              exact.syncedLyrics!.isNotEmpty) {
            return cacheAndReturn(exact.syncedLyrics);
          }
        }

        // What if artist and title were inverted in the metadata? (e.g. artist="Hukum", title="Anirudh")
        for (final cand in candidates) {
          final inverted = await _getExactTrack(
            trackName: effectiveArtist,
            artistName: cand,
            duration: duration,
          );
          if (inverted != null &&
              inverted.syncedLyrics != null &&
              inverted.syncedLyrics!.isNotEmpty) {
            return cacheAndReturn(inverted.syncedLyrics);
          }
        }
      }

      // Phase 2: Fallback to /api/search with structured queries first, then fulltext queries
      final candidatePool = <int, Track>{};

      // 2A. High-precision structured search by track_name & artist_name
      if (effectiveArtist.isNotEmpty) {
        for (final cand in candidates) {
          final structured = await _queryLyricsWithParams(
            trackName: cand,
            artistName: effectiveArtist,
          );
          for (final t in structured) {
            if (t.syncedLyrics != null || t.plainLyrics != null) {
              candidatePool[t.id] = t;
            }
          }
          if (candidatePool.isNotEmpty) {
            if (duration != null && duration > 0) {
              final hasCloseSynced = candidatePool.values.any(
                (t) =>
                    t.syncedLyrics != null &&
                    (t.duration - duration).abs() <= 6,
              );
              if (hasCloseSynced) break;
            } else {
              break;
            }
          }
        }
      }

      // 2B. Structured search by track_name (if no synced lyrics found yet)
      final hasSyncedInPool = candidatePool.values.any(
        (t) => t.syncedLyrics != null && t.syncedLyrics!.isNotEmpty,
      );

      if (!hasSyncedInPool) {
        for (final cand in candidates) {
          final titleResults = await _queryLyricsWithParams(trackName: cand);
          for (final t in titleResults) {
            if (t.syncedLyrics != null || t.plainLyrics != null) {
              candidatePool[t.id] = t;
            }
          }
          if (candidatePool.values.any(
            (t) => t.syncedLyrics != null && t.syncedLyrics!.isNotEmpty,
          )) {
            break;
          }
        }
      }

      // 2C. Fallback to broad fulltext queries (?q=) (if still no synced lyrics found)
      final stillNoSynced = !candidatePool.values.any(
        (t) => t.syncedLyrics != null && t.syncedLyrics!.isNotEmpty,
      );

      if (stillNoSynced) {
        final queries = _buildSearchQueries(artist, title);
        for (final q in queries) {
          final results = await _queryLyricsWithParams(query: q);
          for (final t in results) {
            if (t.syncedLyrics != null || t.plainLyrics != null) {
              candidatePool[t.id] = t;
            }
          }
          if (candidatePool.values.any(
            (t) => t.syncedLyrics != null && t.syncedLyrics!.isNotEmpty,
          )) {
            if (duration != null && duration > 0) {
              final hasCloseSynced = candidatePool.values.any(
                (t) =>
                    t.syncedLyrics != null &&
                    (t.duration - duration).abs() <= 12,
              );
              if (hasCloseSynced) break;
            } else {
              break;
            }
          }
        }
      }

      if (candidatePool.isEmpty) {
        return null;
      }

      final pool = candidatePool.values.toList();
      final cleanSearchTitle = _cleanTitle(title);

      // Rank all candidates with multi-factor scoring: synced lyrics heavily favored
      pool.sort((a, b) {
        final scoreA = _scoreTrack(
          a,
          cleanSearchTitle,
          effectiveArtist,
          duration,
        );
        final scoreB = _scoreTrack(
          b,
          cleanSearchTitle,
          effectiveArtist,
          duration,
        );
        return scoreB.compareTo(scoreA);
      });

      final bestMatch = pool.first;
      return cacheAndReturn(bestMatch.syncedLyrics ?? bestMatch.plainLyrics);
    } catch (_) {
      return null;
    }
  }

  /// Word-overlap and token containment similarity score between 0.0 and 1.0
  static double _titleSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final normA = a.replaceAll(RegExp(r'[^\w\s]'), '').toLowerCase().trim();
    final normB = b.replaceAll(RegExp(r'[^\w\s]'), '').toLowerCase().trim();
    if (normA == normB) return 1;
    if (normA.isEmpty || normB.isEmpty) return 0;

    final wordsA = normA
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toSet();
    final wordsB = normB
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toSet();
    if (wordsA.isEmpty || wordsB.isEmpty) return 0;

    // If one set of words is entirely contained in the other (e.g. artist inside multi-artist string)
    if (wordsB.every(wordsA.contains) || wordsA.every(wordsB.contains)) {
      return 0.90;
    }

    final intersection = wordsA.intersection(wordsB).length;
    final union = wordsA.union(wordsB).length;
    return union == 0 ? 0 : intersection / union;
  }
}
