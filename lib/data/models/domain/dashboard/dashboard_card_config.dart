/// Configuration for one user-added dashboard metric card — the Flutter port
/// of React's `dashboard_fields` entry
/// (`react/src/pages/dashboard/components/DashboardCardSelector.tsx`).
///
/// Each card = a [field] (one of [kDashboardCardFields]) × [period] ×
/// [calculate] × [format]. The tuple is fetched via
/// `POST /api/v1/charts/calculated_fields`. Hand-written (no codegen) to match
/// the rest of `models/domain/dashboard/` (see `dashboard_totals.dart`).
library;

enum CardPeriod { current, previous, total }

enum CardCalc { sum, avg, count }

/// How a card's value is rendered — and, for [none], the fact that the server
/// rejects the `format` key outright.
///
/// [none] exists for the task **count** fields: `ShowCalculatedFieldRequest`
/// errors when `format` is merely *present* for those, so the request builder
/// omits the key rather than sending a value. It is a member rather than a
/// nullable field so the 4-part persistence [DashboardCardConfig.key] keeps its
/// arity — `tryParse` rejects anything that isn't exactly four segments, so a
/// missing segment would silently drop every stored count card.
enum CardFormat { money, time, none }

/// The 19 field keys the server accepts (`ShowCalculatedFieldRequest`'s `in:`
/// list). The first 13 are React's `FIELDS` (`DashboardCardSelector.tsx`) in
/// its order; the six task fields after `paid_tasks` were added server-side on
/// 2026-08-31 and have no React counterpart.
///
/// The order documents React parity only — it does **not** drive the UI, which
/// sorts the options by localized label (`_cardsBody`).
const List<String> kDashboardCardFields = [
  'active_invoices',
  'outstanding_invoices',
  'completed_payments',
  'refunded_payments',
  'active_quotes',
  'unapproved_quotes',
  'logged_tasks',
  'invoiced_tasks',
  'paid_tasks',
  ...kTaskDurationCardFields,
  ...kTaskCountCardFields,
  'logged_expenses',
  'pending_expenses',
  'invoiced_expenses',
  'invoice_paid_expenses',
];

/// Fields the server requires to be `format: time` with a `sum`/`avg`
/// calculation — `ShowCalculatedFieldRequest::TASK_DURATION_FIELDS`. Values come
/// back as **seconds**.
const List<String> kTaskDurationCardFields = [
  'task_estimated_duration',
  'task_remaining_estimated_duration',
];

/// Fields the server requires to be `calculation: count` **with no `format` key
/// at all** — `ShowCalculatedFieldRequest::TASK_COUNT_FIELDS`. Values are plain
/// integers.
const List<String> kTaskCountCardFields = [
  'unestimated_tasks',
  'tasks_over_estimate',
  'overdue_tasks',
  'tasks_due',
];

/// Localization key for a field's card label. React's `FIELDS_LABELS` maps
/// every field to `total_<field>` (e.g. `active_invoices` →
/// `total_active_invoices`), and the six new keys follow the same convention.
String fieldLabelKey(String field) => 'total_$field';

/// Whether [field] renders as a duration.
///
/// **Not a name test.** React used `selectedField.endsWith('tasks')`, which we
/// mirrored — but that misclassifies four of the six fields added in 2026-08:
/// `task_estimated_duration` and `tasks_due` don't end in `tasks` while
/// `overdue_tasks` does and is a *count*. Every combination it got wrong is a
/// 422, so the classes are now explicit lists taken from the server's own
/// constants.
bool isDurationField(String field) => kTaskDurationCardFields.contains(field);

/// Whether [field] is a bare count — no currency, no duration, and no `format`
/// key on the wire.
bool isCountField(String field) => kTaskCountCardFields.contains(field);

/// The three original `*_tasks` fields, which may be viewed as either money or
/// time. The 2026-08 task fields are *not* in this set: their format is forced
/// by the server, so the picker offers no choice.
bool isTaskField(String field) =>
    field.endsWith('tasks') && !isCountField(field);

