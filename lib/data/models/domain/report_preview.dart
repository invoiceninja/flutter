import 'package:decimal/decimal.dart';

import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/reports/report_column_types.dart';

/// One column header in a [ReportPreview]. The `displayLabel` comes from the
/// server's per-locale label; `type` is inferred from the column identifier
/// so the local engine can sort/filter/aggregate without round-tripping
/// through the display string.
class ReportColumn {
  const ReportColumn({
    required this.identifier,
    required this.displayLabel,
    required this.type,
    this.aggregation,
  });

  /// Stable id, e.g. `client.name` or `invoice.amount`. Used as the dictionary
  /// key for column filters, sort field, and column visibility.
  final String identifier;

  /// Locale-formatted human label from the server.
  final String displayLabel;

  final ReportColumnType type;

  /// An explicit answer to "how is this column totalled", or null to take
  /// the one its name implies. Set when the report's row grain says more
  /// than the name can — see [ReportAggregation.oncePerRecord].
  final ReportAggregation? aggregation;

  /// How this column is totalled: [aggregation] when set, otherwise
  /// [defaultReportAggregation].
  ReportAggregation get effectiveAggregation =>
      aggregation ?? defaultReportAggregation(identifier, type);

  ReportColumn copyWith({
    String? displayLabel,
    ReportColumnType? type,
    ReportAggregation? aggregation,
  }) => ReportColumn(
    identifier: identifier,
    displayLabel: displayLabel ?? this.displayLabel,
    type: type ?? this.type,
    aggregation: aggregation ?? this.aggregation,
  );

  @override
  bool operator ==(Object other) =>
      other is ReportColumn &&
      other.identifier == identifier &&
      other.displayLabel == displayLabel &&
      other.type == type &&
      other.aggregation == aggregation;

  @override
  int get hashCode => Object.hash(identifier, displayLabel, type, aggregation);
}

/// Sealed value carried by a single cell of a [ReportRow]. Carries:
/// - the **raw** typed value (for sort, filter, aggregation — and rendering,
///   for every type but a string)
/// - the server's own **display value** (what a string cell shows, and the
///   fallback when a typed value could not be parsed)
/// - the wire-format reference to the *related* record the cell belongs to,
///   when there is one (`entityWire` is the server's raw string, NOT an
///   `EntityType` enum; mapping happens in `resolveDrillTarget`).
///
/// Cell parsing happens in `ReportsRepository._parseCell`. Money uses
/// `parseMoney` from `lib/data/models/value/money.dart` (Decimal); dates use
/// `Date.tryParse` / `DateTime.tryParse`. `double` is forbidden for money by
/// the CI lint.
sealed class ReportCell {
  const ReportCell({this.entityWire, this.entityId, this.displayValue});

  /// The entity this cell's column belongs to — the part of its identifier
  /// before the dot (`client` for `client.name`, `invoice`, `item`, …).
  final String? entityWire;

  /// The id of the **related** record this cell belongs to, and null for a
  /// cell of the row's own entity.
  ///
  /// That asymmetry is the server's (`BaseExport::processMetaData`): it sends
  /// `hashed_id` only when the column's entity is not the row's, so on an
  /// invoice report a `client.name` cell carries the client's id and an
  /// `invoice.number` cell carries nothing. The row's own id is
  /// [ReportRow.recordId], which arrives by a different route.
  ///
  /// It is read from `hashed_id`, not from the cell's `id` — that one is the
  /// *field name* (`"number"`), which this field used to hold and which sent
  /// every row tap to a record called "number".
  final String? entityId;

  /// The server's pre-formatted display string. Used as a fallback when the
  /// local engine can't (or shouldn't) re-render — e.g. text columns where
  /// the server applied an i18n lookup we don't replicate locally.
  final String? displayValue;

  /// Key used by [ReportEngine] for sort and group buckets. `null` sorts
  /// last in ascending order, first in descending — matches v1's
  /// `ReportResult.sortReport` behavior.
  Object? get sortKey;

  /// Lower-case text representation used for substring filter matching on
  /// string columns. Numeric / date types ignore this — they filter via
  /// type-aware comparisons against `sortKey`.
  String get filterText => displayValue?.toLowerCase() ?? '';
}

class ReportStringCell extends ReportCell {
  const ReportStringCell({
    this.value,
    super.entityWire,
    super.entityId,
    super.displayValue,
  });

  final String? value;

