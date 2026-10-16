import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import 'package:admin/data/models/domain/credit_status.dart';
import 'package:admin/data/models/domain/purchase_order_status.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/value/relative_date_token.dart';
import 'package:admin/domain/payment_status.dart';

/// Pure parsers that turn a list ViewModel's `extraFilters` map (the
/// server-bound filter dimensions) into the typed inputs each list DAO's
/// `watchPage` applies as **local Drift predicates** (billing docs, and the
/// task/project mirrors added for `task_status` / `project_tasks` /
/// `client_id` / `tag_ids`).
///
/// Why this exists: the standalone Invoice / Quote / Credit / Payment /
/// Expense lists render from the local Drift cache (`watchPage`), but only
/// the *server* fetch (`ensurePageLoaded`) was honoring `extraFilters`. The
/// local watch re-emitted the whole cache, so a `client:` / `status:` /
/// `date_range:` filter looked like it did nothing. These helpers + the
/// per-DAO predicates close that gap so the local view matches the server
/// filter exactly. Keeping the value parsing here (one source of truth,
/// one test target) avoids re-deriving the divergence-prone mappings —
/// especially the payment computed-status wire→id table — in five places.

/// `client_id` — membership set of client ids. Multi-value (the
/// `ClientFilterKey` is a union membership key).
Set<String> parseClientIdFilter(Map<String, Set<String>> extraFilters) =>
    extraFilters['client_id'] ?? const <String>{};

/// The wire form of a client scope. `client_id` stays the stored key (the
/// local predicate reads it through [parseClientIdFilter]), but the server's
/// `QueryFilters::client_id` decodes ONE hashid: `client_id=a,b` does not
/// decode, and every list answered it with zero rows (measured on the demo
/// server, 5.13.47). Two or more ids therefore move into `client_ids`, the
/// base `whereIn` param (server 5.13.13+), merging with any value already
/// there. A `tmp_` id — a client created offline — is left off when real ids
/// sit beside it, since it would not decode either; an all-`tmp_` scope is
/// kept as is, for the repository's own nothing-to-fetch short-circuit.
/// Returns [extraFilters] itself when there is nothing to move.
Map<String, Set<String>> clientScopeForWire(
  Map<String, Set<String>> extraFilters,
) {
  final single = extraFilters['client_id'] ?? const <String>{};
  final listed = extraFilters['client_ids'] ?? const <String>{};
  if (single.length + listed.length < 2) return extraFilters;
  var ids = {...single, ...listed};
  if (ids.any((id) => !id.startsWith('tmp_'))) {
    ids = {
      for (final id in ids)
        if (!id.startsWith('tmp_')) id,
    };
  }
  return {
    for (final entry in extraFilters.entries)
      if (entry.key != 'client_id') entry.key: entry.value,
    'client_ids': ids,
  };
}

/// Generic CSV membership set for any `whereIn`-style server param whose
/// values are stored verbatim (payload id form) in a denormalized column:
/// `country_id`, `industry_id`, `size_id`, `classification`,
/// `group_settings_id`, `assigned_user_id`, expense `project_ids`/`vendor_ids`.
/// No decode — the column holds the same id form the FilterKey emits.
Set<String> parseCsvFilter(Map<String, Set<String>> extraFilters, String key) =>
    extraFilters[key] ?? const <String>{};

/// Single value pulled from a single-value FilterKey slot: `vat_number`
/// (applied as a substring LIKE) and `number` (applied as an exact match —
/// the server reverted `number=` to exact). `id_number` is a multi-value
/// membership key — use [parseCsvFilter] for it instead. Take the first if
/// present.
String? parseSubstringFilter(
  Map<String, Set<String>> extraFilters,
  String key,
) {
  final values = extraFilters[key];
  if (values == null || values.isEmpty) return null;
  final v = values.first.trim();
  return v.isEmpty ? null : v;
}

/// Invoice `status_id` — already the persisted numeric wire ids `'1'..'6'`,
/// so they map straight onto the `statusId` column.
Set<String> parseInvoiceStatusFilter(Map<String, Set<String>> extraFilters) =>
    extraFilters['status_id'] ?? const <String>{};

