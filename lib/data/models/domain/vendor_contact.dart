import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/vendor_api_model.dart';
import 'package:admin/data/models/value/parsing.dart';

part 'vendor_contact.freezed.dart';

/// Clean domain shape for a Vendor contact. Lives embedded inside [Vendor]
/// because vendor contacts are never browsed independently.
///
/// Parallel to `Contact` in `lib/data/models/domain/contact.dart` — Vendor
/// contacts carry the same identity/email/phone fields, plus the password
/// + send_email flag the server stores for portal access. Vendor contacts
/// also carry their own `custom_value1..4` slots.
@freezed
abstract class VendorContact with _$VendorContact {
  const factory VendorContact({
    required String id,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    // Twin of `Contact.portalPlaceholderEmail` — the address the server minted
    // for a vendor contact that had none, stripped out of [email] on the way in
    // and re-emitted by [toApiJson] rather than cleared. Full rationale (and
    // why omitting the key instead is wrong) lives on the client-side field in
    // `contact.dart`; the vendor portal mints these from
    // `VendorPortal/InvitationController.php:58` and
    // `Middleware/VendorContactKeyLogin.php`.
    @Default('') String portalPlaceholderEmail,
    required bool sendEmail,
    // Server-managed / optional flags default so call sites that don't care
    // can omit them; mirror the optional fields on `Contact`.
    @Default(false) bool ccOnly,
    required bool isPrimary,
    // "Authorized to sign" — portal e-signature permission (React parity).
    @Default(false) bool canSign,
    // Server-generated portal auto-login URL. Read-only; echoed back on save.
    @Default('') String link,
    required String customValue1,
    required String customValue2,
    required String customValue3,
    required String customValue4,
    required DateTime updatedAt,
    required bool isDeleted,
    // Last portal login (read-only, display-only); null when never signed in.
    DateTime? lastLogin,
  }) = _VendorContact;

  factory VendorContact.fromApi(VendorContactApi a) => VendorContact(
    id: a.id,
    firstName: a.firstName,
    lastName: a.lastName,
    // Server-minted junk for an email-less contact: blank it and carry the raw
    // value, the same shape as the `**********` password sentinel below.
    email: isPortalPlaceholderEmail(a.email) ? '' : a.email,
    portalPlaceholderEmail: isPortalPlaceholderEmail(a.email) ? a.email : '',
    phone: a.phone,
    // Server sends `**********` when a password is set; treat it as "no
    // password entered" so it's never echoed back (see [kMaskedPassword]).
    password: a.password == kMaskedPassword ? '' : a.password,
    sendEmail: a.sendEmail,
    ccOnly: a.ccOnly,
    isPrimary: a.isPrimary,
    canSign: a.canSign,
    link: a.link,
    customValue1: a.customValue1,
    customValue2: a.customValue2,
    customValue3: a.customValue3,
    customValue4: a.customValue4,
    updatedAt: epochSecondsToUtc(a.updatedAt),
    isDeleted: a.isDeleted,
    lastLogin: epochSecondsToUtcOrNull(a.lastLogin),
  );
}

extension VendorContactPayload on VendorContact {
  /// Serialize back to the JSON shape the server expects on vendor
  /// create/update. The `id` slot is omitted when it's a `tmp_<uuid>`
  /// (added offline) so the server allocates a real id — unless
  /// [preserveTempId] is `true` for local-only Drift persistence, which
  /// has to keep the temp id so the detail screen can keep watching it.
  /// Mirrors `Contact.toApiJson`.
  Map<String, dynamic> toApiJson({bool preserveTempId = false}) => {
    if (preserveTempId || (!id.startsWith('tmp_') && id.isNotEmpty)) 'id': id,
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
    if (password.isNotEmpty && password != kMaskedPassword)
      'password': password,
    'send_email': sendEmail,
    'cc_only': ccOnly,
    'is_primary': isPrimary,
    'can_sign': canSign,
    'link': link,
    'custom_value1': customValue1,
    'custom_value2': customValue2,
    'custom_value3': customValue3,
    'custom_value4': customValue4,
  };
}

/// Twin of `ContactIdentity.isBlank` on `Contact` — see that doc comment for
/// why `link`, `isPrimary` and `customValue1..4` stay out of the predicate.
///
/// The blank row is the **server's**, not the edit screen's — `_emptyVendor`
/// seeds `contacts: const []`, and `VendorContactRepository::save` then creates
/// one (`//always made sure we have one blank contact to maintain state`) for
/// any vendor that has none. The detail card rendered it as `(no name)` beside
/// a primary star (invoiceninja/flutter#115). Unlike the client factory this
/// one leaves `email` at `''` rather than `' '`, but keep the `trim()` in step
/// with the twin regardless.
extension VendorContactIdentity on VendorContact {
  bool get isBlank =>
      firstName.trim().isEmpty &&
      lastName.trim().isEmpty &&
      email.trim().isEmpty &&
      phone.trim().isEmpty;
}
