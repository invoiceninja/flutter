import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI lint: a **narrow list row has exactly one destination**, so a
/// cross-entity `*NameLabel(link: true)` may never appear on one.
///
/// invoiceninja/flutter#128. `linkOrText` builds a `LinkText` whose
/// `GestureDetector` is `HitTestBehavior.opaque`, and it sits *inside* the
/// row's own `InkWell` — so it wins the gesture arena for every tap that lands
/// on the name and the row's "open this record" tap never fires. Nine tiles
/// shipped that way: the client name was a 12 px muted-grey subtitle directly
/// under the invoice number, styled like ordinary secondary text (the hover
/// underline that says "link" on a pointer platform can never fire on touch),
/// so an unpredictable share of row taps landed on the client instead. In
/// multi-select it was worse — the link still won, so the tap navigated away
/// instead of toggling, and the `⋮` is hidden in that mode.
///
/// A link is legitimate where the slot is **labelled** (a wide-table column
/// under a `Client` header — those registries live in `lib/domain/columns/`,
/// outside this scan) or where nothing competes for the tap (a detail
/// surface). Everything else under `lib/ui/features/` is a row or a card whose
/// own tap opens the record.
///
/// The allowlist names the *permitted* files rather than globbing the
/// forbidden ones on purpose: scoping this to `*_list_tile.dart` would miss a
/// `link: true` added to `kanban_card.dart`, `task_daily_entry_row.dart`,
/// `weekly_grid.dart` or `dashboard_mobile_rows.dart` — all narrow surfaces
/// with a whole-row tap that render a party name as plain text today. This way
/// every new narrow surface is safe by default, and the allowlist is the
/// deliberate escape valve, which is why there is no `// lint: allow-…`
/// comment opt-out: the rule is "never on a row".
///
/// The failure is invisible otherwise — a re-added `link: true` compiles, runs,
/// throws nothing, and passes every other test in the suite.
/// Drop `//` comment tails so the scan reads code, not prose. Without this the
/// lint fails on the very comment that explains it — `invoice_list_tile.dart`
/// says "Deliberately NOT `link: true`" and pointed at this test by name.
String _stripComments(String source) => source
    .split('\n')
    .map((line) {
      final i = line.indexOf('//');
      return i == -1 ? line : line.substring(0, i);
    })
    .join('\n');

void main() {
  /// Detail surfaces where a cross-entity link is correct: nothing else on the
  /// surface is a tap target, so the link steals nothing.
  const allowed = {
    'lib/ui/features/invoices/views/invoice_detail_screen.dart',
    'lib/ui/features/quotes/views/quote_detail_screen.dart',
    'lib/ui/features/credits/views/credit_detail_screen.dart',
    'lib/ui/features/purchase_orders/views/purchase_order_detail_screen.dart',
    'lib/ui/features/recurring_invoices/views/recurring_invoice_detail_screen.dart',
    'lib/ui/features/payments/widgets/detail/payment_detail_header.dart',
    'lib/ui/features/transactions/views/transaction_detail_screen.dart',
  };

  test('no narrow row or card renders a party name as a link', () {
    final dir = Directory('lib/ui/features');
    expect(dir.existsSync(), isTrue, reason: 'lib/ui/features/ should exist');

    var scanned = 0;
    final offenders = <String>[];
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;
      if (entity.path.endsWith('.freezed.dart')) continue;
      scanned++;
      if (allowed.contains(entity.path)) continue;
      if (_stripComments(entity.readAsStringSync()).contains('link: true')) {
        offenders.add(entity.path);
      }
    }

    // Guard against a directory move turning this into `expect([], isEmpty)`.
    expect(
      scanned,
      greaterThan(200),
      reason: 'only $scanned files scanned — the glob is no longer matching',
    );
    // And against the allowlist silently going stale.
    for (final path in allowed) {
      expect(
        File(path).existsSync(),
        isTrue,
        reason: 'allowlisted file no longer exists — prune it: $path',
      );
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'a *NameLabel `link: true` inside a row/card steals the row tap '
          '(invoiceninja/flutter#128). Leave it off; the client is reached '
          'from `⋮ → View client`, the detail header, and the wide table:\n'
          '  ${offenders.join('\n  ')}',
    );
  });
}
