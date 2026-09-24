import 'package:flutter/widgets.dart';
import 'package:catchify/localization/app_localizations.dart';

// Supported app language codes.
const appLanguages = <String>{
  'en',
  'zh',
  'et',
  'fr',
  'de',
  'el',
  'hi',
  'he',
  'hu',
  'id',
  'it',
  'ja',
  'ko',
  'ru',
  'pl',
  'pt',
  'es',
  'sv',
  'ta',
  'tr',
  'uk',
};

/// Supported music-content recommendation language codes (from artistLanguageCodeToName).
const supportedContentLanguageCodes = <String>{
  'ta',
  'hi',
  'te',
  'ml',
  'kn',
  'pa',
  'en',
  'mr',
  'bn',
  'gu',
  'ur',
  'or',
  'as',
  'sa',
  'kok',
  // Global music languages
  'es',
  'ko',
  'ja',
  'fr',
  'de',
  'pt',
  'id',
  'it',
  'tr',
  'ru',
  'ar',
};

class CountryOption {
  const CountryOption({
    required this.code,
    required this.name,
    required this.flag,
    this.primaryLanguages = const [],
  });

  final String code;
  final String name;
  final String flag;
  final List<String> primaryLanguages;
}

const supportedCountries = <CountryOption>[
  CountryOption(
    code: 'IN',
    name: 'India',
    flag: '🇮🇳',
    primaryLanguages: ['ta', 'hi', 'te', 'ml', 'kn', 'pa', 'en'],
  ),
  CountryOption(
    code: 'US',
    name: 'United States',
    flag: '🇺🇸',
    primaryLanguages: ['en', 'es', 'ko'],
  ),
  CountryOption(
    code: 'GB',
    name: 'United Kingdom',
    flag: '🇬🇧',
    primaryLanguages: ['en'],
  ),
  CountryOption(
    code: 'CA',
    name: 'Canada',
    flag: '🇨🇦',
    primaryLanguages: ['en', 'fr', 'pa'],
  ),
  CountryOption(
    code: 'AU',
    name: 'Australia',
    flag: '🇦🇺',
    primaryLanguages: ['en'],
  ),
  CountryOption(
    code: 'DE',
    name: 'Germany',
    flag: '🇩🇪',
    primaryLanguages: ['de', 'en'],
  ),
  CountryOption(
    code: 'FR',
    name: 'France',
    flag: '🇫🇷',
    primaryLanguages: ['fr', 'en'],
  ),
  CountryOption(
    code: 'JP',
    name: 'Japan',
    flag: '🇯🇵',
    primaryLanguages: ['ja', 'en', 'ko'],
  ),
  CountryOption(
    code: 'KR',
    name: 'South Korea',
    flag: '🇰🇷',
    primaryLanguages: ['ko', 'en', 'ja'],
  ),
  CountryOption(
    code: 'BR',
    name: 'Brazil',
    flag: '🇧🇷',
    primaryLanguages: ['pt', 'en'],
  ),
  CountryOption(
    code: 'MX',
    name: 'Mexico',
    flag: '🇲🇽',
    primaryLanguages: ['es', 'en'],
  ),
  CountryOption(
    code: 'ES',
    name: 'Spain',
    flag: '🇪🇸',
    primaryLanguages: ['es', 'en'],
  ),
  CountryOption(
    code: 'ID',
    name: 'Indonesia',
    flag: '🇮🇩',
    primaryLanguages: ['id', 'en'],
  ),
  CountryOption(
    code: 'IT',
    name: 'Italy',
    flag: '🇮🇹',
    primaryLanguages: ['it', 'en'],
  ),
  CountryOption(
    code: 'RU',
    name: 'Russia',
    flag: '🇷🇺',
    primaryLanguages: ['ru', 'en'],
  ),
  CountryOption(
    code: 'TR',
    name: 'Turkey',
    flag: '🇹🇷',
    primaryLanguages: ['tr', 'en'],
  ),
  CountryOption(
    code: 'SA',
    name: 'Saudi Arabia',
    flag: '🇸🇦',
    primaryLanguages: ['ar', 'en'],
  ),
  CountryOption(
    code: 'AE',
    name: 'United Arab Emirates',
    flag: '🇦🇪',
    primaryLanguages: ['ar', 'en', 'hi', 'ta'],
  ),
  CountryOption(
    code: 'SG',
    name: 'Singapore',
    flag: '🇸🇬',
    primaryLanguages: ['en', 'ta', 'zh'],
  ),
  CountryOption(
    code: 'MY',
    name: 'Malaysia',
    flag: '🇲🇾',
    primaryLanguages: ['ms', 'en', 'ta'],
  ),
  CountryOption(
    code: 'ZA',
    name: 'South Africa',
    flag: '🇿🇦',
    primaryLanguages: ['en'],
  ),
  CountryOption(
    code: 'NZ',
    name: 'New Zealand',
    flag: '🇳🇿',
    primaryLanguages: ['en'],
  ),
  CountryOption(
    code: 'PH',
    name: 'Philippines',
    flag: '🇵🇭',
    primaryLanguages: ['en', 'tl'],
  ),
];

