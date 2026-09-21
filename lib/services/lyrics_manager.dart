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

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:catchify/main.dart' show logger;
import 'package:catchify/models/lyric_line.dart';
import 'package:catchify/services/lrclib_service.dart';

class LyricsManager {
  Future<String?> fetchLyrics(
    String artistName,
    String title, {
    int? duration,
    String? ytid,
  }) async {
    final cleanYtid = ytid ?? 'unknown';
    final stopwatch = Stopwatch()..start();
    logger.log(
      '[LYRICS] ytid=$cleanYtid title="$title" artist="$artistName" status=loading',
    );

    // Remove Lyrics/Karaoke only from end of title
    if (title.endsWith(' Lyrics')) {
      title = title.substring(0, title.length - 7).trim();
    } else if (title.endsWith(' Karaoke')) {
      title = title.substring(0, title.length - 8).trim();
    }

    // Try LrcLib first (supports both synced and plain lyrics across all languages)
    final lyricsFromLrcLib = await LrcLibService.getLyrics(
      title: title,
      artist: artistName,
      duration: duration,
    );
    if (lyricsFromLrcLib != null && lyricsFromLrcLib.trim().isNotEmpty) {
      final isSynced = LrcParser.isSynced(lyricsFromLrcLib);
      final lines = isSynced
          ? LrcParser.parse(lyricsFromLrcLib).length
          : lyricsFromLrcLib.split('\n').length;
      logger.log(
        '[LYRICS] ytid=$cleanYtid source=lrclib status=success synced=$isSynced lines=$lines duration_ms=${stopwatch.elapsedMilliseconds}',
      );
      return lyricsFromLrcLib;
    }

    // If LrcLib didn't have it, try fallback web sources
    final isLabel = LrcLibService.isChannelLabel(artistName);
    final effectiveArtist = isLabel ? '' : artistName;

    // Validate title and artist are not empty after sanitization
    if (title.isEmpty || effectiveArtist.isEmpty) {
      logger.log(
        '[LYRICS] ytid=$cleanYtid status=not_found duration_ms=${stopwatch.elapsedMilliseconds}',
      );
      return null;
    }

    final lyricsFromLyricsOvh = await _fetchLyricsFromLyricsOvh(
      effectiveArtist,
      title,
    );
    if (lyricsFromLyricsOvh != null && lyricsFromLyricsOvh.trim().isNotEmpty) {
      logger.log(
        '[LYRICS] ytid=$cleanYtid source=lyrics.ovh status=fallback synced=false lines=${lyricsFromLyricsOvh.split('\n').length} duration_ms=${stopwatch.elapsedMilliseconds}',
      );
      return lyricsFromLyricsOvh;
    }

    final lyricsFromParolesNet = await _fetchLyricsFromParolesNet(
      effectiveArtist.split(',')[0],
      title,
    );
    if (lyricsFromParolesNet != null &&
        lyricsFromParolesNet.trim().isNotEmpty) {
      logger.log(
        '[LYRICS] ytid=$cleanYtid source=paroles.net status=fallback synced=false lines=${lyricsFromParolesNet.split('\n').length} duration_ms=${stopwatch.elapsedMilliseconds}',
      );
      return lyricsFromParolesNet;
    }

    final lyricsFromLyricsMania1 = await _fetchLyricsFromLyricsMania1(
      effectiveArtist,
      title,
    );
    if (lyricsFromLyricsMania1 != null &&
        lyricsFromLyricsMania1.trim().isNotEmpty) {
      logger.log(
        '[LYRICS] ytid=$cleanYtid source=lyricsmania status=fallback synced=false lines=${lyricsFromLyricsMania1.split('\n').length} duration_ms=${stopwatch.elapsedMilliseconds}',
      );
      return lyricsFromLyricsMania1;
    }

    logger.log(
      '[LYRICS] ytid=$cleanYtid status=not_found duration_ms=${stopwatch.elapsedMilliseconds}',
    );
    return null;
  }

  Future<String?> _fetchLyricsFromLyricsOvh(
    String artistName,
    String title,
  ) async {
    try {
      final artistFormatted = _lyricsUrl(artistName.split(',')[0]);
      final titleFormatted = _lyricsUrl(title);
      final uri = Uri.parse(
        'https://api.lyrics.ovh/v1/$artistFormatted/$titleFormatted',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final lyrics = json['lyrics'] as String?;
        if (lyrics != null && lyrics.isNotEmpty) {
          return addCopyright(lyrics, 'lyrics.ovh');
        }
      }
    } catch (e) {
      // Silently fail and return null to try next source
      return null;
    }
    return null;
  }

  Future<String?> _fetchLyricsFromParolesNet(
    String artistName,
    String title,
  ) async {
    try {
      final uri = Uri.parse(
        'https://www.paroles.net/${_lyricsUrl(artistName)}/paroles-${_lyricsUrl(title)}',
      );
      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => http.Response('', 408),
          );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final songTextElements = document.querySelectorAll('.song-text');

        if (songTextElements.isNotEmpty) {
          final lyricsLines = songTextElements.first.text.split('\n');
          if (lyricsLines.length > 1) {
            lyricsLines.removeAt(0);

            final finalLyrics = addCopyright(
              lyricsLines.join('\n'),
              'www.paroles.net',
            );
            return _removeSpaces(finalLyrics);
          }
        }
      }
    } catch (e) {
      // Silently fail and return null to try next source
      return null;
    }

    return null;
  }

  Future<String?> _fetchLyricsFromLyricsMania1(
    String artistName,
    String title,
  ) async {
    try {
      final uri = Uri.parse(
        'https://www.lyricsmania.com/${_lyricsManiaUrl(title)}_lyrics_${_lyricsManiaUrl(artistName)}.html',
      );
      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => http.Response('', 408),
          );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final lyricsBodyElements = document.querySelectorAll('.lyrics-body');

        if (lyricsBodyElements.isNotEmpty) {
          return addCopyright(
            lyricsBodyElements.first.text,
            'www.lyricsmania.com',
          );
        }
      }
    } catch (e) {
      // Silently fail and return null
      return null;
    }

    return null;
  }

  String _lyricsUrl(String input) {
    var result = input.replaceAll(' ', '-').toLowerCase();
    // Remove special characters
    result = result.replaceAll(RegExp('[^a-z0-9-]'), '');
    // Clean up multiple/trailing dashes
    result = result.replaceAll(RegExp('-+'), '-');
    if (result.isNotEmpty && result.endsWith('-')) {
      result = result.substring(0, result.length - 1);
    }
    if (result.isNotEmpty && result.startsWith('-')) {
      result = result.substring(1);
    }
    return result;
  }

  String _lyricsManiaUrl(String input) {
    var result = input.replaceAll(' ', '_').toLowerCase();
    if (result.isNotEmpty && result.startsWith('_')) {
      result = result.substring(1);
    }
    if (result.isNotEmpty && result.endsWith('_')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  String _removeSpaces(String input) {
    return input.replaceAll(RegExp(' {2,}'), ' ');
  }

  String addCopyright(String input, String copyright) {
    return '$input\n\n© $copyright';
  }
}
