import 'package:flutter/widgets.dart';

import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';

/// Base class for multi-valued membership keys whose state is stored as a
/// `Set<String>` of ids in `vm.extraFilters[serverKey]`. Subclasses declare
/// the server key, the id, the display label, and (for statics-backed
/// keys) how to resolve an id to a display value + suggestion list.
///
/// Two flavours of membership key:
///
///   * **Flat** (vat, id_number, classification) — user types a value, it
///     gets unioned in. No suggestion list. `displayValueFor` returns the
///     id verbatim. Subclass only needs `id`, `displayLabel`, `serverKey`,
///     `hintForValueMode`.
///
///   * **Statics-backed** (currency, language, industry, size, country) —
///     id is a numeric reference into the statics bundle. Override
///     `displayValueFor` and `watchValueSuggestions` to read from statics;
///     optionally override `addValue` for accept-alternate-input behaviour
///     (e.g. `CountryFilterKey` accepts ISO codes alongside numeric ids).
abstract class MembershipFilterKey extends FilterKey {
  const MembershipFilterKey();

  /// The Invoice Ninja v2 query-param this dimension writes to (e.g.
  /// `currency_id`, `vat_number`). Reads + writes go through
  /// `vm.extraFilters[serverKey]`.
  String get serverKey;

  @override
  FilterValueType get valueType => FilterValueType.string;

  /// How a raw id should render in a chip. Default returns the id verbatim
  /// (right for flat keys); statics-backed subclasses resolve through the
  /// matching statics map.
  String displayValueFor(String rawValue) => rawValue;

  /// A flat key's value IS what the user typed (a VAT number, an id number),
  /// so editing its chip prefills it. A statics- or repo-backed key's raw
  /// value is an opaque id and prefills nothing — its picker opens instead.
  @override
  String? editableValueText(String rawValue) =>
      acceptsTypedValue ? rawValue : null;

  @override
  bool isAtDefault(GenericListViewModel<dynamic> vm) =>
      (vm.extraFilters[serverKey] ?? const <String>{}).isEmpty;

  @override
  Iterable<FilterToken> tokensFrom(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
  ) {
    final ids = vm.extraFilters[serverKey] ?? const <String>{};
    return [
      for (final v in ids)
        FilterToken(
          keyId: id,
          displayKey: displayLabel(context),
          rawValue: v,
          displayValue: displayValueFor(v),
        ),
    ];
  }

  @override
  Stream<List<FilterValueSuggestion>> watchValueSuggestions(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String query,
  ) => Stream.value(const []);

  @override
  Future<void> addValue(GenericListViewModel<dynamic> vm, String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) return Future.value();
    return unionMembership(vm, serverKey, trimmed);
  }

  @override
  Future<void> removeValue(GenericListViewModel<dynamic> vm, String rawValue) =>
      removeMembership(vm, serverKey, rawValue);

  /// One VM write (one reload): drop [oldRaw] and add [newRaw] together.
  @override
  Future<void> replaceValue(
    GenericListViewModel<dynamic> vm,
    String oldRaw,
    String newRaw,
  ) {
    final trimmed = newRaw.trim();
    if (trimmed.isEmpty || trimmed == oldRaw) return Future.value();
    final next = Set<String>.from(vm.extraFilters[serverKey] ?? const {})
      ..remove(oldRaw)
      ..add(trimmed);
    return vm.setExtraFilter(serverKey: serverKey, values: next);
  }

  /// Replace the whole membership set with [rawValue] in one VM write
  /// (one reload, not one per previously-applied value).
  @override
  Future<void> selectExclusive(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String rawValue,
  ) => writeSingleExtraFilter(vm, serverKey, rawValue.trim());

  /// Clear the whole membership set in one VM write.
  @override
  Future<void> clear(GenericListViewModel<dynamic> vm, BuildContext context) =>
      writeSingleExtraFilter(vm, serverKey, null);
}

/// Union [value] into the existing set at `vm.extraFilters[serverKey]`.
Future<void> unionMembership(
  GenericListViewModel<dynamic> vm,
  String serverKey,
  String value,
) {
  final next = Set<String>.from(vm.extraFilters[serverKey] ?? const {})
    ..add(value);
  return vm.setExtraFilter(serverKey: serverKey, values: next);
}

/// Remove [value] from the existing set at `vm.extraFilters[serverKey]`.
Future<void> removeMembership(
  GenericListViewModel<dynamic> vm,
  String serverKey,
  String value,
) {
  final next = Set<String>.from(vm.extraFilters[serverKey] ?? const {})
    ..remove(value);
  return vm.setExtraFilter(serverKey: serverKey, values: next);
}
