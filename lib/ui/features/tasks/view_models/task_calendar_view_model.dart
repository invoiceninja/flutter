import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/domain/entity_state.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/domain/tasks/task_day.dart';
import 'package:admin/domain/tasks/task_day_load.dart';
import 'package:admin/ui/features/tasks/view_models/task_filters_mixin.dart';
import 'package:admin/utils/date_ranges.dart';

final _log = Logger('TaskCalendarViewModel');

/// Page bound on [TaskCalendarViewModel.ensureMonthLoaded] — the same bound
/// (and the same literal) the other bounded in-VM walks use, e.g.
/// `ClientListViewModel`'s overdue-invoice hydration.
const int kTaskMonthFetchMaxPages = 5;

/// How far *before* the visible month the window fetch reaches back.
///
/// The server's `tasks.calculated_start_date` is harvested from `time_log[0]` —
/// the FIRST entry, not the earliest — and shifted by the COMPANY's utc offset
/// (`TaskRepository::harvestStartDate`). So a task opened in August and still
/// being logged against in September is invisible to a naive September window,
/// and no window width fixes that in general. A quarter covers the realistic
/// "opened a while ago, still working on it" case and dwarfs any timezone skew
/// between that company offset and this app's device-local bucketing (the
/// KNOWN LIMITATION recorded in `task_day.dart`). Past it, the local cache plus
/// a user-triggered Sync is the answer — which is what this screen relied on
/// *entirely* before the fetch existed.
const int kTaskMonthLookbackDays = 90;

/// Drives the monthly calendar view. Subscribes to every active task
/// (`watchAllActive`, includes invoiced) and groups them by day in Dart. The
/// focused month is internal state — `prev/next/goToToday` mutate it and
/// notify, so scrubbing never touches the URL or remounts the VM.
class TaskCalendarViewModel extends ChangeNotifier with TaskFiltersMixin {
  TaskCalendarViewModel({
    required this.repo,
    required this.companyId,
    int firstDayOfWeek = 0,
    Date? focusMonth,
    DateTime Function() now = DateTime.now,
  }) : _firstDayOfWeek = firstDayOfWeek,
       _now = now,
       _month = focusMonth == null
           ? _firstOfMonthAt(now())
           : Date(focusMonth.year, focusMonth.month, 1) {
    _sub = repo.watchAllActive(companyId: companyId).listen(_onTasks);
    unawaited(ensureMonthLoaded());
  }

  final TaskRepository repo;
  final String companyId;
  final DateTime Function() _now;

  int _firstDayOfWeek;
  Date _month; // day-of-month is irrelevant — always the 1st.
  StreamSubscription<List<Task>>? _sub;
  List<Task> _tasks = const [];
  bool _disposed = false;
  bool _hasLoaded = false;

  /// Every month window [ensureMonthLoaded] has **completed** this session.
  ///
  /// A set rather than a single key so scrubbing back to a month already
  /// fetched costs nothing — otherwise stepping forward and back one month
  /// would re-request on every tap. Bounded by how many months the user
  /// actually visits; a failed window is never added, so it retries and
  /// [isVisibleWindowLoaded] stays honest about it.
  final Set<String> _loadedWindows = <String>{};

  /// Windows whose sweep is running right now, keyed the same way.
  ///
  /// Separate from [_loadedWindows] because the two answer different
  /// questions, and collapsing them into one set breaks the concurrency
  /// guard: [invalidateLoadedWindow] clears what has *completed*, and if that
  /// also cleared live claims a refresh landing mid-sweep would start a second
  /// concurrent walk of the identical window — then the first walk's failure
  /// arm would release the key the second one is holding, freeing a third.
  final Map<String, Future<void>> _inFlightWindows = <String, Future<void>>{};

  Date get month => _month;
  int get firstDayOfWeek => _firstDayOfWeek;

  /// Whether the Drift watch has emitted at least once.
  ///
  /// Before it has, `_tasks` is empty and every day reads as free — which a
  /// surface that colours *availability* must not assert. Hosts gate their
  /// rendering on this rather than showing a confident empty month.
  bool get hasLoaded => _hasLoaded;

  /// Whether the **visible** month's window has been fetched successfully.
  ///
  /// [hasLoaded] alone is not enough to make a confident claim about
  /// availability: a Drift watch emits its current contents on subscribe, so it
  /// flips within a frame of construction — before the fetch that fills the
  /// window's far edges has resolved. This is the other half, and it is
  /// deliberately "did it *succeed*" rather than "is it in flight": a failed
  /// sweep never enters [_loadedWindows], so an offline user is never told
  /// they are free on data that never arrived.
  bool get isVisibleWindowLoaded {
    final (from, to) = _windowFor(_month);
    return _loadedWindows.contains('${from.toIso()}_${to.toIso()}');
  }

