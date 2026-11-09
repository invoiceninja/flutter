# Review prompt

Companion to CLAUDE.md § Strict rules. How the app asks for a store review: which builds ask
through the OS sheet and which through the app's own card, the beta gate, what counts as a win
and a moment, the cadence, and the launch checklist. Code: `lib/domain/review_prompt.dart` (the
pure rules), `lib/app/review_prompt_controller.dart` (the schedule),
`lib/ui/features/review_prompt/` (the host, the card, the listing link),
`packages/store_services/lib/src/store_review.dart` (the plugin).

## Nothing asks for a review while kAppIsBeta; a store build asks only through the native API — no question first, never from a button; our card runs only on non-store builds and offers the review link to every answer; an automatic ask needs a server-confirmed finishing win at a quiet moment

Four rules, each from a policy or a measured failure mode:

- **Beta.** `kAppIsBeta` (`lib/app/version.dart`) is `true` until the first GA release. While it
  is, every review surface is inert — no automatic ask, no About button, no palette entry —
  because there is no public listing to send anyone to: iOS and macOS are TestFlight, where
  `requestReview()` does nothing (Apple's documentation), and a Play review from a testing track
  is private feedback with Submit disabled. The counters still run during the beta, so a beta
  tester is eligible soon after GA. The flag is compile-time, so an installed beta build never
  asks — intended.
- **Store builds: the OS sheet only.** Google Play's In-App Review policy forbids any question
  before the review card ("Do you like the app?") and calling it from a call-to-action button;
  Apple's guideline 5.6.1 says to use the provided API and discourages custom review prompts.
  Neither OS reports whether a sheet appeared (Apple shows it at most 3 times in 365 days, Google
  rations it with a hidden quota). So iOS, macOS and the Play build never show the card — the
  channel is chosen from `StoreReview.isStoreBuild`, a const, not from `isAvailable()`, because
  a Play build on a phone without Play Services is still a Play build.
- **Everywhere else: the card, and no review gating.** Windows (the plugin has no Windows code),
  Linux, the web and F-Droid show our card. It asks "Are you enjoying the app?", but **both
  answers can reach the review page**: "Not really" adds Send feedback *beside* Leave a review
  rather than replacing it. Sending only happy users to a review site is review gating, which
  Gartner Digital Markets' (Capterra's) vendor guidelines forbid and the FTC treats as deceptive.
- **A moment.** An automatic ask follows a change the server confirmed (§ Wins), never a toast —
  the success toasts fire when a change is queued, not when it lands.

## Channels

| Build | `ReviewChannel` | What asks | Review page |
|---|---|---|---|
| iOS, macOS (store) | `appleStore` | StoreKit's sheet | `https://apps.apple.com/app/id<kAppStoreId>?action=write-review` (hidden until `kAppStoreId` is set) |
| Android (Play) | `playStore` | Play's In-App Review | `https://play.google.com/store/apps/details?id=com.invoiceninja.admin` |
| Android (F-Droid twin) | `capterra` | the card | Capterra |
| Windows | `microsoftStore` | the card | `ms-windows-store://review/?ProductId=9NG93WNXN797`, falling back to `https://apps.microsoft.com/detail/9NG93WNXN797` |
| Linux, web | `capterra` | the card | `https://www.capterra.com/p/145215/Invoice-Ninja` |
| Demo build / demo mode / demo session | `none` | nothing | none |

`9NG93WNXN797` is the Microsoft **Store ID**, not the Partner Center product id (`docs/setup.md`).
The manual links are built in `lib/` (`reviewListingUri`) rather than through the plugin's
`openStoreListing`: they are the same URLs, but this way they work in the F-Droid build (no
plugin), the Windows link gets an https fallback (the plugin's Windows path returns silently when
`canLaunch` fails), and `ms-windows-store:` goes through `launchExternalUri` because
`openExternalUrl`'s `isSafeWebUrl` gate refuses any non-http(s) scheme.

## What the plugin does

Read from `in_app_review` 2.0.10's README and source:

- `isAvailable()` / `requestReview()`: Android, iOS, macOS — no Windows, Linux or web code
  (`isAvailable` is false on web).
- iOS `requestReview` returns `nil` whatever happens, including when no `UIWindowScene` is found.
  Android returns success once `launchReviewFlow` completes, sheet or not, and errors only when
  `requestReviewFlow` fails ("In-App Review API unavailable"). macOS 13+ errors
  `no-view-controller` when there is no main window. `StoreReview.requestReview()` turns each
  error into `false` — **true means the OS was asked, not that a sheet showed** — and an ask is
  recorded only on true.
- Android's `isAvailable()` checks for the Play Store and Play Services, then fetches and caches a
  `ReviewInfo`, so the host calls `StoreReview.prepare()` when a win arms and the sheet opens
  without a round trip a few seconds later.
