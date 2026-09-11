import 'package:collection/collection.dart';
import 'package:decimal/decimal.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/utils/date_ranges.dart';

final _log = Logger('ReportEngine');

/// Render ceiling for a gap-filled chart timeline. Mirrors the dashboard's
/// own `_maxRenderBuckets` (`chart_series_math.dart`) — past this many
/// points fl_chart is being handed more spots than the axis can show.
const int kMaxReportChartBuckets = 750;

/// How a date-typed group column buckets its values when grouped.
enum ReportSubgroup { day, week, month, quarter, year }

extension ReportSubgroupLabel on ReportSubgroup {
  /// Localization key for this granularity. The five values happen to match
  /// the enum's own names, but they are looked up through `context.tr`, so
  /// `report_registry_date_keys_test` asserts each one resolves in the bundle —
  /// a variable key is invisible to `no_unsubstituted_placeholders_test`.
  String get labelKey {
    switch (this) {
      case ReportSubgroup.day:
        return 'day';
      case ReportSubgroup.week:
        return 'week';
      case ReportSubgroup.month:
        return 'month';
      case ReportSubgroup.quarter:
        return 'quarter';
      case ReportSubgroup.year:
        return 'year';
    }
  }
}

/// All user-mutable knobs the engine reads. Held on the VM; passed in by
/// value so the engine itself stays pure (no Provider / context reach).
class ReportUiState {
  const ReportUiState({
    this.visibleColumnIds = const {},
    this.columnOrder = const [],
    this.columnFilters = const {},
    this.sortField,
    this.sortAscending = true,
    this.group,
    this.subgroup,
    this.selectedGroup,
    this.convertCurrency = false,
  });

  /// Set of column identifiers visible in the table. When empty the engine
  /// shows every column (matches default behavior of a freshly-loaded
  /// preview before the user touches the column picker).
  final Set<String> visibleColumnIds;

  /// User-chosen column display order (identifiers). Columns not listed
  /// fall back to the preview's server order, appended after the ordered
  /// ones. Empty = pure server order. Note: when grouping is active the
  /// group column is still pinned to index 0 (see [_visibleColumns]); the
  /// user order applies to the remaining columns.
  final List<String> columnOrder;

  /// Per-column filter inputs typed by the user in the table's filter row.
  /// Keyed by column identifier; the value semantics depend on the column
  /// type (substring for strings; "min-max" for numbers; preset key for
  /// dates; age bucket for age; "true"/"false" for bool).
  final Map<String, String> columnFilters;

  final String? sortField;
  final bool sortAscending;

  /// Column identifier the rows are grouped by, or null for no grouping.
  final String? group;

  /// When the group column is a date or dateTime, which bucket to roll up
  /// into. Ignored otherwise.
  final ReportSubgroup? subgroup;

  /// Drill-down: when set, rows are filtered to those belonging to this
  /// group bucket and rendered ungrouped. The breadcrumb chip in the UI
  /// is the only exit affordance — clicking a group row again does NOT
  /// clear it (avoids accidents).
  final String? selectedGroup;

  /// Mirrors `company.settings.convertCurrency`. When true and the engine
  /// has exchange rates for every currency, populates
  /// [ReportView.convertedGrandTotals].
  final bool convertCurrency;

  ReportUiState copyWith({
    Set<String>? visibleColumnIds,
    List<String>? columnOrder,
    Map<String, String>? columnFilters,
    String? Function()? sortField,
    bool? sortAscending,
    String? Function()? group,
    ReportSubgroup? Function()? subgroup,
    String? Function()? selectedGroup,
    bool? convertCurrency,
  }) {
    return ReportUiState(
      visibleColumnIds: visibleColumnIds ?? this.visibleColumnIds,
      columnOrder: columnOrder ?? this.columnOrder,
      columnFilters: columnFilters ?? this.columnFilters,
      sortField: sortField == null ? this.sortField : sortField(),
      sortAscending: sortAscending ?? this.sortAscending,
      group: group == null ? this.group : group(),
      subgroup: subgroup == null ? this.subgroup : subgroup(),
      selectedGroup: selectedGroup == null
          ? this.selectedGroup
          : selectedGroup(),
      convertCurrency: convertCurrency ?? this.convertCurrency,
    );
  }

