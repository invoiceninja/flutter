import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:logging/logging.dart';

import 'package:admin/app/design_tokens.dart';

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

/// Registers the script fallback fonts with the engine, after the first
/// frame so they never hold it up. Natively every family loads (a local file
/// read), so an Arabic client name renders in an English UI too. On web only
/// the families the shown language needs load, and again whenever it changes;
/// other scripts there fall back to the engine's own (fonts.gstatic.com) as
/// before. A family named in a `fontFamilyFallback` before it is registered
/// is simply skipped, and registering one relays out the text that needs it.
class ScriptFonts {
  ScriptFonts._();

  static final Set<String> _requested = {};

  /// Start loading for [appLocale] (null: the device's), and follow it on web.
  static void attach(ValueListenable<Locale?> appLocale) {
    void load() => unawaited(
      ensureLoaded(
        kIsWeb
            ? scriptFontsForLanguage(
                (appLocale.value ?? PlatformDispatcher.instance.locale)
                    .languageCode,
              )
            : kScriptFallbackFonts,
      ),
    );
    SchedulerBinding.instance.addPostFrameCallback((_) {
      load();
      if (kIsWeb) appLocale.addListener(load);
    });
  }

  /// Loads each of [families] once; a failure is logged, never thrown — the
  /// text then falls back as it would with no bundled font at all.
  static Future<void> ensureLoaded(Iterable<String> families) async {
    for (final family in families) {
      final asset = kScriptFallbackFontAssets[family];
      if (asset == null || !_requested.add(family)) continue;
      try {
        await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
      } catch (e, st) {
        _requested.remove(family);
        _log.warning('Could not load $family from $asset', e, st);
      }
    }
  }
}
