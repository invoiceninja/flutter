import 'package:decimal/decimal.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/reports_repository.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/reports/local_report_source.dart';
import 'package:admin/domain/reports/report_column_types.dart';

final _log = Logger('RecordReportSource');

/// A report built on the device from one kind of record the app already
/// lists — credits, recurring expenses, bank transactions — which the server
/// has no report for. v1 built the same reports from its local store.
///
/// The shape is Task Items' (`TaskItemsReportSource`): the records the range
/// can hold are fetched page by page into the device's store with the list
/// route's own filters, narrowed to the range where the route can narrow
/// it, then read back and turned into rows on the device. Every filter is
/// applied on the device, so the rows are the same online and off; the fetch
/// only has to be a superset.
class RecordReportSource<T> implements LocalReportSource {
  RecordReportSource({
    required this.name,
    required this.fetchPage,
    required this.fetchFilters,
    required this.readRecords,
    required this.readLookups,
    required this.build,
    this.namesToFetch,
    this.hydrateNames,
  });

  /// For the log.
  final String name;

  /// One page of records from the server into the device's store; true
  /// while there are more.
  final Future<bool> Function(
    String companyId,
    int page,
    Set<EntityState> states,
    Map<String, Set<String>> filters,
  )
  fetchPage;

  /// The list filters a refresh sends for [ReportQuery] — a superset of the
  /// rows, never a subset: the rows are cut on the device.
  final Map<String, Set<String>> Function(ReportQuery query) fetchFilters;

  /// The records the device holds that the report may show, in [states].
  final Future<List<T>> Function(ReportQuery query, Set<EntityState> states)
  readRecords;

  /// The names, currencies and other lookups the rows of [records] read.
  final Future<ReportLookups> Function(String companyId, List<T> records)
  readLookups;

  /// The rows.
  final ReportPreview Function(
    List<T> records,
    ReportQuery query,
    ReportLookups lookups,
  )
  build;

  /// The ids, by kind (`client`, `vendor`, …), that the rows name and
  /// [ReportLookups] cannot resolve. Null fetches nothing.
  final Map<String, Set<String>> Function(
    List<T> records,
    ReportQuery query,
    ReportLookups lookups,
  )?
  namesToFetch;

  /// Fetch the records [namesToFetch] answered. Never throws for a record
  /// that cannot be had: the row reads `—`.
  final Future<void> Function(String companyId, Map<String, Set<String>> ids)?
  hydrateNames;

  @override
  Future<ReportPreview> fromDevice(ReportQuery query) async {
    final records = await readRecords(query, reportRecordStates(query));
    final lookups = await readLookups(query.companyId, records);
    return build(records, query, lookups);
  }

  @override
  Future<ReportPreview> refresh(
    ReportQuery query, {
    bool Function()? isCancelled,
  }) async {
    final states = reportRecordStates(query);
    final filters = fetchFilters(query);
    try {
      for (var page = 1; ; page++) {
        // Before the page, not after: a cancelled run must not spend a
        // request it will throw away.
        if (isCancelled?.call() ?? false) {
          throw const ReportError(kind: ReportErrorKind.cancelled);
        }
        if (page > kRecordReportMaxPages) {
          // Never a quiet partial report. No message: the banner shows a
          // message as written, and this one would be in English.
          _log.warning('$name gave up after $kRecordReportMaxPages pages');
          throw const ReportError(kind: ReportErrorKind.unknown);
        }
        final more = await fetchPage(query.companyId, page, states, filters);
        if (!more) break;
      }
    } on ReportError {
      rethrow;
    } catch (e, st) {
      throw reportErrorFrom(e, st);
    }
    if (isCancelled?.call() ?? false) {
      throw const ReportError(kind: ReportErrorKind.cancelled);
    }
    final records = await readRecords(query, states);
    var lookups = await readLookups(query.companyId, records);
    final missingOf = namesToFetch;
    final hydrate = hydrateNames;
    if (missingOf != null && hydrate != null) {
      final missing = {
        for (final MapEntry(:key, :value) in missingOf(
          records,
          query,
          lookups,
        ).entries)
          if (value.isNotEmpty)
            key: value.take(kRecordReportMaxNameFetches).toSet(),
      };
      if (missing.isNotEmpty) {
        try {
          await hydrate(query.companyId, missing);
        } catch (e, st) {
          // The rows stand without the names; each reads `—`.
          _log.warning('Could not fetch the names $name needs', e, st);
        }
        if (isCancelled?.call() ?? false) {
          throw const ReportError(kind: ReportErrorKind.cancelled);
        }
        lookups = await readLookups(query.companyId, records);
      }
    }
    return build(records, query, lookups);
  }
}

