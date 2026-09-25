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

import 'package:catchify/models/home_section.dart';

/// Pure composition layer for the Catchify Home Feed.
///
/// Responsibilities:
/// 1. Strictly preserves raw YouTube Music server shelf order 1:1 without artificial priority sorting.
/// 2. In-section item deduplication without cross-shelf contamination.
/// 3. Injects local personalization (mood, personalized sections, favorites, recap) at clean, dedicated slots:
///    - `moodSection` (if present) placed at the top (index 0) for active mood listening.
///    - `personalizedSections` (e.g. "Made for you") placed after the primary shelf (or at slot 0 if no remote shelves),
///      preserving the remaining remote feed in its exact server order.
///    - `favoritesSection` and `recapSection` placed at designated positions.
/// 4. Dropping empty sections.
class HomeFeedComposer {
  const HomeFeedComposer._();

  /// Composes a unified, ordered list of [HomeSection]s.
  ///
  /// This method is pure and does NOT perform any network or disk operations.
  static List<HomeSection> compose({
    required List<HomeSection> remoteSections,
    HomeSection? moodSection,
    HomeSection? favoritesSection,
    HomeSection? recapSection,
    List<HomeSection>? personalizedSections,
    List<HomeSection>? languageSections,
  }) {
    final result = <HomeSection>[];

    // 1. Mood section: if present, takes top priority for mood-focused listening
    if (moodSection != null && moodSection.isNotEmpty) {
      final deduped = _deduplicateSection(moodSection);
      if (deduped.isNotEmpty) {
        result.add(deduped);
      }
    }

    // 2. Prepare language curated sections (e.g. "Trending songs for you", "Featured playlists", "New releases")
    final validLanguage = <HomeSection>[];
    if (languageSections != null && languageSections.isNotEmpty) {
      for (final sec in languageSections) {
        if (sec.isEmpty) continue;
        final deduped = _deduplicateSection(sec);
        if (deduped.isNotEmpty) {
          validLanguage.add(deduped);
        }
      }
    }

    // 3. Prepare local personalized sections (e.g. "Continue listening", "Made for you", "Because you listened to...")
    final validPersonalized = <HomeSection>[];
    HomeSection? continueListeningSection;
    if (personalizedSections != null && personalizedSections.isNotEmpty) {
      for (final sec in personalizedSections) {
        if (sec.isEmpty) continue;
        final deduped = _deduplicateSection(sec);
        if (deduped.isNotEmpty) {
          final norm = _normalizeTitle(deduped.title);
          if (norm == 'continue listening' ||
              norm == 'recently played' ||
              norm == 'listen again') {
            continueListeningSection ??= deduped;
          } else {
            validPersonalized.add(deduped);
          }
        }
      }
    }

    // 4. Prepare remote sections, strictly preserving server order
    final validRemote = <HomeSection>[];
    for (final sec in remoteSections) {
      if (sec.isEmpty) continue;
      final deduped = _deduplicateSection(sec);
      if (deduped.isNotEmpty) {
        validRemote.add(deduped);
      }
    }

    // 5. Assemble feed:
    // Top Priority 1: Standard Continue Listening / Recently played:
    // If the user has playback history, standard music app experience places Continue Listening
    // at the very top (slot 0 / directly below active mood) so users can immediately resume playback.
    if (continueListeningSection != null) {
      result.add(continueListeningSection);
    }

    // If language sections are present, place the primary language discovery sections
    // (e.g. Quick picks, Trending songs) right next so the user immediately
    // perceives their selected language without scrolling past generic remote content.
    if (validLanguage.isNotEmpty) {
      final existingTitles = <String>{};
      if (continueListeningSection != null) {
        existingTitles.add(_normalizeTitle(continueListeningSection.title));
      }

      void addSection(HomeSection sec) {
        result.add(sec);
        existingTitles.add(_normalizeTitle(sec.title));
      }

      // 1. Primary language discovery prominently placed
      for (final sec in validLanguage.take(2)) {
        addSection(sec);
      }

      // 2. Local personalization (e.g. "Made for you")
      for (final sec in validPersonalized) {
        addSection(sec);
      }

      // 3. First remote server shelf (if not duplicating existing title)
      if (validRemote.isNotEmpty) {
        final hero = validRemote.first;
        if (!existingTitles.contains(_normalizeTitle(hero.title))) {
          addSection(hero);
        }
      }

      // 4. Secondary language discovery (featured playlists, community playlists, new releases, artists)
      if (validLanguage.length > 2) {
        for (final sec in validLanguage.sublist(2)) {
          if (!existingTitles.contains(_normalizeTitle(sec.title))) {
            addSection(sec);
          }
        }
      }

      if (favoritesSection != null && favoritesSection.isNotEmpty) {
        final deduped = _deduplicateSection(favoritesSection);
        if (deduped.isNotEmpty) addSection(deduped);
      }
      if (recapSection != null && recapSection.isNotEmpty) {
        final deduped = _deduplicateSection(recapSection);
        if (deduped.isNotEmpty) addSection(deduped);
      }

      // 5. Remaining remote server shelves, skipping accidental duplicates of language titles
      if (validRemote.length > 1) {
        for (final sec in validRemote.sublist(1)) {
          if (!existingTitles.contains(_normalizeTitle(sec.title))) {
            addSection(sec);
          }
        }
      }
    } else if (validRemote.isNotEmpty) {
      // No regional language preference (or English): preserve native server order 1:1
      result
        ..add(validRemote.first)
        ..addAll(validPersonalized);

      if (favoritesSection != null && favoritesSection.isNotEmpty) {
        final deduped = _deduplicateSection(favoritesSection);
        if (deduped.isNotEmpty) result.add(deduped);
      }
      if (recapSection != null && recapSection.isNotEmpty) {
        final deduped = _deduplicateSection(recapSection);
        if (deduped.isNotEmpty) result.add(deduped);
      }

      if (validRemote.length > 1) {
        result.addAll(validRemote.sublist(1));
      }
    } else {
      // Remote feed empty or offline mode: show personalization & local sections
      result.addAll(validPersonalized);
      if (favoritesSection != null && favoritesSection.isNotEmpty) {
        final deduped = _deduplicateSection(favoritesSection);
        if (deduped.isNotEmpty) result.add(deduped);
      }
      if (recapSection != null && recapSection.isNotEmpty) {
        final deduped = _deduplicateSection(recapSection);
        if (deduped.isNotEmpty) result.add(deduped);
      }
    }

    return result;
  }

