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

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:catchify/main.dart' show logger;
import 'package:catchify/models/proxy_model.dart';
import 'package:catchify/screens/playlist_page.dart';
import 'package:catchify/screens/user_songs_page.dart';
import 'package:catchify/utilities/language_utils.dart';

const _defaultAccentColor = 0xFF9948EF;

dynamic _settingValue(String key, dynamic defaultValue) {
  return Hive.box('settings').get(key, defaultValue: defaultValue);
}

bool _readBoolSetting(String key, bool defaultValue) {
  final value = _settingValue(key, defaultValue);
  return value is bool ? value : defaultValue;
}

bool? _readNullableBoolSetting(String key) {
  final value = _settingValue(key, null);
  return value is bool ? value : null;
}

int _readIntSetting(String key, int defaultValue) {
  final value = _settingValue(key, defaultValue);
  return value is int ? value : defaultValue;
}

String? _readNullableStringSetting(String key) {
  final value = _settingValue(key, null);
  return value is String ? value : null;
}

String _readStringSetting(String key, String defaultValue) {
  final value = _settingValue(key, defaultValue);
  return value is String && value.isNotEmpty ? value : defaultValue;
}

AudioServiceRepeatMode _readRepeatModeSetting() {
  final index = _readIntSetting('repeatMode', 0);
  if (index < 0 || index >= AudioServiceRepeatMode.values.length) {
    return AudioServiceRepeatMode.none;
  }
  return AudioServiceRepeatMode.values[index];
}

Color _readAccentColorSetting() {
  final value = _settingValue('accentColor', _defaultAccentColor);
  return value is int ? Color(value) : const Color(_defaultAccentColor);
}

// Preferences

final shouldWeCheckUpdates = ValueNotifier<bool?>(
  _readNullableBoolSetting('shouldWeCheckUpdates'),
);

final playNextSongAutomatically = ValueNotifier<bool>(
  _readBoolSetting('playNextSongAutomatically', true),
);

final useSystemColor = ValueNotifier<bool>(
  _readBoolSetting('useSystemColor', false),
);

final usePureBlackColor = ValueNotifier<bool>(
  _readBoolSetting('usePureBlackColor', false),
);

final offlineMode = ValueNotifier<bool>(_readBoolSetting('offlineMode', false));

final wrappedEnabled = ValueNotifier<bool>(
  _readBoolSetting('wrappedEnabled', true),
);

final predictiveBack = ValueNotifier<bool>(
  _readBoolSetting('predictiveBack', true),
);

final sponsorBlockSupport = ValueNotifier<bool>(
  _readBoolSetting('sponsorBlockSupport', false),
);

final externalRecommendations = ValueNotifier<bool>(
  _readBoolSetting('externalRecommendations', false),
);

ProxyMode _initProxyMode() {
  final raw = _readStringSetting('proxyMode', '');
  if (raw.isNotEmpty) {
    return ProxyMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => ProxyMode.off,
    );
  }
  return _readBoolSetting('useProxy', false) ? ProxyMode.auto : ProxyMode.off;
}

final proxyModeNotifier = ValueNotifier<ProxyMode>(_initProxyMode());
final customProxyNotifier = ValueNotifier<String>(
  _readStringSetting('customProxy', ''),
);

final useProxy = ValueNotifier<bool>(proxyModeNotifier.value != ProxyMode.off);

void setProxyMode(ProxyMode mode) {
  proxyModeNotifier.value = mode;
  useProxy.value = mode != ProxyMode.off;
  if (Hive.isBoxOpen('settings')) {
    Hive.box('settings').put('proxyMode', mode.name);
    Hive.box('settings').put('useProxy', mode != ProxyMode.off);
  }
}

void setCustomProxyAddress(String address) {
  final clean = address.trim();
  customProxyNotifier.value = clean;
  if (Hive.isBoxOpen('settings')) {
    Hive.box('settings').put('customProxy', clean);
  }
}

final audioQualitySetting = ValueNotifier<String>(
  _readStringSetting('audioQuality', 'high'),
);

final streamingQualityWifi = ValueNotifier<String>(
  _readStringSetting('streamingQualityWifi', 'high'),
);

