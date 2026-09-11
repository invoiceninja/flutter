import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/time_entry.dart';

import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/ui/features/tasks/view_models/task_calendar_view_model.dart';

/// `TaskCalendarViewModel.ensureMonthLoaded` — the top-up that stops the
/// calendar (and the dashboard panel that shares this VM) from rendering
/// availability off nothing but whatever page 1 of the login prefetch left in
/// Drift.
///
/// The assertions that matter are the ones nothing else can see: the window's
/// exact shape, the latch, and that `setFirstDayOfWeek` fires NO refetch —
/// which is what month-aligning the window buys, and without which every entry
/// to the Tasks calendar on a non-Sunday-first locale would cost two requests.

class _Call {
  _Call(this.page, this.states, this.extraFilters, this.ignoreCursor);
  final int page;
  final Set<EntityState> states;
  final Map<String, Set<String>> extraFilters;
  final bool ignoreCursor;
}

class _RecordingRepo implements TaskRepository {
  _RecordingRepo({this.pagesWithMore = 0, this.failure, this.gate});

  /// When set, every page awaits it — letting a test dispose the view model
  /// while a sweep is parked mid-flight.
  final Future<void>? gate;

  /// How many pages answer "there is more" before one answers "no".
  final int pagesWithMore;

  /// Thrown from the first `ensurePageLoaded` when set.
  final Object? failure;

  final List<_Call> calls = [];

  /// Emissions the view model's watch will receive. `const Stream.empty()`
  /// never emits, which is why `hasLoaded` needs a controller to be observable
  /// at all.
  final StreamController<List<Task>> tasks =
      StreamController<List<Task>>.broadcast();

  @override
  Stream<List<Task>> watchAllActive({
    required String companyId,
    states = const {},
  }) => tasks.stream;