/// Recurring-invoice `status_id` — stored discriminators `'1'..'4'`
/// (draft/active/paused/completed), filtered directly against the `statusId`
/// column. Mirrors React's server-side `status_id` filter (no computed-status
/// remap: completed/pending are display-only derivations).
Set<String> parseRecurringInvoiceStatusFilter(
  Map<String, Set<String>> extraFilters,
) => extraFilters['status_id'] ?? const <String>{};

/// Invoice `overdue:true` — single boolean dimension.
bool parseOverdueFilter(Map<String, Set<String>> extraFilters) =>
    (extraFilters['overdue'] ?? const <String>{}).contains('true');

/// Expense `categories` — membership set of category ids (the server param
/// is `categories`; the local column is `category_id`).
Set<String> parseExpenseCategoryFilter(Map<String, Set<String>> extraFilters) =>
    extraFilters['categories'] ?? const <String>{};

/// Expense `client_status` — computed-status wire labels
/// (`logged|pending|invoiced|paid|unpaid`). Expense status is derived
/// client-side, so `ExpenseDao.watchPage` turns these into a single OR
/// predicate over the denormalized `invoice_id` / `should_be_invoiced` /
/// `is_paid` columns, mirroring admin-portal `Expense.matchesStatuses`.
Set<String> parseExpenseStatusFilter(Map<String, Set<String>> extraFilters) =>
    extraFilters['client_status'] ?? const <String>{};

/// Quote `client_status` — wire labels (`draft|sent|approved|expired|
/// upcoming|converted|cancelled`). Passed through verbatim; `QuoteDao.watchPage`
/// turns the enumerated + computed members into a single OR predicate
/// mirroring `Quote.calculatedStatusId` / `Quote.isExpired`.
Set<String> parseQuoteStatusFilter(Map<String, Set<String>> extraFilters) =>
    extraFilters['client_status'] ?? const <String>{};

/// Credit `client_status` — wire labels (`draft|sent|partial|applied`). Unlike
/// quotes there are no computed states, so each label maps 1:1 to a stored
/// `status_id` wire id (built from the [CreditStatus] enum so the table can't
/// drift); `CreditDao.watchPage` applies a plain `whereIn(status_id, …)`.
/// Mirrors the server `CreditFilters::client_status`.
Set<String> parseCreditStatusFilter(Map<String, Set<String>> extraFilters) {
  final labels = extraFilters['client_status'] ?? const <String>{};
  if (labels.isEmpty) return const <String>{};
  return {
    for (final s in CreditStatus.values)
      if (labels.contains(s.name)) s.wireId,
  };
}

/// Purchase order `client_status` — wire labels (`draft|sent|accepted|
/// cancelled`), each a stored `status_id`, mirroring the plain `whereIn` of
/// `PurchaseOrderFilters::client_status`. `received` has no branch there, so
/// no chip offers it and nothing maps it.
Set<String> parsePurchaseOrderStatusFilter(
  Map<String, Set<String>> extraFilters,
) {
  final labels = extraFilters['client_status'] ?? const <String>{};
  if (labels.isEmpty) return const <String>{};
  return {
    for (final s in PurchaseOrderStatus.values)
      if (s != PurchaseOrderStatus.received && labels.contains(s.name))
        s.wireId,
  };
}

/// Payment `client_status` — wire labels. Map to the `statusId` discriminators
/// `PaymentDao.watchPage` already understands (numeric `'1'..'6'` plus the
/// virtual `kPaymentStatusPartiallyUnapplied` `'-2'`). Mirrors
/// `kPaymentStatusLabels` (the inverse of that table) so the local predicate
/// and `Payment.calculatedStatusId` stay in lockstep.
Set<String> parsePaymentStatusFilter(Map<String, Set<String>> extraFilters) {
  final wire = extraFilters['client_status'] ?? const <String>{};
  if (wire.isEmpty) return const <String>{};
  const byLabel = <String, String>{
    'pending': kPaymentStatusPending,
    'cancelled': kPaymentStatusCancelled,
    'failed': kPaymentStatusFailed,
    'completed': kPaymentStatusCompleted,
    'partially_refunded': kPaymentStatusPartiallyRefunded,
    'refunded': kPaymentStatusRefunded,
    'partially_unapplied': kPaymentStatusPartiallyUnapplied,
    'unapplied': kPaymentStatusUnapplied,
  };
  return {
    for (final w in wire)
      if (byLabel[w] != null) byLabel[w]!,
  };
}

