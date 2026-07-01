import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';

/// `stock:low` / `stock:out` — the inventory-health filter for the products
/// list. Single-valued (low ⊇ out, so only one makes sense at a time).
///
/// Backed by `extraFilters['stock']`, but applied **locally**: the server has
/// no stock filter dimension, so [ProductListViewModel] strips the `stock` key
/// before the network fetch and re-applies it as a post-decode predicate over
/// the loaded page (`StockFilter` in `product_repository.dart`). Registered only
/// when the company tracks inventory (gated in `buildProductFilterKeys`).
class StockFilterKey extends FilterKey {
  const StockFilterKey();

  static const String serverKey = 'stock';
  static const String low = 'low';
  static const String out = 'out';

  @override
  String get id => serverKey;

  @override
  Iterable<String> get aliases => const ['inventory'];

  @override
  String displayLabel(BuildContext context) => context.tr('inventory');

  @override
  FilterValueType get valueType => FilterValueType.enumeration;

  @override
  IconData get icon => Icons.inventory_2_outlined;

  // Single-valued: picking a new value replaces the old (low already includes
  // out, so the two are never usefully combined).
  @override
  bool get singleValue => true;

  String _labelFor(BuildContext context, String raw) =>
      context.tr(raw == out ? 'out_of_stock' : 'low_stock');

  @override
  bool isAtDefault(GenericListViewModel<dynamic> vm) =>
      (vm.extraFilters[serverKey] ?? const <String>{}).isEmpty;

  @override
  Iterable<FilterToken> tokensFrom(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
  ) {
    final values = vm.extraFilters[serverKey] ?? const <String>{};
    return [
      for (final raw in values)
        FilterToken(
          keyId: id,
          displayKey: displayLabel(context),
          rawValue: raw,
          displayValue: _labelFor(context, raw),
        ),
    ];
  }

  List<FilterValueSuggestion> _suggestions(BuildContext context) => [
    FilterValueSuggestion(rawValue: low, displayLabel: context.tr('low_stock')),
    FilterValueSuggestion(
      rawValue: out,
      displayLabel: context.tr('out_of_stock'),
    ),
  ];

  @override
  Stream<List<FilterValueSuggestion>> watchValueSuggestions(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    final all = _suggestions(context);
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

  @override
  List<FilterValueSuggestion> quickValueSuggestions(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return [
      for (final s in _suggestions(context))
        if (s.displayLabel.toLowerCase().startsWith(q) ||
            s.rawValue.toLowerCase().startsWith(q))
          s,
    ];
  }

  @override
  Future<void> addValue(GenericListViewModel<dynamic> vm, String rawValue) {
    final v = rawValue.trim().toLowerCase();
    if (v != low && v != out) return Future.value();
    return writeSingleExtraFilter(vm, serverKey, v);
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
}
