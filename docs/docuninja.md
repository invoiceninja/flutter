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

## The DocuNinja screens follow React's, decided by the session

Phases 1b–1d, shipped: the sidebar entry, the screens before the documents, the list and the detail page. Each mirrors React's (`pages/documents/…` at `origin/HEAD`), in the app's chrome.

- **Entry.** A fixed branch, `FixedBranchKind.docuninja` at `/docuninja` (branch 23), the sidebar row "DocuNinja" (`Icons.draw_outlined`, not the Documents list's icon) and `G N`. Like React's nav it shows for every *hosted* user; on self-hosted there is no row, no Customize-sheet entry and `G N` is refused, since DocuNinja is a hosted service.
- **Before the documents** (`DocuNinjaScreen` switches on `DocuNinjaAccess`):
  - **Join** (`Join.tsx`): the logo, tagline and three features, then Create for an Invoice Ninja owner or admin on Pro or Enterprise (`/api/docuninja/create`, then the session and the company refresh, since the server turns on `enable_modules`), Upgrade for one on another plan, and React's "contact your admin" for everyone else.
  - **Company setup** and the **plan wall** (`DocumentStates.tsx`). React hard-codes the setup sentence in English; the app's is `docuninja_company_setup_help`.
  - **No access**: React's `docuninja_contact_admin_for_access`.
  - **Upgrade** goes to Account Management (`/settings/account_management`), as React's does. That screen already follows the store rules, so nothing here offers a purchase.
- **The list** (`Documents.tsx`, `useTableColumns.tsx`): on a pane of 720 px or more, React's table (contact, user, document, files, status, created at, the date of the first file); narrower, a row per document. A page of 20 at a time, pull to refresh. The status badge keeps React's colour families in this app's tokens, and deleted or archived win over the status. A row opens the detail page; React opens a draft without invitations in the builder, which the app does not have yet.
  - **Search is `search`.** DocuNinja ignores `filter` (measured: every document came back).
  - **One `status` list carries both filters.** React's table sends the lifecycle states (active / archived / deleted, default active) and the statuses (`useDocumentFilters.ts`) together, and DocuNinja matches a document whose state *and* status are both listed (measured: `active,sent` found the sent document, `active,completed` nothing). The state set is never empty; an empty pick means active.
  - **A changed query drops a page still in flight, and clears the load-more flag itself** — the stale request's own `finally` no longer owns it, so without that the list stops paging for good (`docuninja_documents_view_model_test`).
  - **The list re-reads after any change on a detail page** (`DocuNinjaSession.documentsChanged`), as React refetches its documents after every action.
  - **Dates are the user's calendar day** (`dnLocalDate`): DocuNinja stamps UTC, so the date part of the string is the wrong day for anyone far from UTC.
- **The detail** (`show/Document.tsx`): the title and status, the signers in signing order (`Invitations.tsx`, with where each is and a resend) beside the timeline (`TimelineLayout.tsx`, its UTC times shown local), and React's actions in its order where they apply: view PDF, send, audit log, download (completed only), clone, void (sent only), options (description; expiry until sent), archive / restore, delete. They are `EntityActionItem`s in `EntityActionsPopupButton`, so the menu closes on Android back and void and delete confirm through `guardedOnTap` (the Confirm actions preference). Success toasts are React's keys (`voided_document`, `document_archived`, `document_restored`, `deleted_document`, `cloned_document`).
  - **Send** follows React's `useIsSendable`, which checks the *Invoice Ninja* role and permissions (`edit_documents`, `create_documents`, `requires_approval`), not DocuNinja's. React also lets a creator send their own document by comparing the DocuNinja document's `user_id` with the Invoice Ninja user id, which never match; the app leaves that arm off.
  - Send opens React's `send_confirmation` dialog listing who will be emailed, its primary not autofocused because it emails customers.
  - **Resend** is shown until the document is completed, voided or deleted (`dnShowsResend`); with a signing order only the next unsigned signer's is enabled (`dnCanResend`, React's `canSendInvitation`). It confirms first, since it emails a customer.
  - **Delete stays on the page**, as React's does: the document reloads deleted, with Restore.
  - **Options saves from inside the dialog** and stays open on a refusal, showing the field errors, so an edit is never lost. The expiry is the stored string's calendar day, and it is sent only when it changed while the document can still expire — an untouched field is never re-sent shifted a day.
  - The signed PDF opens at `/docuninja/:id/pdf` in `PdfPreview`. Downloads go through `downloadPdf` under DocuNinja's own file name, with `sanitizeFileName` (docs/file-downloads.md); one runs at a time.
- **Not yet:** creating and editing a document and Make template (the builder and templates phases), live updates over DocuNinja's socket, `/app/docuninja/…` deep links and Copy link, a row `⋮` and bulk actions on the list, and DocuNinja's settings. Until then the refresh button and pull to refresh re-read DocuNinja.
- **Strings** are React's keys. The handful missing from this app's `en.json` (`docuninja_join_*`, `docuninja_creating_account`, `signatories`, `send_emails_to_following`, and `docuninja_company_setup_help` for the sentence React hard-codes) have their English in `_app_pending.json`. Most locale bundles already translate them (they came from the server's language files), so a locale's `_app_pending_<locale>.json` carries one only where its bundle does not: React's own translation where it has a real one, the app's otherwise (Serbian is Latin script here, so never React's Cyrillic).

