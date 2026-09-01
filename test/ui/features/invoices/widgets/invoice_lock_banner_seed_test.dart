import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/ui/features/invoices/widgets/detail/invoice_lock_banner.dart';

import '../../shell/_shell_test_helpers.dart';

/// The invoice preview pane jumping on every row click.
///
/// The banner is the first child of the detail header's Column, so when its
/// reason resolved late — two awaited Drift reads after mount, on a subtree the
/// router re-keys per `:id` — ~44 px appeared above the invoice number and
/// pushed the status pill, client, dates, KPI strip and the whole tab block
/// down, after the user had already started reading them.
///
/// A company with `lock_invoices = off` never jumped, because the resolve
/// returns `none`, the `reason != _reason` guard fails, and `setState` never
/// fires. That asymmetry is what identified the bug.
///
/// **These tests assert GEOMETRY, not presence** — the bug is the movement, and
/// a presence assertion would pass against a banner that still arrives a frame
/// late. And they `pump()` exactly once after the remount: `pumpAndSettle`
/// would hide the frame under test (and the fixture leaves timers pending).

/// Rebuilds [child] under a `KeyedSubtree` whose key changes on demand —
/// the mechanism `router.dart:316` uses, so bumping the generation builds a
/// genuinely fresh `State` rather than rebuilding the old one.
class _Remountable extends StatefulWidget {
  const _Remountable({required this.child});

  final Widget child;

  @override
  State<_Remountable> createState() => _RemountableState();
}

class _RemountableState extends State<_Remountable> {
  int _gen = 0;

  void remount() => setState(() => _gen++);

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: ValueKey(_gen), child: widget.child);
}

/// An invoice dated in a prior month — locked under `end_of_month`.
Invoice _pastMonthInvoice() => Invoice.fromApi(
  const InvoiceApi(id: 'inv1', number: 'INV-1', date: '2020-01-15'),
);

Widget _pane(String companyId) => _Remountable(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      InvoiceLockBanner(invoice: _pastMonthInvoice(), companyId: companyId),
      const Text('#INV-1'),
    ],
  ),
);

/// Bounded settle. Not `pumpAndSettle`: `buildFixture`'s `Services` keep timers
/// pending, and settling would also hide the frame these tests exist for.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets('the invoice number does not move when a locked invoice is '
      're-opened', (tester) async {
    final fixture = await buildFixture(
      companies: [
        const FakeCompany(
          id: 'co1',
          name: 'Co',
          settings: {'lock_invoices': 'end_of_month'},
        ),
      ],
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(wrapWithShell(fixture.services, _pane('co1')));
    await _settle(tester);
    // The banner is up: this company locks past-month invoices.
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);

    // The row click.
    tester.state<_RemountableState>(find.byType(_Remountable)).remount();
    await tester.pump();
    final settledY = tester.getTopLeft(find.text('#INV-1')).dy;

    await _settle(tester);
    final afterResolveY = tester.getTopLeft(find.text('#INV-1')).dy;

    expect(
      settledY,
      afterResolveY,
      reason: 'the header moved after the lock reason resolved',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('a company without lock_invoices never shows the banner — the '
      'seed must not invent one', (tester) async {
    final fixture = await buildFixture(
      companies: [const FakeCompany(id: 'co1', name: 'Co')],
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(wrapWithShell(fixture.services, _pane('co1')));
    await tester.pump();
    expect(find.byIcon(Icons.lock_outline), findsNothing);

    await _settle(tester);
    expect(find.byIcon(Icons.lock_outline), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('a stale seed self-heals in exactly one mount', (tester) async {
    // The staleness this design deliberately accepts. Several writers bypass
    // the mirror — `applyUpdateResponse`, the 5-minute delta `/refresh`, any
    // server-side change — so the seed can be wrong. What must hold is that the
    // async resolve always corrects it AND refreshes the mirror, so the window
    // is exactly one mount and cannot recur.
    final fixture = await buildFixture(
      companies: [
        const FakeCompany(
          id: 'co1',
          name: 'Co',
          settings: {'lock_invoices': 'end_of_month'},
        ),
      ],
    );
    addTearDown(fixture.dispose);

    // Mount once so the mirror is warm with `end_of_month`. Doing it through a
    // real mount rather than a bare `resolved()` call also sidesteps racing the
    // fire-and-forget warm that `auth.restore()` kicks off.
    await tester.pumpWidget(wrapWithShell(fixture.services, _pane('co1')));
    await _settle(tester);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);

    // Simulate a writer that skips `onSettingsWritten` (applyUpdateResponse,
    // the delta `/refresh`) — write the row straight through the DAO.
    await (fixture.db.update(fixture.db.companies)
          ..where((c) => c.id.equals('co1')))
        .write(const CompaniesCompanion(settings: Value('{}')));

    // The row click. Documented, not hidden: frame 1 still trusts the seed.
    tester.state<_RemountableState>(find.byType(_Remountable)).remount();
    await tester.pump();
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);

    await _settle(tester);
    expect(find.byIcon(Icons.lock_outline), findsNothing);

    // That correction refreshed the mirror, so the NEXT mount is clean on
    // frame 1 — the staleness window is one mount and cannot recur.
    tester.state<_RemountableState>(find.byType(_Remountable)).remount();
    await tester.pump();
    expect(find.byIcon(Icons.lock_outline), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
