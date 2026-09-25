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
import 'dart:ffi';
import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:catchify/constants/version.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/main.dart';
import 'package:catchify/services/data_manager.dart';
import 'package:catchify/services/router_service.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/flutter_toast.dart';
import 'package:catchify/utilities/url_launcher.dart';
import 'package:catchify/widgets/auto_format_text.dart';

const String checkUrl =
    'https://raw.githubusercontent.com/catchify0/catchify0.github.io/main/check.json';
const String releasesUrl =
    'https://api.github.com/repos/catchify0/catchify0.github.io/releases/latest';
const String downloadUrlKey = 'url';
const String downloadUrlArm64Key = 'arm64url';

String? _extractIpaUrl(
  Map<String, dynamic> releasesResponse,
  Map<String, dynamic> checkMap,
) {
  final assets = releasesResponse['assets'];
  if (assets is List) {
    for (final asset in assets) {
      if (asset is Map<String, dynamic>) {
        final name = asset['name']?.toString().toLowerCase() ?? '';
        if (name.endsWith('.ipa')) {
          final url = asset['browser_download_url']?.toString();
          if (url != null && url.isNotEmpty) return url;
        }
      }
    }
  }
  final ipa = checkMap['ipaUrl']?.toString();
  if (ipa != null && ipa.isNotEmpty) return ipa;
  return null;
}

Future<void> checkAppUpdates({bool manual = false}) async {
  try {
    final response = await http.get(Uri.parse(checkUrl));

    if (response.statusCode != 200) {
      logger.log(
        'Fetch update API (checkUrl) call returned status code ${response.statusCode}',
      );
      if (manual) {
        showToast(
          NavigationManager().context,
          'Unable to check for updates right now',
        );
      }
      return;
    }

    final map = json.decode(response.body) as Map<String, dynamic>;
    announcementURL.value = map['announcementurl'];
    final latestVersion = map['version']?.toString() ?? '';
    if (latestVersion.isEmpty) {
      if (manual) {
        showToast(
          NavigationManager().context,
          'Catchify is up to date (v$appVersion)',
        );
      }
      return;
    }

    if (!isLatestVersionHigher(appVersion, latestVersion)) {
      if (manual) {
        showToast(
          NavigationManager().context,
          'Catchify is up to date (v$appVersion)',
        );
      }
      return;
    }

    final releasesRequest = await http.get(Uri.parse(releasesUrl));

    if (releasesRequest.statusCode != 200) {
      logger.log(
        'Fetch update API (releasesUrl) call returned status code ${releasesRequest.statusCode}',
      );
      if (manual) {
        showToast(
          NavigationManager().context,
          'An update is available (v$latestVersion)',
        );
      }
      return;
    }

    final releasesResponse =
        json.decode(releasesRequest.body) as Map<String, dynamic>;

    await showDialog(
      context: NavigationManager().context,
      builder: (BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;

        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  FluentIcons.arrow_download_24_regular,
                  color: colorScheme.onPrimaryContainer,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n!.appUpdateIsAvailable,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'V$latestVersion',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height / 2.5,
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SingleChildScrollView(
                  child: AutoFormatText(
                    text: releasesResponse['body'] as String? ?? '',
                  ),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colorScheme.outline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(context.l10n!.cancel),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  if (Platform.isIOS) {
                    final ipaUrl = _extractIpaUrl(releasesResponse, map);
                    final releaseHtmlUrl =
                        releasesResponse['html_url']?.toString() ??
                        'https://github.com/catchify0/catchify0.github.io/releases/latest';
                    await launchURL(Uri.parse(ipaUrl ?? releaseHtmlUrl));
                    return;
                  }
                  final url = await getDownloadUrl(map);
                  await launchURL(Uri.parse(url));
                } catch (e, stackTrace) {
                  logger.log(
                    'Error launching update download',
                    error: e,
                    stackTrace: stackTrace,
                  );
                }
              },
              icon: const Icon(FluentIcons.arrow_download_20_regular),
              label: Text(context.l10n!.download),
            ),
          ],
        );
      },
    );
  } catch (e, stackTrace) {
    logger.log('Error in checkAppUpdates', error: e, stackTrace: stackTrace);
  }
}