  @override
  Object? get sortKey => value?.toLowerCase();

  @override
  String get filterText => (displayValue ?? value)?.toLowerCase() ?? '';
}

/// Numeric cell. For money columns [isMoney] is true. [currencyId] is an
/// explicit currency for this one cell and is normally null — a row's amounts
/// share [ReportRow.currencyId], which is where the engine looks next.
/// [exchangeRate] is the cell's rate to the company currency when a producer
/// sets one.
class ReportNumberCell extends ReportCell {
  const ReportNumberCell({
    this.value,
    this.isMoney = false,
    this.currencyId,
    this.exchangeRate,
    super.entityWire,
    super.entityId,
    super.displayValue,
  });

  final Decimal? value;
  final bool isMoney;
  final String? currencyId;
  final Decimal? exchangeRate;

  @override
  Object? get sortKey => value;

  /// Numeric value as `double` for chart axes — chart libraries expect
  /// doubles. **Not** used for totals (which stay in Decimal).
  double? get chartValue =>
      value == null ? null : double.parse(value!.toString());
}

class ReportDateCell extends ReportCell {
  const ReportDateCell({
    this.value,
    super.entityWire,
    super.entityId,
    super.displayValue,
  });

  /// Calendar date — no time, no timezone. `DateTime` would smuggle in
  /// timezone semantics; per CLAUDE.md, date-only columns must use [Date].
  final Date? value;

  @override
  Object? get sortKey => value;
}

class ReportDateTimeCell extends ReportCell {
  const ReportDateTimeCell({
    this.value,
    super.entityWire,
    super.entityId,
    super.displayValue,
  });

  /// Timestamp. Separate from [ReportDateCell] so the engine can't silently
  /// coerce between the two (CLAUDE.md strict rule).
  final DateTime? value;

  @override
  Object? get sortKey => value;
}

/// Age in days. `-1` is the legacy "paid" sentinel — admin-portal renders
/// it as the `paid` localization key, and the bucket filter offers "Paid"
/// as a discrete option.
class ReportAgeCell extends ReportCell {
  const ReportAgeCell({
    this.days,
    super.entityWire,
    super.entityId,
    super.displayValue,
  });

  final int? days;

  /// True when this cell represents the "paid" sentinel (no aging).
  bool get isPaid => days == -1;

  @override
  Object? get sortKey {
    if (days == null) return null;
    if (days == -1) return -1;
    return days;
  }
}

class ReportBoolCell extends ReportCell {
  const ReportBoolCell({
    this.value,
    super.entityWire,
    super.entityId,
    super.displayValue,
  });

  final bool? value;

  @override
  Object? get sortKey => value;
}

class ReportDurationCell extends ReportCell {
  const ReportDurationCell({
    this.seconds,
    super.entityWire,
    super.entityId,
    super.displayValue,
  });

  final int? seconds;

  @override
  Object? get sortKey => seconds;
}

/// One row of a [ReportPreview].
class ReportRow {
  const ReportRow({
    required this.cells,
    this.recordWire,
    this.recordId,
    this.currencyId,
  });

  final List<ReportCell> cells;

  /// The wire name of the record this row *is* (`invoice`, `client`, …; on a
  /// line-item report, the parent document), and its id. Both null until the
  /// row's id is known — the server does not send it unasked, see
  /// `ReportDefinition.rowIdKey` — and a row with no id is not a link.
  final String? recordWire;
  final String? recordId;

  /// The currency this row's amounts are in (a statics currency id), or null
  /// when the report carries no currency column. The server puts no currency
  /// on a cell; it puts an ISO code in a column of the row.
  final String? currencyId;

  ReportRow copyWith({
    List<ReportCell>? cells,
    String? recordWire,
    String? recordId,
    String? currencyId,
  }) => ReportRow(
    cells: cells ?? this.cells,
    recordWire: recordWire ?? this.recordWire,
    recordId: recordId ?? this.recordId,
    currencyId: currencyId ?? this.currencyId,
  );
}

/// The decoded server response for one Run of a report — the column header
/// set + the row body. Held in memory on the ViewModel; all local sort /
/// filter / group / subtotal happens against this object via [ReportEngine].
class ReportPreview {
  const ReportPreview({required this.columns, required this.rows});

  final List<ReportColumn> columns;
  final List<ReportRow> rows;

  static const empty = ReportPreview(columns: [], rows: []);
}
