import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';

/// `number:1234` → server `number=1234` (exact match — no substring,
/// no wildcards). Chip renders as `= "1234"` to be honest about the
/// match shape. Users typing a partial number expect a substring; the
/// free-text `filter=` already covers that. Clients and vendors both take
/// it (`ClientFilters::number`, `VendorFilters::number`).
class NumberFilterKey extends FilterKey {
  const NumberFilterKey({String hintKey = 'number_filter_hint'})
    : _hintKey = hintKey;

  /// The value-entry hint — "Type the exact client number" by default.
  final String _hintKey;

  static const String _serverKey = 'number';

  @override
  String get id => 'number';

  @override
  String displayLabel(BuildContext context) => context.tr('number');

  @override
  IconData get icon => Icons.tag;

  @override
  FilterValueType get valueType => FilterValueType.string;

  @override
  bool get singleValue => true;

  // Server `number=` is an exact match (no substring / wildcards). The
  // chip renders `= "value"` so the match shape is honest, and the local
  // watch mirrors it with an exact predicate — so the key stays available.
  @override
  bool isAvailable(GenericListViewModel<dynamic> vm) => true;

  @override
  bool isAtDefault(GenericListViewModel<dynamic> vm) =>
      (vm.extraFilters[_serverKey] ?? const <String>{}).isEmpty;

  @override
  String? hintForValueMode(BuildContext context) => context.tr(_hintKey);

  @override
  Iterable<FilterToken> tokensFrom(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
  ) {
    final values = vm.extraFilters[_serverKey] ?? const <String>{};
    return [
      for (final wire in values)
        FilterToken(
          keyId: id,
          displayKey: displayLabel(context),
          rawValue: wire,
          displayValue: '= "$wire"',
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
    return writeSingleExtraFilter(vm, _serverKey, trimmed);
  }

  @override
  Future<void> removeValue(GenericListViewModel<dynamic> vm, String rawValue) {
    return writeSingleExtraFilter(vm, _serverKey, null);
  }

  @override
  String? editableValueText(String rawValue) => rawValue;
}
