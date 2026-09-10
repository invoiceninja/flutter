import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/widgets/picker_dismissal.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';

import '../../../_localization_helper.dart';

/// `RawAutocomplete` is not a route and carries no back handling at all — no
/// `PopScope`, no `BackButtonListener`, no `NavigatorPopHandler`. Its overlay is
/// an `OverlayPortal` and `_canShowOptionsView` closes it only on a pick, on
/// Escape (a hardware keyboard) or on focus loss. So on Android, back with a
/// picker popover open reached `SystemBackGate` and navigated off the screen —
/// or exited the app outright, since that gate calls `SystemNavigator.pop()`
/// when there is no history to go back to. That was invoiceninja/flutter#134.
///
/// These drive a real `MaterialApp.router` + `GoRouter`, because the fix hangs
/// off `Router.backButtonDispatcher`: a bare `MaterialApp` has none, and
/// [BackDismissiblePickerOverlay] deliberately degrades to plain popover
/// behaviour there — so a test pumped that way would pass either way and prove
/// nothing. The one exception is the last test, which asserts exactly that
/// degradation.
///
/// `flutter test` forces `TargetPlatform.android`, so `Env.isTouchPrimary` is
/// true and a four-item picker is a `_suppressKeyboard` one: the harness
/// reproduces the reported configuration (a one-user roster, no soft keyboard
/// for the Android IME to swallow the back press) for free.
class _Option {
  const _Option(this.id, this.name);
  final String id;
  final String name;
}

const _items = [
  _Option('1', 'Apple'),
  _Option('2', 'Apricot'),
  _Option('3', 'Banana'),
];

