import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';
import 'package:admin/ui/features/settings/widgets/sidebar_counters_section.dart';
import 'package:admin/ui/features/shell/widgets/sidebar_badge.dart';

import '../../shell/_shell_test_helpers.dart';

/// Renders the real Sidebar counters card against a real `Services` + Drift so
/// the whole chain is exercised: catalog → dropdown → controller → repo →
/// DAO → the preview badge. The preview is the point of the card — the setting
/// showing its own effect — so it's what's asserted.
void main() {
  late ShellFixture fixture;

  /// `addTearDown` from inside the test body, not a top-level `tearDown`: the
  /// fixture's `Services` keep timers running, and the binding's
  /// still-pending-Timer assertion fires before a `tearDown` would get the
  /// chance to stop them.
  Future<void> setUpFixture() async {
    fixture = await buildFixture(
      companies: const [FakeCompany(id: 'co1', name: 'Acme')],
    );
    addTearDown(fixture.dispose);
  }

  Future<void> seedOverdueInvoice(String id) => fixture.db.invoiceDao.upsert(
    InvoicesCompanion.insert(
      id: id,
      companyId: 'co1',
      updatedAt: 1,
      payload: '{}',
      statusId: const Value('2'),
      balance: const Value('100'),
      dueDate: const Value('2020-01-01'),
    ),
  );

  testWidgets('lists a row per sidebar entity with its counter dropdown', (
    tester,
  ) async {
    await setUpFixture();
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        const SingleChildScrollView(child: SidebarCountersSection()),
      ),
    );
    await _pumpFrames(tester);

    expect(find.text('Sidebar counters'), findsOneWidget);
    expect(find.text('Invoices'), findsOneWidget);
    expect(find.text('Clients'), findsOneWidget);
    // Every row starts on the default, so the whole card reads "Total".
    expect(find.text('Total'), findsWidgets);
    await _disposeTree(tester);
  });

  testWidgets(
    'picking a counter updates the controller and the row previews the real '
    'badge — the point of the card is that you see the effect here',
    (tester) async {
      await setUpFixture();
      await seedOverdueInvoice('i1');
      await seedOverdueInvoice('i2');

      await tester.pumpWidget(
        wrapWithShell(
          fixture.services,
          const SingleChildScrollView(child: SidebarCountersSection()),
        ),
      );
      await _pumpFrames(tester);

      // No badge yet: an unchanged row is on Total, and Total has no invoices
      // beyond the two seeded ones — so assert against the mode change instead.
      final invoicesRow = find.ancestor(
        of: find.text('Invoices'),
        matching: find.byType(ListTile),
      );
      await tester.tap(
        find.descendant(
          of: invoicesRow,
          matching: find.byType(DropdownButton<String>),
        ),
      );
      await _pumpFrames(tester);
      await tester.tap(find.text('Overdue').last);
      await _pumpFrames(tester);

      expect(
        fixture.services.sidebarBadgeModes.modeFor(EntityType.invoice),
        'overdue',
      );

      // The preview badge now shows the live overdue count, in the danger tone
      // the rail will use.
      final badge = tester.widget<SidebarBadge>(
        find.descendant(
          of: find.ancestor(
            of: find.text('Invoices'),
            matching: find.byType(ListTile),
          ),
          matching: find.byType(SidebarBadge),
        ),
      );
      expect(badge.count, 2);
      expect(badge.tone, SidebarBadgeTone.danger);
      await _disposeTree(tester);
    },
  );

  testWidgets(
    'the preview stream is hoisted — an unrelated rebuild must not re-subscribe '
    'every row, which would re-run all 14 Drift queries per dropdown change',
    (tester) async {
      await setUpFixture();
      await seedOverdueInvoice('i1');
      await tester.pumpWidget(
        wrapWithShell(
          fixture.services,
          const SingleChildScrollView(child: SidebarCountersSection()),
        ),
      );
      await _pumpFrames(tester);

      await fixture.services.sidebarBadgeModes.set(
        EntityType.invoice,
        'overdue',
      );
      await _pumpFrames(tester);
      expect(_invoiceBadgeCount(tester), 1);
      final before = _invoiceBadgeStream(tester);

      // Touch a DIFFERENT row. The whole card rebuilds under the controller's
      // `ListenableBuilder`; the Invoices preview must hand `StreamBuilder` the
      // *same* stream object, or it tears down and re-subscribes for nothing.
      //
      // Asserting on the stream identity rather than on the rendered count is
      // deliberate: `StreamBuilder.afterDisconnected` preserves the last
      // snapshot across a swap, so the badge looks identical either way and a
      // count assertion would pass against the bug it is meant to catch.
      await fixture.services.sidebarBadgeModes.set(EntityType.quote, 'draft');
      await _pumpFrames(tester);

      expect(identical(_invoiceBadgeStream(tester), before), isTrue);
      expect(_invoiceBadgeCount(tester), 1);

      // Changing this row's own mode SHOULD build a new stream — it counts
      // something else now.
      await fixture.services.sidebarBadgeModes.set(EntityType.invoice, 'draft');
      await _pumpFrames(tester);
      expect(identical(_invoiceBadgeStream(tester), before), isFalse);
      await _disposeTree(tester);
    },
  );

  testWidgets('Reset appears once something is overridden and clears it', (
    tester,
  ) async {
    await setUpFixture();
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        const SingleChildScrollView(child: SidebarCountersSection()),
      ),
    );
    await _pumpFrames(tester);
    expect(find.text('Reset'), findsNothing);

    await fixture.services.sidebarBadgeModes.set(EntityType.invoice, 'overdue');
    await _pumpFrames(tester);
    expect(find.text('Reset'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await _pumpFrames(tester);
    expect(fixture.services.sidebarBadgeModes.hasOverrides, isFalse);
    expect(find.text('Reset'), findsNothing);
    await _disposeTree(tester);
  });

  testWidgets(
    'the stock counters are withheld while inventory tracking is off — a '
    'counter guaranteed to read zero is not worth offering',
    (tester) async {
      await setUpFixture();
      await tester.pumpWidget(
        wrapWithShell(
          fixture.services,
          const SingleChildScrollView(child: SidebarCountersSection()),
        ),
      );
      await _pumpFrames(tester);

      final productsRow = find.ancestor(
        of: find.text('Products'),
        matching: find.byType(ListTile),
      );
      final dropdown = find.descendant(
        of: productsRow,
        matching: find.byType(DropdownButton<String>),
      );
      expect(
        tester.widget<DropdownButton<String>>(dropdown).items!.length,
        availableBadgeModes(kProductBadgeModes, trackInventory: false).length,
      );
      expect(find.text('Low stock'), findsNothing);
      await _disposeTree(tester);
    },
  );
}

