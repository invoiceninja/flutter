import 'package:flutter/widgets.dart';

import 'package:admin/data/models/domain/bank_transaction.dart';
import 'package:admin/data/repositories/tag_repository.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/date_column_filter_key.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_keys_common.dart';
import 'package:admin/ui/core/list/search/tag_filter_key.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';

/// Per-key cap on the synchronous `quickValueSuggestions` lookup. Mirrors
/// the constant in `client_filter_keys.dart` so the picker stays balanced
/// across keys.
const int _kQuickValueLimitPerKey = 3;

/// `status:unmatched` / `status:matched` / `status:converted` — multi-valued
/// `extraFilters['status_id']` filter for the bank-transaction list.
/// Mirrors `IsFilterKey` in shape; differs only in writing to
/// `extraFilters` (status is per-entity) instead of `vm.states` (which
/// covers active/archived/deleted state).
class TransactionStatusFilterKey extends FilterKey {
  const TransactionStatusFilterKey();

  static const String _serverKey = 'status_id';

  @override
  String get id => 'status';

  @override
  String displayLabel(BuildContext context) => context.tr('status');

  @override
  FilterValueType get valueType => FilterValueType.enumeration;

  @override
  bool get singleValue => false;

  /// Render checkboxes so multi-status selection is discoverable.
  @override
  bool get checkboxMultiSelect => true;

  @override
  bool isAtDefault(GenericListViewModel<dynamic> vm) =>
      (vm.extraFilters[_serverKey] ?? const <String>{}).isEmpty;