  // Value-based equality so the engine's memo key (built from
  // `ui.hashCode`) actually hits on identical UI states. Without this,
  // Dart's default identity hash makes every fresh `buildView` call miss
  // the cache and the engine re-computes — invisible to analyze but
  // visible as jank once row counts grow.
  static const _setEq = SetEquality<String>();
  static const _mapEq = MapEquality<String, String>();
  static const _listEq = ListEquality<String>();

  @override
  bool operator ==(Object other) =>
      other is ReportUiState &&
      _setEq.equals(visibleColumnIds, other.visibleColumnIds) &&
      _listEq.equals(columnOrder, other.columnOrder) &&
      _mapEq.equals(columnFilters, other.columnFilters) &&
      sortField == other.sortField &&
      sortAscending == other.sortAscending &&
      group == other.group &&
      subgroup == other.subgroup &&
      selectedGroup == other.selectedGroup &&
      convertCurrency == other.convertCurrency;

  @override
  int get hashCode => Object.hash(
    _setEq.hash(visibleColumnIds),
    _listEq.hash(columnOrder),
    _mapEq.hash(columnFilters),
    sortField,
    sortAscending,
    group,
    subgroup,
    selectedGroup,
    convertCurrency,
  );
}

/// One bucket when the engine is grouping. `key` is the group display value
/// (e.g. "ACME" or "2026-04" for a month subgroup), `rows` is the list of
/// raw rows in that bucket, `numericTotals` is per-numeric-column sum.
class GroupTotals {
  const GroupTotals({
    required this.key,
    required this.rows,
    required this.numericTotals,
  });

  final String key;
  final List<ReportRow> rows;
  final Map<String, Map<String, Decimal>> numericTotals;

  int get count => rows.length;
}

/// Output of one engine [compute] pass — what the table widget renders.
/// Treat as immutable; the engine returns a fresh instance per compute.
class ReportView {
  const ReportView({
    required this.visibleColumns,
    required this.rows,
    required this.groups,
    required this.grandTotalsByCurrency,
    required this.convertedGrandTotals,
    required this.rowCountByCurrency,
    required this.totalRowCount,
    required this.exchangeRatesAvailable,
    required this.cellIndexByColumn,
  });

  /// Columns the table renders, in display order. When grouped, the group
  /// column moves to index 0 (matches v1's `sortedColumns()` behavior).
  final List<ReportColumn> visibleColumns;

  /// Rows after column filters + sort + (when grouped) drill-down. Empty
  /// when [groups] is non-empty (the table renders one row per group
  /// bucket in that case, not raw rows).
  final List<ReportRow> rows;

  /// Per-group buckets when grouping is on. Empty otherwise.
  final List<GroupTotals> groups;

  /// `{columnId: {currencyId: sum}}` for every aggregatable column. Used
  /// by the totals card to show per-currency rollups.
  final Map<String, Map<String, Decimal>> grandTotalsByCurrency;

  /// `{columnId: sum}` converted to the company currency. Null when
  /// `convertCurrency` is off or the engine is missing rates for any
  /// currency that appears in the rows (footnoted in the UI).
  final Map<String, Decimal>? convertedGrandTotals;

  /// `{currencyId: count}` — row counts per currency. Drives the totals
  /// card's per-currency line. Currencies that don't appear in the rows
  /// are absent.
  final Map<String, int> rowCountByCurrency;

  final int totalRowCount;

  /// True when the engine had every exchange rate it needed for converted
  /// totals. Drives the "Convert disabled — exchange rates not yet
  /// loaded" footnote in the totals card.
  final bool exchangeRatesAvailable;

  /// `columnIdentifier → originalCellIndex`. Lets the data table look up
  /// the right cell when [visibleColumns] has been reordered (e.g. the
  /// group column pinned to index 0 when grouped). Without this, the
  /// row-cell lookup `row.cells[visibleIdx]` would point at the wrong
  /// column in the reordered case.
  final Map<String, int> cellIndexByColumn;

