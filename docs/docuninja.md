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
| `can_sign` on contacts | `Contact.canSign`, `VendorContact.canSign` | Which contacts the portal asks to sign by default. |

## A signed document is marked beside its status, and the mark opens the signed PDF

When `sync.dn_completed` is set and DocuNinja is still on for the company, the invoice, quote and purchase order detail headers show React's green **Signed Document** pill (`signed_document`) next to the status pill (`SignedDocumentPill`, the header's `signedPill` slot, decided by `showSignedDocumentPill`). The signed state comes from `isDocuNinjaSigned` (`lib/domain/docuninja/docuninja_signed.dart`), which accepts `true`, `1` and `"1"`. The DocuNinja check is there because the server serves the signed copy only while `docuninjaActive()`; with DocuNinja off it renders afresh, and the pill would open an unsigned PDF. React shows its badge on `sync` alone. The screens pass no pill at all for an unsigned document rather than one that hides itself, because the header's `Wrap` spaces even a zero-size child.

A quote or purchase order stored before the app kept `sync` has none until it is fetched again, so an already-signed one shows the pill only after its next refresh or a Sync.

A tap opens the document's PDF route (`/<entity>/<id>/pdf`). For a signed document that PDF is the signed copy: the stored-PDF route serves the DocuNinja-signed file in place of a fresh render (`lib/data/services/stored_pdf.dart`). React's badge opens the DocuNinja document (`/docuninja/{sync.invitations[0].dn_id}`, read by `docuNinjaDocumentId`); the app's pill gains that destination once it has DocuNinja screens and the user has access.

Clones drop `sync` (`sync: null` in the invoice, quote and PO clone actions; the cross-entity clones start from an empty document), so a copy of a signed quote is not marked signed.
