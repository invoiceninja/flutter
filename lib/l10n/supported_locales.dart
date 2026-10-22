import 'package:flutter/widgets.dart';

import 'package:admin/l10n/transifex_files.dart';

export 'package:admin/l10n/transifex_files.dart' show kTransifexFileNames;

/// Locales we ship in `assets/i18n/`. Adding a locale:
///   1. Append it to [kSupportedLocales].
///   2. Add a `<locale_key>` → `"textsphp-XX.php"` entry to
///      [kTransifexFileNames] (in `transifex_files.dart`).
///   3. Add the same entry to the importer's copy of that map
///      (`tools/transifex_importer/bin/import.dart`), and its own-language
///      name to [kLocaleNativeNames].
///   4. Re-run the importer on the Transifex zip and commit
///      `assets/i18n/<locale>.json`.
///   `test/l10n/supported_locales_test.dart` checks all of the above.
///
/// English ships as the fallback and is loaded eagerly — see
/// `Localization.delegate`.
const List<Locale> kSupportedLocales = [
  Locale('en'),
  Locale('en', 'AU'),
  Locale('en', 'GB'),
  Locale('es'),
  Locale('fr'),
  Locale('de'),
  Locale('it'),
  Locale('nl'),
  Locale('pt', 'BR'),
  Locale('ja'),
  // Script codes where the language has two and the bundle uses one: Flutter
  // then resolves a zh_Hant_HK device to zh_TW, not zh_CN, and Material draws
  // its own strings in the script the app's are in. `localeKey` ignores them.
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans', countryCode: 'CN'),
  Locale('af', 'ZA'),
  Locale('ar'),
  Locale('bg'),
  Locale('ca'),
  Locale('cs'),
  Locale('da'),
  Locale('el'),
  Locale('es', 'ES'),
  Locale('et'),
  Locale('fa'),
  Locale('fi'),
  Locale('fr', 'CA'),
  Locale('fr', 'CH'),
  Locale('he'),
  Locale('hr'),
  Locale('hu'),
  Locale('id', 'ID'),
  Locale('km', 'KH'),
  Locale('lo', 'LA'),
  Locale('lt'),
  Locale('lv', 'LV'),
  Locale('mk', 'MK'),
  Locale('nb', 'NO'),
  Locale('pl'),
  Locale('pt', 'PT'),
  Locale('ro'),
  Locale('ru', 'RU'),
  Locale('sk'),
  Locale('sl'),
  Locale('sq'),
  Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn'),
  Locale('sv'),
  Locale('th'),
  Locale('tr', 'TR'),
  Locale('vi'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW'),
];

/// Each shipped locale's name in its own language, for the App Language
/// picker (keyed by [localeKey]).
const Map<String, String> kLocaleNativeNames = {
  'en': 'English',
  'en_AU': 'English (Australia)',
  'en_GB': 'English (UK)',
  'es': 'Español',
  'fr': 'Français',
  'de': 'Deutsch',
  'it': 'Italiano',
  'nl': 'Nederlands',
  'pt_BR': 'Português (Brasil)',
  'ja': '日本語',
  'zh_CN': '中文 (简体)',
  'af_ZA': 'Afrikaans',
  'ar': 'العربية',
  'bg': 'Български',
  'ca': 'Català',
  'cs': 'Čeština',
  'da': 'Dansk',
  'el': 'Ελληνικά',
  'es_ES': 'Español (España)',
  'et': 'Eesti',
  'fa': 'فارسی',
  'fi': 'Suomi',
  'fr_CA': 'Français (Canada)',
  'fr_CH': 'Français (Suisse)',
  'he': 'עברית',
  'hr': 'Hrvatski',
  'hu': 'Magyar',
  'id_ID': 'Bahasa Indonesia',
  'km_KH': 'ខ្មែរ',
  'lo_LA': 'ລາວ',
  'lt': 'Lietuvių',
  'lv_LV': 'Latviešu',
  'mk_MK': 'Македонски',
  'nb_NO': 'Norsk bokmål',
  'pl': 'Polski',
  'pt_PT': 'Português (Portugal)',
  'ro': 'Română',
  'ru_RU': 'Русский',
  'sk': 'Slovenčina',
  'sl': 'Slovenščina',
  'sq': 'Shqip',
  'sr': 'Srpski',
  'sv': 'Svenska',
  'th': 'ไทย',
  'tr_TR': 'Türkçe',
  'vi': 'Tiếng Việt',
  'zh_TW': '中文 (繁體)',
};

String localeKey(Locale locale) {
  if (locale.countryCode == null || locale.countryCode!.isEmpty) {
    return locale.languageCode;
  }
  return '${locale.languageCode}_${locale.countryCode}';
}
