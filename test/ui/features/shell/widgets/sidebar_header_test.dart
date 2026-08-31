import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/resync_controller.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/ui/features/shell/widgets/company_switcher_button.dart';
import 'package:admin/ui/features/shell/widgets/sidebar_header.dart';
import 'package:admin/ui/features/shell/widgets/sidebar_sync_button.dart';

import '../../../../_localization_helper.dart';

/// Layout of the sidebar header — the company switcher paired with the Sync
/// button (issue #14). The leaf button has its own test; this one guards the
/// *composition*, which is where the real risk sits: an overflow in the 232-px
/// rail or the 64-px collapsed rail, and the two buttons ending up different
/// heights.
///
/// Uses `pump()` rather than `pumpAndSettle()` wherever a pass is in flight —
/// an indeterminate `CircularProgressIndicator` never settles.

/// Mirrors the real call site: `Padding(fromLTRB(14, 8, 14, 8))` inside a
/// fixed-width rail. Only the horizontal 14s feed [_kRailPadding].
const double _kRailPadding = 28; // 14 either side

ThemeData _theme() => ThemeData.light().copyWith(
  extensions: <ThemeExtension<dynamic>>[InTheme.light],
);

AuthSession _session({int companies = 2, String name = 'Acme Co'}) =>
    AuthSession(
      baseUrl: 'https://example.com',
      isHosted: true,
      accountId: 'acc',
      companies: [
        for (var i = 0; i < companies; i++)
          AuthCompany(
            id: 'c${i + 1}',
            name: i == 0 ? name : 'Other $i',
            displayName: i == 0 ? name : 'Other $i',
            permissions: '',
            isAdmin: true,
            isOwner: i == 0,
          ),
      ],
      currentCompanyId: 'c1',
    );

void main() {
  late ValueNotifier<ResyncProgress> progress;
  late int taps;

  setUp(() {
    progress = ValueNotifier<ResyncProgress>(const ResyncProgress.idle());
    taps = 0;
  });

  tearDown(() => progress.dispose());

  Widget wrap({
    required double railWidth,
    bool compact = false,
    bool touch = false,
    AuthSession? session,
    double textScale = 1.0,
  }) {
    return MaterialApp(
      theme: _theme(),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: railWidth,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                  child: SidebarHeader(
                    session: session ?? _session(),
                    resync: progress,
                    onSync: () => taps++,
                    compact: compact,
                    touch: touch,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('expanded rail lays both buttons out with no overflow', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(railWidth: 232));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(CompanySwitcherButton), findsOneWidget);
    expect(find.byType(SidebarSyncButton), findsOneWidget);

    final switcher = tester.getSize(find.byType(CompanySwitcherButton));
    final sync = tester.getSize(find.byType(SidebarSyncButton));
    expect(
      switcher.width + sync.width + InSpacing.sm,
      moreOrLessEquals(232 - _kRailPadding, epsilon: 0.5),
      reason: 'the pair must exactly fill the rail content box',
    );
  });

  testWidgets('the Sync button matches the switcher height exactly', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(railWidth: 232));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(SidebarSyncButton)).height,
      tester.getSize(find.byType(CompanySwitcherButton)).height,
      reason: 'IntrinsicHeight + stretch is what keeps the pair aligned',
    );
  });

  testWidgets('the pair stays aligned at large text scale', (tester) async {
    // The switcher grows with the company name's line box; a fixed-height Sync
    // box would fall short and clip descenders (the Inter Tight trap).
    await tester.pumpWidget(wrap(railWidth: 232, textScale: 1.4));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final switcher = tester.getSize(find.byType(CompanySwitcherButton));
    final sync = tester.getSize(find.byType(SidebarSyncButton));
    expect(sync.height, switcher.height);
  });

  testWidgets('a long company name ellipsizes rather than overflowing', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        railWidth: 232,
        session: _session(name: 'An Extremely Long Workspace Name Ltd'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SidebarSyncButton), findsOneWidget);
  });

  testWidgets('expanded rail on touch fits a 44-px Sync button', (
    tester,
  ) async {
    // A tablet at >=600 px gets the 232-px rail *and* touch sizing. The
    // switcher is Expanded so it absorbs the loss, but the pair still has to
    // fit the content box exactly.
    await tester.pumpWidget(wrap(railWidth: 232, touch: true));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final sync = tester.getSize(find.byType(SidebarSyncButton));
    final switcher = tester.getSize(find.byType(CompanySwitcherButton));
    expect(sync.width, greaterThanOrEqualTo(InSizes.touchTarget));
    expect(sync.height, greaterThanOrEqualTo(InSizes.touchTarget));
    expect(
      switcher.width + sync.width + InSpacing.sm,
      moreOrLessEquals(232 - _kRailPadding, epsilon: 0.5),
    );
  });

  testWidgets('collapsed rail stacks Sync under the avatar, no overflow', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(railWidth: 64, compact: true, touch: true));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final switcher = tester.getTopLeft(find.byType(CompanySwitcherButton));
    final sync = tester.getTopLeft(find.byType(SidebarSyncButton));
    expect(sync.dy, greaterThan(switcher.dy), reason: 'stacked, not beside');
    expect(sync.dx, switcher.dx, reason: 'both stretch to the rail width');
    expect(
      tester.getSize(find.byType(SidebarSyncButton)).width,
      lessThanOrEqualTo(64 - _kRailPadding),
    );
  });

  testWidgets('tapping Sync fires onSync and does not open the picker', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(railWidth: 232));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SidebarSyncButton));
    await tester.pumpAndSettle();

    expect(taps, 1);
    // The switcher's InkWell covers its whole box; if the Sync button were
    // nested inside it the tap would be swallowed and the picker would open.
    expect(find.text('Other 1'), findsNothing);
  });

  testWidgets('a running pass shows the spinner in the header', (tester) async {
    await tester.pumpWidget(wrap(railWidth: 232));
    await tester.pumpAndSettle();

    progress.value = const ResyncProgress.downloading(
      companyId: 'c1',
      completed: 2,
      total: 14,
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byTooltip('Syncing 2 of 14'), findsOneWidget);
  });

  testWidgets('single-company workspaces still get the Sync button', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(railWidth: 232, session: _session(companies: 1)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SidebarSyncButton));
    expect(taps, 1);
  });

  testWidgets('the switcher stays interactive with a single company', (
    tester,
  ) async {
    // Issue #16: the button used to go inert below two companies, so a roster
    // that had wrongly shrunk to one left the user with a dead control (and no
    // route to the picker's Sign out). It is now always tappable — assert the
    // chevron renders and the InkWell has a live callback.
    await tester.pumpWidget(
      wrap(railWidth: 232, session: _session(companies: 1)),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.unfold_more), findsOneWidget);
    final inkWell = tester.widget<InkWell>(
      find.descendant(
        of: find.byType(CompanySwitcherButton),
        matching: find.byType(InkWell),
      ),
    );
    expect(inkWell.onTap, isNotNull);
  });

  testWidgets('carries no search affordance — it lives in the toolbar row', (
    tester,
  ) async {
    // Issue #101 moved the box up into the back/forward row, which had ~172 px
    // of dead horizontal space, so the nav list gets that row back. Its own
    // behaviour is covered by `sidebar_search_box_test.dart`; this guards
    // against it drifting back into the header.
    await tester.pumpWidget(wrap(railWidth: 252, touch: true));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.search), findsNothing);
  });
}
