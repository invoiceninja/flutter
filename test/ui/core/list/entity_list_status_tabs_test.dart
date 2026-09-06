import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/list_status_tabs.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';
import 'package:admin/ui/core/list/entity_list_status_tabs.dart';

import '../../../_localization_helper.dart';

/// The strip's own contract (invoiceninja/flutter#98). It holds no filter state
/// — selection arrives as an index and taps go straight back out — so what
/// there is to pin is what it renders and when it refuses to act.
void main() {
  final tabs = listStatusTabsFor(
    EntityType.invoice,
    modes: kInvoiceBadgeModes,
    trackInventory: false,
  );

  ResolvedStatusTab? tapped;
  var streamsBuilt = 0;

  setUp(() {
    tapped = null;
    streamsBuilt = 0;
  });

  Widget host({
    int selectedIndex = 0,
    bool showCounts = true,
    bool enabled = true,
    String streamKey = 'invoice:co',
    Map<String, int> counts = const {'total': 12, 'draft': 3, 'overdue': 0},
  }) => MaterialApp(
    theme: buildInTheme(InTheme.light),
    localizationsDelegates: kTestLocalizationsDelegates,
    supportedLocales: kTestSupportedLocales,
    home: Scaffold(
      body: EntityListStatusTabs(
        tabs: tabs,
        selectedIndex: selectedIndex,
        showCounts: showCounts,
        enabled: enabled,
        streamKey: streamKey,
        countStream: (modeId) {
          streamsBuilt++;
          return Stream<int>.value(counts[modeId] ?? 0);
        },
        onTap: (t) => tapped = t,
      ),
    ),
  );

  group('decideStatusStrip', () {
    // Every condition that can suppress the strip, unit-tested — the scaffold
    // itself is unreachable from a widget test (it needs the whole Services
    // graph), which is exactly why this logic was extracted.
    StatusStripDecision decide({
      bool embedded = false,
      bool settingEnabled = true,
      String? activeModeId,
      List<ResolvedStatusTab>? tabList,
      bool availabilityKnown = true,
    }) => decideStatusStrip(
      embedded: embedded,
      settingEnabled: settingEnabled,
      activeModeId: activeModeId,
      tabs: tabList ?? tabs,
      availabilityKnown: availabilityKnown,
    );

    test('an embedded list never gets a strip — its counts would be '
        'company-wide over a parent-scoped list', () {
      expect(decide(embedded: true).action, StatusStripAction.hide);
      // Even with a tab active, because the counts would still be wrong.
      expect(
        decide(embedded: true, activeModeId: 'draft').action,
        StatusStripAction.hide,
      );
    });

    test('the device setting hides the strip only while no tab is active — a '
        'live filter always keeps a visible control', () {
      expect(decide(settingEnabled: false).action, StatusStripAction.hide);
      expect(
        decide(settingEnabled: false, activeModeId: 'draft').action,
        StatusStripAction.show,
      );
    });

    test('no available buckets and no active tab: just hide', () {
      expect(decide(tabList: const []).action, StatusStripAction.hide);
    });

    test('an active tab whose bucket this company cannot use is cleared', () {
      final d = decide(tabList: const [], activeModeId: 'low_stock');
      expect(d.action, StatusStripAction.healThenHide);
    });

    test('but NOT while availability is still unknown — the regression that '
        'wiped a restored Products filter before the company row landed', () {
      // Drift cannot answer synchronously, so the first frame has no company
      // row. Treating that as "inventory tracking is off" made an empty tab
      // list look like an unusable bucket and cleared the user's filter.
      final d = decide(
        tabList: const [],
        activeModeId: 'low_stock',
        availabilityKnown: false,
      );
      expect(
        d.action,
        StatusStripAction.hide,
        reason: 'not known yet is not the same as switched off',
      );
    });

    test('All is selected when no tab is active', () {
      final d = decide();
      expect(d.action, StatusStripAction.show);
      expect(d.selectedIndex, 0);
    });

    test('an active tab selects its own index', () {
      expect(decide(activeModeId: 'draft').selectedIndex, 1);
      expect(decide(activeModeId: 'overdue').selectedIndex, 3);
    });

    test('a hand-picked filter matching no tab selects nothing rather than '
        'lighting up All, which would claim no status filter is applied', () {
      expect(decide(activeModeId: 'paid').selectedIndex, -1);
    });
  });

  testWidgets('renders All plus one tab per badge mode', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Unpaid'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
  });

  testWidgets('a tap reports the tab rather than filtering anything itself', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Draft'));
    expect(tapped?.listModeId, 'draft');

    await tester.tap(find.text('All'));
    expect(
      tapped?.listModeId,
      isNull,
      reason: 'All clears the tab rather than selecting a mode of its own',
    );
  });

  testWidgets('counts render, including a zero — "Draft 0" is the answer to '
      'the question the tab asks', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('12'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('0'), findsWidgets);
  });

  testWidgets('showCounts: false drops every badge — the counts are '
      'active-only, so a number over an archived list would be wrong', (
    tester,
  ) async {
    await tester.pumpWidget(host(showCounts: false));
    await tester.pumpAndSettle();

    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('12'), findsNothing);
    expect(find.text('3'), findsNothing);
  });

  testWidgets('selectedIndex -1 selects nothing — a hand-picked status chip '
      'that matches no tab must not light up All', (tester) async {
    await tester.pumpWidget(host(selectedIndex: -1));
    await tester.pumpAndSettle();
    // Nothing to assert visually beyond "it renders and doesn't throw on an
    // out-of-range index"; the regression this guards is a RangeError.
    expect(find.text('All'), findsOneWidget);
  });

  testWidgets('disabled during multi-select: still laid out, no longer '
      'tappable — unmounting would jump the list body', (tester) async {
    await tester.pumpWidget(host(enabled: false));
    await tester.pumpAndSettle();

    expect(find.text('Draft'), findsOneWidget);
    await tester.tap(find.text('Draft'));
    expect(
      tapped,
      isNull,
      reason: 'a tap here would reload the list and clear the selection',
    );
  });

  testWidgets('count streams are built once, not per rebuild — they are fresh '
      'Drift queries and this widget rebuilds with the list', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    final afterFirst = streamsBuilt;
    expect(afterFirst, tabs.length);

    // Same stream key: a rebuild must reuse the cache.
    await tester.pumpWidget(host(selectedIndex: 1));
    await tester.pumpAndSettle();
    expect(streamsBuilt, afterFirst);

    // A company (or entity) switch must NOT reuse it.
    await tester.pumpWidget(host(streamKey: 'invoice:other-co'));
    await tester.pumpAndSettle();
    expect(streamsBuilt, afterFirst * 2);
  });

  group('edge fades', () {
    // The gradients are the only `Container`s in the strip carrying one — the
    // tab buttons decorate with a border. Counting them beats poking at
    // geometry, and tells the two edges apart via their gradient direction.
    Finder fades() => find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).gradient != null,
    );

    bool isLeading(Container c) =>
        ((c.decoration! as BoxDecoration).gradient! as LinearGradient).begin ==
        AlignmentDirectional.centerEnd;

    List<bool> leadingFlags(WidgetTester tester) => tester
        .widgetList<Container>(fades())
        .map(isLeading)
        .toList(growable: false);

    /// A viewport too narrow for the five invoice tabs, so the strip scrolls.
    Future<void> pumpNarrow(WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
    }

    testWidgets('at rest only the trailing edge fades', (tester) async {
      await pumpNarrow(tester);
      expect(
        leadingFlags(tester),
        [false],
        reason:
            'a strip parked at offset 0 has nothing off-screen to its left, so '
            'a leading fade would veil the first tab for no reason',
      );
    });

    testWidgets('scrolled to the end only the leading edge fades', (
      tester,
    ) async {
      await pumpNarrow(tester);
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(
        leadingFlags(tester),
        [true],
        reason:
            'the last tab is now flush against the trailing edge and its count '
            'badge sits only InSpacing.md inside it, so an ungated trailing '
            'fade would veil the number',
      );
    });

    testWidgets('mid-scroll both edges fade', (tester) async {
      await pumpNarrow(tester);
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(
        position.maxScrollExtent,
        greaterThan(0),
        reason:
            'the fixture must actually overflow or this group proves '
            'nothing',
      );
      position.jumpTo(position.maxScrollExtent / 2);
      await tester.pumpAndSettle();
      final flags = leadingFlags(tester);
      expect(flags, hasLength(2));
      expect(flags.toSet(), {true, false});
    });

    testWidgets('a strip that fits fades neither edge', (tester) async {
      // The first-frame rebuild exists for exactly this case: nobody scrolls,
      // so the controller never ticks on its own.
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(fades(), findsNothing);
    });
  });
}
