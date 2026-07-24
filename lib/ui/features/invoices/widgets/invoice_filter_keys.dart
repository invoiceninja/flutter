import 'package:flutter/widgets.dart';

import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_custom_fields.dart';
import 'package:admin/data/models/domain/invoice_status.dart';
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

/// Build the filter keys exposed in the invoices list's search field.
///
/// Confirmed working server-side (May 2026 audit): `is:*` (state),
/// `client:<id>` (`client_id`), `status:<id>` (`status_id`).
List<FilterKey> buildInvoiceFilterKeys({
  required ClientRepository clients,
  required TagRepository tags,
  required String companyId,
  Company? company,
  String? Function(String id)? nameForClientId,
}) => <FilterKey>[
  const IsFilterKey(),
  TagFilterKey(tags: tags, companyId: companyId, entityType: 'invoice'),
  ClientFilterKey(
    clients: clients,
    companyId: companyId,
    nameForClientId: nameForClientId,
  ),
  const InvoiceStatusFilterKey(),
  const InvoiceOverdueFilterKey(),
  const DateColumnFilterKey(id: 'date', serverKey: 'date', labelKey: 'date'),
  const DateColumnFilterKey(
    id: 'due_date',
    serverKey: 'due_date',
    labelKey: 'due_date',
  ),
  for (var i = 1; i <= 4; i++)
    CustomFieldFilterKey(
      columnIndex: i,
      configuredLabel: company?.customFieldLabel('invoice$i') ?? '',
    ),
];

/// `overdue:true` — invoices with `status_id ∈ {sent, partial}`,
/// `balance > 0`, and `due_date < today`. Server-backed via the v2
/// `overdue` query param (`InvoiceFilters::overdue`), the same param the
/// dashboard's "Needs Your Attention" / Overdue-KPI panels use — so a
/// deep-link from those panels lands on an exactly-matching list.
///
/// Writes its own `overdue` param, never `status_id` / `client_status`, so
/// it can't collide with [InvoiceStatusFilterKey] or the lifecycle filter
/// when the repo comma-joins `extraFilters`.
class InvoiceOverdueFilterKey extends FilterKey {
  const InvoiceOverdueFilterKey();

  static const String _serverKey = 'overdue';
  static const String _on = 'true';

  @override
  String get id => 'overdue';

  @override
  String displayLabel(BuildContext context) => context.tr('overdue');

  @override
  FilterValueType get valueType => FilterValueType.enumeration;

  @override
  bool get singleValue => true;

  // Boolean filter: tapping "Overdue" applies it in one tap (no value to pick).
  @override
  String? get directApplyValue => _on;

  @override
  bool isAtDefault(GenericListViewModel<dynamic> vm) =>
      !(vm.extraFilters[_serverKey] ?? const <String>{}).contains(_on);

  @override
  Iterable<FilterToken> tokensFrom(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
  ) {
    if (isAtDefault(vm)) return const [];
    return [
      FilterToken(
        keyId: id,
        displayKey: displayLabel(context),
        rawValue: _on,
        displayValue: context.tr('yes'),
      ),
    ];
  }

  @override
  Stream<List<FilterValueSuggestion>> watchValueSuggestions(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String query,
  ) => Stream.value([
    FilterValueSuggestion(rawValue: _on, displayLabel: context.tr('yes')),
  ]);

  @override
  List<FilterValueSuggestion> quickValueSuggestions(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    if (!context.tr('overdue').toLowerCase().startsWith(q)) return const [];
    return [
      FilterValueSuggestion(rawValue: _on, displayLabel: context.tr('overdue')),
    ];
  }

  @override
  Future<void> addValue(GenericListViewModel<dynamic> vm, String rawValue) =>
      writeSingleExtraFilter(vm, _serverKey, _on);

  @override
  Future<void> removeValue(GenericListViewModel<dynamic> vm, String rawValue) =>
      writeSingleExtraFilter(vm, _serverKey, null);

  @override
  Future<void> selectExclusive(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String rawValue,
  ) => writeSingleExtraFilter(vm, _serverKey, _on);

  @override
  Future<void> clear(GenericListViewModel<dynamic> vm, BuildContext context) =>
      writeSingleExtraFilter(vm, _serverKey, null);
}

/// `status:draft|sent|partial|paid|cancelled|reversed` — multi-valued.
///
/// Writes wire ids `'1'..'6'` to `vm.extraFilters['status_id']`; the
/// server-side audit confirmed `status_id=4` narrows to paid invoices.
/// Computed pseudo-statuses (`viewed`, `past_due`, `unpaid`) are
/// intentionally **not** included — they're derived client-side from
/// invitation + balance state and aren't filterable on the server.
class InvoiceStatusFilterKey extends FilterKey {
  const InvoiceStatusFilterKey();

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
          displayValue: context.tr(invoiceStatusLabelKey(v)),
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
      for (final s in InvoiceStatus.values)
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

  /// Free-text key-mode lookup: tighter `startsWith` matching against the
  /// status label so `pa` surfaces "Paid"/"Partial" without dragging in
  /// unrelated tokens.
  @override
  List<FilterValueSuggestion> quickValueSuggestions(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final out = <FilterValueSuggestion>[];
    for (final s in InvoiceStatus.values) {
      if (out.length >= _kQuickValueLimitPerKey) break;
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
