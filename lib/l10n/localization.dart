import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import 'package:admin/l10n/supported_locales.dart';

final _log = Logger('Localization');

/// In-memory localization for a single locale. Keys map straight to strings;
/// placeholder interpolation uses the `:name` syntax that matches what the
/// existing admin-portal app uses (`activity_149` etc.).
class Localization {
  Localization._(
    this._strings, {
    Map<String, String>? fallback,
    Map<String, String>? pending,
  }) : _fallback = fallback ?? const {},
       _pending = pending ?? const {};

  final Map<String, String> _strings;
  final Map<String, String> _fallback;
  // App-local strings not yet submitted to Transifex. Loaded from
  // `assets/i18n/_app_pending.json`. Only consulted when neither the active
  // locale nor the Transifex English fallback has the key, so Transifex wins
  // automatically once it catches up.
  final Map<String, String> _pending;

  /// Lookup a key with optional `:name` placeholders.
  ///
  /// Missing keys return the raw key so a typo is immediately visible in
  /// the UI rather than silently rendering blank. An **empty** bundled value
  /// counts as missing: Transifex ships unfinished entries as `""` (three such
  /// keys are in every locale file today), and a plain `??` chain would return
  /// that empty string instead of falling through to English — rendering
  /// nothing at all, which for a toast means a blank card
  /// (invoiceninja/flutter#30).
  String lookup(String key, [Map<String, String>? params]) {
    // Sequential `??` rather than iterating a list of candidates: this backs
    // every `context.tr(...)` in the app (~4.6k call sites, nearly all inside
    // `build`), so it runs on essentially every rebuild — a per-call list
    // allocation here is pure waste. The common path (active-locale hit)
    // short-circuits on the first term, and `String.trim()` returns `this`
    // when there's nothing to trim, so a normal lookup allocates nothing.
    final raw =
        _nonBlank(_strings[key]) ??
        _nonBlank(_fallback[key]) ??
        _nonBlank(_pending[key]) ??
        key;
    if (params == null || params.isEmpty) return raw;
    if (params.length == 1) {
      final only = params.entries.first;
      return raw.replaceAll(':${only.key}', only.value);
    }
    // LONGEST NAME FIRST. `replaceAll` in map-insertion order is silently
    // wrong whenever one placeholder name prefixes another: substituting
    // `:time` into ":time in :timezone" first rewrites the *second* token to
    // "<value>zone", and the intended `:timezone` never matches. The result is
    // rendered garbage, not a missing string, so no `tr()` lint catches it —
    // and which of the two wins depends on the caller's literal map order.
    // Five bundled keys have colliding names today (`activity_10`, `_39`,
    // `_40`, `_41` pair `:payment` with `:payment_amount`;
    // `entity_number_placeholder` pairs `:entity` with `:entity_number`); the
    // activity templates dodge it only because they tokenize with a regex
    // instead of coming through here. Sorting costs nothing on the common
    // single-param path, which returned above.
    final names = params.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    var out = raw;
    for (final name in names) {
      out = out.replaceAll(':$name', params[name]!);
    }
    return out;
  }

  static Localization? of(BuildContext context) =>
      Localizations.of<Localization>(context, Localization);

  static const LocalizationsDelegate<Localization> delegate =
      _LocalizationDelegate();

  /// English fallback — loaded once via [_loadEnglishOnce] so every other
  /// locale can layer on top.
  static Map<String, String>? _englishCache;
  static Future<Map<String, String>>? _englishLoad;

  static Future<Map<String, String>> _loadEnglishOnce(AssetBundle bundle) {
    final cached = _englishCache;
    if (cached != null) return Future.value(cached);
    final inFlight = _englishLoad;
    if (inFlight != null) return inFlight;
    final fut = _loadAsset(bundle, 'en')
        .then((map) {
          _englishCache = map;
          _englishLoad = null;
          return map;
        })
        .catchError((Object e) {
          _englishLoad = null;
          // If English isn't bundled we still want the app to start — return
          // an empty map so every lookup falls through to the key. Log loudly:
          // an empty fallback means the whole asset bundle is unreadable
          // (e.g. AssetManifest.bin failed to load), which surfaces as raw
          // keys in the UI. This routes into the diagnostics log so a future
          // recurrence is identifiable in one line, not just as a
          // google_fonts symptom.
          _log.severe(
            'i18n English bundle unavailable — every string will render as '
            'its raw key. The asset bundle (AssetManifest.bin / '
            'assets/i18n/en.json) failed to load.',
            e,
          );
          return <String, String>{};
        });
    _englishLoad = fut;
    return fut;
  }

