// Regression test for the master-detail pane's on-screen-keyboard avoidance
// (`lib/ui/core/list/master_detail_layout.dart`, narrow branch).
//
// On a phone NOTHING above an entity edit / detail screen owns a `Scaffold`:
// `ScaffoldWithNav`'s narrow branch is a deliberate passthrough, and the list's
// Scaffold is a *sibling* of the pane in a Stack (Offstage), never an ancestor.
// So nothing consumed `MediaQuery.viewInsets.bottom`, the form's viewport kept
// its full window height under the keyboard, `EditableText` decided the caret
// was already visible, and a field low in the form stayed behind the keyboard
// — invoiceninja/flutter#105, reported against payment Private Notes.
//
// The narrow pane now owns the Scaffold, which is what makes it shrink.

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../_localization_helper.dart';

/// Minimal Services stub — this path doesn't touch it, but a provider is
/// supplied so any incidental `context.read<Services>()` resolves.
class _FakeServices implements Services {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Pane body that reports the box it was handed and whether the keyboard inset
/// was consumed on the way down. A `Scaffold` both shrinks its body AND zeroes
/// `viewInsets.bottom` for it, so `I=0` is what proves the shrink came from the
/// inset being *consumed* rather than from some unrelated constraint.
class _MetricsProbe extends StatelessWidget {
  const _MetricsProbe();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) => Text(
        'H=${constraints.maxHeight.round()} '
        'I=${MediaQuery.viewInsetsOf(ctx).bottom.round()}',
      ),
    );
  }
}

/// Pane body shaped like a real edit form: one scroll view whose only field
/// sits low enough to be under the keyboard. Focusing it is what `EditableText`
/// answers with `showCaretOnScreen` — which can only help if the viewport
/// actually shrank.
class _FormProbe extends StatelessWidget {
  const _FormProbe({required this.focusNode});

  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Sized so the field lands at y = 620..672 against the FULL 900 px
          // window — i.e. exactly where the unfixed layout leaves it: on screen,
          // inside the bottom 300 the keyboard covers, and with the content
          // (712 px) too short to give the scroll view any extent to escape
          // with. Once the pane insets, the same field starts below the 600 px
          // viewport, and the reveal has 112 px of extent to spend — it uses 97,
          // landing the field at 523..575.
          const SizedBox(height: 620),
          TextField(key: const ValueKey('notes'), focusNode: focusNode),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

void main() {
  Future<GoRouter> pumpApp(
    WidgetTester tester, {
    required Size size,
    double keyboardInset = 0,
    Widget detail = const _MetricsProbe(),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (keyboardInset > 0) {
      tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
      addTearDown(tester.view.resetViewInsets);
    }

    final router = GoRouter(
      initialLocation: '/products',
      routes: [
        ShellRoute(
          pageBuilder: (context, state, child) => NoTransitionPage<void>(
            key: const ValueKey('master_detail:/products'),
            child: Builder(
              builder: (ctx) => MasterDetailLayout(
                basePath: '/products',
                list: const Scaffold(body: Center(child: Text('LIST'))),
                rightPane: child,
                hasPane: state.matchedLocation != '/products',
                viewMode: state.uri.queryParameters['view'],
              ),
            ),
          ),
          routes: [
            GoRoute(
              path: '/products',
              builder: (_, _) => const SizedBox.shrink(),
            ),
            GoRoute(path: '/products/:id', builder: (_, _) => detail),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(),
        child: MaterialApp.router(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets(
    'narrow viewport: the full-page pane lays its body out ABOVE the on-screen '
    'keyboard (invoiceninja/flutter#105)',
    (tester) async {
      final router = await pumpApp(
        tester,
        size: const Size(400, 900),
        keyboardInset: 300,
      );

      router.go('/products/1');
      await tester.pumpAndSettle();

      // Without the pane's Scaffold this reports `H=900 I=300`: the form keeps
      // full height, extends under the keyboard, and can never scroll a covered
      // field into view.
      expect(find.text('H=600 I=0'), findsOneWidget);
    },
  );

  testWidgets('narrow viewport: no keyboard means no change in geometry', (
    tester,
  ) async {
    final router = await pumpApp(tester, size: const Size(400, 900));

    router.go('/products/1');
    await tester.pumpAndSettle();

    expect(find.text('H=900 I=0'), findsOneWidget);
  });

  testWidgets(
    'wide viewport: the pane does NOT inset — the shell Scaffold already did '
    'it, so the pane needs no Scaffold of its own there',
    (tester) async {
      // `ScaffoldWithNav`'s wide branch (>= 600) supplies the Scaffold in the
      // real app; this harness mounts `MasterDetailLayout` without a shell, so
      // the full height here is the correct expectation for the wide *pane*
      // itself. Asserting it stops the narrow fix from being copied upward.
      final router = await pumpApp(
        tester,
        size: const Size(1600, 900),
        keyboardInset: 300,
      );

      router.go('/products/1');
      await tester.pumpAndSettle();

      expect(find.text('H=900 I=300'), findsOneWidget);
    },
  );

  testWidgets(
    'narrow viewport: focusing a field the keyboard covers scrolls it back into '
    'view — the symptom reported in invoiceninja/flutter#105',
    (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      final router = await pumpApp(
        tester,
        size: const Size(400, 900),
        keyboardInset: 300,
        detail: _FormProbe(focusNode: focusNode),
      );

      router.go('/products/1');
      await tester.pumpAndSettle();

      // At rest the field is out of reach either way — behind the keyboard
      // without the fix, below the shrunken viewport with it. What differs is
      // whether focusing it can do anything about that.
      expect(
        tester.getBottomLeft(find.byKey(const ValueKey('notes'))).dy,
        greaterThan(600),
      );

      focusNode.requestFocus();
      await tester.pumpAndSettle();

      // `EditableText` reveals the caret in the nearest scrollable. That is a
      // no-op unless the viewport shrank: with the full 900 px viewport the
      // content (712 px) has no scroll extent at all, so the field stayed put
      // and the user could not reach what they were typing into.
      //
      // The bound is the viewport edge, not a tuned number — the reveal targets
      // the caret inflated by `scrollPadding` (20), so the field settles at 575
      // with 25 px to spare. Only an input `contentPadding.bottom` past ~39
      // would eat that, and then the field really would sit under the fold.
      expect(
        tester.getBottomLeft(find.byKey(const ValueKey('notes'))).dy,
        lessThanOrEqualTo(600),
      );
    },
  );
}
