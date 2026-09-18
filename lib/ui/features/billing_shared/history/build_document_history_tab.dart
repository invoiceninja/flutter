import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/widgets/party_contacts_builder.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/billing_shared/history/billing_doc_history_tab.dart';
import 'package:admin/utils/formatting.dart';

/// Builds the History tab for a billing document's detail screen.
///
/// One call site per screen, mirroring `buildStandardDocumentsTab`. It owns
/// the three lookups the tab needs but must not perform per-row: the party's
/// contacts, the party's **currency**, and the company's user roster. All are
/// watched once here and handed down as plain values.
///
/// The currency is not a field on the document — it belongs to the party, and
/// on a purchase order that party is the *vendor*. Resolving it here rather
/// than taking it as a parameter keeps the call sites from having to hoist a
/// watch they otherwise do not need. Drift keys active query streams by
/// SQL + variables, so watching a row the screen already watches costs one
/// subscription and no extra query.
///
/// **Label and icon.** `tr('history')` is translated in every bundle (the
/// obvious alternative, `versions`, exists in none). The icon is deliberately
/// NOT `Icons.history_outlined` — every one of these screens already gives
/// that glyph to its Activity tab (two slots to the left, three on a recurring
/// invoice where Schedule intervenes), and the detail strip
/// shows only about three tabs at a time on a narrow pane, so the same clock
/// twice would be a coin flip the user cannot even see to resolve.
EntityDetailTab buildDocumentHistoryTab({
  required BuildContext context,
  required Services services,
  required String companyId,
  required String basePath,
  required String entityId,
  required Decimal currentAmount,
  required DateTime? currentUpdatedAt,
  required ValueNotifier<String?> selection,
  required void Function(String? activityId) onOpenVersion,
  required bool showSelection,
  Formatter? formatter,
  String clientId = '',
  String vendorId = '',
}) {
  final isVendorParty = vendorId.isNotEmpty;
  return EntityDetailTab(
    label: context.tr('history'),
    icon: Icons.layers_outlined,
    bodyBuilder: (context) => _PartyBuilder(
      services: services,
      companyId: companyId,
      clientId: clientId,
      vendorId: vendorId,
      builder: (context, contacts, currencyId) => WatchBuilder<List<User>>(
        cacheKey: ('history-users', companyId),
        initialData: const [],
        create: () => services.user.watchAllForPicker(companyId: companyId),
        builder: (context, snap) => ValueListenableBuilder<String?>(
          valueListenable: selection,
          builder: (context, selected, _) => BillingDocHistoryTab(
            api: services.documentVersions,
            basePath: basePath,
            entityId: entityId,
            contacts: contacts,
            userNames: {
              for (final u in snap.data ?? const <User>[])
                if (u.displayName.isNotEmpty) u.id: u.displayName,
            },
            currentAmount: currentAmount,
            currentUpdatedAt: currentUpdatedAt,
            formatter: formatter,
            currencyId: currencyId,
            isVendorParty: isVendorParty,
            selectedActivityId: selected,
            showSelection: showSelection,
            planBlocksBackups: documentBackupsBlockedByPlan(services),
            onOpenVersion: onOpenVersion,
          ),
        ),
      ),
    ),
  );
}

/// True when this account's plan means the server writes no backups at all, so
/// the History tab can explain an empty list instead of implying the document
/// was never edited.
///
/// `ActivityRepository::createBackup()` bails on
/// `$account->isFreeHostedClient()`, which is `plan` free/null/empty **or** a
/// `plan_expires` more than 12 hours past. Self-hosted is never affected.
///
/// Deliberately the slug-only `isPaidPlanSlug` (plus `isPlanExpired`) rather
/// than `isFreePlan`: the latter routes through `hasProAccess`, which is
/// trial-aware, so it reports `false` for exactly the trialing user whose
/// history is empty — the server's predicate has no trial branch.
bool documentBackupsBlockedByPlan(Services services) {
  final session = services.auth.session.value;
  if (session == null || !session.isHosted) return false;
  return !session.isPaidPlanSlug || session.isPlanExpired;
}

/// Watches a billing document's party once and yields both of the things the
/// History tab needs from it: the contacts (to name a portal approver) and the
/// currency (to format money).
///
/// A local widget rather than an extension of [PartyContactsBuilder]: that one
/// is shared by the Email History tab and the `Viewed` pill tooltip, neither of
/// which wants a currency, and widening it would make both pay for a field they
/// discard.
class _PartyBuilder extends StatelessWidget {
  const _PartyBuilder({
    required this.services,
    required this.companyId,
    required this.clientId,
    required this.vendorId,
    required this.builder,
  });

  final Services services;
  final String companyId;
  final String clientId;
  final String vendorId;
  final Widget Function(
    BuildContext context,
    PartyContacts contacts,
    String? currencyId,
  )
  builder;

  @override
  Widget build(BuildContext context) {
    if (clientId.isEmpty && vendorId.isEmpty) {
      return builder(context, const {}, null);
    }
    return WatchBuilder<({PartyContacts contacts, String? currencyId})>(
      cacheKey: ('history-party', companyId, clientId, vendorId),
      initialData: (contacts: const {}, currencyId: null),
      create: () => clientId.isNotEmpty
          ? services.clients
                .watch(companyId: companyId, id: clientId)
                .map(
                  (c) => (
                    contacts: contactsOfClient(c),
                    currencyId: c?.currencyId,
                  ),
                )
          : services.vendors
                .watch(companyId: companyId, id: vendorId)
                .map(
                  (v) => (
                    contacts: contactsOfVendor(v),
                    currencyId: v?.currencyId,
                  ),
                ),
      builder: (context, snap) {
        final data =
            snap.data ??
            (
              contacts: const <String, ({String name, String email})>{},
              currencyId: null,
            );
        return builder(context, data.contacts, data.currencyId);
      },
    );
  }
}
