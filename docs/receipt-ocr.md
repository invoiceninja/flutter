# Receipt OCR

Companion to CLAUDE.md § Strict rules (the store-SDK rule) and § Forms. How New Expense reads a
receipt photo or PDF on the device and fills its fields. The rules are in `lib/domain/expenses/`
(`receipt_parser.dart`, `receipt_fill.dart`, `vendor_matcher.dart`, `receipt_scanner.dart`); the
engines answer one channel from each runner; the form side is `ExpenseEditViewModel`'s receipt
section and `receipt_read_banner.dart`.

## Receipt OCR fills only fields that are unedited and blank, never creates or guesses a vendor, and writes the receipt's number to private notes — never Number or transaction reference

- **Blank and untouched only** (`fillExpenseFromReceipt`). A field is filled when it holds its
  empty value (`emptyExpense()`'s) *and* is not one the user is in. "Equals `createBaseline`"
  is not the test: the baseline *is* the staged draft, so on a "New expense" from a vendor or a
  clone it would have overwritten the vendor and the copied amount. The date's empty value is the
  form's today default, so a clone's or prefilled draft's date is never replaced.
- **A field the user is in is left alone.** `InDateField` commits on blur, and a picker's typed
  query isn't in the draft until a pick — so a half-typed value equals the baseline and would be
  overwritten under the caret. `ReceiptFieldFocus` tells the view model which fields have focus
  (`noteReceiptFieldFocus`); the whole Amount card counts as one.
- **A late result never lands on a finished form.** Native OCR can't be cancelled, so every read
  carries a generation; Cancel, Discard (`reset`), removing the file and `dispose` bump it, and a
  stale result is dropped. A result arriving after a save started (a save counter captured when
  the read began), once the record turned out to exist (`!acceptsDocuments`), or after its file
  was removed is dropped too. Only one automatic read runs at a time (`_autoReadPending`), and a
  file counts as read only once a result was applied.
- **The receipt's number goes to private notes** ("Receipt #1001", app-local
  `receipt_number_note`). The expense Number is the company's own counter and unique per company
  (`StoreExpenseRequest` → a 422 for two receipts both numbered 1001); a non-empty transaction
  reference marks the expense paid (`Expense.isPaid`).
- **Vendors** (`matchVendor`): only an active local vendor, only on an exact folded match or when
  the receipt line starts with every word of the vendor's name, only when one vendor fits best, and
  never a name under three letters. A wrong vendor would also bring its currency. No match →
  "On receipt: <name>" under the field with a Create action that opens the name dialog first (a
  till prints `Wholefds Mkt`). Never created on its own. No category guessing.
- **Currency**: the receipt's ISO code or unambiguous symbol, else the vendor's (the picker's
  step), never `$`/`kr`/`¥`/`R`/`Fr`; a currency equal to the company's is not reported. An invoice
  currency already picked gets a fresh `crossCurrencyRate`.
- **Taxes**: none when `enabled_expense_tax_rates` is 0. One tax at exactly one of the company's
  rates stays By rate under the company's name for it — but only when the printed amount is what
  that rate on the total comes to, to the cent (`_rateAgrees`): a US grocery receipt prints
  8.625% with 0.56 tax on 14.23 because the food is untaxed, and By rate would tax all of it.
  Anything else is By amount, one tier per printed tax, extra lines summed into the last tier.
  Inclusive is set (a receipt total includes its tax) only when the amount came from this read
  or was blank — a net amount the user typed stays net — and never when the user set the switch
  themselves; the read's own edits never latch "user touched".
- **Undo** takes back the newest read only (each read keeps its own before/after), restoring
  each field it filled while that field still holds the read's value — an edit made since is
  kept. Taxes go back per slot; the tax mode and the inclusive switch only when no filled slot
  was edited since, and the switch only if the user hasn't touched it. A currency the read set
  takes its rate back only if no rate was typed since, and the converted amount is recomputed
  from the amount the form holds now. The file's Read button comes back.
- **Markers**: "From receipt" under each filled field, "From receipt — check" for a guess
  (a fallback total, a total with an empty tip line, an ambiguous date). A marker stays while the
  user is in the field and goes when they leave it changed — not on the first keystroke, which
  would shift the form under a finger. The Amount card (amount and all three tax slots) counts as
  one field. Markers and the strip go once the form can no longer take a receipt.

Tests: `receipt_parser_test.dart`, `receipt_fill_test.dart`, `vendor_matcher_test.dart`,
`receipt_scanner_test.dart`, `receipt_text_recognizer_test.dart`, `expense_receipt_read_test.dart`,
`receipt_read_banner_test.dart`.

## When a receipt is read