/// Default fallback region for YouTube Music recommendations.
const defaultHomeFeedRegion = 'IN';

String resolveCountryCode(String? countryCode) {
  if (countryCode == null || countryCode.trim().isEmpty) {
    return defaultHomeFeedRegion;
  }
  final clean = countryCode.trim().toUpperCase();
  for (final country in supportedCountries) {
    if (country.code == clean) return clean;
  }
  return defaultHomeFeedRegion;
}

CountryOption getCountryByCode(String? countryCode) {
  final code = resolveCountryCode(countryCode);
  for (final country in supportedCountries) {
    if (country.code == code) return country;
  }
  return supportedCountries.first;
}

/// Resolves a UI language code to a supported music content language code.
///
/// If [uiLanguageCode] is supported for music content recommendations, returns that code.
/// Otherwise, deterministically defaults to 'en' without crashing or guessing unsupported catalog codes.
String resolveContentLanguageCode(String? uiLanguageCode) {
  if (uiLanguageCode == null || uiLanguageCode.trim().isEmpty) {
    return 'en';
  }
  final clean = uiLanguageCode.trim().toLowerCase();
  final base = clean.contains('-') ? clean.split('-')[0] : clean;
  if (supportedContentLanguageCodes.contains(clean)) {
    return clean;
  }
  if (supportedContentLanguageCodes.contains(base)) {
    return base;
  }
  return 'en';
}

/// Resolves the Home Feed InnerTube transport `hl` parameter.
///
/// For standard Home Feed requests, Catchify intentionally keeps transport `hl` as 'en'
/// so that remote shelf headers and topic labels returned by InnerTube remain clean and English,
/// while Catchify's [contentLanguageCode] independently drives music/content curation.
String resolveHomeFeedTransportLanguage([String? contentLanguageCode]) {
  return 'en';
}

/// Whether the native YouTube Music home shelves are safe to show for the
/// selected content language.
///
/// Native shelves are transported in English and are not guaranteed to match
/// a regional content preference, so regional feeds use curated sections only.
bool shouldUseNativeHomeFeed(String? contentLanguageCode) {
  return resolveContentLanguageCode(contentLanguageCode) == 'en';
}

/// Validates whether a UI language code is supported by Catchify.
///
/// If [languageCode] is unrecognized or null, safely falls back to 'en'.
String resolveUiLanguageCode(String? languageCode) {
  if (languageCode == null || languageCode.trim().isEmpty) {
    return 'en';
  }
  final clean = languageCode.trim().toLowerCase();
  final base = clean.contains('-') ? clean.split('-')[0] : clean;
  if (appLanguages.contains(clean)) {
    return clean;
  }
  if (appLanguages.contains(base)) {
    return base;
  }
  return 'en';
}

final List<Locale> appSupportedLocales = appLanguages.map((languageCode) {
  final parts = languageCode.split('-');
  if (parts.length > 1) {
    return Locale.fromSubtags(languageCode: parts[0], scriptCode: parts[1]);
  }
  return Locale(languageCode);
}).toList();

String getLanguageDisplayName(BuildContext context, String languageCode) {
  final l10n = AppLocalizations.of(context)!;

  switch (languageCode) {
    case 'en':
      return l10n.languageEn;
    case 'zh':
      return l10n.languageZh;
    case 'et':
      return l10n.languageEt;
    case 'fr':
      return l10n.languageFr;
    case 'de':
      return l10n.languageDe;
    case 'el':
      return l10n.languageEl;
    case 'hi':
      return l10n.languageHi;
    case 'he':
      return l10n.languageHe;
    case 'hu':
      return l10n.languageHu;
    case 'id':
      return l10n.languageId;
    case 'it':
      return l10n.languageIt;
    case 'ja':
      return l10n.languageJa;
    case 'ko':
      return l10n.languageKo;
    case 'ru':
      return l10n.languageRu;
    case 'pl':
      return l10n.languagePl;
    case 'pt':
      return l10n.languagePt;
    case 'es':
      return l10n.languageEs;
    case 'sv':
      return l10n.languageSv;
    case 'ta':
      return l10n.languageTa;
    case 'tr':
      return l10n.languageTr;
    case 'uk':
      return l10n.languageUk;
    default:
      return l10n
          .languageEn; // Fallback to English if the language code is not recognized
  }
}

Locale getLocaleFromLanguageCode(String? languageCode) {
  // Early return for null case
  if (languageCode == null) {
    return const Locale('en');
  }

  // Handle codes with script parts
  if (languageCode.contains('-')) {
    final parts = languageCode.split('-');
    final baseLanguage = parts[0];
    final script = parts[1];

    // Try to find exact match with script
    for (final locale in appSupportedLocales) {
      if (locale.languageCode == baseLanguage && locale.scriptCode == script) {
        return locale;
      }
    }

    // Fall back to base language only
    return Locale(baseLanguage);
  }

  // Handle simple language codes
  for (final locale in appSupportedLocales) {
    if (locale.languageCode == languageCode) {
      return locale;
    }
  }

  // Default fallback
  return const Locale('en');
}
