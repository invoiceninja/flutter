# DocuNinja

Companion to CLAUDE.md § Strict rules. DocuNinja is Invoice Ninja's e-signature add-on: documents sent for signature, templates, and the signing of invoices, quotes and purchase orders in the client portal. This doc covers what the app reads from it, how it is gated, and the contract the app relies on. The work ships in phases, and each section below says what has shipped.

**Read React at its upstream ref.** The reference client is React (`invoiceninja/ui`); read it with `git -C ~/Code/react show origin/HEAD:<path>`. The local checkout has lagged hundreds of commits behind, and the DocuNinja screens changed in that gap.

## DocuNinja is a separate service, and the server only stores what it reports

DocuNinja runs on its own host (`https://api.docuninja.co`; `docuninja.co` is the marketing site). The Invoice Ninja server does not proxy its API. A private hosted package hands each IN user a DocuNinja token (`POST /api/docuninja/login`), provisions accounts, users and seats, embeds DocuNinja signing in the client portal, and writes the results back onto the entity.

What the app reads from the IN API (Phase 0, shipped):

| Field | Where | Meaning |
|---|---|---|
| `company.enable_modules` | `Company.enableModules`, Drift `companies.enable_modules` (schema v20) | DocuNinja is on for the company. Server `Company::docuninjaActive()` = hosted (or local) && this flag && the invoice-settings plan feature. **Not** the `enabled_modules` bitmask. Set by the hosted service and not fillable, so it is read-only: `CompanyApi` excludes it from `toJson`. |
| `account.docuninja_num_users` | `AuthSession.docuninjaNumUsers` (via `accounts.features_json`, no migration) | DocuNinja seats bought. React's Join treats a non-zero count as "already joined". |
| `sync` on invoices, quotes, POs | `Invoice.sync`, `Quote.sync`, `PurchaseOrder.sync` | `dn_completed` (every signer has signed), `dn_document_hashed_id`, `invitations[{invitation_key, dn_id, dn_invitation_id, dn_sig}]`. Read-only: kept in the stored row, never sent (`_domainToCompanion` spreads it over `toApiJson`, as for invoices). Credits carry a `sync` too, but no portal flow signs them. |
| `can_sign` on contacts and invitations | `Contact.canSign`, `VendorContact.canSign`, `Invitation.canSign` (tri-state) | Which contacts the portal asks to sign. Set per invitation by "Authorized to sign" under each invited contact on an invoice, quote, credit, recurring invoice or purchase order. The contact's own value (client and vendor forms) is what a new invitation starts with. Both show only while `enable_modules`. The save rules are in `docs/contacts-and-invitations.md` § A save sends an invitation's key only with its can_sign. |

## A signed document is marked beside its status, and the mark opens the signed PDF

When `sync.dn_completed` is set and DocuNinja is still on for the company, the invoice, quote and purchase order detail headers show React's green **Signed Document** pill (`signed_document`) next to the status pill (`SignedDocumentPill`, the header's `signedPill` slot, decided by `showSignedDocumentPill`). The signed state comes from `isDocuNinjaSigned` (`lib/domain/docuninja/docuninja_signed.dart`), which accepts `true`, `1` and `"1"`. The DocuNinja check is there because the server serves the signed copy only while `docuninjaActive()`; with DocuNinja off it renders afresh, and the pill would open an unsigned PDF. React shows its badge on `sync` alone. The screens pass no pill at all for an unsigned document rather than one that hides itself, because the header's `Wrap` spaces even a zero-size child.

A quote or purchase order stored before the app kept `sync` has none until it is fetched again, so an already-signed one shows the pill only after its next refresh or a Sync.

A tap opens the document's PDF route (`/<entity>/<id>/pdf`). For a signed document that PDF is the signed copy: the stored-PDF route serves the DocuNinja-signed file in place of a fresh render (`lib/data/services/stored_pdf.dart`). React's badge opens the DocuNinja document (`/docuninja/{sync.invitations[0].dn_id}`, read by `docuNinjaDocumentId`); the app's pill gains that destination once it has DocuNinja screens and the user has access.