/// Resolves a relative-date token to an absolute value.
///
/// A `ComparableFilterKey` / `DateColumnFilterKey` may store a **rolling**
/// value so a saved filter keeps meaning "7 days ago" or "this month" as time
/// passes. [RelativeDateToken] owns the grammar (`rel:h24`, `rel:d7`,
/// `rel:m0s` …) and the arithmetic; this is the entry point the filter code
/// calls. It must run before the value reaches the API or a Drift query —
/// the server never sees a `rel:` token.
///
///  * `rel:dN` and the calendar-period bounds → an ISO `YYYY-MM-DD`.
///  * `rel:hN` → the UTC instant `YYYY-MM-DDTHH:mm:ssZ` (see
///    [HoursAgoToken.resolve]).
///
/// Returns null when [token] is not a relative token this build can read.
String? resolveRelativeDateToken(String token, {DateTime? now}) =>
    RelativeDateToken.tryParse(token)?.resolve(now: now);

/// Rewrites every `rel:` token in an `extraFilters` map to its absolute form
/// (preserving any `op:` prefix and every non-relative value untouched). Call
/// this once as a pre-pass wherever `extraFilters` is turned into an API
/// query — the server must never receive a `rel:` token. Returns the input
/// map unchanged (same instance) when nothing relative is present, so the
/// common path is allocation-free.
///
/// A value carrying a token this build cannot read (one written by a newer
/// build, restored from a salvaged store) is DROPPED, not sent: as text it
/// would fail to parse on the server, and a filter that is silently skipped
/// is worse than one visibly absent from the fetch. The local predicates
/// treat it as no predicate too, so such a chip narrows nothing anywhere.
Map<String, Set<String>> resolveRelativeFilterTokens(
  Map<String, Set<String>> extraFilters, {
  DateTime? now,
}) {
  var touched = false;
  final out = <String, Set<String>>{};
  for (final entry in extraFilters.entries) {
    final resolved = <String>{};
    for (final v in entry.value) {
      if (!RelativeDateToken.inValue.hasMatch(v)) {
        resolved.add(v);
        continue;
      }
      touched = true;
      final r = _resolveTokensIn(v, now: now);
      if (r != null) resolved.add(r);
    }
    out[entry.key] = resolved;
  }
  return touched ? out : extraFilters;
}

/// [value] with every `rel:` token in it resolved, or null when one of them
/// cannot be.
String? _resolveTokensIn(String value, {DateTime? now}) {
  var failed = false;
  final out = value.replaceAllMapped(RelativeDateToken.inValue, (m) {
    final r = resolveRelativeDateToken(m.group(0)!, now: now);
    if (r == null) failed = true;
    return r ?? m.group(0)!;
  });
  return failed ? null : out;
}

/// A closed `[start, end]` date window (inclusive), or `(null, null)` when
/// absent / malformed. Arity-tolerant: the canonical v5 wire is 3-part
/// `"<column>,<start>,<end>"`, but a legacy 2-part `"<start>,<end>"`
/// (pre-upgrade persisted filter) or 3-part `"<label>,<start>,<end>"`
/// (old payment shape) all resolve by taking the **last two** comma-parts.
/// Values are ISO `YYYY-MM-DD`, which compare correctly against the `date`
/// TEXT column lexicographically.
({String? start, String? end}) parseDateRangeFilter(
  Map<String, Set<String>> extraFilters, {
  DateTime? now,
}) => _parseWindowFilter(extraFilters, 'date_range', now: now);

/// `due_date_range` — the symmetric closed `[start, end]` window on the
/// `due_date` column (the `DateColumnFilterKey(id: 'due_date')`
/// `between` comparator). Same arity-tolerant 3-part / 2-part wire as
/// [parseDateRangeFilter].
({String? start, String? end}) parseDueDateRangeFilter(
  Map<String, Set<String>> extraFilters, {
  DateTime? now,
}) => _parseWindowFilter(extraFilters, 'due_date_range', now: now);

