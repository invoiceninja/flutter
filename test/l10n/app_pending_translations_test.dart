import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/l10n/supported_locales.dart';

import '../_localization_helper.dart';

/// CI lint over `assets/i18n/_app_pending_<locale>.json`, the per-locale
/// translations of the app-local strings.
///
/// The delegate lays each file over its locale's Transifex bundle wherever the
/// bundle has no real translation — absent, blank, or a copy of the English,
/// which is how Transifex exports a key nobody has translated yet. Coverage is
/// not required (a key missing here reads English), but every entry present
/// must be one the app can render:
///
/// - **A translation of an English string the app still has**, in
///   `_app_pending.json` or — once Transifex carries the key — `en.json`. An
///   entry may outlive its `_app_pending.json` line: that is what keeps the
///   language when the English reaches Transifex first.
/// - **Not shadowed by a real translation in the locale's bundle.** Once a
///   translator gets there the entry is dead, so delete it.
/// - **The same `:placeholders` as the English**, or a param is never filled
///   and the raw token renders (`no_unsubstituted_placeholders_test` resolves
///   English only).
void main() {
  final pending = pendingStrings()..remove('_comment');
  final en = enStrings();
  final nonEnglish = kSupportedLocales
      .where((l) => l.languageCode != 'en')
      .map(localeKey);

  Map<String, Object?> readJson(String path) =>
      (jsonDecode(File(path).readAsStringSync()) as Map)
          .cast<String, Object?>();
  String? nonBlank(Object? v) => v is String && v.trim().isNotEmpty ? v : null;

  test('no overlay file for a locale the app does not ship', () {
    final known = nonEnglish.map((k) => '_app_pending_$k.json').toSet();
    final stray = Directory('assets/i18n')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.startsWith('_app_pending_') && !known.contains(n))
        .toList();
    expect(stray, isEmpty, reason: 'Unknown overlay files: $stray');
  });

  for (final key in nonEnglish) {
    final path = 'assets/i18n/_app_pending_$key.json';
    if (!File(path).existsSync()) continue;

    group('_app_pending_$key.json', () {
      final overlay = readJson(path);
      final bundle = readJson('assets/i18n/$key.json');
      String? englishOf(String k) => nonBlank(pending[k]) ?? nonBlank(en[k]);

      test('translates only English the app still has', () {
        final orphans = overlay.keys.where((k) => englishOf(k) == null);
        expect(
          orphans,
          isEmpty,
          reason:
              'Neither _app_pending.json nor en.json has these any more — '
              'delete them:\n  ${orphans.join('\n  ')}',
        );
      });

      test('holds no blank value and nothing $key.json really translates', () {
        final blank = overlay.entries
            .where((e) => nonBlank(e.value) == null)
            .map((e) => e.key);
        final shadowed = overlay.keys.where((k) {
          final own = nonBlank(bundle[k]);
          return own != null && own != nonBlank(en[k]);
        });
        expect(blank, isEmpty, reason: 'Blank translations: $blank');
        expect(
          shadowed,
          isEmpty,
          reason:
              '$key.json now translates these, so the overlay entry never '
              'renders — delete it:\n  ${shadowed.join('\n  ')}',
        );
      });

      test('keeps every :placeholder of the English', () {
        List<String> tokens(String s) =>
            kLocalePlaceholderPattern
                .allMatches(s)
                .map((m) => m.group(1)!)
                .toList()
              ..sort();
        final mismatched = <String>[];
        overlay.forEach((k, v) {
          final english = englishOf(k);
          if (english == null || v is! String) return;
          if (tokens(english).join(',') != tokens(v).join(',')) {
            mismatched.add('$k: "$english" → "$v"');
          }
        });
        expect(mismatched, isEmpty, reason: mismatched.join('\n'));
      });

      // `IsFilterKey` labels the lifecycle chip with the app-owned
      // `entity_state_filter` precisely because Transifex's `entity_state`
      // collides with `status` in several languages — and the per-entity
      // Status chip sits right beside it.
      test('the State filter chip never reads the same as Status', () {
        final loc = Localization.forTesting(
          strings: bundle.map((k, v) => MapEntry(k, '$v')),
          localePending: overlay.map((k, v) => MapEntry(k, '$v')),
          fallback: en,
          pending: pending,
        );
        expect(
          loc.lookup('entity_state_filter').toLowerCase(),
          isNot(loc.lookup('status').toLowerCase()),
        );
      });
    });
  }
}
