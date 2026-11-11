import 'package:flutter/material.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/billing_doc_fields.dart';
import 'package:admin/ui/core/detail/portal_link_action.dart';
import 'package:admin/ui/core/widgets/party_contacts_builder.dart';

/// Whether [doc] has a portal link to hand out: an invitation the server has
/// given a link. A document created offline has none until it syncs.
bool billingDocHasPortalLink(BillingDocFields doc) =>
    doc.invitations.any((i) => i.link.isNotEmpty);

/// The dispatch half of a billing document's `portalLink` action: share the
/// page its client (or, on a purchase order, its vendor) opens with no login.
///
/// The link is the invitation's own, never the sender's `silent=true` form —
/// the recipient opening it is exactly the view the document should record.
/// With several contacts the user picks whose link goes out; the names come
/// from the party's row, and a party not on the device yet lists its
/// invitations unnamed rather than offering nothing.
Future<void> shareBillingDocPortalLink(
  BuildContext context,
  Services services,
  String companyId,
  BillingDocFields doc, {
  required bool vendor,
}) async {
  final linked = [
    for (final i in doc.invitations)
      if (i.link.isNotEmpty) i,
  ];
  var contacts = const <String, ({String name, String email})>{};
  if (linked.length > 1) {
    final partyId = vendor ? doc.vendorId : doc.clientId;
    if (companyId.isNotEmpty && partyId.isNotEmpty) {
      // Names for the picker only: a party that does not answer at once
      // lists its invitations unnamed rather than holding the tap.
      try {
        contacts =
            await (vendor
                    ? services.vendors
                          .watch(companyId: companyId, id: partyId)
                          .map(contactsOfVendor)
                    : services.clients
                          .watch(companyId: companyId, id: partyId)
                          .map(contactsOfClient))
                .first
                .timeout(const Duration(seconds: 1));
      } catch (_) {
        contacts = const {};
      }
      if (!context.mounted) return;
    }
  }
  // The server seeds an all-blank contact and makes an invitation for it:
  // with named contacts to choose from, that one is noise, not a choice.
  bool named(String id) {
    final c = contacts[id];
    return c != null && (c.name.trim().isNotEmpty || c.email.trim().isNotEmpty);
  }

  final anyNamed = linked.any((i) => named(invitationContactId(i)));
  await sharePortalLink(
    context,
    vendor: vendor,
    targets: [
      for (final i in linked)
        if (!anyNamed || named(invitationContactId(i)))
          PortalLinkTarget(
            link: i.link,
            name: contacts[invitationContactId(i)]?.name.trim() ?? '',
            email: contacts[invitationContactId(i)]?.email.trim() ?? '',
          ),
    ],
  );
}