  /// The 42 days (6 weeks) of the current month's grid, honoring the company's
  /// first-day-of-week.
  List<Date> get gridDays => monthGridDays(_month, _firstDayOfWeek);

  /// Tasks grouped by their day for the active filter set, each day's list
  /// sorted chronologically by earliest start. Recomputed per build — cheap
  /// at task volumes a single company holds, and avoids a cache the filter
  /// mixin's setters would have to invalidate.
  Map<Date, List<Task>> tasksByDayFiltered() {
    final src = filtersActive ? _tasks.where(matchesFilters) : _tasks;
    final map = tasksByDay(src);
    for (final list in map.values) {
      list.sort((a, b) {
        final sa = a.earliestStart;
        final sb = b.earliestStart;
        if (sa == null || sb == null) return 0;
        return sa.compareTo(sb);
      });
    }
    return map;
  }

  /// Booked duration per day for the active filter set — what the dashboard's
  /// task-calendar panel colours each cell by.
  ///
  /// Recomputed per call, like [tasksByDayFiltered] and for the same reason:
  /// cheap at the task volumes one company holds, and it avoids a cache the
  /// filter mixin's setters would have to invalidate.
  Map<Date, Duration> loadByDayFiltered() {
    final src = filtersActive ? _tasks.where(matchesFilters) : _tasks;
    // Bounded to the grid: the caller renders 42 days, and an unbounded walk
    // would allocate a `Date` per time entry across the whole account on every
    // emission of a stream the dashboard keeps alive.
    final days = gridDays;
    return taskLoadByDay(src, now: _now(), from: days.first, to: days.last);
  }

  /// Best-effort top-up of the tasks whose first time-log entry falls in (or
  /// shortly before) the visible month.
  ///
  /// **Never throws, never blocks a paint, never surfaces an error.** A failure
  /// leaves the grid rendering exactly what Drift already holds, which is how
  /// this screen behaved before the fetch existed — strictly better than
  /// failing the calendar the user asked for. Nothing needs notifying either:
  /// the upsert re-emits through the `watchAllActive` subscription the
  /// constructor already holds.
  ///
  /// The window is **month-aligned, not grid-aligned**, and that is
  /// load-bearing rather than tidy. `calendarFirstDayOfWeek` resolves the
  /// company setting *or the device locale*, and hosts correct the seeded
  /// `firstDayOfWeek` on their first frame — so a grid-aligned window would
  /// shift under [setFirstDayOfWeek] and fire a second request on every entry
  /// to the calendar for anyone outside a Sunday-first locale. A month window
  /// cannot move, and the `+41` below covers the grid whatever the week start.
  ///
  /// Concurrent calls for the same window share one sweep rather than racing:
  /// see [_inFlightWindows].
  Future<void> ensureMonthLoaded() {
    final (from, to) = _windowFor(_month);
    final windowKey = '${from.toIso()}_${to.toIso()}';

    if (_loadedWindows.contains(windowKey)) return Future<void>.value();
    final existing = _inFlightWindows[windowKey];
    if (existing != null) return existing;

    final run = _runWindow(windowKey, from, to);
    // Registered before this method returns, so no other caller can interleave
    // between the lookup above and the claim here — that is what makes two
    // month taps (or a refresh landing mid-sweep) join one walk rather than
    // starting a second.
    _inFlightWindows[windowKey] = run;
    return run;
  }

  /// The `(from, to)` the fetch covers for [month] — one derivation, so
  /// [isVisibleWindowLoaded] and [ensureMonthLoaded] cannot disagree about
  /// which window a month maps to.
  (Date, Date) _windowFor(Date month) {
    final firstOfMonth = Date(month.year, month.month, 1);
    // 41, not "a few days past the month end". `monthGridDays` is always 42
    // cells starting at `startOfWeek(firstOfMonth, …)`, which is never LATER
    // than the 1st — so the grid can never run past `firstOfMonth + 41`,
    // whatever the week start, and the slack is exactly the leading-blank
    // count. A margin measured from the month *end* instead has to be 14 to be
    // safe (a 28-day February whose 1st is the week start), and the 6 this
    // used to carry left part of the rendered grid unfetched in 383 of the 588
    // month × week-start combinations — those cells then paint "free" off
    // whatever the local cache happened to hold, which is the one claim this
    // panel must never make by accident.
    return (
      firstOfMonth.addDays(-kTaskMonthLookbackDays),
      firstOfMonth.addDays(41),
    );
  }

