import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_panel_pref.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_panel_grid.dart';

import '../../../../_localization_helper.dart';

/// The wide dashboard's bottom grid, pumped on its own — the screen's body
/// never builds in a widget test (its `formatterFor` never completes), so this
/// is the only place its rules can be exercised rather than source-scanned.
///
/// The headline rule is the key: the grid is rows of unkeyed
/// `IntrinsicHeight(Row([Expanded, …]))`, so a card that changes row or column
/// keeps its element only through a `GlobalKey`. The `ValueKey` it used to
/// carry never matched anything, and since invoiceninja/flutter#161 a
/// neighbour emptying out is enough to move a card — which, for the two
/// Drift-backed panels, meant a disposed view model and a refetch.
class _Probe extends StatefulWidget {
  const _Probe(this.label);
  final String label;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 40, child: Text(widget.label));
}

void main() {
  final allVisible = [
    for (final k in DashboardKind.panelKinds)
      DashboardPanelPref(kind: k, visible: true),
  ];

  /// Two stateful stand-ins where the Drift-backed panels sit, and two plain
  /// ones around them. Canonical order renders them as
  /// `past due · pipeline / upcoming · calendar`.
  final builders = <String, Widget Function()>{
    DashboardKind.pastDue: () => const Text('Past due'),
    DashboardKind.invoicesAndQuotes: () => const _Probe('pipeline'),
    DashboardKind.upcomingInvoices: () => const Text('Upcoming'),
    DashboardKind.taskCalendar: () => const _Probe('calendar'),
  };

  Future<void> pumpGrid(
    WidgetTester tester, {
    List<DashboardPanelPref>? prefs,
    Map<String, Widget Function()>? panels,
    Set<String> hidden = const {},
    int columns = 2,
    VoidCallback? onShowPanels,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        theme: buildInTheme(InTheme.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: DashboardPanelGrid(
              panelPrefs: prefs ?? allVisible,
              builders: panels ?? builders,
              hidden: hidden,
              columns: columns,
              gap: 16,
              onShowPanels: onShowPanels ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  Finder probe(String label) =>
      find.byWidgetPredicate((w) => w is _Probe && w.label == label);

  for (final columns in const [2, 1]) {
    testWidgets('a panel keeps its State when a neighbour leaving moves it '
        '($columns-column)', (tester) async {
      await pumpGrid(tester, columns: columns);
      final pipeline = tester.state(probe('pipeline'));
      final calendar = tester.state(probe('calendar'));

      // Two columns: `pipeline` moves from the right cell of row 0 to the
      // left one, `calendar` likewise in row 1. One column: each moves up a
      // row. Either way the element changes parent.
      await pumpGrid(
        tester,
        columns: columns,
        hidden: const {DashboardKind.pastDue},
      );

      expect(find.text('Past due'), findsNothing);
      expect(tester.state(probe('pipeline')), same(pipeline));
      expect(tester.state(probe('calendar')), same(calendar));

      // And back again, when the neighbour returns.
      await pumpGrid(tester, columns: columns);
      expect(find.text('Past due'), findsOneWidget);
      expect(tester.state(probe('pipeline')), same(pipeline));
      expect(tester.state(probe('calendar')), same(calendar));
    });
  }

  testWidgets('with nothing hidden, every renderable panel shows', (
    tester,
  ) async {
    await pumpGrid(tester);

    expect(find.text('Past due'), findsOneWidget);
    expect(probe('pipeline'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(probe('calendar'), findsOneWidget);
  });

  testWidgets('a user-hidden panel stays hidden whatever the empty set says', (
    tester,
  ) async {
    // Switched off AND empty — a real state, since the empty set ignores
    // visibility. A filter that treated the two as cancelling out would show it.
    await pumpGrid(
      tester,
      prefs: [
        for (final p in allVisible)
          p.kind == DashboardKind.upcomingInvoices
              ? p.copyWith(visible: false)
              : p,
      ],
      hidden: const {DashboardKind.upcomingInvoices},
    );

    expect(find.text('Upcoming'), findsNothing);
    expect(find.text('Past due'), findsOneWidget);
  });

  testWidgets('when every shown panel is merely empty, nothing renders — not '
      'a "Show panels" link', (tester) async {
    // They are shown; the link would send the user to switch on panels that
    // are already on.
    await pumpGrid(
      tester,
      panels: {
        DashboardKind.pastDue: builders[DashboardKind.pastDue]!,
        DashboardKind.upcomingInvoices:
            builders[DashboardKind.upcomingInvoices]!,
      },
      hidden: const {DashboardKind.pastDue, DashboardKind.upcomingInvoices},
    );

    expect(find.text('Show panels'), findsNothing);
    expect(tester.getSize(find.byType(DashboardPanelGrid)).height, 0);
  });

  testWidgets('a panel the user switched off earns the way back', (
    tester,
  ) async {
    var opened = 0;
    await pumpGrid(
      tester,
      panels: {
        DashboardKind.pastDue: builders[DashboardKind.pastDue]!,
        DashboardKind.upcomingInvoices:
            builders[DashboardKind.upcomingInvoices]!,
      },
      prefs: [
        for (final p in allVisible)
          p.kind == DashboardKind.pastDue ? p.copyWith(visible: false) : p,
      ],
      // The other one is empty, so nothing is left on screen.
      hidden: const {DashboardKind.upcomingInvoices},
      onShowPanels: () => opened++,
    );

    await tester.tap(find.text('Show panels'));
    expect(opened, 1);
  });

  testWidgets('a switched-off panel that is empty too earns no way back', (
    tester,
  ) async {
    // Following the link would switch it on and still show nothing.
    await pumpGrid(
      tester,
      panels: {
        DashboardKind.pastDue: builders[DashboardKind.pastDue]!,
        DashboardKind.upcomingInvoices:
            builders[DashboardKind.upcomingInvoices]!,
      },
      prefs: [
        for (final p in allVisible)
          p.kind == DashboardKind.pastDue ? p.copyWith(visible: false) : p,
      ],
      hidden: const {DashboardKind.pastDue, DashboardKind.upcomingInvoices},
    );

    expect(find.text('Show panels'), findsNothing);
    expect(tester.getSize(find.byType(DashboardPanelGrid)).height, 0);
  });

  testWidgets('with no panel enabled for the company, nothing renders', (
    tester,
  ) async {
    await pumpGrid(tester, panels: const {});

    expect(find.text('Show panels'), findsNothing);
    expect(tester.getSize(find.byType(DashboardPanelGrid)).height, 0);
  });
}
