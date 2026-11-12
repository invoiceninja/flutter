# Payment types

Companion to CLAUDE.md § Searchable pickers. How a payment's Type is chosen for a new payment, how a company renames a type, and how it hides the ones it never uses (invoiceninja/flutter#191). Code: `lib/domain/payment_types.dart`, `lib/ui/features/payments/seed_payment_create_defaults.dart`, `lib/ui/features/payments/widgets/payment_type_picker_field.dart`, `lib/ui/features/settings/views/basic/payment_types_screen.dart`.

Payment types are a fixed, global server list (ids 1–53, `app/Models/PaymentType.php` → `getDefaultPaymentTypes()`). A company cannot add one; `/statics` serves the list with each name already translated into the user's language (`Statics.php`, `ctrans('texts.payment_type_…')`).

## A new payment's Type: the client's own default, then its last payment, then the group / company default

The server never fills in a payment's type on create, so a blank one stays blank. `seedPaymentCreateDefaults` seeds it:

1. a Default Payment Type set on the **client itself** (`client.settings.payment_type_id`, the sparse map, not the cascade);
2. the type of the client's **last manual payment** (`PaymentDao.latestManualTypeForClient`), unless the company hides that type;
3. the settings cascade: the client's group, then the company.

Without a client only 3 applies. v1 seeded 3 on every new payment and React the company's alone; neither remembered the client's last.

Each client change starts one async chain per request token that works out the winner and calls `PaymentEditViewModel.seedTypeId` once. Four sources answer (the synchronous `resolvedIfReady` guess, the awaited `resolved()`, the client row, the last payment), and letting each seed as it landed made precedence depend on arrival order. Step 2 reads Drift first, so it works offline, then once per client per session `PaymentRepository.refreshLatestForClient` fetches the client's newest page (`client_id`, `sort=date|desc`, active + archived; a narrowed fetch that never touches the cursor) and reads again. `seedTypeId` keeps the existing guards: create only, never over a user's pick, never dirties an untouched form, a clone keeps its type.

**Last means manual, and not Credit.** An online charge (`is_manual = false`) says nothing about how the user records this client's payments by hand. Type 32 (Credit) is excluded because the server records an applied credit (`CreditService`) and a subscription change as manual payments of that type.

**Order.** `date DESC`, then `is_dirty DESC`, then `created_at DESC`. An offline create has `created_at` 0, so without the dirty term it lost a same-day tie to every synced payment. Ids are hashed and can't break a tie.

**The hint.** "Last used for this client" (under the Type field) shows only when the last payment's type differs from the settings default: the one case where the value would surprise. `typeSeedSource` is set inside `seedTypeId`, before its same-value early return, so the hint follows the reason even when the value doesn't change; a pick and a Discard clear it.

Pinned by `test/data/db/dao/payment_latest_manual_type_test.dart` and `test/ui/features/payments/seed_payment_create_defaults_test.dart`.

## A payment type's name goes through `paymentTypeLabel`

A company renames a type by setting its server key in `settings.translations` (`payment_type_Instant Bank Pay` → "Echtzeitüberweisung"). The server already prints that override on PDFs, the client portal, emails and exports (`PaymentType::name()` → `ctrans`, with `Ninja::transformTranslations`), so renaming needs no server change. Every place the app shows a type name goes through `paymentTypeLabel` / `paymentTypeName` (`lib/domain/payment_types.dart`); never render `statics.paymentType(id).name` directly.

- **`kPaymentTypeLabelKeys` mirrors `PaymentType::$type_names`.** When the server adds a type, add its key here (and to `_app_pending.json` if `en.json` lacks it, as `payment_type_Mobile Payment` did).
- **FPX (46) and Stripe Bank Transfer (50) are left out.** The server names them `fpx` and `bank_transfer` in documents but `payment_type_FPX` / `payment_type_Stripe Bank Transfer` in `/statics`, so no one key renames them consistently, and writing `bank_transfer` would relabel every "Bank Transfer" the server prints. They keep the server's name and the Payment Types page offers no rename for them.
- **Only an actual override replaces the server's name** (`lookup(key) != lookupBundled(key)`). The `/statics` name is already localized; the bundle may lack the key in the user's locale and would hand back English.
- **Custom Labels are withheld while the app's language differs from the company's** (`CompanyLabelOverrides`). The Payment Types page therefore reads and writes the draft's `translations[key]` directly, never the rendered label.
- **Pickers search the stock name too** (`searchTextOf`), so "Instant" still finds "Echtzeitüberweisung".

## Hidden payment types: out of the opening list, still searchable, never the selected value

`settings.hidden_payment_types` is a comma-separated id list, edited on Settings → Payment Types (company scope only) or from the Type pickers' "Manage payment types" footer, which opens the same editor as a dialog so the record being entered survives.

- **It applies to the payment and expense Type pickers and the default-type pickers** (`PaymentTypePickerField`, `PaymentTypeOptions`), never to lists, filters, detail screens or reports.
- **A hidden type leaves the opening list but a typed query still finds it** (`SearchableDropdownField.idleExcludes`), tagged "Hidden". A query matching nothing would close the popover, footer and all, with no word on where the type went.
- **The selected value is resolved from the full list and always shown**, so an old payment, or a default, whose type was later hidden still reads correctly. A hidden company default still seeds new payments; its row on the page says so.
- **The pickers show every type without typing** (`idleResults: items.length`); the default of 20 hid SEPA, Venmo and Zelle behind a search.
- **Clearing writes `''`, never null.** `CompanySettingsApi` serializes with `includeIfNull: false`, so a null would leave the stored list in place on save.
- **The server stores the key without declaring it** (`CompanySettingsSaver::saveSettings` copies every incoming key onto the defaults), so the app works against any server; the server PR that declares it in `CompanySettings` makes it official. A company-settings save from the old v1 app, which serializes a typed settings model, resets the list.
- **A hidden last payment type falls through to the settings default** when seeding a new payment.

Pinned by `test/domain/payment_types_test.dart`, `test/ui/core/widgets/searchable_dropdown_field_test.dart` (`idleExcludes`) and `test/ui/features/settings/views/basic/payment_types_screen_test.dart`.
