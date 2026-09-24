import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:catchify/services/playlists_manager.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/language_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('catchify_lang_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    final box = Hive.box('settings');
    await box.clear();
  });

  group('Language Resolution & Mappings', () {
    test('supported music content languages map to identical code', () {
      final supportedCodes = [
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
      ];

      for (final code in supportedCodes) {
        expect(
          resolveContentLanguageCode(code),
          equals(code),
          reason: 'Language code $code should map to itself for music content',
        );
      }
    });

    test('unsupported UI-only languages deterministically fall back to en', () {
      final unsupportedUiOnly = [
        'zh',
        'uk',
        'pl',
        'sv',
        'hu',
        'el',
        'et',
        'he',
        'nl',
        'cs',
        'ro',
        'da',
        'fi',
        'no',
      ];

      for (final code in unsupportedUiOnly) {
        expect(
          resolveContentLanguageCode(code),
          equals('en'),
          reason:
              'UI-only language $code should safely fall back to en for music content',
        );
      }
    });

    test(
      'resolveContentLanguageCode handles null, empty, whitespace, and corrupt values safely',
      () {
        expect(resolveContentLanguageCode(null), equals('en'));
        expect(resolveContentLanguageCode(''), equals('en'));
        expect(resolveContentLanguageCode('   '), equals('en'));
        expect(resolveContentLanguageCode('xyz_corrupt'), equals('en'));
        expect(resolveContentLanguageCode('unknown123'), equals('en'));
      },
    );

    test(
      'resolveContentLanguageCode handles locale codes with script subtags',
      () {
        expect(resolveContentLanguageCode('ta-IN'), equals('ta'));
        expect(resolveContentLanguageCode('hi-IN'), equals('hi'));
        expect(resolveContentLanguageCode('zh-Hans'), equals('en'));
        expect(resolveContentLanguageCode('en-US'), equals('en'));
      },
    );

    test(
      'resolveUiLanguageCode validates supported appLanguages and falls back to en',
      () {
        expect(resolveUiLanguageCode('en'), equals('en'));
        expect(resolveUiLanguageCode('ta'), equals('ta'));
        expect(resolveUiLanguageCode('hi'), equals('hi'));
        expect(resolveUiLanguageCode('fr'), equals('fr'));
        expect(resolveUiLanguageCode('de'), equals('de'));
        expect(resolveUiLanguageCode('ja'), equals('ja'));
        expect(resolveUiLanguageCode(null), equals('en'));
        expect(resolveUiLanguageCode(''), equals('en'));
        expect(resolveUiLanguageCode('invalid_language'), equals('en'));
      },
    );

    test('getLocaleFromLanguageCode correctly returns Locale instances', () {
      expect(getLocaleFromLanguageCode('ta').languageCode, equals('ta'));
      expect(getLocaleFromLanguageCode('hi').languageCode, equals('hi'));
      expect(getLocaleFromLanguageCode('en').languageCode, equals('en'));
      expect(getLocaleFromLanguageCode(null).languageCode, equals('en'));
      expect(
        getLocaleFromLanguageCode('unsupported_xyz').languageCode,
        equals('en'),
      );
    });
  });

  group(
    'InnerTube Transport Language Strategy (resolveHomeFeedTransportLanguage)',
    () {
      test(
        'all music content languages use clean English transport hl for Home Feed',
        () {
          final supportedContentCodes = [
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
          ];

          for (final code in supportedContentCodes) {
            expect(
              resolveHomeFeedTransportLanguage(code),
              equals('en'),
              reason:
                  'Music language $code must use English transport hl to keep shelf headers clean English',
            );
          }
        },
      );

      test('UI-only languages safely use English transport hl', () {
        expect(resolveHomeFeedTransportLanguage('de'), equals('en'));
        expect(resolveHomeFeedTransportLanguage('fr'), equals('en'));
        expect(resolveHomeFeedTransportLanguage('es'), equals('en'));
        expect(resolveHomeFeedTransportLanguage('ja'), equals('en'));
      });

      test('handles null, empty, whitespace, and corrupt values safely', () {
        expect(resolveHomeFeedTransportLanguage(null), equals('en'));
        expect(resolveHomeFeedTransportLanguage(''), equals('en'));
        expect(resolveHomeFeedTransportLanguage('   '), equals('en'));
        expect(resolveHomeFeedTransportLanguage('corrupt_lang'), equals('en'));
      });
    },
  );

  group('Home Feed Native Shelf Policy', () {
    test('allows native shelves only for English content', () {
      expect(shouldUseNativeHomeFeed('en'), isTrue);
      expect(shouldUseNativeHomeFeed('en-IN'), isTrue);
      expect(shouldUseNativeHomeFeed(null), isTrue);
      expect(shouldUseNativeHomeFeed('ta'), isFalse);
      expect(shouldUseNativeHomeFeed('hi-IN'), isFalse);
      expect(shouldUseNativeHomeFeed('te'), isFalse);
    });

    test('unsupported content languages safely follow English policy', () {
      expect(shouldUseNativeHomeFeed('zh'), isTrue);
      expect(shouldUseNativeHomeFeed('invalid_language'), isTrue);
    });
  });

  group('Home Feed Cache Key Generation (v9)', () {
    test(
      'generates versioned language-isolated cache keys with transportHl = en',
      () {
        final keyTa = getHomeFeedCacheKey(
          contentLanguage: 'ta',
          region: 'IN',
          mood: 'All',
        );
        final keyHi = getHomeFeedCacheKey(
          contentLanguage: 'hi',
          region: 'IN',
          mood: 'All',
        );
        final keyTe = getHomeFeedCacheKey(
          contentLanguage: 'te',
          region: 'IN',
          mood: 'All',
        );
        final keyMl = getHomeFeedCacheKey(
          contentLanguage: 'ml',
          region: 'IN',
          mood: 'All',
        );
        final keyEn = getHomeFeedCacheKey(
          contentLanguage: 'en',
          region: 'IN',
          mood: 'All',
        );

        expect(keyTa, equals('ytm_home_feed_v9_ta_en_IN_All'));
        expect(keyHi, equals('ytm_home_feed_v9_hi_en_IN_All'));
        expect(keyTe, equals('ytm_home_feed_v9_te_en_IN_All'));
        expect(keyMl, equals('ytm_home_feed_v9_ml_en_IN_All'));
        expect(keyEn, equals('ytm_home_feed_v9_en_en_IN_All'));

        // Verify complete namespace isolation across languages
        final keys = [keyTa, keyHi, keyTe, keyMl, keyEn];
        expect(keys.toSet().length, equals(keys.length));
      },
    );

    test('isolates cache when transport language is explicitly specified', () {
      final keyDefault = getHomeFeedCacheKey(
        contentLanguage: 'ta',
        region: 'IN',
        mood: 'All',
      );
      final keyCustomTransport = getHomeFeedCacheKey(
        contentLanguage: 'ta',
        transportHl: 'ta',
        region: 'IN',
        mood: 'All',
      );

      expect(keyDefault, equals('ytm_home_feed_v9_ta_en_IN_All'));
      expect(keyCustomTransport, equals('ytm_home_feed_v9_ta_ta_IN_All'));
      expect(keyDefault, isNot(equals(keyCustomTransport)));
    });

    test('generates distinct cache keys for different moods', () {
      final keyAll = getHomeFeedCacheKey(
        contentLanguage: 'ta',
        region: 'IN',
        mood: 'All',
      );
      final keyWorkout = getHomeFeedCacheKey(
        contentLanguage: 'ta',
        region: 'IN',
        mood: 'Workout',
      );
      final keyChill = getHomeFeedCacheKey(
        contentLanguage: 'ta',
        region: 'IN',
        mood: 'Chill',
      );

      expect(keyAll, equals('ytm_home_feed_v9_ta_en_IN_All'));
      expect(keyWorkout, equals('ytm_home_feed_v9_ta_en_IN_Workout'));
      expect(keyChill, equals('ytm_home_feed_v9_ta_en_IN_Chill'));

      expect(keyAll, isNot(equals(keyWorkout)));
      expect(keyWorkout, isNot(equals(keyChill)));
    });

    test('defaults safely when parameters are omitted or empty', () {
      final keyDefault = getHomeFeedCacheKey(mood: '');
      expect(keyDefault, startsWith('ytm_home_feed_v9_'));
      expect(keyDefault, contains('_en_IN_All'));
    });
  });

  group('Required Acceptance Tests (Specification Matrix)', () {
    test(
      'Test 1: selecting Tamil sets contentLanguageCode = ta while languageCode remains en',
      () async {
        final box = Hive.box('settings');
        await box.put('languageCode', 'en');
        languageSetting = const Locale('en');

        // User completes first-launch onboarding selecting Tamil
        await completeContentLanguageOnboarding('ta');

        expect(box.get('languageCode'), equals('en'));
        expect(languageSetting.languageCode, equals('en'));
        expect(box.get('contentLanguageCode'), equals('ta'));
        expect(contentLanguagePreference, equals('ta'));
        expect(box.get('hasSeenLanguageOnboarding'), isTrue);
      },
    );

    test(
      'Test 2: Home request with contentLanguageCode = ta uses hl = en for standard Home Feed transport',
      () {
        const contentLang = 'ta';
        final transportHl = resolveHomeFeedTransportLanguage(contentLang);

        expect(transportHl, equals('en'));
        final cacheKey = getHomeFeedCacheKey(
          contentLanguage: contentLang,
          transportHl: transportHl,
          region: 'IN',
          mood: 'All',
        );
        expect(cacheKey, equals('ytm_home_feed_v9_ta_en_IN_All'));
      },
    );

    test(
      'Test 3: Tamil content curation still receives ta to drive language-specific discovery',
      () {
        const code = 'ta';
        expect(supportedContentLanguageCodes.contains(code), isTrue);
        expect(artistLanguageCodeToName[code], equals('Tamil'));
      },
    );

    test(
      'Test 4: Hindi sets contentLanguageCode = hi while transport uses hl = en',
      () {
        const contentLang = 'hi';
        final transportHl = resolveHomeFeedTransportLanguage(contentLang);

        expect(transportHl, equals('en'));
        final cacheKey = getHomeFeedCacheKey(
          contentLanguage: contentLang,
          transportHl: transportHl,
          region: 'IN',
          mood: 'All',
        );
        expect(cacheKey, equals('ytm_home_feed_v9_hi_en_IN_All'));
      },
    );

    test(
      'Test 5: App Language change updates languageCode while contentLanguageCode is unchanged',
      () async {
        final box = Hive.box('settings');
        await completeContentLanguageOnboarding('ta');
        expect(contentLanguagePreference, equals('ta'));
        expect(box.get('contentLanguageCode'), equals('ta'));

        // User later changes App Language to German in Settings
        await box.put('languageCode', 'de');
        languageSetting = const Locale('de');

        expect(box.get('languageCode'), equals('de'));
        expect(languageSetting.languageCode, equals('de'));
        expect(box.get('contentLanguageCode'), equals('ta'));
        expect(contentLanguagePreference, equals('ta'));
      },
    );

    test(
      'Test 6: Music Language change updates contentLanguageCode, leaves languageCode unchanged, and triggers Home refresh',
      () async {
        final box = Hive.box('settings');
        await box.put('languageCode', 'de');
        languageSetting = const Locale('de');
        await completeContentLanguageOnboarding('ta');

        var refreshTriggered = false;
        void onPreferenceChanged() {
          refreshTriggered = true;
        }

        contentLanguagePreferenceNotifier.addListener(onPreferenceChanged);

        try {
          // User changes Music Language to Hindi
          setContentLanguagePreference('hi');

          expect(box.get('contentLanguageCode'), equals('hi'));
          expect(contentLanguagePreference, equals('hi'));
          expect(box.get('languageCode'), equals('de'));
          expect(languageSetting.languageCode, equals('de'));
          expect(refreshTriggered, isTrue);
        } finally {
          contentLanguagePreferenceNotifier.removeListener(onPreferenceChanged);
        }
      },
    );

    test(
      'Test 7: Cache namespaces for ta + en, hi + en, te + en have isolated namespaces',
      () {
        final keyTa = getHomeFeedCacheKey(
          contentLanguage: 'ta',
          region: 'IN',
          mood: 'All',
        );
        final keyHi = getHomeFeedCacheKey(
          contentLanguage: 'hi',
          region: 'IN',
          mood: 'All',
        );
        final keyTe = getHomeFeedCacheKey(
          contentLanguage: 'te',
          region: 'IN',
          mood: 'All',
        );
        final keyMl = getHomeFeedCacheKey(
          contentLanguage: 'ml',
          region: 'IN',
          mood: 'All',
        );

        expect(keyTa, equals('ytm_home_feed_v9_ta_en_IN_All'));
        expect(keyHi, equals('ytm_home_feed_v9_hi_en_IN_All'));
        expect(keyTe, equals('ytm_home_feed_v9_te_en_IN_All'));
        expect(keyMl, equals('ytm_home_feed_v9_ml_en_IN_All'));

        final setOfKeys = {keyTa, keyHi, keyTe, keyMl};
        expect(setOfKeys.length, equals(4));
      },
    );
  });
}
