/// The contact half of a party list row's subtitle, and the name-equality
/// predicate behind it — the single path shared by the narrow Clients and
/// Vendors rows. Never re-derive "does this contact repeat the row's title?"
/// inline.
///
/// ## Why the two strings collide
///
/// The server's `ClientPresenter::name()` returns the first contact's full name
/// — else their email — whenever `client.name` is blank **or one character**
/// (`strlen($name) > 1`), and `ClientContactPresenter::name()` does the exact
/// reverse: whichever side is empty borrows the other. `clientDisplayNameOf`
/// passes that straight through, rejecting only a server-minted placeholder
/// *email* (invoiceninja/flutter#116), never a contact's *name*. So a row that
/// stacks the party's display name over its primary contact's name printed the
/// same string twice for every individual (invoiceninja/flutter#118).
/// `VendorListTile` did it without the server's help — its `_displayName` runs
/// the same cascade client-side.
///
/// `classification == 'individual'` is deliberately **not** the gate, however
/// much it looks like one: it is optional, usually blank, and carries no
/// display meaning server-side (every backend use is tax / Peppol / filtering,
/// and `ClientPresenter` never reads it). It would miss most of the collisions
/// and catch none of the ones a business hits by naming its contact after
/// itself. The question is name-vs-name.
///
/// **This file imports nothing**, deliberately. `Contact` and `VendorContact`
/// share no supertype and the decision here is pure string work, so callers
/// project into `String`s rather than the file reaching for either model —
/// its sibling `lib/domain/phone/phone_candidates.dart`, which composes the
/// same labels for the same two tiles, needs a generic only because it walks a
/// list. There is no list here.
library;

/// Case- and whitespace-insensitive display-name equality.
///
/// Empty never matches empty — a blank string is "no name", not a name two
/// records happen to share.
///
/// The fold is trim + case + whitespace-runs and deliberately stops there.
/// Each half pays for itself against a shape that exists in the data:
///
///  * **trim** — `ClientPresenter::name()` returns
///    `$contact->first_name . ' ' . $contact->last_name`, **untrimmed**, so a
///    contact with only a first name arrives as `'Jane '` against the tile's
///    `.trim()`ed `'Jane'`. A bare `==` misses the commonest individual shape
///    there is. It also absorbs the literal `' '` the server writes into the
///    seeded blank contact's email (`ClientContactRepository::save`, #115).
///  * **case** — a client name typed `jane smith` against a contact
///    `Jane Smith`. No two *different* people differ only in case.
///  * **whitespace runs** — `'Jane  Smith'` against `'Jane Smith'`. Dart's
///    `RegExp` is ECMA-262, so `\s` also collapses the U+00A0 a name pasted
///    out of Word or Outlook carries — which `trim()` alone leaves mid-string.
///
/// Everything wider stays out: no diacritic folding (unlike admin-portal's
/// `removeDiacritics`, which is for *sorting*, where a wrong merge costs an
/// ordering rather than information), no punctuation, no initials, and above
/// all no prefix/containment — `Smith` is inside `Smith & Sons`, which is a
/// company named after its owner. The failure modes are asymmetric: a false
/// positive hides the only place the narrow row shows that contact's name, a
/// false negative merely leaves today's noise.
bool isSamePartyName(String a, String b) {
  final folded = _fold(a);
  return folded.isNotEmpty && folded == _fold(b);
}

/// The identifier worth putting on a party row's second line, or `''` when the
/// contact says nothing [partyName] hasn't already said.
///
/// Extends the row's existing name → email cascade with one rule: skip any part
/// that merely repeats the title. So a redundant name yields to the contact's
/// **email**, and the caller's own city → number → blank cascade runs on from
/// there.
///
/// The email is checked against [partyName] too, because a nameless client's
/// `display_name` can *be* that address — `ClientPresenter::name()` falls to it
/// when the contact has no name either.
///
/// The comparison must stay **string** equality rather than identity: the two
/// sides don't even pick the same contact (`contacts->whereNotNull('email')
/// ->first()` server-side, `isPrimary`-preferring in the tiles) and
/// `display_name` carries no contact id — so on a multi-contact client the
/// title and this line can legitimately name different people, and the fold
/// correctly declines.
String contactSubtitleLabel({
  required String contactName,
  required String contactEmail,
  required String partyName,
}) {
  final name = contactName.trim();
  if (name.isNotEmpty && !isSamePartyName(name, partyName)) return name;
  final email = contactEmail.trim();
  if (email.isNotEmpty && !isSamePartyName(email, partyName)) return email;
  return '';
}

/// Named to match `toast_controller.dart` and `task_status_colors.dart`, which
/// hoist the identical pattern — a `RegExp` compiled per call would be built
/// 2-4 times per row build, and one grep should find all three.
final _whitespaceRun = RegExp(r'\s+');

/// Case- and whitespace-insensitive form for comparison.
///
/// `task_status_colors._normalize` is the same three lines for the same reason.
/// Deliberately not extracted: the drift that justified collapsing the
/// `isBlank` twins in #115 can't happen to a generic string fold the way it can
/// to a domain predicate, and `toast_controller`'s copy omits `toLowerCase()`,
/// so the three aren't even the same function.
String _fold(String s) =>
    s.trim().toLowerCase().replaceAll(_whitespaceRun, ' ');
