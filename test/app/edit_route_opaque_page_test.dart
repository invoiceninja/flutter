// The edit route is the one page the entity block's shell Navigator pushes
// over another (`/x/:id/edit` nests under `/x/:id`), and the embedded detail
// and edit bodies paint no background of their own — the pane's `bg` sits
// behind the Navigator. So the edit page slid in see-through: for the length
// of the push the form's fields and the record's text were drawn on top of
// each other (the phone's Edit button on an invoice).
//
// Uses the production `buildEntityRouteBlock`, at phone width, with bodies
// that — like the real embedded screens — bring no `Scaffold`.

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../_localization_helper.dart';

void main() {
  testWidgets('the edit page paints an opaque surface over the detail it '
      'slides in above', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/quotes/q1',
      routes: [
        buildEntityRouteBlock(
          basePath: '/quotes',
          list: (_, _) => const Scaffold(body: Text('LIST')),
          create: null,
          detail: (_, _) => const Text('DETAIL'),
          edit: (_, _) => const Text('EDIT'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: buildInTheme(InTheme.dark),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    router.go('/quotes/q1/edit');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Mid-transition: both pages are on screen.
    expect(find.text('DETAIL'), findsOneWidget);
    expect(find.text('EDIT'), findsOneWidget);

    bool opaqueSurface(Widget w) =>
        w is Material && w.color == InTheme.dark.bg && w.color!.a == 1;
    final editSurface = find.ancestor(
      of: find.text('EDIT'),
      matching: find.byWidgetPredicate(opaqueSurface),
    );
    final detailSurface = find.ancestor(
      of: find.text('DETAIL'),
      matching: find.byWidgetPredicate(opaqueSurface),
    );
    // The edit page has a surface the detail page does not share — i.e. one
    // inside the edit route, not the pane's own background behind both.
    final editOnly = editSurface.evaluate().toSet().difference(
      detailSurface.evaluate().toSet(),
    );
    expect(editOnly, isNotEmpty);

    await tester.pumpAndSettle();
  });
}