  /// Normalizes section titles for duplicate shelf detection.
  ///
  /// We intentionally canonicalize common title variants so equivalent rows
  /// like "Featured playlists for you" and "Featured playlists" are treated as
  /// the same shelf even when the source text has minor formatting differences.
  static String _normalizeTitle(String title) {
    final canonical = title
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\u2013\u2014\-]'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (canonical == 'continue listening' ||
        canonical == 'recently played' ||
        canonical == 'listen again') {
      return 'continue listening';
    }
    if (canonical == 'trending songs for you' ||
        canonical == 'trending songs') {
      return 'trending songs';
    }
    if (canonical == 'featured playlists for you' ||
        canonical == 'featured playlists') {
      return 'featured playlists';
    }
    if (canonical == 'trending community playlists' ||
        canonical == 'community playlists') {
      return 'community playlists';
    }
    if (canonical == 'albums for you' || canonical == 'albums') return 'albums';
    if (canonical == 'artists for you' || canonical == 'artists') {
      return 'artists';
    }
    if (canonical == 'quick picks') return 'quick picks';
    if (canonical == 'new releases') return 'new releases';
    if (canonical == 'made for you') return 'made for you';
    return canonical;
  }

  /// Deduplicates items within the same shelf by item ID.
  ///
  /// Items across different shelves are intentionally preserved.
  static HomeSection _deduplicateSection(HomeSection section) {
    if (section.contents.length <= 1) return section;

    final seenIds = <String>{};
    final deduped = <Map<String, dynamic>>[];

    for (final item in section.contents) {
      final normalizedItem = Map<String, dynamic>.from(item);
      final id = _extractItemId(normalizedItem);
      if (id.isNotEmpty) {
        if (seenIds.add(id)) {
          deduped.add(normalizedItem);
        }
      } else {
        // If no stable ID exists, keep the item.
        deduped.add(normalizedItem);
      }
    }

    if (deduped.length == section.contents.length) {
      return section;
    }

    return HomeSection(
      title: section.title,
      subtitle: section.subtitle,
      type: section.type,
      contents: deduped,
      isChunkedSongs: section.isChunkedSongs,
      browseId: section.browseId,
      params: section.params,
    );
  }

  /// Extracts a stable identification key for deduplication.
  static String _extractItemId(Map<String, dynamic> item) {
    final ytid = item['ytid']?.toString().trim();
    if (ytid != null && ytid.isNotEmpty && ytid != 'null') return ytid;

    final id = item['id']?.toString().trim();
    if (id != null && id.isNotEmpty && id != 'null') return id;

    final browseId = item['browseId']?.toString().trim();
    if (browseId != null && browseId.isNotEmpty && browseId != 'null') {
      return browseId;
    }

    final title = item['title']?.toString().trim() ?? '';
    final artist = item['artist']?.toString().trim() ?? '';
    if (title.isNotEmpty) return '$title::$artist';

    return '';
  }

  /// Formats the section order into a clean diagnostic log.
  static String formatHomeOrder(List<HomeSection> sections) {
    final sb = StringBuffer('\n[HOME_ORDER]\n');
    for (var i = 0; i < sections.length; i++) {
      final s = sections[i];
      final num = (i + 1).toString().padLeft(2, '0');
      sb
        ..writeln('$num. title="${s.title}"')
        ..writeln('    type=${s.type.name}')
        ..writeln('    items=${s.contents.length}\n');
    }
    return sb.toString();
  }
}
