import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  group('LocalDataRecoveryNotice', () {
    late ToastController toasts;

    setUp(() => toasts = ToastController());

    Widget app({required bool wasReset, LocalDataRecovery? recovery}) =>
        MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: LocalDataRecoveryNotice(
              wasReset: wasReset,
              recovery: recovery,
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

    testWidgets('told once — a rebuild of the app shows nothing more', (
      tester,
    ) async {
      await tester.pumpWidget(app(wasReset: true, recovery: lost));
      await tester.pump();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(app(wasReset: true, recovery: lost));
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('no reset: nothing at all', (tester) async {
      await tester.pumpWidget(app(wasReset: false));
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      expect(toasts.toasts, isEmpty);
    });
  });
}
