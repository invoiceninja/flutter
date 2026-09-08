import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Seeding an expense's invoice currency from the picked client must also seed
/// the exchange rate.
///
/// Setting one without the other leaves the converted amount on whatever rate
/// the form already held, which is wrong the moment the client's currency
/// differs from the expense's. `RecurringExpenseEditIdentitySection` shipped
/// exactly that: its header says it "mirrors ExpenseEditIdentitySection" and it
/// had dropped the `crossCurrencyRate` half.
///
/// A source scan rather than a widget test because the section needs
/// `Services`, a live Drift stream and a router to pump, and a `pumpAndSettle`
/// over a real Drift watch times out. The invariant is textual and local, so
/// scanning is enough.
///
/// It is file-granular: seeding moved into a sibling picker in the same file
/// would still pass. That is the accepted limit — the failure this exists for
/// is a whole mirrored file drifting from its twin, not a picker moving.
void main() {
  test('every place that seeds invoiceCurrencyId also seeds the exchange '
      'rate', () {
    // Derived, not a hardcoded pair: the bug was a mirror file drifting from
    // its twin, so a lint that names only the two files it already knows about
    // cannot catch the third. Any file that seeds the invoice currency is in
    // scope.
    final offenders = <String>[];
    var scanned = 0;
    for (final f
        in Directory('lib/ui')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final src = f.readAsStringSync();
      // The setter call, not the VM's own declaration.
      if (!src.contains('.setInvoiceCurrencyId(')) continue;
      scanned++;
      if (!src.contains('crossCurrencyRate(') ||
          !src.contains('setExchangeRate(')) {
        offenders.add(f.uri.pathSegments.last);
      }
    }
    expect(
      scanned,
      greaterThan(1),
      reason: 'only $scanned seeding sites found — the marker string moved',
    );
    expect(
      offenders,
      isEmpty,
      reason:
          'these seed the invoice currency from a picked client or currency '
          'but never the exchange rate, so the converted amount keeps a stale '
          'rate:\n  ${offenders.join('\n  ')}',
    );
  });
}
