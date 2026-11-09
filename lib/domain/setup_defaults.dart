import 'dart:ui' show Locale;

import 'package:collection/collection.dart';

import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/language.dart';

/// The setup wizard's starting currency and invoice language, from the
/// device locale (docs/first-run-welcome.md). Pure, so the guesses are
/// testable without a widget. The historical Invoice Ninja defaults — US
/// Dollar and English, both id `'1'` — are the fallback.

/// Hard-coded country → currency for the common cases. Keeps the default
/// smart without dragging in a full ISO-3166 → ISO-4217 table.
const Map<String, String> kCountryCurrency = {
  'US': 'USD',
  'GB': 'GBP',
  'CA': 'CAD',
  'AU': 'AUD',
  'NZ': 'NZD',
  'JP': 'JPY',
  'CH': 'CHF',
  'SE': 'SEK',
  'NO': 'NOK',
  'DK': 'DKK',
  'PL': 'PLN',
  'IN': 'INR',
  'BR': 'BRL',
  'MX': 'MXN',
  'AR': 'ARS',
  'ZA': 'ZAR',
  'SG': 'SGD',
  'HK': 'HKD',
  'IL': 'ILS',
  'KR': 'KRW',
  // Eurozone (20 members as of 2026, by accession year).
  'DE': 'EUR', 'FR': 'EUR', 'ES': 'EUR', 'IT': 'EUR', 'NL': 'EUR',
  'BE': 'EUR', 'AT': 'EUR', 'IE': 'EUR', 'PT': 'EUR', 'GR': 'EUR',
  'FI': 'EUR', 'LU': 'EUR', 'CY': 'EUR', 'MT': 'EUR', 'SI': 'EUR',
  'SK': 'EUR', 'EE': 'EUR', 'LV': 'EUR', 'LT': 'EUR', 'HR': 'EUR',
};

const String kFallbackCurrencyId = '1';
const String kFallbackLanguageId = '1';

String defaultCurrencyId(Iterable<Currency> currencies, Locale? locale) {
  final country = locale?.countryCode;
  if (country == null || country.isEmpty) return kFallbackCurrencyId;
  final code = kCountryCurrency[country.toUpperCase()];
  if (code == null) return kFallbackCurrencyId;
  return currencies.firstWhereOrNull((c) => c.code.toUpperCase() == code)?.id ??
      kFallbackCurrencyId;
}

/// An exact `lang_country` match (`fr_ca`) first, then the first language
/// whose locale starts with the device's language code.
String defaultLanguageId(Iterable<Language> languages, Locale? locale) {
  final lang = locale?.languageCode.toLowerCase();
  if (lang == null || lang.isEmpty) return kFallbackLanguageId;
  final country = locale?.countryCode;
  final tag = country != null && country.isNotEmpty
      ? '${lang}_${country.toLowerCase()}'
      : lang;
  final exact = languages.firstWhereOrNull(
    (l) => l.locale.toLowerCase() == tag,
  );
  if (exact != null) return exact.id;
  return languages
          .firstWhereOrNull((l) => l.locale.toLowerCase().startsWith(lang))
          ?.id ??
      kFallbackLanguageId;
}

/// A company name the server seeds, or the resolver falls back to — what
/// "not named yet" looks like to the router's `/setup` gate
/// (`isCompanySetupRequired`). The wizard refuses it as a name, or the gate
/// would stay shut after the save and the wizard would never leave.
bool isPlaceholderCompanyName(String name) {
  final n = name.trim().toLowerCase();
  return n.isEmpty || n == 'untitled company' || n == 'untitled';
}
