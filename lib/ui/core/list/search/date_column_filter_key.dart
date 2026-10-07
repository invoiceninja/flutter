import 'package:flutter/widgets.dart';

import 'package:admin/data/db/dao/billing_extra_filters.dart'
    show resolveRelativeDateToken;
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';
import 'package:admin/utils/formatting.dart';

/// Generic comparable filter on a single date column (`date`,
/// `due_date`, …) for the billing-doc lists.
///
/// **Two storage slots.** Single-date comparators (`>` / `>=` / `<` /
/// `<=` / `=`) live in the comparable slot `extraFilters[serverKey]`
/// (`op:value` wire) and reuse all of [ComparableFilterKey]. The
/// closed-window [FilterOp.between] comparator lives in a separate
/// **range slot** `extraFilters['${serverKey}_range']` with the proven
/// 3-part wire `"<column>,<start>,<end>"` — the exact contract the
/// dashboard deep-links emit (`extraFilters['date_range']`) and
/// `parseDateRangeFilter` decodes. No new server operator: `between` is
/// routed to `date_range` / `due_date_range`, not `operatorConvertor()`.
///
/// The two-slot branching is deliberately contained here so
/// [ComparableFilterKey] stays a generic single-slot `op:value` mixin.
class DateColumnFilterKey extends FilterKey with ComparableFilterKey {
  const DateColumnFilterKey({
    required this.id,
    required this.serverKey,
    required String labelKey,
    String hintKey = 'created_filter_hint',
    this.windowOnly = false,
    this.isPrimary = false,
  }) : _labelKey = labelKey,
       _hintKey = hintKey;

  /// Set for the one date an entity is usually filtered by (a document's
  /// `date`), so it leads the picker's Suggested block. See
  /// [FilterKey.isPrimary].
  @override
  final bool isPrimary;

  /// Only the date-window comparator ([FilterOp.between]) — for an entity
  /// whose server filters this column by `<col>_range` alone, with no
  /// single-date comparable twin. Tasks are one: `TaskFilters` has no
  /// `due_date` method, only the base `due_date_range`, so a `>= date` chip
  /// would narrow nothing server-side. A single date typed here becomes the
  /// one-day window.
  final bool windowOnly;

  @override
  final String id;

  @override
  final String serverKey;

  final String _labelKey;

  /// Localization key for the value-entry hint. Defaults to the
  /// clients-phrased `created_filter_hint` (kept for the billing call sites,
  /// which all relied on that fixed copy); the clients `updated` key passes
  /// `updated_filter_hint` so its hint reads "…updated after".
  final String _hintKey;

  /// Window slot for [FilterOp.between]. `date` → `date_range`,
  /// `due_date` → `due_date_range` — both are the param names the
  /// dashboard deep-link and `parseDateRangeFilter` already use.
  String get rangeServerKey => '${serverKey}_range';

  @override
  String displayLabel(BuildContext context) => context.tr(_labelKey);

  @override
  FilterValueType get valueType => FilterValueType.date;

  @override
  List<FilterOp> get supportedOps => windowOnly
      ? const [FilterOp.between]
      : const [
          FilterOp.gt,
          FilterOp.gte,
          FilterOp.lt,
          FilterOp.lte,
          FilterOp.eq,
          FilterOp.between,
        ];

  @override
  FilterOp get defaultOp => windowOnly ? FilterOp.between : FilterOp.gte;

  @override
  String? hintForValueMode(BuildContext context) => context.tr(_hintKey);

  // ── Typed input ──────────────────────────────────────────────────────

  /// A digit either side of a date separator, or a run of letters (a month
  /// name, `tomorrow`). [parseDateInput] also accepts bare shortcuts — `20`,
  /// `+1`, `0514` — which are right for a date FIELD the user is committing
  /// on blur, but here they would turn `2026-05-14` into a filter for "the
  /// 20th" two characters in, and Enter would commit it.
  static final _unambiguousDate = RegExp(r'\d\s*[-/.]\s*\d|[A-Za-z]{3}');

