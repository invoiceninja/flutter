import 'package:flutter/material.dart';

import 'package:admin/data/db/dao/billing_extra_filters.dart'
    show resolveRelativeDateToken;
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';

/// One filterable dimension of an entity list — `is`, `custom1`, `country`,
/// and so on. Each `FilterKey` knows how to render itself in the suggestion
/// menu, where its values live on the [GenericListViewModel], and how to
/// apply / remove them.
///
/// Add a new dimension by writing a subclass and adding it to the entity's
/// registry (`client_filter_keys.dart`). Everything else — the search field,
/// the chip rendering, the suggestion menu, persistence — is generic.
///
/// `FilterKey` is intentionally non-generic. The concrete keys only touch
/// the `GenericListViewModel` base API (`states`, `customFilters`,
/// `extraFilters`, `setStates`, `setCustomFilter`, `setExtraFilter`,
/// `watchDistinctCustomValues`); none of them need the entity type. Keeping
/// the VM typed as `GenericListViewModel<dynamic>` lets a single registry
/// of keys serve every entity without phantom generic parameters.
abstract class FilterKey {
  const FilterKey();

  /// Canonical id the user types after the `:` separator (`is`, `custom1`,
  /// `country`). Stable across locales. Lowercase ASCII.
  String get id;

  /// Display label shown in the chip + suggestion menu. Resolved at render
  /// time so it follows the active locale + company settings (the configured
  /// "Region" label for `custom1`, the localized "Status" for `is`).
  String displayLabel(BuildContext context);

  /// Extra ids the user can type to pick this key (`is` accepts `status` as
  /// an alias and vice versa). Powers paste compatibility for Sentry-style
  /// queries.
  Iterable<String> get aliases => const [];

  /// Release any held resources (Drift watch subscriptions on the
  /// membership keys). The hosting search field calls this whenever it
  /// replaces or unmounts a key list — without it, keys rebuilt per list
  /// rebuild leaked one live stream query each (drift's stream-query store
  /// roots the subscription, so GC never collects them). No-op by default.
  void dispose() {}

  /// Coarse value type — drives the chip rendering and the default [icon].
  /// v1 uses [FilterValueType.enumeration] for status and
  /// [FilterValueType.string] for everything else.
  FilterValueType get valueType;

  /// Leading glyph shown in the suggestion menu's key row. Defaults to a
  /// value-type-derived icon; semantic keys (balance, country, assigned, …)
  /// override it so the list scans by shape, not just text. Replaces the
  /// old right-aligned `string`/`date`/`enum` type tag.
  IconData get icon => switch (valueType) {
    FilterValueType.date => Icons.event_outlined,
    FilterValueType.enumeration => Icons.adjust_outlined,
    FilterValueType.string => Icons.short_text,
  };

  /// When true, only one value may be applied at a time — selecting a new
  /// value replaces the old one rather than appending. Enums with a small
  /// fixed set typically opt in (`status`, `assigned`) to keep the chip
  /// compact and to enable [cycleValue].
  bool get singleValue => false;

  /// When true, the value picker renders an explicit checkbox per row and
  /// splits the row's hit-target: tapping the **label** selects only that
  /// value and closes the menu (quick single pick / replace), tapping the
  /// **checkbox** toggles the value into the multi-selection and keeps the
  /// menu open. Opt-in — only the status / state keys set this; every other
  /// key keeps the default toggle-and-close picker.
  bool get checkboxMultiSelect => false;

  /// When non-null, selecting this key from the picker applies this value
  /// IMMEDIATELY rather than opening a value picker. For single-value boolean
  /// keys (e.g. Overdue) whose only choice is "on" — there's nothing to pick,
  /// so a one-item value list is pure friction. The narrow filter sheet's
  /// `_onSelectKey` honours this; default null keeps the normal pick flow.
  String? get directApplyValue => null;

  /// Currently-applied tokens for this key, derived from VM state. Empty
  /// when the key is at its default and no chip should appear.
  Iterable<FilterToken> tokensFrom(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
  );

