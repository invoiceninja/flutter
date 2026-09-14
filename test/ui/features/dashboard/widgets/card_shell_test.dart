import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';

/// `DashboardCardShell.onHeaderTap` — the forgiving tap band added for
/// invoiceninja/flutter#145, where a 12 px `View All` link sitting ~25 dp tall
/// was indistinguishable from a dead link on a phone.
///
/// Note `flutter test` reports `TargetPlatform.android`, so `Env.isTouchPrimary`
/// is true unless a test says otherwise — the touch branch is the default one
/// under test here.
void main() {
  /// [width] drives `InSpacing`, which reads the **window**, so a phone-width
  /// view is what puts the header band near the floor: 40 px with a title
  /// alone, 45 with a `DashboardCardFooterLink` beside it (16/12 and 53 at the
  /// 600 px break). Those five px are the whole subject of this file.
  Future<void> pump(
    WidgetTester tester, {
    VoidCallback? onHeaderTap,
    Widget? trailing,
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        home: Scaffold(
          body: DashboardCardShell(
            title: 'Comments',
            trailing: trailing,
            onHeaderTap: onHeaderTap,
            child: const SizedBox(height: 40, child: Text('body')),
          ),
        ),
      ),
    );
  }

  Widget link() => DashboardCardFooterLink(label: 'View All', onTap: () {});

  Finder headerBand() => find
      .ancestor(
        of: find.text('Comments'),
        matching: find.byType(GestureDetector),
      )
      .first;

  testWidgets('a shell with no onHeaderTap mounts no tap band', (tester) async {
    // The guard for the nine other call sites, which pass nothing: the default
    // has to leave the header byte-identical.
    await pump(tester, trailing: link());
    final plain = tester.getSize(find.byType(DashboardCardShell)).height;
    expect(
      find.ancestor(
        of: find.text('Comments'),
        matching: find.byType(GestureDetector),
      ),
      findsNothing,
    );

    await pump(tester, trailing: link(), onHeaderTap: () {});
    expect(
      tester.getSize(find.byType(DashboardCardShell)).height,
      plain,
      reason:
          'a header carrying a link is already 45 px, so the floor does '
          'not bind and wrapping the real call site costs no height',
    );
  });

  testWidgets('a tap anywhere in the band fires it, including the padding', (
    tester,
  ) async {
    // `HitTestBehavior.opaque` is the whole point — the default `deferToChild`
    // would leave the title's slack and the header padding unhit, which is most
    // of the target this exists to add.
    var taps = 0;
    await pump(tester, onHeaderTap: () => taps++);
    final band = tester.getRect(headerBand());
    await tester.tapAt(Offset(band.right - 8, band.center.dy));
    expect(taps, 1);
    await tester.tapAt(Offset(band.left + 4, band.top + 2));
    expect(taps, 2);
  });

  testWidgets('the floor raises a band that would fall short', (tester) async {
    // A title with no trailing is 40 px on a phone — under the floor. This is
    // the case that proves the `ConstrainedBox` does something; with a link
    // beside the title the band is already 45 and the floor is insurance.
    await pump(tester, onHeaderTap: () {});
    expect(tester.getSize(headerBand()).height, InSizes.touchTarget);

    await pump(tester, trailing: link(), onHeaderTap: () {});
    expect(
      tester.getSize(headerBand()).height,
      greaterThan(InSizes.touchTarget),
    );
  });

  testWidgets('the floor is touch-only, per the token contract', (
    tester,
  ) async {
    // `InSizes.touchTarget`'s own doc says it is applied only when
    // `Env.isTouchPrimary`; a pointer platform keeps its denser metrics, so the
    // same shell that measures 44 above must measure its natural 40 here.
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await pump(tester, onHeaderTap: () {});
      expect(
        tester.getSize(headerBand()).height,
        lessThan(InSizes.touchTarget),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('the band contributes no semantics node of its own', (
    tester,
  ) async {
    // It carries a tap action with neither a role nor a label, so announcing it
    // would give a screen reader a second, silent actionable for one
    // destination. The trailing link stays the only announced target.
    final handle = tester.ensureSemantics();
    await pump(tester, onHeaderTap: () {}, trailing: link());
    expect(
      tester
          .getSemantics(find.text('View All'))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
      reason: 'the link stays the announced, activatable target',
    );
    expect(
      tester
          .getSemantics(find.text('Comments'))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isFalse,
      reason: 'the band announces nothing, so the title node gains no action',
    );
    handle.dispose();
  });
}
