import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:admin/data/db/dao/dashboard_cache_dao.dart'
    show kDashboardListFilterHash;
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/data/services/home_widget_bridge.dart';
import 'package:admin/domain/dashboard/totals_math.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/home_widgets/widget_snapshot.dart';
import 'package:admin/domain/home_widgets/widget_snapshot_builder.dart';
import 'package:admin/utils/formatting.dart';

final _log = Logger('HomeWidgetReader');

/// The periods fetched when a Business snapshot widget is installed but has
/// not reported its own (a fresh install before the first configuration).
const Set<WidgetPeriod> kDefaultWidgetPeriods = {WidgetPeriod.thisMonth};

/// How many of the company's newest running / recent tasks are scanned for
/// the user's own.
const int kWidgetTaskScan = 50;

/// How old a cached dashboard row may be before a background fetch for the
/// widgets asks again. The dashboard's own refreshes ignore it.
const Duration kWidgetFetchMaxAge = Duration(minutes: 1);

/// Reads, from Drift, what the widget snapshot builder needs about a company —
/// and fetches the figures a widget shows that the dashboard did not.
///
/// Reads the dashboard's own cache rows under the dashboard's own saved
/// filter (currency, drafts) with only the date range swapped, so a widget
/// never shows a different figure from the dashboard for the same period.
class HomeWidgetReader {
  HomeWidgetReader({
    required this.dashboard,
    required this.tasks,
    required this.clients,
    required this.navFilters,
    required this.formatterFor,
  });

  final DashboardRepository dashboard;
  final TaskRepository tasks;
  final ClientRepository clients;

  /// `nav_state.filters_json` — where the dashboard keeps its saved filter.
  final Future<String?> Function() navFilters;
  final Future<Formatter> Function(String companyId) formatterFor;

  /// Everything about [company] a widget can show: its figures when
  /// [figures], its running and recent tasks when [timers] — each only for a
  /// widget that shows them, since whatever is read here is written to a file
  /// outside the encrypted store.
  Future<WidgetCompanyInput> read(
    AuthSession session,
    AuthCompany company, {
    required InstalledWidgets installed,
    required bool figures,
    required bool timers,
    required String localeTag,
    required Date today,
  }) async {
    final id = company.id;
    final canView = company.can('view_dashboard');
    // The user's own timers and tasks — created by or assigned to them. The
    // company-wide set would put a teammate's timer, with a Stop an admin may
    // press, on "your running timer". The task table has no user column (the
    // assignee lives in the payload), so a bounded batch is read and
    // filtered here.
    bool mine(Task t) =>
        session.userId.isNotEmpty &&
        (t.userId == session.userId || t.assignedUserId == session.userId);
    final running = timers
        ? (await tasks
                  .watchRunningList(companyId: id, limit: kWidgetTaskScan)
                  .first)
              .where(mine)
              .take(kWidgetMaxTimers)
              .toList()
        : const <Task>[];
    final recent = timers
        ? (await tasks
                  .watchRecentlyWorked(companyId: id, limit: kWidgetTaskScan)
                  .first)
              .where(mine)
              .take(kWidgetRecentTasks)
              .toList()
        : const <Task>[];
    final clientIds = {
      for (final t in [...running, ...recent])
        if (t.clientId.isNotEmpty) t.clientId,
    };
    final names = clientIds.isEmpty
        ? const <String, String>{}
        : {
            for (final c in await clients.getByIds(
              companyId: id,
              ids: clientIds,
            ))
              c.id: c.displayName,
          };
    bool canEdit(Task task) => company.id == session.currentCompanyId
        ? session.canEditRecord(
            'task',
            createdBy: task.userId,
            assignedTo: task.assignedUserId,
            recordId: task.id,
          )
        // The edit rule reads the active company's permissions; a stop for
        // another company is applied only once it is active again, and is
        // checked then.
        : company.can('edit_task') ||
              task.userId == session.userId ||
              task.assignedUserId == session.userId;

    if (!figures || !canView) {
      return WidgetCompanyInput(
        id: id,
        name: company.displayName,
        canViewDashboard: canView,
        localeTag: localeTag,
        runningTasks: running,
        recentTasks: recent,
        clientNames: names,
        canEditTask: canEdit,
      );
    }

    final formatter = await formatterFor(id);
    final filter = (await _savedFilter(
      id,
    )).copyWith(firstMonthOfYear: formatter.settings.firstMonthOfYear);
    final key = selectedCurrencyKey(filter.currencyId);
    final drafts = filter.includeDrafts;
    final outstandingHash = dashboardOutstandingHash(includeDrafts: drafts);

    final periods = <WidgetPeriod, WidgetPeriodInput>{};
    for (final period in _periodsFor(installed)) {
      final f = filter.copyWith(range: DashboardPresetRange(_preset(period)));
      final (start, end) = f.resolveDates(today: today);
      final hash = f.filterHash(today: today);
      periods[period] = WidgetPeriodInput(
        start: start,
        end: end,
        current: await dashboard.watchTotals(id, f).first,
        previous: await dashboard
            .watchTotals(id, f, previousPeriod: true)
            .first,
        fetchedAt: await dashboard.fetchedAt(
          id,
          DashboardKind.totalsCurrent,
          hash,
        ),
      );
    }

    return WidgetCompanyInput(
      id: id,
      name: company.displayName,
      canViewDashboard: true,
      showExpenses: company.moduleEnabled(EntityType.expense),
      showInvoices: company.moduleEnabled(EntityType.invoice),
      formatter: formatter,
      currencyKey: key,
      baseCurrencyId: formatter.settings.currencyId,
      localeTag: localeTag,
      firstMonthOfYear: filter.firstMonthOfYear,
      outstanding: await dashboard
          .watchOutstanding(id, includeDrafts: drafts)
          .first,
      outstandingFetchedAt: await dashboard.fetchedAt(
        id,
        DashboardKind.totalsOutstanding,
        outstandingHash,
      ),
      periods: periods,
      pastDue: await dashboard.watchPastDue(id).first,
      upcoming: await dashboard.watchUpcomingInvoices(id).first,
      listsFetchedAt: await dashboard.fetchedAt(
        id,
        DashboardKind.pastDue,
        kDashboardListFilterHash,
      ),
      runningTasks: running,
      recentTasks: recent,
      clientNames: names,
      canEditTask: canEdit,
    );
  }

