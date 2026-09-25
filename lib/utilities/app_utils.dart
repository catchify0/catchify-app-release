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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:catchify/constants/app_constants.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

BorderRadius getItemBorderRadius(
  int index,
  int totalLength, {
  bool hasItemsBefore = false,
  bool hasItemsAfter = false,
}) {
  // Determine if this item is the absolute top or absolute bottom of the visual block
  final isAbsoluteFirst = index == 0 && !hasItemsBefore;
  final isAbsoluteLast = index == totalLength - 1 && !hasItemsAfter;

  if (isAbsoluteFirst && isAbsoluteLast) {
    return commonCustomBarRadius; // Single item in the entire block
  } else if (isAbsoluteFirst) {
    return commonCustomBarRadiusFirst; // Top of the block
  } else if (isAbsoluteLast) {
    return commonCustomBarRadiusLast; // Bottom of the block
  }
  return BorderRadius.zero; // Default for middle items
}

ValueKey<int> listItemKey(String scope, int index, [Object? item]) {
  final identity = item is Map
      ? (item['ytid'] ?? item['id'] ?? item['title'] ?? item.hashCode)
      : item;
  return ValueKey<int>(Object.hash(scope, index, identity));
}

List<Map<String, dynamic>> asMapList(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
}

/// Safely formats and cleans artist, curator, or author names from various data structures:
/// - Plain String: "Anirudh Ravichander"
/// - List of maps: [{'name': 'Anirudh Ravichander', 'id': '...'}, ...] -> "Anirudh Ravichander"
/// - List of strings: ['Anirudh Ravichander', 'Yuvan'] -> "Anirudh Ravichander, Yuvan"
/// - Single map: {'name': 'Anirudh Ravichander'} -> "Anirudh Ravichander"
/// - Stringified List/Map: "[{name: Anirudh Ravichander, id: ...}]" -> "Anirudh Ravichander"
String formatArtistName(dynamic value) {
  if (value == null) return '';

  if (value is List) {
    final names = <String>[];
    for (final item in value) {
      if (item is Map) {
        final name =
            item['name']?.toString().trim() ??
            item['title']?.toString().trim() ??
            item['artist']?.toString().trim() ??
            '';
        if (name.isNotEmpty && name != 'null') {
          names.add(name);
        }
      } else if (item is String) {
        final trimmed = item.trim();
        if (trimmed.isNotEmpty && trimmed != 'null') {
          names.add(trimmed);
        }
      }
    }
    if (names.isNotEmpty) {
      return names.join(', ');
    }
    return '';
  }

  if (value is Map) {
    final name =
        value['name']?.toString().trim() ??
        value['title']?.toString().trim() ??
        value['artist']?.toString().trim() ??
        '';
    if (name.isNotEmpty && name != 'null') {
      return name;
    }
    return '';
  }

  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == 'null') return '';

    // Check if the string is a stringified list or map representation:
    // e.g. "[{name: Anirudh Ravichander, id: ...}]" or "[{\"name\": \"Anirudh\"}]"
    if ((trimmed.startsWith('[{') || trimmed.startsWith('{')) &&
        (trimmed.contains('name:') ||
            trimmed.contains('"name"') ||
            trimmed.contains("'name'"))) {
      final matches = RegExp(r'''['"]?name['"]?\s*:\s*([^,}\]]+)''')
          .allMatches(trimmed)
          .map((m) {
            var val = m.group(1)?.trim() ?? '';
            if (val.startsWith("'") || val.startsWith('"')) {
              val = val.substring(1);
            }
            if (val.endsWith("'") || val.endsWith('"')) {
              val = val.substring(0, val.length - 1);
            }
            return val.trim();
          })
          .where((s) => s.isNotEmpty && s != 'null')
          .toList();
      if (matches.isNotEmpty) {
        return matches.join(', ');
      }
    }
    return trimmed;
  }

  return value.toString();
}

/// Safely extracts artist or creator text from a song, playlist, or album map.
String getDisplayArtist(Map map, {String fallback = ''}) {
  // Check 'artist' first
  final artist = formatArtistName(map['artist']);
  if (artist.isNotEmpty) return artist;

  // Check 'artists' (plural)
  final artists = formatArtistName(map['artists']);
  if (artists.isNotEmpty) return artists;

  // Check 'author'
  final author = formatArtistName(map['author']);
  if (author.isNotEmpty) return author;

  // Check 'authors'
  final authors = formatArtistName(map['authors']);
  if (authors.isNotEmpty) return authors;

  // Check 'creator'
  final creator = formatArtistName(map['creator']);
  if (creator.isNotEmpty) return creator;

  // Check 'description' (only if clean text, not stringified JSON/object)
  final desc = map['description']?.toString().trim() ?? '';
  if (desc.isNotEmpty && !desc.startsWith('[{') && !desc.startsWith('{')) {
    return desc;
  }

  return fallback;
}

/// Validates if a URL is a YouTube playlist URL
bool isYoutubePlaylistUrl(String url) {
  return _youtubePlaylistRegExp.hasMatch(url);
}

