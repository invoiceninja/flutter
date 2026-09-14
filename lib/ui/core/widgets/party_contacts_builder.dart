import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/vendor_repository.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';

/// A billing party's contacts, keyed by contact id.
typedef PartyContacts = Map<String, ({String name, String email})>;

/// Which contact an invitation names.
///
/// A client-borne document fills `client_contact_id`, a vendor-borne one fills
/// `vendor_contact_id`, and exactly one is ever set — so the picker is not a
/// caller's judgement call and should not be re-written per surface.
String invitationContactId(Invitation invitation) =>
    invitation.clientContactId.isNotEmpty
    ? invitation.clientContactId
    : invitation.vendorContactId;

/// How a contact is named on screen: their name, else the address we would mail,
/// else [fallback] (callers pass `tr('contact')`).
///
/// The middle step earns its place and also often cannot help: the server seeds
/// one all-blank contact per client and per vendor, and it mints its own
/// `…@example.com` addresses which `Contact.email` already blanks — so a seeded
/// contact legitimately renders as the fallback. See
/// `docs/contacts-and-invitations.md`.
String partyContactLabel(
  PartyContacts contacts,
  String contactId, {
  required String fallback,
}) => contactLabelOf(contacts[contactId], fallback: fallback);

/// The same cascade for a contact already in hand.
String contactLabelOf(
  ({String name, String email})? contact, {
  required String fallback,
}) {
  if (contact == null) return fallback;
  if (contact.name.isNotEmpty) return contact.name;
  if (contact.email.isNotEmpty) return contact.email;
  return fallback;
}

PartyContacts contactsOfClient(Client? client) => client == null
    ? const {}
    : {
        for (final c in client.contacts)
          c.id: (name: '${c.firstName} ${c.lastName}'.trim(), email: c.email),
      };

PartyContacts contactsOfVendor(Vendor? vendor) => vendor == null
    ? const {}
    : {
        for (final c in vendor.contacts)
          c.id: (name: '${c.firstName} ${c.lastName}'.trim(), email: c.email),
      };

/// Watches a billing document's party (client *or* vendor) and rebuilds
/// [builder] with its contacts as a `contactId → (name, email)` map — empty
/// until the party resolves, and empty when neither id is set.
///
/// The single home for a lookup two surfaces need: the Email History tab, which
/// names the recipient of every send, and the `Viewed` status pill's tooltip
/// (invoiceninja/flutter#154), which names who looked. Before this they were
/// the same three helpers written twice.
///
/// **No `ensureLoaded` here, deliberately.** Both mount points sit under a
/// header that already renders `ClientNameLabel` / `VendorNameLabel`, and those
/// hydrate the party themselves; Drift keys active query streams by
/// SQL + variables, so watching the same row again costs one subscription and
/// no extra query. A third fetch would be pure duplication.
///
/// Built on [WatchBuilder] rather than a hand-hoisted `StreamBuilder` (the
/// shape `PartyCurrencyBuilder` uses): every repo `watch*` returns a fresh
/// stream per call, so an inline one is torn down and re-subscribed on every
/// parent rebuild. `WatchBuilder`'s doc excludes *per-cell id→name resolvers*
/// from this rule — a hundred rows of one column share a query — but this is
/// one subscription per screen carrying a whole contact list, which is exactly
/// what it is for.
class PartyContactsBuilder extends StatelessWidget {
  const PartyContactsBuilder({
    super.key,
    required this.companyId,
    required this.clients,
    required this.vendors,
    this.clientId = '',
    this.vendorId = '',
    required this.builder,
  });

  final String companyId;
  final ClientRepository clients;
  final VendorRepository vendors;

  /// Exactly one of these is non-empty on a real document.
  final String clientId;
  final String vendorId;

  final Widget Function(BuildContext context, PartyContacts contacts) builder;

  @override
  Widget build(BuildContext context) {
    if (clientId.isEmpty && vendorId.isEmpty) {
      return builder(context, const {});
    }
    return WatchBuilder<PartyContacts>(
      cacheKey: (companyId, clientId, vendorId),
      initialData: const {},
      create: () => clientId.isNotEmpty
          ? clients
                .watch(companyId: companyId, id: clientId)
                .map(contactsOfClient)
          : vendors
                .watch(companyId: companyId, id: vendorId)
                .map(contactsOfVendor),
      builder: (context, snap) => builder(
        context,
        snap.data ?? const <String, ({String name, String email})>{},
      ),
    );
  }
}