  /// Streamed value suggestions for the autocomplete. `query` is the text
  /// after `<id-or-alias>:`. Implementations filter a static list or
  /// project from a live DAO stream.
  Stream<List<FilterValueSuggestion>> watchValueSuggestions(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String query,
  );

  /// Synchronous lookup used by the key-mode picker to surface cross-key
  /// value matches when the user types free text without a `<key>:` prefix —
  /// e.g. typing `act` surfaces a `Status: Active` row so picking it applies
  /// `status:active` directly.
  ///
  /// Distinct from [watchValueSuggestions] because we need same-frame
  /// results per keystroke: a `StreamBuilder` per key per keystroke flickers
  /// the first frame as `Stream.value` emits asynchronously on the
  /// microtask queue. The five statics-backed keys and `IsFilterKey`
  /// already build their suggestion list synchronously inside
  /// `watchValueSuggestions`, so the override is a thin extract.
  ///
  /// Default returns empty so typed-input keys (`name`, `balance`, …)
  /// and flat-membership keys (`vat`, `id_number`, `classification`)
  /// contribute nothing — they have no enumerable value set.
  ///
  /// Implementations should use case-insensitive `startsWith` against
  /// display labels (and ISO codes for country/currency) and cap the
  /// returned list per key — the menu applies its own total cap on top.
  List<FilterValueSuggestion> quickValueSuggestions(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String query,
  ) => const [];

  /// Apply a value. Implementations write through to the relevant VM slot
  /// ([GenericListViewModel.setStates], [GenericListViewModel.setCustomFilter],
  /// [GenericListViewModel.setExtraFilter]).
  Future<void> addValue(GenericListViewModel<dynamic> vm, String rawValue);

  /// Remove a specific value. No-op if the value wasn't applied.
  Future<void> removeValue(GenericListViewModel<dynamic> vm, String rawValue);

  /// Replace every currently-applied value for this key with [rawValue]
  /// alone. Drives the "tap the row label = pick only this" half of the
  /// [checkboxMultiSelect] split action. The generic default removes each
  /// applied token then adds [rawValue] — correct but fires one VM reload
  /// per removal; keys that can express the replace as a single VM write
  /// (`setStates` / `setExtraFilter`) override this for one reload.
  Future<void> selectExclusive(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String rawValue,
  ) {
    // Snapshot the applied raw values synchronously (uses [context]) before
    // any await, so the BuildContext never crosses an async gap.
    final applied = [for (final t in tokensFrom(vm, context)) t.rawValue];
    Future<void> run() async {
      for (final raw in applied) {
        await removeValue(vm, raw);
      }
      await addValue(vm, rawValue);
    }

    return run();
  }

  /// Remove every currently-applied value for this key. Drives the `×` on
  /// an aggregate multi-value chip. The generic default snapshots the
  /// applied raw values synchronously (before any await — no BuildContext
  /// across an async gap) then loops [removeValue]; correct but fires one
  /// VM reload per value. Keys that can express the clear as a single VM
  /// write (`setStates` / `setExtraFilter`) override this for one reload.
  Future<void> clear(GenericListViewModel<dynamic> vm, BuildContext context) {
    final applied = [for (final t in tokensFrom(vm, context)) t.rawValue];
    Future<void> run() async {
      for (final raw in applied) {
        await removeValue(vm, raw);
      }
    }

    return run();
  }

  /// User-typeable form of [rawValue] for chip-tap-to-edit. Returns null
  /// when the key shouldn't pre-fill its value — membership keys whose
  /// raw value is an opaque id (`country:840`), enum keys whose value
  /// belongs in the picker. Typed-input keys override to return the form
  /// the user originally typed; [addValue] must accept what's returned
  /// here so Enter on the pre-fill produces the same wire format.
  String? editableValueText(String rawValue) => null;

  /// For [singleValue] enum keys with a small enumeration, advance to the
  /// next value. Returning `null` (the default) disables the chip's
  /// tap-to-cycle path — keys without an obvious "next" should just open
  /// the popover.
  Future<void> Function()? cycleValue(GenericListViewModel<dynamic> vm) => null;

