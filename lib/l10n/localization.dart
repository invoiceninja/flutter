import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import 'package:admin/l10n/company_labels_scope.dart';
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
    Map<String, String>? overrides,
  }) : _fallback = fallback ?? const {},
       _pending = pending ?? const {},
       _overrides = overrides ?? const {};

  // The active locale's bundle, with its translations of the app-local
  // strings already laid in — see [_withLocalePending].
  final Map<String, String> _strings;
  final Map<String, String> _fallback;
  // App-local strings not yet submitted to Transifex. Loaded from
  // `assets/i18n/_app_pending.json`. Only consulted when neither the active
  // locale nor the Transifex English fallback has the key, so Transifex wins
  // automatically once it catches up.
  final Map<String, String> _pending;

  /// The active company's Custom Labels (`settings.translations`), consulted
  /// before every bundle — see [withOverrides]. Empty on the instance the
  /// delegate loads; [of] layers them on from `CompanyLabelsScope`.
  final Map<String, String> _overrides;

  /// Lookup a key with optional `:name` placeholders.
  ///
  /// Missing keys return the raw key so a typo is immediately visible in
  /// the UI rather than silently rendering blank. An **empty** bundled value
  /// counts as missing: Transifex ships unfinished entries as `""` (three such
  /// keys are in every locale file today), and a plain `??` chain would return
  /// that empty string instead of falling through to English — rendering
  /// nothing at all, which for a toast means a blank card
  /// (invoiceninja/flutter#30).
  ///
  /// The company's Custom Labels come first: a company that calls a quote an
  /// "Estimate" sees "Estimate" wherever the app says `quote`, as React does
  /// and as the server does on every PDF and email. [lookupBundled] skips them.
  ///
  /// The result is plain text, never wrapped in bidi isolates, even in a
  /// right-to-left locale: `tr()` output is also *data* — a logged call's
  /// note, an invoice line's task notes, a CSV header, a prefix match — and an
  /// invisible control character there is persisted, exported and compared.
  /// Isolate at render time instead (`LtrText`, `buildActivitySpans`); see
  /// docs/right-to-left-layout.md.
  String lookup(String key, [Map<String, String>? params]) =>
      _fill(_nonBlank(_overrides[key]) ?? _bundled(key), params);

  /// [lookup] without the company's Custom Labels — the word this app ships.
  ///
  /// For the few places that must not see an override: the Custom Labels
  /// screen, which shows each label beside the user's own wording of it, and
  /// code that matches a stored name against the bundled word (a task
  /// status's built-in colour).
  String lookupBundled(String key, [Map<String, String>? params]) =>
      _fill(_bundled(key), params);

  // Sequential `??` rather than iterating a list of candidates: this backs
  // every `context.tr(...)` in the app (~4.6k call sites, nearly all inside
  // `build`), so it runs on essentially every rebuild — a per-call list
  // allocation here is pure waste. The common path (active-locale hit)
  // short-circuits on the first term, and `String.trim()` returns `this`
  // when there's nothing to trim, so a normal lookup allocates nothing.
  String _bundled(String key) =>
      _nonBlank(_strings[key]) ??
      _nonBlank(_fallback[key]) ??
      _nonBlank(_pending[key]) ??
      key;

  static String _fill(String raw, Map<String, String>? params) {
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

  /// The English string for [key] — the Transifex English bundle, then the
  /// app-pending one — or null when neither has it. Never the raw key, so a
  /// caller matching text against it can't match on a key name.
  ///
  /// For matching, not rendering: settings search accepts the English label
  /// too, so a German UI still finds "Postal Code" when someone types the
  /// word the docs use.
  String? englishOf(String key) =>
      _nonBlank(_fallback[key]) ?? _nonBlank(_pending[key]);

  /// This instance with [overrides] consulted first — shares every bundle,
  /// so it costs one small map. Blank values never reach here
  /// (`companyLabelOverrides` drops them).
  Localization withOverrides(Map<String, String> overrides) {
    if (identical(overrides, _overrides)) return this;
    if (overrides.isEmpty && _overrides.isEmpty) return this;
    return Localization._(
      _strings,
      fallback: _fallback,
      pending: _pending,
      overrides: overrides,
    );
  }

  /// The last [withOverrides] result, for the map it was made with — so
  /// every `context.tr` in a frame shares one instance. Kept on the BUNDLE
  /// instance, so a locale switch, which loads a new one, starts afresh and
  /// never serves the old language's strings.
  Localization? _overlaid;
  Map<String, String>? _overlaidFor;

  Localization _overlay(Map<String, String> overrides) {
    if (overrides.isEmpty) return this;
    final cached = _overlaid;
    if (cached != null && identical(_overlaidFor, overrides)) return cached;
    _overlaidFor = overrides;
    return _overlaid = withOverrides(overrides);
  }

  /// The localization for [context]: the locale's bundles, with the active
  /// company's Custom Labels over them when a `CompanyLabelsScope` is above
  /// [context] (the app installs one around everything it shows). Depends on
  /// that scope, so a label saved, synced or switched away rebuilds every
  /// widget that read a string.
  static Localization? of(BuildContext context) {
    final base = Localizations.of<Localization>(context, Localization);
    if (base == null) return null;
    final labels = CompanyLabelsScope.labelsOf(context);
    return labels == null ? base : base._overlay(labels);
  }

  static const LocalizationsDelegate<Localization> delegate =
      _LocalizationDelegate();

  /// Start loading the English and pending bundles now, without waiting.
  ///
  /// Flutter holds the first frame until [delegate]'s `load` resolves, and that
  /// only begins once `runApp` has built `Localizations` — after the database
  /// open, the session restore and the statics warm-up. Called from `main()`
  /// ahead of all three, so the two bundles every locale needs load alongside
  /// that work and `load` usually finds them cached.
  ///
  /// Never awaited, and never throws: each loader already swallows its own
  /// failure (English falls back to an empty map, loudly), so nothing here can
  /// keep boot from reaching `runApp`.
  static void prewarm({AssetBundle? bundle}) {
    final from = bundle ?? rootBundle;
    try {
      unawaited(_loadEnglishOnce(from));
      unawaited(_loadPendingOnce(from));
    } catch (e, st) {
      _log.warning('i18n prewarm could not start', e, st);
    }
  }

  /// Forget the bundles [prewarm] and [delegate] cache for the process.
  @visibleForTesting
  static void resetCachesForTest() {
    _englishCache = null;
    _englishLoad = null;
    _pendingCache = null;
    _pendingLoad = null;
  }

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

  /// [strings] — the locale's Transifex bundle — with [localePending], its
  /// translations of the app-local strings
  /// (`assets/i18n/_app_pending_<locale>.json`), laid over every entry the
  /// bundle has not really translated: absent, blank, or the [english] text
  /// itself. That last case is the common one, not an edge: Transifex exports
  /// an untranslated key as its source string, so once an app-local key
  /// reaches Transifex in English every bundle carries that English until a
  /// translator gets to it — and a plain "locale bundle first" lookup would
  /// put the user back on English. A real Transifex translation still wins.
  ///
  /// Merged once per load rather than consulted per lookup, so [_bundled]
  /// keeps its short chain.
  static Map<String, String> _withLocalePending(
    Map<String, String> strings,
    Map<String, String>? localePending,
    Map<String, String>? english,
  ) {
    if (localePending == null || localePending.isEmpty) return strings;
    final merged = Map.of(strings);
    localePending.forEach((key, value) {
      if (_nonBlank(value) == null) return;
      final own = _nonBlank(strings[key]);
      if (own == null || own == english?[key]) merged[key] = value;
    });
    return merged;
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
    Map<String, String>? localePending,
    Map<String, String>? fallback,
    Map<String, String>? pending,
    Map<String, String>? overrides,
  }) => Localization._(
    _withLocalePending(strings, localePending, fallback),
    fallback: fallback,
    pending: pending,
    overrides: overrides,
  );
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
    final key = localeKey(locale);
    // All four started before any is awaited. Each is a file read plus an
    // isolate hop, and Flutter holds the first frame until this resolves — one
    // after another they cost four round trips where one will do. The first
    // two are usually done already (`Localization.prewarm`).
    final fallbackLoad = Localization._loadEnglishOnce(rootBundle);
    final pendingLoad = Localization._loadPendingOnce(rootBundle);
    // Locale bundled in supported list but file missing (e.g. importer not yet
    // run) — fall back to English so the app still renders. Folded to null
    // here rather than caught below: while the two loads above are still being
    // awaited nothing is listening to this one, and an error with no listener
    // is an unhandled one.
    final stringsLoad = key == 'en'
        ? null
        : Localization._loadAsset(
            rootBundle,
            key,
          ).then<Map<String, String>?>((m) => m, onError: (Object _) => null);
    // English needs no translation of the app-local strings, and a locale
    // nobody has translated them into yet has no file — both read English.
    final localePendingLoad = locale.languageCode == 'en'
        ? null
        : Localization._loadAsset(
            rootBundle,
            '_app_pending_$key',
          ).then<Map<String, String>?>((m) => m, onError: (Object _) => null);
    final fallback = await fallbackLoad;
    final pending = await pendingLoad;
    final strings = stringsLoad == null ? null : await stringsLoad;
    final localePending = localePendingLoad == null
        ? null
        : await localePendingLoad;
    if (strings == null && localePending == null) {
      return Localization._(fallback, pending: pending);
    }
    return Localization._(
      Localization._withLocalePending(
        strings ?? const {},
        localePending,
        fallback,
      ),
      fallback: fallback,
      pending: pending,
    );
  }

  @override
  bool shouldReload(_LocalizationDelegate old) => false;
}

extension LocalizationContext on BuildContext {
  /// Shorthand: `context.tr('save')` instead of
  /// `Localization.of(context)!.lookup('save')`.
  String tr(String key, [Map<String, String>? params]) =>
      Localization.of(this)?.lookup(key, params) ?? key;

  /// [tr] without the company's Custom Labels — see
  /// [Localization.lookupBundled].
  String trBundled(String key, [Map<String, String>? params]) =>
      Localization.of(this)?.lookupBundled(key, params) ?? key;

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