  @override
  Iterable<FilterToken> tokensFrom(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
  ) {
    final selected = vm.extraFilters[_serverKey] ?? const <String>{};
    return [
      for (final entry in _options(context).entries)
        if (selected.contains(entry.key))
          FilterToken(
            keyId: id,
            displayKey: displayLabel(context),
            rawValue: entry.key,
            displayValue: entry.value,
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
      for (final entry in _options(context).entries)
        FilterValueSuggestion(rawValue: entry.key, displayLabel: entry.value),
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

  @override
  List<FilterValueSuggestion> quickValueSuggestions(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final hits = <FilterValueSuggestion>[];
    for (final entry in _options(context).entries) {
      if (hits.length >= _kQuickValueLimitPerKey) break;
      if (entry.value.toLowerCase().startsWith(q)) {
        hits.add(
          FilterValueSuggestion(rawValue: entry.key, displayLabel: entry.value),
        );
      }
    }
    return hits;
  }

  @override
  Future<void> addValue(
    GenericListViewModel<dynamic> vm,
    String rawValue,
  ) async {
    final wire = _normalize(rawValue);
    if (wire == null) return;
    final current = vm.extraFilters[_serverKey] ?? const <String>{};
    await vm.setExtraFilter(serverKey: _serverKey, values: {...current, wire});
  }

  @override
  Future<void> removeValue(
    GenericListViewModel<dynamic> vm,
    String rawValue,
  ) async {
    final wire = _normalize(rawValue);
    if (wire == null) return;
    final current = vm.extraFilters[_serverKey] ?? const <String>{};
    if (!current.contains(wire)) return;
    final next = Set<String>.from(current)..remove(wire);
    await vm.setExtraFilter(serverKey: _serverKey, values: next);
  }

  /// Tap the row label → replace the whole status set in one VM write.
  /// `_normalize` → null for an unrecognised value; the helper treats null
  /// as "clear", matching the prior explicit empty-set branch.
  @override
  Future<void> selectExclusive(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String rawValue,
  ) => writeSingleExtraFilter(vm, _serverKey, _normalize(rawValue));

  /// Clear the whole status set in one VM write.
  @override
  Future<void> clear(GenericListViewModel<dynamic> vm, BuildContext context) =>
      writeSingleExtraFilter(vm, _serverKey, null);

  /// Accept either the wire id (`1`/`2`/`3`) or the localization key
  /// (`unmatched`/`matched`/`converted`) on `addValue` so users can type
  /// `status:matched` directly.
  String? _normalize(String raw) {
    switch (raw.trim().toLowerCase()) {
      case kTransactionStatusUnmatched:
      case 'unmatched':
        return kTransactionStatusUnmatched;
      case kTransactionStatusMatched:
      case 'matched':
        return kTransactionStatusMatched;
      case kTransactionStatusConverted:
      case 'converted':
        return kTransactionStatusConverted;
      default:
        return null;
    }
  }

  Map<String, String> _options(BuildContext context) => {
    kTransactionStatusUnmatched: context.tr('unmatched'),
    kTransactionStatusMatched: context.tr('matched'),
    kTransactionStatusConverted: context.tr('converted'),
  };
}

/// `type:deposit` / `type:withdrawal` — single-valued
/// `extraFilters['base_type']` filter.
class TransactionTypeFilterKey extends FilterKey {
  const TransactionTypeFilterKey();

  static const String _serverKey = 'base_type';

  @override
  String get id => 'type';

  @override
  String displayLabel(BuildContext context) => context.tr('type');

  @override
  FilterValueType get valueType => FilterValueType.enumeration;

  @override
  bool get singleValue => true;

  @override
  bool isAtDefault(GenericListViewModel<dynamic> vm) =>
      (vm.extraFilters[_serverKey] ?? const <String>{}).isEmpty;

  @override
  Iterable<FilterToken> tokensFrom(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
  ) {
    final selected = vm.extraFilters[_serverKey] ?? const <String>{};
    if (selected.isEmpty) return const [];
    final raw = selected.first;
    final label = _label(context, raw);
    if (label == null) return const [];
    return [
      FilterToken(
        keyId: id,
        displayKey: displayLabel(context),
        rawValue: raw,
        displayValue: label,
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
      FilterValueSuggestion(
        rawValue: kTransactionTypeCredit,
        displayLabel: context.tr('deposit'),
      ),
      FilterValueSuggestion(
        rawValue: kTransactionTypeDebit,
        displayLabel: context.tr('withdrawal'),
      ),
    ];
    return Stream.value(
      q.isEmpty
          ? all
          : all
                .where(
                  (s) =>
                      s.displayLabel.toLowerCase().contains(q) ||
                      s.rawValue.toLowerCase().contains(q),
                )
                .toList(),
    );
  }

  @override
  List<FilterValueSuggestion> quickValueSuggestions(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final hits = <FilterValueSuggestion>[];
    final candidates = [
      (kTransactionTypeCredit, context.tr('deposit')),
      (kTransactionTypeDebit, context.tr('withdrawal')),
    ];
    for (final (raw, label) in candidates) {
      if (hits.length >= _kQuickValueLimitPerKey) break;
      if (label.toLowerCase().startsWith(q)) {
        hits.add(FilterValueSuggestion(rawValue: raw, displayLabel: label));
      }
    }
    return hits;
  }

  @override
  Future<void> addValue(
    GenericListViewModel<dynamic> vm,
    String rawValue,
  ) async {
    final wire = _normalize(rawValue);
    if (wire == null) return;
    // singleValue: true — replace any prior selection.
    await vm.setExtraFilter(serverKey: _serverKey, values: {wire});
  }

  @override
  Future<void> removeValue(
    GenericListViewModel<dynamic> vm,
    String rawValue,
  ) async {
    await vm.setExtraFilter(serverKey: _serverKey, values: const {});
  }

  String? _normalize(String raw) {
    switch (raw.trim().toUpperCase()) {
      case kTransactionTypeCredit:
      case 'DEPOSIT':
        return kTransactionTypeCredit;
      case kTransactionTypeDebit:
      case 'WITHDRAWAL':
        return kTransactionTypeDebit;
      default:
        return null;
    }
  }

  String? _label(BuildContext context, String raw) {
    switch (raw) {
      case kTransactionTypeCredit:
        return context.tr('deposit');
      case kTransactionTypeDebit:
        return context.tr('withdrawal');
      default:
        return null;
    }
  }
}

/// Default filter-key set for the transactions list. Includes the
/// standard archive toggle plus transaction-specific status + type
/// dimensions and a transaction-date range. Bank-account filter is wired
/// via a query param on the route (`/transactions?bank_account_id=…`), not
/// via the token search.
///
/// `date` routes to the server's `date_range` param — `BankTransactionFilters`
/// extends `QueryFilters`, which exposes `date_range` (`column,start,end`)
/// against the `bank_transactions.date` column.
List<FilterKey> buildTransactionFilterKeys({
  required TagRepository tags,
  required String companyId,
}) => <FilterKey>[
  const IsFilterKey(),
  TagFilterKey(
    tags: tags,
    companyId: companyId,
    entityType: 'bank_transaction',
  ),
  const TransactionStatusFilterKey(),
  const TransactionTypeFilterKey(),
  const DateColumnFilterKey(id: 'date', serverKey: 'date', labelKey: 'date'),
];
