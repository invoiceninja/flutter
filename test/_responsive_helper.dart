// Shared responsive-regression pump helper. Extracted from
// `clients/client_detail_cards_grid_test.dart` (the original ad-hoc `_pump`)
// so every responsive test sets up the surface, theme, and localization the
// same way and asserts overflow consistently.
//
// Usage:
//   await pumpAt(tester, 500, MyWidget());            // narrow
//   await pumpAt(tester, 1200, MyWidget());           // wide
//   expectNoOverflow(tester);                         // no RenderFlex throw
//
// The widget is wrapped in a scrollable Scaffold body so vertically tall
// content doesn't itself trip an unbounded-height error — the point is to
// catch *horizontal* overflow and unbounded-width mistakes at each width.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';

import '_localization_helper.dart';

/// Standard responsive breakpoints to sweep: narrow (mobile / sidebar),
/// medium (split), wide (desktop).
const kResponsiveWidths = <double>[500, 800, 1050, 1200];

/// The app's own text-scale settings (`kTextScaleOptions`). 1.4 is the
/// maximum a user can pick in Device Settings — and `composeTextScaler`
/// multiplies it by the OS scaler, so real users exceed it. Anything wrapping
/// scalable text needs to survive at least [kTextScaleMax].
const double kTextScaleMax = 1.4;

Future<void> pumpAt(
  WidgetTester tester,
  double width,
  Widget child, {
  double height = 1400,
  bool scroll = true,
  double textScale = 1.0,
}) async {
  await tester.binding.setSurfaceSize(Size(width, height));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final body = scroll ? SingleChildScrollView(child: child) : child;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      // Applied via `builder` rather than wrapping `home`: `WidgetsApp`
      // inserts its own `MediaQuery.fromView` *inside* MaterialApp, so an
      // outer MediaQuery would be discarded before it reached the child.
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: inner!,
      ),
      home: Scaffold(body: body),
    ),
  );
  await tester.pump();
}

/// Fails if [finder]'s widget is being rendered shorter than it wants to be.
///
/// A `SizedBox(height:)` around scalable content gives it *tight* constraints,
/// so the content is silently sliced — no overflow is thrown and
/// [expectNoOverflow] stays green. This is the check that catches it: express
/// row floors as `ConstrainedBox(minHeight:)` and the two heights agree.
void expectNotVerticallyCrushed(
  WidgetTester tester,
  Finder finder, {
  String? reason,
}) {
  final box = tester.renderObject<RenderBox>(finder);
  final intrinsic = box.getMaxIntrinsicHeight(box.size.width);
  expect(
    box.size.height,
    greaterThanOrEqualTo(intrinsic),
    reason:
        reason ??
        'rendered ${box.size.height}px but wants ${intrinsic}px — a fixed '
            'height is clipping it (use ConstrainedBox(minHeight:) instead)',
  );
}

/// Fails if the last pump produced a layout exception (RenderFlex overflow,
/// unbounded constraints, …). Call after [pumpAt].
void expectNoOverflow(WidgetTester tester) {
  expect(
    tester.takeException(),
    isNull,
    reason: 'layout overflow / constraint violation at this width',
  );
}
