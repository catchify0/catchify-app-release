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
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart' show logger;
import 'package:catchify/services/artwork_service.dart';

// Cache durations for different types of data
const Duration songCacheDuration = Duration(hours: 1, minutes: 30);
const Duration playlistCacheDuration = Duration(hours: 5);
const Duration searchCacheDuration = Duration(days: 4);
const Duration homeFeedCacheDuration = Duration(hours: 1);
const Duration defaultCacheDuration = Duration(days: 7);

// In-memory cache for frequently accessed items
final _memoryCache = <String, _CacheEntry>{};

class _CacheEntry {
  _CacheEntry(this.data, this.timestamp);
  final dynamic data;
  final DateTime timestamp;

  bool isValid(Duration cacheDuration) {
    return DateTime.now().difference(timestamp) < cacheDuration;
  }
}

// Maximum number of entries allowed in the memory cache
const int _maxMemoryCacheSize = 500;
const int _memoryCacheTrimSize = 100;

void _setMemoryCacheEntry(String key, _CacheEntry entry) {
  _memoryCache
    ..remove(key)
    ..[key] = entry;
  _trimMemoryCacheIfNeeded();
}

void _touchMemoryCacheEntry(String key) {
  final entry = _memoryCache.remove(key);
  if (entry != null) {
    _memoryCache[key] = entry;
  }
}

void _trimMemoryCacheIfNeeded() {
  if (_memoryCache.length > _maxMemoryCacheSize) {
    final keysToRemove = _memoryCache.keys.take(_memoryCacheTrimSize).toList();
    for (final key in keysToRemove) {
      _memoryCache.remove(key);
    }
  }
}

Future<void> addOrUpdateData<T>(String category, String key, T value) async {
  final _box = await _openBox(category);
  await _box.put(key, value);

  if (category == 'cache') {
    await _box.put('${key}_date', DateTime.now());

    // Update memory cache too
    final cacheKey = '${category}_$key';
    _setMemoryCacheEntry(cacheKey, _CacheEntry(value, DateTime.now()));
  }
}

Future<dynamic> getData(
  String category,
  String key, {
  dynamic defaultValue,
  Duration? cachingDuration,
  bool allowExpired = false,
}) async {
  // Set appropriate cache duration based on key
  cachingDuration ??= _getCacheDurationForKey(key);

  // Check memory cache first
  final cacheKey = '${category}_$key';
  final memCacheEntry = _memoryCache[cacheKey];
  if (memCacheEntry != null && memCacheEntry.isValid(cachingDuration)) {
    _touchMemoryCacheEntry(cacheKey);
    return memCacheEntry.data;
  }
  _trimMemoryCacheIfNeeded();

  final _box = await _openBox(category);
  if (category == 'cache') {
    final cacheIsValid = isCacheValid(_box, key, cachingDuration);
    final hasTimestamp = _box.get('${key}_date') is DateTime;
    if (!hasTimestamp || (!cacheIsValid && !allowExpired)) {
      await deleteData(category, key);
      await deleteData(category, '${key}_date');
      return defaultValue;
    }
  }

  final data = await _box.get(key, defaultValue: defaultValue);

  // Store in memory cache for faster access next time
  if (data != null && category == 'cache') {
    final rawTimestamp = await _box.get('${key}_date');
    final timestamp = rawTimestamp is DateTime ? rawTimestamp : DateTime.now();
    _setMemoryCacheEntry(cacheKey, _CacheEntry(data, timestamp));
  }

  return data;
}

Future<void> deleteData(String category, String key) async {
  _memoryCache
    ..remove('${category}_$key')
    ..remove('${category}_${key}_date');

  final _box = await _openBox(category);
  await _box.delete(key);
}

Future<bool> clearCache() async {
  try {
    // Clear memory cache
    _memoryCache.clear();

    final cacheBox = await _openBox('cache');
    await cacheBox.clear();
    return true;
  } catch (e, stackTrace) {
    logger.log('Failed to clear cache', error: e, stackTrace: stackTrace);
    return false;
  }
}

