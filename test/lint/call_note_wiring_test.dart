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
}

Iterable<File> _dartFiles(String root) => Directory(root)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));
