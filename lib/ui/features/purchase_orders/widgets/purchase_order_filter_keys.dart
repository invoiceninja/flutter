import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_custom_fields.dart';
import 'package:admin/data/models/domain/purchase_order_status.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/tag_repository.dart';
import 'package:admin/data/repositories/vendor_repository.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/client_filter_key.dart';
import 'package:admin/ui/core/list/search/custom_field_filter_key.dart';
import 'package:admin/ui/core/list/search/date_column_filter_key.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_keys_common.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';
import 'package:admin/ui/core/list/search/membership_filter_key.dart';
import 'package:admin/ui/core/list/search/record_chip_names.dart';
import 'package:admin/ui/core/list/search/server_name_suggestions.dart';
import 'package:admin/ui/core/list/search/tag_filter_key.dart';

/// The purchase orders list's search-field filters.
///
/// Every one is server-backed (`PurchaseOrderFilters` and the base
/// `QueryFilters`) and mirrored by `PurchaseOrderDao.watchPage`: Status as
/// `client_status`, Client as `client_id` (several travel as `client_ids`),
/// Vendor as `vendor_id`, and the two dates as `date_range` /
/// `due_date_range` — the server has no single-date comparison here, so the
/// repository turns one into the window that means the same.
List<FilterKey> buildPurchaseOrderFilterKeys({
  required ClientRepository clients,
  required VendorRepository vendors,
  required TagRepository tags,
  required String companyId,
  Company? company,
  String? Function(String id)? nameForClientId,
  String? Function(String id)? nameForVendorId,
}) => <FilterKey>[
  const IsFilterKey(),
  const PurchaseOrderStatusFilterKey(),
  PurchaseOrderVendorFilterKey(
    vendors: vendors,
    companyId: companyId,
    nameForVendorId: nameForVendorId,
  ),
  // A purchase order is the vendor's document; its client is the secondary
  // party, so Client is not among the suggested filters here.
  ClientFilterKey(
    clients: clients,
    companyId: companyId,
    nameForClientId: nameForClientId,
    isPrimary: false,
  ),
  const DateColumnFilterKey(
    id: 'date',
    serverKey: 'date',
    labelKey: 'date',
    hintKey: 'date_filter_hint',
    isPrimary: true,
  ),
  const DateColumnFilterKey(
    id: 'due_date',
    serverKey: 'due_date',
    labelKey: 'due_date',
    hintKey: 'date_filter_hint',
    lookAhead: true,
  ),
  TagFilterKey(tags: tags, companyId: companyId, entityType: 'purchase_order'),
  // Purchase orders reuse the `invoice` custom-field config slots — there are
  // no `purchase_order1..4` keys server-side, and the PO detail/edit screens
  // already read `prefix: 'invoice'`. Reading the wrong slot yields an empty
  // label, which silently drops all four filters (`isAvailable` is false).
  for (var i = 1; i <= 4; i++)
    CustomFieldFilterKey(
      columnIndex: i,
      configuredLabel: company?.customFieldLabel('invoice$i') ?? '',
    ),
];

/// `status:draft|sent|accepted|cancelled` — multi-valued, server
/// `client_status` (a plain `whereIn` on `status_id`; `sent` is exact only
/// from server 5.13.44 — see `PurchaseOrderListViewModel`). Received has no
/// server branch, so it is not offered: a value the server cannot honour
/// would narrow the cached rows and then be undone by the next fetch.
class PurchaseOrderStatusFilterKey extends MembershipFilterKey {
  const PurchaseOrderStatusFilterKey();

  static const List<PurchaseOrderStatus> _statuses = [
    PurchaseOrderStatus.draft,
    PurchaseOrderStatus.sent,
    PurchaseOrderStatus.accepted,
    PurchaseOrderStatus.cancelled,
  ];

  static String _labelKeyFor(String wire) {
    for (final s in _statuses) {
      if (s.name == wire) return s.labelKey;
    }
    return wire;
  }

  @override
  String get id => 'status';

  @override
  bool get acceptsTypedValue => false;

  @override
  bool get isPrimary => true;

  @override
  String get serverKey => 'client_status';

  @override
  bool get checkboxMultiSelect => true;

  @override
  String displayLabel(BuildContext context) => context.tr('status');

  // Localize the chip label (the base's `displayValueFor` has no context).
  @override
  Iterable<FilterToken> tokensFrom(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
  ) {
    final values = vm.extraFilters[serverKey] ?? const <String>{};
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
      for (final s in _statuses)
        FilterValueSuggestion(
          rawValue: s.name,
          displayLabel: context.tr(s.labelKey),
        ),
    ];
    final filtered = q.isEmpty
        ? all
        : all.where((s) => s.displayLabel.toLowerCase().contains(q)).toList();
    return Stream.value(filtered);
  }
}

/// `vendor:foo` — ONE vendor, server `vendor_id`. Single-valued because the
/// base `QueryFilters::vendor_id` decodes a single id and purchase orders
/// have no `vendor_ids` (expenses do). Its id is `vendor`, which an embedded
/// vendor tab locks (`PurchaseOrderListViewModel.lockedFilterKeyIds`).
class PurchaseOrderVendorFilterKey extends MembershipFilterKey {
  PurchaseOrderVendorFilterKey({
    required this.vendors,
    required this.companyId,
    this.nameForVendorId,
  });

  final VendorRepository vendors;
  final String companyId;

  /// Synchronous `vendor_id → name` lookup from the search field's name
  /// streams — see `ClientFilterKey.nameForClientId`.
  final String? Function(String id)? nameForVendorId;

  @override
  String get id => 'vendor';

  @override
  String get serverKey => 'vendor_id';

  @override
  bool get acceptsTypedValue => false;

  @override
  bool get isPrimary => true;

  @override
  bool get singleValue => true;

  @override
  int? get idleSuggestionCap => 50;

  @override
  String displayLabel(BuildContext context) => context.tr('vendor');

  /// A chip naming a vendor the cache has never held fetches that one
  /// vendor — see [RecordChipNameHydrator].
  late final RecordChipNameHydrator _names = RecordChipNameHydrator(
    (id) => vendors.ensureLoaded(companyId: companyId, id: id),
  );

  @override
  String displayValueFor(String rawValue) =>
      _names.resolve(rawValue, nameForVendorId);

  /// One vendor at a time: a pick replaces the one applied.
  @override
  Future<void> addValue(GenericListViewModel<dynamic> vm, String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) return Future.value();
    return writeSingleExtraFilter(vm, serverKey, trimmed);
  }

  @override
  Stream<List<FilterValueSuggestion>> watchValueSuggestions(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String query,
  ) {
    final idle = query.trim().isEmpty;
    return namesWithServerSearch(
      names: vendors.watchActiveNames(companyId: companyId),
      query: query,
      fetch: (q) =>
          vendors.ensurePageLoaded(companyId: companyId, page: 1, search: q),
      searchedIds: (q) => vendors
          .watchPage(companyId: companyId, search: q)
          .map((rows) => [for (final v in rows) v.id]),
    ).map(
      (rows) => [
        for (final v in idle ? rows.take(idleSuggestionCap!) : rows)
          FilterValueSuggestion(
            rawValue: v.id,
            displayLabel: v.name.isEmpty ? v.id : v.name,
          ),
      ],
    );
  }
}
