import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../_localization_helper.dart';

/// CI lint: no bundled string reaches the UI with a Laravel-style `:token`
/// still in it.
///
/// Transifex ships two flavours of many strings — a parameterised one for the
/// case where the app knows the value (`add_to_invoice` = "Add to invoice
/// :invoice") and a plain verb for the case where it doesn't
/// (`action_add_to_invoice` = "Add To Invoice"). Pointing a menu label at the
/// former renders the raw token to the user; that shipped as
/// invoiceninja/flutter#35 and a sweep found ~24 more instances of the same
/// defect (copy toasts, gateway field labels, confirm dialogs).
///
/// The fix at a call site is always one of: pass the params, point at a
/// placeholder-free key, or — if the bundle has no clean variant — add a
/// distinctly-named key to `_app_pending.json` (`*_label` / `*_short`). Note
/// that file can only *add* a key: lookup is active locale → `en.json` →
/// pending, so a pending entry duplicating a Transifex key never renders.
///
/// ## What this does NOT catch
///
/// Deliberately stated rather than implied — the checks are text scans, so:
///
/// 1. A key held in a variable, a const list, or a **positional** constructor
///    argument is invisible. That is how the `invoice_sent` leak hid, behind
///    `_EventDef('invoice_sent', 'invoice_sent')`, and it is why
///    `plan_gate_banner`'s record-returning `_gateCopy` is unwatched. Where a
///    renderer takes keys from a structure, assert the invariant in that
///    structure's own test — `settings_search_catalog_test` does this for
///    `kSettingsSearchCatalog`.
/// 2. Check B watches only the named parameters in [_keyParamNames]; a new
///    key-carrying parameter name has to be added there or it goes unwatched.
/// 3. Only English + pending are resolved. A locale whose translation carries
///    a token English lacks is not caught — and note that blanking a token is
///    *not* a safe general fix for that reason: German and Japanese put
///    `:invoice` mid-string, where a `.trim()` can't clean up after it.
/// 4. A chained `.replaceAll(':x', …)` is trusted without checking which token
///    it targets.
/// 5. A key that resolves *nowhere* is not reported, though production renders
///    the raw key. There is no repo-wide "every key exists" check.
/// 6. Check C matches any map literal keyed `':name':`. Nothing in `lib/` uses
///    that shape for a non-translation purpose today (go_router's
///    `path: ':id'` is followed by a comma, so it doesn't match), but a
///    rename map — collapsing the duplicated `replaceAll(':user', ':contact')`
///    in `activity_description.dart` / `activity_formatter.dart` into
///    `const {':user': ':contact'}` would be the obvious refactor — would
///    false-fail with a message telling the author to delete a needed colon.
void main() {
  test('_app_pending.json holds no entry shadowed by en.json', () {
    // Lookup is active locale → en.json → pending, so a pending entry whose
    // key already has a non-blank English value can never render. It reads
    // like a fix and does nothing — `fees_sample` sat dead long enough to
    // leave the gateway fee preview naming the *total* as the fee, and 40
    // more were dead alongside it. Need different wording than Transifex
    // ships? Give it a distinct name (`*_label`, `*_short`, `*_detailed`).
    final en = enStrings();
    final pending = pendingStrings();
    final shadowed = pending.keys
        .where((k) => (en[k] ?? '').trim().isNotEmpty)
        .map((k) => '$k: pending "${pending[k]}" vs en "${en[k]}"')
        .toList();
    expect(
      shadowed,
      isEmpty,
      reason:
          'These _app_pending.json entries are shadowed by en.json and never '
          'render. Delete them, or rename to a distinct key if the wording '
          'is deliberate. Found:\n  ${shadowed.join('\n  ')}',
    );
  });

  test('lib/ renders no bundled string with an unsubstituted :placeholder', () {
    final l10n = bundledLocalization();

    // Ask the real `Localization.lookup` what an English user sees, rather
    // than re-deriving its en → pending precedence and blank-counts-as-missing
    // rule here. A key that resolves nowhere comes back as itself; skip those
    // (see limitation 5 below) so a raw key can't masquerade as a leak.
    String? resolve(String key) {
      final value = l10n.lookup(key);
      return value == key ? null : value;
    }

    List<String> placeholdersIn(String value) => kLocalePlaceholderPattern
        .allMatches(value)
        .map((m) => m.group(1)!)
        .toList();

    final offenders = <String>[];
    var scanned = 0;

    for (final file in _dartFiles()) {
      // Blank out comments first. Nine `///` blocks in `lib/` already quote a
      // `tr('key')` call while explaining an API, and this very defect class
      // is one people document in prose — a lint that reds the build on
      // documentation would just get deleted. Offsets are preserved so line
      // numbers still point at the real source.
      final content = _stripComments(file.readAsStringSync());

      // ── Check A: `tr('key')` with no params ──────────────────────────────
      // Matches `tr('k')`, `context.tr('k')`, `.tr('k')`, `trIfDefined('k')`,
      // and `lookup('k')` — plus the trailing-comma form `dart format` emits
      // when the call wraps. A call that passes params has an argument after
      // that comma and can't match.
      for (final match in _bareTrCall.allMatches(content)) {
        scanned++;
        // The house idiom `context.tr('k').replaceAll(':x', v)` substitutes
        // outside the params map — treat a chained replace as handled. The
        // window has to clear the worst real layout: a `.trim()` in the chain
        // at deep indentation costs ~120 characters, and falling short here
        // reds the build on correct code.
        final tail = content.substring(
          match.end,
          (match.end + 200).clamp(0, content.length),
        );
        if (_chainedReplace.hasMatch(tail)) continue;

        final key = match.group(1)!;
        final value = resolve(key);
        if (value == null) continue;
        final tokens = placeholdersIn(value);
        if (tokens.isEmpty) continue;
        offenders.add(
          '${file.path}:${_lineOf(content, match.start)}  '
          "tr('$key') renders '$value' — ${tokens.map((t) => ':$t').join(', ')} "
          'is never substituted',
        );
      }

      // ── Check B: a locale key handed to a renderer as a named param ──────
      for (final match in _namedKeyParam.allMatches(content)) {
        final param = match.group(1)!;
        final isCountValue = _countValueKeyParamNames.contains(param);
        if (!isCountValue && !_keyParamNames.contains(param)) continue;

        final key = match.group(2)!;
        final value = resolve(key);
        if (value == null) continue;
        final tokens = placeholdersIn(value).toSet();
        // `formatBulkMessage` fills :count and :value on the plural key.
        if (isCountValue) tokens.removeAll(const {'count', 'value'});
        if (tokens.isEmpty) continue;
        offenders.add(
          '${file.path}:${_lineOf(content, match.start)}  '
          "$param: '$key' renders '$value' — "
          '${tokens.map((t) => ':$t').join(', ')} is never substituted',
        );
      }

      // ── Check C: params map keyed with a leading colon ───────────────────
      // `lookup` prepends the ':' itself, so `{':user': …}` searches for
      // '::user' and silently substitutes nothing.
      for (final match in _colonPrefixedParamKey.allMatches(content)) {
        offenders.add(
          '${file.path}:${_lineOf(content, match.start)}  '
          "params key '${match.group(1)}' has a leading colon — "
          "Localization.lookup adds it, so use '${match.group(1)!.substring(1)}'",
        );
      }
    }

    // Guard against a silently-broken regex passing green. There are ~4 200
    // param-less `tr()` calls today.
    expect(
      scanned,
      greaterThan(3000),
      reason:
          'Only $scanned tr() calls matched — the scan regex is probably '
          'broken, so an empty offender list means nothing.',
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'A bundled string is rendered with its :placeholder intact. Pass the '
          'params, point at a placeholder-free key, or add a distinctly-named '
          'key to assets/i18n/_app_pending.json. Found:\n  '
          '${offenders.join('\n  ')}',
    );
  });
}

