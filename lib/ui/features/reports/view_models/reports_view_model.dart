import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/db/dao/nav_state_dao.dart';
import 'package:admin/data/models/domain/report_definition.dart';
import 'package:admin/data/models/domain/report_payload.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/value/dashboard_comparison.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/value/money.dart';
import 'package:admin/data/repositories/reports_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/reports_api.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/report_document.dart';
import 'package:admin/domain/reports/report_engine.dart';
import 'package:admin/domain/reports/report_registry.dart';
import 'package:admin/domain/reports/report_row_currency.dart';
import 'package:admin/domain/reports/report_row_records.dart';
import 'package:admin/ui/features/reports/helpers/report_range.dart';

final _log = Logger('ReportsViewModel');

enum ReportRunStatus { idle, loading, ready, error }

/// How a measure over time is drawn.
enum ReportTimeChartStyle { columns, line }

class ReportRunState {
  const ReportRunState({required this.status, this.preview, this.error});

  factory ReportRunState.idle() =>
      const ReportRunState(status: ReportRunStatus.idle);

  /// Loading. Carries the [previousPreview] forward so [cancelRun] can
  /// restore it without an additional VM field — the table stays visible
  /// while the user reruns, and a cancel reverts to what was on screen.
  factory ReportRunState.loading({ReportPreview? previousPreview}) =>
      ReportRunState(status: ReportRunStatus.loading, preview: previousPreview);
  factory ReportRunState.ready(ReportPreview preview) =>
      ReportRunState(status: ReportRunStatus.ready, preview: preview);
  factory ReportRunState.error(ReportError error, {ReportPreview? lastGood}) =>
      ReportRunState(
        status: ReportRunStatus.error,
        preview: lastGood,
        error: error,
      );

  final ReportRunStatus status;

  /// The last successful preview. Stays populated through Cancel and error
  /// states so the table doesn't blank out during a failed Run.
  final ReportPreview? preview;

  final ReportError? error;

  bool get isLoading => status == ReportRunStatus.loading;
  bool get hasPreview => preview != null && preview!.rows.isNotEmpty;
}

/// State holder for the Reports screen. Pure `ChangeNotifier` — owns the
/// payload (server-side filter inputs that drive a refetch), the result, and
/// all local manipulation state (sort / column filters / group / column
/// visibility — none of which refetch).
///
/// `FormatterHostMixin` is a `State<T>` mixin (lib/ui/core/widgets/
/// formatter_host_mixin.dart) and cannot apply here — the screen's State
/// mixes it in and passes the formatter to [buildView] / export helpers.
class ReportsViewModel extends ChangeNotifier {
  ReportsViewModel({
    required this.repo,
    required this.statics,
    String initialReport = kDefaultReportIdentifier,
    this.navStateDao,
    this.companyId,
    this.companyCurrencyId,
    this.fetchRowIds = false,
    this.autoRun = false,
    this.canRun,
    Stream<bool>? online,
    DateTime Function()? now,
    Duration persistDebounce = const Duration(milliseconds: 600),
    this.autoRunDebounce = const Duration(milliseconds: 400),
    this.freshFor = const Duration(minutes: 5),
  }) : _reportIdentifier = initialReport,
       _payload = _openingPayload(initialReport),
       _now = now ?? DateTime.now,
       _persistDebounce = persistDebounce,
       // Nothing to wait for when no loader was given — and the run must not
       // take an extra turn of the event loop to find that out.
       _companyCurrencyResolved = companyCurrencyId == null {
    // Restore the last report + filters + view state for this company
    // (CLAUDE.md: app restart restores where the user left off). No-op when
    // persistence isn't wired (tests). Run is gated on [_hydrated] so a
    // cold Run can't clobber a persisted column set before it loads.
    if (navStateDao != null && companyId != null) {
      _hydration = _hydrate();
    } else {
      _hydrated = true;
      _hydration = Future.value();
    }
    _applyOpeningView();
    // Persist on every state change (debounced, hydration-gated). The
    // debounce coalesces the flurry; snapshot covers only durable fields.
    addListener(_schedulePersist);
    _onlineSubscription = online?.listen(_onOnlineChanged);
  }

  /// Whether the report runs itself: when it is opened or restored, and
  /// whenever a change is made that alters the rows that come back. The
  /// screen turns it on; off, nothing is asked of the server until
  /// [runReport] is called.
  ///
  /// The guard rails are what make it affordable — the report routes are
  /// throttled to twenty requests a minute and a job the app has stopped
  /// waiting for still runs to completion on the server:
  /// * a result fetched less than [freshFor] ago is shown and **not** re-run;
  /// * changes are debounced ([autoRunDebounce]) and a newer run strands an
  ///   older one;
  /// * nothing runs while offline or while [canRun] says no (the Pro gate),
  ///   and the run it owes is made when that changes.
  final bool autoRun;

  /// Whether the server may be asked at all — false behind the hosted plan
  /// gate. Read at the moment a run would start. Null allows.
  final bool Function()? canRun;
  final Duration autoRunDebounce;

  /// How long a result counts as current — see [autoRun].
  final Duration freshFor;

  StreamSubscription<bool>? _onlineSubscription;
  bool _isOnline = true;

  /// Whether the device is believed online. True until told otherwise.
  bool get isOnline => _isOnline;

  Timer? _autoRunTimer;

  /// A run [autoRun] wanted and could not make (offline, or gated). Made as
  /// soon as it can be.
  bool _autoRunOwed = false;

  /// When the result on screen was fetched from the server — now for a live
  /// run, earlier for one read back from disk. Null with no result.
  DateTime? _resultFetchedAt;
  DateTime? get resultFetchedAt => _resultFetchedAt;

  /// The range a report opens on the first time.
  static ReportPayload _openingPayload(String reportIdentifier) =>
      ReportPayload(
        datePreset: reportDefinitionFor(reportIdentifier).defaultRange,
      );

  /// Group the current report the way it opens the first time
  /// ([ReportDefinition.openingView]). Only ever applied to a report with no
  /// remembered state of its own.
  void _applyOpeningView() {
    final view = definition.openingView;
    if (view == null) return;
    _group = view.group;
    _subgroup = view.subgroup;
    _chartColumn = view.measure;
  }

  final ReportsRepository repo;
  final StaticsRepository statics;

  /// Local-only restore-on-restart store (no server round-trip). Keyed by
  /// `companyId → 'reports' → snapshot` inside the shared `filters_json`
  /// blob — the exact mechanism list ViewModels use.
  final NavStateDao? navStateDao;
  final String? companyId;

  /// Resolves the company's own currency (a statics id), awaited once before
  /// the first run. Two things hang off it, and a report is wrong without
  /// either: the server formats every number with *that* currency's
  /// separators and precision whatever currency the row is in
  /// (`BaseExport::formatFloatsForCsv`), so it is what the numbers are parsed
  /// with; and it is the currency of a row on a report that names none.
  ///
  /// A loader rather than a value because the screen learns it from an
  /// async-built `Formatter`. Null (tests, or before the company is known)
  /// falls back to the format-agnostic parse and leaves such rows without a
  /// currency.
  final Future<String?> Function()? companyCurrencyId;
  String? _companyCurrencyId;
  bool _companyCurrencyResolved;

  /// Whether a run also asks the server for each row's own record id
  /// ([ReportDefinition.rowIdKey]) — what makes a row a link to its record
  /// and lets a line-item report count a document once. The screen turns it
  /// on.
  ///
  /// It costs a request shape, which is why it is a switch. A non-empty
  /// `report_keys` *pins* the column set, so the id can only be added to a
  /// set the server has already described: the first run of a report is a
  /// plain one, and a second, silent run follows it with the id appended
  /// (see [_fetchRowIds]). After that the set is remembered and every run
  /// carries the id — until [_kServerColumnsMaxAge] passes and a plain run
  /// re-learns it, so a column the server adds later is not locked out for
  /// good.
  final bool fetchRowIds;

  final DateTime Function() _now;
  final Duration _persistDebounce;

  static const String _persistKey = 'reports';

  bool _hydrated = false;
  late final Future<void> _hydration;
  Timer? _persistTimer;

  /// Set once the user changes any state. [_hydrate] resolves asynchronously
  /// after construction; if the user already interacted (e.g. picked a report
  /// or changed a filter in the first frames), restoring the persisted
  /// snapshot would silently revert their action. The flag lets hydration
  /// yield to a live user action. Only controls reachable *before* the first
  /// Run need to set it — the rest (columns / group / sort / chart) are gated
  /// on `hasPreview`, so they can't fire until a Run has completed, which
  /// itself awaits [_hydration].
  bool _userTouched = false;

  /// Localized header for the synthetic `stock_value` column on the Product
  /// report. Set by the screen from `context.tr('stock_value')` (the VM has no
  /// BuildContext); defaults to English. See [_augmentPreview].
  String stockValueLabel = 'Stock value';

  /// Localized header for [ReportDefinition.optionalDateColumnId]. The
  /// server answers that key with `ctrans('texts.')` — the literal string
  /// `"texts."` — because the column isn't in any of its report-key maps,
  /// so the app supplies its own. Set by the screen from
  /// `context.tr('created_at')`, same route as [stockValueLabel].
  String optionalDateColumnLabel = 'Date Created';

  // ─── Payload (server-side) ───
  String _reportIdentifier;
  String get reportIdentifier => _reportIdentifier;
  ReportDefinition get definition => reportDefinitionFor(_reportIdentifier);

  ReportPayload _payload;
  ReportPayload get payload => _payload;

  /// Snapshot of [payload] at the moment of the last successful run.
  /// `isParamDirty` compares against this — column toggles, sort, group,
  /// and column filters are NOT in here so changing them doesn't bump
  /// dirty (they're local-render concerns).
  ReportPayload? _lastRunPayload;

  /// [_includeDateColumn] as of the last successful run. It changes the
  /// *fetch* without touching the payload, so it has to join the dirty
  /// check by hand or the Run button keeps reading "Run report" when it
  /// should read "Run to refresh" — silent, and it looks right on screen.
  /// It deliberately does not live on [ReportPayload]: that class is a wire
  /// DTO whose `toJson` is a direct dump.
  bool _lastRunIncludeDateColumn = false;

  bool get isParamDirty =>
      _payload.forPreview != _lastRunPayload?.forPreview ||
      _includeDateColumn != _lastRunIncludeDateColumn;

  // ─── Result ───
  ReportRunState _run = ReportRunState.idle();
  ReportRunState get run => _run;

  /// The report as a document, for one the server only writes as a file
  /// ([ReportDefinition.readsAsDocument]). Null until its file has been
  /// fetched and read.
  ReportDocument? _document;
  ReportDocument? get document => _document;

  /// The request the server last answered by email rather than with a file
  /// (`ReportErrorKind.emailedInstead`); see [_showOrRun].
  ReportPayload? _emailedFor;

  /// The file came back and could not be read as a document — a format the
  /// reader does not handle, or a layout it does not recognise. The screen
  /// then offers the download, which always works.
  bool _documentUnreadable = false;
  bool get documentUnreadable => _documentUnreadable;

  // ─── Saved views ───

  String? _viewId;

  /// The saved view this report was last opened from or saved as; null when
  /// it is nobody's. Remembered with the report, so the header can go on
  /// saying which view this is — and that it has since been changed.
  String? get viewId => _viewId;

  /// Keys of a report's remembered state that are not part of a *view* of
  /// it: which view it is, and chrome that is the device's business.
  static const _kNotViewState = {'viewId', 'panelCollapsed', 'columnWidths'};

  /// The report as it stands, as a saved view holds it.
  Map<String, dynamic> reportViewState() =>
      _reportSnapshot()..removeWhere((key, _) => _kNotViewState.contains(key));

  /// Put a saved view's [state] on screen and mark the report as showing
  /// [viewId]. Runs the report when the view asks for different rows.
  void applyReportView(String viewId, Map<String, dynamic> state) {
    _userTouched = true;
    _runEpoch++;
    final widths = _columnWidths;
    _resetReportState();
    _applyReportSnapshot(state);
    // Widths are how this device shows the columns, not part of the view.
    _columnWidths = widths;
    _viewId = viewId;
    _syncRanking();
    _invalidateMemo();
    // (Every notification schedules a write of the remembered state.)
    notifyListeners();
    if (autoRun) unawaited(_showOrRun());
  }