/// Fetch only the announcement URL from the `check.json` file and set the
/// global `announcementURL` ValueNotifier. This does not trigger releases
/// fetching or any update dialogs/downloads and is safe to call for F‑Droid
/// builds where update prompts are not allowed.
Future<void> fetchAnnouncementOnly() async {
  try {
    final response = await http.get(Uri.parse(checkUrl));

    if (response.statusCode != 200) {
      logger.log(
        'Fetch announcement (checkUrl) call returned status code ${response.statusCode}',
      );
      return;
    }

    final map = json.decode(response.body) as Map<String, dynamic>;
    final ann = map['announcementurl'];
    if (ann != null) {
      announcementURL.value = ann.toString();
    }
  } catch (e, stackTrace) {
    logger.log(
      'Error in fetchAnnouncementOnly',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

bool isLatestVersionHigher(String appVersion, String latestVersion) {
  final parsedAppVersion = appVersion.split('.');
  final parsedAppLatestVersion = latestVersion.split('.');
  final length = parsedAppVersion.length > parsedAppLatestVersion.length
      ? parsedAppVersion.length
      : parsedAppLatestVersion.length;
  for (var i = 0; i < length; i++) {
    final value1 = i < parsedAppVersion.length
        ? int.tryParse(parsedAppVersion[i]) ?? 0
        : 0;
    final value2 = i < parsedAppLatestVersion.length
        ? int.tryParse(parsedAppLatestVersion[i]) ?? 0
        : 0;
    if (value2 > value1) {
      return true;
    } else if (value2 < value1) {
      return false;
    }
  }

  return false;
}

Future<String> getCPUArchitecture() async {
  // On Android, Process.run('uname') is unavailable — the OS provides no shell.
  // dart:ffi's Abi.current() is a built-in zero-dependency way to read the
  // native ABI at runtime on every platform Flutter supports.
  if (Platform.isAndroid) {
    final abi = Abi.current()
        .toString(); // e.g. 'androidArm64', 'androidArm', 'androidX64'
    return abi.contains('Arm64') ? 'aarch64' : abi;
  }
  // Desktop/Linux fallback — keep using uname.
  try {
    final info = await Process.run('uname', ['-m']);
    return info.stdout.toString().trim();
  } catch (_) {
    return '';
  }
}

Future<String> getDownloadUrl(Map<String, dynamic> map) async {
  final cpuArchitecture = await getCPUArchitecture();
  final url = cpuArchitecture == 'aarch64'
      ? map[downloadUrlArm64Key]?.toString()
      : map[downloadUrlKey]?.toString();
  if (url == null || url.isEmpty) {
    throw Exception('Download URL not found in update manifest');
  }
  return url;
}

void showUpdateCheckDialog(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        icon: Icon(
          FluentIcons.arrow_sync_circle_24_regular,
          color: colorScheme.primary,
          size: 40,
        ),
        title: Text(
          context.l10n!.checkForUpdates,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          context.l10n!.enableUpdateChecksDescription,
          style: TextStyle(color: colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () {
              shouldWeCheckUpdates.value = false;
              addOrUpdateData<bool>('settings', 'shouldWeCheckUpdates', false);
              Navigator.of(context).pop();
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: colorScheme.outline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(context.l10n!.no),
          ),
          FilledButton(
            onPressed: () {
              shouldWeCheckUpdates.value = true;
              addOrUpdateData<bool>('settings', 'shouldWeCheckUpdates', true);
              if (!isFdroidBuild && kReleaseMode && !offlineMode.value) {
                checkAppUpdates();
                isUpdateChecked = true;
              }
              Navigator.of(context).pop();
            },
            child: Text(context.l10n!.yes),
          ),
        ],
      );
    },
  );
}