  /// Fetches what the installed widgets show for the active company, skipping
  /// anything fetched within [kWidgetFetchMaxAge] — usually by the dashboard
  /// itself, which listens to the same signals. Never throws.
  Future<void> fetch(
    AuthSession session, {
    required InstalledWidgets installed,
    required Date today,
  }) async {
    final company = session.currentCompany;
    if (company == null || !company.can('view_dashboard')) return;
    if (!installed.kinds.any((k) => k != WidgetKind.timer)) return;
    final id = company.id;
    try {
      final formatter = await formatterFor(id);
      final filter = (await _savedFilter(
        id,
      )).copyWith(firstMonthOfYear: formatter.settings.firstMonthOfYear);
      await Future.wait([
        dashboard.refreshOutstanding(
          id,
          includeDrafts: filter.includeDrafts,
          maxAge: kWidgetFetchMaxAge,
        ),
        dashboard.refreshPastDue(id, maxAge: kWidgetFetchMaxAge),
        dashboard.refreshUpcomingInvoices(id, maxAge: kWidgetFetchMaxAge),
        if (installed.kinds.contains(WidgetKind.snapshot))
          for (final period in _periodsFor(installed))
            dashboard.refreshTotals(
              id,
              filter.copyWith(range: DashboardPresetRange(_preset(period))),
              maxAge: kWidgetFetchMaxAge,
            ),
      ]);
      // "Last 30 days" is a new cache row every day; drop the ones nobody
      // has refreshed in two months.
      await dashboard.pruneStaleTotals(id);
    } catch (e) {
      // Offline, a company switch under the fetch, a server error: the widget
      // keeps what is cached and says how old it is.
      _log.fine('Home widget fetch skipped: $e');
    }
  }

  Set<WidgetPeriod> _periodsFor(InstalledWidgets installed) =>
      installed.periods.isEmpty ? kDefaultWidgetPeriods : installed.periods;

  static DashboardDatePreset _preset(WidgetPeriod p) => switch (p) {
    WidgetPeriod.thisMonth => DashboardDatePreset.thisMonth,
    WidgetPeriod.last30Days => DashboardDatePreset.last30,
    WidgetPeriod.thisYear => DashboardDatePreset.thisYear,
  };

  /// The dashboard's saved filter for [companyId] — the same envelope
  /// `DashboardViewModel._hydrate` reads — or the defaults.
  Future<DashboardFilter> _savedFilter(String companyId) async {
    try {
      final raw = await navFilters();
      if (raw == null || raw.isEmpty) return DashboardFilter.defaults();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return DashboardFilter.defaults();
      final company = decoded[companyId];
      if (company is! Map) return DashboardFilter.defaults();
      final dash = company['dashboard'];
      if (dash is! Map) return DashboardFilter.defaults();
      return DashboardFilter.tryFromJson(dash['filter']) ??
          DashboardFilter.defaults();
    } catch (_) {
      return DashboardFilter.defaults();
    }
  }
}
