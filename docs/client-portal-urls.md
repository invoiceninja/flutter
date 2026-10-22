# Client portal URLs

Companion to CLAUDE.md § Settings screens. Why a self-hosted portal URL always carries the company
key, and why the URL's QR code waits for the server to accept the address. The URL builder is
`lib/domain/client_portal_urls.dart`; the row that gates the QR code is
`lib/ui/features/settings/views/advanced/client_portal/widgets/confirmed_portal_url_display.dart`.

## A self-hosted portal URL always carries the company key

`client/login/{company_key?}` and `client/register/{company_key?}` take the key as optional
(`routes/client.php`). What the server does without it, read on `origin/v5-develop` (Oct 2026):

| Page | Hosted | Self-hosted, no key |
|---|---|---|
| Register (`ContactRegister` middleware) | the company whose `subdomain` (with `portal_mode = subdomain`) or `portal_domain` (with `portal_mode = domain`) matches the host | `Account::query()->first()->default_company`, falling back to that account's first company |
| Login (`ContactLoginController::resolveCompany`) | the company matching the subdomain, else the `portal_domain` | the first company whose `portal_domain` + `portal_mode = domain` match the host, else `Company::first()` |

Hosted resolves by host, so its URLs never need the key and are unchanged.

Self-hosted falls back to *the first account's* default company (register) and *the
lowest-id company in the database* (login). From 2c671991 to Oct 2026 the app dropped the key when
the signed-in user had one company (`session.companies.length == 1`). That list is the **user's**
companies, not the server's: in an account with companies A (default) and B where the user belongs
only to B, the app showed B's registration URL with no key, and the server registered B's clients
into A — or answered "Registration disabled" from A's flag — while the login URL showed A's name and
logo.

Nothing the app can see proves a company is the server's fallback:

- `account.default_company_id` (in the session as `defaultCompanyId`) names *this* account's
  default, but the register fallback is the *first* account's. A self-hosted server normally has one
  account (`CreateAccountRequest::authorize` is hosted-only), but an OAuth sign-in with no matching
  user creates another (`LoginController::loginOrCreateFromSocialite`), as do the
  `ninja:create-account` console commands.
- `Company::first()` is the lowest database id, and the app only sees hashed ids. An account owner
  is attached to every company of the account (only an owner may create one —
  `StoreCompanyRequest::authorize` — the creator is attached, and `UserController::detach` refuses
  an owner), so a sole-company owner's company is the only one *in that account*. The same
  second-account case breaks it.

So self-hosted always shows the keyed URL, as React does (`Settings.tsx`, `Registration.tsx`). With
no key loaded yet there is no URL rather than the short one. The path form `/client/register/<key>`
is what `ContactRegister` reads: `$request->company_key` falls back to the route parameter.

Tests: `test/domain/client_portal_urls_test.dart`.

## The portal URL's QR code is offered only for the address the server holds

The Login URL and Registration URL rows follow the settings draft, so the text previews an address
while it is typed. The QR code and its PNG download are what get printed, and a printed code can't
be corrected. A hosted user who typed a subdomain someone else holds saw
`https://<taken>.invoicing.co/client/login` and its QR code; the save went through locally and then
422'd, and the printed code led to the other company's portal.

`ConfirmedPortalUrlDisplay` shows the QR button only when both hold:

1. **The address is saved.** The draft's URL equals the URL built from
   `SettingsDraftHost.initialCompany` (the baseline the draft started from). The Registration row
   also needs `client_can_register` saved on, or the server answers the address with "Registration
   disabled".
2. **The server has accepted it.** Settings save offline-first: `save()` writes Drift, queues an
   outbox row and returns, so "saved" is not "accepted". `OutboxDao.watchHasUnacceptedRecordEdit`
   reports any company row still in the outbox, `dead` included: a rejected edit keeps its value in
   the local row (`CompanySyncDispatcher` does not revert it), so until the row is resent or
   discarded the local subdomain is not the server's. Document uploads and comments don't count
   (`writesNoRecordField`). Any other queued company edit holds the QR code back too, even an
   unrelated field. That is the price of not parsing the full-company payload.

While either fails, the URL text stays as a preview and a caption under it reads
`portal_qr_code_after_sync`. Until the outbox stream has answered, neither the QR code nor the
caption shows, so neither flashes.

Tests: `test/ui/features/settings/views/advanced/client_portal/client_portal_qr_confirmation_test.dart`
(fakes the outbox stream, since a Drift watch stream never settles under the widget-test clock) and
`test/data/db/dao/outbox_unaccepted_record_edit_test.dart` (the query, on a real in-memory database).