/// Extracts the playlist ID from a YouTube playlist URL
String? extractYoutubePlaylistId(String url) {
  if (!isYoutubePlaylistUrl(url)) {
    return null;
  }

  final match = _youtubePlaylistIdRegExp.firstMatch(url);
  return match?.group(1);
}

double getResponsiveTitleFontSize(Size size) {
  final isDesktop = size.width > 800;
  final isLandscape = size.width > size.height;
  if (isDesktop || isLandscape) return 20;
  if (size.width < 360) return 20;
  if (size.width < 400) return 22;
  return size.height * 0.028;
}

double getResponsiveArtistFontSize(Size size) {
  final isDesktop = size.width > 800;
  final isLandscape = size.width > size.height;
  if (isDesktop || isLandscape) return 14;
  if (size.width < 360) return 14;
  if (size.width < 400) return 15;
  return size.height * 0.018;
}

final RegExp _youtubePlaylistRegExp = RegExp(
  r'^(https?:\/\/)?(www\.|m\.|music\.)?(youtube\.com|youtu\.be)\/.*(list=([a-zA-Z0-9_-]+)).*$',
);

final RegExp _youtubePlaylistIdRegExp = RegExp('[&?]list=([a-zA-Z0-9_-]+)');

bool isSponsorshipAnnouncementUrl(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase();
  return host != null && (host == 'ko-fi.com' || host.endsWith('.ko-fi.com'));
}

/// Formats a [monthKey] (e.g. "2026-06") into a locale-aware month label
/// such as "June 2026". Falls back to [monthKey] if parsing fails.
String formatMonthPeriodLabel(Locale locale, String monthKey) {
  final parts = monthKey.split('-');
  if (parts.length != 2) return monthKey;

  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null) return monthKey;

  final label = DateFormat.yMMMM(
    locale.toString(),
  ).format(DateTime(year, month));
  return label.isEmpty
      ? monthKey
      : '${label[0].toUpperCase()}${label.substring(1)}';
}

AudioOnlyStreamInfo selectAudioOnlyStreamForQuality(
  List<AudioOnlyStreamInfo> availableSources,
) {
  final sortedByCompatibility = _sortAudioOnlyByCompatibility(availableSources);
  final compatibleSources = _filterCompatibleAudioOnlySources(
    sortedByCompatibility,
  );
  final selectionPool = compatibleSources.isNotEmpty
      ? compatibleSources
      : sortedByCompatibility;

  final qualitySetting = audioQualitySetting.value;

  if (qualitySetting == 'low') {
    return selectionPool.last;
  } else if (qualitySetting == 'medium') {
    return selectionPool[selectionPool.length ~/ 2];
  }

  return selectionPool.withHighestBitrate();
}

List<AudioOnlyStreamInfo> _filterCompatibleAudioOnlySources(
  List<AudioOnlyStreamInfo> sources,
) {
  return sources.where((stream) {
    final codec = stream.codec.toString().toLowerCase();
    final container = stream.container.name.toLowerCase();

    if (_isDolbyCodec(codec)) {
      return false;
    }

    if (Platform.isIOS) {
      // iOS AVPlayer natively only supports m4a/mp4 containers (AAC codec).
      // WebM/Opus causes infinite loading/buffering in AVPlayer.
      return (codec.contains('mp4a') || codec.contains('aac')) &&
          (container == 'mp4' || container == 'm4a');
    }

    return _isPreferredAudioOnlyCodec(codec, container);
  }).toList();
}

List<AudioOnlyStreamInfo> _sortAudioOnlyByCompatibility(
  List<AudioOnlyStreamInfo> sources,
) {
  final sorted = List<AudioOnlyStreamInfo>.from(sources)
    ..sort((a, b) {
      final aScore = _audioOnlyCompatibilityScore(a);
      final bScore = _audioOnlyCompatibilityScore(b);
      return bScore.compareTo(aScore);
    });
  return sorted;
}

int _audioOnlyCompatibilityScore(AudioOnlyStreamInfo stream) {
  final codec = stream.codec.toString().toLowerCase();
  final container = stream.container.name.toLowerCase();

  if (_isDolbyCodec(codec)) {
    return 0;
  }

  if ((codec.contains('mp4a') || codec.contains('aac')) &&
      (container == 'mp4' || container == 'm4a')) {
    return 3;
  }

  if (codec.contains('opus') || codec.contains('vorbis')) {
    return Platform.isIOS ? 0 : 2;
  }

  return 1;
}

bool _isDolbyCodec(String codec) {
  return codec.contains('ec-3') ||
      codec.contains('ac-3') ||
      codec.contains('eac3') ||
      codec.contains('dolby');
}

bool _isPreferredAudioOnlyCodec(String codec, String container) {
  if ((codec.contains('mp4a') || codec.contains('aac')) &&
      (container == 'mp4' || container == 'm4a')) {
    return true;
  }

  if (Platform.isIOS) {
    return false;
  }

  return codec.contains('opus') || codec.contains('vorbis');
}