- 2.0.10 ships the iOS / macOS privacy manifests and Swift Package Manager support, and Play Review
  2.0.2 (`com.google.android.play:review` + `play-services-base`, both non-free — the reason it
  lives in `packages/store_services`, `docs/fdroid.md`).

## Wins

`classifyReviewWin` (`lib/domain/review_prompt.dart`) sorts a confirmed change into three:

- **arms** — a finishing action, after which asking is fine: `email_entity`, `send_e_invoice`,
  `mark_sent`, `mark_paid`, `apply_payment`, `auto_bill`; a payment or expense `create` (a receipt
  filed is done); a create / update whose `__save_query` carries `paid`, `mark_paid` or
  `mark_sent` (the edit screen's Mark Paid / Mark Sent ride on the save).
- **counts** — real work, but the user's next step is usually Email or Download, so it is no
  moment: a create of invoice / quote / credit / recurring invoice / purchase order / task;
  `convert_to_invoice`, `approve`, `schedule_email`; a recurring invoice's bulk `start`; a save
  query with `approve`, `convert`, `auto_bill`, `send_now` or `start` (recurring Send Now and
  Start ride the save); and **any task save** — a task's timer starts and stops by saving the
  task (`TaskRepository.startTimer` / `stopRunningTimer`), so for a user who only tracks time
  that is the only win there is. Stopping a recurring invoice is not a win.
- **none** — everything else, and anything with a `cancel` in its save query.

The signal is `SyncRepository.landed`, emitted where a delivered row is deleted: `_attempt`'s
success and `_settleCommitted` (marked `committedSettle`, which counts but never arms — that path
also covers a client-too-old reply and a company switch). Never on orphan recovery at launch, the
Check / Resend deletes, an unresolved create, or a dispatch that throws. It is its own stream, not
a `SyncEvent`, so the exhaustive switches over `SyncEvent` don't change.

**Bursts collapse.** `wins` goes up only when the last win was more than 5 minutes ago, so a bulk
email of 20 invoices is one win; `winDays` (distinct days with a win) must reach 2, so one busy
afternoon can't meet the threshold. **Only a fresh row arms**: one queued more than 10 minutes
before it landed is an offline edit arriving after a reconnect, not something the user just did.

## Gates

`ReviewPromptController.isEligibleAt` + `isDue`, all of them:

| Gate | Value |
|---|---|
| Out of beta, and the GA build has run | `!kAppIsBeta`, `gaFirstSeenAt` ≥ 3 days ago |
| Install age | `firstSeenAt` ≥ 7 days ago |
| Days of use | `daysSeen` ≥ 5 (a session, every resume, every win records the day) |
| Wins | `wins` ≥ 3 bursts over `winDays` ≥ 2 |
| Moment | an arming win ≤ 60 s ago |
| No recent problem | none for 3 days — a `DeadEvent` / `UnconfirmedEvent` the user wasn't shown in its own form (`handledByCaller` false), or a `ConflictEvent` |
| Nothing waiting | no dead / unconfirmed outbox rows, online |
| No other prompt | What's New not holding prompts back (a day after it opens), the promo not shown in the last 7 days, no other automatic dialog this launch (`AutomaticDialogs`) |
| Schedule | `now ≥ nextAt`, a version newer than `newerThan`, not `done` |

The days are counted on every resume, not just on a session: the promo counts only on a session
change, which undercounts a phone app that sits suspended for days. A 422 does not hold asks for
days — the user usually fixed it inline — but the dead row it leaves blocks every ask until it is
cleared. **There is no plan or trial gate**: `PlanExpiredFooter.shows` is true for every hosted
owner whose trial ended and who stayed on Free, which would have shut out much of hosted.

Once due, the host (`ReviewPromptHost`, inside the shell so never over `/login`, `/lock` or
`/setup`) waits 2 s for the success toast, then checks every 3 s until the outbox has been empty
on two checks running (a bulk send is still draining), the app is unlocked, and
`QuietMomentCheck` says nothing is going on — no input since the last check, no dialog or field
in front, no unsaved form, not on an edit / new / email / settings screen. The Send Email screen
pops as the email is queued, so an email win lands on a resting screen.

## Cadence

**The first-run Welcome holds it too.** `promoShownRecently` also asks `WelcomeController.holdsBackPromptsAt` — despite its name, any recent automatic prompt — so no review is asked while a Welcome may open or within a week of it (docs/first-run-welcome.md).

- **Native**: an ask sets `nextAt = +120 days` and `newerThan = this version`, and at most 3 asks
  in any 365 days — Apple's own cap, kept as ours since neither OS says what happened. A re-ask
  therefore always comes on an update launch, where What's New opens and holds prompts back a
  day: the first re-ask lands about a day after an update. That's by design.
- **Card** (`cardShows` counts automatic opens, at most 3, recorded as it opens):
  - closed at the first question → 30 days, then 90, then done;
  - closed after Yes → 90 days;
  - closed after Not really, or Send feedback → 180 days and a newer version — someone who
    said they're unhappy is never asked "Are you enjoying the app?" a month later;
  - Leave a review that opened → done. One that failed to open keeps the card up (the standard
    "Couldn't open the link" toast says why) and records nothing.
- **Manual** (About, the command palette): a static link, no schedule; one that opened sets
  `done`.
- **The promo and the review prompt hold each other back for 7 days** (`holdsBackPromptsAt` on
  each, wired in `Services.build`).

## The card

`review_prompt_dialog.dart`, copying the promo dialog's patterns:

- `barrierDismissible: false` — a stray click beside it is not an answer — and a ✕ that is
  **autofocused and stays mounted across the steps**, so Esc always reaches the card's own
  `DismissIntent` (the route's handler is off whenever the barrier isn't dismissible) and Enter
  on it is harmless. On a step change focus moves back to the ✕; a step's buttons were just
  replaced.
- Every button is ignored for 500 ms after the card opens **and after each step change** — the
  next step's primary sits where Yes was, so a double tap would otherwise open the store.
- Two equal halves whose labels may wrap to two lines, centred — side by side at any text size
  (`review_prompt_dialog_test` pins 320 dp at 1.4×, LTR and RTL). The primary is a plain
  `FilledButton`, not `PrimaryDialogAction`: its autofocus and Enter hint are exactly what this
  card must not have.
- The question is a level-1 heading and a live region, so a screen reader hears each step.
- "Opens Capterra" / "Opens Microsoft Store" under the question says where the button goes.
- Leave a review calls the launcher first, inside the tap — a browser's popup blocker drops a
  tab opened after an await — then thanks the user with a toast.
- Send feedback closes the card and the host opens Contact Us from its own context, with the
  card's "What could we do better?" as the intro line (`showContactUsDialog(intro:)`), so the
  two never stack.
- The strings are app-local (`_app_pending.json`), not the upstream `sure_happy_to` /
  `no_not_now` / `review_app` / `would_you_rate_it`: their translations are broken (es_ES's
  `no_not_now` reads "Claro, encantado de", the same as `sure_happy_to`; `sure_happy_to` is cut
  mid-phrase in fr / es / pt_BR / ar; `review_app` reads "examine the app"), and the pending file
  can't override them.

## GA launch checklist

1. Set `kAppStoreId` in `lib/domain/review_prompt.dart` (App Store Connect → General → App
   Information → Apple ID). Confirm iOS and macOS are one App Store record — they share
   `com.invoiceninja.admin`.
2. Confirm the Play listing is the production one, and replace `kCapterraReviewUrl` with
   Capterra's direct write-a-review link from the vendor portal if there is one.
3. Confirm the Microsoft Store listing is public and reviewable — today it is a restricted listing
   (`docs/setup.md`), and every Windows "Leave a review" would land on a page the public can't
   see.
4. Flip `kAppIsBeta` to `false` in the same release that swaps the promo's TestFlight and testing
   links (`docs/mobile-app-promo.md` § Swap the links at launch).
5. Expect the first automatic asks at least 3 days after that build installs, and only at a win.
   Most active users should be asked within one to three months; monthly invoicers come last,
   because a month-end burst is one win.

`IN_REVIEW_PROMPT=false` (`kReviewPromptEnabled`) builds without the prompt, separately from the
beta flag.

## Testing it

- **Debug Panel** (About → Debug Panel): ☆ Force review prompt asks now, skipping every gate and
  recording nothing; ↺ Reset review schedule starts the schedule over. On a store build Force is
  offered only in a debug build — the panel ships in release, and a button that calls the OS
  sheet is what Play forbids.
- **iOS**: the simulator or a device shows the sheet with Submit disabled; TestFlight shows
  nothing. The About link needs a physical device (the simulator has no App Store).
- **macOS**: run locally; Force shows the sheet. With no focused main window the request returns
  false and nothing is recorded.
- **Android**: only a Play-installed build — internal app sharing or an internal test track, the
  primary Gmail account (not an enterprise one), the app in that account's library, no existing
  review. An emulator or sideloaded build shows nothing; that is expected.
- **Windows / web / Linux**: both branches of the card.

## Known limits

- The schedule is a device preference (`review_prompt_json`, `PrefScope.device`): a user is asked
  once per device or browser, and on a shared machine the next user inherits `done`.
- An unresolved dead or unconfirmed outbox row holds every ask until it is cleared.
- A GA build still running from TestFlight records native asks that never showed — harmless,
  since a TestFlight user can't review.
- Not yet: a client's payment arriving through the `/refresh` delta (the happiest moment for an
  invoicing user) doesn't count — it needs a "new payment, not from our outbox" hook in the
  payment repository's delta apply.