final streamingQualityMobile = ValueNotifier<String>(
  _readStringSetting('streamingQualityMobile', 'medium'),
);

final playerGradientStyle = ValueNotifier<String>(
  _readStringSetting('playerGradientStyle', 'dynamic'),
);

final volumeGestureEnabled = ValueNotifier<bool>(
  _readBoolSetting('volumeGestureEnabled', true),
);

final autoCacheSongs = ValueNotifier<bool>(
  _readBoolSetting('autoCacheSongs', true),
);

final lyricsOffsetNotifier = ValueNotifier<int>(
  _readIntSetting('lyricsOffsetMs', 0),
);

/// Active lyrics offset for the currently playing song (falls back to global).
final activeSongLyricsOffsetNotifier = ValueNotifier<int>(0);

/// Get the lyrics sync offset in ms for a specific song [songId] (usually ytid).
/// If the song has its own custom offset, returns that; otherwise returns the global default.
int getLyricsOffsetForSong(String? songId) {
  if (songId == null || songId.isEmpty) return lyricsOffsetNotifier.value;
  final val = Hive.box('settings').get('lyricsOffset_$songId');
  if (val is int) return val;
  return lyricsOffsetNotifier.value;
}

/// Check if a specific song has its own customized offset.
bool hasCustomLyricsOffsetForSong(String? songId) {
  if (songId == null || songId.isEmpty) return false;
  return Hive.box('settings').containsKey('lyricsOffset_$songId');
}

/// Sets the lyrics sync offset in ms specifically for [songId].
void setLyricsOffsetForSong(String? songId, int offsetMs) {
  if (songId == null || songId.isEmpty) {
    lyricsOffsetNotifier.value = offsetMs;
    Hive.box('settings').put('lyricsOffsetMs', offsetMs);
    activeSongLyricsOffsetNotifier.value = offsetMs;
    return;
  }
  Hive.box('settings').put('lyricsOffset_$songId', offsetMs);
  activeSongLyricsOffsetNotifier.value = offsetMs;
}

/// Resets the per-song offset back to the global default.
void resetLyricsOffsetForSong(String? songId) {
  if (songId != null && songId.isNotEmpty) {
    Hive.box('settings').delete('lyricsOffset_$songId');
  }
  activeSongLyricsOffsetNotifier.value = lyricsOffsetNotifier.value;
}

List<double> _readEqualizerGains() {
  final raw = Hive.box(
    'settings',
  ).get('equalizerBandGains', defaultValue: const <dynamic>[]);

  if (raw is List) {
    return raw.map((value) => value is num ? value.toDouble() : 0.0).toList();
  }

  return <double>[];
}

final equalizerEnabled = ValueNotifier<bool>(
  _readBoolSetting('equalizerEnabled', false),
);

final equalizerBandGains = ValueNotifier<List<double>>(_readEqualizerGains());

Locale languageSetting = getLocaleFromLanguageCode(
  resolveUiLanguageCode(_readNullableStringSetting('languageCode')),
);

final hasSeenLanguageOnboarding =
    Hive.isBoxOpen('settings') &&
    _readBoolSetting('hasSeenLanguageOnboarding', false);

String? _initContentLanguagePreference() {
  if (!Hive.isBoxOpen('settings')) return null;
  final box = Hive.box('settings');
  final rawContent = _readNullableStringSetting('contentLanguageCode');
  if (rawContent != null && rawContent.trim().isNotEmpty) {
    return resolveContentLanguageCode(rawContent);
  }
  // Migration / Safety: If user has already completed onboarding or has saved languageCode
  // but missing contentLanguageCode, safely derive it without crashing.
  final hasSeen = _readBoolSetting('hasSeenLanguageOnboarding', false);
  final rawUi = _readNullableStringSetting('languageCode');
  if (hasSeen || (rawUi != null && rawUi.trim().isNotEmpty)) {
    final derived = resolveContentLanguageCode(rawUi);
    box.put('contentLanguageCode', derived);
    return derived;
  }
  return null;
}

