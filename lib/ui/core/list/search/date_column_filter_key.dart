import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
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
  }) : _labelKey = labelKey,
       _hintKey = hintKey;

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

  /// Best-effort company [Formatter] for the chip text. Read from the
  /// screen-tree [Services] (always present where chips are painted;
  /// the per-screen formatter is cached by paint time). Guarded so the
  /// bare-`BuildContext` unit tests — which have no `Provider<Services>`
  /// — fall back to raw ISO instead of throwing.
  Formatter? _formatterOrNull(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
  ) {
    try {
      return context.read<Services>().formatterIfReady(vm.companyId);
    } catch (_) {
      return null;
    }
  }

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