  static const empty = ReportView(
    visibleColumns: [],
    rows: [],
    groups: [],
    grandTotalsByCurrency: {},
    convertedGrandTotals: null,
    rowCountByCurrency: {},
    totalRowCount: 0,
    exchangeRatesAvailable: false,
    cellIndexByColumn: {},
  );
}

/// Pure compute over a [ReportPreview] + [ReportUiState]. No I/O, no
/// services, no globals — easy to unit-test and easy to micro-task off the
/// main isolate when the row count gets big.
class ReportEngine {
  const ReportEngine({this.firstMonthOfYear = 1, this.firstDayOfWeek = 0});

  /// Company `first_month_of_year` (1=Jan..12=Dec) — shifts the `year` subgroup
  /// bucket onto the fiscal year. Quarters and months stay calendar-aligned
  /// (matches admin-portal / React).
  final int firstMonthOfYear;

  /// Company `first_day_of_week` (0=Sun..6=Sat) — the start-of-week for the
  /// `week` subgroup bucket (was hardcoded to Monday).
  final int firstDayOfWeek;

  /// Build a fresh [ReportView] from the loaded preview and the current
  /// UI state. Caller is expected to memoize on
  /// `(preview identity, uiState.hashCode, exchangeRatesEpoch)` — switching
  /// company or refreshing statics changes [exchangeRates], so the rates
  /// epoch must factor into the memo key or stale converted totals leak
  /// across company switches.
  ReportView compute({
    required ReportPreview preview,
    required ReportUiState ui,
    required Map<String, Decimal> exchangeRates,
    required String? companyCurrencyId,
  }) {
    if (preview.columns.isEmpty) return ReportView.empty;

    // 1. Visible columns + group-first reorder.
    final visible = _visibleColumns(preview, ui);

    // 2. Column filters.
    var filtered = preview.rows
        .where((row) => _passesFilters(row, preview.columns, ui))
        .toList(growable: false);

    // 3. Drill-down narrows further when active.
    if (ui.group != null &&
        ui.group!.isNotEmpty &&
        ui.selectedGroup != null &&
        ui.selectedGroup!.isNotEmpty) {
      final groupIdx = _columnIndex(preview.columns, ui.group!);
      if (groupIdx >= 0) {
        filtered = filtered
            .where(
              (row) =>
                  _groupKey(
                    row.cells[groupIdx],
                    preview.columns[groupIdx],
                    subgroup: ui.subgroup,
                  ) ==
                  ui.selectedGroup,
            )
            .toList(growable: false);
      }
    }

    // 4. Sort.
    final sortIdx = ui.sortField == null
        ? -1
        : _columnIndex(preview.columns, ui.sortField!);
    if (sortIdx >= 0) {
      // Stable sort: Dart's List.sort isn't stable, so equal-key rows could
      // reshuffle between rebuilds (and within group buckets). Carry the
      // pre-sort index as a tie-breaker to keep the order deterministic.
      final indexed = [
        for (var i = 0; i < filtered.length; i++) (i, filtered[i]),
      ];
      indexed.sort((a, b) {
        final cmp = _compareCells(
          a.$2.cells[sortIdx],
          b.$2.cells[sortIdx],
          ui.sortAscending,
        );
        return cmp != 0 ? cmp : a.$1.compareTo(b.$1);
      });
      filtered = [for (final e in indexed) e.$2];
    }

    // 5. Group or pass through.
    //
    // The group column must actually be **in** the preview. A caller can name
    // one that isn't there yet — the Reports screen sets the group before the
    // run that fetches an optional column — and without this check `_bucket`
    // returns `[]` while `renderedRows` is still forced to `[]`, so the view
    // comes back with no rows AND no groups over a full preview. That is the
    // "No results" empty state: shown for the length of the fetch, and left
    // there permanently if the run is cancelled or fails.
    final isGrouping =
        ui.group != null &&
        ui.group!.isNotEmpty &&
        _columnIndex(preview.columns, ui.group!) >= 0 &&
        (ui.selectedGroup == null || ui.selectedGroup!.isEmpty);
    final groups = isGrouping
        ? _bucket(filtered, preview.columns, ui)
        : <GroupTotals>[];
    final renderedRows = isGrouping ? <ReportRow>[] : filtered;

    // 6. Per-currency totals + (optional) converted totals.
    final perCurrencyTotals = _perCurrencyTotals(filtered, preview.columns);
    final rowCountByCurrency = _rowCountByCurrency(filtered, preview.columns);
    final (converted, ratesAvailable) = ui.convertCurrency
        ? _convertedTotals(perCurrencyTotals, exchangeRates, companyCurrencyId)
        : (null, false);

    return ReportView(
      visibleColumns: visible,
      rows: renderedRows,
      groups: groups,
      grandTotalsByCurrency: perCurrencyTotals,
      convertedGrandTotals: converted,
      rowCountByCurrency: rowCountByCurrency,
      totalRowCount: filtered.length,
      exchangeRatesAvailable: ratesAvailable,
      // Map covers every preview column, not just the visible subset —
      // the data-table renderer looks up cells for *visible* columns,
      // which are always a subset of the original column list.
      cellIndexByColumn: {
        for (var i = 0; i < preview.columns.length; i++)
          preview.columns[i].identifier: i,
      },
    );
  }

