import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/app_locale_resolver.dart';
import 'package:admin/l10n/supported_locales.dart';

/// Pure mapping tests for the statics-locale → shipped-locale resolution that
/// drives the app UI language (React-parity company-language behaviour).
void main() {
  group('AppLocaleResolver.bestSupportedLocale', () {
    Locale map(String code) => AppLocaleResolver.bestSupportedLocale(code);

    test('exact language match passes through', () {
      expect(map('de'), const Locale('de'));
      expect(map('fr'), const Locale('fr'));
      expect(map('en'), const Locale('en'));
    });

    test('exact language+country match passes through', () {
      expect(map('pt_BR'), const Locale('pt', 'BR'));
      expect(map('en_GB'), const Locale('en', 'GB'));
    });

    test('country variant we do not ship falls back to the base language '
        '(fr_BE → fr) so the right asset loads, not English', () {
      // The bug guarded against: Locale("fr","BE") passes the delegate's
      // isSupported (matches "fr") but load("fr_BE") finds no asset and falls
      // back to English. Mapping to "fr" loads French.
      expect(map('fr_BE'), const Locale('fr'));
      expect(map('es_MX'), const Locale('es'));
    });

    test('a different country of the same language maps to a shipped variant '
        'when there is no country-less one (nb_SJ → nb_NO)', () {
      expect(map('nb_SJ'), const Locale('nb', 'NO'));
    });

    test('every language the server offers ships as itself', () {
      // `LanguageSeeder` on the server: the codes a company's
      // `settings.language_id` can resolve to through the statics.
      const serverLocales = [
        'en', 'it', 'de', 'fr', 'pt_BR', 'nl', 'es', 'nb_NO', 'da', 'ja', //
        'sv', 'es_ES', 'fr_CA', 'lt', 'pl', 'cs', 'hr', 'sq', 'el', 'en_GB',
        'pt_PT', 'sl', 'fi', 'ro', 'tr_TR', 'th', 'mk_MK', 'zh_TW', 'ru_RU',
        'ar', 'fa', 'lv_LV', 'sr', 'sk', 'et', 'bg', 'he', 'km_KH', 'hu',
        'fr_CH', 'lo_LA', 'vi', 'ca', 'af_ZA', 'id_ID',
      ];
      for (final code in serverLocales) {
        expect(localeKey(map(code)), code, reason: code);
      }
    });

    test('an unshipped language falls back to English', () {
      expect(map('ko'), const Locale('en'));
      expect(map('xx_YY'), const Locale('en'));
    });

    test('empty code falls back to English', () {
      expect(map(''), const Locale('en'));
    });
  });
}