/// `updated_at_range` / `created_at_range` — the closed `[start, end]`
/// windows on the clients list's `updated_at` / `created_at` columns (the
/// `DateColumnFilterKey(id: 'updated' | 'created')` `between` comparator).
/// Same arity-tolerant 3-part / 2-part wire as [parseDateRangeFilter]; ISO
/// `YYYY-MM-DD` strings (`ClientRepository` converts them to the epoch-second
/// day bounds its DAO compares against).
({String? start, String? end}) parseUpdatedAtRangeFilter(
  Map<String, Set<String>> extraFilters, {
  DateTime? now,
}) => _parseWindowFilter(extraFilters, 'updated_at_range', now: now);

({String? start, String? end}) parseCreatedAtRangeFilter(
  Map<String, Set<String>> extraFilters, {
  DateTime? now,
}) => _parseWindowFilter(extraFilters, 'created_at_range', now: now);

/// The window in [key], each bound resolved if it is a rolling token (This
/// month is `date,rel:m0s,rel:m0e`). A bound that cannot be resolved gives no
/// window at all: comparing a date column against the text `rel:…` matches
/// every row or none, and the list would look unfiltered or empty.
({String? start, String? end}) _parseWindowFilter(
  Map<String, Set<String>> extraFilters,
  String key, {
  DateTime? now,
}) {
  final raw = (extraFilters[key] ?? const <String>{});
  if (raw.isEmpty) return (start: null, end: null);
  final parts = raw.first.split(',');
  if (parts.length < 2) return (start: null, end: null);
  final start = _resolveBound(parts[parts.length - 2].trim(), now);
  final end = _resolveBound(parts[parts.length - 1].trim(), now);
  if (start == null || end == null) return (start: null, end: null);
  if (start.isEmpty || end.isEmpty) return (start: null, end: null);
  return (start: start, end: end);
}

String? _resolveBound(String bound, DateTime? now) => bound.startsWith('rel:')
    ? resolveRelativeDateToken(bound, now: now)
    : bound;

const Set<String> _comparableDateOps = {'gt', 'gte', 'lt', 'lte', 'eq'};

/// Single-amount comparator slot for a `ComparableFilterKey` over a money
/// column (the clients list's `balance`). The canonical wire is the prefix
/// `op:value` form the server's `QueryFilters::split()` reads; the legacy
/// suffix `value:op` (persisted by older builds) and a bare value — read as
/// `gt`, `BalanceFilterKey.defaultOp`, which is how the chip shows it — are
/// decoded too. The value comes back as a canonical `Decimal` string, so no
/// money passes through a `double`; `(null, null)` when the slot is absent or
/// the value is not a number.
({String? op, String? value}) parseComparableAmountFilter(
  Map<String, Set<String>> extraFilters,
  String key,
) {
  final raw = extraFilters[key] ?? const <String>{};
  if (raw.isEmpty) return (op: null, value: null);
  final wire = raw.first.trim();
  var op = 'gt';
  var value = wire;
  final idx = wire.indexOf(':');
  if (idx > 0) {
    final head = wire.substring(0, idx);
    final tail = wire.substring(idx + 1);
    if (_comparableDateOps.contains(head)) {
      op = head;
      value = tail;
    } else if (_comparableDateOps.contains(tail)) {
      op = tail;
      value = head;
    } else {
      return (op: null, value: null);
    }
  }
  final amount = Decimal.tryParse(value.trim());
  if (amount == null) return (op: null, value: null);
  return (op: op, value: amount.toString());
}

/// Single-date comparator slot for a `DateColumnFilterKey` (e.g. the
/// transactions `date` filter). Wire is `op:value` (`gte:2026-01-01`) or a bare
/// `value` (defaulting to `gte`, matching the key's `defaultOp`). Relative
/// tokens (`rel:d7`) are resolved to absolute ISO first so the DB never sees
/// one. Returns `(op, value)` with op ∈ gt|gte|lt|lte|eq, or `(null, null)`
/// when the slot is absent/blank or holds a comma (a window wire — that lives in
/// the `*_range` slot and is read by [parseDateRangeFilter]). Values are ISO
/// `YYYY-MM-DD`, which compare correctly against a `date` TEXT column.
({String? op, String? value}) parseComparableDateFilter(
  Map<String, Set<String>> extraFilters,
  String key, {
  DateTime? now,
}) {
  final raw = extraFilters[key] ?? const <String>{};
  if (raw.isEmpty) return (op: null, value: null);
  final stored = raw.first.trim();
  if (stored.isEmpty || stored.contains(',')) return (op: null, value: null);
  // Resolve a `rel:` token (bare or after an `op:` prefix) to absolute ISO;
  // one this build cannot read gives no predicate.
  final wire = _resolveTokensIn(stored, now: now);
  if (wire == null) return (op: null, value: null);
  final idx = wire.indexOf(':');
  if (idx > 0 && _comparableDateOps.contains(wire.substring(0, idx))) {
    final value = wire.substring(idx + 1).trim();
    if (value.isEmpty) return (op: null, value: null);
    return (op: wire.substring(0, idx), value: value);
  }
  return (op: 'gte', value: wire);
}