  @override
  Future<bool> ensurePageLoaded({
    required String companyId,
    required int page,
    String? search,
    states = const {EntityState.active},
    Map<String, Set<String>> extraFilters = const {},
    bool ignoreCursor = false,
  }) async {
    calls.add(_Call(page, states, extraFilters, ignoreCursor));
    if (gate != null) await gate;
    if (failure != null) throw failure!;
    return page <= pagesWithMore;
  }

  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

TaskCalendarViewModel _build(_RecordingRepo repo, {int firstDayOfWeek = 0}) =>
    TaskCalendarViewModel(
      repo: repo,
      companyId: 'co',
      firstDayOfWeek: firstDayOfWeek,
      focusMonth: Date(2026, 6, 10),
    );

/// Lets the constructor's unawaited future run to completion.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

String _rangeOf(_Call c) => c.extraFilters['date_range']!.single;

Task _task(List<TimeEntry> log) => Task(
  id: 't${log.length}',
  number: '1',
  description: 'x',
  rate: Decimal.zero,
  invoiceId: '',
  clientId: '',
  projectId: '',
  statusId: 's',
  statusOrder: 0,
  assignedUserId: '',
  timeLog: log,
  customValue1: '',
  customValue2: '',
  customValue3: '',
  customValue4: '',
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  archivedAt: null,
  isDeleted: false,
);

void main() {
  test('construction fetches page 1 of the month window, once', () async {
    final repo = _RecordingRepo();
    final vm = _build(repo);
    await _settle();

    expect(repo.calls, hasLength(1));
    final call = repo.calls.single;
    expect(call.page, 1);
    expect(call.states, {EntityState.active});
    expect(call.ignoreCursor, isTrue);
    // ONE element: the repository serialises a filter's values with
    // `join(',')`, so a second would corrupt this into a 4-part value.
    expect(call.extraFilters['date_range'], hasLength(1));
    vm.dispose();
  });

  test('the window always covers the whole rendered grid', () {
    // The invariant, not a transcription of the arithmetic. `monthGridDays` is
    // 42 cells from a start that is never later than the 1st, so a margin
    // measured from the month END has to be 14 to be safe — the 6 this once
    // carried left part of the grid unfetched in most month × week-start
    // combinations, and those cells then paint "free" off whatever the local
    // cache happened to hold.
    //
    // February is the worst case every year and is why the sweep includes one:
    // a 28-day month whose 1st falls on the week start spills a full 14 days.
    for (final month in [
      Date(2026, 2, 1), // 28 days
      Date(2028, 2, 1), // leap
      Date(2026, 6, 1),
      Date(2026, 12, 1), // year rollover
    ]) {
      for (var fdow = 0; fdow < 7; fdow++) {
        final repo = _RecordingRepo();
        final vm = TaskCalendarViewModel(
          repo: repo,
          companyId: 'co',
          firstDayOfWeek: fdow,
          focusMonth: month,
        );
        final end = Date.tryParse(_rangeOf(repo.calls.single).split(',').last)!;
        expect(
          end.compareTo(vm.gridDays.last),
          greaterThanOrEqualTo(0),
          reason:
              '${month.toIso()} fdow=$fdow: window ends ${end.toIso()} but the '
              'grid runs to ${vm.gridDays.last.toIso()}',
        );
        vm.dispose();
      }
    }
  });

  test('the window is month-aligned: 90 days back, 41 forward', () async {
    // One literal as a readability anchor for the sweep above. June 2026 →
    // 1 Jun − 90d = 3 Mar; 1 Jun + 41d = 12 Jul.
    final repo = _RecordingRepo();
    final vm = _build(repo);
    await _settle();
    expect(
      _rangeOf(repo.calls.single),
      'calculated_start_date,2026-03-03,2026-07-12',
    );
    vm.dispose();
  });

  test('changing month refetches with the new window', () async {
    final repo = _RecordingRepo();
    final vm = _build(repo);
    await _settle();
    vm.nextMonth();
    await _settle();

    expect(repo.calls, hasLength(2));
    expect(
      _rangeOf(repo.calls[1]),
      'calculated_start_date,2026-04-02,2026-08-11',
    );
    vm.dispose();
  });

  test('returning to a month already fetched costs nothing', () async {
    final repo = _RecordingRepo();
    final vm = _build(repo);
    await _settle();
    vm.nextMonth();
    await _settle();
    vm.prevMonth();
    await _settle();

    expect(
      repo.calls,
      hasLength(2),
      reason: 'the latch must survive a round trip back to June',
    );
    vm.dispose();
  });

  test('invalidateLoadedWindow re-arms every window', () async {
    // Pull-to-refresh on the dashboard: that pass refreshes the server-cached
    // panels, so without this hook the one gesture a user makes on a stale
    // dashboard would refresh everything except the calendar.
    final repo = _RecordingRepo();
    final vm = _build(repo);
    await _settle();
    vm.invalidateLoadedWindow();
    await vm.ensureMonthLoaded();

    expect(repo.calls, hasLength(2));
    expect(_rangeOf(repo.calls[1]), _rangeOf(repo.calls[0]));
    vm.dispose();
  });

  test('overlapping calls share one sweep', () async {
    // The claim is registered before `ensureMonthLoaded` returns — no other
    // caller can run between the lookup and the claim — so this is the guard
    // against two month taps (or a refresh landing mid-sweep) each starting
    // their own 5-page walk. Deliberately does NOT settle between the calls:
    // settling first would populate the latch from a *completed* sweep, and
    // then dropping the claim entirely would still pass.
    final repo = _RecordingRepo();
    final vm = _build(repo);
    final a = vm.ensureMonthLoaded();
    final b = vm.ensureMonthLoaded();
    await Future.wait([a, b]);

    expect(
      repo.calls.where((c) => c.page == 1),
      hasLength(1),
      reason: 'the second caller must join the first sweep, not start one',
    );
    vm.dispose();
  });

  test('isVisibleWindowLoaded only after the sweep SUCCEEDS', () async {
    final repo = _RecordingRepo();
    final vm = _build(repo);
    expect(vm.isVisibleWindowLoaded, isFalse, reason: 'still on the wire');
    await _settle();
    expect(vm.isVisibleWindowLoaded, isTrue);

    // A month with no sweep yet is not loaded either — the getter is about the
    // VISIBLE window, not "some window somewhere".
    vm.nextMonth();
    expect(vm.isVisibleWindowLoaded, isFalse);
    vm.dispose();
  });

  test('a FAILED sweep leaves the window unloaded', () async {
    // The distinction the caption rests on: "stopped" is not "succeeded".
    // Offline, a user must not be told they are free on data that never came.
    final repo = _RecordingRepo(failure: const NetworkException('offline'));
    final vm = _build(repo);
    await _settle();
    expect(vm.isVisibleWindowLoaded, isFalse);
    vm.dispose();
  });

  test('a sweep that writes NOTHING still notifies', () async {
    // `upsertAllPreservingDirty` early-returns on an empty batch, so an empty
    // response raises no drift update and the task watch stays silent. If the
    // sweep did not notify, a host gating on `isVisibleWindowLoaded` would
    // never rebuild — and the one state that matters (a new account, an empty
    // month) would never render.
    final repo = _RecordingRepo();
    final vm = _build(repo);
    var notified = 0;
    vm.addListener(() => notified++);
    await _settle();

    expect(notified, greaterThan(0));
    expect(vm.isVisibleWindowLoaded, isTrue);
    vm.dispose();
  });

  test('dispose stops the sweep instead of paying for the rest', () async {
    // `dispose` cancels the Drift subscription, but the page loop is a plain
    // `for` — without an explicit check it keeps buying pages for a screen that
    // is gone, and on a company switch the next one goes out under the NEW
    // company's token for the OLD company's window.
    final gate = Completer<void>();
    final repo = _RecordingRepo(pagesWithMore: 99, gate: gate.future);
    final vm = _build(repo);
    await _settle();
    expect(repo.calls, hasLength(1), reason: 'parked on page 1');

    vm.dispose();
    gate.complete();
    await _settle();
    await _settle();

    expect(repo.calls, hasLength(1), reason: 'no page 2 after dispose');
  });

  group('hasLoaded / loadByDayFiltered', () {
    test('hasLoaded is false until the watch emits', () async {
      final repo = _RecordingRepo();
      final vm = _build(repo);
      await _settle();
      expect(vm.hasLoaded, isFalse);

      repo.tasks.add(const <Task>[]);
      await _settle();
      expect(vm.hasLoaded, isTrue);
      vm.dispose();
      await repo.tasks.close();
    });

    test('the load map is bounded to the visible grid', () async {
      final repo = _RecordingRepo();
      final vm = _build(repo);
      repo.tasks.add([
        // In June's grid.
        _task([
          TimeEntry(
            start: DateTime(2026, 6, 10, 9),
            stop: DateTime(2026, 6, 10, 11),
          ),
        ]),
        // Well outside it — must not be walked into the map.
        _task([
          TimeEntry(
            start: DateTime(2025, 1, 5, 9),
            stop: DateTime(2025, 1, 5, 11),
          ),
          TimeEntry(
            start: DateTime(2027, 1, 5, 9),
            stop: DateTime(2027, 1, 5, 11),
          ),
        ]),
      ]);
      await _settle();

      final load = vm.loadByDayFiltered();
      expect(load[Date(2026, 6, 10)], const Duration(hours: 2));
      expect(load.containsKey(Date(2025, 1, 5)), isFalse);
      expect(load.containsKey(Date(2027, 1, 5)), isFalse);
      vm.dispose();
      await repo.tasks.close();
    });
  });

  test('setFirstDayOfWeek fires NO refetch', () async {
    // The assertion that pins month alignment. Hosts seed `firstDayOfWeek`
    // from the company and correct it from the locale on their first frame,
    // so a grid-aligned window would double every calendar open.
    final repo = _RecordingRepo();
    final vm = _build(repo);
    await _settle();
    vm.setFirstDayOfWeek(1);
    await _settle();

    expect(repo.calls, hasLength(1));
    vm.dispose();
  });

  test('paging stops at the bound', () async {
    final repo = _RecordingRepo(pagesWithMore: 99);
    final vm = _build(repo);
    await _settle();

    expect(repo.calls, hasLength(kTaskMonthFetchMaxPages));
    expect(repo.calls.map((c) => c.page), [1, 2, 3, 4, 5]);
    vm.dispose();
  });

  test('paging stops early on a short page', () async {
    final repo = _RecordingRepo(pagesWithMore: 2);
    final vm = _build(repo);
    await _settle();

    expect(repo.calls.map((c) => c.page), [1, 2, 3]);
    vm.dispose();
  });

  group('failure is silent and re-armable', () {
    Future<void> expectSurvives(Object failure) async {
      final repo = _RecordingRepo(failure: failure);
      final vm = _build(repo);
      var notified = false;
      vm.addListener(() => notified = true);
      await _settle();

      expect(repo.calls, hasLength(1));
      expect(notified, isFalse, reason: 'a failed top-up must not notify');
      expect(vm.gridDays, hasLength(42), reason: 'the VM stays usable');

      // Retried on the SAME month. `nextMonth()` would build a different key
      // and refetch whether or not the failed window was released, so it
      // proves nothing — an implementation that marked a failed window as
      // loaded would pass it.
      await vm.ensureMonthLoaded();
      expect(repo.calls, hasLength(2));
      expect(_rangeOf(repo.calls[1]), _rangeOf(repo.calls[0]));
      vm.dispose();
    }

    test(
      'a network blip',
      () => expectSurvives(const NetworkException('offline')),
    );

    test(
      'a company switch',
      () => expectSurvives(
        const CompanySwitchedException(
          expected: 'co',
          active: 'other',
          entityType: 'task',
        ),
      ),
    );

    test(
      'an Error, not just an Exception',
      // A bare `catch` is what makes this pass: the repository doubles in the
      // sibling suites raise `UnimplementedError`, which `on Exception` misses,
      // and nothing awaits the constructor's future — so an escape would land
      // as an unhandled async error and fail an unrelated test file.
      () => expectSurvives(UnimplementedError('boom')),
    );
  });
}
