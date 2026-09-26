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

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:path_provider/path_provider.dart';

bool isNetworkError(dynamic error) {
  if (error == null) return false;
  if (error is SocketException ||
      error is HttpException ||
      error is TimeoutException ||
      error is HandshakeException ||
      error is TlsException) {
    return true;
  }
  if (error is PlatformException &&
      (error.code == '-1009' ||
          (error.message?.toLowerCase().contains('offline') ?? false))) {
    return true;
  }
  final str = error.toString().toLowerCase();
  return str.contains('-1009') ||
      str.contains('offline') ||
      str.contains('failed host lookup') ||
      str.contains('socketexception') ||
      str.contains('network is unreachable') ||
      str.contains('connection refused') ||
      str.contains('connection reset') ||
      str.contains('connection closed') ||
      str.contains('connection abort') ||
      str.contains('timed out') ||
      str.contains('handshakeexception') ||
      str.contains('tlsexception') ||
      str.contains('nodename nor servname provided') ||
      str.contains('no route to host') ||
      str.contains('clientexception with socketexception');
}

class Logger {
  static const int _maxLogEntries = 500;
  static const int _maxLogFileBytes = 1024 * 1024;
  final List<String> _logEntries = [];
  int _logCount = 0;
  File? _logFile;
  Future<void> _writeQueue = Future<void>.value();

  static final RegExp _sanitizationRegex = RegExp(
    r'(authorization:\s*[^\s]+|bearer\s+[a-zA-Z0-9_\-\.]+|cookie:\s*[^;\n]+|token=[a-zA-Z0-9_\-]+|password=[^\s&]+)',
    caseSensitive: false,
  );

  static String _sanitize(String text) {
    if (text.isEmpty) return text;
    var sanitized = text.replaceAllMapped(
      _sanitizationRegex,
      (m) => '[REDACTED]',
    );
    if (sanitized.length > 2000) {
      sanitized = '${sanitized.substring(0, 2000)}... [TRUNCATED]';
    }
    return sanitized;
  }

  void log(String errorLocation, {Object? error, StackTrace? stackTrace}) {
    final timestamp = DateTime.now().toString();

    // Check if error is not null, otherwise use an empty string
    final errorMessage = error != null ? ' ${_sanitize(error.toString())}' : '';

    final isNetErr = isNetworkError(error) || isNetworkError(errorLocation);

    // Suppress heavy stack traces for expected network/offline errors to avoid dumping AOT snapshot crash-like markers
    final stackTraceMessage = (stackTrace != null && !isNetErr)
        ? '$stackTrace'
        : '';

    final cleanLocation = _sanitize(errorLocation);
    final logMessage = stackTraceMessage.isNotEmpty
        ? '[$timestamp] $cleanLocation:$errorMessage\n$stackTraceMessage'
        : '[$timestamp] $cleanLocation$errorMessage';

    if (kDebugMode) {
      debugPrint(logMessage);
    }
    _logEntries.add(logMessage);
    if (_logEntries.length > _maxLogEntries) {
      _logEntries.removeAt(0);
    }
    _logCount++;

    final file = _logFile;
    if (file != null) {
      _writeQueue = _writeQueue
          .then(
            (_) => file.writeAsString('$logMessage\n', mode: FileMode.append),
          )
          .then((_) => _trimLogFile(file))
          .catchError((Object writeError, StackTrace writeStack) {
            if (kDebugMode) {
              debugPrint('[LOGGER_WRITE_ERROR] $writeError\n$writeStack');
            }
          });
    }
  }

  Future<void> initialize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}catchify.log',
      );
      await file.parent.create(recursive: true);
      _logFile = file;

      if (await file.exists()) {
        final existing = await file.readAsLines();
        _logEntries
          ..clear()
          ..addAll(
            existing.length > _maxLogEntries
                ? existing.sublist(existing.length - _maxLogEntries)
                : existing,
          );
        _logCount = _logEntries.length;
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[LOGGER_INIT_ERROR] $error\n$stackTrace');
      }
    }
  }

  Future<void> _trimLogFile(File file) async {
    if (!await file.exists()) return;
    final length = await file.length();
    if (length <= _maxLogFileBytes) return;

    final lines = await file.readAsLines();
    final retained = <String>[];
    var retainedBytes = 0;
    for (final line in lines.reversed) {
      final lineBytes = line.length + 1;
      if (retainedBytes + lineBytes > _maxLogFileBytes) break;
      retained.add(line);
      retainedBytes += lineBytes;
    }
    await file.writeAsString(retained.reversed.join('\n'));
    if (retained.isNotEmpty) {
      await file.writeAsString('\n', mode: FileMode.append);
    }
  }

  Future<String> copyLogs(BuildContext context) async {
    try {
      await _writeQueue;
      var logs = _logEntries.join('\n');
      final file = _logFile;
      if (file != null && await file.exists()) {
        logs = await file.readAsString();
      }

      if (logs.trim().isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: logs));
        if (!context.mounted) return '';
        return '${context.l10n!.copyLogsSuccess}.';
      } else {
        return '${context.l10n!.copyLogsNoLogs}.';
      }
    } catch (e, stackTrace) {
      log('Error copying logs', error: e, stackTrace: stackTrace);
      return 'Error: $e';
    }
  }

  int getLogCount() {
    return _logCount;
  }
}
