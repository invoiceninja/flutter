import 'package:flutter/material.dart';

import 'package:admin/domain/entity_state.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';

/// Per-key cap on the synchronous `quickValueSuggestions` lookup powering
/// the key-mode picker's cross-key value matches. Mirrors the constant in
/// `client_filter_keys.dart` — kept private here so each filter key file
/// owns its own pacing.
const int _kQuickValueLimitPerKey = 3;

/// `is:active` / `is:archived` / `is:deleted` — the entity lifecycle filter,
/// multi-valued, default [kDefaultListStates]. Entity-agnostic: operates on
/// [GenericListViewModel.states] only, so every entity list can register the
/// same instance.
///
/// **The dimension is never empty**, so archived and deleted rows appear only
/// when someone asks for them (invoiceninja/flutter#126). Clearing lands on
/// the default instead of dropping the dimension; `setStates` on the VM
/// normalizes as the backstop, and the two methods below say so where a
/// reader looks for the product rule.
///
/// Labelled **"State"** (not "Status") and aliased `state` (not `status`):
/// invoices / tasks / bank-transactions also register a per-entity *Status*
/// key (`status:draft|paid|…`), and a shared `status` alias here both
/// duplicated the "Status" picker row and shadowed that real key when the
/// user typed `status:`. Keeping `state`/`is` here leaves `status:`
/// unambiguous for the per-entity key.
///
/// The **label** uses the app-owned key `entity_state_filter` (not the
/// Transifex `entity_state`): in de / es / it / ja both `entity_state` and
/// `status` translate to the same word, so the default lifecycle chip read
/// identically to the per-entity Status chip. `entity_state_filter` lives in
/// `_app_pending.json` and stays distinct until native translations land in
/// Transifex.
class IsFilterKey extends FilterKey {
  const IsFilterKey();

  @override
  String get id => 'is';

  @override
  Iterable<String> get aliases => const ['state'];

  @override
  String displayLabel(BuildContext context) =>
      context.tr('entity_state_filter');

  @override
  FilterValueType get valueType => FilterValueType.enumeration;

  // Lifecycle state (active / archived / deleted) — distinct icon from the
  // generic enum default so it doesn't read like a per-entity Status key.
  @override
  IconData get icon => Icons.toggle_on_outlined;

  // `singleValue` keeps the base default (`false`): multi-valued so users
  // can filter to a union like `{archived, deleted}` — `vm.setStates`
  // takes an arbitrary `Set<EntityState>` and the server param is
  // comma-joined.

  /// State is the canonical multi-select dimension — render checkboxes so
  /// the union (`{active, archived}`) is discoverable.
  @override
  bool get checkboxMultiSelect => true;

  /// Tapping the row label picks just this state in one `setStates` write.
  @override
  Future<void> selectExclusive(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String rawValue,
  ) {
    final state = _stateOf(rawValue);
    if (state == null) return Future.value();
    return vm.setStates({state});
  }

  /// Clearing the aggregate chip returns the dimension to its default in one
  /// write — never to the empty set, which meant "show everything, deleted
  /// included" while rendering no chip and hiding the clear-filters button
  /// (#126). See [removeValue].
  @override
  Future<void> clear(GenericListViewModel<dynamic> vm, BuildContext context) =>
      vm.setStates(kDefaultListStates);

  /// Also decides whether a chip renders at all: `TokenSearchController`
  /// skips a key at its default, so an active-only list carries no `State`
  /// chip and every `×` the user *can* see does something.
  @override
  bool isAtDefault(GenericListViewModel<dynamic> vm) =>
      vm.states.length == 1 && vm.states.contains(EntityState.active);

