import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/contact.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/data/models/domain/vendor_contact.dart';
import 'package:admin/utils/formatting.dart';

/// One dialable number offered by a billing document's party, with enough
/// context for the picker to say whose it is.
///
/// [phone] is the **stored** string, not the normalised one: it is what the
/// user typed, what the picker renders, and what `callPhoneNumber` /
/// `copyToClipboard` are handed. Normalisation happens inside `telUri`, and
/// here only to compare two spellings of the same number.
typedef PhoneCandidate = ({
  String label,
  String phone,
  bool isPrimary,
  bool isPartyOwnLine,
});

/// Every number worth offering for [client], most-likely first.
///
/// Order: the primary contact, then the remaining contacts in declaration
/// order, then the client's own top-level line. Deliberately **not** ordered by
/// the document's `invitations` — an invitation is an email-delivery fact, and
/// "whom do I ring about this invoice" is answered more predictably by the
/// primary contact, which also doesn't change from one document to the next.
///
/// Deleted contacts, blank numbers and anything `cleanPhoneNumber` rejects
/// (`1-800-FLOWERS`, `Reception, dial 9 first`, a bare extension) are dropped,
/// so an empty result means "there is nothing here to dial" and the caller can
/// render no affordance at all.
List<PhoneCandidate> clientPhoneCandidates(Client client) =>
    _partyPhoneCandidates<Contact>(
      contacts: client.contacts,
      isPrimary: (c) => c.isPrimary,
      isDeleted: (c) => c.isDeleted,
      phoneOf: (c) => c.phone,
      labelOf: (c) => '${c.firstName} ${c.lastName}',
      partyName: client.displayName,
      partyPhone: client.phone,
    );

/// The [Vendor] twin of [clientPhoneCandidates]. `Contact` and `VendorContact`
/// share no supertype, so the walk itself is generic rather than written twice.
List<PhoneCandidate> vendorPhoneCandidates(Vendor vendor) =>
    _partyPhoneCandidates<VendorContact>(
      contacts: vendor.contacts,
      isPrimary: (c) => c.isPrimary,
      isDeleted: (c) => c.isDeleted,
      phoneOf: (c) => c.phone,
      labelOf: (c) => '${c.firstName} ${c.lastName}',
      partyName: vendor.name,
      partyPhone: vendor.phone,
    );

List<PhoneCandidate> _partyPhoneCandidates<T>({
  required List<T> contacts,
  required bool Function(T) isPrimary,
  required bool Function(T) isDeleted,
  required String Function(T) phoneOf,
  required String Function(T) labelOf,
  required String partyName,
  required String partyPhone,
}) {
  final out = <PhoneCandidate>[];
  // Keyed on the normalised form so `+1 (415) 555-2671` and `+14155552671`
  // collapse — a client whose own line is also its primary contact's number is
  // the common case, not an edge one.
  final seen = <String>{};

  void add(
    String phone,
    String label, {
    required bool primary,
    required bool ownLine,
  }) {
    if (cleanPhoneNumber(phone).isEmpty) return;
    if (!seen.add(cleanPhoneNumber(phone))) return;
    out.add((
      label: label.trim(),
      phone: phone.trim(),
      isPrimary: primary,
      isPartyOwnLine: ownLine,
    ));
  }

  // Filtered before the primary split, so a mixed list can't promote a deleted
  // contact (mirrors `_autoInvitations` in the billing-doc edit VM).
  final live = contacts.where((c) => !isDeleted(c)).toList(growable: false);
  for (final c in live.where(isPrimary)) {
    add(phoneOf(c), labelOf(c), primary: true, ownLine: false);
  }
  for (final c in live.where((c) => !isPrimary(c))) {
    add(phoneOf(c), labelOf(c), primary: false, ownLine: false);
  }
  add(partyPhone, partyName, primary: false, ownLine: true);
  return List<PhoneCandidate>.unmodifiable(out);
}