  /// Say which saved view the report now is — after saving it as one — or,
  /// with null, that it is no longer any.
  void setViewId(String? viewId) {
    if (viewId == _viewId) return;
    _userTouched = true;
    _viewId = viewId;
    notifyListeners();
  }

  // ─── Compare to the previous period ───

  bool _compare = false;

  /// Whether the report is being read against the period before it.
  bool get compare => _compare;

  ReportPreview? _comparePreview;
  DashboardComparison? _compareWindow;
  int _compareEpoch = 0;
  int? _compareMemoKey;
  ReportView? _compareMemoView;

  /// The month the company's financial year starts in (1–12). Set by the
  /// host from the company's settings; it decides what "the year before
  /// this year" is. A change re-reads the comparison.
  int get firstMonthOfYear => _firstMonthOfYear;
  int _firstMonthOfYear = 1;
  set firstMonthOfYear(int value) {
    if (value == _firstMonthOfYear) return;
    _firstMonthOfYear = value;
    // The host sets this from `build`; a run notifies, so it waits.
    if (_compare && _run.preview != null) {
      scheduleMicrotask(() {
        if (!_disposed) unawaited(_runCompare());
      });
    }
  }

  /// The windows a comparison of [payload] sets against each other, or null
  /// when there is no period before it to compare with — "All time", or a
  /// custom range that is not yet two dates.
  ///
  /// The dashboard's rule, not a second one: a period still in progress is
  /// compared with the same elapsed span of the one before, so the 8th of
  /// October sets this year to date against last year to the 8th of
  /// October, not against the whole of last year.
  DashboardComparison? comparisonFor(ReportPayload payload) {
    if (payload.datePreset == ReportDatePreset.allTime) return null;
    if (payload.datePreset == ReportDatePreset.custom &&
        (payload.startDate == null || payload.endDate == null)) {
      return null;
    }
    final now = _now();
    return DashboardFilter(
      range: reportRangeAsPickerValue(payload),
      firstMonthOfYear: _firstMonthOfYear,
    ).comparison(today: Date(now.year, now.month, now.day));
  }

  /// The bucket of the previous window that stands where [periodKey] stands
  /// in the current one — the third month of last year for the third month
  /// of this — or null when the earlier window has no such bucket. At the
  /// granularity the report is grouped by.
  String? previousPeriodOf(String periodKey) {
    final window = compareWindow;
    if (window == null) return null;
    final ordinal =
        periodSpan(window.currentStart.toIso(), periodKey).length - 1;
    if (ordinal < 0) return null;
    final earlier = periodSpan(
      window.previousStart.toIso(),
      window.previousEnd.toIso(),
    );
    return ordinal < earlier.length ? earlier[ordinal] : null;
  }

  /// Whether this report, as it stands, has a previous period to be read
  /// against: it honours a date range and the range is not open-ended.
  bool get canCompare =>
      definition.supportsPreview &&
      definition.honoursDateRange &&
      comparisonFor(_payload) != null;

  /// The window the figures on screen are being compared with; null until
  /// the comparison has been fetched.
  DashboardComparison? get compareWindow =>
      _comparePreview == null ? null : _compareWindow;

  void setCompare(bool value) {
    if (value == _compare) return;
    _compare = value;
    if (!value) {
      _compareEpoch++;
      _comparePreview = null;
      _compareWindow = null;
      _compareMemoKey = null;
      _compareMemoView = null;
    }
    notifyListeners();
    if (value && _run.preview != null) unawaited(_runCompare());
  }

  /// Fetch the same report for the period before. A second, quieter run: it
  /// draws no spinner and reports no error — a comparison that could not be
  /// had is simply not shown, and the report itself is unaffected.
  Future<void> _runCompare() async {
    final epoch = ++_compareEpoch;
    final window = _compare && canCompare ? comparisonFor(_payload) : null;
    if (window == null || !_mayRun) {
      if (_comparePreview != null) {
        _comparePreview = null;
        _compareWindow = null;
        _compareMemoKey = null;
        _compareMemoView = null;
        notifyListeners();
      }
      return;
    }
    final report = _reportIdentifier;
    try {
      final raw = await repo.runPreview(
        reportIdentifier: report,
        endpoint: definition.endpoint,
        payload: _payload.copyWith(
          datePreset: ReportDatePreset.custom,
          startDate: () => window.previousStart,
          endDate: () => window.previousEnd,
        ),
        numberStyle: _numberStyle,
        companyId: companyId,
        // The same columns the result on screen was asked for, so the two
        // can be cut the same way.
        reportKeys: _previewReportKeys(),
        isCancelled: () => _disposed || epoch != _compareEpoch,
      );
      if (_disposed || epoch != _compareEpoch || report != _reportIdentifier) {
        return;
      }
      _comparePreview = _augmentPreview(raw);
      _compareWindow = window;
      _compareMemoKey = null;
      _compareMemoView = null;
      notifyListeners();
    } on ReportError catch (e) {
      if (_disposed || epoch != _compareEpoch) return;
      if (e.kind != ReportErrorKind.cancelled) {
        _log.fine('Comparison run failed: ${e.kind}');
      }
      _comparePreview = null;
      _compareWindow = null;
      notifyListeners();
    } catch (e, st) {
      if (_disposed || epoch != _compareEpoch) return;
      _log.warning('Unhandled comparison failure', e, st);
      _comparePreview = null;
      _compareWindow = null;
      notifyListeners();
    }
  }

  /// Whether there is anything of this report on screen to keep while it is
  /// refreshed, or to describe as "from an hour ago" when a refresh fails.
  bool get hasResult => _run.preview != null || _document != null;

  /// Whether what is on screen answers the request as it now stands — the
  /// payload has not changed since it was fetched. A document that could
  /// not be read counts: fetching the same file again reads no better.
  bool get hasResultForRequest =>
      (hasResult || _documentUnreadable) && !isParamDirty;

  String? _activePollingHash; // for "Keep waiting?" continuation

  // ─── Local-only UI state ───
  Set<String> _visibleColumnIds = const {};
  Set<String> get visibleColumnIds => _visibleColumnIds;

  /// User-chosen column display order (identifiers). Empty = server order.
  /// Set by the column picker's reorder; honored by the engine (with the
  /// group-pinned-to-index-0 exception when grouping).
  List<String> _columnOrder = const [];
  List<String> get columnOrder => _columnOrder;

  Map<String, String> _columnFilters = const {};
  Map<String, String> get columnFilters => _columnFilters;

  bool _columnFiltersVisible = false;
  bool get columnFiltersVisible => _columnFiltersVisible;

  bool _chartVisible = true;
  bool get chartVisible => _chartVisible;

  /// Whether the Report Settings panel is collapsed to a thin rail. Local-
  /// only UI state; persisted across restarts in Slice 2.
  bool _panelCollapsed = false;
  bool get panelCollapsed => _panelCollapsed;
  void setPanelCollapsed(bool value) {
    if (_panelCollapsed == value) return;
    _userTouched = true;
    _panelCollapsed = value;
    notifyListeners();
  }

  /// Opt-in for [ReportDefinition.optionalDateColumnId]. On, the preview
  /// asks for the server's own column set **plus** that column; off, it
  /// sends an empty `report_keys` exactly as before.
  ///
  /// It has to be opt-in rather than always-on because a non-empty
  /// `report_keys` *pins* the column set: a column the server adds later
  /// would never reach a pinned user. Off is the escape hatch — a plain
  /// run re-learns the current set into [_serverColumnIds] — and it keeps
  /// default behaviour byte-identical for anyone who doesn't want it.
  bool _includeDateColumn = false;
  bool get includeDateColumn => _includeDateColumn;

  /// Identifiers the last successful preview returned, persisted so the
  /// augmented request survives a cold start (a restored `group` pointing
  /// at the optional column would otherwise be dropped by
  /// [_reconcileWithColumns] on the very first run).
  ///
  /// Deliberately not [_visibleColumnIds]: that is the user's *selection*,
  /// so reusing it would make hiding a column stop it being **fetched**,
  /// and the column picker — sourced from `preview.columns` — could never
  /// offer it back.
  List<String> _serverColumnIds = const [];

  /// When [_serverColumnIds] was last learned from a **plain** run — one that
  /// sent no `report_keys`, so the answer is the server's own current set and
  /// not an echo of what was asked for. Milliseconds since the epoch; 0 for
  /// never.
  int _serverColumnsLearnedAt = 0;

  /// How long a learned column set is trusted before a plain run re-learns
  /// it. Only matters while runs are pinning the set ([fetchRowIds]).
  static const Duration _kServerColumnsMaxAge = Duration(days: 7);

  String? _sortField;
  bool _sortAscending = true;

  /// Whether the sort in force is the ranking a category grouping opens
  /// with ([_syncRanking]) rather than one the reader chose. Persisted with
  /// the sort: an implicit ranking that came back from disk looking like a
  /// choice would then survive a switch to "by month", and list the months
  /// largest first.
  bool _sortIsRanking = false;
  String? get sortField => _sortField;
  bool get sortAscending => _sortAscending;

  /// Further sort keys behind [sortField] — see [toggleSort].
  List<ReportSort> _thenBy = const [];
  List<ReportSort> get thenBy => _thenBy;

  /// The row search. Not remembered between sessions: a search is something
  /// typed to find a row, not a setting of the report.
  String _search = '';
  String get search => _search;

  /// The currency the figures are read in, when the reader chose one. Null
  /// lets the view pick (`resolveReportCurrency`).
  String? _currencyId;
  String? get currencyId => _currencyId;

  /// Column widths the reader dragged, by column identifier.
  Map<String, double> _columnWidths = const {};
  Map<String, double> get columnWidths => _columnWidths;

  /// Whether a time series is drawn as a running total.
  bool _cumulative = false;
  bool get cumulative => _cumulative;

  /// How a time series is drawn; null lets the chart choose by how many
  /// periods it has.
  ReportTimeChartStyle? _timeChartStyle;
  ReportTimeChartStyle? get timeChartStyle => _timeChartStyle;

  /// The groups open in the table (`ReportTableGroupLine.id`). Not
  /// remembered: which groups were open is a place in the page, not a
  /// setting.
  Set<String> _expandedGroups = const {};
  Set<String> get expandedGroups => _expandedGroups;

  String? _group;
  String? get group => _group;
  ReportSubgroup? _subgroup;
  ReportSubgroup? get subgroup => _subgroup;

  /// Date column splitting a non-date [group] by period (granularity
  /// [subgroup]) — see [ReportUiState.periodColumn]. Local-only: the server
  /// has no two-level grouping, so export / email / schedule stay grouped by
  /// [serverGroupBy] alone.
  String? _periodColumn;
  String? get periodColumn => _periodColumn;
  String? _selectedGroup;
  String? get selectedGroup => _selectedGroup;

  /// Identifier of the numeric column the chart card aggregates per group.
  /// Null when no group is active or before the chart card auto-picks the
  /// first numeric column from the active preview. Cleared on `setReport`
  /// (a new report's column set is unrelated) and `resetEverything`.
  String? _chartColumn;
  String? get chartColumn => _chartColumn;

  /// Numeric columns (money + plain number) from the active preview that
  /// the chart card's column picker can offer. Returns `[]` before a
  /// preview is loaded. Reads from `preview.columns`, not
  /// `_visibleColumnIds`, so hiding a column from the table doesn't blank
  /// the chart.
  List<ReportColumn> numericChartColumns() {
    final preview = _run.preview;
    if (preview == null) return const [];
    return preview.columns
        .where(
          (c) =>
              c.type == ReportColumnType.money ||
              c.type == ReportColumnType.number,
        )
        .toList(growable: false);
  }