  @override
  Iterable<FilterToken> tokensFrom(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
  ) {
    // Emit one token per state in `vm.states`, INCLUDING the default
    // `{active}`. Deliberately not gated on [isAtDefault]: the value picker
    // reads its applied set (the check icon, and toggle-vs-add) straight off
    // this method, so an early return here would render Active un-ticked on
    // an active-only list. The *chip* is suppressed one layer up, in
    // `TokenSearchController.activeChips` / `activeTokens`.
    //
    // This is a reversal: the default chip used to be visible, matching
    // Sentry's `is:unresolved`. Sentry's chip is removable and removing it
    // genuinely widens; ours can't widen any more (#126), so a permanently
    // dead `×` was the alternative. Suppressing it also un-blocks the search
    // placeholder on three surfaces — see § List state filter in CLAUDE.md.
    return [
      for (final s in EntityState.values)
        if (vm.states.contains(s))
          FilterToken(
            keyId: id,
            displayKey: displayLabel(context),
            rawValue: s.serverName,
            displayValue: context.tr(s.labelKey),
          ),
    ];
  }

  @override
  Stream<List<FilterValueSuggestion>> watchValueSuggestions(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    final all = [
      for (final s in EntityState.values)
        FilterValueSuggestion(
          rawValue: s.serverName,
          displayLabel: context.tr(s.labelKey),
        ),
    ];
    final filtered = q.isEmpty
        ? all
        : all
              .where(
                (s) =>
                    s.displayLabel.toLowerCase().contains(q) ||
                    s.rawValue.toLowerCase().contains(q),
              )
              .toList();
    return Stream.value(filtered);
  }

  /// Free-text key-mode lookup. Tighter than [watchValueSuggestions]
  /// (`startsWith` not `contains`) because the user hasn't committed to
  /// the State dimension — a stray substring match like `act` against
  /// `inactive` (hypothetical future state) would be noise, not a clue.
  @override
  List<FilterValueSuggestion> quickValueSuggestions(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final out = <FilterValueSuggestion>[];
    for (final s in EntityState.values) {
      if (out.length >= _kQuickValueLimitPerKey) break;
      final label = context.tr(s.labelKey).toLowerCase();
      if (label.startsWith(q) || s.serverName.startsWith(q)) {
        out.add(
          FilterValueSuggestion(
            rawValue: s.serverName,
            displayLabel: context.tr(s.labelKey),
          ),
        );
      }
    }
    return out;
  }

  @override
  Future<void> addValue(GenericListViewModel<dynamic> vm, String rawValue) {
    final state = _stateOf(rawValue);
    if (state == null) return Future.value();
    // Always union. From `{active}` + Archived → `{active, archived}` (two
    // chips). The user removes individual chips with `×` if they want to
    // narrow. Sentry / Linear style: each click adds, never replaces.
    return vm.setStates({...vm.states, state});
  }

  @override
  Future<void> removeValue(GenericListViewModel<dynamic> vm, String rawValue) {
    final state = _stateOf(rawValue);
    if (state == null) return Future.value();
    final next = Set<EntityState>.from(vm.states)..remove(state);
    // Removing the LAST state lands on the default, not the empty set: empty
    // means "no restriction" at the watch query and the server `status` param
    // alike, i.e. deleted rows, from a gesture that reads as "stop filtering"
    // (#126). One consequence, and it is the rule rather than a bug: the
    // picker's Active row becomes inert on a default list. `_FilterCheckbox`
    // is stateless and draws from `tokensFrom`, and `setStates` early-returns
    // on an unchanged set without notifying, so the tick never even flickers
    // — the tap is silently ignored rather than refused. Cheap (no reload, no
    // `nav_state` write) but genuinely unsignposted; the chip's dead `×` was
    // traded for this, which at least sits behind a deliberate menu tap.
    return vm.setStates(next.isEmpty ? kDefaultListStates : next);
  }

  // `cycleValue` is intentionally NOT overridden — users found the silent
  // chip-tap value change surprising. Tapping the chip falls through to
  // `TokenSearchField._onChipTap`'s "open value picker" branch instead,
  // which lets the user pick the new value intentionally.

  EntityState? _stateOf(String raw) {
    for (final s in EntityState.values) {
      if (s.serverName == raw || s.name == raw) return s;
    }
    return null;
  }
}