  /// True when this key has no chip to render (e.g. `is` with only
  /// `{active}`). The search field uses this to suppress noise on a fresh
  /// load: a user who hasn't filtered shouldn't see a default chip.
  bool isAtDefault(GenericListViewModel<dynamic> vm);

  /// True when this key should appear in the suggestion menu at all. Keys
  /// whose options come from a stream that may be empty (the custom-field
  /// columns, groups before the Groups entity ships) opt out so they don't
  /// surface a key with no values to pick from. Defaults to true.
  bool isAvailable(GenericListViewModel<dynamic> vm) => true;

  /// Optional hint shown in the value menu when `watchValueSuggestions`
  /// emits an empty list. For typed-value keys (`name`, `balance`,
  /// `created`, …) the value menu has nothing to pick — the user types
  /// the value directly and presses Enter. Returning a localized hint
  /// here replaces the default "No matches" copy with something
  /// actionable like "Type a name (starts with)". Default null leaves
  /// the menu's existing fallback in place.
  String? hintForValueMode(BuildContext context) => null;

  /// Operators this key exposes when the user has typed a value. Default
  /// empty → no operator picker (value menu falls back to suggestions
  /// or the `hintForValueMode` text). Keys that opt in must also accept
  /// the wire format `<value>:<op.name>` from `addValue` — see
  /// `BalanceFilterKey` for the reference implementation.
  List<FilterOp> get supportedOps => const [];

  /// Pre-flight validation for a user-typed value before Enter commits
  /// it through [addValue]. Default accepts anything.
  ///
  /// Keys can reject inputs that would silently produce no chip — e.g.
  /// `BalanceFilterKey` rejects bare operator symbols (`>`, `<`,
  /// `:gt`, `:lt`) with no numeric value, so Enter on `balance:>`
  /// keeps the overlay open instead of dropping the input on the floor.
  ///
  /// Return `true` to accept; `false` to reject and keep the input.
  bool isValidValue(String rawValue) => true;
}

/// Single-write helper for `extraFilters[serverKey]`. Writes a one-element
/// set for a non-empty value; null/empty clears the dimension entirely.
/// Used both by typed-input keys (substring text, `value:gt` / `value:lt`,
/// `value:eq`, …) for `addValue`, and by enum/membership keys for the
/// single-write `selectExclusive` / `clear` paths.
Future<void> writeSingleExtraFilter(
  GenericListViewModel<dynamic> vm,
  String serverKey,
  String? wireValue,
) {
  if (wireValue == null || wireValue.isEmpty) {
    return vm.setExtraFilter(serverKey: serverKey, values: const {});
  }
  return vm.setExtraFilter(serverKey: serverKey, values: {wireValue});
}

/// Comparison operators a [FilterKey] can expose in its value menu.
///
/// **Canonical wire format = server-native PREFIX `op:value`**
/// (`balance=gt:5000`, `created_at=gte:2026-01-01`). The server's
/// `QueryFilters::split()` does `explode(':')` → `operator = parts[0]`,
/// `value = parts[1]`, and `operatorConvertor()` already maps
/// `lt,gt,lte,gte,eq → <,>,<=,>=,=`. The earlier SUFFIX form
/// `value:op` parsed as `where(col,'=','op')` server-side (zero rows) —
/// it is still *decoded* by [ComparableFilterKey.parseWire] for
/// persisted `nav_state` self-heal, but every write emits canonical.
///
/// Invariant: a value must never itself contain `:` (the server splits
/// on the first colon) — fine for the date-only / numeric values used
/// here. The `rel:` relative-date token is the one exception and is
/// always resolved to an absolute value client-side before the request.
enum FilterOp {
  /// Greater than. Date phrasing: *is after*.
  gt,

  /// Greater than or equal. Date phrasing: *is on or after*.
  gte,

  /// Less than. Date phrasing: *is before*.
  lt,

  /// Less than or equal. Date phrasing: *is on or before*.
  lte,

  /// Equal. Date phrasing: *is on*.
  eq,

  /// Closed window. Date phrasing: *is between*. Unlike the other ops
  /// this is **not** sent to the server `operatorConvertor()`; date keys
  /// route it to the `<column>_range` window param (`date_range` /
  /// `due_date_range`) — see [DateColumnFilterKey].
  between,
}