// The placeholder pattern lives in `test/_localization_helper.dart`
// (`kLocalePlaceholderPattern`) so this lint and the per-structure invariant
// tests can't drift apart. Verified against every value in both bundles: no
// false positives, so no allowlist is needed.

final _bareTrCall = RegExp(
  r"""\b(?:tr|trIfDefined|lookup)\(\s*'([a-z0-9_]+)'\s*,?\s*\)""",
);

/// Replaces `//` line comments and `/* … */` blocks with spaces, preserving
/// length so byte offsets (and therefore line numbers) stay correct. String
/// literals are respected so a `'http://x'` doesn't swallow the rest of a line.
String _stripComments(String source) {
  final out = source.split('');
  var i = 0;
  String? quote;
  while (i < source.length) {
    final c = source[i];
    if (quote != null) {
      if (c == r'\') {
        i += 2;
        continue;
      }
      if (c == quote) quote = null;
      i++;
      continue;
    }
    if (c == "'" || c == '"') {
      quote = c;
      i++;
      continue;
    }
    if (c == '/' && i + 1 < source.length) {
      final next = source[i + 1];
      if (next == '/') {
        while (i < source.length && source[i] != '\n') {
          out[i++] = ' ';
        }
        continue;
      }
      if (next == '*') {
        final end = source.indexOf('*/', i + 2);
        final stop = end == -1 ? source.length : end + 2;
        for (var j = i; j < stop; j++) {
          if (out[j] != '\n') out[j] = ' ';
        }
        i = stop;
        continue;
      }
    }
    i++;
  }
  return out.join();
}