  /// Active filter count for the toolbar badge. Excludes `date_range`, which
  /// has its own toolbar surface, and matches against the report's
  /// `defaultFilterValues`.
  int get activeFilterCount {
    final defaults = definition.defaultFilterValues;
    String defaultStr(String key) => defaults[key]?.toString() ?? '';
    bool defaultBool(String key) => defaults[key] == true;
    var n = 0;
    for (final f in definition.filterFields) {
      bool changed;
      switch (f) {
        case ReportFilterField.dateRange:
          continue;
        case ReportFilterField.status:
          changed = (_payload.status ?? '') != defaultStr('status');
        case ReportFilterField.clientsMulti:
          changed = (_payload.clients ?? '') != defaultStr('clients');
        case ReportFilterField.clientSingle:
        case ReportFilterField.clientIdsMulti:
          changed = (_payload.clientId ?? '') != defaultStr('client_id');
        case ReportFilterField.vendorsMulti:
          changed = (_payload.vendors ?? '') != defaultStr('vendors');
        case ReportFilterField.projectsMulti:
          changed = (_payload.projects ?? '') != defaultStr('projects');
        case ReportFilterField.tagsMulti:
          changed = (_payload.tags ?? '') != defaultStr('tag_ids');
        case ReportFilterField.categoriesMulti:
          changed = (_payload.categories ?? '') != defaultStr('categories');
        case ReportFilterField.activityType:
          changed =
              (_payload.activityTypeId ?? '') != defaultStr('activity_type_id');
        case ReportFilterField.productKey:
          changed = (_payload.productKey ?? '') != defaultStr('product_key');
        case ReportFilterField.template:
          changed = (_payload.templateId ?? '') != defaultStr('template');
        case ReportFilterField.documentEmailAttachment:
          changed =
              _payload.documentEmailAttachment !=
              defaultBool('document_email_attachment');
        case ReportFilterField.pdfEmailAttachment:
          changed =
              _payload.pdfEmailAttachment !=
              defaultBool('pdf_email_attachment');
        case ReportFilterField.includeDeleted:
          changed = _payload.includeDeleted != defaultBool('include_deleted');
        case ReportFilterField.isIncomeBilled:
          changed = _payload.isIncomeBilled != defaultBool('is_income_billed');
      }
      if (changed) n++;
    }
    return n;
  }

  // ─── Concurrency ───
  int _runEpoch = 0;
  bool _disposed = false;

  /// Used by the polling layer to bail out on cancel / dispose. Captures
  /// the epoch at the moment the run started so a fresh run (which bumps
  /// the epoch) immediately strands the old poll.
  ReportPollingCancellation _cancellationFor(int epoch) =>
      () => _disposed || _runEpoch != epoch;

  // ─── Engine memoization ───
  // Non-final: rebuilt in [buildView] when the company fiscal-year / week-start
  // settings change (the engine carries them so date subgroups bucket on the
  // fiscal year + configured week start).
  ReportEngine _engine = const ReportEngine();
  // Memo key: (preview identity, ui-state hash, exchange-rates epoch).
  // statics.currencies is rebuilt on company switch / refresh; we use its
  // identityHashCode as a cheap epoch proxy.
  int? _memoKey;
  ReportView? _memoView;

  /// Compute the view from the current preview + UI state. Memoized so the
  /// table widget can call this on every rebuild without recomputing.
  ///
  /// Caller supplies the [companyCurrencyId] and [convertCurrency] flag
  /// (typically from the active company's `CompanyFormatSettings` + a
  /// pending settings model). Phase 1 ships with `convertCurrency: false`
  /// so the engine path is wired but defaulted off; flipping it on per
  /// company is a Phase-2 concern.
  ReportView buildView({
    String? companyCurrencyId,
    bool convertCurrency = false,
    int firstMonthOfYear = 1,
    int firstDayOfWeek = 0,
    Map<String, Decimal>? exchangeRatesOverride,
  }) {
    final preview = _run.preview ?? ReportPreview.empty;
    final rates =
        exchangeRatesOverride ??
        {
          for (final entry in statics.currencies.entries)
            entry.key: entry.value.exchangeRate,
        };
    final ratesEpoch = identityHashCode(statics.currencies);
    final ui = ReportUiState(
      visibleColumnIds: _visibleColumnIds,
      columnOrder: _columnOrder,
      columnFilters: _columnFilters,
      search: _search,
      sortField: _sortField,
      sortAscending: _sortAscending,
      thenBy: _thenBy,
      currencyId: _currencyId,
      group: _group,
      subgroup: _subgroup,
      periodColumn: _periodColumn,
      selectedGroup: _selectedGroup,
      convertCurrency: convertCurrency,
    );
    final key = Object.hash(
      identityHashCode(preview),
      ui.hashCode,
      // Exchange rates only feed converted totals; when conversion is off a
      // company-switch / statics refresh shouldn't bust the memo.
      convertCurrency ? ratesEpoch : 0,
      companyCurrencyId,
      convertCurrency,
      firstMonthOfYear,
      firstDayOfWeek,
    );
    if (_memoKey == key && _memoView != null) return _memoView!;
    // The engine holds the fiscal-year / week-start settings; rebuild it when
    // they change so date subgroups bucket correctly.
    if (_engine.firstMonthOfYear != firstMonthOfYear ||
        _engine.firstDayOfWeek != firstDayOfWeek) {
      _engine = ReportEngine(
        firstMonthOfYear: firstMonthOfYear,
        firstDayOfWeek: firstDayOfWeek,
      );
    }
    _memoView = _engine.compute(
      preview: preview,
      ui: ui,
      exchangeRates: rates,
      companyCurrencyId: companyCurrencyId,
    );
    _memoKey = key;
    return _memoView!;
  }

  /// The previous period cut exactly as [buildView] cuts the current one —
  /// same columns, filters, search, grouping and granularity — or null when
  /// there is no comparison on screen. A drill is not carried over: it names
  /// a bucket of *this* period.
  ReportView? buildCompareView({
    String? companyCurrencyId,
    int firstMonthOfYear = 1,
    int firstDayOfWeek = 0,
  }) {
    final preview = _comparePreview;
    if (preview == null) return null;
    final ui = ReportUiState(
      visibleColumnIds: _visibleColumnIds,
      columnOrder: _columnOrder,
      columnFilters: _columnFilters,
      search: _search,
      sortField: _sortField,
      sortAscending: _sortAscending,
      thenBy: _thenBy,
      currencyId: _currencyId,
      group: _group,
      subgroup: _subgroup,
      periodColumn: _periodColumn,
    );
    final key = Object.hash(
      identityHashCode(preview),
      ui.hashCode,
      companyCurrencyId,
      firstMonthOfYear,
      firstDayOfWeek,
    );
    if (_compareMemoKey == key && _compareMemoView != null) {
      return _compareMemoView;
    }
    _compareMemoView =
        ReportEngine(
          firstMonthOfYear: firstMonthOfYear,
          firstDayOfWeek: firstDayOfWeek,
        ).compute(
          preview: preview,
          ui: ui,
          exchangeRates: const {},
          companyCurrencyId: companyCurrencyId,
        );
    _compareMemoKey = key;
    return _compareMemoView;
  }

  /// The contiguous bucket keys a date-grouped chart should plot, or
  /// `const []` when there is nothing to fill.
  ///
  /// `_bucket` only emits a bucket for a date that *has* rows, so a month
  /// nobody signed up in is absent rather than zero — and a chart plotting
  /// buckets by index then draws two non-adjacent periods as neighbours.
  /// This hands the chart the full span so it can plot the gaps as zeroes.
  ///
  /// It lives here rather than in the card because the span depends on the
  /// engine's fiscal-year and week-start configuration, which only this
  /// class holds. [buildView] must have run at least once (it always has —
  /// the card is built from its result).
  List<String> chartBucketKeys(List<GroupTotals> groups, ReportColumn? column) {
    if (column == null || groups.length < 2) return const [];
    if (column.type != ReportColumnType.date &&
        column.type != ReportColumnType.dateTime) {
      return const [];
    }
    // Only fill when the granularity is *declared*. `_dateBucket` falls back
    // to day for a null subgroup, so filling on that assumption would invent
    // a daily timeline under buckets that may not be daily at all — and the
    // group-by control always sets one for a date column, so in practice
    // this only skips a grouping set some other way.
    final subgroup = _subgroup;
    if (subgroup == null) return const [];
    final span = _engine.dateBucketSpan(
      groups.first.key,
      groups.last.key,
      subgroup,
    );
    // Nothing missing (or the span was refused as too long) — the caller
    // plots the raw buckets, exactly as before.
    if (span.length <= groups.length) return const [];
    return span;
  }

  /// Every period between two bucket starts at the granularity in force —
  /// what a chart's time axis is filled with, so a month nothing happened in
  /// is drawn as a zero rather than left out. Empty when the granularity is
  /// not declared, or the span is too long to draw (see
  /// [ReportEngine.dateBucketSpan]); the chart then plots the buckets it has.
  ///
  /// Here rather than in the chart because the span depends on the engine's
  /// fiscal-year and week-start configuration, which only this class holds.
  List<String> periodSpan(String first, String last) {
    final subgroup =
        _subgroup ?? (isSplitByPeriod ? ReportSubgroup.month : null);
    if (subgroup == null) return const [];
    return _engine.dateBucketSpan(first, last, subgroup);
  }

  /// Which colour each group wears in a chart of groups over time — the
  /// chart model's memory (`ReportChartModels.build`), kept here so it
  /// outlives a rebuild. A group keeps its colour while the reader narrows
  /// and widens the filters; it is forgotten with the grouping.
  final Map<String, int> seriesSlots = {};

  /// The series the reader has switched off in the chart, by group key.
  Set<String> _hiddenSeries = const {};
  Set<String> get hiddenSeries => _hiddenSeries;

  void toggleSeries(String key) {
    final next = {..._hiddenSeries};
    if (!next.remove(key)) next.add(key);
    _hiddenSeries = Set.unmodifiable(next);
    notifyListeners();
  }

  void _invalidateMemo() {
    _memoKey = null;
    _memoView = null;
  }

  // ─── Restore-on-restart persistence ───

  /// Awaitable that completes once hydration has run. [runReport] awaits it
  /// so a cold Run can't overwrite a persisted column set before it loads.
  Future<void> get hydration => _hydration;

  Future<void> _hydrate() async {
    try {
      final row = await navStateDao!.current();
      final raw = row?.filtersJson;
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final company = decoded[companyId];
      if (company is! Map) return;
      final snap = company[_persistKey];
      if (snap is! Map) return;
      // Yield to a live user action that landed before hydration resolved —
      // restoring here would clobber what they just did.
      if (_userTouched) return;
      _applySnapshot(Map<String, dynamic>.from(snap));
    } catch (e, st) {
      _log.warning('Failed to hydrate reports state; using defaults', e, st);
    } finally {
      // Marks the hydration *attempt* complete — state may have been skipped
      // above when the user already acted — and opens the persist gate.
      _hydrated = true;
      notifyListeners();
    }
  }

  /// How many reports' own state is remembered besides the current one.
  /// The blob this lives in is shared with every list screen and decoded by
  /// each of them on every write, so it is kept small.
  static const int _kRememberedReports = 8;

  /// What is written to disk: the current report's state at the top level —
  /// the shape every earlier build wrote and reads, so a rolled-back build
  /// still finds its place — plus, beside it, the state of the reports
  /// visited before it ([_perReport]) and the order they were visited in.
  Map<String, dynamic> _snapshot() => <String, dynamic>{
    'report': _reportIdentifier,
    ..._reportSnapshot(),
    if (_recent.isNotEmpty) 'recent': _recent,
    if (_perReport.isNotEmpty) 'reports': _perReport,
  };