  // ───── helpers ─────

  List<ReportColumn> _visibleColumns(ReportPreview preview, ReportUiState ui) {
    final allCols = preview.columns;
    var visible = ui.visibleColumnIds.isEmpty
        ? allCols.toList()
        : allCols
              .where((c) => ui.visibleColumnIds.contains(c.identifier))
              .toList();
    // Apply the user's chosen order: listed columns first (in order),
    // unlisted ones after in server order. Built explicitly rather than
    // via List.sort (Dart's sort isn't stable, so unlisted columns could
    // otherwise reshuffle). A no-op when columnOrder is empty.
    if (ui.columnOrder.isNotEmpty) {
      final byId = {for (final c in visible) c.identifier: c};
      final ordered = <ReportColumn>[];
      final used = <String>{};
      for (final id in ui.columnOrder) {
        final c = byId[id];
        if (c != null && used.add(id)) ordered.add(c);
      }
      for (final c in visible) {
        if (!used.contains(c.identifier)) ordered.add(c);
      }
      visible = ordered;
    }
    if (ui.group == null || ui.group!.isEmpty) return visible.toList();
    // Resolve the group column against the preview's full column set. When
    // it's missing (stale group setting carried across a report switch),
    // fall through without reordering — the caller will treat the report
    // as ungrouped (group key is unreachable from any cell).
    ReportColumn? groupCol;
    for (final c in allCols) {
      if (c.identifier == ui.group) {
        groupCol = c;
        break;
      }
    }
    // No grouping reorder — also covers stale group settings carried
    // across a report switch (the identifier doesn't exist on this
    // report's columns).
    if (groupCol == null) return visible.toList();
    final out = <ReportColumn>[groupCol];
    for (final c in visible) {
      if (c.identifier != groupCol.identifier) out.add(c);
    }
    return out;
  }

  int _columnIndex(List<ReportColumn> columns, String identifier) {
    for (var i = 0; i < columns.length; i++) {
      if (columns[i].identifier == identifier) return i;
    }
    return -1;
  }

  bool _passesFilters(
    ReportRow row,
    List<ReportColumn> columns,
    ReportUiState ui,
  ) {
    if (ui.columnFilters.isEmpty) return true;
    for (final entry in ui.columnFilters.entries) {
      final filter = entry.value.trim();
      if (filter.isEmpty) continue;
      final idx = _columnIndex(columns, entry.key);
      if (idx < 0 || idx >= row.cells.length) continue;
      if (!_matchCell(row.cells[idx], columns[idx], filter)) return false;
    }
    return true;
  }

