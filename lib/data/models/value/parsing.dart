import 'package:decimal/decimal.dart';

import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/domain/document.dart';

/// Epoch seconds (Invoice Ninja's wire convention for all timestamps) → UTC
/// [DateTime]. Mirrors the `_seconds(int)` helper that every entity's
/// `fromApi` used to declare privately.
DateTime epochSecondsToUtc(int s) =>
    DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);

/// Same as [epochSecondsToUtc] but returns null when [seconds] is <= 0.
/// Matches the server convention where `archived_at = 0` means "not
/// archived" — the domain model carries `archivedAt: null` for that case.
DateTime? epochSecondsToUtcOrNull(int seconds) =>
    seconds > 0 ? epochSecondsToUtc(seconds) : null;

/// `num` → `Decimal` via string round-trip. Used for non-money numeric
/// fields (tax rates, inventory quantities) where IEEE-754 doubles would
/// lose precision. Money goes through `parseMoney` in `money.dart`.
Decimal numToDecimal(num n) => Decimal.parse(n.toString());

/// The literal placeholder the server returns for a contact's `password`
/// when one is set — it never sends the real hash (see
/// `ClientContactTransformer`/`VendorContactTransformer`). It must never be
/// written back: echoing it fails the backend's password validation
/// (`min:7` + lower/upper/digit regexes) with a 422 the user can't see or
/// clear. Treat it as "no change" — blanked on the way in (`fromApi`), never
/// serialized on the way out (`toApiJson`).
const String kMaskedPassword = '**********';

/// Matches the junk address alone; [isPortalPlaceholderEmail] is the API. The
/// uppercase lookahead is the whole false-positive story — see the doc there.
final RegExp _kPortalPlaceholderEmail = RegExp(
  r'^(?=[^@]*[A-Z])(?:[A-Za-z0-9]{6}|[A-Za-z0-9]{15})@example\.com$',
);

/// Whether [email] is an address the **server** minted, not one the user typed.
///
/// When a contact with no email of its own first reaches the client or vendor
/// portal, the backend writes one so Laravel's `contact` guard has a username
/// to log in with — then **persists** it and returns it on every `GET` for
/// ever after, so the user sees an address they never entered
/// (invoiceninja/flutter#116). The app's own "View portal" button on the
/// contacts card is one of the triggers. Fourteen mint sites in the server
/// source, every one of them followed by a `save()`:
///
///  * `ClientPortal/InvitationController.php:112` and its vendor twin
///    `VendorPortal/InvitationController.php:58` — `Str::random(15)`;
///  * `Middleware/ContactKeyLogin.php` :57 (15) and :77/:97/:115/:129/:144 (6),
///    plus `Middleware/VendorContactKeyLogin.php` :55 (15) and five more at
///    (6) — magic-link, contact-key and client-hash portal logins.
///
/// The server already treats these as junk everywhere *except* the API:
/// `HtmlEngine.php:568` / `VendorHtmlEngine.php:272` blank the address before
/// rendering a PDF, and `NinjaMailerJob.php:814` refuses to mail it on hosted.
/// `ClientContactTransformer.php:36` returns it raw, and that asymmetry is the
/// bug this closes.
///
/// `Str::random(n)` is base64 of `random_bytes` with `/`, `+` and `=` stripped
/// — **exactly n characters from `[A-Za-z0-9]`** — so the stored value is
/// always 6 or 15 alphanumerics at `@example.com`. Nothing else about it is
/// inferable, which makes this a heuristic, and the calibration matters in one
/// specific place: the seeded dataset behind the public demo build
/// (`tools/build_demo_web.sh`) is Faker data whose every contact sits at
/// `example.com` / `.net` / `.org`, so a blanket "hide anything @example.com"
/// rule would blank all 96 of them. Measured live against
/// `demo.invoiceninja.com` (96 contacts, 31 at `example.com`): matching on
/// length alone also matches three **real** addresses — `shad30@`, `cboyle@`,
/// `lucy17@` — while requiring at least one **uppercase letter in the local
/// part** takes that to zero and still matches the reported
/// `dq9GHaI6Dncm0Zd@example.com`. Every Faker local part is lowercase, as is
/// every hand-written `@example.com` fixture in this repo's own tests. The
/// price is a miss — an all-lowercase mint — at `(36/62)^6 ≈ 3.8%` for the
/// 6-char variant and `≈ 0.029%` for the 15-char one. That asymmetry is the
/// point: a miss shows one junk address, a false positive **hides a real
/// one**. `example.net` / `.org` stay out for the same reason — the server
/// never mints those, and 65 demo contacts live there.
///
/// Considered and rejected as a co-signal: `last_login > 0`. Only the two
/// `InvitationController`s fire `ContactLoggedIn` → `UpdateContactLastLogin`;
/// the eleven `*ContactKeyLogin` middleware branches call `loginUsingId`
/// directly, so ANDing it in would silently miss every 6-char mint.
///
/// Handled exactly like [kMaskedPassword] — a server literal that is not user
/// data — with one deliberate difference on the way out. Blanked on the way in
/// (`Contact.fromApi` / `VendorContact.fromApi`), then **carried and
/// re-emitted, never cleared**, by `toApiJson`: see the field doc on
/// `Contact.portalPlaceholderEmail` for why omitting the key instead round-trips
/// to `''` through the local-save payload.
///
/// The `trim()` mirrors the load-bearing one in `ContactIdentity.isBlank`: the
/// server's seeded blank contact carries `email = ' '`
/// (`ClientContactRepository.php:126`), which trims to `''` and correctly does
/// not match.
bool isPortalPlaceholderEmail(String email) =>
    _kPortalPlaceholderEmail.hasMatch(email.trim());

/// Lift the optional API `documents` list into the non-nullable domain
/// list. The DTO is nullable so it can distinguish JSON-omitted from
/// JSON-empty; the domain model is non-nullable so the UI never has to
/// null-check the list.
List<Document> mapDocuments(List<DocumentApi>? raw) =>
    (raw ?? const <DocumentApi>[])
        .map(Document.fromApi)
        .toList(growable: false);
