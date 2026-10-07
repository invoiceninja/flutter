import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/detail/related_tab_counts.dart';

/// The counts beside a record screen's related tabs.
///
/// `testWidgets` for its fake clock — `tester.pump(d)` is the debounce timer's
/// only way forward — not because anything here is a widget. The view model's
/// own clock is [_Server.now], moved by hand, so "fresh for a minute" is
/// tested without waiting one.

class _Server {
  final Map<String, int?> totals = {};
  final Set<String> failing = {};
  final List<(String, Map<String, String>)> calls = [];
  final Map<String, Completer<void>> holds = {};
  DateTime now = DateTime.utc(2026, 6, 15, 12);
  bool online = true;
  bool current = true;

  int inFlight = 0;
  int mostInFlight = 0;

  RelatedCountFetcher fetcher(String tab) => ({filters = const {}}) async {
    calls.add((tab, filters));
    inFlight++;
    if (inFlight > mostInFlight) mostInFlight = inFlight;
    try {
      await holds[tab]?.future;
      if (failing.contains(tab)) throw StateError('boom');
      return totals[tab];
    } finally {
      inFlight--;
    }
  };

  Map<String, RelatedCountFetcher> fetchersFor(Iterable<String> tabs) => {
    for (final t in tabs) t: fetcher(t),
  };

  List<String> get asked => [for (final c in calls) c.$1];
}

const _three = {'invoices', 'quotes', 'tasks'};
const _second = Duration(seconds: 1);

RelatedTabCountsViewModel _vm(
  _Server server, {
  RelatedTabCountsCache? cache,
  String scope = 'u|co|client|c1',
  Set<String> tabs = _three,
}) => RelatedTabCountsViewModel(
  cache: cache ?? RelatedTabCountsCache(),
  scope: scope,
  filters: const {'client_id': 'c1', 'status': 'active'},
  fetchers: server.fetchersFor(tabs),
  isOnline: () async => server.online,
  isCurrent: () => server.current,
  now: () => server.now,
);

