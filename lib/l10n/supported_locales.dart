import 'package:flutter/widgets.dart';

import 'package:admin/l10n/transifex_files.dart';

export 'package:admin/l10n/transifex_files.dart' show kTransifexFileNames;

/// Locales we ship in `assets/i18n/`. Adding a locale:
///   1. Append it to [kSupportedLocales].
///   2. Add a `<locale_key>` → `"textsphp-XX.php"` entry to
///      [kTransifexFileNames] (in `transifex_files.dart`).
///   3. Re-run `dart run tools/import_transifex_zip.dart <zip>`.
///   4. Commit `assets/i18n/<locale>.json`.
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
  Locale('zh', 'CN'),
];

String localeKey(Locale locale) {
  if (locale.countryCode == null || locale.countryCode!.isEmpty) {
    return locale.languageCode;
  }
  return '${locale.languageCode}_${locale.countryCode}';
}
