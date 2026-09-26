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

import 'package:file_picker/file_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart' show logger;
import 'package:catchify/services/artist_service.dart' show ytMusicClient;
import 'package:catchify/services/playlists_manager.dart';
import 'package:catchify/utilities/flutter_toast.dart';
import 'package:catchify/utilities/formatter.dart';
import 'package:catchify/utilities/url_launcher.dart';
import 'package:catchify/widgets/mini_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// A CSV row and its original position, used to preserve playlist order.
typedef _ImportRow = ({
  int index,
  String title,
  String artist,
  int? durationSeconds,
});

class ImportSpotifyPlaylistPage extends StatefulWidget {
  const ImportSpotifyPlaylistPage({super.key});

  @override
  State<ImportSpotifyPlaylistPage> createState() =>
      _ImportSpotifyPlaylistPageState();
}

class _ImportSpotifyPlaylistPageState extends State<ImportSpotifyPlaylistPage> {
  // Shared across page instances so navigating away and reopening the page
  // can't spawn a second import running concurrently with the first.
  static bool _importRunning = false;

  // Limit concurrency and leave a short pause between batches.
  static const _batchSize = 12;
  static const _batchPause = Duration(milliseconds: 150);

  final _csvController = TextEditingController();
  final _playlistNameController = TextEditingController();
  bool _isImporting = false;
  String? _fileName;
  int _processedCount = 0;
  int _totalCount = 0;

  @override
  void dispose() {
    _csvController.dispose();
    _playlistNameController.dispose();
    super.dispose();
  }