/// Pages a refresh may take before it gives up — `refreshAll`'s ceiling.
const int kRecordReportMaxPages = 1000;

/// At most this many records of each kind are fetched for their names in one
/// refresh — one request each.
const int kRecordReportMaxNameFetches = 200;

/// `loadedPages` for a repository's `watchPage` that has to return every row
/// it matches: its limit is the page size times this. A report is cut by its
/// own filters, never by a list's window.
const int kRecordReportAllPages = 1 << 24;

/// The lifecycle states a report reads: archived records count, deleted ones
/// only when asked — the server's reports' rule.
Set<EntityState> reportRecordStates(ReportQuery query) => {
  EntityState.active,
  EntityState.archived,
  if (query.includeDeleted) EntityState.deleted,
};

/// What the rows of a report built on the device read besides the records
/// themselves: names by kind and id, the currencies, and the `tmp_` ids that
/// have synced.
class ReportLookups {
  const ReportLookups({
    this.names = const {},
    this.remap = const {},
    this.currencies = const {},
    this.companyCurrencyId = '',
    this.extra = const {},
  });

  /// Kind (`client`, `vendor`, `category`, `user`, …) → id → name.
  final Map<String, Map<String, String>> names;

  /// `tmp_` id → the real id it became.
  final Map<String, String> remap;

  /// The statics currencies, by id.
  final Map<String, Currency> currencies;

  /// The company's currency — what a record with none of its own is in.
  final String companyCurrencyId;

  /// Whatever else a report needs, by kind — records rather than names
  /// (a client's number and address, say).
  final Map<String, Map<String, Object>> extra;

  String idOf(String id) => remap[id] ?? id;

  /// The name of [id] of [kind]: `''` for no id, `—` for one the device
  /// cannot name — never the id itself.
  String nameOf(String kind, String id) {
    if (id.isEmpty) return '';
    return names[kind]?[idOf(id)] ?? '—';
  }

  /// Whether [id] of [kind] has a name here.
  bool knows(String kind, String id) =>
      id.isEmpty || (names[kind]?.containsKey(idOf(id)) ?? false);

  /// The currency [currencyId] names, else the company's.
  Currency? currencyOr(String currencyId) =>
      currencies[currencyId.isEmpty ? companyCurrencyId : currencyId] ??
      currencies[companyCurrencyId];
}

/// The ids among [ids] that [lookups] cannot name as [kind] and that the
/// server could answer for — real ids only: one created offline has nothing
/// to fetch.
Set<String> unnamedIds(
  ReportLookups lookups,
  String kind,
  Iterable<String> ids,
) => {
  for (final raw in ids)
    if (raw.isNotEmpty)
      if (lookups.idOf(raw) case final id
          when !id.startsWith('tmp_') && !lookups.knows(kind, id))
        id,
};

/// [ids] in chunks of [size] — a few requests at a time.
Iterable<List<String>> reportIdChunks(Set<String> ids, int size) sync* {
  final list = ids.toList(growable: false);
  for (var i = 0; i < list.length; i += size) {
    yield list.sublist(i, i + size > list.length ? list.length : i + size);
  }
}

/// Whether [id] passes an id filter of [wanted], compared on real ids: a
/// record created offline is named by its `tmp_` id on one side until it
/// syncs, and by its real one on the other after.
bool reportIdMatches(Set<String> wanted, String id, ReportLookups lookups) {
  if (wanted.isEmpty) return true;
  final real = lookups.idOf(id);
  return wanted.any((w) => lookups.idOf(w) == real);
}

/// Whether [date] is inside [query]'s range; every date is, on "All time",
/// and no date is inside a range.
bool reportDateInRange(Date? date, ReportQuery query) {
  final start = query.start;
  final end = query.end;
  if (start == null || end == null) return true;
  if (date == null) return false;
  return date.compareTo(start) >= 0 && date.compareTo(end) <= 0;
}