/// `pumpAndSettle` never returns here: the preview badge holds a live Drift
/// watch, so the tree is never "settled". Pump a fixed number of frames long
/// enough to cover the dropdown menu's open/close animation instead.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Tear the subtree down inside the test body so the Drift watches' close
/// timers (`StreamQueryStore.markAsClosed` schedules a zero-duration Timer on
/// unsubscribe) fire before the binding's end-of-test `!timersPending` check.
/// The preview badges hold one such watch each, so this is required here.
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

/// The count on the Invoices row's preview badge, or null when no badge is
/// rendered (which is what a blink through `AsyncSnapshot.nothing` looks like).
int? _invoiceBadgeCount(WidgetTester tester) {
  final badges = find.descendant(
    of: find.ancestor(
      of: find.text('Invoices'),
      matching: find.byType(ListTile),
    ),
    matching: find.byType(SidebarBadge),
  );
  if (badges.evaluate().isEmpty) return null;
  return tester.widget<SidebarBadge>(badges).count;
}

/// The stream object the Invoices row currently hands its `StreamBuilder`.
/// Identity across rebuilds is what proves the stream is hoisted.
Stream<int>? _invoiceBadgeStream(WidgetTester tester) => tester
    .widget<StreamBuilder<int>>(
      find.descendant(
        of: find.ancestor(
          of: find.text('Invoices'),
          matching: find.byType(ListTile),
        ),
        matching: find.byType(StreamBuilder<int>),
      ),
    )
    .stream;