/// The only [CardFormat] the server will accept for [field], or null when the
/// user may choose (the money/time fields).
CardFormat? forcedFormatFor(String field) {
  if (isDurationField(field)) return CardFormat.time;
  if (isCountField(field)) return CardFormat.none;
  return null;
}

/// The format to use for [field] given a user's [desired] choice — the single
/// place that decision is made.
///
/// Both the picker and [DashboardCardConfig.tryParse] route through this. They
/// used to carry the same expression inline and it was subtly wrong in both:
/// `forcedFormatFor(f) ?? (isTaskField(f) ? desired : money)` **keeps a sticky
/// `none`** when moving from a count field to a money/time one, because
/// `isTaskField` is true there. That produced `logged_tasks|…|none`, whose
/// request omits `format` for a field that requires it — a permanent 422 card
/// that survived restart, with the format control showing neither option
/// selected.
CardFormat resolveFormatFor(String field, CardFormat desired) {
  final forced = forcedFormatFor(field);
  if (forced != null) return forced;
  // `none` is legal only for a count field; anywhere else it means the key
  // would be omitted from a request that requires it.
  if (!isTaskField(field) || desired == CardFormat.none) {
    return CardFormat.money;
  }
  return desired;
}

/// The only [CardCalc] the server will accept for [field], or null when the
/// user may choose. Duration fields accept `sum` **or** `avg`, so they are not
/// forced to a single value — see [allowedCalcsFor].
CardCalc? forcedCalcFor(String field) =>
    isCountField(field) ? CardCalc.count : null;

/// The calculations the server accepts for [field]. Count fields allow only
/// `count`; duration fields allow `sum`/`avg` but never `count`.
List<CardCalc> allowedCalcsFor(String field) {
  if (isCountField(field)) return const [CardCalc.count];
  if (isDurationField(field)) return const [CardCalc.sum, CardCalc.avg];
  return CardCalc.values;
}

class DashboardCardConfig {
  const DashboardCardConfig({
    required this.field,
    required this.period,
    required this.calculate,
    required this.format,
  });

  final String field;
  final CardPeriod period;
  final CardCalc calculate;
  final CardFormat format;

  /// Stable identity used as the persistence value and the per-card cache
  /// `kind` suffix. Matches React's encode (minus the trailing index, which
  /// only existed to disambiguate React's array keys — list order does that
  /// for us).
  String get key => '$field|${period.name}|${calculate.name}|${format.name}';

  /// Parse a `field|period|calculate|format` key. Returns null for anything
  /// malformed or referencing an unknown field/enum (callers skip it).
  static DashboardCardConfig? tryParse(Object? raw) {
    if (raw is! String) return null;
    final parts = raw.split('|');
    if (parts.length != 4) return null;
    final field = parts[0];
    if (!kDashboardCardFields.contains(field)) return null;
    final period = _byName(CardPeriod.values, parts[1]);
    var calc = _byName(CardCalc.values, parts[2]);
    var fmt = _byName(CardFormat.values, parts[3]);
    if (period == null || calc == null || fmt == null) return null;
    // Repair a stored tuple the server would now reject, rather than dropping
    // the card: the format/calculation rules are server-enforced, so a key
    // persisted before they existed (or hand-edited) must be coerced, not lost.
    fmt = resolveFormatFor(field, fmt);
    if (!allowedCalcsFor(field).contains(calc)) {
      calc = allowedCalcsFor(field).first;
    }
    return DashboardCardConfig(
      field: field,
      period: period,
      calculate: calc,
      format: fmt,
    );
  }

  /// Persisted form is just [key] — keeps the nav_state envelope compact and
  /// mirrors React storing an array of encoded strings.
  String toJson() => key;

  static T? _byName<T extends Enum>(List<T> values, String name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is DashboardCardConfig && other.key == key;

  @override
  int get hashCode => key.hashCode;
}