/// The comma-joined filter values of [raw] — the Status filter's wire shape.
Set<String> reportCsv(String raw) => {
  for (final p in raw.split(','))
    if (p.trim().isNotEmpty) p.trim(),
};

/// A column of a report built on the device. [labelKey] is a localization
/// key, resolved through the query; the type is set, not inferred from the
/// id.
typedef ReportColumnSpec = ({
  String labelKey,
  ReportColumnType type,
  ReportAggregation? aggregation,
});

/// The columns [ids] of [specs], their headers read through [query].
List<ReportColumn> reportColumnsOf(
  List<String> ids,
  Map<String, ReportColumnSpec> specs,
  ReportQuery query,
) => [
  for (final id in ids)
    ReportColumn(
      identifier: id,
      displayLabel: query.label(specs[id]!.labelKey),
      type: specs[id]!.type,
      aggregation: specs[id]!.aggregation,
    ),
];

/// A text cell; [id] makes it a link to that record of [wire] — never one
/// that has not reached the server.
ReportStringCell reportText(String value, {String? wire, String? id}) =>
    ReportStringCell(
      value: value,
      displayValue: value,
      entityWire: wire,
      entityId: id == null || id.isEmpty || id.startsWith('tmp_') ? null : id,
    );

/// An amount in the row's currency.
ReportNumberCell reportMoney(Decimal? value) => ReportNumberCell(
  value: value,
  isMoney: true,
  displayValue: value?.toString(),
);

/// A plain number.
ReportNumberCell reportNumber(Decimal? value) =>
    ReportNumberCell(value: value, displayValue: value?.toString());

ReportDateCell reportDate(Date? value) =>
    ReportDateCell(value: value, displayValue: value?.toIso() ?? '');

/// A timestamp — UTC, as the formatter expects one.
ReportDateTimeCell reportDateTime(DateTime? value) => ReportDateTimeCell(
  value: value?.toUtc(),
  displayValue: value?.toUtc().toIso8601String() ?? '',
);

ReportBoolCell reportBool(bool value, ReportQuery query) => ReportBoolCell(
  value: value,
  displayValue: query.label(value ? 'yes' : 'no'),
);

/// Active, Archived or Deleted — v1's `record_state` column.
ReportStringCell reportRecordState({
  required bool isDeleted,
  required DateTime? archivedAt,
  required ReportQuery query,
}) => reportText(
  query.label(
    isDeleted
        ? 'deleted'
        : archivedAt != null
        ? 'archived'
        : 'active',
  ),
);

/// [ids]' records, each read with [read] — for a record kind with no batch
/// read — [kReportReadChunk] at a time, so a year of links does not open
/// thousands of reads at once. A record the device lacks has no entry.
Future<Map<String, E>> reportRecordsById<E>(
  Iterable<String> ids,
  Future<E?> Function(String id) read,
) async {
  final unique = {
    for (final id in ids)
      if (id.isNotEmpty) id,
  };
  final out = <String, E>{};
  for (final chunk in reportIdChunks(unique, kReportReadChunk)) {
    final found = await Future.wait([
      for (final id in chunk) read(id).then((r) => (id, r)),
    ]);
    for (final (id, record) in found) {
      if (record != null) out[id] = record;
    }
  }
  return out;
}

/// How many local reads [reportRecordsById] runs at once.
const int kReportReadChunk = 50;

/// [ids]' names through [reportRecordsById].
Future<Map<String, String>> reportNamesById<E>(
  Iterable<String> ids,
  Future<E?> Function(String id) read,
  String Function(E record) nameOf,
) async => {
  for (final MapEntry(:key, :value) in (await reportRecordsById(
    ids,
    read,
  )).entries)
    key: nameOf(value),
};

/// Fetch [ids] one request each, ten at a time, with [ensureLoaded].
Future<void> reportEnsureLoaded(
  Set<String>? ids,
  Future<Object?> Function(String id) ensureLoaded,
) async {
  for (final chunk in reportIdChunks(ids ?? const {}, 10)) {
    await Future.wait([for (final id in chunk) ensureLoaded(id)]);
  }
}