/// Inclusive epoch-second bounds for a filter over a TIMESTAMP column stored
/// as epoch seconds (a client's or vendor's `created_at` / `updated_at`).
///
/// The `<key>_range` window wins when set, as one key never fills both. A
/// bare ISO date spans its whole UTC day — start at 00:00:00, end at
/// 23:59:59 — matching the server's per-day reading of a date-only value
/// (`QueryFilters::comparableDatetime`). A value with a time in it (a resolved
/// `rel:hN`, `…T…Z`) is an instant and compares exactly, as the server does:
/// "1 hour ago" used to be cut to its day here, so it meant "since UTC
/// midnight" on the device. [now] resolves rolling tokens.
({int? from, int? to}) timestampBounds(
  Map<String, Set<String>> extraFilters, {
  required String singleKey,
  required String rangeKey,
  DateTime? now,
}) {
  final window = _parseWindowFilter(extraFilters, rangeKey, now: now);
  final windowFrom = _isoDayStartEpoch(window.start);
  final windowTo = _isoDayEndEpoch(window.end);
  if (windowFrom != null || windowTo != null) {
    return (from: windowFrom, to: windowTo);
  }
  final cmp = parseComparableDateFilter(extraFilters, singleKey, now: now);
  final v = cmp.value;
  if (v == null) return (from: null, to: null);
  if (v.contains('T')) {
    final instant = DateTime.tryParse(v);
    if (instant == null) return (from: null, to: null);
    final e = instant.millisecondsSinceEpoch ~/ 1000;
    return switch (cmp.op) {
      'gt' => (from: e + 1, to: null),
      'lt' => (from: null, to: e - 1),
      'lte' => (from: null, to: e),
      'eq' => (from: e, to: e),
      _ => (from: e, to: null),
    };
  }
  final start = _isoDayStartEpoch(v);
  final end = _isoDayEndEpoch(v);
  return switch (cmp.op) {
    'gt' => (from: end == null ? null : end + 1, to: null),
    'lt' => (from: null, to: start == null ? null : start - 1),
    'lte' => (from: null, to: end),
    'eq' => (from: start, to: end),
    _ => (from: start, to: null),
  };
}

/// The server params a `DateColumnFilterKey` window on a timestamp column
/// travels as. The keys store a 3-part `<column>,<start>,<end>` window under
/// `created_at_range` / `updated_at_range`, names the server has no handler
/// for (`QueryFilters::apply()` skips unknown params silently); what it
/// honours is `created_between` / `updated_between`, a 2-part `<start>,<end>`.
const Map<String, String> _timestampWindowServerParams = {
  'created_at_range': 'created_between',
  'updated_at_range': 'updated_between',
};

/// Rewrites the timestamp window slots of [extraFilters] into the params the
/// server reads (see [_timestampWindowServerParams]) for the FETCH only — the
/// local watch keeps reading the `*_at_range` keys.
///
/// Rolling bounds are resolved first, against [now]. A bare end DATE is then
/// stretched to `23:59:59` of that day: `whereBetween` takes a bare date as
/// 00:00, so the server used to leave the window's last day out while the
/// local list kept it — measured on the demo server, `created_between=D,D`
/// matched nothing created on D. Returns the input itself when no window slot
/// is set.
Map<String, Set<String>> timestampWindowsForServer(
  Map<String, Set<String>> extraFilters, {
  DateTime? now,
}) {
  if (!extraFilters.keys.any(_timestampWindowServerParams.containsKey)) {
    return extraFilters;
  }
  final resolved = resolveRelativeFilterTokens(extraFilters, now: now);
  final out = <String, Set<String>>{};
  for (final entry in resolved.entries) {
    final serverKey = _timestampWindowServerParams[entry.key];
    if (serverKey == null) {
      out[entry.key] = entry.value;
      continue;
    }
    final window = _parseWindowFilter(resolved, entry.key);
    final start = window.start;
    var end = window.end;
    if (start == null || end == null) continue;
    if (_isoDate.hasMatch(end)) end = '$end 23:59:59';
    out[serverKey] = {'$start,$end'};
  }
  return out;
}

