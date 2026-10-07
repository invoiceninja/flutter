import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/repositories/ensure_loaded_outcome.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_state_banner.dart';
import 'package:admin/ui/core/detail/generic_detail_view_model.dart';

import '../../../_localization_helper.dart';

/// What the scaffold does for a record that did not load, and for one in a
/// state the user needs told about.

class _Harness {
  final rows = StreamController<String?>();
  late final vm = GenericDetailViewModel<String>.bound(rows.stream);
  void dispose() {
    vm.dispose();
    rows.close();
  }
}

Future<_Harness> _pump(
  WidgetTester tester, {
  Future<Object?> Function()? hydrate,
  String? record,
  Widget? Function(BuildContext, String)? banner,
  bool Function(String)? isReadOnly,
  Future<void> Function()? onRefresh,
  Widget? emptyAction,
}) async {
  final h = _Harness();
  addTearDown(h.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: EntityDetailScaffold<String>(
        // A fresh State per pump. Without it a second `_pump` in one test
        // reuses the first one's State, `initState` does not run again, and
        // the hydrate under test is never called.
        key: UniqueKey(),
        id: 'x',
        vm: h.vm,
        hydrate: hydrate,
        emptyTitle: 'Not found',
        emptyAction: emptyAction,
        bannerForItem: banner,
        isReadOnly: isReadOnly,
        onRefresh: onRefresh,
        // Nothing in the body takes focus by itself — as in the app.
        bodyBuilder: (context, item) => _Body(item: item),
      ),
    ),
  );
  h.rows.add(record);
  // The focus keeper claims post-frame; give it its frames.
  await tester.pump();
  await tester.pump();
  await tester.pump();
  return h;
}

/// A body with state worth losing: it counts its own mounts, and it scrolls.
class _Body extends StatefulWidget {
  const _Body({required this.item});
  final String item;

  static int mounts = 0;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  @override
  void initState() {
    super.initState();
    _Body.mounts++;
  }

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      for (var i = 0; i < 60; i++)
        SizedBox(height: 40, child: Text('${widget.item} row $i')),
    ],
  );
}

