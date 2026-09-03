import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/domain/phone/call_note.dart';
import 'package:admin/ui/features/activity/view_models/activity_view_model.dart';

import '../dashboard/_fake_dashboard_repo.dart';

/// Reference instant used to build day-grouping fixtures.
///
/// Built in **local** time on purpose. The unit under test is a *local*
/// calendar-day bucket, and nothing here asserts a fixed date — only that two
/// rows share a day or don't. Pinning the fixture to a UTC hour instead is the
/// trap: the usual 11:00–13:00 UTC safe band (CLAUDE.md § Strict rules) covers
/// UTC−11 … UTC+10, so 11:00 UTC is already the *next* local day in
/// Pacific/Auckland under DST (UTC+13) and the grouping assertions flip. Midday
/// local is a full 12 hours from either midnight in every zone.
///
/// A DST jump can shift the `daysAgo` subtraction by an hour; from 12:00 that
/// still can't cross midnight, so the calendar day is unchanged.
DateTime _at(int daysAgo, {int hour = 12}) {
  final now = DateTime.now();
  return DateTime(
    now.year,
    now.month,
    now.day,
    hour,
  ).subtract(Duration(days: daysAgo));
}

DashboardActivity _activity({
  required String id,
  int type = 4,
  String? userId,
  String? userLabel,
  String notes = '',
  String? clientLabel,
  DateTime? at,
}) => DashboardActivity.fromJson(<String, dynamic>{
  'id': id,
  'activity_type_id': type,
  'created_at': (at ?? _at(0)).millisecondsSinceEpoch ~/ 1000,
  'notes': notes,
  'ip': '10.0.0.1',
  if (userId != null)
    'user': {'label': userLabel ?? 'User $userId', 'hashed_id': userId},
  if (clientLabel != null)
    'client': {'label': clientLabel, 'hashed_id': 'client_$id'},
});

