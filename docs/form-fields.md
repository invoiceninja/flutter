# Form field input types

Companion to CLAUDE.md § Forms — Input types and § Forms — Date and time fields. Every text input declares the keyboard, capitalization and autofill its data needs, and none of it is visible under `flutter test` — a soft keyboard never renders. The main file carries one line per rule; this doc carries the evidence, including the engine-level reasons a wrong flag silently produces the wrong keyboard — plus Enter-to-save wiring for raw fields and dialogs, and the date / time shortcut list. Pinned by `test/lint/field_input_types_test.dart`.

## `signed:` is checked before `decimal:`, so `decimal` alone means no minus

**`signed:` is checked before `decimal:`, so `decimal: true` alone means no
minus key.** The iOS engine's `ToUIKeyboardType` (`FlutterTextInputPlugin.mm`)
tests `signed` first: `signed: true` → `UIKeyboardTypeNumbersAndPunctuation`
(has `-`), `decimal: true` alone → `UIKeyboardTypeDecimalPad` (big keys, no
minus), neither → `UIKeyboardTypeNumberPad` (digits only); Android mirrors this
with `TYPE_NUMBER_FLAG_SIGNED`. Every money field in the app shipped unsigned,
which made a negative line item — the standard way to put a discount or credit
row on an invoice — impossible to type on a phone or tablet. Sign a field iff a
negative is a value the product actually produces: line-item cost / quantity /
discount (`_NumericCell` covers all three on desktop), custom surcharges,
expense amount / foreign amount / tax amount, the gateway fee amount and
percent (a negative fee is a discount for using that method), and the
payment-schedule amount. Leave payment / refund / allocation amounts,
`partial`, doc-level discount, tax rates, exchange rates, budgets, stock
counts, `min_amount` / `max_amount` and the gateway **fee cap** unsigned — a
minus is meaningless there, and they keep iOS's larger 10-key decimal pad.
And **never sign a field whose own `inputFormatters` strips `-`**: the
recurring price-increase dialog filters to `[0-9.,]` and requires `n > 0`, so
signing it bought a minus key the formatter swallowed while costing every
user the decimal pad. `field_input_types_test.dart` now fails on that shape.
Product `price` / `cost` stay unsigned too: those are catalogue values, and the
negative case is entered on the line item. `parseDecimal` already preserves `-`
(its strip regex is `[^0-9\.\-]`), so nothing downstream changes.

## Autofill hints go only on the user's own identity or company

**Autofill hints go only on the signed-in user's own identity or their own
company.** Settings → User Details and Settings → Company Details carry them;
a client / vendor / contact record must **never** — the platform would offer to
fill the *admin's* own name, phone and address into somebody else's record, and
offer to save a client's portal password as the admin's. Note Flutter gates on
**null vs non-null**, so an empty list does *not* opt out (`auth_fields.dart`
documents this); pass `null`. A "save password" prompt also needs an
`AutofillGroup` around the correlated fields — login, signup and the
change-password screen each have one — and a *new* credential wants
`AutofillHints.newPassword`, not `.password`, or the OS offers the existing
saved one instead of generating a fresh one.

## `TextInputType.multiline` is derived — never add it

**`TextInputType.multiline` is derived — never add it.** `TextField`'s
constructor is `keyboardType ?? (maxLines == 1 ? text : multiline)`, and
`EntityEditField` / `OverridableTextField` derive `textInputAction: newline`
the same way, so ~35 notes / terms / footer / description fields are correct
with no `keyboardType` at all. The corollary is the live bug this rule exists
for: **setting any `textInputAction` other than `newline` on a multi-line
field breaks it** — `.next` made Return move focus instead of inserting a
newline, so the account cancellation feedback box was silently single-line on
touch. Writing `newline` out explicitly is fine and four sites do
(`log_call_sheet.dart`, `add_comment_dialog.dart`, `task_edit_layout.dart`,
`contact_us_dialog.dart`); the lint allows exactly that one value.