/// The token the server's `operatorConvertor()` accepts (`gt`, `gte`,
/// `lt`, `lte`, `eq`). Single source of truth for the wire op name.
String filterOpServerName(FilterOp op) => op.name;

/// The math symbol shown in a chip / typed into the input. Pretty
/// Unicode for `gte`/`lte`; ASCII for the rest. [parseWire] accepts
/// both these and the ASCII `>=` / `<=` forms.
String filterOpSymbol(FilterOp op) {
  switch (op) {
    case FilterOp.gt:
      return '>';
    case FilterOp.gte:
      return '≥';
    case FilterOp.lt:
      return '<';
    case FilterOp.lte:
      return '≤';
    case FilterOp.eq:
      return '=';
    case FilterOp.between:
      return '↔';
  }
}

/// The comparator label for menus and accessibility. For
/// [FilterValueType.date] this is a localized phrase
/// (*is after* / *is on or after* / …); otherwise the math symbol.
String filterOpPhrase(
  BuildContext context,
  FilterOp op,
  FilterValueType valueType,
) {
  if (valueType != FilterValueType.date) return filterOpSymbol(op);
  switch (op) {
    case FilterOp.gt:
      return context.tr('is_after');
    case FilterOp.gte:
      return context.tr('is_on_or_after');
    case FilterOp.lt:
      return context.tr('is_before');
    case FilterOp.lte:
      return context.tr('is_on_or_before');
    case FilterOp.eq:
      return context.tr('is_on');
    case FilterOp.between:
      return context.tr('is_between');
  }
}

/// Relative-date value presets offered in the date value picker. The
/// token is the wire value (combined with an op by `buildWire` →
/// `gte:rel:d7`); the label key is resolved at render time.
/// `resolveRelativeDateToken` (data layer) is the single resolver.
const kRelativeDatePresets = <(String token, String labelKey)>[
  ('rel:h1', 'relative_1_hour_ago'),
  ('rel:h24', 'relative_24_hours_ago'),
  ('rel:d7', 'relative_7_days_ago'),
  ('rel:d14', 'relative_14_days_ago'),
  ('rel:d30', 'relative_30_days_ago'),
];

/// Localized label for a value that may be a `rel:` token — "7 days
/// ago" for `rel:d7`, the value verbatim otherwise.
String relativeValueLabel(BuildContext context, String value) {
  for (final (token, labelKey) in kRelativeDatePresets) {
    if (token == value) return context.tr(labelKey);
  }
  return value;
}

