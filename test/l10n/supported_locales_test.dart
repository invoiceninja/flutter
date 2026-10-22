import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/l10n/supported_locales.dart';

import '../_localization_helper.dart';

/// A locale is shipped in five places that nothing else ties together: the
/// runtime list, the two copies of the Transifex file map (the importer can't
/// import Flutter, so it carries its own), the App Language picker's names,
/// and the bundled asset. Miss one and the failure is quiet — a locale the
/// importer never refreshes, a picker row reading `nb_NO`, or a language that
/// loads English.
void main() {
  final keys = kSupportedLocales.map(localeKey).toList();

  test('every shipped locale has a Transifex file and a bundled asset', () {
    expect(kTransifexFileNames.keys.toSet(), keys.toSet());
    final missing = keys
        .where((k) => !File('assets/i18n/$k.json').existsSync())
        .toList();
    expect(missing, isEmpty, reason: 'No assets/i18n/<locale>.json');
  });

  test("the importer's copy of the file map matches the app's", () {
    final source = File(
      'tools/transifex_importer/bin/import.dart',
    ).readAsStringSync();
    final entries = {
      for (final m in RegExp(
        r"'([A-Za-z_]+)': '(textsphp-[a-z_]+\.php)'",
      ).allMatches(source))
        m.group(1)!: m.group(2)!,
    };
    expect(entries, kTransifexFileNames);
  });

  test('every shipped locale has an own-language name for the picker', () {
    expect(kLocaleNativeNames.keys.toSet(), keys.toSet());
  });

  test('Material and Cupertino ship strings for every locale', () {
    // An unsupported language leaves no MaterialLocalizations in the tree,
    // and the first date picker or back button throws.
    for (final locale in kSupportedLocales) {
      expect(
        GlobalMaterialLocalizations.delegate.isSupported(locale),
        isTrue,
        reason: '$locale',
      );
      expect(
        GlobalCupertinoLocalizations.delegate.isSupported(locale),
        isTrue,
        reason: '$locale',
      );
    }
  });

  test('locale keys are unique', () {
    expect(keys.toSet().length, keys.length);
  });

  test('exactly Arabic, Persian and Hebrew lay out right-to-left', () async {
    // `GlobalWidgetsLocalizations` is what sets `Directionality` from the
    // locale, so this is the direction the whole app is drawn in.
    final rtl = <String>[];
    for (final locale in kSupportedLocales) {
      final widgets = await GlobalWidgetsLocalizations.delegate.load(locale);
      if (widgets.textDirection == TextDirection.rtl) {
        rtl.add(localeKey(locale));
      }
    }
    expect(rtl, unorderedEquals(['ar', 'fa', 'he']));
  });

  test('no bundle carries a :placeholder its English lacks', () {
    // Translators rename tokens (`:arvo` for `:value`, `:day s` for `:days`)
    // and the app, filling the English name, renders the raw token. The
    // importer drops those; this catches a bundle that arrived another way.
    final english = {...pendingStrings(), ...enStrings()};
    Set<String> tokens(String s) => {
      for (final m in kLocalePlaceholderPattern.allMatches(s)) m.group(1)!,
    };
    final bad = <String>[];
    for (final key in keys.where((k) => k != 'en')) {
      final bundle =
          (jsonDecode(File('assets/i18n/$key.json').readAsStringSync()) as Map)
              .cast<String, Object?>();
      bundle.forEach((k, v) {
        final source = english[k];
        if (source == null || v is! String) return;
        if (!tokens(source).containsAll(tokens(v))) bad.add('$key → $k: "$v"');
      });
    }
    expect(bad, isEmpty, reason: bad.take(20).join('\n'));
  });

  test('a Traditional Chinese device gets zh_TW, never Simplified', () {
    // Flutter matches language + script before language alone, so the
    // scripts on the two zh entries decide this — without them the first
    // `zh` in the list (zh_CN) wins for a Hong Kong or Macau device.
    for (final device in const [
      Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
        countryCode: 'HK',
      ),
      Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
        countryCode: 'MO',
      ),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    ]) {
      final resolved = basicLocaleListResolution([device], kSupportedLocales);
      expect(localeKey(resolved), 'zh_TW', reason: '$device');
    }
  });

  test(
    'Material draws Serbian in the Latin script the app strings use',
    () async {
      final serbian = kSupportedLocales.firstWhere(
        (l) => l.languageCode == 'sr',
      );
      final material = await GlobalMaterialLocalizations.delegate.load(serbian);
      expect(
        RegExp(r'[\u0400-\u04FF]').hasMatch(material.cancelButtonLabel),
        isFalse,
        reason: material.cancelButtonLabel,
      );
    },
  );
}
