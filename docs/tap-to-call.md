# Tap to call — dialling a phone number from the app

Settings → Device Settings → **Phone numbers**. Tapping a phone number opens the platform dialer;
contact rows also get a Message button, a billing document's header offers a call button beside the
client's name, and on a phone a Clients / Vendors row with a number stored carries one too. Device-local, with two
optional guards. From
[invoiceninja/flutter#109](https://github.com/invoiceninja/flutter/issues/109), where field workers
were copy-pasting numbers into the phone app, extended by
[#110](https://github.com/invoiceninja/flutter/issues/110) and
[#111](https://github.com/invoiceninja/flutter/issues/111).

## The shape

```
PhoneActionsController          device-local prefs (ChangeNotifier)   lib/app/
  └─ PhoneActionsSettings       value + JSON codec + window math      lib/domain/phone/
callPhoneNumber()               guards, then launch                   lib/ui/core/utils/phone_actions.dart
  ├─ SettingsRepository.resolved()   client → company timezone_id
  ├─ StaticsRepository.timezone()    id → IANA name + utc_offset
  ├─ showConfirmActionDialog()       the one prompt
  └─ launchExternalUri(Uri)          tel: / sms:
PhoneDetailRow / PhoneNumberValue / ContactLocalTime   lib/ui/core/widgets/phone_number_value.dart
PartyCallButton / PhoneCallButton    the glyph + picker                      lib/ui/core/widgets/party_call_button.dart
  ├─ PhoneCallButtonVariant          .inline (detail header) / .listRow
  └─ clientPhoneCandidates()         which numbers, in what order            lib/domain/phone/phone_candidates.dart
ClientListTile._callButton / VendorListTile._callButton   callers, not children: the narrow list row
```

## Where it applies

Detail screens and contact cards: client detail (its own phone + every contact), vendor detail
(same), a team member's User Details row, and — from
[#110](https://github.com/invoiceninja/flutter/issues/110) — the header of every billing-doc detail
screen (see below). From [#111](https://github.com/invoiceninja/flutter/issues/111), also the
**narrow Clients and Vendors list rows** (see below).

**Still not list table *cells*.** A phone cell whose *text* dials would swallow the row tap that
opens the record — on a phone, exactly the mis-tap #109 was worried about — so numbers in a list
stay inert text with the usual hover-copy. That rule is about the cell, not about the row: the call
button #111 added is a discrete icon with its own hit target in the row's trailing action cluster,
and the row tap is only suppressed inside that box — 44 px on touch, 32 with a pointer — which is
the point of it.

Three surfaces are deliberately left out:

- **A "Call" entity action** in the row / detail actions menu. #110 built the picker this was
  waiting on, so it is now only a wiring job (per-entity `EntityActionItem`, `guardedOnTap`, keys) —
  but it is still not built. It is also the only thing that would reach the **wide** list table,
  which #111 deliberately did not (see below).
- **`payment_detail_header.dart`**, which also names a client. It goes through the shared
  `EntityDetailHeaderHost` rather than a bespoke `_Header`, so it is a different edit; a field
  worker on a payment has the same problem.
- **The billing-doc Contacts tab** (invoice / quote / PO) renders name + email only:
  `BillingContact` (`lib/data/models/domain/billing/billing_contact.dart`) carries no phone field,
  so there is no number there to link.

## The billing-doc header button (#110)

`PartyCallButton` / `PhoneCallButton` (`lib/ui/core/widgets/party_call_button.dart`) put a discrete
phone glyph beside the client (or vendor) name on the Invoice / Quote / Credit / Recurring-invoice /
Purchase-order detail headers, so a call doesn't cost a trip to the client screen.

**One tap for a single number; a picker otherwise** — and the picker is the *main* path, not the
edge case: a client with an office line and one contact mobile already has two candidates. Don't
describe the feature as "one-tap dial".

`clientPhoneCandidates` / `vendorPhoneCandidates` (`lib/domain/phone/phone_candidates.dart`) build
the list: **primary contact, then the remaining contacts in declaration order, then the party's own
top-level `phone`**, dropping deleted contacts and anything `cleanPhoneNumber` refuses, deduped on
the normalised form (a client whose office line is repeated on its primary contact is the common
case). It is deliberately **not** ordered by the document's `invitations` — an invitation is an
email-delivery fact, and primary-first is both more predictable and stable from one document to the
next. A "was sent this document" *marker* on the matching picker rows is the one thing this surface
knows that the client screen doesn't, and is the obvious next increment.

Six things here are load-bearing, and most of them fail silently:

- **The trigger's box is `actionButtonSize()` wide and only as tall as the name row's line box**
  (20 px), never the 44 px touch floor. That is CLAUDE.md's touch-target **trap 4** — *cap trailing
  widgets to the row's content box, not the target* — and it is what keeps the affordance from
  pushing the dates + KPI strip down ~24 px on five screens, and from doing it *a frame or two late*
  once the party resolves from Drift. `party_call_button_test.dart`'s `layout` group pins the row
  height against a no-icon baseline at 1.0× and `kTextScaleMax`.
- **`Semantics` sits *inside* the `InkWell`, with no `excludeSemantics`.** That flag prunes all
  descendant semantics, and `InkWell` contributes its tap action as a descendant — wrapping from
  outside yields a node a screen reader announces and cannot activate. (`PhoneNumberValue` still has
  this shape; its test only asserts the label.)
- **The picker returns a candidate; the caller dials afterwards.** `callPhoneNumber` re-checks
  `context.mounted` only *after* awaiting the timezone cascade, so dialling from the picker's own
  mid-pop context is a race against the exit animation that silently drops the call **and** its
  confirm dialog. The button dials with its own context.
- **The picker re-provides `Services`.** It is a route, so its subtree hangs off a `Navigator` that
  may sit above the caller's `Provider<Services>`; `ContactLocalTime` reads it.
- **The local-time line is omitted on the vendor picker.** With a null `clientId` the cascade
  resolves the *company's* zone — a fair per-number fallback, but a false claim about the vendor's
  local time once hoisted under "Call Acme Supplies", which is exactly the confident lie this
  feature refuses to tell.
- **A bottom sheet on touch, a centered dialog with a pointer** — the split
  `showLineItemPickerSheet` already makes. `showModalBottomSheet` defaults to
  `useRootNavigator: false`, so on a wide layout it mounts on the master-detail pane's nested
  navigator and would be a full-width slab pinned to the bottom of a ~500 px column.

Smaller, but deliberate: the gap between the name and the glyph lives *inside* the button so it
vanishes with it, and it exists because the name is a `LinkText` whose `GestureDetector` is
`HitTestBehavior.opaque` — two adjacent targets that do opposite things (dial vs. navigate away).
Long-press copies on touch and right-click copies with a pointer, because on desktop the detail body
sits in a `SelectionArea` and the tooltip already claims long-press. The glyph grows a `▾` when
there is more than one number, so one icon never hides two behaviours. And the picker's footer links
to the party's own screen — the only way a user can tell "no number stored" from "a number
`cleanPhoneNumber` refused".

## The list-row button (#111)

Every **narrow** Clients and Vendors row with a dialable number carries the same trigger in its
trailing action cluster — after the money column and the status pill, immediately before the `…`
menu — so a call costs one tap from the list instead of a trip into the record to hunt for a
number. `ClientListTile._callButton` / `VendorListTile._callButton` build it
straight from the `Client` / `Vendor` the row already holds, so there is no `PartyCallButton` and no
second Drift watch per row.

`PhoneCallButtonVariant.listRow` is the whole difference, and each of its four deltas is the mirror
image of a header constraint that doesn't apply in a row:

- **A square `actionButtonSize()` box, not the header's 20 px.** Trap 4 says reclaim the target on
  the axis that has room; in a header that axis is horizontal, in a list row it is *vertical* — the
  row is floored at `kEntityListRowHeight` (72) and the sibling `…` is already `actionButtonSize()`
  tall, so 44 px adds no height at all.
- **A centred glyph**, because the `…` next to it is a centred `IconButton`.
- **20/18 px icons in `ink2`.** That `…` is an M3 `IconButton`: 24 px in `onSurfaceVariant`, which
  `theme.dart` maps to `ink2`. At the inline 16 px `ink3` the call glyph read as a faint
  afterthought beside it.
- **No secondary gesture.** The row owns long-press — it enters multi-select — and a copy toast
  where the user expected selection is the wrong trade. With no child `LongPressGestureRecognizer`
  the gesture falls straight through to the row; `client_list_tile_test.dart` pins that.

Four more things are load-bearing:

- **The caret fits *inside* the target rather than widening it.** A 44 px box already holds 20 + 18,
  and in a list row an extra 12 px comes straight out of the client's name — enough that the fullest
  possible row overflowed by 7.2 px at 500 px / 1.4× text before this was fixed. The `math.max`
  against the glyph pair is for the pointer case, where the target is only 32 and the glyphs really
  do need more.
- **A row with no dialable number mounts nothing** — not even the `PhoneActionsScope`
  `ListenableBuilder` inside the button. The candidate walk therefore runs *before* any preference
  check: it is a short walk over data the row already holds, while a listener per row is the heavier
  of the two. A row that *does* have a number keeps its scope even with `tapToCall` off, so flipping
  the switch brings the icons back in place.
- **It hides in multi-select**, exactly as the `…` menu does. The row's tap means "toggle" there and
  a dial target inside it is a mis-tap magnet.
- **`onViewRecord` comes from the screen, not the tile.** The picker's "View client" footer has to
  navigate to the record unconditionally — unlike the row's own `onTap`, which toggles selection in
  multi-select and *closes* the pane when the row is already URL-selected. It lives on the screen
  because `goEntityRecord` needs a `GoRouter`, and the tile is the one piece of this that stays
  pumpable without one.

**Only the narrow row, and that is a real gap worth knowing.** A trailing slot in the wide data
table would have to be mirrored into the shared `EntityListColumnHeaders` strip and
`computeTableMinWidth`, which every entity reads — a framework change to serve one entity. Since
`Breakpoints.isWide` is 600 px of *pane* width, that means a **phone in landscape** and every tablet
get the wide table and no button. `tapToCall` defaults off on desktop, so the pointer audience is
small either way; the "Call" entity action above is the thing that would close this properly.

**What it costs the row.** Exactly 52 px off the identity column (the button plus its leading
`InSpacing.sm`). Measured at 390 px in a throwaway golden with the bundled TTFs
loaded through a `FontLoader`, since the substituted test font is useless for this: a name that had
177 px keeps 125, and one on a row that also shows a status pill drops from 96 px to 44. The pill is the visibly tight
case, and it is also the rare one: the Clients list filters to active records by default, so
`Deleted` / `Archived` only appear behind a status filter and `Unsynced` only with a queued offline
edit. Two consequences were weighed and accepted:

- **The money block's right edge jogs** by that 52 px between a row that has a number and one that
  doesn't. Putting the button *before* the money column would fix that and make the ☎ column ragged
  instead; the interactive columns are the ones a thumb needs to find in the same place every row,
  and the status pill already shifts money further than this. Reserving a fixed empty slot on
  numberless rows would hold both alignments but taxes every row of an account that stores no
  numbers — including the phone user, for whom `tapToCall` is on by default.
- **Overflow.** `client_list_tile_test.dart`'s `layout` group pins the fullest row the tile can
  build (status pill + `▾` + a balance wide enough to hit the narrow money cap) at the app's own
  responsive floor of 500 px, at 1.0× and `kTextScaleMax`. That case has teeth: before the caret was
  moved inside the target it overflowed there by 7.2 px at 1.4×.

  It does **not** pin that fixture at a handset width, for two reasons. `flutter test` substitutes a
  font whose every glyph is a full em square, so text measures far wider than it ever will on a
  device — a 10-character amount is 132.5 px under it against 80.5 px of the bundled JetBrains Mono
  the money column actually uses (`moneyTextStyle` → `kMonoFontFamily`; the identity column is Inter
  Tight, and neither is what the test process renders). And under that same substituted font a
  nine-figure balance overflows a 390 px row *without* the call button at all — 22 px at 1.0×, 53 px
  at 1.4× measured on the pre-#111 tile — so pinning it would assert a pre-existing limit rather
  than this change. The handset case uses an ordinary row instead.

## The preference

Six fields in one JSON blob, `nav_state.phone_actions_json` (schema v7).

| Field | Default | Why |
|---|---|---|
| `tapToCall` | `Env.isTouchPrimary` | see below. Gates the call link, the Call / Message buttons, the billing-doc header glyph **and** the list-row button, checked both where they're drawn and again at fire time. Deliberately **not** the local-time suffix, which is contact context rather than part of the calling flow — so "off" is not quite the pre-#109 rendering. |
| `confirmBeforeCall` | off | the OS already confirms |
| `warnOutsideBusinessHours` | on | the only guard the OS can't give you |
| `startMinutes` / `endMinutes` | 08:00 / 20:00 | generous — it exists to catch a 2 a.m. mis-tap, not to police a working day |
| `offerToLogCalls` | on | the post-call offer, below. Costs a dismissible toast and nothing else; the *platform* gate is separate |

The sixth field landed after schema v7 shipped and cost **no migration** — which is the blob paying
for itself a second time.

**The default is per-device, and that is the reason this is a blob rather than five typed columns.**
The app cannot ask whether a `tel:` handler exists — `canLaunchUrl` is banned by
`test/lint/no_can_launch_url_test.dart` because on Android 11+ it answers a package-visibility
question and lies — so on a Windows or Linux desktop with no dialer, an on-by-default link would
both stop the number selecting as text *and* report "Couldn't open the link" to someone who never
asked for the feature. A null column therefore means "ask this device"
(`PhoneActionsSettings.deviceDefaults()`); a SQL `withDefault` could only pick one answer for a
phone and a desktop alike. A *stored* blob is taken literally — the platform must never re-decide
for a user who has already chosen.

**Why `confirmBeforeCall` defaults off.** `tel:` is launched as `ACTION_VIEW`, so Android opens the
dialer *pre-filled* and the user still presses the call button, and iOS shows its own `Call …?`
alert. An in-app prompt on top of that is the double-prompt CLAUDE.md warns against under
§ Action confirmations. The switch exists because the issue asked for it.

## Logging a call (invoiceninja/flutter#120)

The other half of the loop #119 started: find the client to chase, ring them, write down what was
said. Two entry points, one form, and no new storage.

**Where a logged call lives.** Nowhere new. `POST /api/v1/activities/notes` writes an `Activity`
row with `activity_type_id = 141` (`Activity::USER_NOTE`), rendered from the already-translated
`activity_141` — *"User :user entered note: :notes"*. The app reaches it through the existing
`MutationKind.addComment` outbox path, so a call logged offline queues and syncs like anything
else and gets the optimistic "Syncing…" row for free. This is not a workaround: Invoice Ninja's own
Pancake importer stores imported phone-call logs the same way
(`app/Import/Pancake/DatabaseSource.php`, the `contact_log` branch), and `composeCallNote` mirrors
its shape.

**The form.** `showLogCallSheet` (`lib/ui/core/dialogs/log_call_sheet.dart`) — direction, date +
time, contact, duration, summary — resolves with the **composed note string**. Every entry point
goes through `promptLogCallFor` / `promptAddCommentFor`
(`lib/ui/core/detail/activity_note_actions.dart`), which own the `requireSynced` gate, the prompt
and the success/error toast; a caller supplies only its own `repo.addComment`. That is reachable
from the record's `⋯` menu on all ten comment-capable entities and from the
`Log call` / `Add comment` pair (`ActivityNoteButtons`) on nine Activity tabs — the same edit that
finally switched on `onAddComment`, which had shipped as a declared-but-never-passed parameter.
Task and Project mount the same tab and pass null for both: neither repository has an
`addComment`. `test/lint/call_note_wiring_test.dart` pins those call sites, because a dark button
is silent.

Routing everything through the two helpers is not tidiness. Before it, five billing `⋯` arms
awaited the repo bare — no success toast, no Retry — while the Activity tab on the same screen
toasted; three more used private helpers that skipped `requireSynced` entirely; and Vendor showed
two visibly different Add-comment dialogs depending on the entry point. There is now one
add-comment dialog (`clients/widgets/detail/add_comment_dialog.dart`); the near-identical
`billing_shared/actions/add_comment_prompt.dart` is gone.

**After a call.** `callPhoneNumber` takes an optional `logTarget` and, on a successful launch,
parks a `PendingCallLog` on `Services.pendingCall`. `CallLogPrompter` — mounted beside `ToastHost`
in `main.dart` — watches the app lifecycle and raises a dismissible toast with a `Log Call` action
when the user comes back. The billing-doc headers target their **document** rather than the party,
so the note also records which document the call was about; it still reaches the party's feed
either way, because the server stamps `client_id` (invoice / quote / credit / recurring invoice)
or `vendor_id` (purchase order — its `client_id` is null for an ordinary vendor-facing PO).

**What the marker is and is not.** The composed note starts with `📞`, and that is the only thing
separating a logged call from a typed comment — the wire carries no note subtype. It drives exactly
two things: the phone icon on the activity row, and the Calls lens on `/activity`. It is a display
hint, not a data model; nothing else may key off it, and the header is **never parsed back**.

## The out-of-hours warning

1. `SettingsRepository.resolved(companyId:, clientId:)` → `timezone_id`. A client's
   `settings.timezone_id` override wins over the company's; vendors and users have no cascade of
   their own and fall back to the company's.
2. `StaticsRepository.timezone(id)` → the IANA `name` and `utcOffset`.
3. `contactClock()` resolves that IANA name through the tzdb and returns the callee's wall clock
   (only its `hour` / `minute` mean anything) plus their *current* UTC offset.
4. `PhoneActionsSettings.isOutsideBusinessHours` decides.

**An unresolvable timezone skips the warning** rather than falling back to the caller's own clock.
"It's 11 PM for this contact" would be a confident lie for a client eight zones away, and a warning
people learn to dismiss is worse than none.

**One dialog, never two.** The quiet-hours state is resolved *before* anything is shown, so a user
with both guards on gets a single prompt whose copy varies — not a generic "Are you sure?" followed
by an out-of-hours one.

**DST — resolved through the IANA tzdb, not the server's offset.** `Timezone.utc_offset` is the
server's *standard-time* value (`ConstantsSeeder` seeds `America/New_York` as `-18000`) and encodes
no DST rule, so it is an hour wrong for a DST-observing zone for most of the year. That mattered
twice over and the two errors compounded rather than cancelled: the clock printed 14:30 when New
York read 15:30, **and** the "is this contact even in a different zone?" test compared it against
`DateTime.now().timeZoneOffset`, which *is* DST-aware — so a New York user saw a (wrong) suffix
beside every New York client for roughly eight months a year.

`contactClock()` (`lib/ui/core/utils/phone_actions.dart`) therefore resolves `Timezone.name` through
`package:timezone`, which `main.dart` initialises at boot, and returns both the wall clock and the
zone's *current* offset from the same source so the two can't disagree. `utcOffset` survives only as
the fallback for a name the tzdb doesn't know — degrade by an hour, never throw inside a build.
(`lib/domain/tasks/task_day.dart` still documents the older limitation for task-day bucketing; it
does not go through this path.)

## The local-time suffix

`ContactLocalTime` puts a dimmed clock next to a number — **only when the callee's current UTC
offset differs from this device's** (both DST-resolved; see above for why that qualifier is
load-bearing). That rule is what keeps it from being noise: an account whose clients
are all domestic never sees it, and an overseas one is warned *before* the tap rather than after.
The zone is resolved asynchronously and the widget renders nothing until it lands — deliberately
*not* seeded from `SettingsRepository`'s synchronous first-frame mirror, whose reach
`test/lint/peek_is_seed_only_test.dart` pins to the invoice lock banner (it exists so ~44px of
chrome can be sized on frame 1, and is allowed to be stale). Nothing moves when a trailing suffix
appears a frame late, so a stale answer would buy nothing here. A one-minute ticker, armed only
while something is actually shown, keeps a screen left open from displaying a stale clock.

`resolveContactTimezone` dedupes **in-flight** resolutions per `companyId/clientId`: a contacts card
mounts one of these per contact in a single frame and they all share a client, so a client with
eight contacts would otherwise run nine identical cascade walks, each a companies read plus a
query-stream subscribe/cancel. The entry is dropped as soon as the future completes, so it is a
burst dedupe and not a cache — `SettingsRepository.resolved` stays uncached, as its own doc requires.

## Things that will bite you

- **`cleanPhoneNumber` (`lib/utils/formatting.dart`) is where a wrong number comes from.** Four
  rules, each because breaking it dials *something*, just not the right thing: a `+` **before the
  first digit** survives (`(+1) 415…` and `Mobile: +44 …` are ordinary stored formats, so
  `startsWith('+')` is not the test); it cuts at an extension marker rather than inlining its digits
  (`555-1234 x22` must not dial `555123422`); it drops a bracketed trunk prefix after a country code
  (`+44 (0)20 …` → `+4420…`); and it discards anything under five digits, because a phone field
  holding `1-800-FLOWERS` or `Reception, dial 9 first` otherwise becomes a link that hands the
  dialer `tel:1800`.
- **`tel:` / `sms:` bypass `isSafeWebUrl` on purpose.** That predicate exists to stop a
  *server-supplied* URL becoming a `javascript:` / `file:` / `intent:` launch, and it rejects `tel:`
  by design. Here the scheme is a compile-time constant and the number is already normalised to
  `[+]?\d+`, so there is nothing to inject with — hence `launchExternalUri(Uri)` directly rather
  than `openExternalUrl(String)`.
- **Android needs `<queries>` entries** for `tel` and `sms` (`AndroidManifest.xml`), asserted by
  `test/lint/android_url_queries_test.dart`. `android.permission.CALL_PHONE` is declared in that
  manifest and is deliberately **not** used: it is for `ACTION_CALL`, which dials immediately with
  no user confirmation.
- **Every phone surface listens to the controller** via `PhoneActionsScope`. A detail screen stays
  mounted behind the `/settings/**` route while the switch is flipped, so a plain build-time read
  would leave it styling numbers with the old value until an unrelated rebuild.
- **A logged call's note is append-only and frozen at compose time.** The server exposes no `PUT`
  or `DELETE` for an activity and `activities` has no `deleted_at`, so whatever `composeCallNote`
  writes is permanent, in the author's locale and the company's date format of that moment, for
  every client that ever reads it. Get the string right the first time; do not parse it back
  (a contact name may contain the ` · ` separator).
- **Compose the time with `formatTimeOfDay`, never `Formatter.date(..., showTime: true)`.** That
  path assumes a *server UTC* string — it appends `Z` and calls `.toLocal()` — while the form holds
  a local wall clock. Passing one to the other shifts the printed time by the device's offset, and
  reads correct on CI (which runs in UTC) while being wrong on every developer machine.
- **A `SegmentedButton` clips its labels rather than overflowing.** It clamps each child to
  `maxWidth / childCount`, so a full-width box never throws — it silently truncates, and
  `Comments` is one unbreakable word that already exceeds its share on a 320 px sheet at
  `kTextScaleMax` (worse in de/fr). Wrap it in a horizontal `SingleChildScrollView`, as
  `debug_panel_section.dart` and `segmented_setting_row.dart` both do.
- **The direction control is a `SegmentedButton`, never a `RadioGroup`.** `RadioGroup` installs a
  `Shortcuts.manager` + `FocusTraversalGroup` and runs a post-frame single-selection check, which
  mutates the subtree mid-frame and crashes inside `showModalBottomSheet`'s size-listening layout —
  the reason `entity_sort_filter_sheet.dart` and `tax_category_dialog.dart` both hand-roll a
  selectable list. The design rule ("two choices stay visible") is about the affordance, not that
  widget. `log_call_sheet_test.dart` pins it in both presentations.
- **The contact field is a plain `TextField`, never a `SearchableDropdownField`.** That widget sets
  `TextInputType.none` for a list of six or fewer, so the soft keyboard never opens, and renders a
  *disabled* field when `items` is empty — between them they make it impossible to log a call to a
  number that isn't already on the record, which is the ordinary shape of an inbound call.
- **The post-call offer is gated on `Env.isMobile`, not `Env.isTouchPrimary`.** The latter includes
  a mobile *browser*, where `AppLifecycleState` follows page visibility and every tab switch would
  look like a finished call. Only `paused` / `detached` → `resumed` counts as a round trip, for the
  same reason `SyncLifecycleObserver` says so: iOS fires `inactive` for a notification-shade peek.
  And `launchExternalUri` returning `true` means the *intent started*, never that a call connected —
  which is why the copy reads "Log call" and never "Call completed".
- **`Localization.lookup` substitutes the longest placeholder name first.** `contact_local_time` is
  `":time in :timezone"`, and in map-insertion order `:time` rewrites the second token to
  `"<value>zone"`, which then never matches — rendered garbage that no `tr()` lint catches. Five
  bundled keys have the same shape (`activity_10`/`_39`/`_40`/`_41`, `entity_number_placeholder`);
  the activity templates dodge it only because they tokenize with a regex instead.