  Future<void> _runWindow(String windowKey, Date from, Date to) async {
    // The catch is deliberately bare rather than `on Exception`: nothing awaits
    // this future, so anything that escapes becomes an unhandled async error,
    // and a repository double that throws an `Error` (test fakes raise
    // `UnimplementedError`) would sail past an Exception-only clause.
    try {
      for (var page = 1; page <= kTaskMonthFetchMaxPages; page++) {
        final more = await repo.ensurePageLoaded(
          companyId: companyId,
          page: page,
          // Matches `watchAllActive`'s default: the grid renders active tasks.
          states: const {EntityState.active},
          // A 3-part `date_range` naming the column explicitly. ONE element:
          // `ensurePageLoadedTemplate` serialises a filter's values with
          // `join(',')`, so a second element would silently corrupt this into a
          // 4-part value. Note the server degrades a column it does not
          // recognise into *no filter at all* (it falls back to `date`, which
          // `tasks` also lacks, and returns the builder untouched) — harmless,
          // since that is what `refreshAll` fetches anyway, but it means an old
          // self-hosted install without `calculated_start_date` simply pages
          // the newest tasks instead, with nothing observable client-side.
          extraFilters: {
            'date_range': {
              'calculated_start_date,${from.toIso()},${to.toIso()}',
            },
          },
          // A non-empty `extraFilters` already makes this a narrowed fetch, so
          // the shared task delta cursor is neither read nor advanced. Explicit
          // anyway: the intent must not rest on `isNarrowedFetch` keeping that
          // shape.
          ignoreCursor: true,
        );
        // Disposed mid-sweep — the screen is gone. Without this the loop keeps
        // paying for pages nobody will render, and on a company switch the next
        // one goes out under the NEW company's token for the OLD company's
        // window, only to be thrown away when the response arrives.
        if (_disposed || !more) break;
      }
      _loadedWindows.add(windowKey);
      // The sweep just changed [isVisibleWindowLoaded], and nothing else will
      // say so. It is tempting to lean on "the upsert re-emits through the
      // `watchAllActive` subscription" — but `upsertAllPreservingDirty`
      // early-returns on an empty batch, so a `{"data": []}` response writes
      // nothing, drift raises no table update, and the stream stays silent.
      // That is exactly the shape of a brand-new account or a genuinely empty
      // month: without this, a host gating on the getter never rebuilds, and
      // the "nothing booked" caption is unreachable in the one state it exists
      // for. On the failure arms nothing observable changed, so they stay
      // silent — a best-effort top-up that fails must remain invisible.
      if (!_disposed) notifyListeners();
    } on CompanySwitchedException catch (e) {
      // The company changed under the fetch — expected, same log policy.
      _log.fine('task month window abandoned: $e');
    } on NetworkException catch (e) {
      // Best-effort, same policy as the sidebar prefetch: an offline blip is
      // expected here and must not pollute the WARNING+ diagnostics log.
      _log.fine('task month window skipped: ${e.message}');
    } catch (e, st) {
      _log.warning('task month window failed', e, st);
    } finally {
      // `remove` hands back the future it evicted — this one, already
      // completing — so discard it rather than leaving a bare expression the
      // analyzer reads as a dropped async call.
      unawaited(_inFlightWindows.remove(windowKey) ?? Future<void>.value());
    }
  }

  /// Re-arm every window — the host calls this when the dashboard's
  /// pull-to-refresh completes, since that pass refreshes the server-cached
  /// panels and would otherwise leave this one untouched. Clears the whole set,
  /// not just the visible month: the user asked for fresh data, and the next
  /// month they scrub to should honour that too.
  ///
  /// Deliberately leaves [_inFlightWindows] alone — a sweep already on the wire
  /// is fresh data by definition, and dropping its claim would let a second
  /// walk of the same window start beside it.
  void invalidateLoadedWindow() => _loadedWindows.clear();

  void setFirstDayOfWeek(int value) {
    if (_firstDayOfWeek == value) return;
    _firstDayOfWeek = value;
    if (!_disposed) notifyListeners();
  }

  void prevMonth() => _setMonth(_addMonths(_month, -1));
  void nextMonth() => _setMonth(_addMonths(_month, 1));
  void goToToday() => _setMonth(_firstOfMonthAt(_now()));

  void _setMonth(Date next) {
    if (next == _month) return;
    _month = next;
    if (!_disposed) notifyListeners();
    unawaited(ensureMonthLoaded());
  }

  void _onTasks(List<Task> tasks) {
    _tasks = tasks;
    _hasLoaded = true;
    if (!_disposed) notifyListeners();
  }

  /// Derived from the injected clock, not `Date.today()` — otherwise a caller
  /// that fakes `now` gets its durations from the fake and its month from the
  /// real one, and the initial month is untestable.
  static Date _firstOfMonthAt(DateTime now) {
    final local = now.toLocal();
    return Date(local.year, local.month, 1);
  }

  /// Step months through `DateTime` so month 0 / 13 normalize correctly — the
  /// `Date` constructor does not (`Date(2026, 0, 1)` would be invalid).
  static Date _addMonths(Date m, int delta) {
    final d = DateTime(m.year, m.month + delta, 1);
    return Date(d.year, d.month, 1);
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}
