import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level guards for the log-a-call wiring (invoiceninja/flutter#120).
///
/// Scanned rather than exercised, for the two reasons this repo already writes
/// tests this way (`status_tab_wiring_test.dart`, `list_pagination_wiring_test.dart`):
/// reaching these paths for real needs the whole app graph, and every failure
/// here is **silent** — the button still renders, the sheet still opens, the
/// note is still saved. Both guards below encode a mistake that actually
/// shipped into this change and survived `flutter analyze`, `dart format` and
/// 6000 passing tests.
void main() {
  test('no detail screen ships a raw Dart template as a log-call subject', () {
    // `'#\$ {x.number}'` (without the space) is an *escaped* dollar in a
    // single-quoted Dart string, so the sheet titles itself with the literal
    // template text. It reads correctly at a glance, references the variable in
    // the surrounding ternary so nothing is unused, and is valid Dart — the
    // only thing that catches it is looking for the backslash.
    final offenders = <String>[];
    for (final file in _dartFiles('lib')) {
      final lines = file.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains(r'\${')) {
          offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'An escaped `\\\${` renders the template verbatim to the user. If a '
          'literal dollar-brace is ever genuinely wanted, use a raw string and '
          'exempt it here.\n${offenders.join('\n')}',
    );
  });

  test('every Activity tab that can write a note is passed both callbacks', () {
    // `EntityActivityTab.onAddComment` (then `BillingDocActivityTab`) shipped
    // as a declared-but-never-passed parameter: the button was dark on all
    // eight billing-doc screens for as long as it existed, and nothing failed.
    // `onLogCall` is the same shape, so pin the call sites rather than the
    // widget. The callbacks now travel as one `EntityNoteActions`, but the two
    // named arguments are still what a screen writes.
    //
    // Task and Project mount the same tab and must NOT be listed — neither
    // repository has an `addComment` for the callbacks to call, which is why
    // they pass `EntityNoteActions.none` rather than spelling the nulls out.
    //
    // An entry is a LIST of files, because the screen that builds the
    // callbacks and the widget that mounts the tab are the same file
    // everywhere except Client and Project, which extract a
    // `<Entity>DetailTabs`. The client's `EntityNoteActions` is built in the
    // screen and handed down, so checking the tabs file alone would demand a
    // second, duplicate construction — the very thing that type exists to
    // prevent.
    const eligible = <List<String>>[
      [
        'lib/ui/features/clients/views/client_detail_screen.dart',
        'lib/ui/features/clients/widgets/detail/client_detail_tabs.dart',
      ],
      ['lib/ui/features/invoices/views/invoice_detail_screen.dart'],
      ['lib/ui/features/quotes/views/quote_detail_screen.dart'],
      ['lib/ui/features/credits/views/credit_detail_screen.dart'],
      [
        'lib/ui/features/purchase_orders/views/purchase_order_detail_screen.dart',
      ],
      [
        'lib/ui/features/recurring_invoices/views/recurring_invoice_detail_screen.dart',
      ],
      ['lib/ui/features/payments/views/payment_detail_screen.dart'],
      ['lib/ui/features/expenses/views/expense_detail_screen.dart'],
      ['lib/ui/features/vendors/views/vendor_detail_screen.dart'],
    ];
    const ineligible = <String>[
      'lib/ui/features/tasks/views/task_detail_screen.dart',
      'lib/ui/features/projects/widgets/detail/project_detail_tabs.dart',
    ];

    for (final paths in eligible) {
      final src = paths
          .map(File.new)
          .map((f) => f.readAsStringSync())
          .join('\n');
      final label = paths.first;
      expect(
        src,
        contains('EntityActivityTab('),
        reason: '$label no longer mounts the tab — update this list',
      );
      for (final cb in ['onAddComment:', 'onLogCall:']) {
        expect(
          src,
          contains(cb),
          reason:
              '$label mounts the Activity tab but never passes $cb, so that '
              'button is dark on that screen',
        );
      }
    }

    // Both lists are hand-maintained, so a NEW entity that mounts the tab and
    // forgets `onLogCall:` would be caught by nothing at all. Derive the
    // candidate set instead of trusting the lists to be complete.
    const declaredIn =
        'lib/ui/features/billing_shared/activity/entity_activity_tab.dart';
    final known = {...eligible.expand((paths) => paths), ...ineligible};
    final unlisted = <String>[];
    for (final file in _dartFiles('lib')) {
      if (file.path == declaredIn || known.contains(file.path)) continue;
      // Comment-stripped like the two scans below, so a doc comment naming
      // the widget can't red the build.
      if (_stripComments(
        file.readAsStringSync(),
      ).contains('EntityActivityTab(')) {
        unlisted.add(file.path);
      }
    }
    expect(
      unlisted,
      isEmpty,
      reason:
          'this file mounts the Activity tab but is in neither list, so '
          'nothing checks whether its note buttons are wired. Add it to '
          '`eligible` (and pass both callbacks) or to `ineligible` (and pass '
          'neither).\n${unlisted.join('\n')}',
    );

    for (final path in ineligible) {
      final src = File(path).readAsStringSync();
      expect(
        src,
        contains('EntityActivityTab('),
        reason: '$path no longer mounts the tab — update this list',
      );
      for (final cb in ['onAddComment:', 'onLogCall:']) {
        expect(
          src.contains(cb),
          isFalse,
          reason:
              '$path passes $cb, but its repository has no addComment — '
              'add one deliberately before wiring the button',
        );
      }
    }
  });

  test('the log-call sheet never composes a time through Formatter.date', () {
    // `Formatter.date(v, showTime: true)` assumes a *server UTC* string — it
    // appends `Z` and calls `.toLocal()`. The sheet holds a local wall clock, so
    // routing it through there shifts the printed time by the device's offset.
    // Untestable by comparing output: the shift is zero on a UTC machine, which
    // is exactly what CI is. Only the source can be checked.
    final lines = File(
      'lib/ui/core/dialogs/log_call_sheet.dart',
    ).readAsLinesSync();
    // Prose about the trap is the point of documenting it — the same exemption
    // `no_can_launch_url_test.dart` makes.
    final code = lines
        .where((l) => !l.trimLeft().startsWith('//'))
        .toList(growable: false);
    expect(code.any((l) => l.contains('formatTimeOfDay(')), isTrue);
    expect(
      code.where((l) => l.contains('showTime: true')),
      isEmpty,
      reason:
          'compose the time with formatTimeOfDay — see the trap in '
          'docs/tap-to-call.md § Things that will bite you',
    );
  });

  test('every promptLogCallFor call site names the right party', () {
    // invoiceninja/flutter#129. The log-call sheet seeds its Contact field from
    // the candidate list it is handed and renders the contacts picker only when
    // that list is non-empty — so an arm that names no party opens a form with a
    // blank Contact field and no way to fill it but typing. That shipped on all
    // eight document entities, at every one of their 15 call sites, because only
    // Client and Vendor held a resolved record to build candidates from. Nothing
    // failed: the button rendered, the sheet opened, the note saved.
    //
    // The check is per-entity, not "either id", and that is the point. Every one
    // of these models ALSO declares a `vendorId` — `Invoice`, `Quote`, `Credit`,
    // `RecurringInvoice` and `Payment` all do, with a shipped Vendor list column
    // — so a plain "names some party" rule would accept
    // `vendorId: invoice.vendorId` and wave through exactly the mistake
    // `activity_note_actions.dart` warns about in prose.
    //
    // Two things this CANNOT catch, so a green run is not read as more than it
    // is: `clientId: x.clientId` where that field happens to be `''`, and a
    // party id that is simply the wrong record. A desync of the depth walk
    // below (a paren inside a string literal, or a `//` inside one that
    // `_stripComments` cuts at) is reported rather than thrown — see `fail`.
    const declaredIn = 'lib/ui/core/detail/activity_note_actions.dart';

    // Path fragment -> what that entity's call sites must pass. A document's
    // counterparty for a call note is whoever the note is about: the client who
    // owes an invoice, the vendor a purchase order goes to. Expense / recurring
    // expense / purchase order carry both and prefer the vendor, so both.
    const clientOnly = <String>[
      '/invoices/',
      '/quotes/',
      '/credits/',
      '/recurring_invoices/',
      '/payments/',
    ];
    const bothVendorFirst = <String>[
      '/expenses/',
      '/recurring_expenses/',
      '/purchase_orders/',
    ];

    final offenders = <String>[];
    var found = 0;

    for (final file in _dartFiles('lib')) {
      if (file.path == declaredIn) continue;
      final source = file.readAsStringSync();
      // Comment tails first, or the lint fails on the prose that explains it —
      // several detail screens mention the function by name.
      final code = _stripComments(source);
      for (final match in RegExp(r'\bpromptLogCallFor\s*\(').allMatches(code)) {
        found++;
        final line = '\n'.allMatches(code.substring(0, match.start)).length + 1;
        final where = '${file.path}:$line';

        // Walk to the matching `)` counting depth rather than reading a line or
        // a fixed window: that survives a `dart format` reflow, any argument
        // order, and a nested call such as `_confirmSubject(invoice)`.
        var depth = 0;
        var end = -1;
        for (var i = match.end - 1; i < code.length; i++) {
          final ch = code[i];
          if (ch == '(') depth++;
          if (ch == ')') {
            depth--;
            if (depth == 0) {
              end = i;
              break;
            }
          }
        }
        // Report rather than throw a RangeError out of `substring`: the two
        // ways to get here (a paren in a string literal, a `//` inside one) are
        // both fixable, and a stack trace from the matcher names neither.
        if (end < 0) {
          fail(
            '$where: could not find the end of this argument list. A paren or '
            'a `//` inside a string literal desynchronises the scan — see the '
            'comment above.',
          );
        }
        final args = code.substring(match.end, end);

        final client = args.contains('clientId:');
        final vendor = args.contains('vendorId:');

        if (clientOnly.any(file.path.contains)) {
          if (!client) offenders.add('$where: must pass clientId:');
          if (vendor) {
            offenders.add(
              '$where: must NOT pass vendorId: — this document declares one, '
              'but a call about it is a call to its client',
            );
          }
        } else if (bothVendorFirst.any(file.path.contains)) {
          if (!vendor) offenders.add('$where: must pass vendorId:');
          if (!client) offenders.add('$where: must pass clientId: as well');
        } else if (!client && !vendor) {
          // Client / Vendor themselves, and anything added later.
          offenders.add('$where: must pass clientId: or vendorId:');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'a log-call arm that names no party opens the sheet with no contacts, '
          'so its Contact field is blank and its picker icon absent — and '
          'nothing else in the suite can see it. One that names the WRONG party '
          'silently files the note against the wrong contact, into a row that '
          'is append-only (invoiceninja/flutter#129).\n${offenders.join('\n')}',
    );
    expect(
      found,
      greaterThanOrEqualTo(19),
      reason:
          'found only $found promptLogCallFor call sites, expected at least 19 '
          '— either the function was renamed or the per-entity arms were '
          'consolidated. Either way this guard has gone vacuous; re-point it '
          'rather than lowering the floor.',
    );
  });

  test('the log-call candidate builders never reach a dialer', () {
    // `clientCallLogCandidates` / `vendorCallLogCandidates` also carry contacts
    // with no stored number, which is right for "who did you speak to" and wrong
    // for "which number do I dial": handed to `PhoneCallButton` one produces a
    // dead tap with no toast, a tooltip ending in a bare `·`, and a long-press
    // that copies the empty string. `PhoneCallButton` asserts against it in
    // debug; this is what keeps the two lists apart in the first place.
    //
    // A file allowlist rather than a shape rule — "which files may know about
    // this" is the invariant that matters. Prose is already safe because the
    // scan strips comments first, so the name is matched bare rather than as
    // `symbol(`: a tear-off (`const build = clientCallLogCandidates;`) would
    // otherwise walk straight past it.
    const allowed = {
      'lib/domain/phone/phone_candidates.dart',
      'lib/ui/core/detail/activity_note_actions.dart',
    };
    final pattern = RegExp(r'\b(client|vendor)CallLogCandidates\b');
    final offenders = <String>[];
    for (final file in _dartFiles('lib')) {
      if (allowed.contains(file.path)) continue;
      final code = _stripComments(file.readAsStringSync());
      if (pattern.hasMatch(code)) offenders.add(file.path);
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'only the log-call path may build a candidate list that can contain '
          'a contact with no number.\n${offenders.join('\n')}',
    );
  });
}

/// Drop `//` comment tails so a scan reads code, not prose. Same helper, and
/// the same reason, as `no_list_tile_name_link_test.dart`: without it these
/// lints fail on the very comments that explain them.
String _stripComments(String source) => source
    .split('\n')
    .map((line) {
      final i = line.indexOf('//');
      return i == -1 ? line : line.substring(0, i);
    })
    .join('\n');

Iterable<File> _dartFiles(String root) => Directory(root)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));
