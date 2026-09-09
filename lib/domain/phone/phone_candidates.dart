import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/contact.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/data/models/domain/vendor_contact.dart';
import 'package:admin/utils/formatting.dart';

/// One number offered by a party, with enough context for a picker to say
/// whose it is.
///
/// [phone] is the **stored** string, not the normalised one: it is what the
/// user typed, what the picker renders, and what `callPhoneNumber` /
/// `copyToClipboard` are handed. Normalisation happens inside `telUri`, and
/// here only to compare two spellings of the same number.
///
/// On a list built by [clientPhoneCandidates] / [vendorPhoneCandidates] — the
/// dialer's — [phone] is always dialable. On the log-call list
/// ([clientCallLogCandidates] / [vendorCallLogCandidates]) it may be empty, or
/// a string `cleanPhoneNumber` refuses; see there.
typedef PhoneCandidate = ({
  String label,
  String phone,
  bool isPrimary,
  bool isPartyOwnLine,
});

/// Every number worth **dialling** for [client], most-likely first.
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
    _clientCandidates(client, includeNumberless: false);

/// The [Vendor] twin of [clientPhoneCandidates]. `Contact` and `VendorContact`
/// share no supertype, so the walk itself is generic rather than written twice.
List<PhoneCandidate> vendorPhoneCandidates(Vendor vendor) =>
    _vendorCandidates(vendor, includeNumberless: false);

/// Every contact worth **naming** in a logged call for [client]
/// (invoiceninja/flutter#129) — the same walk and the same order as
/// [clientPhoneCandidates], widened because the log-call form's Contact field
/// answers *"who did you speak to"*, not *"which number do I dial"*.
///
/// Three differences from the dialer's list, each deliberate:
///
///  * **A contact with no stored number is kept**, contributing its name alone.
///    Email-only contacts are ordinary, and dropping them is what left the
///    field blank. A contact with neither a name nor a dialable number is still
///    dropped — that is the all-blank row the server seeds for every client,
///    and it would render as `(no name)` beside nothing. Note the test is the
///    *name*, not `Contact.isBlank`, which also counts `email` and so would
///    admit a nameless contact carrying only a server-minted portal address.
///  * **Contacts are not deduped against each other.** Two colleagues who share
///    one switchboard number are two different answers here, where they are one
///    entry in the dialer. The party's own line is still deduped, so a client
///    whose office number is repeated on its primary contact doesn't show it
///    twice.
///  * **A named contact's un-dialable number is kept verbatim.**
///    `1-800-FLOWERS` can't be dialled but is a true record of who was called,
///    and the note is permanent — better the string the user stored than
///    nothing. A *nameless* contact storing one is still dropped, by the same
///    name test as above: the row would carry neither a usable name nor a
///    usable number.
///
/// The party's own top-level line still requires a real number, so this never
/// invents a numberless row labelled with the party's own name.
///
/// **Never hand one of these to the dialer.** `PhoneCallButton` asserts against
/// it and `test/lint/call_note_wiring_test.dart` pins which files may *call*
/// these two functions (any file may name them — the scan strips comments
/// first), because a numberless candidate reaching `callPhoneNumber` is a dead
/// tap with no toast, a tooltip ending in a bare `·`, and a long-press that
/// copies the empty string.
List<PhoneCandidate> clientCallLogCandidates(Client client) =>
    _clientCandidates(client, includeNumberless: true);

/// The [Vendor] twin of [clientCallLogCandidates].
List<PhoneCandidate> vendorCallLogCandidates(Vendor vendor) =>
    _vendorCandidates(vendor, includeNumberless: true);

List<PhoneCandidate> _clientCandidates(
  Client client, {
  required bool includeNumberless,
}) => _partyPhoneCandidates<Contact>(
  contacts: client.contacts,
  isPrimary: (c) => c.isPrimary,
  isDeleted: (c) => c.isDeleted,
  phoneOf: (c) => c.phone,
  labelOf: (c) => '${c.firstName} ${c.lastName}',
  partyName: client.displayName,
  partyPhone: client.phone,
  includeNumberless: includeNumberless,
);

List<PhoneCandidate> _vendorCandidates(
  Vendor vendor, {
  required bool includeNumberless,
}) => _partyPhoneCandidates<VendorContact>(
  contacts: vendor.contacts,
  isPrimary: (c) => c.isPrimary,
  isDeleted: (c) => c.isDeleted,
  phoneOf: (c) => c.phone,
  labelOf: (c) => '${c.firstName} ${c.lastName}',
  partyName: vendor.name,
  partyPhone: vendor.phone,
  includeNumberless: includeNumberless,
);

List<PhoneCandidate> _partyPhoneCandidates<T>({
  required List<T> contacts,
  required bool Function(T) isPrimary,
  required bool Function(T) isDeleted,
  required String Function(T) phoneOf,
  required String Function(T) labelOf,
  required String partyName,
  required String partyPhone,
  required bool includeNumberless,
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
    final key = cleanPhoneNumber(phone);
    final name = label.trim();

    if (ownLine) {
      // The party's own line IS a number — a numberless row labelled with the
      // party's own name says nothing and duplicates a picker's heading — and
      // it is the one entry still deduped when [includeNumberless] is set.
      if (key.isEmpty || !seen.add(key)) return;
    } else if (key.isEmpty) {
      if (!includeNumberless || name.isEmpty) return;
    } else {
      final fresh = seen.add(key);
      // `seen.add` ran either way, so the party's own line still collapses
      // against a contact's identical number. What changes is only whether a
      // *contact* is dropped for sharing one with another contact: right for
      // the dialer, wrong for "who did you speak to".
      if (!fresh && !includeNumberless) return;
    }

    out.add((
      label: name,
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
