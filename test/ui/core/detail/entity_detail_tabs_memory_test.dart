import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/list/master_detail_nav_scope.dart';

import '../../../_localization_helper.dart';

/// Clicking a different row tears the whole detail subtree down (the router
/// re-keys it per `:id`), which used to snap the tab strip back to the first
/// tab every time. The remembered index lives on `MasterDetailNavController`
/// precisely because that object outlives the swap.

List<EntityDetailTab> _tabs() => [
  EntityDetailTab(
    label: 'Invoices',
    icon: Icons.receipt_long_outlined,
    bodyBuilder: (_) => const Text('invoices-body'),
  ),
  EntityDetailTab(
    label: 'Payments',
    icon: Icons.payments_outlined,
    bodyBuilder: (_) => const Text('payments-body'),
  ),
  EntityDetailTab(
    label: 'Documents',
    icon: Icons.folder_outlined,
    bodyBuilder: (_) => const Text('documents-body'),
  ),
];

/// `recordId` keys the subtree exactly the way `router.dart` does, so pumping
/// a new one builds a genuinely fresh `State` rather than reusing the old one.
Future<void> _pumpRecord(
  WidgetTester tester, {
  required MasterDetailNavController controller,
  required String recordId,
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildInTheme(InTheme.light),
    localizationsDelegates: kTestLocalizationsDelegates,
    supportedLocales: kTestSupportedLocales,
    home: MasterDetailNavScope(
      controller: controller,
      child: Scaffold(
        body: KeyedSubtree(
          key: ValueKey('detail:$recordId'),
          child: EntityDetailTabs(tabs: _tabs()),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('the active tab survives a row-to-row swap', (tester) async {
    final controller = MasterDetailNavController();

    await _pumpRecord(tester, controller: controller, recordId: 'a');
    expect(find.text('invoices-body'), findsOneWidget);

    await tester.tap(find.text('Documents'));
    await tester.pumpAndSettle();
    expect(find.text('documents-body'), findsOneWidget);
    expect(controller.lastTab, (index: 2, count: 3));

    // Click a different row: fresh State, same controller.
    await _pumpRecord(tester, controller: controller, recordId: 'b');
    await tester.pumpAndSettle();

    expect(find.text('documents-body'), findsOneWidget);
    expect(find.text('invoices-body'), findsNothing);
  });

  testWidgets('without a nav scope the strip still opens on the first tab', (
    tester,
  ) async {
    // The settings-hosted detail screens have no MasterDetailLayout above
    // them; they must keep working, just without the memory.
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(body: EntityDetailTabs(tabs: _tabs())),
      ),
    );

    expect(find.text('invoices-body'), findsOneWidget);
    await tester.tap(find.text('Payments'));
    await tester.pumpAndSettle();
    expect(find.text('payments-body'), findsOneWidget);
  });

  testWidgets('a strip with a different tab COUNT declines to restore', (
    tester,
  ) async {
    // An index only means the same tab while the strip has the same shape.
    // The invoice pane gates one tab on `invoiceSupportsPaymentSchedule` —
    // per record — so restoring across a count change would silently land the
    // user on a tab they weren't reading.
    final controller = MasterDetailNavController()
      ..lastTab = (index: 2, count: 3);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: MasterDetailNavScope(
          controller: controller,
          child: Scaffold(
            body: EntityDetailTabs(tabs: _tabs().take(2).toList()),
          ),
        ),
      ),
    );

    expect(find.text('invoices-body'), findsOneWidget);
    expect(find.text('payments-body'), findsNothing);
  });

  testWidgets('a remembered index past the end of a shorter strip clamps', (
    tester,
  ) async {
    // Tab sets are gated on company module flags, so they can shrink under a
    // remembered index — `_newController` clamps, and an unclamped index
    // would leave every body Offstage with no tab underlined.
    final controller = MasterDetailNavController()
      ..lastTab = (index: 2, count: 2);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: MasterDetailNavScope(
          controller: controller,
          child: Scaffold(
            body: EntityDetailTabs(tabs: _tabs().take(2).toList()),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('payments-body'), findsOneWidget);
  });
}