String _initContentCountryPreference() {
  if (!Hive.isBoxOpen('settings')) return defaultHomeFeedRegion;
  final rawCountry = _readNullableStringSetting('contentCountryCode');
  if (rawCountry != null && rawCountry.trim().isNotEmpty) {
    return resolveCountryCode(rawCountry);
  }
  return defaultHomeFeedRegion;
}

/// Content-country/region preference picked on first launch or in settings,
/// used to steer trending charts, new releases, and native home feed curation.
String contentCountryPreference = _initContentCountryPreference();

final contentCountryPreferenceNotifier = ValueNotifier<String>(
  contentCountryPreference,
);

void setContentCountryPreference(String countryCode) {
  final validCode = resolveCountryCode(countryCode);
  contentCountryPreference = validCode;
  contentCountryPreferenceNotifier.value = validCode;
  if (Hive.isBoxOpen('settings')) {
    Hive.box('settings').put('contentCountryCode', validCode);
    logger.log('[COUNTRY_RUNTIME] contentCountryCode=$validCode');
  }
}

/// Dynamic region getter for Home Feed and charts curation.
String get homeFeedRegion => contentCountryPreference;

/// Content-language preference picked on first launch, used only to steer
/// which playlists/songs are suggested. Distinct from [languageSetting],
/// which controls the app's displayed UI language and is unaffected by this.
String? contentLanguagePreference = _initContentLanguagePreference();

final contentLanguagePreferenceNotifier = ValueNotifier<String?>(
  contentLanguagePreference,
);

void setContentLanguagePreference(String languageCode) {
  final validCode = resolveContentLanguageCode(languageCode);
  contentLanguagePreference = validCode;
  contentLanguagePreferenceNotifier.value = validCode;
  if (Hive.isBoxOpen('settings')) {
    Hive.box('settings').put('contentLanguageCode', validCode);
    final uiLang = resolveUiLanguageCode(
      _readNullableStringSetting('languageCode'),
    );
    logger.log(
      '[LANGUAGE_RUNTIME] contentLanguageCode=$validCode uiLanguageCode=$uiLang',
    );
  }
}

/// Atomically completes first-launch music content language & country onboarding by:
/// 1. Validating the selected content language code against supportedContentLanguageCodes.
/// 2. Validating the selected country code against supportedCountries.
/// 3. Persisting `contentLanguageCode`, `contentCountryCode`, and `hasSeenLanguageOnboarding = true` to Hive.
/// 4. Updating in-memory preferences and notifiers.
/// 5. Crucially preserving `languageCode` (App UI language remains 'en' by default).
Future<void> completeContentLanguageOnboarding(
  String selectedContentLanguageCode, {
  String? selectedCountryCode,
}) async {
  final validContentLang = resolveContentLanguageCode(
    selectedContentLanguageCode,
  );
  final validCountry = resolveCountryCode(selectedCountryCode);

  if (Hive.isBoxOpen('settings')) {
    final box = Hive.box('settings');
    await box.put('contentLanguageCode', validContentLang);
    await box.put('contentCountryCode', validCountry);
    await box.put('hasSeenLanguageOnboarding', true);

    final uiLang = resolveUiLanguageCode(
      _readNullableStringSetting('languageCode'),
    );
    logger.log(
      '[LANGUAGE_RUNTIME] contentLanguageCode=$validContentLang contentCountryCode=$validCountry uiLanguageCode=$uiLang',
    );
  }

  contentCountryPreference = validCountry;
  contentCountryPreferenceNotifier.value = validCountry;
  contentLanguagePreference = validContentLang;
  contentLanguagePreferenceNotifier.value = validContentLang;
}

/// Legacy onboarding API. Delegates to [completeContentLanguageOnboarding] to
/// guarantee that App UI language is NEVER modified during first-launch onboarding.
Future<void> completeLanguageOnboarding(String selectedLanguageCode) async {
  await completeContentLanguageOnboarding(selectedLanguageCode);
}

final themeModeSetting = _readIntSetting('themeIndex', 0);

String playlistSortSetting = _readStringSetting(
  'playlistSortType',
  PlaylistSortType.default_.name,
);

String offlineSortSetting = _readStringSetting(
  'offlineSortType',
  OfflineSortType.default_.name,
);

