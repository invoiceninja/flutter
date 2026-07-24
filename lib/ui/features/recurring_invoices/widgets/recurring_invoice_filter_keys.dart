import 'package:flutter/widgets.dart';

import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_custom_fields.dart';
import 'package:admin/data/models/domain/recurring_invoice_status.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/tag_repository.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/client_filter_key.dart';
import 'package:admin/ui/core/list/search/custom_field_filter_key.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_keys_common.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';
import 'package:admin/ui/core/list/search/membership_filter_key.dart';
import 'package:admin/ui/core/list/search/tag_filter_key.dart';

List<FilterKey> buildRecurringInvoiceFilterKeys({
  required ClientRepository clients,
  required TagRepository tags,
  required String companyId,
  Company? company,
  String? Function(String id)? nameForClientId,
}) => <FilterKey>[
  const IsFilterKey(),
  TagFilterKey(
    tags: tags,
    companyId: companyId,
    entityType: 'recurring_invoice',
  ),
  ClientFilterKey(
    clients: clients,
    companyId: companyId,
    nameForClientId: nameForClientId,
  ),
  const RecurringInvoiceStatusFilterKey(),
  // Recurring invoices share Invoice Ninja's `invoice1..4` custom-fields.
  for (var i = 1; i <= 4; i++)
    CustomFieldFilterKey(
      columnIndex: i,
      configuredLabel: company?.customFieldLabel('invoice$i') ?? '',
    ),
];

/// `status:draft|active|paused|completed` — multi-valued lifecycle filter.
/// Writes wire ids `'1'..'4'` to `vm.extraFilters['status_id']`; the recurring
/// DAO turns them into an `isIn` predicate on the stored `statusId` column
/// (mirrors React's server-side `status_id` filter). Modeled on the invoices'
/// `InvoiceStatusFilterKey`.
class RecurringInvoiceStatusFilterKey extends FilterKey {
  const RecurringInvoiceStatusFilterKey();

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
    final ids = vm.extraFilters[_serverKey] ?? const <String>{};
    return [
      for (final v in ids)
        FilterToken(
          keyId: id,
          displayKey: displayLabel(context),
          rawValue: v,
          displayValue: context.tr(recurringInvoiceStatusLabelKey(v)),
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
      for (final s in RecurringInvoiceStatus.values)
        FilterValueSuggestion(
          rawValue: s.wireId,
          displayLabel: context.tr(s.labelKey),
        ),
    ];
    final filtered = q.isEmpty
        ? all
        : all.where((s) => s.displayLabel.toLowerCase().contains(q)).toList();
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
    final out = <FilterValueSuggestion>[];
    for (final s in RecurringInvoiceStatus.values) {
      if (out.length >= kQuickValueLimitPerKey) break;
      final label = context.tr(s.labelKey).toLowerCase();
      if (label.startsWith(q)) {
        out.add(
          FilterValueSuggestion(
            rawValue: s.wireId,
            displayLabel: context.tr(s.labelKey),
          ),
        );
      }
    }
    return out;
  }

  @override
  Future<void> addValue(GenericListViewModel<dynamic> vm, String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) return Future.value();
    return unionMembership(vm, _serverKey, trimmed);
  }

  @override
  Future<void> removeValue(GenericListViewModel<dynamic> vm, String rawValue) =>
      removeMembership(vm, _serverKey, rawValue);

  /// Tap the row label → replace the whole status set in one VM write.
  @override
  Future<void> selectExclusive(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String rawValue,
  ) => writeSingleExtraFilter(vm, _serverKey, rawValue.trim());

  /// Clear the whole status set in one VM write.
  @override
  Future<void> clear(GenericListViewModel<dynamic> vm, BuildContext context) =>
      writeSingleExtraFilter(vm, _serverKey, null);
}