- **On its own**: the first readable file added to a pristine New Expense (`draft ==
  createBaseline`, not prefilled, nothing read yet) — however it arrived: Scan Receipt, a share
  from another app, a desktop drop, the phone tiles. It starts after `seedCompanyDefaults`, so the
  company's tax-mode defaults don't fight the read. Scan Receipt and a share stage the files with
  a blank draft; the screen drops that draft (`stagedExpenseDraft`), because a staged draft makes
  the form `prefilled`, which would stop the read and the date fill.
- **Otherwise**: a **Read receipt** button on the file's row (`_PendingDocumentRow`), for a file
  that is a JPEG / PNG / GIF / WebP / HEIC / PDF by its first bytes (`ReceiptScanner.isReadable`;
  HEIC not on Windows, which needs the Store's HEIF/HEVC extensions). Hidden once that file was
  read; back after Undo. Sized from the row's own width: the file size gives way below 420 px,
  and below 340 px the button is an icon with a `read_receipt` tooltip.
- **Never** on an existing expense (out of scope), and nowhere without an engine.

The strip (`ReceiptReadBanner`, state `ReceiptBannerState`) sits in the edit scaffold's banner
slot (`bannerBuilder`): reading (Cancel); filled (the values as the read left them, not the live
draft — the matched vendor's own name, the month as a word via `Formatter.dateWithMonthName` so a
swapped day and month shows, amount and date each in `LtrText`; Undo, Hide); a vendor-only read
("On receipt: <name>"; Hide); or failed (Hide). A new read replaces the previous strip; a failure
wins over an older fill. Undo and Hide are disabled while a save runs. Hidden on a phone while
the keyboard is up — read from the window (`View.of(context).viewInsets`), because the Scaffold
strips the keyboard from its body's MediaQuery, and rebuilt on `didChangeMetrics`. It never moves
focus, scrolls or opens the keyboard.

**Announced once per state of each read** (keyed on `receiptReadId`), from a listener on the view
model rather than the build — so a strip hidden behind the keyboard still tells a screen reader
the read finished — and with no `liveRegion`, which would speak it again on every rebuild.

## Engines, per platform

One channel, `invoice_ninja/receipt_ocr`: `isAvailable` → bool; `recognize {path?, bytes?}` →
`[{text, x, y, w, h}]`, normalised, top-left origin; errors carry a code only (`no_language`,
`unsupported_image`, `failed`) — **never recognised text, which is personal data, and nothing
logs it**. `ChannelReceiptTextRecognizer` latches "unsupported" on a `MissingPluginException`,
`unavailable` or `no_language`.

| Platform | Engine | Where | Notes |
|---|---|---|---|
| iOS | Vision `VNRecognizeTextRequest` (accurate) | `AppDelegate.swift` `ReceiptOcr` | languages auto-detected on 16+; on 15 the device's matched to `supportedRecognitionLanguages()` by language (`fr-CA` → `fr-FR`), Chinese by script, English last, and a refused list retried in `en-US`. iOS 15 has no Japanese/Korean/Russian |
| macOS | the same Vision code | `MainFlutterWindow.swift` `NinjaReceiptOcr` | auto-detect on 13+, the same matching on 12 |
| Android | ML Kit `text-recognition` 16.0.1, bundled | `packages/store_services/android` `ReceiptOcrPlugin` | Latin script only; ~7–11 MB of native code per ABI; its `.so` is 16 KB-aligned on the 64-bit ABIs (`0x4000`, checked with `llvm-readelf -l`) |
| Windows | `Windows.Media.Ocr` via WRL | `windows/runner/receipt_ocr.cpp` | the user's OCR language packs; none → `no_language` |
| Linux, web, F-Droid | none | — | the feature hides itself |

- **Orientation and size.** Apple: `CGImageSourceCreateThumbnailAtIndex` with
  `…WithTransform` applies EXIF orientation and downsamples to 3000 px in one step. Android:
  `ExifInterface.rotationDegrees` into `InputImage.fromBitmap`, decoded with `inSampleSize`.
  Windows: `GetSoftwareBitmapTransformedAsync(RespectExifOrientation)`, scaled to the smaller of
  `OcrEngine.MaxImageDimension` and 3000. A 48 MP photo decoded whole is ~190 MB. Apple decodes
  the primary image (`CGImageSourceGetPrimaryImageIndex`), not index 0, which in a HEIC can be a
  thumbnail.
- **Threads.** Apple: a background queue, each job in an `autoreleasepool`, replies on main.
  Android: one executor thread, which alone touches the recognizer (closed on it at detach); any
  `Throwable`, OOM included, replies `failed`. Windows: no C++/WinRT — the runner builds without
  exceptions (`_HAS_EXCEPTIONS=0`) and C++/WinRT throws — so the raw ABI through WRL, on one MTA
  worker waiting on each async op in 100 ms slices that notice shutdown and cancel; the handler's
  state is shared, not on the waiter's stack. Replies are posted back to the window with a
  registered message (`ReceiptOcr::DoneMessage()`) and sent on the platform thread; the destructor
  joins the worker before the window goes.
- **Paths, not bytes**, for a file on disk (no 25 MB copy over the channel); bytes for a
  rasterised PDF page or a web/test bytes source.
- **PDF**: `Printing.raster` at 200 dpi — the first page and the last of the first 20, only
  those two encoded to PNG — vendor and date from the first page, total and its taxes from the
  last page with a sure total, else the last with any (`ReceiptScanner._merge`), so a guessed
  largest amount on a terms page never beats a labelled TOTAL.

## The parser rebuilds rows before it reads anything

No engine returns "TOTAL" and its amount together: Vision returns them as separate observations,
ML Kit groups text by column. `rebuildRows` groups fragments by vertical centre into printed rows,
left to right; every rule matches rows. The fixtures under `test/fixtures/receipts/vision/` are
receipts rendered and read by Vision on macOS (`receipt_parser_test.dart` loads them all), so they
carry real engine output, slanted pages included — not hand-typed lines. Captured with a
throwaway Swift script (render with AppKit, `VNRecognizeTextRequest`, dump top-left boxes); add
ML Kit and Windows captures under their own engine folders when a device is at hand.

Rules worth knowing before changing one:

- **Amounts** are read with the currency's `precision` (0 JPY, 3 KWD/BHD/OMR): the last `.`/`,`
  followed by exactly that many digits is the decimal point. `1.234` is 1234 at 2 and 1.234 at 3.
  Space, NBSP and `'` grouping, refunds (`-` either side), zeros ignored.
- **Total**: the last row with a total keyword (many languages) and no exclusion (SUBTOTAL, NET,
  TOTAL HT, excl., savings, discount, CHANGE, CASH, TIP…); an amount a row lower is taken only from
  a row that is just a number. Fallback: the largest decimal amount in the lower 60 % that isn't
  excluded — marked to check. An empty TIP line marks the total to check.
- **Date**: the company's order decides `03/04`; a €/£ receipt hints day-first on an `mdy`
  company; still ambiguous → check. Month names come from a small hand-held table (11 languages),
  not `intl`'s locale data; exact names and common abbreviations are checked before prefixes, so
  English `Mar` is March, not Finnish `marraskuu`. `15-Mar-2026` and `15MAR26` read too. Within 2 years back and 1 day ahead. A row with a DATE keyword wins.
- **Tax** rows: rate and amount; an amount equal to or above the total is the total again
  ("Total incl. VAT"); `VAT No`/`USt-IdNr` rows without a `%` are identifiers. CGST and SGST at
  the same rate are two taxes.
- **Vendor**: the first of the top six rows with letters that isn't boilerplate, a phone, a URL,
  an address or a date; processor prefixes (`SQ *`, `TST*`) and store numbers dropped; an
  all-caps line title-cased, dotted abbreviations (`S.A.`) kept.

## ML Kit lives only in `packages/store_services/android`, which `prepare_foss.sh` removes before F-Droid's scan

ML Kit is Google's proprietary SDK, so it stays out of the F-Droid build entirely — and being a
Gradle artifact, not a pub package, none of the pub-level boundary checks can see it:

- It is declared in `packages/store_services/android/build.gradle` and nowhere else (the
  store package became an Android-only plugin; its Dart API is unchanged — the app reaches the
  plugin over the shared `invoice_ninja/receipt_ocr` channel). The FOSS twin is no plugin, so the
  F-Droid build gets a `MissingPluginException` and hides reading.
- `prepare_foss.sh` deletes that `android/` folder once the twin is in place (step 4) — F-Droid's
  scanner reads every `build.gradle` in the tree, built or not — and its `--restore` snapshot
  carries the folder back, uncommitted edits included.
- CI's FOSS classpath grep names `com.google.mlkit` and `com.google.android.datatransport`, and a
  step fails if the folder survived prepare. `store_sdk_boundary_test` fails ML Kit in any other
  `build.gradle*`, an `android/` in the twin, or a prepare script that stops deleting or
  snapshotting it. Details: `docs/fdroid.md` § What is non-free, and why.

## Privacy

All on the device; nothing is sent anywhere by the app. ML Kit's bundled model reports usage
through Google's `datatransport`, which merges `INTERNET` and `ACCESS_NETWORK_STATE` into the
manifest and starts `MlKitInitProvider` at launch — the Play Data safety form and the privacy
policy must say so.
Photos keep their EXIF metadata (`docs/sharing-files-into-the-app.md`).
