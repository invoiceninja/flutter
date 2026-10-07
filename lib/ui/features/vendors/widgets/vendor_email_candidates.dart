import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/data/models/domain/vendor_contact.dart';
import 'package:admin/domain/email_candidates.dart';
import 'package:admin/utils/email_address.dart';

/// Every address worth **writing to** for [vendor], most-likely first: the
/// primary contact, then the rest in declaration order.
///
/// The vendor twin of `clientEmailCandidates`, with the same contract —
/// deleted and blank contacts are dropped, and so is any address
/// [cleanEmailAddress] refuses, so an empty result means "there is nobody here
/// to write to" and the caller draws no affordance at all. Two contacts
/// sharing one address are one entry: the first, which is the primary when
/// either is.
///
/// A contact's server-minted portal placeholder is never offered: it is
/// stripped out of `VendorContact.email` on the way in.
List<EmailCandidate> vendorEmailCandidates(Vendor vendor) {
  final contacts = [
    for (final c in vendor.contacts)
      if (!c.isDeleted && !c.isBlank) c,
  ];
  final ordered = [
    ...contacts.where((c) => c.isPrimary),
    ...contacts.where((c) => !c.isPrimary),
  ];
  final seen = <String>{};
  return [
    for (final c in ordered)
      if (cleanEmailAddress(c.email) case final email
          when email.isNotEmpty && seen.add(email.toLowerCase()))
        (
          label: '${c.firstName} ${c.lastName}'.trim(),
          email: email,
          isPrimary: c.isPrimary,
        ),
  ];
}
