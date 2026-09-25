import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/db_open_exception.dart';
import 'package:admin/ui/features/boot/local_data_unavailable_app.dart';

/// The boot screen renders before `Services` and localization exist, so its
/// copy is plain English and picked per platform and per failure kind — the
/// advice that fixes a lock ("close your other tab") is useless for a full
/// disk, and the web and native resets cost different things.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    DbOpenFailureKind? kind,
    required bool isWeb,
    bool isDesktop = false,
    Future<bool> Function()? resetStore,
    void Function()? reload,
    void Function()? quit,
  }) => tester.pumpWidget(
    LocalDataUnavailableApp(
      detail: 'SqliteException(5): database is locked',
      kind: kind,
      isWeb: isWeb,
      isDesktop: isDesktop,
      resetStore: resetStore ?? () async => true,
      reload: reload ?? () {},
      quit: quit ?? () {},
    ),
  );

  testWidgets('a lock on web says another tab, and offers Try again first', (
    tester,
  ) async {
    await pump(tester, kind: DbOpenFailureKind.transient, isWeb: true);
    expect(find.textContaining('open in another tab'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Reset local data'), findsOneWidget);
    expect(find.textContaining('are lost'), findsOneWidget);
    expect(find.text('SqliteException(5): database is locked'), findsOneWidget);
  });

  testWidgets('a lock on native says relaunch, with no page to reload', (
    tester,
  ) async {
    await pump(tester, kind: DbOpenFailureKind.transient, isWeb: false);
    expect(find.textContaining('busy or temporarily unavailable'), findsOne);
    expect(find.text('Try again'), findsNothing);
    expect(find.text('Then relaunch the app.'), findsOneWidget);
    // Natively a reset carries unsynced work across when it can.
    expect(find.textContaining('carried over'), findsOneWidget);
  });

  testWidgets('another copy of the app says so, and offers no Reset — it '
      'would move the store out from under that copy', (tester) async {
    await pump(tester, kind: DbOpenFailureKind.inUse, isWeb: false);
    expect(find.textContaining('already open in another window'), findsOne);
    expect(find.text('Reset local data'), findsNothing);
    expect(find.textContaining('Resetting'), findsNothing);
    expect(find.text('Then relaunch the app.'), findsNothing);
  });

  testWidgets('a desktop window, which may have no close button of its own, '
      'offers Quit — for another copy of the app the only way out', (
    tester,
  ) async {
    var quits = 0;
    await pump(
      tester,
      kind: DbOpenFailureKind.inUse,
      isWeb: false,
      isDesktop: true,
      quit: () => quits++,
    );
    await tester.tap(find.text('Quit'));
    expect(quits, 1);

    await pump(tester, kind: DbOpenFailureKind.corrupt, isWeb: false);
    expect(find.text('Quit'), findsNothing, reason: 'a phone closes it');
  });

  testWidgets('a full disk says so, per platform', (tester) async {
    await pump(tester, kind: DbOpenFailureKind.storageFull, isWeb: true);
    expect(find.textContaining('browser has run out of storage'), findsOne);
    await pump(tester, kind: DbOpenFailureKind.storageFull, isWeb: false);
    expect(find.textContaining('device has run out of storage'), findsOne);
  });

  testWidgets('a failed recovery gets the plain explanation', (tester) async {
    await pump(tester, isWeb: false);
    expect(
      find.text('Invoice Ninja could not open its local database.'),
      findsOneWidget,
    );
  });

  testWidgets('Reset moves the store aside, then reloads on web', (
    tester,
  ) async {
    final gate = Completer<bool>();
    var reloads = 0;
    await pump(
      tester,
      kind: DbOpenFailureKind.corrupt,
      isWeb: true,
      resetStore: () => gate.future,
      reload: () => reloads++,
    );

    await tester.tap(find.text('Reset local data'));
    await tester.pump();
    expect(find.text('Resetting…'), findsOneWidget);
    expect(reloads, 0, reason: 'not before the store has moved');

    gate.complete(true);
    await tester.pump();
    expect(reloads, 1);
  });

  testWidgets('Reset on native comes back ready for a relaunch, even when '
      'the reset throws', (tester) async {
    await pump(
      tester,
      kind: DbOpenFailureKind.corrupt,
      isWeb: false,
      resetStore: () async => throw StateError('rename failed'),
    );

    await tester.tap(find.text('Reset local data'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Reset local data'), findsOneWidget);
    expect(find.text('Resetting…'), findsNothing);
  });
}
