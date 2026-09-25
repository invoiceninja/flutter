import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/data/db/salvage.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';
import 'package:admin/ui/features/boot/local_data_recovery_notice.dart';

import '../../../_localization_helper.dart';

/// A reset's outcome used to reach only the diagnostics log: a user whose
/// unsynced changes could not be recovered was never told. Now they are told
/// once — a toast when everything came across, a dialog when their work may
/// not have.
void main() {
  const salvaged = LocalDataSalvaged(
    rowsByTable: {'outbox': 3, 'nav_state': 1},
    source: 'invoiceninja.sqlite.broken.1',
  );
  const salvagedNothingPending = LocalDataSalvaged(
    rowsByTable: {'nav_state': 1},
    source: 'invoiceninja.sqlite.broken.1',
  );
  const partly = LocalDataSalvaged(
    rowsByTable: {'outbox': 1},
    source: 'invoiceninja.sqlite.unrecovered.1',
    incompleteTables: ['saved_views'],
  );
  const lost = LocalDataUnrecoverable(
    reason: 'file is not a database',
    retainedAt: 'invoiceninja.sqlite.unrecovered.1',
  );

  group('localDataNoticeFor', () {
    test('no reset and nothing recovered: nothing to say', () {
      expect(localDataNoticeFor(wasReset: false, recovery: null), isNull);
    });

    test('each outcome maps to what the user is told', () {
      expect(localDataNoticeFor(wasReset: true, recovery: salvaged), (
        kind: LocalDataNoticeKind.rebuilt,
        unsynced: 3,
      ));
      expect(
        localDataNoticeFor(wasReset: true, recovery: partly)?.kind,
        LocalDataNoticeKind.partlyRecovered,
      );
      expect(
        localDataNoticeFor(wasReset: true, recovery: lost)?.kind,
        LocalDataNoticeKind.notRecovered,
      );
      // Web: a reset with nothing read out of the old store.
      expect(
        localDataNoticeFor(wasReset: true, recovery: null)?.kind,
        LocalDataNoticeKind.reset,
      );
    });

    test(
      'an earlier launch\'s reset, salvaged on this open, is still news',
      () {
        expect(
          localDataNoticeFor(wasReset: false, recovery: lost)?.kind,
          LocalDataNoticeKind.notRecovered,
        );
      },
    );
  });

  group('LocalDataNoticeSlot.forgetKeptChanges', () {
    // A wipe of the local data makes the toast untrue — it counts unsynced
    // changes as kept — but not a dialog: the work it says was lost stays
    // lost, and the copy it points to is kept, wipe or not.
    test('drops the toast that counts changes as kept', () {
      final slot = LocalDataNoticeSlot(wasReset: true, recovery: salvaged)
        ..forgetKeptChanges();
      expect(slot.isPending, isFalse);
    });

    test('keeps a dialog about work that may be lost', () {
      for (final recovery in [lost, partly, null]) {
        final slot = LocalDataNoticeSlot(wasReset: true, recovery: recovery)
          ..forgetKeptChanges();
        expect(slot.isPending, isTrue, reason: '$recovery');
      }
    });
  });

  group('LocalDataNoticeHold', () {
    // Held while locked, and while no one is signed in: a sign-out that wipes
    // the data drops the notice before it can show (`onBeforeDataWipe`), and
    // one that keeps it shows it after the next sign-in. Released on the lock
    // alone, the lock screen's Sign out let it show on `/login`, saying
    // changes were kept that the sign-out had just wiped.
    late ValueNotifier<bool> locked;
    late ValueNotifier<bool> signedIn;
    late LocalDataNoticeHold hold;

    setUp(() {
      locked = ValueNotifier(true);
      signedIn = ValueNotifier(true);
      hold = LocalDataNoticeHold(
        triggers: Listenable.merge([locked, signedIn]),
        held: () => locked.value || !signedIn.value,
      );
    });
    tearDown(() {
      hold.dispose();
      locked.dispose();
      signedIn.dispose();
    });

    test('released only once unlocked and signed in', () {
      expect(hold.value, isTrue);
      signedIn.value = false; // the lock screen's Sign out
      locked.value = false; // …which drops the lock with the session
      expect(hold.value, isTrue);
      signedIn.value = true;
      expect(hold.value, isFalse);
    });

    test('says when it changes', () {
      var changes = 0;
      hold.addListener(() => changes++);
      locked.value = false;
      expect(changes, 1);
      signedIn.value = true; // no change
      expect(changes, 1);
    });
  });

  group('LocalDataRecoveryNotice', () {
    late ToastController toasts;

    setUp(() => toasts = ToastController());

    Widget app({
      required bool wasReset,
      LocalDataRecovery? recovery,
      LocalDataNoticeSlot? slot,
      ValueListenable<bool>? holdWhile,
      Key? key,
    }) => MaterialApp(
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: LocalDataRecoveryNotice(
          key: key,
          slot:
              slot ??
              LocalDataNoticeSlot(wasReset: wasReset, recovery: recovery),
          holdWhile: holdWhile ?? ValueNotifier<bool>(false),
          toasts: toasts,
        ),
      ),
    );

    testWidgets('everything carried across: a toast that counts what was '
        'kept', (tester) async {
      await tester.pumpWidget(app(wasReset: true, recovery: salvaged));
      await tester.pump();

      expect(find.byType(AlertDialog), findsNothing);
      final toast = toasts.toasts.single;
      expect(toast.variant, NotifyVariant.info);
      expect(toast.message, 'Local data was rebuilt');
      expect(toast.detail, contains('The 3 changes that hadn\'t synced'));
      // In the body, not a tearDown: the binding checks for a pending
      // auto-dismiss timer before any tearDown runs.
      toasts.clearAll();
    });

    testWidgets('nothing was pending: the toast doesn\'t count changes', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(wasReset: true, recovery: salvagedNothingPending),
      );
      await tester.pump();
      expect(
        toasts.toasts.single.detail,
        contains('Everything is downloading'),
      );
      toasts.clearAll();
    });

    testWidgets('nothing recovered: a dialog that says so, until closed', (
      tester,
    ) async {
      await tester.pumpWidget(app(wasReset: true, recovery: lost));
      await tester.pump();

      expect(find.text('Local data couldn\'t be recovered'), findsOneWidget);
      expect(find.textContaining('Device Settings'), findsOneWidget);
      expect(toasts.toasts, isEmpty);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('some left behind is a dialog too', (tester) async {
      await tester.pumpWidget(app(wasReset: true, recovery: partly));
      await tester.pump();
      expect(
        find.text('Some local data couldn\'t be recovered'),
        findsOneWidget,
      );
    });

    testWidgets('the web reset names what was lost', (tester) async {
      await tester.pumpWidget(app(wasReset: true));
      await tester.pump();
      expect(find.text('Local data was reset'), findsOneWidget);
      expect(find.textContaining('were lost'), findsOneWidget);
    });

    testWidgets('told once — a remount of the notice shows nothing more', (
      tester,
    ) async {
      // The same element was reused on a rebuild, so this never tested the
      // once-only guard — which lived in the State a remount replaces. The
      // iOS splash once remounted it, and the user was told twice.
      final slot = LocalDataNoticeSlot(wasReset: true, recovery: lost);
      await tester.pumpWidget(
        app(wasReset: true, slot: slot, key: const ValueKey(1)),
      );
      await tester.pump();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        app(wasReset: true, slot: slot, key: const ValueKey(2)),
      );
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('under the biometric lock nothing is shown over the lock '
        'screen, and the dialog appears once unlocked', (tester) async {
      // Pushed over `/lock`, the dialog went when unlocking replaced that page
      // — the user was never told their changes couldn't be recovered.
      final locked = ValueNotifier<bool>(true);
      addTearDown(locked.dispose);
      final router = GoRouter(
        initialLocation: '/home',
        refreshListenable: locked,
        redirect: (_, state) {
          final atLock = state.matchedLocation == '/lock';
          if (locked.value) return atLock ? null : '/lock';
          return atLock ? '/home' : null;
        },
        routes: [
          GoRoute(path: '/lock', builder: (_, _) => const Text('locked')),
          GoRoute(path: '/home', builder: (_, _) => const Text('home')),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          routerConfig: router,
          builder: (context, child) => Stack(
            children: [
              child!,
              LocalDataRecoveryNotice(
                slot: LocalDataNoticeSlot(wasReset: true, recovery: lost),
                holdWhile: locked,
                toasts: toasts,
                contextOf: () =>
                    router.routerDelegate.navigatorKey.currentContext,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('locked'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      locked.value = false;
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      expect(find.text('Local data couldn\'t be recovered'), findsOneWidget);
    });

    testWidgets('the rebuilt toast waits for the unlock too', (tester) async {
      // Queued at once, it expired behind the biometric prompt unseen.
      final locked = ValueNotifier<bool>(true);
      addTearDown(locked.dispose);
      await tester.pumpWidget(
        app(wasReset: true, recovery: salvaged, holdWhile: locked),
      );
      await tester.pump();
      expect(toasts.toasts, isEmpty);

      locked.value = false;
      await tester.pump();
      await tester.pump();

      expect(toasts.toasts.single.message, 'Local data was rebuilt');
      toasts.clearAll();
    });

    testWidgets('no reset: nothing at all', (tester) async {
      await tester.pumpWidget(app(wasReset: false));
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      expect(toasts.toasts, isEmpty);
    });
  });
}
