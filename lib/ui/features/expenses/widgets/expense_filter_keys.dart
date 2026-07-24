import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:admin/data/models/domain/expense_category.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/expense_category_repository.dart';
import 'package:admin/data/repositories/project_repository.dart';
import 'package:admin/data/repositories/tag_repository.dart';
import 'package:admin/data/repositories/vendor_repository.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/client_filter_key.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_keys_common.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';
import 'package:admin/ui/core/list/search/membership_filter_key.dart';
import 'package:admin/ui/core/list/search/tag_filter_key.dart';

/// Build the filter keys exposed in the expenses list's search field.
///
/// Live server-side: `client_id`, `categories`, and — as of the v5 filter
/// PR — `project_ids` / `vendor_ids` (`ExpenseFilters::project_ids` /
/// `vendor_ids`, CSV of hashids → `whereIn`). The local `ExpenseDao`
/// mirrors all of them.
List<FilterKey> buildExpenseFilterKeys({
  required ClientRepository clients,
  required ExpenseCategoryRepository categories,
  required ProjectRepository projects,
  required VendorRepository vendors,
  required TagRepository tags,
  required String companyId,
  String? Function(String id)? nameForClientId,
}) => <FilterKey>[
  const IsFilterKey(),
  TagFilterKey(tags: tags, companyId: companyId, entityType: 'expense'),
  ClientFilterKey(
    clients: clients,
    companyId: companyId,
    nameForClientId: nameForClientId,
  ),
  const ExpenseStatusFilterKey(),
  ExpenseCategoryFilterKey(categories: categories, companyId: companyId),
  ExpenseProjectFilterKey(projects: projects, companyId: companyId),
  ExpenseVendorFilterKey(vendors: vendors, companyId: companyId),
];

/// `status:logged|pending|invoiced|paid|unpaid` — multi-valued. Expense status
/// is computed client-side (`Expense.calculatedStatusId` + `isPaid`), so it's
/// applied as a LOCAL Drift predicate (`ExpenseDao.watchPage`) built from the
/// denormalized `invoice_id` / `should_be_invoiced` / `is_paid` columns. The
/// wire values match Invoice Ninja's `ExpenseFilters::client_status`, so the
/// same set is forwarded to the server (best-effort) under `client_status`.
class ExpenseStatusFilterKey extends MembershipFilterKey {
  const ExpenseStatusFilterKey();

  /// `(wire value, localization key)` — mirrors `kExpenseStatusLabels`.
  static const List<(String, String)> _statuses = [
    ('logged', 'logged'),
    ('pending', 'pending'),
    ('invoiced', 'invoiced'),
    ('paid', 'paid'),
    ('unpaid', 'unpaid'),
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
}

/// `category:foo` — multi-valued, resolved through the expense-category
/// repository. `serverKey` is `categories` (`ExpenseFilters::categories` —
/// CSV of category ids → `whereIn('category_id', …)`).
///
/// Mirrors the Tasks `ProjectFilterKey` pattern: the suggestion menu
/// streams `(id, name)` from `ExpenseCategoryRepository.watchActive`, and
/// the same stream populates an in-memory `id → name` cache so chips show
/// the category name instead of the raw id.
class ExpenseCategoryFilterKey extends MembershipFilterKey {
  ExpenseCategoryFilterKey({
    required this.categories,
    required this.companyId,
  }) {
    _namesSub = categories.watchActive(companyId: companyId).listen((rows) {
      _names
        ..clear()
        ..addEntries(rows.map((c) => MapEntry(c.id, c.name)));
    });
  }

  final ExpenseCategoryRepository categories;
  final String companyId;
  final Map<String, String> _names = <String, String>{};
  StreamSubscription<List<ExpenseCategory>>? _namesSub;

  @override
  String get id => 'category';

  @override
  String get serverKey => 'categories';

  /// Render checkboxes — inherits the single-write `selectExclusive` /
  /// `clear` from [MembershipFilterKey].
  @override
  bool get checkboxMultiSelect => true;

  @override
  String displayLabel(BuildContext context) => context.tr('category');

  @override
  String displayValueFor(String rawValue) {
    final cached = _names[rawValue];
    if (cached != null && cached.isNotEmpty) return cached;
    return rawValue;
  }

  @override
  Stream<List<FilterValueSuggestion>> watchValueSuggestions(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    return categories.watchActive(companyId: companyId).map((all) {
      final filtered = q.isEmpty
          ? all.take(50)
          : all.where((c) => c.name.toLowerCase().contains(q));
      return [
        for (final c in filtered)
          FilterValueSuggestion(
            rawValue: c.id,
            displayLabel: c.name.isEmpty ? c.id : c.name,
          ),
      ];
    });
  }

  /// Release the names-cache subscription when the key is replaced (e.g.
  /// company switch). `FilterKey` has no lifecycle hook today, so this
  /// lives until GC otherwise — same trade-off as Tasks `ProjectFilterKey`.
  @override
  void dispose() {
    _namesSub?.cancel();
    _namesSub = null;
  }
}

/// Shared base for the expense Project / Vendor filters: multi-valued,
/// repo-backed via an `(id, name)` record stream, with an in-memory
/// id→name cache so chips render names. Server params are the v5
/// `ExpenseFilters::project_ids` / `vendor_ids` (CSV hashids).
abstract class _RecordMembershipFilterKey extends MembershipFilterKey {
  _RecordMembershipFilterKey({required this.companyId}) {
    _namesSub = nameStream().listen((rows) {
      _names
        ..clear()
        ..addEntries(rows.map((r) => MapEntry(r.id, r.name)));
    });
  }

  final String companyId;
  final Map<String, String> _names = <String, String>{};
  StreamSubscription<List<({String id, String name})>>? _namesSub;

  Stream<List<({String id, String name})>> nameStream();

  @override
  bool get checkboxMultiSelect => true;

  @override
  String displayValueFor(String rawValue) {
    final cached = _names[rawValue];
    return (cached != null && cached.isNotEmpty) ? cached : rawValue;
  }

  @override
  Stream<List<FilterValueSuggestion>> watchValueSuggestions(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    return nameStream().map((all) {
      final filtered = q.isEmpty
          ? all.take(50)
          : all.where((r) => r.name.toLowerCase().contains(q));
      return [
        for (final r in filtered)
          FilterValueSuggestion(
            rawValue: r.id,
            displayLabel: r.name.isEmpty ? r.id : r.name,
          ),
      ];
    });
  }

  @override
  void dispose() {
    _namesSub?.cancel();
    _namesSub = null;
  }
}

/// `project:foo` — multi-valued; server `project_ids` (CSV hashids).
class ExpenseProjectFilterKey extends _RecordMembershipFilterKey {
  ExpenseProjectFilterKey({required this.projects, required super.companyId});

  final ProjectRepository projects;

  @override
  String get id => 'project';

  @override
  String get serverKey => 'project_ids';

  @override
  String displayLabel(BuildContext context) => context.tr('project');

  @override
  Stream<List<({String id, String name})>> nameStream() =>
      projects.watchActiveNames(companyId: companyId);
}

/// `vendor:foo` — multi-valued; server `vendor_ids` (CSV hashids).
class ExpenseVendorFilterKey extends _RecordMembershipFilterKey {
  ExpenseVendorFilterKey({required this.vendors, required super.companyId});

  final VendorRepository vendors;

  @override
  String get id => 'vendor';

  @override
  String get serverKey => 'vendor_ids';

  @override
  String displayLabel(BuildContext context) => context.tr('vendor');

  @override
  Stream<List<({String id, String name})>> nameStream() =>
      vendors.watchActiveNames(companyId: companyId);
}