void main() {
  group('a record that did not load', () {
    testWidgets('unreachable is not "not found", and can be retried', (
      tester,
    ) async {
      // The record may well exist — the device is offline. "Not found" here
      // sent a user with a good link looking for something never missing.
      var calls = 0;
      await _pump(
        tester,
        hydrate: () async {
          calls++;
          return calls == 1
              ? EnsureLoadedOutcome.unreachable
              : EnsureLoadedOutcome.missing;
        },
      );
      expect(find.text('No internet connection'), findsOneWidget);
      expect(find.text('Not found'), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(calls, 2, reason: 'Retry runs the hydrate again');
      // This time the server answered: there is no such record.
      expect(find.text('Not found'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a server error offers Retry too', (tester) async {
      await _pump(tester, hydrate: () async => EnsureLoadedOutcome.failed);
      expect(find.text('An error occurred'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('Retry sits beside the host\'s own way onward, not instead '
        'of it', (tester) async {
      // On a full-page host "go to the list" is the only way off this screen.
      await _pump(
        tester,
        hydrate: () async => EnsureLoadedOutcome.unreachable,
        emptyAction: const Text('Go to list'),
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Go to list'), findsOneWidget);
    });

    testWidgets('once the record has been seen, its going away is "not '
        'found" — not the old "could not be reached"', (tester) async {
      final h = await _pump(
        tester,
        hydrate: () async => EnsureLoadedOutcome.unreachable,
      );
      expect(find.text('No internet connection'), findsOneWidget);
      // A later sync delivers it…
      h.rows.add('rec');
      await tester.pump();
      await tester.pump();
      expect(find.text('rec row 0'), findsOneWidget);
      // …and later still it is removed.
      h.rows.add(null);
      await tester.pump();
      await tester.pump();
      expect(find.text('Not found'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a hydrate that throws is a failure, not a crash', (
      tester,
    ) async {
      await _pump(tester, hydrate: () async => throw StateError('boom'));
      expect(tester.takeException(), isNull);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('missing, or a hydrate that says nothing, is "not found"', (
      tester,
    ) async {
      await _pump(tester, hydrate: () async => EnsureLoadedOutcome.missing);
      expect(find.text('Not found'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);

      // A hydrate with nothing to report — the pre-outcome contract.
      await _pump(tester, hydrate: () async => null);
      expect(find.text('Not found'), findsOneWidget);
    });
  });

  group('the state banner', () {
    testWidgets('sits above the body and does not scroll with it', (
      tester,
    ) async {
      await _pump(
        tester,
        record: 'rec',
        banner: (context, item) =>
            const SizedBox(height: 40, child: Text('banner')),
      );
      final before = tester.getTopLeft(find.text('banner')).dy;
      expect(before, lessThan(tester.getTopLeft(find.text('rec row 0')).dy));

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();
      expect(find.text('rec row 0').hitTestable(), findsNothing);
      expect(tester.getTopLeft(find.text('banner')).dy, before);
    });

    testWidgets('a builder that returns null mounts nothing', (tester) async {
      await _pump(tester, record: 'rec', banner: (context, item) => null);
      expect(find.text('rec row 0'), findsOneWidget);
    });

    testWidgets('coming and going leaves the page under it alone', (
      tester,
    ) async {
      // Archive, Undo, Restore: each flips the banner. The body used to be
      // returned bare without one and inside a Column with one, so every flip
      // remounted the page — back to the top, every tab's filter gone.
      _Body.mounts = 0;
      final h = await _pump(
        tester,
        record: 'rec',
        banner: (context, item) => item == 'archived'
            ? const SizedBox(height: 40, child: Text('banner'))
            : null,
      );
      expect(_Body.mounts, 1);
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();
      final scrolled = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .pixels;
      expect(scrolled, greaterThan(0));

      for (final next in ['archived', 'rec', 'archived']) {
        h.rows.add(next);
        await tester.pump();
        await tester.pump();
      }
      expect(find.text('banner'), findsOneWidget);
      expect(_Body.mounts, 1, reason: 'the same page, not a new one');
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        scrolled,
      );
    });
  });

  group('entityStateBanner', () {
    Future<void> pumpBanner(WidgetTester tester, Widget? banner) =>
        tester.pumpWidget(
          MaterialApp(
            theme: buildInTheme(InTheme.light),
            localizationsDelegates: kTestLocalizationsDelegates,
            supportedLocales: kTestSupportedLocales,
            home: Scaffold(body: banner ?? const Text('nothing')),
          ),
        );

    testWidgets('an ordinary record gets none', (tester) async {
      await pumpBanner(
        tester,
        entityStateBanner(
          entityId: 'c1',
          isDeleted: false,
          archivedAt: null,
          formatter: null,
        ),
      );
      expect(find.text('nothing'), findsOneWidget);
    });

    testWidgets('deleted says it is read-only and offers Restore', (
      tester,
    ) async {
      var restored = 0;
      await pumpBanner(
        tester,
        entityStateBanner(
          entityId: 'c1',
          isDeleted: true,
          // Deleted outranks archived, as it does in the header's pills.
          archivedAt: DateTime.utc(2024),
          formatter: null,
          onRestore: () => restored++,
        ),
      );
      expect(
        find.text('This record is deleted. Restore it to make changes.'),
        findsOneWidget,
      );
      expect(find.textContaining('Archived'), findsNothing);
      await tester.tap(find.text('Restore'));
      expect(restored, 1);
    });

    testWidgets('archived says so; no Restore for a user who cannot', (
      tester,
    ) async {
      await pumpBanner(
        tester,
        entityStateBanner(
          entityId: 'c1',
          isDeleted: false,
          archivedAt: DateTime.utc(2024, 3, 9, 12),
          formatter: null,
        ),
      );
      expect(find.text('Archived'), findsOneWidget);
      expect(find.text('Restore'), findsNothing);
    });
  });

  group('keys', () {
    testWidgets('R refreshes the record — with nothing clicked first', (
      tester,
    ) async {
      var refreshes = 0;
      await _pump(tester, record: 'rec', onRefresh: () async => refreshes++);
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyR), isTrue);
      await tester.pump();
      expect(refreshes, 1);
    });

    testWidgets('R held down, or pressed again mid-refresh, is one refresh', (
      tester,
    ) async {
      var refreshes = 0;
      final gate = Completer<void>();
      await _pump(
        tester,
        record: 'rec',
        onRefresh: () {
          refreshes++;
          return gate.future;
        },
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyR);
      for (var i = 0; i < 5; i++) {
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyR);
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyR);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      expect(refreshes, 1);

      gate.complete();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      expect(refreshes, 2, reason: 'and available again once it lands');
    });

    testWidgets('a refresh that throws is not an unhandled error', (
      tester,
    ) async {
      await _pump(
        tester,
        record: 'rec',
        onRefresh: () async => throw StateError('boom'),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('R is left alone on a screen with no refresh', (tester) async {
      await _pump(tester, record: 'rec');
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyR), isFalse);
    });

    testWidgets('E does not open a read-only record for editing', (
      tester,
    ) async {
      // The edit action reads `GoRouterState`, which this harness does not
      // have — so reaching it throws. A read-only record must return first.
      await _pump(tester, record: 'rec', isReadOnly: (_) => true);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.pump();
      expect(tester.takeException(), isNull);

      // The converse, so the assertion above is not vacuous.
      await _pump(tester, record: 'rec', isReadOnly: (_) => false);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.pump();
      expect(tester.takeException(), isNotNull);
    });
  });
}
