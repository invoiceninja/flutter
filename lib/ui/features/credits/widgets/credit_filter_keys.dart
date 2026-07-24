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

List<FilterKey> buildCreditFilterKeys({
  required ClientRepository clients,
  required TagRepository tags,
  required String companyId,
  Company? company,
  String? Function(String id)? nameForClientId,
}) => <FilterKey>[
  const IsFilterKey(),
  TagFilterKey(tags: tags, companyId: companyId, entityType: 'credit'),
  ClientFilterKey(
    clients: clients,
    companyId: companyId,
    nameForClientId: nameForClientId,
  ),
  const CreditClientStatusFilterKey(),
  const DateColumnFilterKey(id: 'date', serverKey: 'date', labelKey: 'date'),
  const DateColumnFilterKey(
    id: 'due_date',
    serverKey: 'due_date',
    labelKey: 'due_date',
  ),
  // Credits share Invoice Ninja's `invoice1..4` custom-field labels.
  for (var i = 1; i <= 4; i++)
    CustomFieldFilterKey(
      columnIndex: i,
      configuredLabel: company?.customFieldLabel('invoice$i') ?? '',
    ),
];

/// `status:draft|sent|partial|applied` — multi-valued.
///
/// Writes the status labels to `vm.extraFilters['client_status']`, the
/// server-backed `CreditFilters::client_status` param. Unlike quotes there are
/// no computed states (expired/upcoming/converted) — each label maps 1:1 to a
/// stored `status_id`, so `CreditDao.watchPage` applies a plain membership
/// test. `viewed` is a display-only computed status (a sent credit whose
/// invitation was opened) and is **not** a server filter dimension, so it is
/// intentionally absent — React omits it too.
///
/// Does not collide with lifecycle: `stateQueryParams` emits the distinct
/// `status` param (not `client_status`) — see
/// `BaseEntityRepository.stateQueryParams`.
class CreditClientStatusFilterKey extends FilterKey {
  const CreditClientStatusFilterKey();

  static const String _serverKey = 'client_status';

  /// `(wire value, localization key)`. Mirrors `CreditFilters::client_status`
  /// exactly — the server handles only these four.
  static const List<(String, String)> _statuses = [
    ('draft', 'draft'),
    ('sent', 'sent'),
    ('partial', 'partial'),
    ('applied', 'applied'),
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