Color primaryColorSetting = _readAccentColorSetting();

final shuffleNotifier = ValueNotifier<bool>(
  _readBoolSetting('shuffleEnabled', false),
);

final repeatNotifier = ValueNotifier<AudioServiceRepeatMode>(
  _readRepeatModeSetting(),
);

// Non-storage notifiers

var sleepTimerNotifier = ValueNotifier<Duration?>(null);

// Server-Notifiers

final announcementURL = ValueNotifier<String?>(null);

/// Re-syncs every persisted setting's in-memory value from the `settings`
/// Hive box. Every setting above is only read once, at process start, into
/// either a [ValueNotifier] or a plain top-level variable — data_manager's
/// restoreData overwrites the box on disk but never touches these. Without
/// calling this afterward, a restored backup (e.g. from another device)
/// silently keeps behaving like the pre-restore settings — proxy, equalizer,
/// audio quality, theme colors, etc. — until the app is fully force-quit and
/// relaunched.
///
/// `themeModeSetting` and `hasSeenLanguageOnboarding` are intentionally not
/// reloaded here: both are declared `final` and only ever consulted once at
/// cold start (live theme-mode changes flow through `_CatchifyState.themeMode`
/// instead), so there is nothing a mid-session reload could affect.
void reloadSettingsFromStorage() {
  shouldWeCheckUpdates.value = _readNullableBoolSetting('shouldWeCheckUpdates');
  playNextSongAutomatically.value = _readBoolSetting(
    'playNextSongAutomatically',
    true,
  );
  useSystemColor.value = _readBoolSetting('useSystemColor', false);
  usePureBlackColor.value = _readBoolSetting('usePureBlackColor', false);
  offlineMode.value = _readBoolSetting('offlineMode', false);
  wrappedEnabled.value = _readBoolSetting('wrappedEnabled', true);
  predictiveBack.value = _readBoolSetting('predictiveBack', true);
  sponsorBlockSupport.value = _readBoolSetting('sponsorBlockSupport', false);
  externalRecommendations.value = _readBoolSetting(
    'externalRecommendations',
    false,
  );
  proxyModeNotifier.value = _initProxyMode();
  customProxyNotifier.value = _readStringSetting('customProxy', '');
  useProxy.value = proxyModeNotifier.value != ProxyMode.off;
  audioQualitySetting.value = _readStringSetting('audioQuality', 'high');
  streamingQualityWifi.value = _readStringSetting(
    'streamingQualityWifi',
    'high',
  );
  streamingQualityMobile.value = _readStringSetting(
    'streamingQualityMobile',
    'medium',
  );
  playerGradientStyle.value = _readStringSetting(
    'playerGradientStyle',
    'dynamic',
  );
  volumeGestureEnabled.value = _readBoolSetting('volumeGestureEnabled', true);
  autoCacheSongs.value = _readBoolSetting('autoCacheSongs', true);
  lyricsOffsetNotifier.value = _readIntSetting('lyricsOffsetMs', 0);
  equalizerEnabled.value = _readBoolSetting('equalizerEnabled', false);
  equalizerBandGains.value = _readEqualizerGains();
  shuffleNotifier.value = _readBoolSetting('shuffleEnabled', false);
  repeatNotifier.value = _readRepeatModeSetting();

  final rawUi = _readNullableStringSetting('languageCode');
  final validUi = resolveUiLanguageCode(rawUi);
  languageSetting = getLocaleFromLanguageCode(validUi);

  final rawContent = _readNullableStringSetting('contentLanguageCode');
  if (rawContent != null && rawContent.trim().isNotEmpty) {
    contentLanguagePreference = resolveContentLanguageCode(rawContent);
  } else {
    contentLanguagePreference = resolveContentLanguageCode(validUi);
  }
  contentLanguagePreferenceNotifier.value = contentLanguagePreference;
  playlistSortSetting = _readStringSetting(
    'playlistSortType',
    PlaylistSortType.default_.name,
  );
  offlineSortSetting = _readStringSetting(
    'offlineSortType',
    OfflineSortType.default_.name,
  );
  primaryColorSetting = _readAccentColorSetting();
}
