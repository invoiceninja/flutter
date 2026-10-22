import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'package:admin/app/locale_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/l10n/supported_locales.dart';

/// Resolves the locale the app UI actually renders in, and feeds
/// `MaterialApp.locale`.
///
/// Mirrors the React app's behaviour (`react/src/App.tsx`): the display
/// language follows the active company's `settings.language_id` (mapped to a
/// shipped locale via the statics `languages` table), re-localizing **on save**
/// — not on selection — because it derives from the *persisted* company row.
///
/// Precedence:
///   1. The device-local override (`LocaleController`, set from Settings →
///      User Details → Preferences → App Language). This is a rebuild addition
///      React doesn't have; when it's unset the chain below is exactly React's.
///   2. The active company's `settings.language_id` → matched shipped locale.
///   3. English, when the company language isn't one we ship UI strings for
///      (React falls back the same way via i18next).
///   4. `null` (follow the OS/device locale) only before any company is active
///      — i.e. on the login screen.
///
/// (React also lets a per-user `user.language_id` override the company; the
/// field exists on the user model but has no editor yet, so it's a documented
/// follow-up — see the Localization review plan.)
class AppLocaleResolver extends ValueNotifier<Locale?> {
  AppLocaleResolver({
    required LocaleController override,
    required AuthRepository auth,
    required StaticsRepository statics,
    required AppDatabase db,
  }) : _override = override,
       _auth = auth,
       _statics = statics,
       _db = db,
       super(override.value) {
    _override.addListener(_recompute);
    _auth.session.addListener(_recompute);
    _recompute();
  }

  final LocaleController _override;
  final AuthRepository _auth;
  final StaticsRepository _statics;
  final AppDatabase _db;

  /// Recompute after the active company's settings are persisted (a settings
  /// save). Wired into `CompanyRepository.onSettingsWritten` so changing
  /// Localization → Language re-localizes the running app on save.
  void onSettingsWritten() => _recompute();

  Future<void> _recompute() async {
    // Device override always wins — the picker only offers shipped locales, so
    // it's safe to pass straight through.
    final override = _override.value;
    if (override != null) {
      value = override;
      return;
    }
    final companyId = _auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) {
      // No active company (login screen) — follow the OS/device locale.
      value = null;
      return;
    }
    final resolved = await _companyLocale(companyId);
    value = resolved;
  }

  Future<Locale?> _companyLocale(String companyId) async {
    await _statics.ensureLoaded();
    final row = await _db.companiesDao.byId(companyId);
    final settingsJson = row?.settings ?? '';
    final languageId = _languageIdFrom(settingsJson);
    final code = languageId.isEmpty
        ? ''
        : (_statics.languages[languageId]?.locale ?? '');
    // A company is active, so always render in *some* concrete language
    // (English when the company language isn't shipped), never the OS locale.
    return bestSupportedLocale(code);
  }

  String _languageIdFrom(String settingsJson) {
    if (settingsJson.isEmpty) return '';
    try {
      final map = jsonDecode(settingsJson) as Map<String, dynamic>;
      return map['language_id']?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Map a statics locale code (`en`, `de`, `pt_BR`, `fr_CA`, …) to the closest
  /// locale we actually ship strings for, falling back to English.
  ///
  /// Crucially this resolves country variants to the shipped asset: `fr_BE`
  /// would pass the delegate's `isSupported` (it matches `fr`) but then
  /// `load('fr_BE')` finds no asset and falls back to *English* — so we map it
  /// to `fr` here instead. Every locale the server's languages table offers
  /// ships as itself today, so this guards a locale the server adds later.
  @visibleForTesting
  static Locale bestSupportedLocale(String code) {
    if (code.isEmpty) return const Locale('en');
    final parts = code.split('_');
    final lang = parts[0];
    final country = parts.length > 1 ? parts[1] : null;
    // Shipped, but only as an explicit App Language choice.
    if (kOptInOnlyLanguages.contains(lang)) return const Locale('en');

    // Exact language+country match (e.g. pt_BR, en_GB).
    for (final l in kSupportedLocales) {
      if (l.languageCode == lang && l.countryCode == country) return l;
    }
    // Same language: prefer the country-less shipped entry (fr_BE → fr),
    // otherwise any same-language entry (nb_SJ → nb_NO).
    Locale? countryless;
    Locale? sameLang;
    for (final l in kSupportedLocales) {
      if (l.languageCode == lang) {
        sameLang ??= l;
        if (l.countryCode == null || l.countryCode!.isEmpty) countryless = l;
      }
    }
    return countryless ?? sameLang ?? const Locale('en');
  }

  @override
  void dispose() {
    _override.removeListener(_recompute);
    _auth.session.removeListener(_recompute);
    super.dispose();
  }
}