  static final _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// The date the user TYPED after `<key>:`, with any operator they typed in
  /// front of it (`>=5/14`). Null when [typed] is not an unambiguous date —
  /// the menu then keeps offering the comparator → preset picker.
  ///
  /// `today` / `yesterday` come back as rolling `rel:` tokens so a saved view
  /// keeps meaning "today"; a [windowOnly] key has no rolling form (its wire
  /// is a closed range), so there they resolve to the absolute date.
  ({String value, FilterOp? op})? parseTypedDate(
    String typed, {
    String? activePattern,
    DateTime? now,
  }) {
    final split = splitTypedOperator(typed);
    final t = split.value;
    // No comma test here: `May 14, 2026` has one and is a single date. A
    // typed WINDOW (`2026-01-01,2026-02-01`) simply fails to parse as one.
    if (t.isEmpty) return null;
    if (resolveRelativeDateToken(t) != null) {
      return (value: t, op: split.op);
    }
    final keyword = switch (t.toLowerCase()) {
      'today' => 'rel:d0',
      'yesterday' => 'rel:d1',
      _ => null,
    };
    if (keyword != null) {
      return (
        value: windowOnly
            ? resolveRelativeDateToken(keyword, now: now)!
            : keyword,
        op: split.op,
      );
    }
    if (!_unambiguousDate.hasMatch(t)) return null;
    final date = parseDateInput(t, activePattern: activePattern, now: now);
    if (date == null) return null;
    String two(int v) => v.toString().padLeft(2, '0');
    return (
      value: '${date.year}-${two(date.month)}-${two(date.day)}',
      op: split.op,
    );
  }

  /// The company's date pattern, for [parseTypedDate] — so `14/5/2026` reads
  /// the way the rest of the app shows dates to this user.
  String? activeDatePattern(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
  ) {
    final formatter = _formatterOrNull(vm, context);
    return formatter?.dateFormats[formatter.settings.dateFormatId]?.format;
  }

  @override
  String? normalizeTypedValue(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String typed,
  ) {
    // A single date first: it may legitimately contain a comma, which is
    // also what marks a window.
    final parsed = parseTypedDate(
      typed,
      activePattern: activeDatePattern(vm, context),
    );
    if (parsed != null) {
      if (windowOnly) return canonicalWindow(parsed.value, parsed.value);
      return buildWire(parsed.value, parsed.op ?? defaultOp);
    }
    if (isWindowWire(typed)) {
      final (start, end) = parseWindow(typed);
      return _isoDate.hasMatch(start) && _isoDate.hasMatch(end) ? typed : null;
    }
    return null;
  }

  /// An absolute date reads the company's way on the chip, matching the
  /// between-window chip below (which always did) — a single date used to
  /// show raw ISO beside it.
  @override
  String chipValueLabel(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String value,
  ) {
    final label = relativeValueLabel(context, value);
    if (label != value || !_isoDate.hasMatch(value)) return label;
    final formatted = _formatterOrNull(vm, context)?.date(value) ?? '';
    return formatted.isEmpty ? value : formatted;
  }

  // ── Window-wire helpers ──────────────────────────────────────────────

  /// A window wire is the canonical `<col>,<start>,<end>`, the legacy
  /// 2-part `<start>,<end>`, or the prefixed `between:<start>,<end>`.
  /// Single-date comparable wires (`gte:2026-01-01`, `2026-01-01`) never
  /// contain a comma, so a comma unambiguously means "window".
  bool isWindowWire(String wire) {
    final w = wire.trim();
    return w.startsWith('between:') || w.contains(',');
  }

  /// Decode any window shape to `(start, end)` — arity-tolerant, taking
  /// the **last two** comma parts (mirrors `parseDateRangeFilter`).
  (String start, String end) parseWindow(String wire) {
    var w = wire.trim();
    if (w.startsWith('between:')) w = w.substring('between:'.length).trim();
    final parts = w.split(',');
    if (parts.length < 2) return ('', '');
    return (parts[parts.length - 2].trim(), parts[parts.length - 1].trim());
  }

  String canonicalWindow(String start, String end) => '$serverKey,$start,$end';

  Set<String> _rangeValues(GenericListViewModel<dynamic> vm) =>
      vm.extraFilters[rangeServerKey] ?? const <String>{};

  // ── Two-slot overrides ───────────────────────────────────────────────

  @override
  bool isAtDefault(GenericListViewModel<dynamic> vm) =>
      super.isAtDefault(vm) && _rangeValues(vm).isEmpty;

