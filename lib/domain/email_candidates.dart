import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/contact.dart';
import 'package:admin/utils/email_address.dart';

/// One address a party can be written to, with enough context for a picker to
/// say whose it is.
typedef EmailCandidate = ({String label, String email, bool isPrimary});

/// Every address worth **writing to** for [client], most-likely first: the
/// primary contact, then the rest in declaration order.
///
/// The email twin of `clientPhoneCandidates`, with the same contract: deleted
/// and blank contacts are dropped, and so is any address
/// [cleanEmailAddress] refuses, so an empty result means "there is nobody here
/// to write to" and the caller can draw no affordance at all. Two contacts
/// sharing one address are one entry — the first, which is the primary when
/// either is.
List<EmailCandidate> clientEmailCandidates(Client client) {
  final contacts = [
    for (final c in client.contacts)
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
