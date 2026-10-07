/// One plain email address, or `''` when [raw] is anything else.
///
/// This is the gate in front of every `mailto:` the app builds, and it is
/// strict on purpose. A contact's email is free text typed by a user or
/// imported from a spreadsheet, and a `mailto:` URI is not just an address:
/// `a@b.com?bcc=x@evil.example&body=…` is a valid one, and a mail client will
/// honour every header in it. `tel:` gets away with a looser check because
/// `cleanPhoneNumber` reduces its payload to digits; there is no equivalent
/// reduction for an address, so the only safe move is to accept exactly one
/// address and nothing that could carry a second one or a header:
///
///  * no `?` (where headers start), no `,` or `;` (a recipient list), no `%`
///    (pre-encoded anything), no whitespace, double quotes or angle brackets;
///  * exactly one `@`, a non-empty local part, and a dotted domain.
///
/// What it does **not** refuse, because real addresses use them: `+`, an
/// apostrophe, and `&` in the local part (`r&d@acme.com`). `&` separates
/// headers only after a `?`, which cannot get in — and `mailtoUri` encodes it
/// regardless.
///
/// Letters and digits may be Unicode, combining marks included, so an
/// internationalised address works in any script.
/// A string that fails is not "repaired" — the caller offers no mail
/// affordance and the address stays what it always was, text to copy.
String cleanEmailAddress(String raw) {
  final address = raw.trim();
  return _address.hasMatch(address) ? address : '';
}

/// Local part: RFC 5322 `atext` minus `%` and `?`. Domain: dot-separated
/// labels that neither start nor end with a hyphen.
///
/// `&` is allowed in the local part (`r&d@acme.com` is a real address, and
/// the server's own email rule accepts it): in a `mailto:` it only means
/// anything *after* a `?`, and `?` can never get in. `\p{M}` is there beside
/// letters and digits because many scripts write a letter as a base plus
/// combining marks — Devanagari, Thai, pointed Hebrew and Arabic, or any
/// Latin text in decomposed form — and without it "an internationalised
/// address works" was only true of the precomposed ones.
final RegExp _address = RegExp(
  r"^[\p{L}\p{M}\p{N}.!#$&'*+/=^_`{|}~-]+"
  r'@[\p{L}\p{M}\p{N}](?:[\p{L}\p{M}\p{N}-]*[\p{L}\p{M}\p{N}])?'
  r'(?:\.[\p{L}\p{M}\p{N}](?:[\p{L}\p{M}\p{N}-]*[\p{L}\p{M}\p{N}])?)+$',
  unicode: true,
);