  /// The current report's own state — everything that is the reader's
  /// choice and worth finding again, and nothing that is a result.
  Map<String, dynamic> _reportSnapshot() => <String, dynamic>{
    'payload': _payloadToMap(_payload),
    'visibleColumns': _visibleColumnIds.toList(),
    if (_columnOrder.isNotEmpty) 'columnOrder': _columnOrder,
    'columnFilters': _columnFilters,
    if (_group != null) 'group': _group,
    if (_subgroup != null) 'subgroup': _subgroup!.name,
    if (_periodColumn != null) 'periodColumn': _periodColumn,
    if (_sortField != null) 'sortField': _sortField,
    'sortAscending': _sortAscending,
    if (_sortIsRanking) 'sortIsRanking': true,
    if (_thenBy.isNotEmpty)
      'thenBy': [
        for (final sort in _thenBy)
          {'column': sort.columnId, 'ascending': sort.ascending},
      ],
    'panelCollapsed': _panelCollapsed,
    'chartVisible': _chartVisible,
    if (_compare) 'compare': true,
    if (_viewId != null) 'viewId': _viewId,
    // The chart's series is as much "where the user left off" as the group
    // it charts; without it a restart re-auto-picks the first numeric column
    // and silently drops a deliberate Count selection.
    if (_chartColumn != null) 'chartColumn': _chartColumn,
    if (_currencyId != null) 'currency': _currencyId,
    if (_cumulative) 'cumulative': true,
    if (_timeChartStyle != null) 'timeChartStyle': _timeChartStyle!.name,
    if (_columnWidths.isNotEmpty) 'columnWidths': _columnWidths,
    if (_includeDateColumn) 'includeDateColumn': true,
    // Persisted so a restored grouping on the optional date column survives
    // the cold run that would otherwise drop it (see `_previewReportKeys`).
    if (_serverColumnIds.isNotEmpty) 'serverColumns': _serverColumnIds,
    if (_serverColumnsLearnedAt > 0) 'serverColumnsAt': _serverColumnsLearnedAt,
  };

  void _applySnapshot(Map<String, dynamic> s) {
    final report = s['report'];
    if (report is String &&
        kReportDefinitions.any((d) => d.identifier == report)) {
      _reportIdentifier = report;
    }
    final reports = s['reports'];
    if (reports is Map) {
      _perReport = {
        for (final e in reports.entries)
          if (e.value is Map && _isKnownReport('${e.key}'))
            '${e.key}': Map<String, dynamic>.from(e.value as Map),
      };
    }
    final recent = s['recent'];
    if (recent is List) {
      _recent = [
        for (final id in recent)
          if (_isKnownReport('$id')) '$id',
      ];
    }
    _applyReportSnapshot(s);
  }

  static bool _isKnownReport(String identifier) =>
      kReportDefinitions.any((d) => d.identifier == identifier);

  /// Put the current report into the state [s] describes — and into nothing
  /// else: every field is reset first, so a key [s] does not carry cannot be
  /// left holding the previous report's value.
  void _applyReportSnapshot(Map<String, dynamic> s) {
    _resetReportState();
    final pm = s['payload'];
    if (pm is Map) _payload = _payloadFromMap(Map<String, dynamic>.from(pm));
    final vc = s['visibleColumns'];
    if (vc is List) {
      _visibleColumnIds = Set.unmodifiable(vc.map((e) => '$e'));
    }
    final co = s['columnOrder'];
    if (co is List) {
      _columnOrder = List.unmodifiable(co.map((e) => '$e'));
    }
    final cf = s['columnFilters'];
    if (cf is Map) {
      _columnFilters = Map.unmodifiable(cf.map((k, v) => MapEntry('$k', '$v')));
    }
    final g = s['group'];
    if (g is String) _group = g;
    final sg = s['subgroup'];
    if (sg is String) {
      _subgroup = ReportSubgroup.values.where((e) => e.name == sg).firstOrNull;
    }
    final pcol = s['periodColumn'];
    if (pcol is String && pcol.isNotEmpty) _periodColumn = pcol;
    final sf = s['sortField'];
    if (sf is String) _sortField = sf;
    final sa = s['sortAscending'];
    if (sa is bool) _sortAscending = sa;
    _sortIsRanking = s['sortIsRanking'] == true && _sortField != null;
    final tb = s['thenBy'];
    if (tb is List) {
      _thenBy = List.unmodifiable([
        for (final e in tb)
          if (e is Map && e['column'] is String)
            ReportSort(
              e['column'] as String,
              ascending: e['ascending'] != false,
            ),
      ]);
    }
    final pc = s['panelCollapsed'];
    if (pc is bool) _panelCollapsed = pc;
    _compare = s['compare'] == true;
    final vid = s['viewId'];
    _viewId = vid is String && vid.isNotEmpty ? vid : null;
    final cv = s['chartVisible'];
    if (cv is bool) _chartVisible = cv;
    final cc = s['chartColumn'];
    if (cc is String && cc.isNotEmpty) _chartColumn = cc;
    final cur = s['currency'];
    if (cur is String && cur.isNotEmpty) _currencyId = cur;
    _cumulative = s['cumulative'] == true;
    final tcs = s['timeChartStyle'];
    if (tcs is String) {
      _timeChartStyle = ReportTimeChartStyle.values
          .where((e) => e.name == tcs)
          .firstOrNull;
    }
    final cw = s['columnWidths'];
    if (cw is Map) {
      _columnWidths = Map.unmodifiable({
        for (final e in cw.entries)
          if (e.value is num) '${e.key}': (e.value as num).toDouble(),
      });
    }
    _includeDateColumn = s['includeDateColumn'] == true;
    final sc = s['serverColumns'];
    if (sc is List) {
      _serverColumnIds = List.unmodifiable(sc.map((e) => '$e'));
    }
    final sca = s['serverColumnsAt'];
    if (sca is int) _serverColumnsLearnedAt = sca;
  }

  /// Every per-report field back to blank: no result, no choices.
  void _resetReportState() {
    _payload = _openingPayload(_reportIdentifier);
    _lastRunPayload = null;
    _visibleColumnIds = const {};
    _columnOrder = const [];
    _columnFilters = const {};
    _columnWidths = const {};
    _sortField = null;
    _sortAscending = true;
    _sortIsRanking = false;
    _thenBy = const [];
    _search = '';
    _group = null;
    _subgroup = null;
    _periodColumn = null;
    _selectedGroup = null;
    _expandedGroups = const {};
    _chartColumn = null;
    _chartVisible = true;
    _compare = false;
    _viewId = null;
    _currencyId = null;
    _cumulative = false;
    _timeChartStyle = null;
    // Both are per-report: the Group by entry that turns the flag on is
    // itself gated on a loaded preview, so re-picking after a report switch
    // costs nothing.
    _includeDateColumn = false;
    _lastRunIncludeDateColumn = false;
    _serverColumnIds = const [];
    _serverColumnsLearnedAt = 0;
    _resultFetchedAt = null;
    seriesSlots.clear();
    _hiddenSeries = const {};
    _run = ReportRunState.idle();
    _activePollingHash = null;
    _invalidateMemo();
  }

  /// The state of the reports visited before the current one, by identifier
  /// — each as [_reportSnapshot] wrote it. What makes a report remember its
  /// own range, filters, grouping and columns across a switch to another.
  Map<String, Map<String, dynamic>> _perReport = {};

  /// Reports in the order they were last opened, most recent first. Drives
  /// the gallery's "Recent" row and which of [_perReport] is kept.
  List<String> _recent = const [];
  List<String> get recentReports => _recent;

  Map<String, dynamic> _payloadToMap(ReportPayload p) => <String, dynamic>{
    'datePreset': p.datePreset.name,
    if (p.startDate != null) 'startDate': p.startDate!.toIso(),
    if (p.endDate != null) 'endDate': p.endDate!.toIso(),
    if (p.dateKey != null) 'dateKey': p.dateKey,
    if (p.clientId != null) 'clientId': p.clientId,
    if (p.clients != null) 'clients': p.clients,
    if (p.vendors != null) 'vendors': p.vendors,
    if (p.categories != null) 'categories': p.categories,
    if (p.projects != null) 'projects': p.projects,
    if (p.tags != null) 'tags': p.tags,
    if (p.status != null) 'status': p.status,
    if (p.activityTypeId != null) 'activityTypeId': p.activityTypeId,
    if (p.productKey != null) 'productKey': p.productKey,
    if (p.templateId != null) 'templateId': p.templateId,
    // Not `documentEmailAttachment` / `pdfEmailAttachment`: they are choices
    // made when an email is sent, and a switch remembered from last month
    // would zip every PDF into an email nobody asked that of.
    'includeDeleted': p.includeDeleted,
    'includeTax': p.includeTax,
    'isExpenseBilled': p.isExpenseBilled,
    'isIncomeBilled': p.isIncomeBilled,
  };

  ReportPayload _payloadFromMap(Map<String, dynamic> m) {
    Date? d(Object? v) => v is String ? Date.tryParse(v) : null;
    String? s(Object? v) => v is String && v.isNotEmpty ? v : null;
    return ReportPayload(
      datePreset:
          ReportDatePreset.values
              .where((e) => e.name == m['datePreset'])
              .firstOrNull ??
          ReportDatePreset.allTime,
      startDate: d(m['startDate']),
      endDate: d(m['endDate']),
      dateKey: s(m['dateKey']),
      clientId: s(m['clientId']),
      clients: s(m['clients']),
      vendors: s(m['vendors']),
      categories: s(m['categories']),
      projects: s(m['projects']),
      tags: s(m['tags']),
      status: s(m['status']),
      activityTypeId: s(m['activityTypeId']),
      productKey: s(m['productKey']),
      templateId: s(m['templateId']),
      includeDeleted: m['includeDeleted'] == true,
      includeTax: m['includeTax'] == true,
      isExpenseBilled: m['isExpenseBilled'] == true,
      isIncomeBilled: m['isIncomeBilled'] == true,
    );
  }

  void _schedulePersist() {
    if (!_hydrated || navStateDao == null || companyId == null) return;
    _persistTimer?.cancel();
    _persistTimer = Timer(_persistDebounce, _persist);
  }

  Future<void> _persist() async {
    final dao = navStateDao;
    final cid = companyId;
    if (dao == null || cid == null) return;
    try {
      final row = await dao.current();
      final existing = row?.filtersJson;
      Map<String, dynamic> doc;
      if (existing == null || existing.isEmpty) {
        doc = <String, dynamic>{};
      } else {
        final decoded = jsonDecode(existing);
        doc = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      }
      final companyBlob = doc[cid];
      final companyMap = companyBlob is Map<String, dynamic>
          ? Map<String, dynamic>.from(companyBlob)
          : <String, dynamic>{};
      companyMap[_persistKey] = _snapshot();
      doc[cid] = companyMap;
      await dao.saveFilters(
        filtersJson: jsonEncode(doc),
        now: _now().millisecondsSinceEpoch,
      );
    } catch (e, st) {
      _log.warning('Failed to persist reports state', e, st);
    }
  }

  /// After a fresh preview lands, reconcile view-state against the columns the
  /// report actually returned. The preview always requests the server's full
  /// default column set (see [runReport]), so the user's visible selection is
  /// authoritative: keep the ids that still exist and drop ones the report no
  /// longer returns — but do **not** auto-show columns the user has hidden (the
  /// column picker exposes the full set for manual re-add). Also drop a
  /// `group`/`sortField` pointing at a vanished column. `_columnOrder` still
  /// appends any unlisted columns so the picker can order them; rendering is
  /// gated on `_visibleColumnIds`, so a hidden column sitting in the order is
  /// inert.
  void _reconcileWithColumns(ReportPreview preview) {
    final ids = preview.columns.map((c) => c.identifier).toSet();
    if (ids.isEmpty) return;
    if (_visibleColumnIds.isNotEmpty) {
      _visibleColumnIds = Set.unmodifiable(
        _visibleColumnIds.where(ids.contains).toSet(),
      );
    }
    if (_columnOrder.isNotEmpty) {
      // Drop vanished ids; append any new server columns so a reordered
      // report still shows new data (at the end, like visibleColumns).
      final kept = _columnOrder.where(ids.contains).toList();
      final added = ids.where((id) => !kept.contains(id));
      _columnOrder = List.unmodifiable([...kept, ...added]);
    }
    if (_group != null && !ids.contains(_group)) {
      _group = null;
      _subgroup = null;
      _periodColumn = null;
    }
    if (_periodColumn != null && !ids.contains(_periodColumn)) {
      _periodColumn = null;
      // The drill was into a composite bucket that no longer exists.
      _selectedGroup = null;
    }
    if (_sortField != null && !ids.contains(_sortField)) {
      _sortField = null;
      _sortIsRanking = false;
    }
  }

