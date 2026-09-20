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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:catchify/extensions/l10n.dart';

class Logger {
  static const int _maxLogEntries = 500;
  final List<String> _logEntries = [];
  int _logCount = 0;

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

    // Check if stackTrace is not null, otherwise use an empty string
    final stackTraceMessage = stackTrace != null ? '$stackTrace' : '';

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
  }

  Future<String> copyLogs(BuildContext context) async {
    try {
      if (_logEntries.isNotEmpty) {
        await Clipboard.setData(
          ClipboardData(text: _logEntries.join('\n')),
        );
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