/// Single-value comparable dimension backed by `extraFilters[serverKey]`
/// whose value carries an operator (`balance`, `created`, `updated`,
/// per-entity `date`/`due_date`). Centralizes the wire encode/decode so
/// concrete keys only declare `serverKey`, `supportedOps`, `defaultOp`,
/// `valueType` (+ the usual `id` / `displayLabel`).
///
/// Wire is canonical PREFIX `op:value` (see [FilterOp]). [parseWire]
/// also decodes the legacy SUFFIX `value:op`, the symbol-prefix
/// `>1000` / `>=1000` a user types, and a bare value (→ [defaultOp]),
/// so persisted state from older app versions still renders and
/// self-heals on the next write.
mixin ComparableFilterKey on FilterKey {
  /// API/Drift param name (`balance`, `created_at`, …).
  String get serverKey;

  /// Operator assumed when a bare value (no operator) is parsed.
  /// Date keys use [FilterOp.gte] to preserve the historical
  /// server `>=` semantics for plain `created_at=<date>`.
  FilterOp get defaultOp;

  @override
  bool get singleValue => true;

  @override
  bool isAtDefault(GenericListViewModel<dynamic> vm) =>
      (vm.extraFilters[serverKey] ?? const <String>{}).isEmpty;

  @override
  Stream<List<FilterValueSuggestion>> watchValueSuggestions(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String query,
  ) => Stream.value(const []);

  static const _opByName = {
    'gt': FilterOp.gt,
    'gte': FilterOp.gte,
    'lt': FilterOp.lt,
    'lte': FilterOp.lte,
    'eq': FilterOp.eq,
  };

  /// Decode any persisted/typed shape into `(value, op)`.
  (String value, FilterOp op) parseWire(String wire) {
    final w = wire.trim();
    // 1. Canonical prefix `op:value`.
    final colon = w.indexOf(':');
    if (colon > 0) {
      final maybeOp = _opByName[w.substring(0, colon)];
      if (maybeOp != null) {
        return (w.substring(colon + 1).trim(), maybeOp);
      }
    }
    // 2. Legacy suffix `value:op`.
    for (final entry in _opByName.entries) {
      final suffix = ':${entry.key}';
      if (w.endsWith(suffix)) {
        return (w.substring(0, w.length - suffix.length).trim(), entry.value);
      }
    }
    // 3. Symbol prefix the user types (`>=1000`, `≤30`, `>1000`).
    for (final probe in const [
      ('>=', FilterOp.gte),
      ('<=', FilterOp.lte),
      ('≥', FilterOp.gte),
      ('≤', FilterOp.lte),
      ('>', FilterOp.gt),
      ('<', FilterOp.lt),
      ('=', FilterOp.eq),
    ]) {
      if (w.startsWith(probe.$1)) {
        return (w.substring(probe.$1.length).trim(), probe.$2);
      }
    }
    // 4. Bare value → default operator.
    return (w, defaultOp);
  }

  /// Encode `(value, op)` into the canonical prefix wire.
  String buildWire(String value, FilterOp op) =>
      '${filterOpServerName(op)}:${value.trim()}';

  @override
  bool isValidValue(String rawValue) => parseWire(rawValue).$1.isNotEmpty;

  @override
  Iterable<FilterToken> tokensFrom(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
  ) {
    final values = vm.extraFilters[serverKey] ?? const <String>{};
    return [
      for (final wire in values)
        () {
          final (value, op) = parseWire(wire);
          final comparator = filterOpPhrase(context, op, valueType);
          final resolved = resolveRelativeDateToken(value);
          return FilterToken(
            keyId: id,
            displayKey: displayLabel(context),
            rawValue: wire,
            displayValue: relativeValueLabel(context, value),
            displayComparator: comparator,
            // Reveal the absolute date behind a rolling "7 days ago".
            valueTooltip: resolved,
          );
        }(),
    ];
  }

  @override
  Future<void> addValue(GenericListViewModel<dynamic> vm, String rawValue) {
    final (value, op) = parseWire(rawValue);
    if (value.isEmpty) return Future.value();
    return writeSingleExtraFilter(vm, serverKey, buildWire(value, op));
  }

  @override
  Future<void> removeValue(GenericListViewModel<dynamic> vm, String rawValue) =>
      writeSingleExtraFilter(vm, serverKey, null);

  @override
  Future<void> selectExclusive(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String rawValue,
  ) => addValue(vm, rawValue);

  @override
  Future<void> clear(GenericListViewModel<dynamic> vm, BuildContext context) =>
      writeSingleExtraFilter(vm, serverKey, null);

  /// Replace just the operator on an already-applied chip, keeping the
  /// value. One `setExtraFilter` → one notify, no flicker, no focus or
  /// text-controller side effects.
  Future<void> changeOp(
    GenericListViewModel<dynamic> vm,
    String currentWire,
    FilterOp newOp,
  ) {
    final (value, _) = parseWire(currentWire);
    if (value.isEmpty) return Future.value();
    return writeSingleExtraFilter(vm, serverKey, buildWire(value, newOp));
  }

  /// Chip-tap-to-edit prefill: numeric keys round-trip to the
  /// `symbol+value` the user can retype; date keys prefill the bare
  /// value (the comparator is changed via the comparator segment, not
  /// by typing). A relative token has no typeable form.
  @override
  String? editableValueText(String rawValue) {
    final (value, op) = parseWire(rawValue);
    if (value.startsWith('rel:')) return null;
    if (valueType == FilterValueType.date) return value;
    return '${filterOpSymbol(op)}$value';
  }
}