  // ─── Mutations ───

  /// Switch to another report, putting this one's state away and taking the
  /// other's back out — or, for a report never opened, its opening view.
  void setReport(String identifier) {
    if (identifier == _reportIdentifier) return;
    _userTouched = true;
    // Strand whatever is in flight. A run only checks its epoch, so without
    // this a report switched away from mid-run still landed — its rows
    // appearing under the new report's name, columns and filters.
    _runEpoch++;
    _autoRunTimer?.cancel();
    _autoRunOwed = false;
    // Another report's document is not this one's — nor its comparison.
    _document = null;
    _documentUnreadable = false;
    _emailedFor = null;
    _compareEpoch++;
    _comparePreview = null;
    _compareWindow = null;
    _compareMemoKey = null;
    _compareMemoView = null;
    _perReport[_reportIdentifier] = _reportSnapshot();
    _reportIdentifier = identifier;
    final remembered = _perReport.remove(identifier);
    if (remembered != null) {
      _applyReportSnapshot(remembered);
    } else {
      _resetReportState();
      _applyOpeningView();
    }
    _noteOpened(identifier);
    notifyListeners();
  }

  /// Move [identifier] to the front of [_recent], and forget the state of
  /// whatever has fallen out of the remembered few.
  void _noteOpened(String identifier) {
    _recent = List.unmodifiable([
      identifier,
      for (final id in _recent)
        if (id != identifier) id,
    ]);
    if (_perReport.length > _kRememberedReports) {
      final keep = _recent.take(_kRememberedReports + 1).toSet();
      _perReport.removeWhere((id, _) => !keep.contains(id));
    }
  }

  /// Show [identifier]: switch to it if it is not the current report, and —
  /// under [autoRun] — put its last result on screen and refresh it if that
  /// is stale. What the screen calls when its route names a report.
  ///
  /// Waits for the restore first. The route decides which report is shown;
  /// the restore only supplies what each report remembers, and applied after
  /// this it would swap the report out from under the route.
  Future<void> open(String identifier) async {
    if (!_hydrated) await _hydration;
    if (_disposed) return;
    if (identifier != _reportIdentifier) {
      setReport(identifier);
    } else if (_recent.firstOrNull != identifier) {
      _noteOpened(identifier);
      notifyListeners();
    }
    if (autoRun) await _showOrRun();
  }

  void setPayload(ReportPayload payload) {
    if (payload == _payload) return;
    _userTouched = true;
    final changesRows = payload.forPreview != _payload.forPreview;
    _payload = payload;
    notifyListeners();
    if (changesRows) _scheduleAutoRun();
  }

  /// [order], when given, is the full column display order chosen in the
  /// picker (the engine pins the group column to index 0 when grouping,
  /// regardless). Pass `null` to leave the existing order untouched.
  void setVisibleColumns(Set<String> ids, {List<String>? order}) {
    _visibleColumnIds = Set.unmodifiable(ids);
    if (order != null) _columnOrder = List.unmodifiable(order);
    _invalidateMemo();
    notifyListeners();
  }

  void setColumnFilter(String columnId, String value) {
    final next = Map<String, String>.from(_columnFilters);
    if (value.isEmpty) {
      next.remove(columnId);
    } else {
      next[columnId] = value;
    }
    _columnFilters = Map.unmodifiable(next);
    _invalidateMemo();
    notifyListeners();
  }

  void clearColumnFilter(String columnId) => setColumnFilter(columnId, '');

  void toggleColumnFiltersVisible() {
    _columnFiltersVisible = !_columnFiltersVisible;
    notifyListeners();
  }

  void setChartVisible(bool value) {
    if (_chartVisible == value) return;
    _chartVisible = value;
    notifyListeners();
  }

  /// Pick the column the chart card aggregates by. Null clears. Does NOT
  /// invalidate the engine memo — `chartColumn` doesn't feed into the
  /// engine compute; the chart card reads from the same `ReportView` the
  /// table renders.
  void setChartColumn(String? id) {
    if (_chartColumn == id) return;
    _chartColumn = id;
    // A ranking follows the figure it ranks by.
    if (_syncRanking()) _invalidateMemo();
    notifyListeners();
  }

  /// The figure a category grouping is ranked by: the one the chart is of
  /// when that is a column, else the report's first headline the result
  /// carries, else its first figure. Null when the result has none (or the
  /// chart is of the row count, which is not a column to sort by).
  String? get _rankingMeasureId {
    final measures = [
      for (final c in _run.preview?.columns ?? const <ReportColumn>[])
        if (c.effectiveAggregation != ReportAggregation.none) c.identifier,
    ];
    if (measures.isEmpty) return null;
    final chosen = _chartColumn;
    if (chosen != null) return measures.contains(chosen) ? chosen : null;
    for (final id in definition.headlineMeasureIds) {
      if (measures.contains(id)) return id;
    }
    return measures.first;
  }

  /// Keep the table's order in step with what the chart above it says.
  ///
  /// Grouped by a category — client, status, product — the chart is a
  /// ranking, largest first, and a table beneath it in alphabetical order is
  /// a second, different list of the same things. So a category grouping
  /// opens sorted by its figure, descending, **as an ordinary sort**: the
  /// header shows the arrow, and one click changes it.
  ///
  /// Only ever in place of *no* sort, or of a ranking this put there
  /// itself; a sort the reader chose is never touched. Grouped by a date, or
  /// not at all, the ranking is taken off again — months belong in order.
  ///
  /// Returns whether the sort changed.
  bool _syncRanking() {
    if (_sortField != null && !_sortIsRanking) return false;
    final group = _group;
    final ranks = group != null && group.isNotEmpty && !_isDateColumn(group);
    final measure = ranks ? _rankingMeasureId : null;
    if (measure == null) {
      if (!_sortIsRanking) return false;
      _sortField = null;
      _sortAscending = true;
      _sortIsRanking = false;
      return true;
    }
    if (_sortIsRanking && _sortField == measure && !_sortAscending) {
      return false;
    }
    _sortField = measure;
    _sortAscending = false;
    _thenBy = const [];
    _sortIsRanking = true;
    return true;
  }

  /// Click a column header to (re)sort. First click → ascending; second
  /// click on the same column → descending; subsequent clicks toggle.
  ///
  /// With [additive] (a shift-click) the column joins the sort behind the
  /// ones already there instead of replacing them — or, if it is already
  /// one of them, flips its own direction in place.
  void toggleSort(String columnId, {bool additive = false}) {
    if (additive && _sortField != null && _sortField != columnId) {
      final at = _thenBy.indexWhere((sort) => sort.columnId == columnId);
      final next = [..._thenBy];
      if (at >= 0) {
        next[at] = ReportSort(columnId, ascending: !next[at].ascending);
      } else {
        next.add(ReportSort(columnId));
      }
      _thenBy = List.unmodifiable(next);
    } else if (_sortField == columnId) {
      _sortAscending = !_sortAscending;
    } else {
      _sortField = columnId;
      _sortAscending = true;
      // A plain click starts the sort over.
      _thenBy = const [];
    }
    // Touched by the reader: theirs from here on.
    _sortIsRanking = false;
    _invalidateMemo();
    notifyListeners();
  }

  /// Sort by [columnId] in a stated direction — what a column menu's
  /// "Sort ascending / descending" does. Null clears the sort.
  void setSort(String? columnId, {bool ascending = true}) {
    _sortField = columnId;
    _sortAscending = ascending;
    _sortIsRanking = false;
    _thenBy = const [];
    _invalidateMemo();
    notifyListeners();
  }

  void setSearch(String value) {
    if (value == _search) return;
    _search = value;
    _invalidateMemo();
    notifyListeners();
  }

  /// Read the figures in [currencyId]; null hands the choice back to the
  /// view.
  void setCurrency(String? currencyId) {
    if (currencyId == _currencyId) return;
    _currencyId = currencyId;
    _invalidateMemo();
    notifyListeners();
  }

  void setColumnWidth(String columnId, double width) {
    _columnWidths = Map.unmodifiable({..._columnWidths, columnId: width});
    notifyListeners();
  }

  void setCumulative(bool value) {
    if (value == _cumulative) return;
    _cumulative = value;
    notifyListeners();
  }

  void setTimeChartStyle(ReportTimeChartStyle? style) {
    if (style == _timeChartStyle) return;
    _timeChartStyle = style;
    notifyListeners();
  }

  /// Open or close one group in the table.
  void toggleGroupExpanded(String lineId) {
    final next = {..._expandedGroups};
    if (!next.remove(lineId)) next.add(lineId);
    _expandedGroups = Set.unmodifiable(next);
    notifyListeners();
  }

  void setExpandedGroups(Set<String> lineIds) {
    _expandedGroups = Set.unmodifiable(lineIds);
    notifyListeners();
  }

  /// Apply one of the report's ready-made views.
  void applyStarterView(ReportStarterView view) {
    _group = view.group;
    _subgroup = view.subgroup;
    _periodColumn = null;
    _selectedGroup = null;
    _expandedGroups = const {};
    if (view.measure != null) _chartColumn = view.measure;
    _chartVisible = true;
    _syncRanking();
    _invalidateMemo();
    notifyListeners();
  }

  /// Drop every filter the reader put on the rows locally — the column
  /// filters, the search and a drill — leaving the server-side ones.
  void clearLocalFilters() {
    _columnFilters = const {};
    _search = '';
    _selectedGroup = null;
    _invalidateMemo();
    notifyListeners();
  }

  void setGroup(String? columnId, {ReportSubgroup? subgroup}) {
    _group = columnId;
    _subgroup = columnId == null ? null : (subgroup ?? _subgroup);
    // A period only splits a non-date grouping. Kept across a switch between
    // two non-date columns (User → Assigned User keeps "by month").
    if (columnId == null || _isDateColumn(columnId)) _periodColumn = null;
    _selectedGroup = null;
    _expandedGroups = const {};
    seriesSlots.clear();
    _hiddenSeries = const {};
    _syncRanking();
    _invalidateMemo();
    notifyListeners();
  }

  // ─── Grouping, as the reader asks for it ───
  //
  // The rules below used to live in two dropdowns' `onChanged` closures. They
  // are not presentation: each exists because of how the optional date
  // column is fetched (docs/reports.md § Asking for a column the server
  // omits), and a second surface that regroups — a column menu, a starter
  // view — has to obey every one of them.

  /// The column the report is grouped by, when the result carries it.
  ReportColumn? get groupColumn => _previewColumn(_group);

