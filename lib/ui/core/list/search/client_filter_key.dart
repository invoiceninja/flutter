import 'package:flutter/material.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';
import 'package:admin/ui/core/list/search/membership_filter_key.dart';
import 'package:admin/ui/core/list/search/record_chip_names.dart';
import 'package:admin/ui/core/list/search/server_name_suggestions.dart';

/// `client:foo` — multi-valued client filter shared by every list whose
/// API endpoint honors `client_id` (invoices, quotes, credits, recurring
/// invoices, payments, expenses, projects — all confirmed working server
/// side in the May 2026 audit).
///
/// Chip-name resolution is decoupled from the filter key itself:
/// `EntityTokenSearchField` subscribes once (via `StreamBuilder`) to
/// `ClientRepository.watchActiveNames` and passes a synchronous resolver
/// closure in via [nameForClientId]. The names map lives in the widget tree,
/// and because [displayValueFor] calls the closure lazily at render time, a
/// key built earlier still resolves the latest names — so the key list is NOT
/// rebuilt on a name emit, which would re-open a `TagFilterKey` Drift
/// subscription each time. The alternative it replaced was a per-instance
/// stream cache that showed the raw id until a later rebuild.
class ClientFilterKey extends MembershipFilterKey {
  ClientFilterKey({
    required this.clients,
    required this.companyId,
    this.nameForClientId,
    this.isPrimary = true,
  });

  final ClientRepository clients;
  final String companyId;

  /// Synchronous `client_id → display name` lookup, supplied by the parent
  /// widget. Returning `null` (or an empty string) falls back to the raw
  /// id so chips never render blank when the names stream hasn't emitted.
  final String? Function(String id)? nameForClientId;

  @override
  String get id => 'client';

  @override
  bool get acceptsTypedValue => false;

  /// Suggested on every list it is on but one: a purchase order is the
  /// vendor's document, and its client the secondary party.
  @override
  final bool isPrimary;

  @override
  int? get idleSuggestionCap => 50;

  @override
  String get serverKey => 'client_id';

  @override
  String displayLabel(BuildContext context) => context.tr('client');

  @override
  IconData get icon => Icons.account_circle_outlined;

  /// The `client_id → name` map a list's `nameSources` hands this key's
  /// [nameForClientId]: every cached client, archived and deleted included
  /// (`ClientRepository.watchAllNames`). It used to be the active names, the
  /// suggestions' list, so a saved view or a deep link naming a client
  /// archived since showed its chip as a raw id.
  static Stream<Map<String, String>> chipNames(
    Services services,
    String companyId,
  ) => services.clients
      .watchAllNames(companyId: companyId)
      .map(
        (rows) => {
          for (final r in rows)
            if (r.name.isNotEmpty) r.id: r.name,
        },
      );

  /// A chip naming a client the cache has never held fetches that one
  /// client — see [RecordChipNameHydrator].
  late final RecordChipNameHydrator _names = RecordChipNameHydrator(
    (id) => clients.ensureLoaded(companyId: companyId, id: id),
  );

  @override
  String displayValueFor(String rawValue) =>
      _names.resolve(rawValue, nameForClientId);

  @override
  Stream<List<FilterValueSuggestion>> watchValueSuggestions(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String query,
  ) {
    final idle = query.trim().isEmpty;
    return namesWithServerSearch(
      names: clients.watchActiveNames(companyId: companyId),
      query: query,
      fetch: (q) =>
          clients.ensurePageLoaded(companyId: companyId, page: 1, search: q),
      searchedIds: (q) => clients
          .watchPage(companyId: companyId, search: q)
          .map((rows) => [for (final c in rows) c.id]),
    ).map(
      (rows) => [
        for (final c in idle ? rows.take(idleSuggestionCap!) : rows)
          FilterValueSuggestion(
            rawValue: c.id,
            displayLabel: c.name.isEmpty ? c.id : c.name,
          ),
      ],
    );
  }
}