The other direction is worse, because it destroys data rather than merely
blocking input: **a field that can be *seeded* with multi-line text must
itself be multi-line.** `EditableText` prepends
`FilteringTextInputFormatter.singleLineFormatter` to every `maxLines: 1`
field, and a `FilteringTextInputFormatter` filters the *whole* new value, not
just the inserted characters — so the first keystroke strips every newline the
value already held. The wide line-item table's Description cell shipped like
that: there was no way to type a break, and a multi-line product description
picked onto the line, or a line written on the phone, in admin-portal or in
React, lost all its breaks the moment the user touched the cell. It is now
`maxLines: 6` (`_kDescriptionMaxLines` in `line_item_table_desktop.dart`),
pinned by `test/ui/features/billing_shared/line_item_table_description_test.dart`.

## A credential is obscured; whether it gets autofill depends on whose it is

**A credential is obscured and keyboard-hardened; whether it also gets
autofill depends on whose credential it is.** All of them take `obscureText`
(which `EntityEditField` renders with a reveal toggle) plus
`TextInputType.visiblePassword`. **The user's own** password does get autofill
— login, signup and Settings → User Details → Password each wrap theirs in an
`AutofillGroup`. **Another party's credential or a stored service secret never
does**: the client and vendor **portal password** belongs to the contact, and
the SMTP / Postmark / Mailgun / Brevo / SES / e-invoice-passphrase / gateway
config secrets belong to a service, so `autofillHints` stays null on all of
them. Note the shared widgets derive `autocorrect` from the **declaration**
(`obscureText` / `obscureToggle`), not from the live reveal state — revealing
a secret does not make it stop being one, and keying it the other way handed
the IME a revealed API key the moment the user edited it.

## `autocorrect: false` on identifier-shaped values

**`autocorrect: false` on identifier-shaped values** — invoice / quote / credit
/ PO numbers, VAT and registration numbers, transaction references, hostnames,
license keys, subdomains, and search boxes (iOS turning "Acme" into "Acne"
mid-search is the failure). It travels with `enableSuggestions`, so the shared
widgets expose one knob and set both. On iOS an `emailAddress` / `url`
keyboard already suppresses autocorrection under `UITextAutocorrectionTypeDefault`,
so the flag is belt-and-braces there — but it is **written out anyway** on
those fields, because that guarantee is iOS-only and reads as a decision
rather than an omission. It is load-bearing wherever the keyboard stays
`text`.

## The three shared widgets take these as plain parameters

