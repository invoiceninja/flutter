import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:logging/logging.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/utils/perf_trace.dart';

final _log = Logger('ScriptFonts');

/// Each [kScriptFallbackFonts] family's bundled file. Plain assets, not
/// pubspec `fonts:` — the web engine downloads every declared font before the
/// first frame, and these are ~1.7 MB nobody reading English needs there.
const Map<String, String> kScriptFallbackFontAssets = {
  'Noto Sans Arabic': 'assets/fonts/NotoSansArabic.ttf',
  'Noto Sans Hebrew': 'assets/fonts/NotoSansHebrew.ttf',
  'Noto Sans Thai': 'assets/fonts/NotoSansThai.ttf',
  'Noto Sans Lao': 'assets/fonts/NotoSansLao.ttf',
  'Noto Sans Khmer': 'assets/fonts/NotoSansKhmer.ttf',
};

/// The script fallbacks text in [languageCode] needs.
List<String> scriptFontsForLanguage(String languageCode) =>
    switch (languageCode) {
      'ar' || 'fa' => const ['Noto Sans Arabic'],
      'he' => const ['Noto Sans Hebrew'],
      'th' => const ['Noto Sans Thai'],
      'lo' => const ['Noto Sans Lao'],
      'km' => const ['Noto Sans Khmer'],
      _ => const [],
    };

/// The latest, after the first frame, a native build registers the families
/// the UI language does not need (see [ScriptFonts.attach]). Normally they
/// load sooner — once launch work has settled ([ScriptFonts.launchSettled]);
/// this is for a launch that never gets there (the login screen, which has no
/// company to sweep). Offline the sweep fails fast, which is settled too:
/// nothing else is coming over the network to lay out.
const Duration kDeferredScriptFontsDelay = Duration(seconds: 30);

/// How long after launch work settles the deferred families load — the rows
/// the last request wrote are still being laid out for a frame or two.
const Duration kScriptFontsSettleGrace = Duration(seconds: 1);

/// How long the localization delegate waits on the UI language's family
/// before letting the first frame go without it (see
/// [ScriptFonts.loadForLocale]).
const Duration kScriptFontFirstFrameBudget = Duration(seconds: 2);

/// Registers the script fallback fonts with the engine.
///
/// **The UI language's family** loads from the localization delegate's
/// `load` ([loadForLocale]), which Flutter awaits before the first frame and
/// runs again on every language change, keyed off the locale Flutter actually
/// resolved. An Arabic, Hebrew, Thai, Lao or Khmer UI therefore paints its
/// first frame in its bundled font — on web, without CanvasKit fetching its
/// own fallback from fonts.gstatic.com first — and every other language pays
/// nothing.
///
/// **The other families** load natively only, once launch work has settled
/// ([launchSettled], the first sidebar prefetch sweep) or at the latest
/// [kDeferredScriptFontsDelay] after the first frame ([attach]), so an Arabic
/// client name in an English UI renders in the bundled font too. The trace
/// records which came first and when, so the launch window is measured on
/// real launches rather than guessed. Every `FontLoader.load` sends a
/// `fontsChange` that re-lays out every paragraph, so they are kept out of
/// the launch window and loaded together; until then the platform's own
/// font fallback draws those scripts (each OS ships fonts for them). On web
/// they never load: other scripts fall back to the engine as before.
///
/// A family named in a `fontFamilyFallback` before it is registered is
/// simply skipped, and registering one relays out the text that needs it.
/// See `docs/right-to-left-layout.md`.
class ScriptFonts {
  ScriptFonts._();

  static final Map<String, Future<void>> _loads = {};
  static Timer? _deferred;
  static bool _attached = false;
  static bool _settled = false;
  static Stopwatch? _sinceFirstFrame;

  /// Loads the families text in [locale]'s language needs, waiting at most
  /// [budget] — past it the load carries on and the text relays out when it
  /// lands, so a stuck asset read can never hold the first frame. Completes
  /// at once, with no work, for a language Inter Tight covers.
  static Future<void> loadForLocale(
    Locale locale, {
    Duration budget = kScriptFontFirstFrameBudget,
  }) {
    final families = scriptFontsForLanguage(locale.languageCode);
    if (families.isEmpty) return Future.value();
    return ensureLoaded(families).timeout(budget, onTimeout: () {});
  }

  /// Natively, schedule the families the UI language did not need. Web: no-op.
  static void attach() {
    if (kIsWeb || _attached) return;
    _attached = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_attached) return;
      _sinceFirstFrame = Stopwatch()..start();
      _deferred ??= Timer(
        kDeferredScriptFontsDelay,
        () => _loadDeferred('ceiling'),
      );
      if (_settled) _onSettled();
    });
  }

  /// Launch work is over: the first sidebar prefetch sweep has finished
  /// (`Services`). Brings the deferred load forward to
  /// [kScriptFontsSettleGrace] from now. Later calls do nothing.
  static void launchSettled() {
    if (kIsWeb || _settled) return;
    _settled = true;
    // Before the first frame, the post-frame callback in [attach] picks it up.
    if (_attached && _sinceFirstFrame != null) _onSettled();
  }

  static void _onSettled() {
    final pending = _deferred;
    if (pending == null || !pending.isActive) return;
    pending.cancel();
    _deferred = Timer(kScriptFontsSettleGrace, () => _loadDeferred('settled'));
  }

  /// What set off the last deferred load — `settled` or `ceiling` — or null.
  @visibleForTesting
  static String? lastDeferredTrigger;

  static void _loadDeferred(String trigger) {
    lastDeferredTrigger = trigger;
    unawaited(
      traceAsync(
        'scriptFonts.deferred',
        () => ensureLoaded(kScriptFallbackFonts),
        args: {
          'trigger': trigger,
          'sinceFirstFrameMs': _sinceFirstFrame?.elapsedMilliseconds,
        },
      ),
    );
  }

  /// Cancels a deferred load [attach] scheduled that has not run yet.
  static void detach() {
    _attached = false;
    lastDeferredTrigger = null;
    _settled = false;
    _sinceFirstFrame = null;
    _deferred?.cancel();
    _deferred = null;
  }

  /// The families a load has started for (and not failed).
  @visibleForTesting
  static Set<String> get requested => _loads.keys.toSet();

  /// Loads each of [families] once, side by side, so their `fontsChange`
  /// notices land together; a failure is logged, never thrown — the text then
  /// falls back as it would with no bundled font at all — and a later call
  /// retries it.
  static Future<void> ensureLoaded(Iterable<String> families) async {
    await Future.wait([
      for (final family in families)
        if (kScriptFallbackFontAssets[family] case final asset?)
          _loads[family] ??= _load(family, asset),
    ]);
  }

  static Future<void> _load(String family, String asset) =>
      traceAsync('scriptFonts.load', () async {
        try {
          await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
        } catch (e, st) {
          _loads.remove(family)?.ignore();
          _log.warning('Could not load $family from $asset', e, st);
        }
      }, args: {'family': family});
}
