import 'package:flutter/widgets.dart';

import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_custom_fields.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/tag_repository.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/client_filter_key.dart';
import 'package:admin/ui/core/list/search/custom_field_filter_key.dart';
import 'package:admin/ui/core/list/search/date_column_filter_key.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_keys_common.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';
import 'package:admin/ui/core/list/search/membership_filter_key.dart';
import 'package:admin/ui/core/list/search/tag_filter_key.dart';

/// Per-key cap on the synchronous `quickValueSuggestions` lookup. Three rows
/// matches `IsFilterKey` so the picker stays consistent across keys.
const int _kQuickValueLimitPerKey = 3;

/// Build the filter keys exposed in the payments list's search field.
///
/// `client_id` was confirmed working server-side in the May 2026 audit
/// (`client_id=<id>` → narrows). The "has unapplied funds" toggle is a
/// dedicated bool on the ViewModel, not a search token.
List<FilterKey> buildPaymentFilterKeys({
  required ClientRepository clients,
  required TagRepository tags,
  required String companyId,
  Company? company,
  String? Function(String id)? nameForClientId,
}) => <FilterKey>[
  const IsFilterKey(),
  TagFilterKey(tags: tags, companyId: companyId, entityType: 'payment'),
  ClientFilterKey(
    clients: clients,
    companyId: companyId,
    nameForClientId: nameForClientId,
  ),
  const PaymentStatusFilterKey(),
  const DateColumnFilterKey(id: 'date', serverKey: 'date', labelKey: 'date'),
  for (var i = 1; i <= 4; i++)
    CustomFieldFilterKey(
      columnIndex: i,
      configuredLabel: company?.customFieldLabel('payment$i') ?? '',
    ),
];

/// `status:pending|cancelled|failed|completed|partially_refunded|refunded|
/// partially_unapplied` — multi-valued. Writes to
/// `vm.extraFilters['client_status']`, the server-backed
/// `PaymentFilters::client_status` param the dashboard's "Paid" KPI deep-link
/// uses (`completed`).
class PaymentStatusFilterKey extends FilterKey {
  const PaymentStatusFilterKey();

  static const String _serverKey = 'client_status';

  /// `(wire value, localization key)`. Mirrors `PaymentFilters::client_status`.
  static const List<(String, String)> _statuses = [
    ('pending', 'pending'),
    ('cancelled', 'cancelled'),
    ('failed', 'failed'),
    ('completed', 'completed'),
    ('partially_refunded', 'partially_refunded'),
    ('refunded', 'refunded'),
    ('partially_unapplied', 'partially_unapplied'),
  ];

  static String _labelKeyFor(String wire) {
    for (final (value, labelKey) in _statuses) {
      if (value == wire) return labelKey;
    }
    return wire;
  }

  @override
  String get id => 'status';

  @override
  String displayLabel(BuildContext context) => context.tr('status');

  @override
  FilterValueType get valueType => FilterValueType.enumeration;

  @override
  bool get singleValue => false;

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
    final values = vm.extraFilters[_serverKey] ?? const <String>{};
    return [
      for (final v in values)
        FilterToken(
          keyId: id,
          displayKey: displayLabel(context),
          rawValue: v,
          displayValue: context.tr(_labelKeyFor(v)),
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
      for (final (value, labelKey) in _statuses)
        FilterValueSuggestion(
          rawValue: value,
          displayLabel: context.tr(labelKey),
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
    for (final (value, labelKey) in _statuses) {
      if (out.length >= _kQuickValueLimitPerKey) break;
      final label = context.tr(labelKey);
      if (label.toLowerCase().startsWith(q)) {
        out.add(FilterValueSuggestion(rawValue: value, displayLabel: label));
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

  @override
  Future<void> selectExclusive(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String rawValue,
  ) => writeSingleExtraFilter(vm, _serverKey, rawValue.trim());

  @override
  Future<void> clear(GenericListViewModel<dynamic> vm, BuildContext context) =>
      writeSingleExtraFilter(vm, _serverKey, null);
}
