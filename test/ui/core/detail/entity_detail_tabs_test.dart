import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/detail/entity_detail_tabs.dart';

import '../../../_responsive_helper.dart';

/// `ClientDetailTabs` builds a VARIABLE-length tab list — eight of its tabs are
/// gated on `me?.moduleEnabled(...)` — and toggling a module in Account
/// Management rebuilds the branch in place. So this widget has to survive its
/// `tabs.length` changing under it.
///
/// Two ways that went wrong, both unguarded until this file existed:
///   * building a second `TabController` under `SingleTickerProviderStateMixin`
///     throws "multiple tickers were created" (the mixin asserts one ticker for
///     the State's whole life and never resets it);
///   * a rebuilt controller that doesn't re-attach the tab-change listener stops
///     growing `_activated`, so every tab body opened afterwards renders
///     nothing — a permanently blank pane.
EntityDetailTab _tab(String label) => EntityDetailTab(
  label: label,
  icon: Icons.circle_outlined,
  bodyBuilder: (_) => Text('$label body'),
);

void main() {
  Future<void> pumpTabs(WidgetTester tester, List<String> labels) => pumpAt(
    tester,
    900,
    EntityDetailTabs(tabs: [for (final l in labels) _tab(l)]),
    scroll: false,
  );

  testWidgets('shrinking the tab list does not throw', (tester) async {
    await pumpTabs(tester, ['Invoices', 'Quotes', 'Tasks']);
    expect(find.text('Invoices body'), findsOneWidget);

    await pumpTabs(tester, ['Invoices', 'Quotes']); // Tasks module disabled
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Invoices body'), findsOneWidget);
  });

  testWidgets('growing the tab list does not throw', (tester) async {
    await pumpTabs(tester, ['Invoices']);
    await pumpTabs(tester, ['Invoices', 'Quotes', 'Tasks']);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('tabs still open after the count changes', (tester) async {
    await pumpTabs(tester, ['Invoices', 'Quotes', 'Tasks']);
    await pumpTabs(tester, ['Invoices', 'Quotes']);
    await tester.pump();

    // The listener has to survive the controller rebuild, or `_activated`
    // never grows and this body never mounts.
    await tester.tap(find.text('Quotes'));
    await tester.pumpAndSettle();

    expect(find.text('Quotes body'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an already-open tab keeps its body across a count change', (
    tester,
  ) async {
    await pumpTabs(tester, ['Invoices', 'Quotes', 'Tasks']);
    await tester.tap(find.text('Quotes'));
    await tester.pumpAndSettle();
    expect(find.text('Quotes body'), findsOneWidget);

    // Disabling a module must not tear down every live tab body — this class
    // promises activated tabs stay alive for the screen's lifetime.
    await pumpTabs(tester, ['Invoices', 'Quotes']);
    await tester.pumpAndSettle();

    expect(find.text('Quotes body'), findsOneWidget);
  });

  testWidgets('an unchanged tab count keeps the same controller', (
    tester,
  ) async {
    await pumpTabs(tester, ['Invoices', 'Quotes']);
    await tester.tap(find.text('Quotes'));
    await tester.pumpAndSettle();

    await pumpTabs(tester, ['Invoices', 'Quotes']);
    await tester.pumpAndSettle();

    // Still on Quotes: a same-length rebuild must not reset the selection.
    expect(find.text('Quotes body'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
