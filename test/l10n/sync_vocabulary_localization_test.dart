import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the user-facing vocabulary of the Sync pass (push queued outbox
/// edits, then re-download every entity — `Services.syncNow`).
///
/// Three failure modes, all silent:
///
///  1. **A key stops resolving.** `Localization.lookup` (`lib/l10n/
///     localization.dart:36`, reached via the `context.tr` extension) falls
///     back to the raw snake_case key when it's in neither `en.json` nor
///     `_app_pending.json`, so the button would read `sync` instead of "Sync".
///     That's a live risk: `_app_pending.json`'s own `_comment` instructs you to
///     delete an entry once Transifex carries the key, and `sync` is *not*
///     currently in this project's `en.json` even though upstream Transifex has
///     it. Deleting it before an import that actually lands it ships a slug.
///
///  2. **The wording drifts back apart.** Issue #15: one action was exposed as
///     "Download" (Device Settings), "Force full resync" (Account Management)
///     and "Sync" (sidebar). Three names for one button read as three features
///     — and "Download" specifically was mistaken for a Google Takeout-style
///     export.
///
///  3. **A call site reverts to a retired key.** The nastiest one: `download`
///     ("Download") and `download_data` ("Press button below to download the
///     data.") still exist in Transifex-owned `en.json` and can't be deleted
///     from here, so `tr('download')` would render the pre-rename wording
///     perfectly while every JSON-level check above stayed green. Only a scan
///     of the Dart sources catches it.
void main() {
  // Every key in the Sync *vocabulary*, across the surfaces that render it:
  // the sidebar header button, Settings → Device Settings → Data, Settings →
  // Account Management → Overview → Data, the shared outcome toasts in
  // `SettingsActions.forceResync`, and the settings-search label
  // (`settings_search_catalog.dart:431`).
  //
  // Deliberately excludes `data` and `last_updated`, which those cards also
  // render: they're generic app-wide en.json labels, not Sync wording.
  //
  // Two entries are shared with unrelated features, so rewording either means
  // splitting the key first: `sync_now` also labels `sync_first_banner.dart:57`
  // (flush one record's outbox row, not the full pass), and `sync_failed` also
  // labels a dead outbox row in `outbox_screen.dart:322` plus both the error
  // toast (`confirm_pending_outbox.dart:135`) and the ternary-selected title
  // (`:163`) in the pending-outbox dialog.
  const syncKeys = <String>{
    'sync', // Device Settings button label
    'sync_data_help', // Device Settings body copy
    'sync_now', // sidebar tooltip (idle)
    'syncing', // sidebar tooltip (running, total unknown)
    'syncing_progress', // all three surfaces, running
    'sync_in_progress', // another company's pass holds the lock
    'sync_complete', // shared success toast
    'sync_failed', // shared failure toast
    'force_full_sync', // Account Management tile title
    'force_sync_description', // Account Management tile subtitle
  };

  // Retired by issue #15. `download` / `download_data` are not in this list:
  // they're Transifex keys that legitimately survive in en.json for the
  // file-download features — they're only forbidden at a Sync *call site*,
  // which the source scan below enforces.
  //
  // `sync_failed_with_error` was deleted alongside these but is deliberately
  // absent: it was dead code, not retired wording. Re-adding it would be
  // legitimate (the vocabulary is already right), so failing on it would be a
  // false alarm.
  const retiredKeys = <String>{
    'download_complete',
    'download_data_help',
    'download_failed',
    'force_full_resync',
    'force_resync_description',
    'resync_complete',
    'resync_failed',
    'resync_failed_with_error',
  };

  // The widgets that render the Sync vocabulary, scanned as source text.
  const syncSources = <String>[
    'lib/ui/features/settings/views/basic/device_settings_screen.dart',
    'lib/ui/features/settings/views/basic/account_management/overview_screen.dart',
    'lib/ui/features/shell/widgets/sidebar_sync_button.dart',
    'lib/ui/features/settings/settings_actions.dart',
  ];

  test('every Sync localization key resolves', () {
    final resolved = _resolvedStrings();
    final missing = syncKeys.where((k) => !resolved.containsKey(k)).toList()
      ..sort();
    expect(
      missing,
      isEmpty,
      reason:
          'The Sync action uses these keys but neither en.json nor '
          '_app_pending.json defines them — they would render as raw slugs. '
          'If you removed one from _app_pending.json because Transifex now '
          'carries it, confirm the import actually landed it in '
          'en.json:\n${missing.join('\n')}',
    );
  });

  test('the Sync action speaks one vocabulary', () {
    final resolved = _resolvedStrings();
    // Word-anchored, NOT `contains('sync')` — "reSYNC" contains "sync", so a
    // plain substring test would wave "Force full resync" straight through and
    // guard only half of what issue #15 retired.
    final saysSync = RegExp(r'\bsync', caseSensitive: false);
    final offenders = <String>[];
    for (final key in syncKeys) {
      // `sync_data_help` / `force_sync_description` legitimately describe the
      // mechanics ("…then download a fresh copy…"); only the labels and the
      // toasts are held to the vocabulary.
      if (key.endsWith('_help') || key.endsWith('_description')) continue;
      final value = resolved[key];
      if (value == null) continue; // reported by the test above
      if (!saysSync.hasMatch(value)) offenders.add('$key => "$value"');
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Every Sync label and toast must say "sync" (issue #15). These no '
          'longer do — or say "resync", the wording the issue retired — so the '
          'sidebar button, Device Settings and Account Management would again '
          'look like three different features:\n${offenders.join('\n')}',
    );
  });

  test('no Sync surface renders a retired key', () {
    final rendered = _trKeysFromSources(syncSources);

    // Sanity floor: without it a broken regex returns nothing and the
    // assertion below passes vacuously. A count floor would be too weak —
    // `overview_screen.dart` alone contributes 23 of the ~36 keys, almost all
    // unrelated account-management vocabulary, so any threshold it satisfies
    // says nothing about the other three files. Pin one Sync key per scanned
    // file instead. `sync_now` is the load-bearing one: it is only reachable
    // through the ternary form at `sidebar_sync_button.dart:66`, so it also
    // guards the scanner itself (see `_trKeysFromSources`).
    expect(
      rendered,
      containsAll([
        'sync', // device_settings_screen.dart
        'sync_data_help', // device_settings_screen.dart
        'sync_now', // sidebar_sync_button.dart (ternary argument)
        'sync_complete', // settings_actions.dart
        'force_full_sync', // account_management/overview_screen.dart
      ]),
      reason:
          'tr() scan returned ${rendered.length} keys but missed a known Sync '
          'call site — the scan is broken or a file moved, and the assertion '
          'below would pass vacuously',
    );

    // `download` / `download_data` are the trap: both still resolve from
    // en.json, so reverting a call site to either renders the pre-rename
    // wording with no other test noticing.
    final forbidden = {...retiredKeys, 'download', 'download_data'};
    final used = rendered.intersection(forbidden).toList()..sort();
    expect(
      used,
      isEmpty,
      reason:
          'A Sync surface renders wording retired by issue #15. Use the '
          '`sync_*` / `force_full_sync` keys instead — note `download` and '
          '`download_data` still resolve from en.json, so this renders the old '
          'wording without failing any other test:\n${used.join('\n')}',
    );
  });

  test('the retired keys stay out of _app_pending.json', () {
    // Scoped to _app_pending.json — the file we own. en.json is regenerated by
    // the Transifex importer and legitimately carries unrelated `download_*`
    // keys (download_pdf, download_documents, …) this rename never touched.
    final pending = _readJson('assets/i18n/_app_pending.json');
    final resurrected = retiredKeys.where(pending.containsKey).toList()..sort();
    expect(
      resurrected,
      isEmpty,
      reason:
          'These keys were retired when the Sync vocabulary was unified '
          '(issue #15) — a re-added one means a surface has drifted back to '
          'its own wording. Fix the surface; use the `sync_*` / '
          '`force_full_sync` keys:\n${resurrected.join('\n')}',
    );
  });
}

/// The strings `context.tr()` would resolve for an English user, in production
/// precedence: `en.json` wins over `_app_pending.json` (see
/// `Localization.lookup`, `lib/l10n/localization.dart:36`).
Map<String, String> _resolvedStrings() => {
  ..._readJson('assets/i18n/_app_pending.json'),
  ..._readJson('assets/i18n/en.json'),
};

Map<String, String> _readJson(String path) {
  final json =
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return json.map((k, v) => MapEntry(k, v.toString()));
}

/// Extracts the key literals from every line that calls `.tr(` in [paths].
///
/// Deliberately line-scoped rather than anchored on `.tr('` the way
/// `email_settings_localization_test`'s twin is: that form silently skips
/// `context.tr(cond ? 'a' : 'b')`, and `sidebar_sync_button.dart:66` is exactly
/// that shape — so an anchored scan would have read only 2 of its 4 keys and
/// waved through a revert of the Sync tooltip to `'download'`. (The sibling
/// documents "no `tr(variable)` on this screen" as a precondition; it does not
/// hold here.) The `containsAll` floor above pins `sync_now`, which only the
/// line-scoped form can reach, so this can't silently regress.
///
/// Requiring `.tr(` on the line keeps a key merely *mentioned* in a comment
/// (e.g. the `download_data` warning in `device_settings_screen.dart`) out of
/// the set. A stray non-key literal sharing a line with a `.tr(` call would be
/// collected too — harmless, since the set is only tested for forbidden keys.
Set<String> _trKeysFromSources(List<String> paths) {
  final literal = RegExp('''(['"])([a-z0-9_]+)\\1''');
  final keys = <String>{};
  for (final path in paths) {
    for (final line in File(path).readAsLinesSync()) {
      if (!line.contains('.tr(')) continue;
      for (final m in literal.allMatches(line)) {
        keys.add(m.group(2)!);
      }
    }
  }
  return keys;
}
