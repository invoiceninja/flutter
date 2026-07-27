import 'package:drift/drift.dart';

import 'package:admin/data/models/domain/credit_status.dart';
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
/// upcoming|converted`). Passed through verbatim; `QuoteDao.watchPage`
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
/// A `ComparableFilterKey` may store a **rolling** value so a saved
/// filter keeps meaning "7 days ago" as time passes. The wire token is
/// `rel:<unit><n>` — `rel:h24` (24 hours ago) / `rel:d7` (7 days ago).
/// This is the single source of truth for turning that into an absolute
/// value; it must run before the value reaches the API or a Drift query
/// (the server never sees a `rel:` token).
///
///  * `rel:dN` → date-only `YYYY-MM-DD` of `now - N days` (the backend
///    applies a per-calendar-day `whereDate`).
///  * `rel:hN` → second-precision `YYYY-MM-DDTHH:mm:ss` of
///    `now - N hours` (the backend applies an exact `where`).
///
/// Returns null when [token] is not a relative token.
String? resolveRelativeDateToken(String token, {DateTime? now}) {
  final m = RegExp(r'^rel:([hd])(\d+)$').firstMatch(token.trim());
  if (m == null) return null;
  final unit = m.group(1)!;
  final n = int.parse(m.group(2)!);
  final base = now ?? DateTime.now();
  if (unit == 'd') {
    final d = base.subtract(Duration(days: n));
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
  final t = base.subtract(Duration(hours: n));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}'
      'T${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

final _relTokenInValue = RegExp(r'rel:[hd]\d+');

/// Rewrites every `rel:<unit><n>` occurrence in an `extraFilters` map to
/// its absolute form (preserving any `op:` prefix and every non-relative
/// value untouched). Call this once as a pre-pass wherever `extraFilters`
/// is turned into an API query or a Drift query — the server / DB must
/// never receive a `rel:` token. Returns the input map unchanged (same
/// instance) when nothing relative is present, so the common path is
/// allocation-free.
Map<String, Set<String>> resolveRelativeFilterTokens(
  Map<String, Set<String>> extraFilters, {
  DateTime? now,
}) {
  var touched = false;
  final out = <String, Set<String>>{};
  for (final entry in extraFilters.entries) {
    final resolved = <String>{};
    for (final v in entry.value) {
      if (_relTokenInValue.hasMatch(v)) {
        touched = true;
        resolved.add(
          v.replaceAllMapped(
            _relTokenInValue,
            (m) =>
                resolveRelativeDateToken(m.group(0)!, now: now) ?? m.group(0)!,
          ),
        );
      } else {
        resolved.add(v);
      }
    }
    out[entry.key] = resolved;
  }
  return touched ? out : extraFilters;
}

/// A closed `[start, end]` date window (inclusive), or `(null, null)` when
/// absent / malformed. Arity-tolerant: the canonical v5 wire is 3-part
/// `"<column>,<start>,<end>"`, but a legacy 2-part `"<start>,<end>"`
/// (pre-upgrade persisted filter) or 3-part `"<label>,<start>,<end>"`
/// (old payment shape) all resolve by taking the **last two** comma-parts.
/// Values are ISO `YYYY-MM-DD`, which compare correctly against the `date`
/// TEXT column lexicographically.
({String? start, String? end}) parseDateRangeFilter(
  Map<String, Set<String>> extraFilters,
) => _parseWindowFilter(extraFilters, 'date_range');

/// `due_date_range` — the symmetric closed `[start, end]` window on the
/// `due_date` column (the `DateColumnFilterKey(id: 'due_date')`
/// `between` comparator). Same arity-tolerant 3-part / 2-part wire as
/// [parseDateRangeFilter].
({String? start, String? end}) parseDueDateRangeFilter(
  Map<String, Set<String>> extraFilters,
) => _parseWindowFilter(extraFilters, 'due_date_range');

/// `updated_at_range` / `created_at_range` — the closed `[start, end]`
/// windows on the clients list's `updated_at` / `created_at` columns (the
/// `DateColumnFilterKey(id: 'updated' | 'created')` `between` comparator).
/// Same arity-tolerant 3-part / 2-part wire as [parseDateRangeFilter]; ISO
/// `YYYY-MM-DD` strings (`ClientRepository` converts them to the epoch-second
/// day bounds its DAO compares against).
({String? start, String? end}) parseUpdatedAtRangeFilter(
  Map<String, Set<String>> extraFilters,
) => _parseWindowFilter(extraFilters, 'updated_at_range');

({String? start, String? end}) parseCreatedAtRangeFilter(
  Map<String, Set<String>> extraFilters,
) => _parseWindowFilter(extraFilters, 'created_at_range');

({String? start, String? end}) _parseWindowFilter(
  Map<String, Set<String>> extraFilters,
  String key,
) {
  final raw = (extraFilters[key] ?? const <String>{});
  if (raw.isEmpty) return (start: null, end: null);
  final parts = raw.first.split(',');
  if (parts.length < 2) return (start: null, end: null);
  final start = parts[parts.length - 2].trim();
  final end = parts[parts.length - 1].trim();
  if (start.isEmpty || end.isEmpty) return (start: null, end: null);
  return (start: start, end: end);
}

const Set<String> _comparableDateOps = {'gt', 'gte', 'lt', 'lte', 'eq'};

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
  var wire = raw.first.trim();
  if (wire.isEmpty || wire.contains(',')) return (op: null, value: null);
  // Resolve a `rel:` token (bare or after an `op:` prefix) to absolute ISO.
  wire = wire.replaceAllMapped(
    _relTokenInValue,
    (m) => resolveRelativeDateToken(m.group(0)!, now: now) ?? m.group(0)!,
  );
  final idx = wire.indexOf(':');
  if (idx > 0 && _comparableDateOps.contains(wire.substring(0, idx))) {
    final value = wire.substring(idx + 1).trim();
    if (value.isEmpty) return (op: null, value: null);
    return (op: wire.substring(0, idx), value: value);
  }
  return (op: 'gte', value: wire);
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
