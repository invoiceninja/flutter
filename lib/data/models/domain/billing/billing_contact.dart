import 'package:admin/data/models/domain/contact.dart';
import 'package:admin/data/models/domain/vendor_contact.dart';

/// Minimal surface every "contact attached to a billing doc" exposes —
/// just enough for the shared [`BillingDocContactsSection`] widget to
/// render a row (identity / email / primary badge).
///
/// Callers map their concrete contact type into this via the
/// `.toBilling()` extension defined below. Examples:
///
/// ```dart
/// // Client contacts (invoice / quote / credit / recurring_invoice):
/// final billingContacts =
///     client.contacts.map((c) => c.toBilling()).toList();
///
/// // Vendor contacts (purchase_order):
/// final billingContacts =
///     vendor.contacts.map((c) => c.toBilling()).toList();
/// ```
///
/// The widget then takes `List<BillingContact>` and the entity-specific
/// host wires the invitation-toggle callback to whichever invitation
/// slot it owns (`clientContactId` or `vendorContactId`).
class BillingContact {
  const BillingContact({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.isPrimary,
    this.isLocked = false,
    this.canSign = false,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final bool isPrimary;

  /// Email destination suppressed by a bounce / unsubscribe. Client
  /// contacts only — vendor contacts don't carry this flag.
  final bool isLocked;

  /// The contact's own "Authorized to sign" (`can_sign`): the value a new
  /// invitation for this contact starts with, as React seeds it.
  final bool canSign;
}

extension ContactToBillingContact on Contact {
  BillingContact toBilling() => BillingContact(
    id: id,
    firstName: firstName,
    lastName: lastName,
    email: email,
    isPrimary: isPrimary,
    isLocked: isLocked,
    canSign: canSign,
  );
}

extension VendorContactToBillingContact on VendorContact {
  BillingContact toBilling() => BillingContact(
    id: id,
    firstName: firstName,
    lastName: lastName,
    email: email,
    isPrimary: isPrimary,
    canSign: canSign,
  );
}