final _chainedReplace = RegExp(
  r'^(?:\s*\.(?:trim|toUpperCase|toLowerCase)\(\))*\s*\.(?:replaceAll|replaceFirst)\(',
);

final _namedKeyParam = RegExp(
  r"\b([A-Za-z_][A-Za-z0-9_]*)\s*[:=]\s*'([a-z0-9_]+)'",
);

final _colonPrefixedParamKey = RegExp(r"'(:[a-z][a-z0-9_]*)'\s*:");

/// Named parameters that carry a localization key to a renderer which looks it
/// up with no params. Explicit list, not a `*Key` wildcard — `apiKey`,
/// `fieldKey`, `permissionKey`, `patternKey` and friends are not locale keys.
const _keyParamNames = <String>{
  'labelKey',
  'tooltipKey',
  'disabledTooltipKey',
  'hintKey',
  'hintTextKey',
  'nothingKey',
  'singleSuccessKey',
  'titleKey',
  'subtitleKey',
  'descriptionKey',
  'messageKey',
  'emptyTitleKey',
  'emptyHintKey',
  'emptyMessageKey',
  'sectionTitleKey',
  'headerKey',
  'headingKey',
  'createTitleKey',
  'editTitleKey',
  'idleLabelKey',
  'addLabelKey',
  'newLabelKey',
  'confirmKey',
  'successKey',
  'placeholderKey',
  'helpKey',
};

// Only add a parameter here when its renderer looks the key up with **no**
// params. Deliberately NOT watched:
//   * `errorKey` — a record field on `login_view_model`'s result types,
//     substituted at the caller (`context.tr(vm.errorKey!, vm.errorParams)`).
//   * `body` — `user_detail_screen._confirmAction` passes a params map to
//     `ctx.tr(body, params)`, so its `confirm_*_user_body` keys are meant to
//     carry tokens. (Check C guards the failure mode that actually bit there:
//     params keyed `':user'` instead of `'user'`.)
//   * `apiKey` / `fieldKey` / `permissionKey` / `patternKey` — not locale keys.

/// Keys whose renderer substitutes `:count` and `:value` (`formatBulkMessage`)
/// — any *other* token in the string is still a leak.
const _countValueKeyParamNames = <String>{'pluralSuccessKey'};

Iterable<File> _dartFiles() sync* {
  final libDir = Directory('lib');
  expect(libDir.existsSync(), isTrue, reason: 'lib/ should exist');
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.endsWith('.g.dart')) continue;
    if (entity.path.endsWith('.freezed.dart')) continue;
    yield entity;
  }
}

int _lineOf(String content, int offset) =>
    '\n'.allMatches(content.substring(0, offset)).length + 1;
