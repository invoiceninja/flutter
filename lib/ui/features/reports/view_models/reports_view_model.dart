import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/db/dao/nav_state_dao.dart';
import 'package:admin/data/models/domain/report_definition.dart';
import 'package:admin/data/models/domain/report_payload.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/reports_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/reports_api.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/report_engine.dart';
import 'package:admin/domain/reports/report_registry.dart';

final _log = Logger('ReportsViewModel');

enum ReportRunStatus { idle, loading, ready, error }

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
    DateTime Function()? now,
    Duration persistDebounce = const Duration(milliseconds: 600),
  }) : _reportIdentifier = initialReport,
       _payload = const ReportPayload(),
       _now = now ?? DateTime.now,
       _persistDebounce = persistDebounce {
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
    // Persist on every state change (debounced, hydration-gated). The
    // debounce coalesces the flurry; snapshot covers only durable fields.
    addListener(_schedulePersist);
  }

  final ReportsRepository repo;
  final StaticsRepository statics;

  /// Local-only restore-on-restart store (no server round-trip). Keyed by
  /// `companyId → 'reports' → snapshot` inside the shared `filters_json`
  /// blob — the exact mechanism list ViewModels use.
  final NavStateDao? navStateDao;
  final String? companyId;
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
  bool get isParamDirty => _payload != _lastRunPayload;

  // ─── Result ───
  ReportRunState _run = ReportRunState.idle();
  ReportRunState get run => _run;

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

  String? _sortField;
  bool _sortAscending = true;
  String? get sortField => _sortField;
  bool get sortAscending => _sortAscending;

  String? _group;
  String? get group => _group;
  ReportSubgroup? _subgroup;
  ReportSubgroup? get subgroup => _subgroup;
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

  /// Active filter count for the toolbar badge. Excludes `date_range`
  /// and `date_key` (they have their own toolbar surface) and matches
  /// against the report's `defaultFilterValues`.
  int get activeFilterCount {
    final defaults = definition.defaultFilterValues;
    String defaultStr(String key) => defaults[key]?.toString() ?? '';
    bool defaultBool(String key) => defaults[key] == true;
    var n = 0;
    for (final f in definition.filterFields) {
      bool changed;
      switch (f) {
        case ReportFilterField.dateRange:
        case ReportFilterField.dateColumn:
          continue;
        case ReportFilterField.status:
          changed = (_payload.status ?? '') != defaultStr('status');
        case ReportFilterField.clientsMulti:
          changed = (_payload.clients ?? '') != defaultStr('clients');
        case ReportFilterField.clientSingle:
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
        case ReportFilterField.includeTax:
          changed = _payload.includeTax != defaultBool('include_tax');
        case ReportFilterField.isExpenseBilled:
          changed =
              _payload.isExpenseBilled != defaultBool('is_expense_billed');
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
      sortField: _sortField,
      sortAscending: _sortAscending,
      group: _group,
      subgroup: _subgroup,
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

  Map<String, dynamic> _snapshot() => <String, dynamic>{
    'report': _reportIdentifier,
    'payload': _payloadToMap(_payload),
    'visibleColumns': _visibleColumnIds.toList(),
    if (_columnOrder.isNotEmpty) 'columnOrder': _columnOrder,
    'columnFilters': _columnFilters,
    if (_group != null) 'group': _group,
    if (_subgroup != null) 'subgroup': _subgroup!.name,
    if (_sortField != null) 'sortField': _sortField,
    'sortAscending': _sortAscending,
    'panelCollapsed': _panelCollapsed,
    'chartVisible': _chartVisible,
  };

  void _applySnapshot(Map<String, dynamic> s) {
    final report = s['report'];
    if (report is String &&
        kReportDefinitions.any((d) => d.identifier == report)) {
      _reportIdentifier = report;
    }
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
    final sf = s['sortField'];
    if (sf is String) _sortField = sf;
    final sa = s['sortAscending'];
    if (sa is bool) _sortAscending = sa;
    final pc = s['panelCollapsed'];
    if (pc is bool) _panelCollapsed = pc;
    final cv = s['chartVisible'];
    if (cv is bool) _chartVisible = cv;
  }

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
    'documentEmailAttachment': p.documentEmailAttachment,
    'pdfEmailAttachment': p.pdfEmailAttachment,
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
      documentEmailAttachment: m['documentEmailAttachment'] == true,
      pdfEmailAttachment: m['pdfEmailAttachment'] == true,
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
    }
    if (_sortField != null && !ids.contains(_sortField)) {
      _sortField = null;
    }
  }

  // ─── Mutations ───

  void setReport(String identifier) {
    if (identifier == _reportIdentifier) return;
    _userTouched = true;
    _reportIdentifier = identifier;
    // Reset payload-side state to defaults for the new report, but keep the
    // local-only state (visible columns) cleared so the new report's
    // server-returned columns are all initially visible.
    _payload = const ReportPayload();
    _visibleColumnIds = const {};
    _columnOrder = const [];
    _columnFilters = const {};
    _sortField = null;
    _group = null;
    _subgroup = null;
    _selectedGroup = null;
    _chartColumn = null;
    _run = ReportRunState.idle();
    _invalidateMemo();
    notifyListeners();
  }

  void setPayload(ReportPayload payload) {
    if (payload == _payload) return;
    _userTouched = true;
    _payload = payload;
    notifyListeners();
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
    notifyListeners();
  }

  /// Click a column header to (re)sort. First click → ascending; second
  /// click on the same column → descending; subsequent clicks toggle.
  void toggleSort(String columnId) {
    if (_sortField == columnId) {
      _sortAscending = !_sortAscending;
    } else {
      _sortField = columnId;
      _sortAscending = true;
    }
    _invalidateMemo();
    notifyListeners();
  }

  void setGroup(String? columnId, {ReportSubgroup? subgroup}) {
    _group = columnId;
    _subgroup = columnId == null ? null : (subgroup ?? _subgroup);
    _selectedGroup = null;
    _invalidateMemo();
    notifyListeners();
  }

  void setSubgroup(ReportSubgroup? sg) {
    _subgroup = sg;
    _invalidateMemo();
    notifyListeners();
  }

  void setSelectedGroup(String? key) {
    _selectedGroup = key;
    _invalidateMemo();
    notifyListeners();
  }

  /// Reset payload filter values (not date range / date column / columns /
  /// sort / group). Keeps the loaded preview so the user doesn't have to
  /// re-Run just to clear filters.
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
    _group = null;
    _subgroup = null;
    _selectedGroup = null;
    _chartColumn = null;
    _chartVisible = true;
    _invalidateMemo();
    notifyListeners();
  }

  // ─── Server actions ───

  Future<void> runReport() async {
    // Don't let a cold Run race ahead of restore — a persisted column set
    // would be clobbered by the "empty → server columns" default below.
    if (!_hydrated) await _hydration;
    if (_disposed) return;
    final epoch = ++_runEpoch;
    final lastGood = _run.preview;
    _run = ReportRunState.loading(previousPreview: lastGood);
    _activePollingHash = null;
    notifyListeners();

    try {
      final rawPreview = await repo.runPreview(
        reportIdentifier: _reportIdentifier,
        endpoint: definition.endpoint,
        payload: _payload,
        // Preview always requests the server's full default column set (empty
        // report_keys) — column visibility is a purely local concern applied
        // by the engine. Sending the visible subset here would narrow the
        // server response, and since the column picker is sourced from
        // `preview.columns`, a hidden column would vanish from the picker and
        // become unrecoverable on the next Run. Export/email still send the
        // visible subset so the file honors the user's selection.
        reportKeys: const [],
        isCancelled: _cancellationFor(epoch),
      );
      if (_disposed || epoch != _runEpoch) return;
      // Inject the synthetic Product-report `stock_value` column before it
      // seeds the default visible set / column picker below.
      final preview = _augmentPreview(rawPreview);
      _lastRunPayload = _payload;
      _run = ReportRunState.ready(preview);
      _activePollingHash = null;
      if (_visibleColumnIds.isEmpty) {
        // First Run on this report: default visible columns to the
        // server's returned set so the column picker has a baseline.
        _visibleColumnIds = preview.columns.map((c) => c.identifier).toSet();
      } else {
        // Hydrated/customized set: keep it but drop columns the report no
        // longer returns and surface any new server columns.
        _reconcileWithColumns(preview);
      }
      _invalidateMemo();
      notifyListeners();
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

  /// Re-poll the in-flight hash for another budget. Only valid when the
  /// last error was a timeout; the repository surfaces a `pollingHash` on
  /// that error specifically so we can pick up where we left off.
  Future<void> keepWaiting() async {
    final hash = _activePollingHash;
    if (hash == null) return;
    final epoch = ++_runEpoch;
    final lastGood = _run.preview;
    _run = ReportRunState.loading(previousPreview: lastGood);
    notifyListeners();
    try {
      final preview = await repo.continuePreview(
        hash: hash,
        isCancelled: _cancellationFor(epoch),
      );
      if (_disposed || epoch != _runEpoch) return;
      _lastRunPayload = _payload;
      _run = ReportRunState.ready(preview);
      _activePollingHash = null;
      _invalidateMemo();
      notifyListeners();
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
  ReportExportFormat? _activeExportFormat;

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
  Future<ReportExportResult?> runExport(ReportExportFormat format) async {
    if (_isExporting) return null;
    final epoch = ++_exportEpoch;
    _isExporting = true;
    _exportError = null;
    _activeExportHash = null;
    _activeExportFormat = format;
    notifyListeners();
    try {
      final result = await repo.runExport(
        reportIdentifier: _reportIdentifier,
        endpoint: definition.endpoint,
        payload: _payload,
        format: format,
        reportKeys: serverReportKeys(),
        groupBy: _group,
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
    final format = _activeExportFormat;
    if (hash == null || format == null || _isExporting) return null;
    final epoch = ++_exportEpoch;
    _isExporting = true;
    _exportError = null;
    notifyListeners();
    try {
      final result = await repo.continueExport(
        hash: hash,
        format: format,
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
  Future<void> sendEmail() async {
    if (_isEmailing) return;
    _isEmailing = true;
    notifyListeners();
    try {
      await repo.sendEmail(
        reportIdentifier: _reportIdentifier,
        endpoint: definition.endpoint,
        payload: _payload,
        reportKeys: serverReportKeys(),
        groupBy: _group,
      );
    } finally {
      if (!_disposed) {
        _isEmailing = false;
        notifyListeners();
      }
    }
  }

  // ─── Product-report inventory valuation (synthetic, preview-only) ───

  static const String _kStockValueId = 'stock_value';

  /// Visible report keys safe to send to the server (export / email / schedule):
  /// the visible selection minus any synthetic, client-computed column
  /// (`stock_value`) the server doesn't know. Pass [ordered] to honor the
  /// user's column order — the schedule flow needs it; export/email don't.
  List<String> serverReportKeys({bool ordered = false}) {
    final base = ordered && _columnOrder.isNotEmpty
        ? _columnOrder.where(_visibleColumnIds.contains)
        : _visibleColumnIds;
    return base.where((k) => k != _kStockValueId).toList();
  }

  /// Inject the synthetic `stock_value` (on-hand stock × price) money column
  /// into the Product report so the totals card shows the total inventory value
  /// with zero column setup. Other reports pass through unchanged. The column is
  /// preview-only — [_serverReportKeys] strips it from export/email, so it never
  /// reaches the server (and so isn't in CSV/PDF output).
  ReportPreview _augmentPreview(ReportPreview preview) {
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
    final hadPending = _persistTimer?.isActive ?? false;
    _persistTimer?.cancel();
    // Flush a pending debounced write so a company-switch / app-close
    // doesn't drop the last edit. Targets this VM's captured companyId
    // (set at construction), so it can't cross-write another company.
    if (hadPending) unawaited(_persist());
    super.dispose();
  }
}
