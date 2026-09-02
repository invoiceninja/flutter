# Tap to call — dialling a phone number from the app

Settings → Device Settings → **Phone numbers**. Tapping a phone number opens the platform dialer;
contact rows also get a Message button, and a billing document's header offers a call button beside
the client's name. Device-local, with two optional guards. From
[invoiceninja/flutter#109](https://github.com/invoiceninja/flutter/issues/109), where field workers
were copy-pasting numbers into the phone app, extended by
[#110](https://github.com/invoiceninja/flutter/issues/110).

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
PartyCallButton / PhoneCallButton    the billing-doc header glyph + picker   lib/ui/core/widgets/party_call_button.dart
  └─ clientPhoneCandidates()         which numbers, in what order            lib/domain/phone/phone_candidates.dart
```

## Where it applies

Detail screens and contact cards: client detail (its own phone + every contact), vendor detail
(same), a team member's User Details row, and — from
[#110](https://github.com/invoiceninja/flutter/issues/110) — the header of every billing-doc detail
screen (see below).

**Not list table cells.** A phone cell that dials would swallow the row tap that opens the record —
on a phone, exactly the mis-tap the issue was worried about. Numbers in a list stay inert text with
the usual hover-copy.

Three surfaces are deliberately left out:

- **A "Call" entity action** in the row / detail actions menu. #110 built the picker this was
  waiting on, so it is now only a wiring job (per-entity `EntityActionItem`, `guardedOnTap`, keys) —
  but it is still not built.
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

## The preference

Five fields in one JSON blob, `nav_state.phone_actions_json` (schema v7).

| Field | Default | Why |
|---|---|---|
| `tapToCall` | `Env.isTouchPrimary` | see below. Gates the call link **and** the Call / Message buttons, checked both where they're drawn and again at fire time. Deliberately **not** the local-time suffix, which is contact context rather than part of the calling flow — so "off" is not quite the pre-#109 rendering. |
| `confirmBeforeCall` | off | the OS already confirms |
| `warnOutsideBusinessHours` | on | the only guard the OS can't give you |
| `startMinutes` / `endMinutes` | 08:00 / 20:00 | generous — it exists to catch a 2 a.m. mis-tap, not to police a working day |

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
- **`Localization.lookup` substitutes the longest placeholder name first.** `contact_local_time` is
  `":time in :timezone"`, and in map-insertion order `:time` rewrites the second token to
  `"<value>zone"`, which then never matches — rendered garbage that no `tr()` lint catches. Five
  bundled keys have the same shape (`activity_10`/`_39`/`_40`/`_41`, `entity_number_placeholder`);
  the activity templates dodge it only because they tokenize with a regex instead.