void main() {
  // `ActivityViewModel` defers a mid-frame recompute through `SchedulerBinding`
  // (see `_recomputeSoon`), which needs a binding — as `reports_view_model_test`
  // does for the same reason.
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeDashboardRepo repo;
  late ActivityViewModel vm;

  /// Titles the VM would otherwise get from `ActivityFormatter` (which needs a
  /// BuildContext). Mirrors the real sentence closely enough to test matching.
  String title(DashboardActivity a) =>
      '${a.labels['user'] ?? ''} touched ${a.labels['client'] ?? ''}'.trim();

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = FakeDashboardRepo(db);
    vm = ActivityViewModel(repo: repo, companyId: 'co1')
      ..setTitleResolver(title);
  });

  tearDown(() async {
    vm.dispose();
    await db.close();
  });

  Future<void> emit(List<DashboardActivity> rows) async {
    repo.activities.add(rows);
    await Future<void>.delayed(Duration.zero);
  }

  List<DashboardActivity> rowsOf(ActivityViewModel v) => [
    for (final e in v.entries)
      if (e is ActivityFeedItem) e.activity,
  ];

  test('refreshes on construction so a cold open is not empty forever', () {
    expect(repo.refreshActivitiesCalls, 1);
  });

  group('lens persistence', () {
    test('a blob written before the lens existed still decodes', () {
      // `nav_state.filters_json` on disk today carries `{'comments': true}`.
      // Dropping that key would silently clear the user's filter on upgrade.
      final f = ActivityFilters.fromJson(const {'comments': true});
      expect(f.lens, ActivityLens.comments);
      expect(f.isActive, isTrue);
    });

    test('calls round-trips, and still writes nothing when unset', () {
      const calls = ActivityFilters(lens: ActivityLens.calls);
      expect(ActivityFilters.fromJson(calls.toJson()).lens, ActivityLens.calls);
      expect(const ActivityFilters().toJson(), isEmpty);
    });

    test('calls does NOT write the legacy key — an older build widens to All '
        'rather than lying', () {
      expect(
        const ActivityFilters(lens: ActivityLens.calls).toJson()['comments'],
        isNull,
      );
    });
  });

  group('filters', () {
    late DashboardActivity byAlice;
    late DashboardActivity byBob;
    late DashboardActivity comment;
    late DashboardActivity call;

    setUp(() async {
      byAlice = _activity(
        id: '1',
        userId: 'alice',
        userLabel: 'Alice',
        clientLabel: 'Acme',
      );
      byBob = _activity(
        id: '2',
        type: 6,
        userId: 'bob',
        userLabel: 'Bob',
        clientLabel: 'Globex',
      );
      comment = _activity(
        id: '3',
        type: kCommentActivityTypeId,
        userId: 'alice',
        userLabel: 'Alice',
        notes: 'chasing the renewal',
      );
      call = _activity(
        id: '4',
        type: kCommentActivityTypeId,
        userId: 'bob',
        userLabel: 'Bob',
        // A logged call is the same activity type as a comment; only the
        // marker in the text tells them apart, which is why the lens is a
        // content filter and not a type one.
        notes: '$kCallNoteMarker Outgoing · 3 Sep 2026\nrang, will pay Friday',
      );
      await emit([byAlice, byBob, comment, call]);
    });

    test('no filter keeps every row', () {
      expect(rowsOf(vm).map((a) => a.id), ['1', '2', '3', '4']);
      expect(vm.matchCount, 4);
      expect(vm.filters.isActive, isFalse);
    });

    test('user narrows to that actor', () {
      vm.setUser('alice');
      expect(rowsOf(vm).map((a) => a.id), ['1', '3']);
      expect(vm.matchCount, 2);
    });

    test('type narrows to the selected ids', () {
      vm.setTypeIds({6});
      expect(rowsOf(vm).map((a) => a.id), ['2']);
    });

    test('comments keeps everything a person wrote, calls included', () {
      vm.setLens(ActivityLens.comments);
      expect(rowsOf(vm).map((a) => a.id), ['3', '4']);
    });

    test('calls narrows to the marker-bearing notes', () {
      vm.setLens(ActivityLens.calls);
      expect(rowsOf(vm).map((a) => a.id), ['4']);
    });

    test('the two lenses nest — calls are a subset of comments', () {
      // Modelled as one enum rather than two booleans for exactly this: two
      // switches would let a user ask for "calls but not comments", which
      // selects nothing and reads as a bug.
      vm.setLens(ActivityLens.calls);
      final calls = rowsOf(vm).map((a) => a.id).toSet();
      vm.setLens(ActivityLens.comments);
      final comments = rowsOf(vm).map((a) => a.id).toSet();
      expect(comments.containsAll(calls), isTrue);
    });

    test('comments-only overrides the type filter rather than colliding', () {
      // The sheet disables the type picker while comments-only is on; the
      // predicate has to agree, or a *persisted* pair would resurrect a filter
      // the UI is hiding and silently return nothing.
      vm.setTypeIds({6});
      vm.setLens(ActivityLens.comments);
      expect(rowsOf(vm).map((a) => a.id), ['3', '4']);
    });

    test('search matches the rendered sentence', () {
      vm.setSearch('globex');
      expect(rowsOf(vm).map((a) => a.id), ['2']);
    });

    test('search matches notes', () {
      vm.setSearch('renewal');
      expect(rowsOf(vm).map((a) => a.id), ['3']);
    });

    test('search matches a label the sentence never renders', () {
      vm.setSearch('Acme');
      expect(rowsOf(vm).map((a) => a.id), ['1']);
    });

    test('filters compose', () {
      vm.setUser('alice');
      vm.setSearch('renewal');
      expect(rowsOf(vm).map((a) => a.id), ['3']);
      expect(vm.filters.activeCount, 2);
    });

    test('clearFilters restores the full window', () {
      vm.setUser('alice');
      vm.setLens(ActivityLens.comments);
      vm.clearFilters();
      expect(rowsOf(vm).map((a) => a.id), ['1', '2', '3', '4']);
      expect(vm.filters.isActive, isFalse);
    });

    test('windowCount reports the unfiltered size', () {
      vm.setUser('alice');
      expect(vm.matchCount, 2);
      expect(vm.windowCount, 4);
    });
  });

  group('day grouping', () {
    test('emits one header per local day, newest first', () async {
      await emit([
        _activity(id: 'a', at: _at(0)),
        _activity(id: 'b', at: _at(0, hour: 13)),
        _activity(id: 'c', at: _at(1)),
      ]);

      final kinds = vm.entries
          .map((e) => e is ActivityDayHeader ? 'H' : 'R')
          .join();
      expect(kinds, 'HRRHR');

      final headers = vm.entries.whereType<ActivityDayHeader>().toList();
      expect(headers, hasLength(2));
      expect(headers.first.day.isAfter(headers.last.day), isTrue);
    });

    test('rows are ordered newest-first inside a day', () async {
      final early = _activity(id: 'early', at: _at(0, hour: 12));
      final late_ = _activity(id: 'late', at: _at(0, hour: 13));
      await emit([early, late_]);
      expect(rowsOf(vm).map((a) => a.id), ['late', 'early']);
    });

    test('filtering out a whole day drops its header too', () async {
      await emit([
        _activity(id: 'today', userId: 'alice', at: _at(0)),
        _activity(id: 'y', userId: 'bob', at: _at(1)),
      ]);
      vm.setUser('alice');
      expect(vm.entries.whereType<ActivityDayHeader>(), hasLength(1));
      expect(rowsOf(vm).map((a) => a.id), ['today']);
    });
  });

  group('async state', () {
    test('a null emission leaves no entries (skeleton, not empty)', () {
      expect(vm.section.data, isNull);
      expect(vm.entries, isEmpty);
    });

    test('a refresh failure keeps the rows already on screen', () async {
      await emit([_activity(id: '1')]);
      repo.refreshActivitiesError = StateError('boom');
      await vm.refresh();
      expect(vm.section.hasError, isTrue);
      expect(vm.section.hasData, isTrue, reason: 'stale rows must survive');
      expect(rowsOf(vm), hasLength(1));
    });
  });

  group('setTitleResolver', () {
    test('is inert when no search is active', () async {
      await emit([_activity(id: '1', userId: 'alice', clientLabel: 'Acme')]);
      var notifications = 0;
      vm.addListener(() => notifications++);

      // The screen hands over a *fresh closure* on every dependency change —
      // theme toggle, rotation, and every frame of a desktop window drag. With
      // no search there is nothing for it to change, so this must not recompute
      // and must not notify: notifying here reaches the filter sheet's
      // ListenableBuilder (root navigator, so out of scope) mid-build.
      vm.setTitleResolver((a) => 'completely different ${a.id}');

      expect(notifications, 0);
      expect(rowsOf(vm).map((a) => a.id), ['1']);
    });

    test('re-filters when a search is active', () async {
      await emit([
        _activity(id: '1', userId: 'alice', userLabel: 'Alice'),
        _activity(id: '2', userId: 'bob', userLabel: 'Bob'),
      ]);
      vm.setSearch('zebra');
      expect(rowsOf(vm), isEmpty);

      // A renderer whose output now matches must bring the row back.
      vm.setTitleResolver((a) => a.id == '2' ? 'zebra crossing' : 'nope');
      await Future<void>.delayed(Duration.zero);
      expect(rowsOf(vm).map((a) => a.id), ['2']);
    });
  });

  group('disposal while work is in flight', () {
    test('a refresh completing after dispose does not notify', () async {
      // The constructor starts a refresh, so this window is open every time the
      // screen is first opened; a company switch or logout lands inside it.
      // `ChangeNotifier` asserts on a post-dispose notify, so an unguarded
      // `finally { notifyListeners(); }` throws here.
      final gate = Completer<void>();
      repo.refreshActivitiesGate = gate;
      final subject = ActivityViewModel(repo: repo, companyId: 'co1')
        ..setTitleResolver(title);

      subject.dispose();
      gate.complete();
      // Let the awaiting `refresh()` resume and run its `finally`.
      await Future<void>.delayed(Duration.zero);
      repo.refreshActivitiesGate = null;
    });

    test(
      'a failing refresh completing after dispose does not notify',
      () async {
        final gate = Completer<void>();
        repo.refreshActivitiesGate = gate;
        repo.refreshActivitiesError = StateError('boom');
        final subject = ActivityViewModel(repo: repo, companyId: 'co1')
          ..setTitleResolver(title);

        subject.dispose();
        gate.complete();
        await Future<void>.delayed(Duration.zero);
        repo
          ..refreshActivitiesGate = null
          ..refreshActivitiesError = null;
      },
    );

    test('hydration completing after dispose does not notify', () async {
      final subject = ActivityViewModel(
        repo: repo,
        companyId: 'co1',
        navStateDao: db.navStateDao,
      )..setTitleResolver(title);
      // Dispose before the nav_state read resolves.
      subject.dispose();
      await subject.hydration;
    });
  });

  group('restore on restart', () {
    test('round-trips the filters through nav_state', () async {
      final saver = ActivityViewModel(
        repo: repo,
        companyId: 'co1',
        navStateDao: db.navStateDao,
        persistDebounce: Duration.zero,
      )..setTitleResolver(title);
      await saver.hydration;
      saver
        ..setUser('alice')
        ..setLens(ActivityLens.comments)
        ..setSearch('renewal');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      saver.dispose();

      final restored = ActivityViewModel(
        repo: repo,
        companyId: 'co1',
        navStateDao: db.navStateDao,
      )..setTitleResolver(title);
      await restored.hydration;
      expect(restored.filters.userId, 'alice');
      expect(restored.filters.lens, ActivityLens.comments);
      expect(restored.filters.search, 'renewal');
      restored.dispose();
    });

    test('a change inside the debounce window survives dispose', () async {
      final saver = ActivityViewModel(
        repo: repo,
        companyId: 'co1',
        navStateDao: db.navStateDao,
        // Long enough that the timer is still pending when we dispose — the
        // real screen's 600 ms is trivially beaten by tapping a filter and
        // immediately navigating away or switching company.
        persistDebounce: const Duration(seconds: 5),
      )..setTitleResolver(title);
      await saver.hydration;
      saver.setUser('alice');
      saver.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final restored = ActivityViewModel(
        repo: repo,
        companyId: 'co1',
        navStateDao: db.navStateDao,
      )..setTitleResolver(title);
      await restored.hydration;
      expect(restored.filters.userId, 'alice');
      restored.dispose();
    });

    test('another company does not inherit them', () async {
      final saver = ActivityViewModel(
        repo: repo,
        companyId: 'co1',
        navStateDao: db.navStateDao,
        persistDebounce: Duration.zero,
      )..setTitleResolver(title);
      await saver.hydration;
      saver.setUser('alice');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      saver.dispose();

      final other = ActivityViewModel(
        repo: repo,
        companyId: 'co2',
        navStateDao: db.navStateDao,
      )..setTitleResolver(title);
      await other.hydration;
      expect(other.filters.isActive, isFalse);
      other.dispose();
    });
  });
}