void main() {
  testWidgets('nothing is asked until the debounce passes', (tester) async {
    final server = _Server()..totals['invoices'] = 12;
    final vm = _vm(server)..kick(tabIds: _three);
    await tester.pump(const Duration(milliseconds: 999));
    expect(server.calls, isEmpty);
    await tester.pump(const Duration(milliseconds: 2));
    expect(server.calls, hasLength(3));
    expect(vm.countFor('invoices'), 12);
    vm.dispose();
  });

  testWidgets('a record opened and left inside the debounce costs no '
      'request', (tester) async {
    // Stepping down a list with J / K.
    final server = _Server();
    final vm = _vm(server)..kick(tabIds: _three);
    await tester.pump(const Duration(milliseconds: 400));
    vm.dispose();
    await tester.pump(const Duration(seconds: 2));
    expect(server.calls, isEmpty);
  });

  testWidgets('each request carries the tab list\'s own starting filters', (
    tester,
  ) async {
    final server = _Server();
    final vm = _vm(server)..kick(tabIds: _three);
    await tester.pump(_second);
    expect(server.calls, hasLength(3), reason: 'or the loop proves nothing');
    for (final (_, filters) in server.calls) {
      expect(filters, {'client_id': 'c1', 'status': 'active'});
    }
    vm.dispose();
  });

  testWidgets('a tab the company has switched off is not asked about', (
    tester,
  ) async {
    final server = _Server();
    final vm = _vm(server)..kick(tabIds: const {'invoices'});
    await tester.pump(_second);
    expect(server.asked, ['invoices']);
    vm.dispose();
  });

  testWidgets('unknown is not zero', (tester) async {
    final server = _Server()
      ..totals['invoices'] = 0
      ..totals['quotes'] = null
      ..failing.add('tasks');
    final vm = _vm(server)..kick(tabIds: _three);
    await tester.pump(_second);
    expect(vm.countFor('invoices'), 0, reason: 'the server said none');
    expect(vm.countFor('quotes'), isNull, reason: 'no figure in the answer');
    expect(vm.countFor('tasks'), isNull, reason: 'the request failed');
    vm.dispose();
  });

  testWidgets('one failing tab does not cost the others their counts', (
    tester,
  ) async {
    final server = _Server()
      ..totals['invoices'] = 3
      ..totals['tasks'] = 9
      ..failing.add('quotes');
    var notified = 0;
    final vm = _vm(server)
      ..addListener(() => notified++)
      ..kick(tabIds: _three);
    await tester.pump(_second);
    expect(vm.countFor('invoices'), 3);
    expect(vm.countFor('tasks'), 9);
    expect(notified, 1, reason: 'one repaint for the batch');
    vm.dispose();
  });

  group('rationing', () {
    testWidgets('no more than three requests are out at once', (tester) async {
      const eight = {'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'};
      final server = _Server();
      for (final t in eight) {
        server.totals[t] = 1;
        server.holds[t] = Completer<void>();
      }
      final vm = _vm(server, tabs: eight)..kick(tabIds: eight);
      await tester.pump(_second);
      expect(server.inFlight, 3);

      // Each answer lets the next one out, until all eight have been asked.
      for (final t in eight) {
        server.holds[t]!.complete();
        await tester.pump();
        await tester.pump();
      }
      expect(server.calls, hasLength(8));
      expect(server.mostInFlight, 3);
      expect(vm.countFor('h'), 1);
      vm.dispose();
    });

    testWidgets('a re-opened record shows its counts at once, without '
        'notifying during build — and is not asked about again while they '
        'are fresh', (tester) async {
      final cache = RelatedTabCountsCache();
      final server = _Server()
        ..totals['invoices'] = 12
        ..totals['quotes'] = 0
        ..totals['tasks'] = 4;
      final first = _vm(server, cache: cache)
        ..kick(tabIds: _three, revision: 7);
      await tester.pump(_second);
      first.dispose();
      expect(server.calls, hasLength(3));

      var notified = 0;
      server.now = server.now.add(const Duration(seconds: 30));
      final second = _vm(server, cache: cache)..addListener(() => notified++);
      second.kick(tabIds: _three, revision: 7);
      // Synchronously, before any timer: `kick` runs inside the host's build.
      expect(second.countFor('invoices'), 12);
      expect(notified, 0);
      await tester.pump(const Duration(seconds: 3));
      expect(server.calls, hasLength(3), reason: 'thirty seconds old: fresh');
      second.dispose();
    });

    testWidgets('…but is, once they have aged', (tester) async {
      final cache = RelatedTabCountsCache();
      final server = _Server()..totals['invoices'] = 12;
      final first = _vm(server, cache: cache)
        ..kick(tabIds: const {'invoices'}, revision: 7);
      await tester.pump(_second);
      first.dispose();

      server
        ..now = server.now.add(const Duration(seconds: 61))
        ..totals['invoices'] = 13;
      final second = _vm(server, cache: cache)
        ..kick(tabIds: const {'invoices'}, revision: 7);
      expect(second.countFor('invoices'), 12, reason: 'the head start');
      await tester.pump(_second);
      expect(second.countFor('invoices'), 13);
      second.dispose();
    });

    testWidgets('…or the record has moved', (tester) async {
      final cache = RelatedTabCountsCache();
      final server = _Server()..totals['invoices'] = 12;
      final first = _vm(server, cache: cache)
        ..kick(tabIds: const {'invoices'}, revision: 7);
      await tester.pump(_second);
      first.dispose();

      final second = _vm(server, cache: cache)
        ..kick(tabIds: const {'invoices'}, revision: 8);
      await tester.pump(_second);
      expect(server.calls, hasLength(2));
      second.dispose();
    });

    testWidgets('kicked every build, asks once — until the record changes', (
      tester,
    ) async {
      final server = _Server()..totals['invoices'] = 1;
      final vm = _vm(server);
      for (var i = 0; i < 5; i++) {
        vm.kick(tabIds: _three, revision: 100);
      }
      await tester.pump(_second);
      expect(server.calls, hasLength(3));

      vm.kick(tabIds: _three, revision: 100);
      await tester.pump(_second);
      expect(server.calls, hasLength(3), reason: 'same record, same answer');

      // The server's copy moved — an invoice may have been added.
      server.totals['invoices'] = 2;
      vm.kick(tabIds: _three, revision: 101);
      await tester.pump(_second);
      expect(server.calls, hasLength(6));
      expect(vm.countFor('invoices'), 2);
      vm.dispose();
    });
  });

  group('refresh', () {
    testWidgets('asks again now, fresh or not', (tester) async {
      final server = _Server()..totals['invoices'] = 1;
      final vm = _vm(server)..kick(tabIds: _three);
      await tester.pump(_second);
      server.totals['invoices'] = 5;
      unawaited(vm.refresh());
      await tester.pump();
      expect(vm.countFor('invoices'), 5);
      vm.dispose();
    });

    testWidgets('a second one while the first is out joins it', (tester) async {
      final server = _Server()..totals['invoices'] = 1;
      final vm = _vm(server)..kick(tabIds: const {'invoices'});
      await tester.pump(_second);
      final before = server.calls.length;

      server.holds['invoices'] = Completer<void>();
      final a = vm.refresh();
      final b = vm.refresh();
      await tester.pump();
      expect(server.calls.length - before, 1);
      server.holds['invoices']!.complete();
      await tester.pump();
      await Future.wait([a, b]);
      vm.dispose();
    });

    testWidgets('its answers stand for the record as it is when they land', (
      tester,
    ) async {
      // A manual refresh fetches the record and the counts together, and the
      // record's newer revision usually arrives first. Filed under the old
      // one, the counts would look stale and all be asked for a second time.
      final server = _Server()..totals['invoices'] = 1;
      final vm = _vm(server)..kick(tabIds: const {'invoices'}, revision: 1);
      await tester.pump(_second);
      final before = server.calls.length;

      server.holds['invoices'] = Completer<void>();
      unawaited(vm.refresh());
      await tester.pump();
      vm.kick(tabIds: const {'invoices'}, revision: 2);
      server.holds['invoices']!.complete();
      await tester.pump(const Duration(seconds: 3));
      expect(server.calls.length - before, 1, reason: 'not asked twice');
      vm.dispose();
    });
  });

  group('offline', () {
    testWidgets('asks nothing, and keeps what is cached on screen', (
      tester,
    ) async {
      final cache = RelatedTabCountsCache()
        ..put('u|co|client|c1', 'invoices', 7, at: DateTime.utc(2020));
      final server = _Server()..online = false;
      final vm = _vm(server, cache: cache)..kick(tabIds: _three);
      await tester.pump(_second);
      expect(server.calls, isEmpty);
      expect(vm.countFor('invoices'), 7);
      expect(vm.countFor('quotes'), isNull);
      vm.dispose();
    });

    testWidgets('back online, what went unanswered is asked', (tester) async {
      final server = _Server()
        ..online = false
        ..totals['invoices'] = 3;
      final vm = _vm(server)..kick(tabIds: _three);
      await tester.pump(_second);
      // Kicked again by a rebuild: same record, so still nothing.
      vm.kick(tabIds: _three);
      await tester.pump(_second);
      expect(server.calls, isEmpty);

      server.online = true;
      vm.retryIfUnanswered();
      await tester.pump(_second);
      expect(server.calls, hasLength(3));
      expect(vm.countFor('invoices'), 3);
      vm.dispose();
    });

    testWidgets('a retry with nothing unanswered asks nothing', (tester) async {
      final server = _Server()..totals['invoices'] = 3;
      final vm = _vm(server)..kick(tabIds: _three);
      await tester.pump(_second);
      vm.retryIfUnanswered();
      await tester.pump(_second);
      expect(server.calls, hasLength(3));
      vm.dispose();
    });
  });

  group('whose counts', () {
    testWidgets('are per record and per user', (tester) async {
      final cache = RelatedTabCountsCache()
        ..put('u|co|client|c1', 'invoices', 7);
      for (final scope in ['u|co|client|c2', 'other|co|client|c1']) {
        final vm = _vm(_Server(), cache: cache, scope: scope)
          ..kick(tabIds: _three);
        expect(vm.countFor('invoices'), isNull, reason: scope);
        vm.dispose();
      }
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('an answer that lands after the session ended is not put '
        'back', (tester) async {
      final cache = RelatedTabCountsCache();
      final hold = Completer<void>();
      final server = _Server()
        ..totals['invoices'] = 4
        ..holds['invoices'] = hold;
      final vm = _vm(server, cache: cache)..kick(tabIds: const {'invoices'});
      await tester.pump(_second);
      cache.clear(); // sign-out
      hold.complete();
      await tester.pump();
      expect(cache.lastKnown('u|co|client|c1', 'invoices'), isNull);
      vm.dispose();
    });

    testWidgets('an answer that lands after a company switch is dropped', (
      tester,
    ) async {
      // It was answered under the new company's token; it is not about this
      // record at all.
      final cache = RelatedTabCountsCache();
      final hold = Completer<void>();
      final server = _Server()
        ..totals['invoices'] = 0
        ..holds['invoices'] = hold;
      final vm = _vm(server, cache: cache)..kick(tabIds: const {'invoices'});
      await tester.pump(_second);
      server.current = false;
      hold.complete();
      await tester.pump();
      expect(vm.countFor('invoices'), isNull);
      expect(cache.lastKnown('u|co|client|c1', 'invoices'), isNull);
      vm.dispose();
    });

    testWidgets('an answer that lands after the screen has gone is dropped', (
      tester,
    ) async {
      final hold = Completer<void>();
      final server = _Server()
        ..totals['invoices'] = 4
        ..holds['invoices'] = hold;
      var notified = 0;
      final vm = _vm(server)
        ..addListener(() => notified++)
        ..kick(tabIds: const {'invoices'});
      await tester.pump(_second);
      vm.dispose();
      hold.complete();
      await tester.pump();
      expect(notified, 0);
    });
  });
}
