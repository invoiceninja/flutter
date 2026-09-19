import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/widgets/focus_owner_keeper.dart';

/// `FocusOwnerKeeper` is the reason `ScaffoldWithNav`'s keyboard layer cannot be
/// switched off by a focus change nobody made on purpose. The real shell can't
/// be pumped (it needs `Services`, a `GoRouter` and a `StatefulNavigationShell`),
/// which is exactly why the recovery lives in a leaf that can: everything below
/// is the genuine framework mechanism, not a mock of it.
///
/// Every failure this guards against is silent — the widget tree is identical,
/// nothing throws, keys simply stop arriving — so each test asserts on
/// `FocusManager.instance.primaryFocus` *and* on a real key actually reaching
/// the handler.
void main() {
  late FocusNode shell;
  late List<LogicalKeyboardKey> seen;

  setUp(() {
    shell = FocusNode(debugLabel: 'shell');
    seen = <LogicalKeyboardKey>[];
  });

  tearDown(() => shell.dispose());

  Widget harness({
    required int revision,
    required StaleFocusTest focusIsStale,
    Widget body = const SizedBox.shrink(),
    bool withKeeper = true,
    bool enabled = true,
    bool Function()? canClaim,
  }) {
    final leader = Focus(
      focusNode: shell,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) seen.add(event.logicalKey);
        return KeyEventResult.handled;
      },
      child: body,
    );
    return MaterialApp(
      home: Scaffold(
        body: withKeeper
            ? FocusOwnerKeeper(
                node: shell,
                revision: revision,
                focusIsStale: focusIsStale,
                enabled: enabled,
                canClaim: canClaim,
                child: leader,
              )
            : leader,
      ),
    );
  }

  // Two frames: the first runs the post-frame check, the second applies the
  // focus change it requested. Deliberately not `pumpAndSettle` — a bug that
  // made the keeper re-arm itself would hang the suite for ten minutes instead
  // of failing.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  group('focus escaping above the shell', () {
    testWidgets('unfocus() parks focus on the enclosing route scope, and the '
        'keeper brings it back', (tester) async {
      await tester.pumpWidget(harness(revision: 0, focusIsStale: (_) => false));
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, shell);

      // The real trigger: `FocusNode.unfocus()`'s default
      // `UnfocusDisposition.scope` clears the scope's remembered children and
      // parks primary focus on the scope *itself* — an ancestor of the shell,
      // so nothing below it can ever see a key again. Both edit-save paths do
      // exactly this to flush an unblurred field.
      FocusManager.instance.primaryFocus!.unfocus();
      await settle(tester);

      expect(FocusManager.instance.primaryFocus, shell);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      expect(seen, <LogicalKeyboardKey>[LogicalKeyboardKey.keyG]);
    });

    testWidgets('without the keeper the same unfocus kills every shortcut '
        '(the bug being fixed)', (tester) async {
      await tester.pumpWidget(
        harness(revision: 0, focusIsStale: (_) => false, withKeeper: false),
      );
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, shell);

      FocusManager.instance.primaryFocus!.unfocus();
      await settle(tester);

      expect(FocusManager.instance.primaryFocus, isNot(shell));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      expect(
        seen,
        isEmpty,
        reason:
            'key dispatch walks up from primaryFocus and never down, so a '
            'scope above the shell skips the whole keyboard layer — on macOS '
            'the keystroke then falls through to AppKit and beeps',
      );
    });

    testWidgets('claims when it mounts under an ancestor that already holds '
        'focus, with no route change to move it', (tester) async {
      // The case the class doc names as its own reason to exist — "a list
      // rebuilt under a route that already existed" — and the one the rest of
      // this file cannot see, because `harness` always mounts with
      // `primaryFocus == null`, which escapes through the `primary == null` arm.
      //
      // It matters because `_schedule` evaluates `_needsCheck()` *synchronously*
      // from `didChangeDependencies`, i.e. during the keeper's own first build,
      // before the child `Focus` has reparented the node. So `node.ancestors` is
      // still empty at that moment, and a direction test that reads it cannot
      // tell "above" from "beside" yet. Nothing re-arms afterwards:
      // `didChangeDependencies` won't re-run, `didUpdateWidget` sees no change,
      // and attaching a node fires no `FocusManager` notification.
      //
      // Live trigger: the Tasks view toggle `go`s `/tasks`, which go_router
      // treats as a no-op on an unchanged `RouteMatchList`, so the body swaps
      // through a `ValueListenableBuilder` with no route push, no disposal and
      // no focus change at all.
      final ancestor = FocusNode(debugLabel: 'ancestor');
      addTearDown(ancestor.dispose);

      Widget tree({required bool withKeeper}) => MaterialApp(
        home: Scaffold(
          body: Focus(
            focusNode: ancestor,
            autofocus: true,
            child: withKeeper
                ? FocusOwnerKeeper(
                    node: shell,
                    focusIsStale: (_) => false,
                    child: Focus(
                      focusNode: shell,
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent) seen.add(event.logicalKey);
                        return KeyEventResult.handled;
                      },
                      child: const SizedBox.shrink(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      );

      await tester.pumpWidget(tree(withKeeper: false));
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, ancestor);

      await tester.pumpWidget(tree(withKeeper: true));
      await settle(tester);

      expect(
        FocusManager.instance.primaryFocus,
        shell,
        reason:
            'the surface mounted with focus above it and nothing else will ever '
            'move it, so a keeper that declines here leaves every shortcut '
            'below it dead until the user clicks',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      expect(seen, <LogicalKeyboardKey>[LogicalKeyboardKey.keyN]);
    });

    testWidgets('focus parked on the root scope is reclaimed', (tester) async {
      await tester.pumpWidget(harness(revision: 0, focusIsStale: (_) => false));
      await tester.pump();

      // Where `FocusManager` lands when a focused node is disposed and nothing
      // else claims focus (`_markDetached` → `applyFocusChangesIfNeeded`).
      FocusManager.instance.rootScope.requestScopeFocus();
      await settle(tester);

      expect(FocusManager.instance.primaryFocus, shell);
    });
  });

  group('routes above the shell', () {
    testWidgets('a dialog keeps its focus, and the shell reclaims on close', (
      tester,
    ) async {
      await tester.pumpWidget(harness(revision: 0, focusIsStale: (_) => false));
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, shell);

      final closed = showDialog<void>(
        context: tester.element(find.byType(Scaffold)),
        builder: (_) => const AlertDialog(content: SizedBox.shrink()),
      );
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus,
        isNot(shell),
        reason:
            'a dialog on the root navigator legitimately owns focus above '
            'the shell — stealing it back would break its Esc / Enter',
      );

      Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      await tester.pumpAndSettle();
      await settle(tester);
      await closed;

      expect(
        FocusManager.instance.primaryFocus,
        shell,
        reason:
            'a popped route hands focus back to the shell page\'s own '
            'scope, which is an ancestor of the shell node, not a descendant',
      );
    });
  });

  group('a nested navigator — the entity list\'s real shape', () {
    // The group above passes because `harness` mounts ONE navigator, so the
    // keeper's nearest `ModalRoute` is the same route the dialog is pushed over
    // and `isCurrent` flips to false. The entity list is not shaped like that.
    //
    // `buildEntityRouteBlock` is a `ShellRoute` whose `pageBuilder` builds the
    // list as a *sibling* of its inner Navigator, and that shell page lives on a
    // `StatefulShellRoute.indexedStack` branch Navigator. So the list's nearest
    // `ModalRoute` is the branch's page — and `Route.isCurrent` is strictly
    // per-navigator (`navigator.dart`: it compares `this` against its own
    // `_navigator`'s last present route entry). `showDialog` defaults to
    // `useRootNavigator: true`, so that branch page stays `isCurrent == true`
    // for the whole life of the dialog and `_routeIsCurrent` never stands down.
    //
    // Note the inversion this makes: `showModalBottomSheet` defaults to the
    // *nearest* navigator, so sheets disarm the keeper and dialogs do not —
    // the opposite way round from what the guard is for.
    Widget nested({bool Function()? canClaim}) => MaterialApp(
      home: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: FocusOwnerKeeper(
              node: shell,
              focusIsStale: (_) => false,
              canClaim: canClaim,
              child: Focus(
                focusNode: shell,
                autofocus: true,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) seen.add(event.logicalKey);
                  return KeyEventResult.handled;
                },
                child: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('a dialog on the ROOT navigator keeps its focus', (
      tester,
    ) async {
      await tester.pumpWidget(nested());
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, shell);

      unawaited(
        showDialog<void>(
          context: tester.element(find.byType(Scaffold)),
          builder: (_) =>
              const AlertDialog(content: TextField(autofocus: true)),
        ),
      );
      await tester.pumpAndSettle();
      // The keeper's post-frame reclaim needs two more frames to land, and
      // `pumpAndSettle` above has already given it them — but pump again so a
      // reclaim scheduled off the dialog's own focus change is included.
      await settle(tester);

      expect(
        FocusManager.instance.primaryFocus,
        isNot(shell),
        reason:
            'the dialog legitimately owns focus. Reclaiming it blurs the '
            'field one frame after it opens, so the command palette cannot be '
            'typed into and its arrow keys stop working — and because '
            'isTextInputFocused() is then false, bare letters are serviced by '
            'the list underneath instead (N navigates behind the dialog)',
      );

      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();
      expect(
        find.text('abc'),
        findsOneWidget,
        reason: 'a field the keeper keeps blurring cannot be typed into',
      );
    });

    testWidgets('a field in a sibling subtree — the master-detail pane — keeps '
        'its focus', (tester) async {
      // The create-route half of the same bug, and the reason the fix is the
      // direction test rather than a better route check. `/x/new` is its own
      // `GoRoute` with no `:id`, so `paneIsOpenForList` (which reads
      // `pathParameters['id']`) is false there even though the pane is up and
      // owns focus — and on a wide window `MasterDetailLayout` keeps the list
      // mounted under `Offstage`, whose children "can receive focus and have
      // keyboard input directed to them". So neither of the keeper's two guards
      // fires, and the list pulls focus off the create form.
      //
      // No `canClaim` here on purpose: this asserts the keeper leaves a sibling
      // alone on its own, without the host having to know about it.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: FocusOwnerKeeper(
                    node: shell,
                    focusIsStale: (_) => false,
                    child: Focus(
                      focusNode: shell,
                      autofocus: true,
                      child: const SizedBox.shrink(),
                    ),
                  ),
                ),
                // The pane: a sibling of the keeper's node, not a descendant.
                const Expanded(child: TextField()),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, shell);

      await tester.tap(find.byType(TextField));
      await settle(tester);

      expect(
        FocusManager.instance.primaryFocus,
        isNot(shell),
        reason:
            'every tap into a create-form field would otherwise be blurred '
            'one frame later, so the form is untypable and the keystrokes '
            'drive the hidden list instead',
      );

      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();
      expect(find.text('abc'), findsOneWidget);
    });
  });

  group('app lifecycle', () {
    testWidgets('stands down while suspended', (tester) async {
      await tester.pumpWidget(harness(revision: 0, focusIsStale: (_) => false));
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, shell);

      // On a desktop host the framework parks focus on the root scope itself
      // here and restores its `_suspendedNode` on resume; reclaiming would make
      // it discard that and blur whatever the user was typing in. The park is
      // staged by hand because `FocusManager` registers its lifecycle listener
      // everywhere *but* `android` and `iOS` (`_respondToLifecycleChange`,
      // flutter#148475) while `flutter test` always reports `android`, so the
      // lifecycle change alone moves no focus at all here — and
      // `debugDefaultTargetPlatformOverride` cannot reach it either, since that
      // decision is made in the constructor of a `FocusManager` the test
      // binding builds during the *previous* test's `postTest`. What is under
      // test is the keeper standing down, not the framework's own suspend.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      FocusManager.instance.rootScope.requestScopeFocus();
      await settle(tester);
      expect(
        FocusManager.instance.primaryFocus,
        isNot(shell),
        reason:
            'the identical park is reclaimed within these two frames while '
            'resumed — see `focus parked on the root scope is reclaimed`, '
            'which is what makes this a real assertion',
      );

      // Coming back is the keeper's job here, not the framework's: the
      // `_suspendedNode` restore it would normally ride on never happened.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
      expect(FocusManager.instance.primaryFocus, shell);
    });
  });

  group('branch switches', () {
    late FocusNode branchA;
    late FocusNode branchB;
    late FocusNode inA;
    late FocusNode inB;
    late FocusNode chrome;
    late int index;

    setUp(() {
      branchA = FocusNode(debugLabel: 'branchA');
      branchB = FocusNode(debugLabel: 'branchB');
      inA = FocusNode(debugLabel: 'inA');
      inB = FocusNode(debugLabel: 'inB');
      chrome = FocusNode(debugLabel: 'chrome');
      index = 0;
    });

    tearDown(() {
      branchA.dispose();
      branchB.dispose();
      inA.dispose();
      inB.dispose();
      chrome.dispose();
    });

    // go_router keeps every visited branch mounted behind an `Offstage`, which
    // does not move focus — so both subtrees stay focusable, exactly as they do
    // in the app.
    Widget branches() => Column(
      children: [
        Focus(
          focusNode: branchA,
          child: Focus(focusNode: inA, child: const SizedBox(height: 1)),
        ),
        Focus(
          focusNode: branchB,
          child: Focus(focusNode: inB, child: const SizedBox(height: 1)),
        ),
        // Shell chrome — the sidebar's stand-in. It belongs to no branch, which
        // is the whole point of the third test below.
        Focus(focusNode: chrome, child: const SizedBox(height: 1)),
      ],
    );

    bool inHiddenBranch(FocusNode? primary) {
      if (primary == null) return false;
      final hidden = index == 0 ? branchB : branchA;
      return identical(primary, hidden) || primary.ancestors.contains(hidden);
    }

    Widget tree() => harness(
      revision: index,
      focusIsStale: inHiddenBranch,
      body: branches(),
    );

    testWidgets('focus left behind in the outgoing branch returns to the '
        'shell', (tester) async {
      await tester.pumpWidget(tree());
      await tester.pump();
      inA.requestFocus();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, inA);

      index = 1;
      await tester.pumpWidget(tree());
      await settle(tester);

      expect(
        FocusManager.instance.primaryFocus,
        shell,
        reason:
            'key dispatch is leaf-first, so focus parked in the hidden '
            'branch lets that branch\'s Shortcuts service a bare N / E / arrow '
            'meant for the screen on screen',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      expect(seen, <LogicalKeyboardKey>[LogicalKeyboardKey.keyG]);
    });

    testWidgets('focus already inside the new branch is left alone', (
      tester,
    ) async {
      await tester.pumpWidget(tree());
      await tester.pump();
      inB.requestFocus();
      await tester.pump();

      index = 1;
      await tester.pumpWidget(tree());
      await settle(tester);

      expect(FocusManager.instance.primaryFocus, inB);
    });

    testWidgets('shell chrome keeps its focus across a branch switch', (
      tester,
    ) async {
      // The reason the test is "focus is in a *hidden branch*" rather than
      // "focus is not in the active branch": a sidebar row a keyboard user has
      // tabbed to belongs to no branch, and the negated form would take away
      // their place in the traversal order every time they activated one.
      await tester.pumpWidget(tree());
      await tester.pump();
      chrome.requestFocus();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, chrome);

      index = 1;
      await tester.pumpWidget(tree());
      await settle(tester);

      expect(FocusManager.instance.primaryFocus, chrome);
    });
  });

  group('host gates', () {
    testWidgets('a disabled keeper stands down entirely', (tester) async {
      // What keeps two keepers off the same focus: the entity list disables
      // itself while its branch is off stage, so the hidden branch's list and
      // the visible one can never both claim.
      await tester.pumpWidget(
        harness(revision: 0, focusIsStale: (_) => false, enabled: false),
      );
      await tester.pump();
      FocusManager.instance.rootScope.requestScopeFocus();
      await settle(tester);

      expect(FocusManager.instance.primaryFocus, isNot(shell));

      // …and re-enabling is itself a trigger: nothing else would prompt one,
      // because focus did not move.
      await tester.pumpWidget(harness(revision: 0, focusIsStale: (_) => false));
      await settle(tester);
      expect(FocusManager.instance.primaryFocus, shell);
    });

    testWidgets('canClaim is consulted at check time, not at build time', (
      tester,
    ) async {
      var covered = true;
      await tester.pumpWidget(
        harness(
          revision: 0,
          focusIsStale: (_) => false,
          canClaim: () => !covered,
        ),
      );
      await tester.pump();
      FocusManager.instance.rootScope.requestScopeFocus();
      await settle(tester);
      expect(FocusManager.instance.primaryFocus, isNot(shell));

      // Nothing re-delivers the value — the same closure simply reads
      // differently on the next check, which is the point of it being a
      // callback: the list refuses to subscribe to "is a pane open" and
      // rebuild on every row click, and relies on the check being reached by a
      // focus notification instead.
      covered = false;
      await tester.pumpWidget(
        harness(
          revision: 1,
          focusIsStale: (_) => false,
          canClaim: () => !covered,
        ),
      );
      await settle(tester);
      expect(FocusManager.instance.primaryFocus, shell);
    });
  });
}
