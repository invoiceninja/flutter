import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../_localization_helper.dart';

/// CI lint: every entity list's search field offers the same filter hint.
///
/// The placeholder is a single localization key threaded verbatim through
/// `EntityTokenSearchField` → `TokenSearchField` → `FilterEntrySheet`; nothing
/// derives it from the entity's declared `FilterKey`s, so the whole "or try
/// is:archived" affordance lives inside the translated string. Point one field
/// at a plain `search_<entity>` label and that list silently stops telling the
/// user the field takes filter tokens — even though `is:` still works there.
///
/// That shipped: Payments kept `search_payments` ("Search Payments") from its
/// original implementation, predating the `*_or_filter_hint` convention, and
/// commit 02f9e268 carried it across when the hand-written fields collapsed
/// into the shared widget. `shared_list_widgets_test` checks that a list screen
/// *uses* the shared field, not which key it hands over, so nothing caught it.
void main() {
  final fields = Directory('lib/ui/features')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('_token_search_field.dart'))
      .toList();

  // Otherwise a directory move or a renamed suffix turns each test below into
  // `expect([], isEmpty)` — green, and guarding nothing.
  test('the search-field scan still matches', () {
    expect(
      fields.length,
      greaterThan(10),
      reason:
          'only ${fields.length} *_token_search_field.dart found — the glob is '
          'no longer matching',
    );
  });

  final hintKey = RegExp(r"hintKey:\s*'([a-z0-9_]+)'");

  /// `<file basename>` → the key it passes.
  Map<String, String> declaredHintKeys() => {
    for (final f in fields)
      if (hintKey.firstMatch(f.readAsStringSync()) case final m?)
        f.uri.pathSegments.last: m.group(1)!,
  };

  test('every entity search field declares a hint key', () {
    final declared = declaredHintKeys();
    final missing = [
      for (final f in fields)
        if (!declared.containsKey(f.uri.pathSegments.last))
          f.uri.pathSegments.last,
    ];
    expect(
      missing,
      isEmpty,
      reason:
          'hintKey is a required parameter on both TokenSearchField and '
          'EntityTokenSearchField, so a file with none means the regex above '
          'no longer matches how it is written:\n  ${missing.join('\n  ')}',
    );
  });

  test('every entity search field uses the *_or_filter_hint convention', () {
    final offenders = [
      for (final e in declaredHintKeys().entries)
        if (!e.key.endsWith('_or_filter_hint'))
          if (!e.value.endsWith('_or_filter_hint')) '${e.key}: ${e.value}',
    ];
    expect(
      offenders,
      isEmpty,
      reason:
          'a plain search_<entity> label renders "Search Payments" where every '
          'other list renders "Search or try is:archived" — add a '
          'search_<entity>_or_filter_hint entry to assets/i18n/'
          '_app_pending.json and point the field at it:\n'
          '  ${offenders.join('\n  ')}',
    );
  });

  test('every hint key resolves to a real string, and they all agree', () {
    // Lookup is active locale → en.json → _app_pending.json → the raw key, so
    // an unresolved key paints its own name into the search box. Go through
    // the real Localization rather than re-deriving that precedence (and its
    // blank-counts-as-missing rule) here.
    final l10n = bundledLocalization();
    final rendered = {
      for (final e in declaredHintKeys().entries) e.key: l10n.lookup(e.value),
    };

    final unresolved = [
      for (final e in declaredHintKeys().entries)
        if (rendered[e.key] == e.value ||
            (rendered[e.key] ?? '').trim().isEmpty)
          '${e.key}: ${e.value}',
    ];
    expect(
      unresolved,
      isEmpty,
      reason:
          'these hint keys are in neither en.json nor _app_pending.json, so '
          'the search field renders the raw key:\n  ${unresolved.join('\n  ')}',
    );

    // The point of the convention: one placeholder, everywhere. Payments read
    // "Search Payments" and Bank Transactions "Search transactions or type
    // is:archived" while the other fifteen read "Search or try is:archived".
    expect(
      rendered.values.toSet(),
      hasLength(1),
      reason:
          'entity search fields render more than one placeholder:\n  '
          '${rendered.entries.map((e) => '${e.key}: "${e.value}"').join('\n  ')}',
    );
  });

  test('the app-local hint keys live in _app_pending.json, not en.json', () {
    // en.json is generated: tools/transifex_importer/bin/import.dart parses the
    // upstream PHP and writes each <locale>.json wholesale. A hand-added key
    // there is deleted by the next routine import, and the field then falls
    // through to the raw key. search_transactions_or_filter_hint shipped that
    // way for exactly this reason.
    final en = enStrings();
    final stranded = [
      for (final e in declaredHintKeys().entries)
        if (e.value.endsWith('_or_filter_hint') &&
            (en[e.value] ?? '').trim().isNotEmpty)
          '${e.key}: ${e.value}',
    ];
    expect(
      stranded,
      isEmpty,
      reason:
          'move these to assets/i18n/_app_pending.json — en.json is overwritten '
          'by the Transifex importer:\n  ${stranded.join('\n  ')}',
    );
  });
}