void main() {
  /// The platform's back gesture. `WidgetsBinding.handlePopRoute` is what the
  /// engine calls on Android; `RootBackButtonDispatcher` observes it.
  Future<void> pressBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  /// Starts on `/one` and pushes `/two`, so a back press that is *not* consumed
  /// by the popover has something observable to do. Without the push, an
  /// unhandled back reaches `SystemNavigator.pop()`, which a widget test cannot
  /// see — and every assertion below would then be vacuous.
  Future<(GoRouter, List<_Option?>)> pumpPicker(WidgetTester tester) async {
    final picked = <_Option?>[];
    final router = GoRouter(
      initialLocation: '/one',
      routes: [
        GoRoute(path: '/one', builder: (_, _) => const Text('page one')),
        GoRoute(
          path: '/two',
          builder: (_, _) => Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: SearchableDropdownField<_Option>(
                  label: 'Fruit',
                  items: _items,
                  initialValue: null,
                  displayString: (o) => o.name,
                  idOf: (o) => o.id,
                  onChanged: picked.add,
                ),
              ),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    unawaited(router.push('/two'));
    await tester.pumpAndSettle();
    return (router, picked);
  }

  Future<void> openPopover(WidgetTester tester) async {
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.text('Apricot'), findsOneWidget, reason: 'popover should open');
  }

  testWidgets('back closes an open popover instead of navigating', (
    tester,
  ) async {
    final (router, picked) = await pumpPicker(tester);
    await openPopover(tester);

    await pressBack(tester);

    expect(
      find.text('Apricot'),
      findsNothing,
      reason: 'the popover must close',
    );
    expect(
      router.state.uri.path,
      '/two',
      reason: 'and back must NOT have left the screen underneath it',
    );
    expect(find.byType(TextField), findsOneWidget);
    expect(picked, isEmpty, reason: 'closing is not picking');
  });

  testWidgets('the next back navigates normally', (tester) async {
    // The strongest single sequence here: it proves the claim AND the
    // release-on-unmount, without depending on `SystemNavigator.pop()` being
    // observable. A wrapper that never released would eat this second press.
    final (router, _) = await pumpPicker(tester);
    await openPopover(tester);

    await pressBack(tester);
    expect(router.state.uri.path, '/two');

    await pressBack(tester);
    expect(find.text('page one'), findsOneWidget);
  });

  testWidgets('back still navigates when no popover is open', (tester) async {
    // Without this, a "fix" that swallowed every back press on the screen would
    // pass the first test.
    await pumpPicker(tester);
    expect(find.byType(TextField), findsOneWidget);

    await pressBack(tester);

    expect(find.text('page one'), findsOneWidget);
  });

  testWidgets('a popover closed by picking releases its back handler', (
    tester,
  ) async {
    // The leak test. `onSelected` hides the overlay, which unmounts the wrapper;
    // a stale registration would swallow the back below.
    final (_, picked) = await pumpPicker(tester);
    await openPopover(tester);

    await tester.tap(find.text('Apricot'));
    await tester.pumpAndSettle();
    expect(picked.single?.name, 'Apricot');

    await pressBack(tester);

    expect(find.text('page one'), findsOneWidget);
  });

  testWidgets('a popover closed by tapping away releases its back handler', (
    tester,
  ) async {
    // The other dismissal path from `picker_dismissal.dart`. Unlike a pick this
    // one unfocuses, so it exercises the blur route into unmount.
    await pumpPicker(tester);
    await openPopover(tester);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Apricot'), findsNothing);

    await pressBack(tester);

    expect(find.text('page one'), findsOneWidget);
  });

  testWidgets('the wrapper forgets its dispatcher on unmount', (tester) async {
    // Pins `_release()`, which **no behavioural test can see** — and that is
    // the point worth writing down. `_onBack` opens with `if (!mounted) return
    // false`, so a leaked `ChildBackButtonDispatcher` declines exactly as a
    // released one does and back falls through either way. The two are
    // redundant by design; the redundancy is what makes the behaviour
    // identical. What is actually lost is `parent.forget(this)` — the only
    // path out of the root's `LinkedHashSet` (`router.dart:1159-1165`) — so
    // every popover open leaks a dispatcher for the life of the app.
    //
    // So observe the ledger instead of the outcome: a `RootBackButtonDispatcher`
    // subclass counting `deferTo` / `forget`. That needs `MaterialApp.router`'s
    // split form, since `routerConfig` would supply GoRouter's own dispatcher.
    var mounted = true;
    late void Function(void Function()) rebuild;
    final dispatcher = _CountingRootDispatcher();

    final router = GoRouter(
      initialLocation: '/one',
      routes: [
        GoRoute(path: '/one', builder: (_, _) => const Text('page one')),
        GoRoute(
          path: '/two',
          builder: (_, _) => Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return mounted
                    ? BackDismissibleOverlay(
                        onBack: () {},
                        child: const Text('popover'),
                      )
                    : const Text('gone');
              },
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerDelegate: router.routerDelegate,
        routeInformationParser: router.routeInformationParser,
        routeInformationProvider: router.routeInformationProvider,
        backButtonDispatcher: dispatcher,
      ),
    );
    await tester.pumpAndSettle();
    unawaited(router.push('/two'));
    await tester.pumpAndSettle();

    expect(dispatcher.deferrals, 1, reason: 'mounting claims priority');
    expect(dispatcher.forgets, 0);

    rebuild(() => mounted = false);
    await tester.pumpAndSettle();

    expect(
      dispatcher.forgets,
      1,
      reason:
          'unmounting must call removeCallback, whose only job is to reach '
          '`parent.forget(this)` — without it the child stays in the root\'s '
          'set for ever and every popover open leaks one',
    );
  });

  /// The callback form, which `token_search_field.dart`'s two `OverlayPortal`
  /// menus use. They are driven by an `OverlayPortalController` and their
  /// visibility is deliberately decoupled from focus, so the picker form's
  /// `focusNode.unfocus()` would swallow the press and leave the menu on screen
  /// — "back is dead", strictly worse than the bug. Hence `onBack` +
  /// `canDismiss`.
  testWidgets('the callback form runs onBack and honours canDismiss', (
    tester,
  ) async {
    var open = true;
    // Two DISTINCT closures, swapped between builds. Closing over one mutable
    // counter would pass even if the wrapper had captured the first `onBack` at
    // registration time — the callback is registered once as a tear-off and
    // must read `widget.onBack` at call time, which only a changed closure
    // identity can prove.
    var useSecond = false;
    var first = 0;
    var second = 0;
    late void Function(void Function()) rebuild;

    final router = GoRouter(
      initialLocation: '/one',
      routes: [
        GoRoute(path: '/one', builder: (_, _) => const Text('page one')),
        GoRoute(
          path: '/two',
          builder: (_, _) => Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return BackDismissibleOverlay(
                  onBack: useSecond ? () => second++ : () => first++,
                  canDismiss: () => open,
                  child: const Text('overlay'),
                );
              },
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    unawaited(router.push('/two'));
    await tester.pumpAndSettle();

    await pressBack(tester);
    expect(first, 1, reason: 'onBack runs while canDismiss agrees');
    expect(router.state.uri.path, '/two', reason: 'and the press is consumed');

    // A rebuilt parent's NEW closure must be the one that runs.
    rebuild(() => useSecond = true);
    await tester.pumpAndSettle();

    await pressBack(tester);
    expect(
      second,
      1,
      reason: 'the current widget.onBack runs, not a stale one',
    );
    expect(first, 1, reason: 'and the superseded closure does not');

    // Declining must fall through to the Router rather than eat the press —
    // the failure mode has to be "back behaves normally", never "back is dead".
    rebuild(() => open = false);
    await tester.pumpAndSettle();

    await pressBack(tester);
    expect(second, 1, reason: 'onBack must not run when canDismiss declines');
    expect(find.text('page one'), findsOneWidget);
  });

  testWidgets('a picker with no Router still opens and closes its popover', (
    tester,
  ) async {
    // `Router.maybeOf`, not `Router.of`: the picker suites pump bare
    // `MaterialApp`s, and Flutter's own `BackButtonListener` would throw in all
    // of them. Those suites are the real net; this states the intent where
    // someone about to "simplify" the lookup will read it.
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: SearchableDropdownField<_Option>(
                label: 'Fruit',
                items: _items,
                initialValue: null,
                displayString: (o) => o.name,
                idOf: (o) => o.id,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.text('Apricot'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// Counts what the root dispatcher is actually told, so a test can see a leaked
/// child that behaves identically to a released one. `deferTo` / `forget` are
/// the only public surface for this — `BackButtonDispatcher` exposes no view of
/// its `_children`.
class _CountingRootDispatcher extends RootBackButtonDispatcher {
  int deferrals = 0;
  int forgets = 0;

  @override
  void deferTo(ChildBackButtonDispatcher child) {
    deferrals++;
    super.deferTo(child);
  }

  @override
  void forget(ChildBackButtonDispatcher child) {
    forgets++;
    super.forget(child);
  }
}
