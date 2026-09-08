import 'package:flutter/material.dart';

import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';
import 'package:admin/ui/core/list/search/membership_filter_key.dart';

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
  String get serverKey => 'client_id';

  @override
  String displayLabel(BuildContext context) => context.tr('client');

  @override
  IconData get icon => Icons.account_circle_outlined;

  @override
  String displayValueFor(String rawValue) {
    final resolved = nameForClientId?.call(rawValue);
    if (resolved != null && resolved.isNotEmpty) return resolved;
    return rawValue;
  }

  @override
  Stream<List<FilterValueSuggestion>> watchValueSuggestions(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    return clients.watchActiveNames(companyId: companyId).map((all) {
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
}
