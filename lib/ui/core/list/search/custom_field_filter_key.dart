import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_keys_common.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';

/// `custom1:foo` … `custom4:bar` — multi-valued, hidden when the company
/// hasn't configured a label for that slot. Suggestions stream from
/// [GenericListViewModel.watchDistinctCustomValues].
///
/// Entity-agnostic: it reads/writes the generic VM `customFilters` slot, so
/// any list (clients, invoices, …) can register it. The owning
/// `build*FilterKeys` supplies the per-entity [configuredLabel] (e.g.
/// `company.customFieldLabel('invoice1')`).
///
/// Server status: as of the v5 filter PR the server supports
/// `custom_value1..4` (single-value substring `LIKE`); the generic VM's
/// `_serverExtraFilters` emits a single-value slot to the server, and
/// multi-value selections still narrow locally via the per-entity
/// `*Dao.watchPage` `customValuesN` predicate.
class CustomFieldFilterKey extends FilterKey {
  const CustomFieldFilterKey({
    required this.columnIndex,
    required this.configuredLabel,
  }) : assert(columnIndex >= 1 && columnIndex <= 4);

  final int columnIndex;

  /// Label the company configured for this column (`Region`, `Project`,
  /// …). Empty when unset — the key is then hidden from autocomplete.
  final String configuredLabel;

  @override
  String get id => 'custom$columnIndex';

  @override
  String displayLabel(BuildContext context) {
    if (configuredLabel.isNotEmpty) return configuredLabel;
    return context.tr('custom_column_n', {'index': columnIndex.toString()});
  }

  @override
  FilterValueType get valueType => FilterValueType.string;

  // Distinct icon so a configured custom-field label (shown verbatim, e.g.
  // "CUSTOM CLIENT") reads as a custom field rather than a mislabeled
  // standard one.
  @override
  IconData get icon => Icons.tune;

  // Server supports `custom_value1..4` as of the v5 filter PR; multi-value
  // selections still narrow locally. Show the key whenever the slot is
  // configured.
  @override
  bool isAvailable(GenericListViewModel<dynamic> vm) =>
      configuredLabel.isNotEmpty;

  @override
  bool isAtDefault(GenericListViewModel<dynamic> vm) =>
      (vm.customFilters[columnIndex] ?? const <String>{}).isEmpty;

  @override
  Iterable<FilterToken> tokensFrom(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
  ) {
    // Don't paint an orphan chip when the company has un-configured this
    // custom column — the chip would show with an empty `displayKey`.
    // Symmetric with `isAvailable` already gating the menu visibility;
    // the chip data is retained in `vm.customFilters` and re-paints if
    // the label is restored.
    if (configuredLabel.isEmpty) return const [];
    final values = vm.customFilters[columnIndex] ?? const <String>{};
    return [
      for (final v in values)
        FilterToken(
          keyId: id,
          displayKey: displayLabel(context),
          rawValue: v,
          displayValue: v,
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
    return vm.watchDistinctCustomValues(columnIndex).map((values) {
      final filtered = q.isEmpty
          ? values
          : values.where((v) => v.toLowerCase().contains(q)).toList();
      return [
        for (final v in filtered)
          FilterValueSuggestion(rawValue: v, displayLabel: v),
      ];
    });
  }

  /// Free-text key-mode lookup. Reads from the synchronous cache populated
  /// by `GenericListViewModel._subscribeCustomValues` so the cross-key
  /// picker can surface `Region: North` without an extra async hop per
  /// keystroke. Hidden when the column hasn't been configured (mirrors
  /// `isAvailable`) so we don't emit suggestions for a key that wouldn't
  /// show up in the menu anyway.
  @override
  List<FilterValueSuggestion> quickValueSuggestions(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String query,
  ) {
    if (configuredLabel.isEmpty) return const [];
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final out = <FilterValueSuggestion>[];
    for (final v in vm.distinctCustomValues(columnIndex)) {
      if (out.length >= kQuickValueLimitPerKey) break;
      if (v.toLowerCase().startsWith(q)) {
        out.add(FilterValueSuggestion(rawValue: v, displayLabel: v));
      }
    }
    return out;
  }

  @override
  Future<void> addValue(GenericListViewModel<dynamic> vm, String rawValue) {
    final next = Set<String>.from(vm.customFilters[columnIndex] ?? const {})
      ..add(rawValue);
    return vm.setCustomFilter(columnIndex: columnIndex, values: next);
  }

  @override
  Future<void> removeValue(GenericListViewModel<dynamic> vm, String rawValue) {
    final next = Set<String>.from(vm.customFilters[columnIndex] ?? const {})
      ..remove(rawValue);
    return vm.setCustomFilter(columnIndex: columnIndex, values: next);
  }

  @override
  Future<void> replaceValue(
    GenericListViewModel<dynamic> vm,
    String oldRaw,
    String newRaw,
  ) {
    if (newRaw.isEmpty || newRaw == oldRaw) return Future.value();
    final next = Set<String>.from(vm.customFilters[columnIndex] ?? const {})
      ..remove(oldRaw)
      ..add(newRaw);
    return vm.setCustomFilter(columnIndex: columnIndex, values: next);
  }
}