  Future<void> _chooseFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    final file = result.files.single;
    final path = file.path;
    if (path == null) return;
    _csvController.text = await File(path).readAsString();
    if (!mounted) return;
    setState(() => _fileName = file.name);
  }

  int? _parseDurationSeconds(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return null;
    if (clean.contains(':')) {
      final parts = clean.split(':');
      var s = 0;
      for (final p in parts) {
        final n = int.tryParse(p.trim());
        if (n == null) return null;
        s = s * 60 + n;
      }
      return s > 0 ? s : null;
    }
    final n = int.tryParse(clean) ?? double.tryParse(clean)?.round();
    if (n != null && n > 0) {
      if (n > 10000) {
        return (n / 1000).round();
      }
      return n;
    }
    return null;
  }

  Future<void> _importPlaylist() async {
    if (_isImporting) return;
    if (_importRunning) {
      showToast(context, context.l10n!.spotifyPlaylistAlreadyImporting);
      return;
    }
    final playlistName = _playlistNameController.text.trim();
    if (playlistName.isEmpty) {
      showToast(context, context.l10n!.enterPlaylistName);
      return;
    }
    final records = _parseCsv(_csvController.text);
    if (records.length < 2) {
      showToast(context, context.l10n!.spotifyPlaylistEmpty);
      return;
    }

    final headers = records.first
        .map((header) => header.replaceFirst('\ufeff', '').trim().toLowerCase())
        .toList();
    bool isNameColumn(String header) =>
        !header.contains('id') &&
        !header.contains('uri') &&
        !header.contains('url') &&
        !header.contains('genre');
    final songIndex = headers.indexWhere(
      (header) =>
          (header.contains('song') || header.contains('track')) &&
          isNameColumn(header),
    );
    final artistIndex = headers.indexWhere(
      (header) => header.contains('artist') && isNameColumn(header),
    );
    final durationIndex = headers.indexWhere(
      (header) =>
          (header.contains('duration') ||
              header.contains('length') ||
              header.contains('time')) &&
          !header.contains('time signature') &&
          !header.contains('added'),
    );
    if (songIndex == -1 || artistIndex == -1) {
      showToast(context, context.l10n!.spotifyPlaylistInvalid);
      return;
    }

    setState(() {
      _isImporting = true;
      _processedCount = 0;
      _totalCount = records.length - 1;
    });
    _importRunning = true;
    try {
      // Collect all rows with their original position in the CSV.
      final rows = <_ImportRow>[];
      for (var i = 1; i < records.length; i++) {
        final row = records[i];
        if (row.length <= songIndex || row.length <= artistIndex) continue;
        final song = row[songIndex].trim();
        final artist = row[artistIndex].trim();
        if (song.isEmpty) continue;
        final durationSeconds =
            (durationIndex != -1 && row.length > durationIndex)
            ? _parseDurationSeconds(row[durationIndex])
            : null;
        rows.add((
          index: i - 1,
          title: song,
          artist: artist,
          durationSeconds: durationSeconds,
        ));
      }

      // First pass: resolve the rows in batches.
      final firstPass = await _searchBatch(
        rows,
        onProgress: (done) {
          if (mounted) setState(() => _processedCount += done);
        },
      );

      final found = firstPass.found;
      var missing = firstPass.missing;

      // Second pass: single retry for anything missed, unless rate-limited.
      if (missing.isNotEmpty && !firstPass.rateLimited) {
        if (mounted) {
          setState(() => _totalCount = rows.length + missing.length);
        }
        final retryPass = await _searchBatch(
          missing,
          onProgress: (done) {
            if (mounted) setState(() => _processedCount += done);
          },
        );
        found.addAll(retryPass.found);
        missing = retryPass.missing;
      }

      // Reconstruct the playlist in original CSV order.
      final songs = (found.keys.toList()..sort())
          .map((index) => found[index]!)
          .toList();

      if (songs.isNotEmpty) {
        createCustomPlaylistWithSongs(
          playlistName,
          songs,
          image: songs.first['image'] as String?,
        );
      }

      final resultText = context.l10n!.spotifyPlaylistImportResult(
        songs.length,
        rows.length,
      );
      if (missing.isNotEmpty) {
        final missingText = missing
            .map((r) => r.artist.isEmpty ? r.title : '${r.title} - ${r.artist}')
            .join('\n');
        if (mounted) {
          showToast(
            context,
            '$resultText\n\n${context.l10n!.spotifyPlaylistMissingSongs}:\n$missingText',
            duration: const Duration(seconds: 8),
            icon: FluentIcons.warning_24_regular,
          );
        }
      } else if (mounted) {
        showToast(context, resultText);
      }
    } catch (e, st) {
      logger.log('Error importing Spotify playlist', error: e, stackTrace: st);
      if (mounted) {
        showToast(context, context.l10n!.error);
      }
    } finally {
      _importRunning = false;
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  /// Resolves [rows] in batches and stops when rate limiting is detected.
  /// Results are keyed by the rows' original positions for retry merging.
  Future<({Map<int, Map> found, List<_ImportRow> missing, bool rateLimited})>
  _searchBatch(
    List<_ImportRow> rows, {
    required void Function(int processedCount) onProgress,
  }) async {
    final found = <int, Map>{};
    final missing = <_ImportRow>[];
    for (var i = 0; i < rows.length; i += _batchSize) {
      final batch = rows.skip(i).take(_batchSize).toList();
      final batchResults = await Future.wait(
        batch.map((row) async {
          final (match, wasRateLimited) = await _findSongWithRetry(
            '${row.title} ${row.artist}',
            expectedArtist: row.artist,
            expectedTitle: row.title,
            expectedDurationSeconds: row.durationSeconds,
          );
          return (row, match, wasRateLimited);
        }),
      );
      var batchRateLimited = false;
      for (final (row, match, wasRateLimited) in batchResults) {
        if (wasRateLimited) batchRateLimited = true;
        if (match == null) {
          missing.add(row);
        } else {
          found[row.index] = match;
        }
      }
      onProgress(batchResults.length);
      if (batchRateLimited) {
        missing.addAll(rows.skip(i + _batchSize));
        return (found: found, missing: missing, rateLimited: true);
      }
      await Future.delayed(_batchPause);
    }
    return (found: found, missing: missing, rateLimited: false);
  }

  /// Returns the best match for [query], or `null` if none was found.
  /// The second value is `true` when YouTube is actively rate-limiting this
  /// device, so the caller can stop the whole import instead of retrying
  /// every remaining song for minutes on end.
  Future<(Map<String, dynamic>?, bool)> _findSongWithRetry(
    String query, {
    String? expectedArtist,
    String? expectedTitle,
    int? expectedDurationSeconds,
  }) async {
    const maxAttempts = 2;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final video = await ytMusicClient.music.searchSong(
          query,
          expectedArtist: expectedArtist,
          expectedTitle: expectedTitle,
          expectedDuration:
              expectedDurationSeconds != null && expectedDurationSeconds > 0
              ? Duration(seconds: expectedDurationSeconds)
              : null,
        );
        if (video == null) return (null, false);
        final songLayout = Map<String, dynamic>.from(
          returnSongLayout(0, video),
        );
        final vidDuration = video.duration?.inSeconds;
        if (vidDuration != null && vidDuration > 0) {
          songLayout['duration'] = vidDuration;
        } else if (expectedDurationSeconds != null &&
            expectedDurationSeconds > 0) {
          songLayout['duration'] = expectedDurationSeconds;
        }
        return (songLayout, false);
      } on RequestLimitExceededException {
        if (attempt == maxAttempts - 1) return (null, true);
        await Future.delayed(const Duration(seconds: 2));
      } catch (e, stackTrace) {
        if (attempt == maxAttempts - 1) {
          logger.log(
            'Error searching Spotify import match for "$query"',
            error: e,
            stackTrace: stackTrace,
          );
          return (null, false);
        }
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
    return (null, false);
  }

  List<List<String>> _parseCsv(String input) {
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var quoted = false;

    for (var index = 0; index < input.length; index++) {
      final character = input[index];
      if (character == '"') {
        if (quoted && index + 1 < input.length && input[index + 1] == '"') {
          field.write('"');
          index++;
        } else {
          quoted = !quoted;
        }
      } else if (character == ',' && !quoted) {
        row.add(field.toString());
        field = StringBuffer();
      } else if ((character == '\n' || character == '\r') && !quoted) {
        if (character == '\r' &&
            index + 1 < input.length &&
            input[index + 1] == '\n') {
          index++;
        }
        row.add(field.toString());
        field = StringBuffer();
        if (row.any((value) => value.trim().isNotEmpty)) rows.add(row);
        row = <String>[];
      } else {
        field.write(character);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      if (row.any((value) => value.trim().isNotEmpty)) rows.add(row);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n!.importSpotifyPlaylistTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n!.importSpotifyPlaylistInstructions),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => launchURL(
                Uri.parse('https://www.chosic.com/spotify-playlist-exporter/'),
              ),
              icon: const Icon(FluentIcons.open_24_regular),
              label: Text(context.l10n!.openChosicExporter),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isImporting ? null : _chooseFile,
              icon: const Icon(FluentIcons.document_add_24_regular),
              label: Text(_fileName ?? context.l10n!.chooseCsvFile),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _playlistNameController,
              enabled: !_isImporting,
              decoration: InputDecoration(
                labelText: '${context.l10n!.playlistName} *',
                hintText: context.l10n!.spotifyPlaylistNameHint,
                filled: true,
                fillColor: colorScheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _csvController,
              enabled: !_isImporting,
              minLines: 10,
              maxLines: 18,
              decoration: InputDecoration(
                labelText: context.l10n!.pasteCsv,
                hintText: context.l10n!.spotifyCsvHint,
                alignLabelWithHint: true,
                filled: true,
                fillColor: colorScheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isImporting ? null : _importPlaylist,
              icon: _isImporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(FluentIcons.arrow_upload_24_regular),
              label: Text(
                _isImporting
                    ? context.l10n!.spotifyPlaylistImporting
                    : context.l10n!.importPlaylist,
              ),
            ),
            if (_isImporting && _totalCount > 0) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _processedCount / _totalCount,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n!.spotifyPlaylistProgress(
                  _processedCount,
                  _totalCount,
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: MiniPlayer.playerHeight + 24),
          ],
        ),
      ),
    );
  }
}