  bool _matchCell(ReportCell cell, ReportColumn column, String filter) {
    switch (column.type) {
      case ReportColumnType.boolean:
        if (cell is! ReportBoolCell) return false;
        final lower = filter.toLowerCase();
        final yes = lower == 'true' || lower == 'yes' || lower == '1';
        return cell.value == yes;
      case ReportColumnType.number:
      case ReportColumnType.money:
        return _matchRange(cell, filter);
      case ReportColumnType.age:
        return _matchAge(cell, filter);
      case ReportColumnType.date:
      case ReportColumnType.dateTime:
        // Date filters arrive as `start..end` ISO strings; empty halves
        // mean unbounded. Substring match falls back when the input
        // doesn't parse as a range.
        return _matchDateRange(cell, filter);
      case ReportColumnType.duration:
        return _matchRange(cell, filter);
      case ReportColumnType.string:
        return cell.filterText.contains(filter.toLowerCase());
    }
  }

  bool _matchRange(ReportCell cell, String filter) {
    Decimal? value;
    if (cell is ReportNumberCell) {
      value = cell.value;
    } else if (cell is ReportDurationCell && cell.seconds != null) {
      value = Decimal.fromInt(cell.seconds!);
    }
    if (value == null) return false;
    final (lower, upper) = _parseNumericRange(filter);
    if (lower != null && value < lower) return false;
    if (upper != null && value > upper) return false;
    return true;
  }

  /// Parse a `min..max` range, either side optional (`100..`, `..500`,
  /// `100..500`). A bare number with no `..` is a lower bound (`>=`), matching
  /// admin-portal's numeric filter. Using `..` (not `-`) keeps negative bounds
  /// such as `-100..0` unambiguous (the old `-`-split mangled them).
  (Decimal?, Decimal?) _parseNumericRange(String filter) {
    final i = filter.indexOf('..');
    if (i < 0) {
      return (Decimal.tryParse(filter.trim()), null);
    }
    final lo = filter.substring(0, i).trim();
    final hi = filter.substring(i + 2).trim();
    return (
      lo.isEmpty ? null : Decimal.tryParse(lo),
      hi.isEmpty ? null : Decimal.tryParse(hi),
    );
  }

  bool _matchAge(ReportCell cell, String filter) {
    if (cell is! ReportAgeCell) return false;
    final lower = filter.toLowerCase();
    if (lower == 'paid') return cell.isPaid;
    final age = cell.days;
    if (age == null) return false;
    switch (lower) {
      case '0':
      case '30':
        return age >= 0 && age <= 30;
      case '60':
        return age > 30 && age <= 60;
      case '90':
        return age > 60 && age <= 90;
      case '120':
        return age > 90 && age <= 120;
      case '120+':
        return age > 120;
    }
    // Fallback: numeric range like "30-60".
    return _matchRange(ReportNumberCell(value: Decimal.fromInt(age)), filter);
  }

  bool _matchDateRange(ReportCell cell, String filter) {
    final parts = filter.split('..');
    if (parts.length == 2) {
      final start = parts[0].trim();
      final end = parts[1].trim();
      if (cell is ReportDateCell && cell.value != null) {
        if (start.isNotEmpty) {
          final s = Date.tryParse(start);
          if (s != null && cell.value!.compareTo(s) < 0) return false;
        }
        if (end.isNotEmpty) {
          final e = Date.tryParse(end);
          if (e != null && cell.value!.compareTo(e) > 0) return false;
        }
        return true;
      }
      if (cell is ReportDateTimeCell && cell.value != null) {
        // Range bounds arrive as date-only ISO (the picker emits Date.toIso()),
        // so compare on the cell's calendar day (Date-to-Date) — mirrors the
        // date branch above and the dateTime grouping in _groupKey. Comparing
        // the raw DateTime against a midnight-parsed end bound would drop every
        // same-day timestamp on the end date (off-by-one excluding the end day).
        final v = cell.value!;
        final cellDate = Date(v.year, v.month, v.day);
        if (start.isNotEmpty) {
          final s = Date.tryParse(start);
          if (s != null && cellDate.compareTo(s) < 0) return false;
        }
        if (end.isNotEmpty) {
          final e = Date.tryParse(end);
          if (e != null && cellDate.compareTo(e) > 0) return false;
        }
        return true;
      }
      return false;
    }
    // Fallback: substring match on the display string.
    return cell.filterText.contains(filter.toLowerCase());
  }