  @override
  bool isValidValue(String rawValue) {
    if (isWindowWire(rawValue)) {
      final (s, e) = parseWindow(rawValue);
      return s.isNotEmpty && e.isNotEmpty;
    }
    return super.isValidValue(rawValue);
  }

  Formatter? _formatterOrNull(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
  ) => filterFormatterOrNull(vm, context);

  @override
  Iterable<FilterToken> tokensFrom(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
  ) {
    final formatter = _formatterOrNull(vm, context);
    final windowTokens = [
      for (final wire in _rangeValues(vm))
        () {
          final (start, end) = parseWindow(wire);
          final raw = '$start – $end';
          final formatted = formatter?.dateRange(start, end) ?? '';
          return FilterToken(
            keyId: id,
            displayKey: displayLabel(context),
            rawValue: canonicalWindow(start, end),
            displayValue: formatted.isEmpty ? raw : formatted,
            displayComparator: filterOpPhrase(
              context,
              FilterOp.between,
              valueType,
            ),
            // Keep the exact ISO bounds inspectable on hover.
            valueTooltip: raw,
          );
        }(),
    ];
    return [...super.tokensFrom(vm, context), ...windowTokens];
  }

  @override
  Future<void> addValue(GenericListViewModel<dynamic> vm, String rawValue) {
    if (windowOnly && !isWindowWire(rawValue)) {
      final day = parseWire(rawValue).$1.trim();
      if (day.isEmpty) return Future.value();
      return addValue(vm, canonicalWindow(day, day));
    }
    if (isWindowWire(rawValue)) {
      final (start, end) = parseWindow(rawValue);
      if (start.isEmpty || end.isEmpty) return Future.value();
      // Window and single-date are mutually exclusive for this key —
      // setting one clears the other (each `setExtraFilter` no-ops when
      // the slot is already empty, so this is one reload in practice).
      Future<void> run() async {
        await writeSingleExtraFilter(vm, serverKey, null);
        await writeSingleExtraFilter(
          vm,
          rangeServerKey,
          canonicalWindow(start, end),
        );
      }

      return run();
    }
    Future<void> run() async {
      await writeSingleExtraFilter(vm, rangeServerKey, null);
      await super.addValue(vm, rawValue);
    }

    return run();
  }

  @override
  Future<void> removeValue(GenericListViewModel<dynamic> vm, String rawValue) {
    if (isWindowWire(rawValue)) {
      return writeSingleExtraFilter(vm, rangeServerKey, null);
    }
    return super.removeValue(vm, rawValue);
  }

  @override
  Future<void> clear(GenericListViewModel<dynamic> vm, BuildContext context) {
    // Mirrors ComparableFilterKey.clear (clears the comparable slot) plus
    // the window slot — done inline so no BuildContext crosses the await.
    Future<void> run() async {
      await writeSingleExtraFilter(vm, rangeServerKey, null);
      await writeSingleExtraFilter(vm, serverKey, null);
    }

    return run();
  }

  @override
  Future<void> changeOp(
    GenericListViewModel<dynamic> vm,
    String currentWire,
    FilterOp newOp,
  ) {
    final isWindow = isWindowWire(currentWire);
    if (newOp == FilterOp.between) {
      // Between needs a window value the comparator tap can't supply —
      // the UI opens the range popover next. Just make room by clearing
      // the comparable slot (keep an existing window untouched).
      if (isWindow) return Future.value();
      return writeSingleExtraFilter(vm, serverKey, null);
    }
    // Target is a single-date op. Seed it from the window start when
    // coming from a between chip so the chip stays meaningful.
    final String value;
    if (isWindow) {
      final (start, _) = parseWindow(currentWire);
      value = start;
    } else {
      value = parseWire(currentWire).$1;
    }
    if (value.isEmpty) return Future.value();
    Future<void> run() async {
      await writeSingleExtraFilter(vm, rangeServerKey, null);
      await writeSingleExtraFilter(vm, serverKey, buildWire(value, newOp));
    }

    return run();
  }

  @override
  String? editableValueText(String rawValue) {
    if (isWindowWire(rawValue)) return null;
    return super.editableValueText(rawValue);
  }
}