  static Map<String, String>? _pendingCache;
  static Future<Map<String, String>>? _pendingLoad;

  static Future<Map<String, String>> _loadPendingOnce(AssetBundle bundle) {
    final cached = _pendingCache;
    if (cached != null) return Future.value(cached);
    final inFlight = _pendingLoad;
    if (inFlight != null) return inFlight;
    final fut = bundle
        .loadString('assets/i18n/_app_pending.json')
        .then((raw) => compute(_decodeStringMap, raw))
        .then((map) {
          _pendingCache = map;
          _pendingLoad = null;
          return map;
        })
        .catchError((Object e) {
          _pendingLoad = null;
          return <String, String>{};
        });
    _pendingLoad = fut;
    return fut;
  }

  static Future<Map<String, String>> _loadAsset(
    AssetBundle bundle,
    String localeKey,
  ) async {
    final raw = await bundle.loadString('assets/i18n/$localeKey.json');
    // Large files — decode off the main isolate when possible.
    final decoded = await compute(_decodeStringMap, raw);
    return decoded;
  }

  // Test seam: lets the in-memory parser run without bundle plumbing.
  @visibleForTesting
  static Localization forTesting({
    required Map<String, String> strings,
    Map<String, String>? fallback,
    Map<String, String>? pending,
  }) => Localization._(strings, fallback: fallback, pending: pending);
}

/// The value itself, or null when it's absent or blank — so a blank bundled
/// entry falls through the lookup chain instead of ending it.
String? _nonBlank(String? value) =>
    value != null && value.trim().isNotEmpty ? value : null;

Map<String, String> _decodeStringMap(String raw) {
  final json = jsonDecode(raw);
  if (json is! Map) {
    throw FormatException('Expected JSON object, got ${json.runtimeType}');
  }
  return json.map((k, v) => MapEntry(k.toString(), v.toString()));
}

class _LocalizationDelegate extends LocalizationsDelegate<Localization> {
  const _LocalizationDelegate();

  @override
  bool isSupported(Locale locale) {
    return kSupportedLocales.any(
      (l) =>
          l.languageCode == locale.languageCode &&
          (l.countryCode == null || l.countryCode == locale.countryCode),
    );
  }

  @override
  Future<Localization> load(Locale locale) async {
    final fallback = await Localization._loadEnglishOnce(rootBundle);
    final pending = await Localization._loadPendingOnce(rootBundle);
    final key = localeKey(locale);
    if (key == 'en') {
      return Localization._(fallback, pending: pending);
    }
    try {
      final strings = await Localization._loadAsset(rootBundle, key);
      return Localization._(strings, fallback: fallback, pending: pending);
    } catch (_) {
      // Locale bundled in supported list but file missing (e.g. importer
      // not yet run) — fall back to English so the app still renders.
      return Localization._(fallback, pending: pending);
    }
  }

  @override
  bool shouldReload(_LocalizationDelegate old) => false;
}

extension LocalizationContext on BuildContext {
  /// Shorthand: `context.tr('save')` instead of
  /// `Localization.of(context)!.lookup('save')`.
  String tr(String key, [Map<String, String>? params]) =>
      Localization.of(this)?.lookup(key, params) ?? key;

  /// Optional shorthand: returns the localized string when the key is
  /// defined, or `null` when the bundle has no entry for it (the `lookup`
  /// default of returning the raw key would render the snake_case slug to
  /// the user — useless for optional help-text subtitles).
  ///
  /// Used by settings screens that want to surface a `*_help` line under a
  /// toggle when the translation exists, and render the toggle cleanly
  /// without a subtitle otherwise.
  String? trIfDefined(String key, [Map<String, String>? params]) {
    final loc = Localization.of(this);
    if (loc == null) return null;
    final raw = loc.lookup(key, params);
    if (raw == key) return null;
    return raw;
  }
}
