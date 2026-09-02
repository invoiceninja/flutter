import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/contact_api_model.dart';
import 'package:admin/data/models/value/parsing.dart';

part 'contact.freezed.dart';

/// Clean domain shape for a Client contact. Lives embedded inside [Client]
/// because contacts are never browsed independently.
@freezed
abstract class Contact with _$Contact {
  const factory Contact({
    required String id,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required bool isPrimary,
    required bool sendEmail,
    @Default(false) bool ccOnly,
    @Default(false) bool isLocked,
    // "Authorized to sign" — portal e-signature permission. Editable when the
    // company has the relevant module enabled (React parity).
    @Default(false) bool canSign,
    @Default('') String password,
    required DateTime updatedAt,
    required bool isDeleted,
    @Default('') String link,
    // Server-assigned stable identifier for the contact. Read-only; echoed
    // back on save so the server can match existing portal credentials.
    @Default('') String contactKey,
    // Last portal login (read-only); null when the contact has never signed
    // in. Display-only — not written back.
    DateTime? lastLogin,
    @Default('') String customValue1,
    @Default('') String customValue2,
    @Default('') String customValue3,
    @Default('') String customValue4,
  }) = _Contact;

  factory Contact.fromApi(ContactApi a) => Contact(
    id: a.id,
    firstName: a.firstName,
    lastName: a.lastName,
    email: a.email,
    phone: a.phone,
    isPrimary: a.isPrimary,
    sendEmail: a.sendEmail,
    ccOnly: a.ccOnly,
    isLocked: a.isLocked,
    canSign: a.canSign,
    // Server sends `**********` when a password is set; treat it as "no
    // password entered" so it's never echoed back (see [kMaskedPassword]).
    password: a.password == kMaskedPassword ? '' : a.password,
    updatedAt: epochSecondsToUtc(a.updatedAt),
    isDeleted: a.isDeleted,
    link: a.link,
    contactKey: a.contactKey,
    lastLogin: epochSecondsToUtcOrNull(a.lastLogin),
    customValue1: a.customValue1,
    customValue2: a.customValue2,
    customValue3: a.customValue3,
    customValue4: a.customValue4,
  );
}

extension ContactCopy on Contact {
  Map<String, dynamic> toApiJson() => {
    if (id.isNotEmpty) 'id': id,
    'first_name': firstName,
    'last_name': lastName,
    'email': email,
    'phone': phone,
    'is_primary': isPrimary,
    'send_email': sendEmail,
    'cc_only': ccOnly,
    'can_sign': canSign,
    if (password.isNotEmpty && password != kMaskedPassword)
      'password': password,
    if (contactKey.isNotEmpty) 'contact_key': contactKey,
    'link': link,
    'custom_value1': customValue1,
    'custom_value2': customValue2,
    'custom_value3': customValue3,
    'custom_value4': customValue4,
  };
}

/// Whether the user has given this contact any identity at all.
///
/// The server creates one all-blank contact for every client — literally
/// `//always made sure we have one blank contact to maintain state` in
/// `ClientContactRepository::save` — so a client the user never gave contact
/// details to still carries a row the detail card used to render
/// (invoiceninja/flutter#115). Read as "nothing was typed here" by both that
/// card (which filters these out) and `ClientEditViewModel`'s discard prompt.
///
/// **The `trim()` is load-bearing, not defensive.** That server-side factory
/// sets `email = ' '` — a literal single space — and nothing between the wire
/// and here trims it, so without the trim every seeded client contact reads as
/// non-blank. (The vendor twin gets `''`, which is why the same row showed
/// `(no name)` on a vendor but a blank title on a client.)
///
/// Otherwise deliberately narrow. [link] stays out even though the detail row
/// builds portal buttons from it: the server mints a portal link for the blank
/// contact too, so counting it would filter nothing at all (React's
/// `clients/show/components/Contacts.tsx` omits it from the same test, and the
/// portal is still reachable from `ClientAction.clientPortal`). [isPrimary] is
/// the flag that same factory sets on the row it created. `customValue1..4`
/// are out because the **detail cards** don't render them; the contact
/// *editors* do (`client_edit_contacts_section.dart`), so the edit VMs' discard
/// prompt misses a custom-value-only edit — a pre-existing gap this predicate
/// inherited unchanged from the two `_isBlankContact` twins it replaced. A card
/// that starts rendering them must widen its own `hasContent`, never this.
extension ContactIdentity on Contact {
  bool get isBlank =>
      firstName.trim().isEmpty &&
      lastName.trim().isEmpty &&
      email.trim().isEmpty &&
      phone.trim().isEmpty;
}
