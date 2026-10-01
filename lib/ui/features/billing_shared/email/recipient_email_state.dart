import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/vendor.dart';

/// One contact of the document's client / vendor, as the send-email surfaces
/// need it. Built from the domain contact, whose `email` already has the
/// server's portal placeholder (`…@example.com`) blanked.
typedef EmailContact = ({
  String id,
  String label,
  String email,
  bool ccOnly,
  bool isLocked,
  bool isPrimary,
});

/// Whether emailing a document would reach anyone (invoiceninja/ui#3400).
enum RecipientEmailState {
  /// At least one invited contact has an address.
  has,

  /// The recipient is known, and none of the contacts the document is
  /// addressed to has an email — the server would accept the request and
  /// send nothing.
  none,

  /// The client / vendor isn't in the local cache (offline, never browsed),
  /// so there is no way to tell. **Never blocks** — a guess here would stop a
  /// perfectly good send.
  unknown,
}

/// The document's client contacts, keyed by id. Null for a missing client —
/// see [RecipientEmailState.unknown].
Map<String, EmailContact>? emailContactsOfClient(Client? client) {
  if (client == null) return null;
  return {
    for (final c in client.contacts)
      c.id: (
        id: c.id,
        label: '${c.firstName} ${c.lastName}'.trim(),
        email: c.email.trim(),
        ccOnly: c.ccOnly,
        isLocked: c.isLocked,
        isPrimary: c.isPrimary,
      ),
  };
}

/// The purchase order's vendor contacts, keyed by id. Null for a missing
/// vendor.
Map<String, EmailContact>? emailContactsOfVendor(Vendor? vendor) {
  if (vendor == null) return null;
  return {
    for (final c in vendor.contacts)
      c.id: (
        id: c.id,
        label: '${c.firstName} ${c.lastName}'.trim(),
        email: c.email.trim(),
        ccOnly: c.ccOnly,
        isLocked: false,
        isPrimary: c.isPrimary,
      ),
  };
}

/// The contact id an invitation addresses — client or vendor side.
String invitedContactId(Invitation inv) =>
    inv.clientContactId.isNotEmpty ? inv.clientContactId : inv.vendorContactId;

/// The contacts a send is addressed to: the **invited** ones, because the
/// server mails a document's invitations (`EmailController::send`), not the
/// client's contacts. A client can have a contact with an email that isn't
/// invited to this document, and that contact receives nothing.
List<EmailContact> invitedContacts(
  Iterable<Invitation> invitations,
  Map<String, EmailContact> contacts,
) => [
  for (final inv in invitations)
    if (contacts[invitedContactId(inv)] case final c?) c,
];

/// See [RecipientEmailState]. [contacts] null = the party isn't loaded.
RecipientEmailState recipientEmailState({
  required Iterable<Invitation> invitations,
  required Map<String, EmailContact>? contacts,
}) {
  if (contacts == null) return RecipientEmailState.unknown;
  final invited = invitedContacts(invitations, contacts);
  return invited.any((c) => c.email.isNotEmpty)
      ? RecipientEmailState.has
      : RecipientEmailState.none;
}

/// The contacts the server CCs on every send to this client / vendor:
/// `cc_only`, with an address, not locked, at most four
/// (`Client::cc_contacts`). Shown on their own line (invoiceninja/ui#3280)
/// rather than mixed into "To".
List<EmailContact> ccOnlyContacts(Map<String, EmailContact> contacts) => [
  for (final c in contacts.values)
    if (c.ccOnly && c.email.isNotEmpty && !c.isLocked) c,
].take(4).toList(growable: false);

/// Which invited contact an "Add email" fix should write to: the primary one
/// when it is invited, else the first invited contact. Null when nothing is
/// invited — there is no invitation an address could make deliverable.
EmailContact? contactToAddEmailTo(
  Iterable<Invitation> invitations,
  Map<String, EmailContact> contacts,
) {
  final invited = invitedContacts(invitations, contacts);
  if (invited.isEmpty) return null;
  return invited.firstWhere((c) => c.isPrimary, orElse: () => invited.first);
}