  /// Null-aware compare over two typed sort keys (nulls last in ascending).
  /// Returns 0 for mixed / incomparable types — sorting a column whose cells
  /// share a type never hits that, and a tie beats a `toString` compare that
  /// would mis-order Decimals ("100" < "20" as strings).
  int _compareSortKeys(Object? ak, Object? bk) {
    if (ak == null && bk == null) return 0;
    if (ak == null) return 1;
    if (bk == null) return -1;
    if (ak is Comparable &&
        bk is Comparable &&
        ak.runtimeType == bk.runtimeType) {
      return ak.compareTo(bk);
    }
    return 0;
  }

  int _compareCells(ReportCell a, ReportCell b, bool ascending) {
    final ak = a.sortKey;
    final bk = b.sortKey;
    if (ak != null && bk != null && ak.runtimeType != bk.runtimeType) {
      // Shouldn't happen in a well-formed preview (all cells in a column share
      // a type); log at FINE so a data-quality regression surfaces without
      // destabilising the UI (the compare falls back to a tie).
      _log.fine('mixed-type sort keys: ${ak.runtimeType} vs ${bk.runtimeType}');
    }
    final cmp = _compareSortKeys(ak, bk);
    return ascending ? cmp : -cmp;
  }

  /// Group columns whose typed sort key is numeric — their bucket keys are
  /// display strings that must NOT be ordered lexicographically. Age is
  /// included so age *groups* sort numerically, even though it's excluded from
  /// `isAggregatable` (group ordering and summability are separate concerns).
  bool _numericGroupOrder(ReportColumnType t) =>
      t == ReportColumnType.money ||
      t == ReportColumnType.number ||
      t == ReportColumnType.age ||
      t == ReportColumnType.duration;

  List<GroupTotals> _bucket(
    List<ReportRow> rows,
    List<ReportColumn> columns,
    ReportUiState ui,
  ) {
    final groupIdx = _columnIndex(columns, ui.group!);
    if (groupIdx < 0) return const [];
    final buckets = <String, List<ReportRow>>{};
    for (final row in rows) {
      final key = _groupKey(
        row.cells[groupIdx],
        columns[groupIdx],
        subgroup: ui.subgroup,
      );
      (buckets[key] ??= <ReportRow>[]).add(row);
    }
    final keys = buckets.keys.toList();
    if (_numericGroupOrder(columns[groupIdx].type)) {
      // Bucket keys are display strings; for numeric group columns those sort
      // lexicographically ("$1,000" before "$200", "10" before "9"). Order by
      // each bucket's representative typed sort key instead.
      keys.sort(
        (a, b) => _compareSortKeys(
          buckets[a]!.first.cells[groupIdx].sortKey,
          buckets[b]!.first.cells[groupIdx].sortKey,
        ),
      );
    } else {
      keys.sort();
    }
    return [
      for (final key in keys)
        GroupTotals(
          key: key,
          rows: buckets[key]!,
          numericTotals: _perCurrencyTotals(buckets[key]!, columns),
        ),
    ];
  }

  /// Bucket key for a cell when grouping by its column. Date columns honor
  /// the [subgroup] (`day`/`week`/`month`/`quarter`/`year`); other types
  /// fall back to the cell's display string.
  String _groupKey(
    ReportCell cell,
    ReportColumn column, {
    ReportSubgroup? subgroup,
  }) {
    if (column.type == ReportColumnType.date && cell is ReportDateCell) {
      return _dateBucket(cell.value, subgroup);
    }
    if (column.type == ReportColumnType.dateTime &&
        cell is ReportDateTimeCell &&
        cell.value != null) {
      // `.toLocal()` is load-bearing, not defensive. An epoch-seconds `*_at`
      // value is parsed `isUtc: true` (`_parseTyped`), while the table cell
      // renders it through `Formatter.date(..., showTime: true)`, which
      // appends `Z` and calls `.toLocal()`. Reading the calendar fields off
      // the UTC instant would bucket a client created 2026-03-01 09:00 at
      // UTC+10 under **February** while its own row displays 01/Mar — the
      // headline "new clients per month" figure contradicting itself on the
      // same screen. A local DateTime (the string branch) is unaffected.
      final d = cell.value!.toLocal();
      return _dateBucket(Date(d.year, d.month, d.day), subgroup);
    }
    // Prefer displayValue → cell's raw value (case-preserving for strings)
    //   → sortKey.toString() (raw typed value for Decimals / Dates / Ints;
    // ONLY strings are case-folded into sortKey, and we handle them above
    // before this line so the toString() fallback is safe for numerics).
    if (cell.displayValue != null) return cell.displayValue!;
    if (cell is ReportStringCell && cell.value != null) return cell.value!;
    return cell.sortKey?.toString() ?? '';
  }

