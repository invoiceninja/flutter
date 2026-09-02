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
    // The address the **server** minted for a contact that had none (see
    // [isPortalPlaceholderEmail]) — stripped out of [email] on the way in so
    // nothing renders it, kept here so [ContactCopy.toApiJson] can put it back.
    // Clearing it instead would be a write the user never asked for, on an
    // unrelated save, to the field the portal guard authenticates this contact
    // by — and it would never settle, since the next portal visit mints a
    // different address. Empty for every contact whose address is real, which
    // is what keeps a genuine "user cleared their email" edit going out as ''.
    //
    // Deliberately not a Drift column: it is re-derived by [Contact.fromApi] on
    // every read, because a local save's stored payload *is* `toApiJson`'s
    // output and that re-emits the raw value. Omitting the key there instead
    // would look equivalent on the wire but round-trip to '' through
    // `_domainToCompanion` → `_fromRow`, so the second offline save would clear
    // the server's value after all.
    @Default('') String portalPlaceholderEmail,
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
    // Server-minted junk for an email-less contact: blank it and carry the raw
    // value, the same shape as the `**********` password sentinel below.
    email: isPortalPlaceholderEmail(a.email) ? '' : a.email,
    portalPlaceholderEmail: isPortalPlaceholderEmail(a.email) ? a.email : '',
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
    // Re-emit the placeholder the user was never shown rather than clearing the
    // server's value on an unrelated save. A real address the user cleared
    // carries no placeholder, so that edit still goes out as ''.
    //
    // `id.isNotEmpty` is the clone guard, not a formality: `ClientAction.clone`
    // / `VendorAction.clone` copy each contact with `id: ''` and keep every
    // other field, so without it a clone would POST a **new** contact carrying
    // the *source* contact's minted address — invisible, since the form shows
    // the email field blank. There is nothing to preserve for a contact the
    // server has never seen; it mints a fresh one if that contact ever reaches
    // the portal.
    'email':
        id.isNotEmpty &&
            email.trim().isEmpty &&
            portalPlaceholderEmail.isNotEmpty
        ? portalPlaceholderEmail
        : email,
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
///
/// invoiceninja/flutter#116 widened what this hides: [Contact.email] is blanked
/// when the server minted it (see `isPortalPlaceholderEmail`), so a contact
/// whose *only* content was such an address now reads as blank and its card row
/// — including its own "View portal" button — is filtered out. Deliberate. For
/// a **non-primary** contact that link becomes unreachable from the app, since
/// `ClientAction.clientPortal` resolves the primary contact only; the record it
/// costs is one with no name, no phone and no real email, and the alternative —
/// counting [Contact.link] — is exactly what the paragraph above rules out.
extension ContactIdentity on Contact {
  bool get isBlank =>
      firstName.trim().isEmpty &&
      lastName.trim().isEmpty &&
      email.trim().isEmpty &&
      phone.trim().isEmpty;
}
