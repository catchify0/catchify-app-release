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
 */

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:catchify/services/common_services.dart';
import 'package:catchify/services/download_manager.dart';
import 'package:catchify/services/io_service.dart';
import 'package:catchify/services/playlist_download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('catchify_download_test_');
    applicationDirPath = tempDir.path;
    await FilePaths.ensureDirectoriesExist();
    Hive.init(tempDir.path);
    await Hive.openBox('userNoBackup');
  });

  tearDownAll(() async {
    try {
      await Hive.close();
    } catch (_) {}
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() {
    userOfflineSongs.value = [];
    userLocalSongs.value = [];
  });

  group('DownloadStatus & Progress Info Tests', () {
    test(
      'DownloadStatus fromString parses valid values and falls back safely',
      () {
        expect(DownloadStatus.fromString('queued'), DownloadStatus.queued);
        expect(
          DownloadStatus.fromString('downloading'),
          DownloadStatus.downloading,
        );
        expect(
          DownloadStatus.fromString('completed'),
          DownloadStatus.completed,
        );
        expect(DownloadStatus.fromString('failed'), DownloadStatus.failed);
        expect(
          DownloadStatus.fromString('cancelled'),
          DownloadStatus.cancelled,
        );
        expect(DownloadStatus.fromString('deleting'), DownloadStatus.deleting);
        expect(DownloadStatus.fromString('missing'), DownloadStatus.missing);
        expect(
          DownloadStatus.fromString('unknown_value'),
          DownloadStatus.queued,
        );
        expect(DownloadStatus.fromString(null), DownloadStatus.queued);
      },
    );

    test('DownloadProgressInfo copyWith updates values properly', () {
      final info = DownloadProgressInfo(
        ytid: 'test_ytid',
        title: 'Test Song',
        status: DownloadStatus.queued,
      );

      expect(info.progress, 0.0);
      expect(info.bytesDownloaded, 0);

      final updated = info.copyWith(
        status: DownloadStatus.downloading,
        progress: 0.45,
        bytesDownloaded: 4500,
        totalBytes: 10000,
      );

      expect(updated.status, DownloadStatus.downloading);
      expect(updated.progress, 0.45);
      expect(updated.bytesDownloaded, 4500);
      expect(updated.totalBytes, 10000);
      expect(updated.ytid, 'test_ytid');
      expect(updated.title, 'Test Song');
    });
  });

  group('Canonical Download Metadata Preservation Tests', () {
    test(
      'buildCanonicalMetadata retains all required canonical and legacy fields',
      () {
        final inputSong = {
          'ytid': 'abc123xyz',
          'title': 'Illuminati',
          'artist': 'Sushin Shyam',
          'artistId': 'artist_sushin',
          'album': 'Aavesham',
          'image': 'https://example.com/cover.jpg',
          'highResImage': 'https://example.com/cover_hq.jpg',
          'lowResImage': 'https://example.com/cover_lq.jpg',
          'duration': 214,
        };

        final canonical = DownloadManager.buildCanonicalMetadata(
          song: inputSong,
          ytid: 'abc123xyz',
          localPath: '/local/path/tracks/abc123xyz.m4a',
          artworkPath: '/local/path/artworks/abc123xyz.jpg',
          fileSize: 4194304,
          duration: 214,
          status: DownloadStatus.completed,
        );

        expect(canonical['ytid'], 'abc123xyz');
        expect(canonical['id'], 'abc123xyz');
        expect(canonical['title'], 'Illuminati');
        expect(canonical['artist'], 'Sushin Shyam');
        expect(canonical['artistId'], 'artist_sushin');
        expect(canonical['album'], 'Aavesham');
        expect(canonical['duration'], 214);
        expect(canonical['localPath'], '/local/path/tracks/abc123xyz.m4a');
        expect(canonical['audioPath'], '/local/path/tracks/abc123xyz.m4a');
        expect(canonical['artworkPath'], '/local/path/artworks/abc123xyz.jpg');
        expect(canonical['fileSize'], 4194304);
        expect(canonical['status'], 'completed');
        expect(canonical['isLive'], false);
        expect(canonical['downloadedAt'], isNotNull);
        expect(canonical['dateAdded'], isNotNull);
      },
    );
  });

  group('Storage Integrity & Missing File Reconciliation Tests', () {
    test(
      'reconcileStorageIntegrity marks missing tracks when files are absent',
      () async {
        final validYtid = 'valid_song_1';
        final validFilePath = FilePaths.getAudioPath(validYtid);
        final validFile = File(validFilePath);
        await validFile.writeAsString('mock audio content');

        final missingYtid = 'missing_song_2';

        userOfflineSongs.value = [
          {'ytid': validYtid, 'title': 'Valid Song', 'status': 'queued'},
          {'ytid': missingYtid, 'title': 'Missing Song', 'status': 'completed'},
        ];

        await DownloadManager.instance.reconcileStorageIntegrity();

        final result = userOfflineSongs.value;
        expect(result.length, 2);

        final validResult = result.firstWhere((s) => s['ytid'] == validYtid);
        expect(validResult['status'], DownloadStatus.completed.name);
        expect(validResult['fileSize'], greaterThan(0));

        final missingResult = result.firstWhere(
          (s) => s['ytid'] == missingYtid,
        );
        expect(missingResult['status'], DownloadStatus.missing.name);
      },
    );

    test(
      'isSongAlreadyOffline verifies actual file existence on disk',
      () async {
        final ytid = 'offline_verify_song';
        final filePath = FilePaths.getAudioPath(ytid);
        final file = File(filePath);

        userOfflineSongs.value = [
          {
            'ytid': ytid,
            'title': 'Offline Verify Song',
            'audioPath': filePath,
            'status': 'completed',
          },
        ];

        // File does not exist yet
        expect(isSongAlreadyOffline(ytid), isFalse);

        // Create file on disk
        await file.writeAsString('audio bytes');
        expect(isSongAlreadyOffline(ytid), isTrue);

        // Delete file
        await file.delete();
        expect(isSongAlreadyOffline(ytid), isFalse);
      },
    );
  });

  group('Storage Accounting Tests', () {
    test('StorageAccounting formats byte sizes accurately', () {
      const zeroAccounting = StorageAccounting(
        downloadedSongsCount: 0,
        totalFilesCount: 0,
        totalStorageBytes: 0,
      );
      expect(zeroAccounting.formattedStorageSize, '0.0 MB');

      const mbAccounting = StorageAccounting(
        downloadedSongsCount: 3,
        totalFilesCount: 6,
        totalStorageBytes: 25 * 1024 * 1024,
      );
      expect(mbAccounting.formattedStorageSize, '25.0 MB');

      final gbAccounting = StorageAccounting(
        downloadedSongsCount: 150,
        totalFilesCount: 300,
        totalStorageBytes: (1.45 * 1024 * 1024 * 1024).toInt(),
      );
      expect(gbAccounting.formattedStorageSize, '1.45 GB');
    });

    test('getStorageAccounting calculates files and bytes from disk', () async {
      final testAudio = File(
        '${applicationDirPath}/${FilePaths.tracksDir}/test_song.m4a',
      );
      await testAudio.writeAsBytes(List.filled(1024 * 100, 1)); // 100 KB

      final testArtwork = File(
        '${applicationDirPath}/${FilePaths.artworksDir}/test_song.jpg',
      );
      await testArtwork.writeAsBytes(List.filled(1024 * 20, 2)); // 20 KB

      final accounting = await DownloadManager.instance.getStorageAccounting();

      expect(accounting.totalFilesCount, greaterThanOrEqualTo(2));
      expect(accounting.totalStorageBytes, greaterThanOrEqualTo(120 * 1024));

      // Cleanup
      if (await testAudio.exists()) await testAudio.delete();
      if (await testArtwork.exists()) await testArtwork.delete();
    });
  });

  group('Playlist Download Progress Aggregation Tests', () {
    test('DownloadProgress aggregates progress accurately', () {
      final progress = DownloadProgress(total: 10);
      expect(progress.progress, 0.0);
      expect(progress.isCancelled, isFalse);

      progress.completed = 3;
      expect(progress.progress, 0.3);
      expect(progress.toString(), '30.0% (3/10)');

      progress.failed = 2;
      expect(progress.progress, 0.5);
      expect(progress.toString(), '50.0% (3/10)');

      progress.completed = 8;
      // 8 completed + 2 failed = 10 total
      expect(progress.progress, 1.0);
    });

    test('buildCanonicalMetadata coerces String and double durations safely', () {
      final songWithStringDuration = {
        'ytid': 'duration_str_test',
        'title': 'Duration Test',
        'duration': '195',
      };

      final canonical = DownloadManager.buildCanonicalMetadata(
        song: songWithStringDuration,
        ytid: 'duration_str_test',
        localPath: '/local/test.m4a',
        fileSize: 1024,
        status: DownloadStatus.completed,
      );

      expect(canonical['duration'], 195);
      expect(canonical['duration'], isA<int>());
    });

    test('reconcileStorageIntegrity deduplicates duplicate ytid entries', () async {
      final audioFile = File(FilePaths.getAudioPath('dedup_song'));
      await audioFile.writeAsBytes([1, 2, 3, 4]);

      userOfflineSongs.value = [
        {
          'ytid': 'dedup_song',
          'title': 'Dedup Song Copy 1',
          'audioPath': audioFile.path,
        },
        {
          'ytid': 'dedup_song',
          'title': 'Dedup Song Copy 2',
          'audioPath': audioFile.path,
        },
      ];

      await DownloadManager.instance.reconcileStorageIntegrity();

      expect(userOfflineSongs.value.length, 1);
      expect(userOfflineSongs.value.first['ytid'], 'dedup_song');

      if (await audioFile.exists()) await audioFile.delete();
    });

    test('isPlaylistFullyOffline detects missing disk tracks accurately', () async {
      final presentAudio = File(FilePaths.getAudioPath('present_song'));
      await presentAudio.writeAsBytes([1, 2, 3]);

      userOfflineSongs.value = [
        {
          'ytid': 'present_song',
          'audioPath': presentAudio.path,
          'status': DownloadStatus.completed.name,
        },
        {
          'ytid': 'absent_song',
          'audioPath': FilePaths.getAudioPath('absent_song'),
          'status': DownloadStatus.missing.name,
        },
      ];

      final playlistWithMissing = [
        {'ytid': 'present_song'},
        {'ytid': 'absent_song'},
      ];

      expect(isPlaylistFullyOffline(playlistWithMissing), isFalse);

      final playlistAllPresent = [
        {'ytid': 'present_song'},
      ];

      expect(isPlaylistFullyOffline(playlistAllPresent), isTrue);

      if (await presentAudio.exists()) await presentAudio.delete();
    });
  });
}
