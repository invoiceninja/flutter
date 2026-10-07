import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/detail/record_screen_controller.dart';
import 'package:admin/ui/core/detail/related_tab_counts.dart';

/// `RecordScreenController` — the timing rules every record screen shares.
/// `testWidgets` for its fake clock; nothing here is a widget.

class _Probe {
  final List<String> refreshed = [];
  final List<(String, Map<String, String>)> counted = [];
  bool has = true;
  int settled = 0;

  RelatedCountFetcher counter(String tab) => ({filters = const {}}) async {
    counted.add((tab, filters));
    return 3;
  };
}

/// The app, as far as the controller can tell.
class _Env {
  final ChangeNotifier backOnline = ChangeNotifier();
  final RelatedTabCountsCache cache = RelatedTabCountsCache();
  String? activeCompany = 'co1';
  bool online = true;
}

void main() {
  /// Runs [body] with a fake environment and disposes whatever it [owned].
  Future<void> withServices(
    WidgetTester tester,
    Future<void> Function(_Env s, List<RecordScreenController> owned) body,
  ) async {
    final env = _Env();
    final owned = <RecordScreenController>[];
    try {
      await body(env, owned);
    } finally {
      for (final c in owned) {
        c.dispose();
      }
      env.backOnline.dispose();
      await tester.pump(const Duration(seconds: 3));
    }
  }

  RecordScreenController controller(
    _Env env, {
    String routeId = 'r1',
    String wireName = 'project',
    required Future<void> Function(String id) refreshRecord,
    bool Function()? hasRecord,
    String? countFilterKey,
    Map<String, String> countFilterKeys = const {},
    Map<String, Map<String, String>> countExtras = const {},
    Map<String, RelatedCountFetcher> countFetchers = const {},
    List<Future<void> Function()> refreshWith = const [],
    List<Future<void> Function()> refreshAfter = const [],
    VoidCallback? onSettled,
    VoidCallback? onBackOnline,
  }) => RecordScreenController.withEnvironment(
    backOnline: env.backOnline,
    activeCompanyId: () => env.activeCompany,
    userId: () => 'u1',
    countsCache: env.cache,
    isOnline: () async => env.online,
    companyId: 'co1',
    routeId: routeId,
    entityWireName: wireName,
    refreshRecord: refreshRecord,
    hasRecord: hasRecord ?? () => true,
    countFilterKey: countFilterKey,
    countFilterKeys: countFilterKeys,
    countExtras: countExtras,
    countFetchers: countFetchers,
    refreshWith: refreshWith,
    refreshAfter: refreshAfter,
    onSettled: onSettled,
    onBackOnline: onBackOnline,
  );

  RecordScreenController build(
    _Env s,
    _Probe probe, {
    String routeId = 'r1',
    Map<String, String> filterKeys = const {},
  }) => controller(
    s,
    routeId: routeId,
    refreshRecord: (id) async => probe.refreshed.add(id),
    hasRecord: () => probe.has,
    countFilterKey: 'project_id',
    countFilterKeys: filterKeys,
    countFetchers: {
      'invoices': probe.counter('invoices'),
      'tasks': probe.counter('tasks'),
    },
    onSettled: () => probe.settled++,
  );

  const second = Duration(seconds: 2);
  const tabs = {'invoices', 'tasks'};

  /// Lets the count requests (plain async closures) finish.
  Future<void> drain(WidgetTester tester) async {
    await tester.pump(second);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }

  testWidgets('re-checks the record after a pause, then counts — in that '
      'order', (tester) async {
    await withServices(tester, (s, owned) async {
      final probe = _Probe();
      final c = build(s, probe)..attach(recordId: 'r1', tabIds: tabs);
      owned.add(c);

      await tester.pump(const Duration(milliseconds: 299));
      expect(probe.refreshed, isEmpty);
      expect(c.settled, isFalse);
      await tester.pump(const Duration(milliseconds: 2));
      expect(probe.refreshed, ['r1']);
      expect(c.settled, isTrue);
      expect(probe.settled, 1);
      expect(probe.counted, isEmpty, reason: 'the counts debounce after that');

      await drain(tester);
      expect(probe.counted.map((c) => c.$1).toSet(), tabs);
      expect(c.countFor('invoices'), 3);
    });
  });

  testWidgets('each tab is counted with the key its own list uses', (
    tester,
  ) async {
    // A project is `project_id` on invoices and `project_tasks` on tasks.
    await withServices(tester, (s, owned) async {
      final probe = _Probe();
      final c = build(s, probe, filterKeys: const {'tasks': 'project_tasks'})
        ..attach(recordId: 'r1', tabIds: tabs);
      owned.add(c);
      await tester.pump(second);
      await drain(tester);

      final by = {for (final (tab, filters) in probe.counted) tab: filters};
      expect(by['invoices'], {'project_id': 'r1', 'status': 'active'});
      expect(by['tasks'], {'project_tasks': 'r1', 'status': 'active'});
    });
  });

  testWidgets('a tab\'s count carries what its list sends besides the '
      'parent', (tester) async {
    // A repository adds some parameters by itself — `without_deleted_clients`
    // on most client-bearing lists, `active_banks` on transactions — and a
    // count asked without them is of a different set of rows.
    await withServices(tester, (s, owned) async {
      final probe = _Probe();
      final c = controller(
        s,
        refreshRecord: (id) async {},
        countFilterKey: 'project_id',
        countFilterKeys: const {'tasks': 'project_tasks'},
        countExtras: const {
          'tasks': {'without_deleted_clients': 'true'},
          'invoices': {'without_deleted_clients': 'true'},
        },
        countFetchers: {
          'invoices': probe.counter('invoices'),
          'tasks': probe.counter('tasks'),
          'quotes': probe.counter('quotes'),
        },
      )..attach(recordId: 'r1', tabIds: const {'invoices', 'tasks', 'quotes'});
      owned.add(c);
      await tester.pump(second);
      await drain(tester);

      final by = {for (final (tab, filters) in probe.counted) tab: filters};
      expect(by['tasks'], {
        'project_tasks': 'r1',
        'status': 'active',
        'without_deleted_clients': 'true',
      });
      // The extra goes with the default key too, not only an overridden one.
      expect(by['invoices'], {
        'project_id': 'r1',
        'status': 'active',
        'without_deleted_clients': 'true',
      });
      expect(by['quotes'], {'project_id': 'r1', 'status': 'active'});
    });
  });

  testWidgets('counts the session already holds are announced when the '
      're-check settles — with no request', (tester) async {
    // A record re-opened: its counts are in the session cache. Adopting them
    // is silent by design (it was written to run inside build), and the
    // re-check is not build — so unless the controller says something, a
    // strip that listens to it shows no badges and a `RelatedRowsProof` never
    // learns the count says it is short.
    await withServices(tester, (s, owned) async {
      final first = _Probe();
      final a = controller(
        s,
        refreshRecord: (id) async {},
        countFilterKey: 'project_id',
        countFetchers: {'invoices': first.counter('invoices')},
      )..attach(recordId: 'r1', revision: 7, tabIds: const {'invoices'});
      await tester.pump(second);
      await drain(tester);
      expect(a.countFor('invoices'), 3);
      a.dispose();

      // The same record, opened again.
      final again = _Probe();
      var heard = 0;
      final b =
          controller(
              s,
              refreshRecord: (id) async {},
              countFilterKey: 'project_id',
              countFetchers: {'invoices': again.counter('invoices')},
            )
            ..addListener(() => heard++)
            ..attach(recordId: 'r1', revision: 7, tabIds: const {'invoices'});
      owned.add(b);
      expect(b.countFor('invoices'), isNull, reason: 'not before it settles');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(b.countFor('invoices'), 3);
      expect(heard, greaterThan(0), reason: 'the strip has to hear about it');
      await drain(tester);
      expect(again.counted, isEmpty, reason: 'fresh for this revision');
    });
  });

  testWidgets('offline, the record is not asked for — and the screen still '
      'settles', (tester) async {
    // The request would only fail, and every failed by-id fetch is logged at
    // WARNING: one line per cached record opened without a connection.
    await withServices(tester, (s, owned) async {
      s.online = false;
      final probe = _Probe();
      final c = build(s, probe)..attach(recordId: 'r1', tabIds: tabs);
      owned.add(c);
      await tester.pump(second);
      expect(probe.refreshed, isEmpty);
      expect(c.settled, isTrue);
      expect(probe.settled, 1);

      await c.refresh();
      expect(probe.refreshed, isEmpty, reason: 'nor on a manual refresh');

      s.online = true;
      await c.refresh();
      expect(probe.refreshed, ['r1']);
    });
  });

  testWidgets('a record that is not on the server is neither re-checked nor '
      'counted', (tester) async {
    await withServices(tester, (s, owned) async {
      final probe = _Probe();
      final c = build(s, probe, routeId: 'tmp_1')
        ..attach(recordId: 'tmp_1', tabIds: tabs);
      owned.add(c);
      expect(c.settled, isTrue, reason: 'nothing to wait for');
      await tester.pump(second);
      await drain(tester);
      expect(probe.refreshed, isEmpty);
      expect(probe.counted, isEmpty);
    });
  });

  testWidgets('…and once it syncs, it is counted under its server id', (
    tester,
  ) async {
    // The screen keeps its `tmp_…` route; the record does not keep that id.
    await withServices(tester, (s, owned) async {
      final probe = _Probe();
      final c = build(s, probe, routeId: 'tmp_1')
        ..attach(recordId: 'tmp_1', tabIds: tabs);
      owned.add(c);
      await tester.pump(second);

      c.attach(recordId: 'real9', tabIds: tabs);
      await drain(tester);
      expect(probe.counted, isNotEmpty);
      for (final (_, filters) in probe.counted) {
        expect(filters['project_id'], 'real9');
      }
    });
  });

  testWidgets('a record not held locally is not fetched by id', (tester) async {
    // That is the hydrate's job; a re-check is of a record we have.
    await withServices(tester, (s, owned) async {
      final probe = _Probe()..has = false;
      final c = build(s, probe)..attach(recordId: 'r1', tabIds: tabs);
      owned.add(c);
      await tester.pump(second);
      expect(probe.refreshed, isEmpty);
      expect(c.mayRefreshRecord, isFalse);
      expect(c.settled, isTrue, reason: 'it still settles');
    });
  });

  testWidgets('after a company switch nothing is fetched by id', (
    tester,
  ) async {
    // The screen outlives the switch and still holds the old company's
    // record, while the token is the new company's.
    await withServices(tester, (s, owned) async {
      final probe = _Probe();
      final c = build(s, probe)..attach(recordId: 'r1', tabIds: tabs);
      owned.add(c);
      s.activeCompany = 'co2';
      await tester.pump(second);
      expect(probe.refreshed, isEmpty);
      expect(c.mayRefreshRecord, isFalse);
      await c.refresh();
      expect(probe.refreshed, isEmpty, reason: 'nor on a manual refresh');
    });
  });

  testWidgets('offline nothing is counted; back online, it is', (tester) async {
    await withServices(tester, (s, owned) async {
      final probe = _Probe();
      var heard = 0;
      s.online = false;
      final c = controller(
        s,
        refreshRecord: (id) async {},
        countFilterKey: 'project_id',
        countFetchers: {'invoices': probe.counter('invoices')},
        onBackOnline: () => heard++,
      )..attach(recordId: 'r1', tabIds: const {'invoices'});
      owned.add(c);
      await tester.pump(second);
      await drain(tester);
      expect(probe.counted, isEmpty);

      s.online = true;
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      s.backOnline.notifyListeners();
      await drain(tester);
      expect(heard, 1, reason: 'the host hears too');
      expect(probe.counted, hasLength(1));
    });
  });

  testWidgets('a refresh covers the record, what refreshes beside it, the '
      'list on stage, then what depends on the record', (tester) async {
    await withServices(tester, (s, owned) async {
      final order = <String>[];
      final c = controller(
        s,
        refreshRecord: (id) async => order.add('record'),
        hasRecord: () => true,
        refreshWith: [() async => order.add('activity')],
        refreshAfter: [() async => order.add('after')],
      )..attach(recordId: 'r1');
      owned.add(c);
      var signals = 0;
      c.page.refreshSignal.addListener(() => signals++);
      await tester.pump(second);
      order.clear();

      await c.refresh();
      expect(signals, 1, reason: 'the embedded list hears through the page');
      expect(order.last, 'after');
      expect(order.toSet(), {'record', 'activity', 'after'});
    });
  });

  testWidgets('one part of a refresh throwing does not fail the rest', (
    tester,
  ) async {
    await withServices(tester, (s, owned) async {
      var after = 0;
      final c = controller(
        s,
        refreshRecord: (id) async => throw StateError('boom'),
        hasRecord: () => true,
        refreshWith: [() async => throw StateError('boom too')],
        refreshAfter: [() async => after++],
      )..attach(recordId: 'r1');
      owned.add(c);
      await tester.pump(second);
      await c.refresh();
      expect(after, 1);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('disposed mid-flight, it touches nothing afterwards', (
    tester,
  ) async {
    await withServices(tester, (s, owned) async {
      final gate = Completer<void>();
      var settled = 0;
      final c = controller(
        s,
        refreshRecord: (id) => gate.future,
        hasRecord: () => true,
        onSettled: () => settled++,
      )..attach(recordId: 'r1');
      await tester.pump(const Duration(milliseconds: 400));
      c.dispose();
      gate.complete();
      await tester.pump();
      expect(settled, 0);
    });
  });
}
