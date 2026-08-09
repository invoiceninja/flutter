import 'package:admin/app/design_tokens.dart';
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

  void expectActionsAtLeastTouchTall(WidgetTester tester) {
    final actions = footerActions();
    // Contact · Forum · Guide · About · Theme. Pinned so the finder can't
    // quietly start matching the collapse toggle and dilute the assertion.
    expect(actions, findsNWidgets(5));
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