final _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// For a list whose server can filter a date column only by window — a
/// purchase order's or an expense's `date`, which `*Filters.php` reads through
/// the base `date_range` / `due_date_range` and nothing else: each
/// single-date comparator in [extraFilters] (`date=gte:2026-05-14`) becomes
/// the window that means the same (`date_range=date,2026-05-14,9999-12-31`)
/// for the FETCH, so the server narrows exactly what the local predicate
/// will. Sent as is, the comparator was skipped and every page came back
/// unfiltered. [columns] maps each single key to its window key; the window
/// slot wins where both are set (the key never fills both). Rolling bounds
/// are resolved first, against [now].
Map<String, Set<String>> singleDatesAsServerWindows(
  Map<String, Set<String>> extraFilters,
  Map<String, String> columns, {
  DateTime? now,
}) {
  if (!columns.keys.any(extraFilters.containsKey)) return extraFilters;
  final out = Map<String, Set<String>>.of(extraFilters);
  for (final MapEntry(key: single, value: windowKey) in columns.entries) {
    final cmp = parseComparableDateFilter(extraFilters, single, now: now);
    out.remove(single);
    final value = cmp.value;
    if (value == null || !_isoDate.hasMatch(value)) continue;
    if ((extraFilters[windowKey] ?? const <String>{}).isNotEmpty) continue;
    final day = Date.tryParse(value);
    if (day == null) continue;
    const first = '1000-01-01';
    const last = '9999-12-31';
    final (lo, hi) = switch (cmp.op) {
      'gt' => (day.addDays(1).toIso(), last),
      'lt' => (first, day.addDays(-1).toIso()),
      'lte' => (first, value),
      'eq' => (value, value),
      _ => (value, last),
    };
    out[windowKey] = {'$single,$lo,$hi'};
  }
  return out;
}

int? _isoDayStartEpoch(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final d = DateTime.tryParse(iso);
  if (d == null) return null;
  return DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 1000;
}

int? _isoDayEndEpoch(String? iso) {
  final start = _isoDayStartEpoch(iso);
  return start == null ? null : start + 86399;
}

/// Drift predicate for a single-date comparator (`>`, `>=`, `<`, `<=`, `=`) on
/// an ISO `YYYY-MM-DD` TEXT column, or null when the slot is empty.
///
/// `DateColumnFilterKey` stores `between` in the `<key>_range` slot and every
/// other operator in the `<key>` slot as an `op:value` wire. The billing repos
/// read only the range slot, so a bare `date:2026-06-01` (which defaults to
/// `gte`) narrowed the SERVER fetch while the local watch applied no date
/// predicate at all — the list re-emitted unfiltered cached rows. Pair this
/// with [parseComparableDateFilter]. `gte` is the fallback so it matches
/// `DateColumnFilterKey.defaultOp`.
Expression<bool>? comparableDatePredicate(
  GeneratedColumn<String> column, {
  required String? op,
  required String? value,
}) {
  if (value == null || value.isEmpty) return null;
  // These columns default to `''` (an unset date), and in SQLite
  // `'' < '2026-08-01'` is TRUE — so a naive `<` / `<=` sweeps in every row
  // with no date at all, which the server (comparing a real DATE column,
  // where NULL comparisons are false) excludes. Compare against the
  // NULL-ified column so an empty date matches nothing, mirroring
  // `quote_dao`'s existing `NULLIF(due_date, '')` idiom.
  final notEmpty = CustomExpression<String>("NULLIF(${column.name}, '')");
  return switch (op) {
    'gt' => notEmpty.isBiggerThanValue(value),
    'lt' => notEmpty.isSmallerThanValue(value),
    'lte' => notEmpty.isSmallerOrEqualValue(value),
    'eq' => notEmpty.equals(value),
    _ => notEmpty.isBiggerOrEqualValue(value),
  };
}