// Clean up old cache entries to prevent excessive storage usage
Future<void> cleanupOldCacheEntries() async {
  try {
    final cacheBox = await _openBox('cache');
    final now = DateTime.now();

    // Get all keys except the ones with _date suffix
    final keys = cacheBox.keys
        .where((k) => !k.toString().endsWith('_date'))
        .toList();

    for (final key in keys) {
      final dateKey = '${key}_date';
      final date = cacheBox.get(dateKey);

      if (date == null) {
        await cacheBox.delete(key);
        continue;
      }

      if (date is! DateTime) {
        await cacheBox.delete(key);
        await cacheBox.delete(dateKey);
        continue;
      }

      final age = now.difference(date);
      // Very old cache entries (older than 30 days) should be removed
      if (age > const Duration(days: 30)) {
        await cacheBox.delete(key);
        await cacheBox.delete(dateKey);
      }
    }
  } catch (e, stackTrace) {
    logger.log(
      'Error cleaning up old cache entries',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

// Check if the cache is still valid based on the caching duration
bool isCacheValid(Box box, String key, Duration cachingDuration) {
  final date = box.get('${key}_date');
  if (date is! DateTime) {
    return false;
  }
  final age = DateTime.now().difference(date);
  return age < cachingDuration;
}

Duration _getCacheDurationForKey(String key) {
  if (key.startsWith('song_') || key.contains('manifest_')) {
    return songCacheDuration;
  } else if (key.startsWith('playlist_') || key.contains('playlistSongs')) {
    return playlistCacheDuration;
  } else if (key.startsWith('search_')) {
    return searchCacheDuration;
  } else if (key.startsWith('dynamic_home_') || key.startsWith('ytm_home_')) {
    return homeFeedCacheDuration;
  }
  return defaultCacheDuration;
}

Future<Box> _openBox(String category) async {
  if (Hive.isBoxOpen(category)) {
    return Hive.box(category);
  } else {
    return Hive.openBox(category);
  }
}

Future<({String message, bool success})> backupData(
  BuildContext context,
) async {
  final boxNames = ['user', 'settings'];
  final dlPath = await FilePicker.getDirectoryPath();

  if (dlPath == null) {
    return (message: '${context.l10n!.chooseBackupDir}!', success: false);
  }

  if (Platform.isAndroid) {
    final dlPathLower = dlPath.toLowerCase();
    if (!dlPathLower.contains('documents') &&
        !dlPathLower.contains('download')) {
      return (message: context.l10n!.folderRestrictions, success: false);
    }
  }

  try {
    for (final boxName in boxNames) {
      final box = await _openBox(boxName);

      if (box.path == null) {
        logger.log('Box path is null for $boxName');
        continue;
      }

      final sourceFile = File(box.path!);
      final targetFile = File('$dlPath/$boxName.hive');

      // Ensure the target directory exists
      await targetFile.parent.create(recursive: true);

      // Safely handle existing backup file
      if (await targetFile.exists()) {
        try {
          await targetFile.delete();
        } catch (e) {
          // If delete fails, try with a timestamp suffix
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final newTargetFile = File('$dlPath/${boxName}_$timestamp.hive');
          await sourceFile.copy(newTargetFile.path);
          continue;
        }
      }

      // Compact the box before copying
      try {
        await box.compact();
      } catch (e, stackTrace) {
        logger.log(
          'Failed to compact box $boxName',
          error: e,
          stackTrace: stackTrace,
        );
      }

      // Copy the box file to backup location
      if (await sourceFile.exists()) {
        await sourceFile.copy(targetFile.path);
      } else {
        logger.log(
          'Source file does not exist for $boxName at ${sourceFile.path}',
        );
      }
    }

    return (message: '${context.l10n!.backedupSuccess}!', success: true);
  } catch (e, stackTrace) {
    logger.log('Backup error', error: e, stackTrace: stackTrace);
    return (message: '${context.l10n!.backupError}: $e', success: false);
  }
}

Future<({String message, bool success})> restoreData(
  BuildContext context,
) async {
  final boxNames = ['user', 'settings'];
  final result = await FilePicker.pickFiles(
    allowMultiple: true,
    type: Platform.isIOS ? FileType.any : FileType.custom,
    allowedExtensions: Platform.isIOS ? null : ['hive'],
  );

  if (result == null || result.files.isEmpty) {
    return (message: '${context.l10n!.chooseBackupFiles}!', success: false);
  }
  const maxBackupBytes = 50 * 1024 * 1024;

  final selectedFiles = <String, PlatformFile>{};
  for (final boxName in boxNames) {
    final backupFile = result.files
        .where(
          (file) =>
              file.name == '$boxName.hive' ||
              file.name.startsWith('${boxName}_'),
        )
        .firstOrNull;
    if (backupFile == null) {
      return (
        message: '${context.l10n!.chooseBackupFiles} ($boxName.hive)!',
        success: false,
      );
    }
    selectedFiles[boxName] = backupFile;
  }

  final boxPaths = <String, String>{};
  for (final boxName in boxNames) {
    final box = Hive.isBoxOpen(boxName)
        ? Hive.box(boxName)
        : await _openBox(boxName);
    final path = box.path;
    if (path == null) {
      return (message: context.l10n!.restoreError, success: false);
    }
    boxPaths[boxName] = path;
  }

  final backupBytes = <String, List<int>>{};
  final originalBytes = <String, List<int>>{};
  for (final boxName in boxNames) {
    final bytes = await _readPickedFile(selectedFiles[boxName]!);
    if (bytes.length > maxBackupBytes) {
      return (message: context.l10n!.restoreError, success: false);
    }
    backupBytes[boxName] = bytes;
    originalBytes[boxName] = await File(boxPaths[boxName]!).readAsBytes();
  }

  final restoredBoxes = <String>[];
  try {
    for (final boxName in boxNames) {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).close();
      }
    }

    for (final boxName in boxNames) {
      await _validateHiveBytes(boxName, backupBytes[boxName]!);
    }

    for (final boxName in boxNames) {
      await _replaceHiveFile(boxPaths[boxName]!, backupBytes[boxName]!);
      restoredBoxes.add(boxName);
      logger.log('Restored $boxName');
    }

    return (message: '${context.l10n!.restoredSuccess}!', success: true);
  } catch (e, stackTrace) {
    logger.log('Restore error', error: e, stackTrace: stackTrace);
    for (final boxName in restoredBoxes.reversed) {
      try {
        await _replaceHiveFile(boxPaths[boxName]!, originalBytes[boxName]!);
      } catch (rollbackError, rollbackStackTrace) {
        logger.log(
          'Failed to roll back $boxName after restore error',
          error: rollbackError,
          stackTrace: rollbackStackTrace,
        );
      }
    }
    return (message: '${context.l10n!.restoreError}: $e', success: false);
  } finally {
    for (final boxName in boxNames) {
      try {
        await _openBox(boxName);
      } catch (e, stackTrace) {
        logger.log(
          'Failed to reopen box $boxName',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }
}

Future<List<int>> _readPickedFile(PlatformFile file) async {
  if (file.bytes != null) return file.bytes!;
  if (file.path != null) return File(file.path!).readAsBytes();
  throw StateError('Cannot read picked file: ${file.name}');
}

Future<void> _validateHiveBytes(String boxName, List<int> bytes) async {
  final validationDirectory = await Directory.systemTemp.createTemp(
    'catchify_restore_',
  );
  try {
    final validationFile = File('${validationDirectory.path}/$boxName.hive');
    await validationFile.writeAsBytes(bytes, flush: true);
    final box = await Hive.openBox(boxName, path: validationDirectory.path);
    await box.close();
  } finally {
    await validationDirectory.delete(recursive: true);
  }
}

Future<void> _replaceHiveFile(String targetPath, List<int> bytes) async {
  final targetFile = File(targetPath);
  final temporaryFile = File('$targetPath.restore.tmp');
  final backupFile = File('$targetPath.restore.bak');

  await temporaryFile.writeAsBytes(bytes, flush: true);
  if (await backupFile.exists()) await backupFile.delete();

  try {
    if (await targetFile.exists()) await targetFile.rename(backupFile.path);
    await temporaryFile.rename(targetPath);
    if (await backupFile.exists()) await backupFile.delete();
  } catch (_) {
    if (await temporaryFile.exists()) await temporaryFile.delete();
    if (!await targetFile.exists() && await backupFile.exists()) {
      await backupFile.rename(targetPath);
    }
    rethrow;
  }
}

/// Cleans expired keys from the 'cache' box to prevent disk bloat.
Future<void> pruneExpiredCacheEntries() async {
  if (!Hive.isBoxOpen('cache')) return;
  try {
    final box = Hive.box('cache');
    final keys = box.keys.toList();
    final now = DateTime.now();
    final toDelete = <dynamic>[];

    for (final key in keys) {
      if (key is String && !key.endsWith('_date')) {
        final dateKey = '${key}_date';
        final rawDate = box.get(dateKey);
        if (rawDate is DateTime) {
          final maxAge = _getCacheDurationForKey(key);
          if (now.difference(rawDate) > maxAge) {
            toDelete
              ..add(key)
              ..add(dateKey);
          }
        }
      }
    }

    if (toDelete.isNotEmpty) {
      await box.deleteAll(toDelete);
      logger.log(
        'Pruned ${toDelete.length ~/ 2} expired entries from cache box',
      );
    }
  } catch (e, st) {
    logger.log(
      'Error during pruneExpiredCacheEntries',
      error: e,
      stackTrace: st,
    );
  }
}

/// Compacts all open Hive boxes asynchronously to recover disk space and defragment database files.
Future<void> compactAllBoxes() async {
  await pruneExpiredCacheEntries();
  await ArtworkService.instance.pruneOldArtworkCache();

  const boxNames = ['user', 'settings', 'cache', 'userNoBackup'];
  for (final name in boxNames) {
    if (Hive.isBoxOpen(name)) {
      try {
        final box = Hive.box(name);
        await box.compact();
      } catch (e, st) {
        logger.log('Failed to compact box $name', error: e, stackTrace: st);
      }
    }
  }
}