**The three shared widgets take these as plain parameters**, all defaulting to
Flutter's own defaults: `EntityEditField` (`keyboardType`,
`textCapitalization`, `autofillHints`, `autocorrect`, `obscureText`), and
`OverridableTextField` / `SettingsTextField` (the same minus `obscureText`,
which the first has as `obscureToggle`). `AuthField` / `AuthPasswordField`
supplied the `autocorrect`-follows-`obscureText` idiom but is **not** a fourth
member: of the input-type hooks it exposes `keyboardType`, `obscureText` and
`autofillHints` only, and hard-codes `autocorrect: !obscureText` — fine for the
auth screens, whose only non-obscured fields are an email, a URL and a TOTP
code (keyboards that suppress autocorrect anyway), but it cannot take a
`textCapitalization`. (Its other parameters — `readOnly`, `autofocus`,
`focusNode`, `textInputAction`, `onEditingComplete`, `labelTrailing` — serve
the two-step login's focus and layout, not input types.) A local one-off wrapper
(`_OnboardingField`, `_SmtpTextField`, `_LabeledField`, `client_locations_tab`'s
`_field`) needs the same hooks rather than hard-coding.

## The date placeholder is a worked example, never a format pattern

**The placeholder is a worked example, never a format pattern.** `InDateField` renders `kDateFormatSampleIso` (`2000-01-31`) through `Formatter.dateExample` → `Formatter.date`, so the hint is produced by the same code as a committed value and the two can never disagree; `InTimeField` uses `timeFormatSample` → `formatTimeOfDay` for the same reason. Showing the raw intl pattern was invoiceninja/flutter#127: the server's **default** format (`date_formats` id 1) is `dd/MMM/yyyy`, and `MMM` is an abbreviated month *name*, so an empty Due Date field read as a typo — "one too many M" — and the reporter's own fix (lowercase it to `dd/mm/yyyy`) would have told them to type digits where the app renders `Sep`. Three things are load-bearing. The sample date is **fixed and its day is 31**: today's date cannot disambiguate the day/month slot order (on 2026-09-08 both `MM/dd/yyyy` and `dd/MM/yyyy` render two 2-digit slots, which is the one question a format hint exists to answer), and a fixed constant also keeps the fixture clear of the UTC/CI rule above; January keeps the month name short and 2000-01-31 is a Monday, so id 7 (`EEE MMM d, yyyy`) renders a real weekday. Routing through `Formatter.date` rather than reading `dateFormats[id]?.format` **also fixes a silent third branch** — before statics load that map is empty, the lookup was null, and the field had no placeholder at all; `date` falls back to `'yyyy-MM-dd'`. And the guard is a **round-trip** assertion (`in_date_field_test.dart` sweeps all 14 server `format_dart` values and requires `parseDateInput(hint, activePattern:)` to return the sample back), not an equality check against a hardcoded string — that is what catches a "humanized" pattern (`dd/mm/yyyy`) as well as a raw one; pin the locale, since id 12 (`d. MMM. yyyy`) renders `31. janv.. 2000` in French and `Formatter.date`'s `'..'` fixup makes it unre-parsable by its own pattern. The same sample backs Settings → Localization's date-format dropdown (`_dateFormatPreview` → `dateFormatSample`), so the picker and the field agree; that helper is the one place a raw `DateFormat` is legitimately built, because it previews formats that are *not* the active one. Every `InDateField` / `InTimeField` call site must pass `formatter:` — seven had not, and rendered ISO dates on screens whose every other date honored `date_format_id`.

## Enter-to-save in raw fields and dialogs

Reusable field widgets read the scope automatically (see `OverridableTextField`, `ClientEditField`). Raw `TextField`s with `maxLines == 1` should read `FormSaveScope.maybeOf(context)`, set `textInputAction: TextInputAction.done`, and pipe `onSubmitted` to `scope.trySubmit()`. Dialogs with a single text input + primary action: wrap the dialog body in `FormSaveScope` so Enter fires the primary action (login's fields wire `onSubmitted` explicitly in `lib/ui/features/auth/views/login_screen.dart` — on step 2, Enter moves to an empty *required* field before it submits).

## How the input-type invariants are pinned

Every text input declares the keyboard, capitalization and autofill its data
actually needs. None of this is visible under `flutter test` — a soft keyboard
never renders — so the invariants are pinned by
`test/lint/field_input_types_test.dart` (a source scan keyed on each field's
own label / `apiKey` token, with `// lint: allow-input-type <reason>` as the
opt-out) and by `test/ui/core/edit/entity_edit_field_test.dart`, which reads
the properties back off the underlying `TextField`.

## Date and time shortcuts

Single-date and single-time-of-day inputs go through `InDateField` (`lib/ui/core/widgets/in_date_field.dart`) and `InTimeField` (`lib/ui/core/widgets/in_time_field.dart`) — a typed `TextField` with a trailing picker icon; users type shortcuts *or* tap the icon for the Material modal:

- Date shortcuts: `today` / `tomorrow` / `yesterday` / `now`; signed offsets `+1`, `-7`; bare day `14`; short slash `5/14` (current year, US/EU order from the active pattern); compact `051426` (2-digit-year heuristic); plus ISO `2026-05-14`, the company's active format, and short/long fallbacks.
- Time shortcuts: bare hour `9` → `9:00`; compact `930` → `9:30`; AM/PM suffix `9p` / `9am`; plus `HH:mm`, `H:mm`, `h:mm a`.

Commit-on-blur + Enter; silent revert on parse failure (the picker icon is the fallback — no red-border noise). Display format comes from the active company `Formatter` (`formatter.settings.dateFormatId`, `.enableMilitaryTime`); without one the field falls back to ISO date and 24-hour time. **Parsing of typed input is locale-independent** — `9` always means `9:00`, `9p` always `21:00`; only display rendering switches between 24-hour and 12-hour.

**Don't use `showDatePicker` / `showTimePicker` directly** for form fields — only one-tap *range* filters still warrant it (`DateRangePickerButton`, `lib/ui/features/dashboard/widgets/filters/`). Reference call sites for typed single-date / single-time inputs: time-log table (`lib/ui/features/tasks/widgets/edit/time_entry_table.dart`), time-entry editor sheet, project due-date field. Parsing rules live in `parseDateInput` / `parseTimeInput` (`lib/utils/formatting.dart`) — reuse those for the same shortcuts without the field chrome.
