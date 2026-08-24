import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/contact.dart';
import 'package:admin/data/models/value/country.dart';
import 'package:admin/data/services/device_contacts_service.dart';

/// The client contact the rest of the app treats as "the" one: the flagged
/// primary, else the first listed.
///
/// Shared so the several places that need it can't disagree — the contacts-sync
/// mapper below decides which card carries the client-level phone on this.
Contact? primaryContact(List<Contact> contacts) {
  if (contacts.isEmpty) return null;
  for (final contact in contacts) {
    if (contact.isPrimary) return contact;
  }
  return contacts.first;
}

/// Maps one client onto the address-book cards it should produce.
///
/// Pure — no I/O, no plugin types, no `BuildContext` — so the mapping rules are
/// unit-testable without a device. [countries] is the statics map
/// (`services.statics.countries`), used to turn the client's numeric
/// `country_id` into a name the OS can show.
///
/// The shape is one card per **contact**, not per client, because caller ID
/// resolves a number to a person: "Jane Smith / Acme Corp" is the useful
/// answer, "Acme Corp" alone is not. Three rules follow from that:
///
/// * the client's own name becomes each card's **organization**, so the company
///   line is filled in without inventing a second contact;
/// * the client-level phone rides along on the **primary** contact's card as a
///   `work` number, so a call from the company's main line still resolves —
///   only the primary's, or a client with five contacts would plant the same
///   number five times;
/// * a client whose contacts are all unusable still yields **one** card built
///   from its own record, so a company that never named a person isn't
///   invisible.
///
/// Cards with neither a phone nor an email are dropped: they can't do the job
/// this feature exists for and are pure noise in the user's address book.
List<DeviceContactCard> buildCards(
  Client client, {
  required Map<String, Country> countries,
}) {
  final organization = client.displayName.trim().isNotEmpty
      ? client.displayName.trim()
      : client.name.trim();
  final countryName = countries[client.countryId]?.name ?? '';
  final clientPhone = client.phone.trim();
  final primary = primaryContact(
    client.contacts.where((c) => !c.isDeleted).toList(),
  );

  final cards = <DeviceContactCard>[];
  for (final contact in client.contacts) {
    if (contact.isDeleted) continue;
    // No stable id means no stable link-table key, so the card would be
    // re-created (and duplicated) on every single run.
    if (contact.id.trim().isEmpty) continue;

    final contactPhone = contact.phone.trim();
    final isPrimary = primary != null && primary.id == contact.id;
    final phones = <DeviceContactPhone>[
      if (contactPhone.isNotEmpty) DeviceContactPhone(contactPhone),
      if (isPrimary &&
          clientPhone.isNotEmpty &&
          !_sameNumber(clientPhone, contactPhone))
        DeviceContactPhone(clientPhone, isWork: true),
    ];

    final first = contact.firstName.trim();
    final last = contact.lastName.trim();
    final unnamed = first.isEmpty && last.isEmpty;
    final card = DeviceContactCard(
      sourceId: contact.id,
      // An unnamed contact would otherwise show as a bare phone number on the
      // call screen; the company name is a far better answer than nothing.
      firstName: unnamed ? organization : first,
      lastName: unnamed ? '' : last,
      organization: organization,
      email: contact.email.trim(),
      website: client.website.trim(),
      phones: phones,
      address1: client.address1.trim(),
      city: client.city.trim(),
      state: client.state.trim(),
      postalCode: client.postalCode.trim(),
      countryName: countryName,
    );
    if (card.isUseful) cards.add(card);
  }

  if (cards.isNotEmpty) return cards;

  // Fallback: the client itself.
  //
  // The email is the primary contact's, mirroring the `clients.email`
  // denormalization the repository does (`_primaryEmailOf`) — the domain
  // `Client` carries no address of its own. In practice it is almost always
  // blank here, because a contact holding an email would have produced a
  // useful card above and we'd never have reached this branch; it is read
  // anyway so the fallback stays correct if `isUseful` is ever tightened.
  final fallback = DeviceContactCard(
    sourceId: clientFallbackSourceId(client.id),
    firstName: organization,
    organization: organization,
    email: primary?.email.trim() ?? '',
    website: client.website.trim(),
    phones: [
      if (clientPhone.isNotEmpty) DeviceContactPhone(clientPhone, isWork: true),
    ],
    address1: client.address1.trim(),
    city: client.city.trim(),
    state: client.state.trim(),
    postalCode: client.postalCode.trim(),
    countryName: countryName,
  );
  return fallback.isUseful ? [fallback] : const <DeviceContactCard>[];
}

/// Link-table key for the single card a client with no usable contact emits.
/// Namespaced so it can never collide with a real contact id.
String clientFallbackSourceId(String clientId) => 'client:$clientId';

/// Content fingerprint of everything [DeviceContactCard] writes to the device.
///
/// The reconcile compares this against the stored hash and skips the OS write
/// entirely when it matches — which is what makes a repeat sync cost one Drift
/// read instead of thousands of address-book updates. Any field added to the
/// card must be added here too, or edits to it will never propagate.
///
/// Hashed over a JSON encoding rather than a joined string so field boundaries
/// are unambiguous: `["Jane Smith", ""]` and `["Jane", "Smith"]` must not
/// collide, and both would if the parts were simply joined on a space.
String cardHash(DeviceContactCard card) {
  final parts = <String>[
    card.firstName,
    card.lastName,
    card.organization,
    card.email,
    card.website,
    for (final phone in card.phones) '${phone.number}|${phone.isWork}',
    card.address1,
    card.city,
    card.state,
    card.postalCode,
    card.countryName,
  ];
  return sha256.convert(utf8.encode(jsonEncode(parts))).toString();
}

/// Compare two phone numbers the way a human would — formatting, spaces and
/// punctuation differ constantly between a client record and a contact record,
/// and duplicating the same line under two labels looks like a bug.
bool _sameNumber(String a, String b) {
  String digits(String v) => v.replaceAll(RegExp('[^0-9]'), '');
  final da = digits(a);
  final db = digits(b);
  if (da.isEmpty || db.isEmpty) return a.trim() == b.trim();
  return da == db;
}