Clones drop `sync` (`sync: null` in the invoice, quote and PO clone actions; the cross-entity clones start from an empty document), so a copy of a signed quote is not marked signed.

## DocuNinja talks only through `DocuNinjaClient` (`api.docuninja.co`, its own token); its IN-side handshake passes `unauthorizedIsAnswer`, so no DocuNinja 401 ever ends the IN session

Phase 1a, shipped: the session and the client, with no screens yet.

**The handshake.** `DocuNinjaLoginApi` posts `/api/docuninja/login` to the Invoice Ninja host root (not `/api/v1`), through `ApiClient` with `unauthorizedIsAnswer: true` and `readOnly: true`. A user with no DocuNinja account gets a 400 or 401, and on `ApiClient`'s normal path a 401 runs the permission sniff, a `/ping` and, if that ping fails (offline, a captive portal), a forced logout. The flag skips that whole block, so the refusal arrives as `DocuNinjaRefused`. React does the same with `skipIntercept`. `docuninja_login_api_test` pins that no 400 / 401 reaches `onUnauthorized` or sends a `/ping`.

**What it answers** (probed live on a hosted test account, Nov 2026; fixtures in `test/fixtures/docuninja/`, with tokens, keys, emails and signed URLs replaced):

- One answer per *user*, the same whichever Invoice Ninja company asks: the DocuNinja user, `companies[]` (each with its own `token` and `ninja_company_key`), and the user's `company_user` (`is_admin`, `is_owner`), `account` (`plan`, `num_users`) and `permissions`, once at the top level, not per company.
- The DocuNinja company for the active Invoice Ninja company is the one whose `ninja_company_key` equals the company's `company_key` (`DnLogin.companyFor`). Only the Invoice Ninja companies with `enable_modules` on had one; the others are React's company-setup step.
- The DocuNinja plan was `pro`, with a per-company `document_limit`.

**The session.** `DocuNinjaSession` (`Services.docuNinja`) holds the answer in memory only and maps it to a `DocuNinjaAccess`, as React's provider, Join and Documents pages decide:

| State | When |
|---|---|
| `unavailable` | self-hosted (DocuNinja is hosted-only); the server is never asked |
| `notJoined` | the handshake refused and the account bought no seats (`docuninja_num_users == 0`): Join |
| `noAccess` | refused, but the account has seats: this user was not given one (React's Join sends such a user back, so a loop would follow) |
| `companySetup` | an answer with no company paired to this one |
| `planWall` | a DocuNinja admin whose DocuNinja plan is not `pro` (`useDocuNinjaAdmin`, the DocuNinja role, not the IN one) |
| `ready` | everything else |
| `offline` / `failed` | the handshake could not reach the server / failed otherwise |

It resets on sign-out and on every company change (`Services.build`, beside the calendar connection), and a generation counter drops an answer that lands after a reset, so a late handshake never hands company A's token to company B. A forced reload (Reconnect, a 401) keeps the current state and token until the new answer lands.

**The client.** `DocuNinjaClient` uses its own `http.Client` (`createDefaultHttpClient`), never `ApiClient`, whose 401 handling belongs to the Invoice Ninja session. It sends `Authorization: Bearer <company token>`; a 401 re-runs the handshake once (`DocuNinjaSession.refreshToken`) and retries, and a second one surfaces as `DocuNinjaException`, which the screens answer with Reconnect. Server messages are logged, never shown raw. `DocuNinjaApi` holds the document endpoints the list and detail screens use.

**Online-only.** DocuNinja data is not in Drift and does not go through the outbox (both are exceptions in CLAUDE.md): it is another service whose state machines (send, sign, void) run server-side, and a queued write against them could not be replayed safely. Page previews are signed URLs that expire after an hour (`DnFile.previews`), so they are re-read with the document, never stored; they send `Access-Control-Allow-Origin: *`, so the web build can draw them.