  String _dateBucket(Date? date, ReportSubgroup? subgroup) {
    if (date == null) return '';
    switch (subgroup ?? ReportSubgroup.day) {
      case ReportSubgroup.day:
        return date.toIso();
      case ReportSubgroup.week:
        // Week start honors the company first_day_of_week (0=Sun..6=Sat);
        // with the default 0 this is the Sunday of the week.
        return startOfWeek(date, firstDayOfWeek).toIso();
      case ReportSubgroup.month:
        return Date(date.year, date.month, 1).toIso();
      case ReportSubgroup.quarter:
        // Calendar quarters — deliberately NOT fiscal-shifted (matches
        // admin-portal / React).
        final qStartMonth = ((date.month - 1) ~/ 3) * 3 + 1;
        return Date(date.year, qStartMonth, 1).toIso();
      case ReportSubgroup.year:
        // Fiscal-year aware: the bucket starts on first_month_of_year (Jan 1
        // when unset / 1).
        return startOfFiscalYear(date, firstMonthOfYear).toIso();
    }
  }

  /// Every bucket key from [firstKey] to [lastKey] inclusive at [subgroup]
  /// granularity — the contiguous timeline `groups` does *not* provide.
  ///
  /// [_bucket] only emits a bucket for a date that has rows, so a month
  /// nobody signed up in simply isn't there; a chart plotting buckets by
  /// index then closes the gap and draws two non-adjacent periods as
  /// neighbours. Callers fill the missing keys with zero. Both bounds are
  /// expected to be keys [_dateBucket] produced, and are re-canonicalized
  /// anyway so a hand-written bound can't walk off the grid.
  ///
  /// Deliberately **interior only** — the caller passes the first and last
  /// bucket present in the data, never the selected date range, so "This
  /// year" viewed in March doesn't assert zeros for months that haven't
  /// happened.
  ///
  /// Returns `const []` when the bounds don't parse, are inverted, or the
  /// span exceeds [kMaxReportChartBuckets] (All-time at day granularity is
  /// thousands of points). Over the cap the caller plots the raw buckets
  /// rather than coarsening: the user picked this granularity, unlike the
  /// dashboard's own axis builder, which is the model for the cap itself
  /// (`chart_series_math.dart`).
  List<String> dateBucketSpan(
    String firstKey,
    String lastKey,
    ReportSubgroup? subgroup,
  ) {
    final first = Date.tryParse(firstKey);
    final last = Date.tryParse(lastKey);
    if (first == null || last == null) return const [];
    if (first.compareTo(last) > 0) return const [];
    final sub = subgroup ?? ReportSubgroup.day;
    final end = _dateBucket(last, sub);
    var cursor = Date.tryParse(_dateBucket(first, sub));
    if (cursor == null) return const [];
    final out = <String>[];
    while (true) {
      if (out.length >= kMaxReportChartBuckets) return const [];
      final key = cursor!.toIso();
      out.add(key);
      if (key == end || cursor.compareTo(last) >= 0) break;
      cursor = _nextBucket(cursor, sub);
    }
    return out;
  }

  /// The start of the bucket following the one starting at [d]. Bucket
  /// starts are canonical (month → the 1st, quarter → the quarter's first
  /// month, year → the fiscal-year start, week → the week start), so
  /// stepping by one period keeps them canonical.
  Date _nextBucket(Date d, ReportSubgroup sub) {
    switch (sub) {
      case ReportSubgroup.day:
        return d.addDays(1);
      case ReportSubgroup.week:
        return d.addDays(7);
      case ReportSubgroup.month:
        return _addMonths(d, 1);
      case ReportSubgroup.quarter:
        return _addMonths(d, 3);
      case ReportSubgroup.year:
        return startOfNextFiscalYear(d, firstMonthOfYear);
    }
  }