  ReportColumn? _previewColumn(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final c in _run.preview?.columns ?? const <ReportColumn>[]) {
      if (c.identifier == id) return c;
    }
    return null;
  }

  /// Whether the grouping is split by period: a non-date group column and a
  /// date [periodColumn], both in the result. Mirrors the engine's own test
  /// for a composite key.
  bool get isSplitByPeriod {
    final group = groupColumn;
    if (group == null || isReportDateType(group.type)) return false;
    final period = _previewColumn(_periodColumn);
    return period != null && isReportDateType(period.type);
  }

  /// The report's [ReportDefinition.optionalDateColumnId] when it is worth
  /// offering: the report has one, and the result on screen does not already
  /// carry it. Offered only over a loaded result — that is what guarantees
  /// there is a column list to add it to.
  String? get offerableDateColumnId {
    final extra = definition.optionalDateColumnId;
    final preview = _run.preview;
    if (extra == null || preview == null) return null;
    if (preview.columns.any((c) => c.identifier == extra)) return null;
    return extra;
  }

  /// Group by [columnId]; null or empty for no grouping.
  ///
  /// A date column starts by month. The optional date column is the one
  /// choice that is not a free local regroup: it has to be fetched, so it
  /// opts in and — where the report does not run itself — runs it, rather
  /// than leave the reader to work out that a Run is needed. And once
  /// fetched, picking it again must keep the opt-in on, or the next run
  /// sends no `report_keys`, the server omits the column, and the grouping
  /// is dropped one interaction later with no message.
  void groupBy(String? columnId) {
    if (columnId == null || columnId.isEmpty) {
      setGroup(null);
      return;
    }
    if (columnId == offerableDateColumnId) {
      setIncludeDateColumn(true);
      setGroup(columnId, subgroup: ReportSubgroup.month);
      if (!autoRun) unawaited(runReport());
      return;
    }
    if (columnId == definition.optionalDateColumnId) {
      setIncludeDateColumn(true);
    }
    final column = _previewColumn(columnId);
    final isDate = column != null && isReportDateType(column.type);
    setGroup(
      columnId,
      subgroup: isDate ? (_subgroup ?? ReportSubgroup.month) : null,
    );
  }

  /// The result's date columns a non-date grouping can be split by, the one
  /// the report's date range filters on first — it is almost always the one
  /// meant ("per month" of an invoice means its date, of a task its start).
  List<ReportColumn> get periodCandidates {
    final columns = _run.preview?.columns ?? const <ReportColumn>[];
    final dates = columns.where((c) => isReportDateType(c.type)).toList();
    final key = switch (definition.dateRangeKey) {
      'calculated_start_date' => 'start_date',
      final k => k,
    };
    if (key == null) return dates;
    bool matches(ReportColumn c) =>
        c.identifier == key || c.identifier.endsWith('.$key');
    return [...dates.where(matches), ...dates.where((c) => !matches(c))];
  }

  /// Split the grouping by [columnId]'s period; null or empty to stop. The
  /// optional date column is fetched on pick and kept opted in, exactly as
  /// [groupBy] does.
  void splitByPeriod(String? columnId) {
    if (columnId == null || columnId.isEmpty) {
      setPeriodColumn(null);
      return;
    }
    if (columnId == offerableDateColumnId) {
      setIncludeDateColumn(true);
      setPeriodColumn(columnId);
      if (!autoRun) unawaited(runReport());
      return;
    }
    if (columnId == definition.optionalDateColumnId) {
      setIncludeDateColumn(true);
    }
    setPeriodColumn(columnId);
  }

  /// Split the current non-date grouping by [columnId]'s date (null to stop
  /// splitting). A new split starts by month; switching the split to another
  /// date column keeps the granularity chosen for it.
  void setPeriodColumn(String? columnId) {
    final id = (columnId == null || columnId.isEmpty) ? null : columnId;
    if (id == _periodColumn) return;
    // Not `??=`: a Day or Week left over from an earlier date grouping is not
    // a choice anyone made for this split.
    if (id != null && _periodColumn == null) _subgroup = ReportSubgroup.month;
    _periodColumn = id;
    // A drill names a bucket of the old key shape, which no longer exists.
    _selectedGroup = null;
    _invalidateMemo();
    notifyListeners();
  }

  bool _isDateColumn(String columnId) {
    for (final c in _run.preview?.columns ?? const <ReportColumn>[]) {
      if (c.identifier == columnId) return isReportDateType(c.type);
    }
    // Not fetched yet — `_GroupByField` groups by the optional date column
    // *before* the run that brings it, and a period left set then would be
    // persisted and resurface on the next non-date grouping.
    return isReportDateType(inferColumnType(columnId));
  }

  void setSubgroup(ReportSubgroup? sg) {
    _subgroup = sg;
    // A drill is into a bucket *at the old granularity*, so it can't survive
    // the change — `_groupKey` re-derives against the new one and matches
    // nothing, leaving "No results" under a breadcrumb that has re-formatted
    // the stale key and now names a period that does have rows. `setGroup`
    // clears it for the same reason.
    _selectedGroup = null;
    _invalidateMemo();
    notifyListeners();
  }

  void setSelectedGroup(String? key) {
    _selectedGroup = key;
    _invalidateMemo();
    notifyListeners();
  }

  /// Reset payload filter values (not the date range, columns, sort or
  /// group). Keeps the loaded preview so the user doesn't have to re-Run
  /// just to clear filters.
  void resetFilters() {
    _userTouched = true;
    final defaults = definition.defaultFilterValues;
    _payload = ReportPayload(
      datePreset: _payload.datePreset,
      startDate: _payload.startDate,
      endDate: _payload.endDate,
      dateKey: _payload.dateKey,
      clientId: defaults['client_id']?.toString(),
      clients: defaults['clients']?.toString(),
      vendors: defaults['vendors']?.toString(),
      categories: defaults['categories']?.toString(),
      projects: defaults['projects']?.toString(),
      status: defaults['status']?.toString(),
      activityTypeId: defaults['activity_type_id']?.toString(),
      productKey: defaults['product_key']?.toString(),
      templateId: defaults['template']?.toString(),
      documentEmailAttachment: defaults['document_email_attachment'] == true,
      pdfEmailAttachment: defaults['pdf_email_attachment'] == true,
      includeDeleted: defaults['include_deleted'] == true,
      includeTax: defaults['include_tax'] == true,
      isExpenseBilled: defaults['is_expense_billed'] == true,
      isIncomeBilled: defaults['is_income_billed'] == true,
    );
    notifyListeners();
    _scheduleAutoRun();
  }

  /// Reset everything except the report identifier — payload, columns,
  /// sort, group, chart. The loaded preview stays so the user can recover
  /// by re-Running.
  void resetEverything() {
    _userTouched = true;
    _payload = const ReportPayload();
    _visibleColumnIds = const {};
    _columnOrder = const [];
    _columnFilters = const {};
    _sortField = null;
    _sortAscending = true;
    _sortIsRanking = false;
    _group = null;
    _subgroup = null;
    _periodColumn = null;
    _selectedGroup = null;
    _chartColumn = null;
    _chartVisible = true;
    _compare = false;
    _viewId = null;
    _comparePreview = null;
    _compareWindow = null;
    _compareEpoch++;
    _includeDateColumn = false;
    _thenBy = const [];
    _search = '';
    _currencyId = null;
    _columnWidths = const {};
    _cumulative = false;
    _timeChartStyle = null;
    _expandedGroups = const {};
    _invalidateMemo();
    notifyListeners();
    _scheduleAutoRun();
  }

  // ─── Server actions ───

  Future<void> runReport() async {
    // Don't let a cold Run race ahead of restore — a persisted column set
    // would be clobbered by the "empty → server columns" default below.
    if (!_hydrated) await _hydration;
    if (_disposed) return;
    if (!definition.supportsPreview) {
      if (definition.readsAsDocument) await _runDocument();
      return;
    }
    final epoch = ++_runEpoch;
    final lastGood = _run.preview;
    _run = ReportRunState.loading(previousPreview: lastGood);
    _activePollingHash = null;
    // The comparison on screen was with the result being replaced. Deltas
    // against the wrong period are worse than none for a moment.
    if (isParamDirty) {
      _compareEpoch++;
      _comparePreview = null;
      _compareWindow = null;
      _compareMemoKey = null;
      _compareMemoView = null;
    }
    notifyListeners();

    try {
      if (!_companyCurrencyResolved) {
        await _resolveCompanyCurrency();
        if (_disposed || epoch != _runEpoch) return;
      }
      final reportKeys = _previewReportKeys();
      final rawPreview = await repo.runPreview(
        reportIdentifier: _reportIdentifier,
        endpoint: definition.endpoint,
        payload: _payload,
        numberStyle: _numberStyle,
        companyId: companyId,
        // Empty = the server's full default column set, which is what the
        // preview wants: column visibility is a purely local concern applied
        // by the engine. Sending the visible *subset* here would narrow the
        // server response, and since the column picker is sourced from
        // `preview.columns`, a hidden column would vanish from the picker and
        // become unrecoverable on the next Run. Export/email still send the
        // visible subset so the file honors the user's selection.
        //
        // The one non-empty case is the opt-in optional date column, which
        // still sends the *full* known set plus that one — never a subset.
        reportKeys: reportKeys,
        isCancelled: _cancellationFor(epoch),
      );
      if (_disposed || epoch != _runEpoch) return;
      _applySuccessfulPreview(rawPreview, plainRun: reportKeys.isEmpty);
      _activePollingHash = null;
      notifyListeners();
      if (_wantsRowIds && !reportKeys.contains(definition.rowIdKey)) {
        unawaited(_fetchRowIds(epoch));
      }
      if (_compare) unawaited(_runCompare());
    } on ReportError catch (e) {
      if (_disposed || epoch != _runEpoch) return;
      if (e.kind == ReportErrorKind.cancelled) {
        // Cancelled: restore previous preview if any, else go back to idle.
        _run = lastGood == null
            ? ReportRunState.idle()
            : ReportRunState.ready(lastGood);
        notifyListeners();
        return;
      }
      _activePollingHash = e.pollingHash;
      _run = ReportRunState.error(e, lastGood: lastGood);
      notifyListeners();
    } catch (e, st) {
      if (_disposed || epoch != _runEpoch) return;
      _log.warning('Unhandled report run failure', e, st);
      _run = ReportRunState.error(
        const ReportError(kind: ReportErrorKind.unknown),
        lastGood: lastGood,
      );
      notifyListeners();
    }
  }

  /// Fetch a file-only report's file and read it into [document].
  ///
  /// The same request the Export menu's "full report" makes, with nothing
  /// that would change the file's shape: no template (that asks for a PDF),
  /// no column list, no grouping.
  Future<void> _runDocument({String? resumeHash}) async {
    final epoch = ++_runEpoch;
    _run = ReportRunState.loading();
    _activePollingHash = null;
    notifyListeners();
    final payload = _payload;
    try {
      if (!_companyCurrencyResolved) {
        await _resolveCompanyCurrency();
        if (_disposed || epoch != _runEpoch) return;
      }
      final result = resumeHash != null
          ? await repo.continueExport(
              hash: resumeHash,
              isCancelled: _cancellationFor(epoch),
            )
          : await repo.runExport(
              reportIdentifier: _reportIdentifier,
              endpoint: definition.endpoint,
              payload: payload.copyWith(templateId: () => null),
              isCancelled: _cancellationFor(epoch),
            );
      if (_disposed || epoch != _runEpoch) return;
      _document = result.format == ReportExportFormat.csv
          ? parseReportDocument(
              utf8.decode(result.bytes, allowMalformed: true),
              numberStyleFor: _numberStyleForCode,
              defaultStyle: _numberStyle,
            )
          : null;
      _documentUnreadable = _document == null;
      _lastRunPayload = payload;
      _lastRunIncludeDateColumn = _includeDateColumn;
      _resultFetchedAt = _now();
      _run = ReportRunState.idle();
      notifyListeners();
    } on ReportError catch (e) {
      if (_disposed || epoch != _runEpoch) return;
      if (e.kind == ReportErrorKind.cancelled) {
        _run = ReportRunState.idle();
        notifyListeners();
        return;
      }
      _activePollingHash = e.pollingHash;
      // Emailed instead of returned: asking again is another email. Only
      // the reader pressing refresh, or a changed request, asks again.
      if (e.kind == ReportErrorKind.emailedInstead) _emailedFor = payload;
      // The document on screen, if any, stays: `_document` is not touched.
      _run = ReportRunState.error(e);
      notifyListeners();
    } catch (e, st) {
      if (_disposed || epoch != _runEpoch) return;
      _log.warning('Unhandled report document failure', e, st);
      _run = ReportRunState.error(
        const ReportError(kind: ReportErrorKind.unknown),
      );
      notifyListeners();
    }
  }

  /// How the currency with ISO [code] writes its numbers — a per-currency
  /// table in a report file is in that currency's own notation.
  FormattedNumberStyle? _numberStyleForCode(String code) {
    for (final currency in statics.currencies.values) {
      if (currency.code.toUpperCase() == code) {
        return FormattedNumberStyle(
          thousandSeparator: currency.thousandSeparator,
          decimalSeparator: currency.decimalSeparator,
          precision: currency.precision,
        );
      }
    }
    return null;
  }

  /// Everything that must happen when a preview lands, whichever request
  /// produced it.
  ///
  /// It exists because [keepWaiting] used to do a shorter version of this by
  /// hand and silently drifted: a report that timed out and was resumed came
  /// back with no synthetic `stock_value` column, an unresolved `"texts."`
  /// header on the optional date column, that column fetched but invisible,
  /// no refreshed column set, a stale `group`/`sortField`, and `isParamDirty`
  /// stuck true so Run read "Run to refresh" over a current preview. Six
  /// divergences, none of them visible at either call site.
  ///
  /// [plainRun] is whether the request sent no `report_keys` — the one kind
  /// of answer that describes the server's current column set rather than
  /// echoing a list (see [_serverColumnsLearnedAt]). A continuation does not
  /// know what its original request sent, so it does not claim to be one.
  void _applySuccessfulPreview(
    ReportPreview rawPreview, {
    bool plainRun = false,
    DateTime? fetchedAt,
  }) {
    // Inject the synthetic Product-report `stock_value` column, and relabel
    // the optional date column, before either seeds the visible set below.
    final preview = _augmentPreview(rawPreview);
    _lastRunPayload = _payload;
    _lastRunIncludeDateColumn = _includeDateColumn;
    _run = ReportRunState.ready(preview);
    _serverColumnIds = List.unmodifiable(
      preview.columns.map((c) => c.identifier),
    );
    if (plainRun) _serverColumnsLearnedAt = _now().millisecondsSinceEpoch;
    _resultFetchedAt = fetchedAt ?? _now();
    if (_visibleColumnIds.isEmpty) {
      // First run of this report: show its curated columns, in their
      // curated order (see `ReportDefinition.defaultColumnIds`) — or, where
      // it has none or the server returned none of them, everything.
      final returned = preview.columns.map((c) => c.identifier).toSet();
      final curated = [
        for (final id in definition.defaultColumnIds)
          if (returned.contains(id)) id,
      ];
      if (curated.isEmpty) {
        _visibleColumnIds = returned;
      } else {
        _visibleColumnIds = Set.unmodifiable(curated);
        if (_columnOrder.isEmpty) _columnOrder = List.unmodifiable(curated);
      }
    } else {
      // Hydrated/customized set: keep it but drop columns the report no
      // longer returns and surface any new server columns.
      _reconcileWithColumns(preview);
    }
    // `_reconcileWithColumns` deliberately never auto-shows a new server
    // column ("don't un-hide what the user hid"), but the optional date
    // column is one the user just asked for by name — without this it
    // arrives fetched and invisible, and the switch appears to do nothing.
    _showOptionalDateColumn(preview);
    // A grouping restored before its columns were known gets its ranking
    // now that there is a figure to rank by.
    _syncRanking();
    _invalidateMemo();
  }

  // ─── Running itself ───

  /// Whether a run may be started right now: online, and not forbidden.
  bool get _mayRun => _isOnline && (canRun?.call() ?? true);

  /// Whether the result on screen is too old to stand without a refresh.
  bool get _resultIsStale {
    final at = _resultFetchedAt;
    if (at == null) return true;
    return _now().difference(at) > freshFor;
  }

  /// After a change that alters the rows: run again, once the reader has
  /// stopped changing things. No-op unless [autoRun].
  void _scheduleAutoRun() {
    if (!autoRun || _disposed) return;
    _autoRunTimer?.cancel();
    _autoRunTimer = Timer(autoRunDebounce, () {
      if (_disposed) return;
      unawaited(_showOrRun());
    });
  }

  /// Put this report's result on screen: the one remembered for exactly
  /// this request if there is one — at once, before the server is asked
  /// anything — and then a fresh one if that was stale or missing.
  ///
  /// The remembered result is what makes a report open instantly and work
  /// with no connection; the freshness check is what stops opening the same
  /// report twice in a minute from costing two server jobs.
  Future<void> _showOrRun() async {
    if (_disposed || !definition.showsOnScreen) return;
    if (!_hydrated) await _hydration;
    if (!definition.supportsPreview) {
      // A document: nothing kept on disk to show first, so it is simply
      // fetched when there is none, or the one on screen is for another
      // request or has gone stale.
      if (_run.isLoading) return;
      if (hasResultForRequest && !_resultIsStale) {
        _autoRunOwed = false;
        return;
      }
      if (_emailedFor == _payload) return;
      if (!_mayRun) {
        _autoRunOwed = true;
        return;
      }
      _autoRunOwed = false;
      await runReport();
      return;
    }
    final report = _reportIdentifier;
    final payload = _payload;
    final cid = companyId;
    // Nothing on screen for this request yet: look for what it returned last
    // time. (A result already on screen for it is at least as new.)
    if (cid != null && (isParamDirty || _run.preview == null)) {
      if (!_companyCurrencyResolved) await _resolveCompanyCurrency();
      final hit = await repo.cachedPreview(
        companyId: cid,
        reportIdentifier: report,
        payload: payload,
        numberStyle: _numberStyle,
      );
      if (_disposed || report != _reportIdentifier || payload != _payload) {
        return;
      }
      // A run started while the disk was being read wins.
      if (hit != null && !_run.isLoading) {
        _applySuccessfulPreview(hit.preview, fetchedAt: hit.fetchedAt);
        notifyListeners();
      }
    }
    if (_run.isLoading) return;
    if (!isParamDirty && !_resultIsStale) {
      _autoRunOwed = false;
      // Shown from disk and fresh enough to stand: the comparison is not
      // kept there, so it is fetched alone.
      if (_compare && _comparePreview == null && _run.preview != null) {
        unawaited(_runCompare());
      }
      return;
    }
    if (!_mayRun) {
      // Made as soon as it can be — see [_onOnlineChanged] and [retryOwed].
      _autoRunOwed = true;
      return;
    }
    _autoRunOwed = false;
    await runReport();
  }

  void _onOnlineChanged(bool online) {
    if (online == _isOnline || _disposed) return;
    _isOnline = online;
    notifyListeners();
    if (online) retryOwed();
  }

  /// Make the run [autoRun] could not make earlier, if it still owes one —
  /// called when the device comes back online, and by the screen when
  /// whatever [canRun] guards has changed.
  void retryOwed() {
    if (!_autoRunOwed || !autoRun || _disposed) return;
    unawaited(_showOrRun());
  }

  /// Re-poll the in-flight hash for another budget. Only valid when the
  /// last error was a timeout; the repository surfaces a `pollingHash` on
  /// that error specifically so we can pick up where we left off.
  Future<void> keepWaiting() async {
    final hash = _activePollingHash;
    if (hash == null) return;
    if (!definition.supportsPreview) {
      // A document's job is an export: it is polled where exports are.
      await _runDocument(resumeHash: hash);
      return;
    }
    final epoch = ++_runEpoch;
    final lastGood = _run.preview;
    _run = ReportRunState.loading(previousPreview: lastGood);
    notifyListeners();
    try {
      final preview = await repo.continuePreview(
        hash: hash,
        numberStyle: _numberStyle,
        isCancelled: _cancellationFor(epoch),
      );
      if (_disposed || epoch != _runEpoch) return;
      _applySuccessfulPreview(preview);
      _activePollingHash = null;
      notifyListeners();
      if (_compare) unawaited(_runCompare());
    } on ReportError catch (e) {
      if (_disposed || epoch != _runEpoch) return;
      _activePollingHash = e.pollingHash;
      _run = ReportRunState.error(e, lastGood: lastGood);
      notifyListeners();
    }
  }

  /// Bump the epoch (stranding the in-flight future) and restore the
  /// previous preview if one existed. Caller surfaces a "Run cancelled"
  /// snackbar.
  void cancelRun() {
    if (!_run.isLoading) return;
    _runEpoch++;
    final lastGood = _run.preview;
    _run = lastGood == null
        ? ReportRunState.idle()
        : ReportRunState.ready(lastGood);
    notifyListeners();
  }

  // ─── Export / email in-flight state ───
  bool _isExporting = false;
  bool get isExporting => _isExporting;
  bool _isEmailing = false;
  bool get isEmailing => _isEmailing;

  int _exportEpoch = 0;
  String? _activeExportHash;

  /// Timeout error from the last export, if any — drives a "Keep waiting?"
  /// affordance on the export action (mirrors the preview timeout flow).
  ReportError? _exportError;
  ReportError? get exportError => _exportError;
  bool get exportCanKeepWaiting =>
      _exportError?.kind == ReportErrorKind.timeout &&
      _activeExportHash != null;

  /// Run the queued export. Returns the binary result on success, or null on
  /// failure (caller shows a snackbar from [exportError]). Guards against
  /// double-submit via [isExporting]; cancellable via the epoch like
  /// [runReport].
  ///
  /// [templateId] renders the report through one of the company's template
  /// designs and comes back as a PDF. It is a choice about this one file,
  /// so it is passed here and never kept on the report.
  Future<ReportExportResult?> runExport({String? templateId}) async {
    if (_isExporting) return null;
    final epoch = ++_exportEpoch;
    _isExporting = true;
    _exportError = null;
    _activeExportHash = null;
    notifyListeners();
    try {
      final result = await repo.runExport(
        reportIdentifier: _reportIdentifier,
        endpoint: definition.endpoint,
        payload: templateId == null
            ? _payload.copyWith(templateId: () => null)
            : _payload.copyWith(templateId: () => templateId),
        reportKeys: serverReportKeys(),
        groupBy: serverGroupBy,
        isCancelled: () => _disposed || _exportEpoch != epoch,
      );
      if (_disposed || epoch != _exportEpoch) return null;
      return result;
    } on ReportError catch (e) {
      if (_disposed || epoch != _exportEpoch) return null;
      if (e.kind == ReportErrorKind.cancelled) return null;
      _activeExportHash = e.pollingHash;
      _exportError = e;
      return null;
    } finally {
      if (!_disposed && epoch == _exportEpoch) {
        _isExporting = false;
        notifyListeners();
      }
    }
  }

  /// Re-poll an in-flight export hash for another budget. Only valid after
  /// an export timeout (the repo surfaces a `pollingHash` then).
  Future<ReportExportResult?> keepWaitingExport() async {
    final hash = _activeExportHash;
    if (hash == null || _isExporting) return null;
    final epoch = ++_exportEpoch;
    _isExporting = true;
    _exportError = null;
    notifyListeners();
    try {
      final result = await repo.continueExport(
        hash: hash,
        isCancelled: () => _disposed || _exportEpoch != epoch,
      );
      if (_disposed || epoch != _exportEpoch) return null;
      return result;
    } on ReportError catch (e) {
      if (_disposed || epoch != _exportEpoch) return null;
      _activeExportHash = e.pollingHash;
      _exportError = e;
      return null;
    } finally {
      if (!_disposed && epoch == _exportEpoch) {
        _isExporting = false;
        notifyListeners();
      }
    }
  }

  /// Cancel an in-flight export (strands the poll via the epoch).
  void cancelExport() {
    if (!_isExporting) return;
    _exportEpoch++;
    _isExporting = false;
    notifyListeners();
  }

  /// Email-flow: POSTs `send_email: true` and returns. Email is independent
  /// of the preview/Run state — failures don't taint `_run` (the on-screen
  /// table doesn't owe the user an error there). Callers surface their own
  /// snackbar via the rethrown [ReportError]. Guards double-submit via
  /// [isEmailing].
  ///
  /// [attachPdfs] and [attachDocuments] add a zip of each document's PDF, or
  /// of the files uploaded to them, to the email. Choices about this one
  /// send, so they are passed here and never kept on the report — a switch
  /// remembered from last month would zip every PDF into an email nobody
  /// asked that of.
  Future<void> sendEmail({
    bool attachPdfs = false,
    bool attachDocuments = false,
  }) async {
    if (_isEmailing) return;
    _isEmailing = true;
    notifyListeners();
    try {
      await repo.sendEmail(
        reportIdentifier: _reportIdentifier,
        endpoint: definition.endpoint,
        payload: _payload.copyWith(
          templateId: () => null,
          pdfEmailAttachment: attachPdfs,
          documentEmailAttachment: attachDocuments,
        ),
        reportKeys: serverReportKeys(),
        groupBy: serverGroupBy,
      );
    } finally {
      if (!_disposed) {
        _isEmailing = false;
        notifyListeners();
      }
    }
  }

  // ─── Optional date column (opt-in, preview-only) ───

  /// `report_keys` for the preview request. Empty — the server's own default
  /// set — unless there is a column to add to it: the optional date column
  /// the user opted into, or the row id ([fetchRowIds]). Then it is the full
  /// **known** set plus those, never a subset.
  ///
  /// The live preview wins over [_serverColumnIds] so the set is as fresh
  /// as the last answer; with neither we fall back to a plain run rather
  /// than pinning the report to a single column (`prepareForValidation`
  /// would happily accept a one-element list).
  List<String> _previewReportKeys() {
    final dateColumn = definition.optionalDateColumnId;
    final idColumn = _wantsRowIds ? definition.rowIdKey : null;
    final extras = [
      if (_includeDateColumn && dateColumn != null) dateColumn,
      ?idColumn,
    ];
    if (extras.isEmpty) return const [];
    // A pinned set goes stale: an echo of last week's list will never show a
    // column the server added since. Only the id pins by default (the date
    // column is the user's own, deliberate pin), so only it expires.
    final onlyTheId = extras.length == 1 && extras.first == idColumn;
    if (onlyTheId && _serverColumnsAreStale) return const [];
    final known =
        _run.preview?.columns.map((c) => c.identifier).toList() ??
        _serverColumnIds;
    if (known.isEmpty) return const [];
    // Strip-then-append, never "skip if already present": after the first
    // augmented run `known` *contains* the extra (we asked for it), so a
    // `contains` guard would send `[]` on the very next run and the column
    // would vanish again — a bug invisible until the second Run. Stripping
    // also drops the date column once the user has switched it back off.
    final drop = {_kStockValueId, ?dateColumn, ?idColumn};
    return [
      for (final id in known)
        if (!drop.contains(id)) id,
      ...extras,
    ];
  }

  bool get _wantsRowIds => fetchRowIds && definition.rowIdKey != null;

  bool get _serverColumnsAreStale {
    final age = _now().millisecondsSinceEpoch - _serverColumnsLearnedAt;
    return age > _kServerColumnsMaxAge.inMilliseconds;
  }

  /// The second half of a first run: the same report again, now that its
  /// column set is known, with the row id appended.
  ///
  /// Silent in both directions. The rows are already on screen and do not
  /// change — they gain an id — so the run state stays `ready` rather than
  /// dimming the table for a refresh nobody asked for; and a failure is
  /// swallowed, because rows that are not links are exactly what the user
  /// had a moment ago. It rides the epoch of the run that started it, so a
  /// newer run or a report switch strands it like any other.
  Future<void> _fetchRowIds(int epoch) async {
    final reportKeys = _previewReportKeys();
    if (!reportKeys.contains(definition.rowIdKey)) return;
    try {
      final rawPreview = await repo.runPreview(
        reportIdentifier: _reportIdentifier,
        endpoint: definition.endpoint,
        payload: _payload,
        numberStyle: _numberStyle,
        companyId: companyId,
        reportKeys: reportKeys,
        isCancelled: _cancellationFor(epoch),
      );
      if (_disposed || epoch != _runEpoch) return;
      _applySuccessfulPreview(rawPreview);
      notifyListeners();
    } on ReportError catch (e) {
      if (e.kind != ReportErrorKind.cancelled) {
        _log.fine('Row ids not fetched: $e');
      }
    } catch (e, st) {
      _log.warning('Row-id fetch failed', e, st);
    }
  }

  void setIncludeDateColumn(bool value) {
    if (_includeDateColumn == value) return;
    _userTouched = true;
    _includeDateColumn = value;
    // Turning it off strands a grouping on a column the next run won't
    // return. `_reconcileWithColumns` would clear it, but only after the
    // fetch — until then the panel offers a grouping that is already gone.
    if (!value && _group != null && _group == definition.optionalDateColumnId) {
      _group = null;
      _subgroup = null;
      _periodColumn = null;
      _selectedGroup = null;
      _invalidateMemo();
    }
    // Same for a period split on it.
    if (!value &&
        _periodColumn != null &&
        _periodColumn == definition.optionalDateColumnId) {
      _periodColumn = null;
      _selectedGroup = null;
      _invalidateMemo();
    }
    notifyListeners();
    _scheduleAutoRun();
  }

  /// Make the opted-in column visible the first time it arrives.
  void _showOptionalDateColumn(ReportPreview preview) {
    final extra = definition.optionalDateColumnId;
    if (!_includeDateColumn || extra == null) return;
    if (_visibleColumnIds.contains(extra)) return;
    if (!preview.columns.any((c) => c.identifier == extra)) return;
    _visibleColumnIds = Set.unmodifiable({..._visibleColumnIds, extra});
  }

  // ─── Product-report inventory valuation (synthetic, preview-only) ───

  static const String _kStockValueId = 'stock_value';

  /// Visible report keys safe to send to the server (export / email / schedule):
  /// the visible selection minus any column the server can't render into a
  /// file — the client-computed `stock_value`, and the optional date column,
  /// whose value arrives as a raw epoch int the CSV has no way to format.
  /// Pass [ordered] to honor the user's column order — the schedule flow
  /// needs it; export/email don't.
  List<String> serverReportKeys({bool ordered = false}) {
    final base = ordered && _columnOrder.isNotEmpty
        ? _columnOrder.where(_visibleColumnIds.contains)
        : _visibleColumnIds;
    final extra = definition.optionalDateColumnId;
    return base.where((k) => k != _kStockValueId && k != extra).toList();
  }

  /// `group_by` safe to send to the server, for the same three flows.
  ///
  /// Stripping the key out of [serverReportKeys] is **not** enough on its
  /// own: `GenericReportRequest::prepareForValidation` does
  /// `array_unshift($report_keys, $group_by)` for any `group_by` not
  /// already in the list, so the server would put the column straight back.
  /// (`BaseExport::groupRows` also groups on the *exact* value with no date
  /// bucketing, so grouping a file by a per-second timestamp would emit one
  /// group per row anyway.)
  ///
  /// [periodColumn] is never sent: the server groups on one column only, so
  /// a file downloaded from a "user × month" view is grouped by user.
  String? get serverGroupBy =>
      _group == definition.optionalDateColumnId ? null : _group;

  /// Inject the synthetic `stock_value` (on-hand stock × price) money column
  /// into the Product report so the totals card shows the total inventory value
  /// with zero column setup. Other reports pass through unchanged. The column is
  /// preview-only — [_serverReportKeys] strips it from export/email, so it never
  /// reaches the server (and so isn't in CSV/PDF output).
  ReportPreview _augmentPreview(ReportPreview preview) {
    // The id comes out first — it is a column the user never sees, and
    // everything after it works on the columns that are left. Then currency:
    // the synthetic stock value below is an amount of the row, and is
    // totalled under the row's currency like every other.
    return _relabelOptionalDateColumn(
      _augmentStockValue(
        _assignRowCurrencies(
          withRowGrain(
            withRowRecords(
              withTextColumns(preview, definition.textColumnIds),
              definition,
            ),
            definition,
          ),
        ),
      ),
    );
  }

  // ─── Company currency (number format + the default row currency) ───

  Future<void> _resolveCompanyCurrency() async {
    final load = companyCurrencyId;
    if (_companyCurrencyResolved || load == null) return;
    try {
      _companyCurrencyId = await load();
      _companyCurrencyResolved = true;
    } catch (e, st) {
      // Not fatal, and not remembered: the run goes ahead on the
      // format-agnostic parse and the next one asks again.
      _log.warning('Could not resolve the company currency', e, st);
    }
  }

  /// How the server writes numbers for this company, or null while the
  /// company currency is unknown. See [companyCurrencyId].
  FormattedNumberStyle? get _numberStyle {
    final currency = statics.currencies[_companyCurrencyId];
    if (currency == null) return null;
    return FormattedNumberStyle(
      thousandSeparator: currency.thousandSeparator,
      decimalSeparator: currency.decimalSeparator,
      precision: currency.precision,
    );
  }

  /// Stamp each row with the currency its amounts are in — see
  /// [withRowCurrencies].
  ReportPreview _assignRowCurrencies(ReportPreview preview) {
    final currencies = statics.currencies;
    return withRowCurrencies(
      preview,
      currencyIdByCode: {
        for (final c in currencies.values)
          if (c.code.isNotEmpty) c.code.toUpperCase(): c.id,
      },
      fallbackCurrencyId: currencies.containsKey(_companyCurrencyId)
          ? _companyCurrencyId
          : null,
    );
  }

  /// Replace the optional date column's header. The server resolves it with
  /// `ctrans('texts.')` — the literal `"texts."` — because the column is in
  /// none of its report-key maps.
  ///
  /// Gated on the label actually being *unresolved* rather than on the
  /// identifier alone: should the server ever adopt the column properly, its
  /// own `ctrans` label is in the company's locale and should win.
  ReportPreview _relabelOptionalDateColumn(ReportPreview preview) {
    final extra = definition.optionalDateColumnId;
    if (extra == null) return preview;
    var touched = false;
    final columns = [
      for (final c in preview.columns)
        if (c.identifier == extra && _looksUnresolved(c.displayLabel))
          () {
            touched = true;
            return ReportColumn(
              identifier: c.identifier,
              displayLabel: optionalDateColumnLabel,
              type: c.type,
            );
          }()
        else
          c,
    ];
    if (!touched) return preview;
    return ReportPreview(columns: columns, rows: preview.rows);
  }

  static bool _looksUnresolved(String label) {
    final t = label.trim();
    return t.isEmpty || t.startsWith('texts.');
  }

  ReportPreview _augmentStockValue(ReportPreview preview) {
    if (_reportIdentifier != 'product') return preview;
    if (preview.columns.any((c) => c.identifier == _kStockValueId)) {
      return preview; // defensive: already injected
    }
    final priceIdx = preview.columns.indexWhere(
      (c) => _columnTail(c.identifier) == 'price',
    );
    final stockIdx = preview.columns.indexWhere(
      (c) => _columnTail(c.identifier) == 'in_stock_quantity',
    );
    if (priceIdx < 0 || stockIdx < 0) return preview;
    final columns = [
      ...preview.columns,
      ReportColumn(
        identifier: _kStockValueId,
        displayLabel: stockValueLabel,
        type: ReportColumnType.money,
      ),
    ];
    final rows = [
      for (final row in preview.rows)
        ReportRow(
          cells: [...row.cells, _stockValueCell(row, priceIdx, stockIdx)],
        ),
    ];
    return ReportPreview(columns: columns, rows: rows);
  }

  ReportCell _stockValueCell(ReportRow row, int priceIdx, int stockIdx) {
    final price = _numericAt(row, priceIdx);
    final stock = _numericAt(row, stockIdx);
    if (price == null || stock == null) {
      return const ReportNumberCell(isMoney: true);
    }
    // Carry the price cell's currency so the totals card buckets the value
    // under the right currency (empty → company currency, like price/cost).
    final priceCell = row.cells[priceIdx];
    final currencyId = priceCell is ReportNumberCell
        ? priceCell.currencyId
        : null;
    return ReportNumberCell(
      value: stock * price,
      isMoney: true,
      currencyId: currencyId,
    );
  }

  Decimal? _numericAt(ReportRow row, int idx) {
    if (idx < 0 || idx >= row.cells.length) return null;
    final cell = row.cells[idx];
    return cell is ReportNumberCell ? cell.value : null;
  }

  static String _columnTail(String identifier) {
    final id = identifier.toLowerCase();
    return id.contains('.') ? id.split('.').last : id;
  }

  @override
  void dispose() {
    _disposed = true;
    _runEpoch++;
    _exportEpoch++;
    removeListener(_schedulePersist);
    _autoRunTimer?.cancel();
    unawaited(_onlineSubscription?.cancel());
    final hadPending = _persistTimer?.isActive ?? false;
    _persistTimer?.cancel();
    // Flush a pending debounced write so a company-switch / app-close
    // doesn't drop the last edit. Targets this VM's captured companyId
    // (set at construction), so it can't cross-write another company.
    if (hadPending) unawaited(_persist());
    super.dispose();
  }
}
