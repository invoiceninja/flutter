import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/ui/features/shell/widgets/company_avatar.dart';
import 'package:admin/ui/features/shell/widgets/sidebar_footer_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_shell_test_helpers.dart';

/// Touch-density coverage for the sidebar footer (issue #11). The pure
/// `userGuideUrl` mapping is covered by `sidebar_footer_actions_test.dart`;
/// this file pumps the widget, which needs the full `Services` graph because
/// the theme action reads `context.read<Services>().theme`.
///
/// The row is the tightest horizontal space in the sidebar: on the expanded
/// 232-px rail five 44-px-wide actions plus the divider and the collapse
/// toggle would need 273 px against 216 available. `touch` therefore grows the
/// height and shares out the width via `Expanded` — these tests pin both ends
/// of that (44 tall, no overflow).
void main() {
  // The persistent rail (232) and the mobile drawer (280) — the two real
  // hosts. Height must clear the target in both; width must never overflow.
  const railWidth = 232.0;
  const drawerWidth = 280.0;

  Future<void> pumpFooter(
    WidgetTester tester, {
    required double width,
    required bool showCollapseToggle,
    bool touch = true,
    Widget? leading,
  }) async {
    final fixture = await buildFixture(
      companies: const [FakeCompany(id: 'c1', name: 'Acme Co')],
    );
    addTearDown(fixture.dispose);

    await tester.binding.setSurfaceSize(Size(width, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: width,
            child: SidebarFooterActions(
              touch: touch,
              showCollapseToggle: showCollapseToggle,
              leading: leading,
            ),
          ),
        ),
      ),
    );
    // Not pumpAndSettle: a ShellFixture owns live Drift watch streams that
    // never settle.
    await tester.pump();
  }

  /// The footer's icon actions. Scoped to `InkWell`s under a `Tooltip`-wrapped
  /// `Material` so it excludes the collapse toggle: that is an `IconButton`,
  /// and Material 3 builds those on `ButtonStyleButton`, which has an `InkWell`
  /// of its own that a bare `byType(InkWell)` would sweep up.
  Finder footerActions() => find.descendant(
    of: find.byType(SidebarFooterActions),
    matching: find.byWidgetPredicate(
      (w) => w is InkWell && w.borderRadius != null,
    ),
  );

  void expectActionsAtLeastTouchTall(WidgetTester tester, {int count = 5}) {
    final actions = footerActions();
    // Contact · Forum · Guide · About · Theme, plus the company action when the
    // single-company drawer passes one. Pinned so the finder can't quietly
    // start matching the collapse toggle and dilute the assertion.
    expect(actions, findsNWidgets(count));
    for (var i = 0; i < tester.widgetList(actions).length; i++) {
      expect(
        tester.getSize(actions.at(i)).height,
        greaterThanOrEqualTo(InSizes.touchTarget),
        reason: 'footer action $i is below the touch target',
      );
    }
  }

  testWidgets('drawer: every action clears the touch target, no overflow', (
    tester,
  ) async {
    await pumpFooter(tester, width: drawerWidth, showCollapseToggle: false);

    expectActionsAtLeastTouchTall(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded rail: actions + divider + collapse toggle still fit', (
    tester,
  ) async {
    await pumpFooter(tester, width: railWidth, showCollapseToggle: true);

    expectActionsAtLeastTouchTall(tester);
    // The collapse toggle goes through ButtonStyle rather than an explicit
    // IconButton.constraints, so no visual-density adjustment shrinks it.
    expect(
      tester
          .getSize(find.widgetWithIcon(IconButton, Icons.chevron_left))
          .height,
      greaterThanOrEqualTo(InSizes.touchTarget),
    );
    expect(
      tester.takeException(),
      isNull,
      reason: 'fixed-width touch actions would overflow the 232-px rail',
    );
  });

  testWidgets('drawer: the company action makes six, still at the touch floor', (
    tester,
  ) async {
    // Issue #104. This row has no slack at all. Here it is 280 - 8 - 8 = 264 of
    // content shared six ways = exactly 44.0, the touch target — but in the
    // real drawer it is 43.83, because `InSidebar`'s `AnimatedContainer` has a
    // `Border(right:)` whose 1 px folds inside the width constraint and this
    // harness pumps into a bare `SizedBox(width: 280)` instead. So treat 44.0
    // here as the ceiling, not the truth: a seventh action (37.6) or a divider
    // ahead of the company slot (the rail's idiom, 9 px, 42.3) silently drops
    // the whole row well below the floor. Assert the width, not just height.
    await pumpFooter(
      tester,
      width: drawerWidth,
      showCollapseToggle: false,
      leading: SidebarCompanyFooterAction(
        company: const AuthCompany(
          id: 'c1',
          name: 'Acme Co',
          displayName: 'Acme Co',
          permissions: '',
          isAdmin: true,
          isOwner: true,
        ),
        touch: true,
        onTap: () {},
      ),
    );

    expectActionsAtLeastTouchTall(tester, count: 6);
    for (var i = 0; i < 6; i++) {
      expect(
        tester.getSize(footerActions().at(i)).width,
        greaterThanOrEqualTo(InSizes.touchTarget),
        reason:
            'footer action $i is narrower than the touch target — 264 / 6 is '
            'exactly 44.0, so anything else in this row breaks all six',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the company action announces the name once, not the initials', (
    tester,
  ) async {
    // `CompanyAvatar` paints a real `Text(initials)`, unlike the five icon
    // siblings — so a tooltip-only label would announce "AC" and then the name.
    // Disposed inline, not via addTearDown: flutter_test verifies every
    // semantics handle is released at the END of the body, before tear-downs.
    final handle = tester.ensureSemantics();

    await pumpFooter(
      tester,
      width: drawerWidth,
      showCollapseToggle: false,
      leading: SidebarCompanyFooterAction(
        company: const AuthCompany(
          id: 'c1',
          name: 'Acme Co',
          displayName: 'Acme Co',
          permissions: '',
          isAdmin: true,
          isOwner: true,
        ),
        touch: true,
        onTap: () {},
      ),
    );

    expect(find.bySemanticsLabel('Acme Co'), findsOneWidget);
    expect(find.bySemanticsLabel('AC'), findsNothing);
    handle.dispose();
  });

  testWidgets('an empty roster gets a neutral glyph, never an em dash', (
    tester,
  ) async {
    // As the sole account affordance on that layout, a tinted square holding an
    // em dash — with a tooltip that is also an em dash — reads as a rendering
    // bug rather than the way back to Sign out.
    await pumpFooter(
      tester,
      width: drawerWidth,
      showCollapseToggle: false,
      leading: SidebarCompanyFooterAction(
        company: null,
        touch: true,
        onTap: () {},
      ),
    );

    expect(find.byIcon(Icons.business_outlined), findsOneWidget);
    expect(find.byType(CompanyAvatar), findsNothing);
    expect(find.byTooltip('—'), findsNothing);
    expect(find.byTooltip('Switch Company'), findsOneWidget);

    // ...and says it once. With a company the hint ("Switch Company") adds to
    // the label (the name); with none the two would be the same string and a
    // screen reader would announce "Switch Company, button, Switch Company".
    final handle = tester.ensureSemantics();
    final labelled = find.bySemanticsLabel('Switch Company');
    expect(labelled, findsOneWidget);
    expect(tester.getSemantics(labelled).hint, isEmpty);
    handle.dispose();
  });

  testWidgets('pointer platforms keep the dense 30-px footer', (tester) async {
    await pumpFooter(
      tester,
      width: railWidth,
      showCollapseToggle: true,
      touch: false,
    );

    // 18px icon + 6px padding either side, unchanged by this issue.
    expect(tester.getSize(footerActions().first).height, 30);
    expect(tester.takeException(), isNull);
  });
}