  /// [d] shifted by whole months, snapped to the 1st. Month-space math, so
  /// there is no "Jan 31 + 1 month" clamping question to get wrong.
  static Date _addMonths(Date d, int months) {
    final zeroBased = d.year * 12 + (d.month - 1) + months;
    return Date(zeroBased ~/ 12, zeroBased % 12 + 1, 1);
  }

  Map<String, Map<String, Decimal>> _perCurrencyTotals(
    List<ReportRow> rows,
    List<ReportColumn> columns,
  ) {
    final out = <String, Map<String, Decimal>>{};
    for (var i = 0; i < columns.length; i++) {
      final col = columns[i];
      if (!isAggregatable(col.type)) continue;
      final perCurrency = <String, Decimal>{};
      for (final row in rows) {
        if (i >= row.cells.length) continue;
        final cell = row.cells[i];
        Decimal? add;
        String currencyId = '';
        if (cell is ReportNumberCell && cell.value != null) {
          add = cell.value;
          currencyId = cell.currencyId ?? '';
        } else if (cell is ReportDurationCell && cell.seconds != null) {
          add = Decimal.fromInt(cell.seconds!);
        }
        if (add == null) continue;
        perCurrency[currencyId] =
            (perCurrency[currencyId] ?? Decimal.zero) + add;
      }
      if (perCurrency.isNotEmpty) {
        out[col.identifier] = perCurrency;
      }
    }
    return out;
  }

  Map<String, int> _rowCountByCurrency(
    List<ReportRow> rows,
    List<ReportColumn> columns,
  ) {
    // Pick the first money column we find — its currencyId labels the row.
    // For non-money reports (Tasks, Activity), bucket under '' so the
    // totals card shows a single row-count line.
    var moneyIdx = -1;
    for (var i = 0; i < columns.length; i++) {
      if (columns[i].type == ReportColumnType.money) {
        moneyIdx = i;
        break;
      }
    }
    final out = <String, int>{};
    for (final row in rows) {
      String cid = '';
      if (moneyIdx >= 0 && moneyIdx < row.cells.length) {
        final c = row.cells[moneyIdx];
        if (c is ReportNumberCell) cid = c.currencyId ?? '';
      }
      out[cid] = (out[cid] ?? 0) + 1;
    }
    return out;
  }

  (Map<String, Decimal>?, bool) _convertedTotals(
    Map<String, Map<String, Decimal>> perCurrency,
    Map<String, Decimal> rates,
    String? companyCurrencyId,
  ) {
    if (companyCurrencyId == null || companyCurrencyId.isEmpty) {
      return (null, false);
    }
    final companyRate = rates[companyCurrencyId];
    if (companyRate == null || companyRate == Decimal.zero) {
      return (null, false);
    }
    final out = <String, Decimal>{};
    for (final entry in perCurrency.entries) {
      Decimal sum = Decimal.zero;
      for (final cur in entry.value.entries) {
        final from = cur.key;
        final amount = cur.value;
        if (from.isEmpty || from == companyCurrencyId) {
          sum += amount;
          continue;
        }
        final fromRate = rates[from];
        if (fromRate == null || fromRate == Decimal.zero) {
          // Missing a needed rate — give up on converted totals.
          return (null, false);
        }
        // amount in `from` → company: (amount / fromRate) * companyRate.
        // `companyRate / fromRate` produces a Rational; we materialise it
        // at 12 fractional digits — more than enough to keep typical
        // 4–8 digit fx rates intact, and small enough that the resulting
        // `amount * ratio` doesn't accumulate noise across long sums. If
        // chart math (Phase 5) demands more, revisit.
        final ratio = (companyRate / fromRate).toDecimal(
          scaleOnInfinitePrecision: 12,
        );
        sum += amount * ratio;
      }
      out[entry.key] = sum;
    }
    return (out, true);
  }
}
