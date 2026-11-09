# First-run welcome — the setup wizard, the dashboard checklist and the Welcome

Companion to CLAUDE.md § Strict rules. That section carries the rule; this doc carries who gets which first impression, how a first run is told apart from a restored session or an update, why the wizard writes once and in that order, how the checklist reads its ticks, and how the Welcome keeps the other automatic prompts away.

| Who | What they get |
|---|---|
| A brand-new sign-up (an admin of an unnamed company) | `/setup`: **Your business** → **Add your logo**, beside a live invoice preview, then the dashboard led by the **Start getting paid** checklist. No Welcome: the wizard is theirs. |
| An existing account, new to this app | The **Welcome** on **Get started**: how this app works (search, offline, other devices, make it yours). |
| An existing account from the previous Flutter app | The same Welcome on **What's changed**: "All your data is already here", three highlights, "Can't find something?". |

| Piece | File |
|---|---|
| Who is who — pure | `lib/domain/welcome.dart` (`decideWelcome`, `SignInFacts`, `welcomeUserKey`) |
| The Welcome's rows and the store filter | `lib/domain/welcome_content.dart` |
| The record, a device preference | `lib/app/welcome_controller.dart` (`DevicePrefKeys.welcome`) |
| The sign-in hook | `AuthRepository.onSigningIn`, wired by `main.dart` |
| The wizard | `lib/ui/features/auth/views/setup_wizard_screen.dart`, `view_models/setup_wizard_view_model.dart`, `widgets/setup_wizard/` |
| The checklist | `lib/domain/setup_checklist.dart`, `lib/ui/features/dashboard/view_models/setup_checklist_view_model.dart`, `widgets/setup_checklist_card.dart` |
| The Welcome and its opener | `lib/ui/features/welcome/welcome_dialog.dart`, `welcome_host.dart` (built by `SyncEventListener`) |
| Motion and haptics | docs/motion-and-haptics.md |

## The Welcome is decided once per user per device, at an interactive sign-in, from the login response

**At a sign-in, never at a restore.** `AuthRepository.onSigningIn` fires from `login`, `loginWithPasskey`, `oauthLogin` and `signup` — after `_wipeIfIdentityChanged`, before `_persistAndActivate`, so the shell mounts on a decision already made — and never from `restore`, `refresh` or `loginWithToken`. A session that came back by itself is not a first run.

**Wired by `main.dart`, never by `Services.build`.** The CI smoke test builds the real `Services` and signs in through the form; a hook assigned in `Services.build` would pop the Welcome over it. Only `main()` arms it, as only `main()` calls `WhatsNewController.noteLaunch`.

**The decision, in order** (`decideWelcome`, table-tested in `test/domain/welcome_test.dart`):

1. An email sign-up (`/signup`) is a **new account**. No Welcome; `/setup` and the checklist are its welcome. An OAuth sign-up is **not** taken as one even with `create`: the server logs an existing Google or Microsoft user in before it reads the flag (`LoginController::handleGoogleOauth`), so "Sign up with Google" by someone who already has an account would have been filed as new and never greeted. A truly new OAuth account lands on `/setup` with its one unnamed company, and finishing the wizard re-labels it (below).
2. A `company_user.react_settings` carrying `flutter_welcome` (the Welcome's own server flag) or `flutter_dashboard` (this app's dashboard namespace) — recorded as seen, silently. `flutter_dashboard` is written only once the user customises the dashboard, so it proves they ran this app somewhere, not that every user of it carries it: an uncustomised user signing in on a second device is greeted once there, and `flutter_welcome` settles every device after.
3. A `company_user.settings` holding `dashboard_fields_per_row_mobile` / `_desktop` is the **previous app**. Only admin-portal writes those. It also writes `report_settings`, `number_years_active` and `include_deleted_clients` — but so does React's user-create screen, for every user it makes, so they prove nothing. Most previous-app users leave no trace at all, which is why the guess only picks the Welcome's first list and a footer link switches.
4. Everything else is an **existing account**.

**No `created_at`.** An invited user's is their invite date, and a self-hosted admin who set up on the web looks new by it. An OAuth account created from either screen lands on `/setup` with an unnamed company, and finishing the wizard re-classifies it (`noteSetupCompleted`: a pending existing-account entry for a user with one company becomes a new account).

**Keyed by server and user** (`welcomeUserKey`): a hashed id is unique only within one server.

## An install that predates the Welcome is baselined, never greeted

`main.dart` calls `noteLaunch(existingInstall:, storedUserKey:)` on every launch, with What's New's `existingInstall` and the user named by the **stored identity** (`kAuthUserIdKey` + `kAuthBaseUrlKey`, `AuthRepository.storedWelcomeUserKey`). A 401, an idle re-lock and a timed-out restore all keep that identity, so the person this device last served is recorded as seen even when no session came back.

**Known gap.** A deliberate sign-out deletes the stored identity. A long-time user who signed out *before* updating to this build, then signs in again, is greeted once — unless a server flag (step 2 above) already covers them. Accepted: one Welcome to someone who knew the app is cheap, and the alternative — greeting nobody whose device predates the record — would silence every previous-app user who installs this app fresh.

## The record

`DevicePrefKeys.welcome` (`welcome_json`), `PrefScope.device`: a sign-out must not greet the same person again. Per user because the JSON is keyed by user.

```json
{"shownAt": 1731150000000,
 "users": {"https://invoicing.co#VolejRejNm": {"status": "pending", "kind": "from_old_app", "at": 1731150000000, "attempts": 1, "companies": 2}},
 "checklists": {"Xrtq1oa8Aq": {"armedAt": 1731150000000, "hidden": false, "doneShown": ["business", "logo"]}}}
```

- At most 25 users; the oldest go.
- A Welcome still pending after 30 days is no longer a first run.
- Three launches that stood down stop the automatic open — in total, not per version, because a pending Welcome holds the other prompts back. A stand-down lasts the whole process (`stoodDownThisLaunch`): the shell, and the host in it, is rebuilt after an unlock or a re-sign-in, and a new host must neither pop the Welcome up mid-session nor spend another attempt.
- Opening it from About or the palette reads it, even once it has stopped opening on its own (`currentPending`, not `autoOpens`).
- Malformed JSON reads as no record; nothing is written before `DevicePrefsStore.loadSucceeded`, or on a demo build or session.

## The wizard writes once, in a fixed order, after its finish moment

**Saving the name opens the gate.** `CompanyRepository.updateCompany` writes Drift first; the companies table notifies `auth.session`, the router's `refreshListenable`; and the `/setup` redirect leaves the moment `isCompanySetupRequired` is false. A wizard that saved its first step would be thrown out before its second. So `SetupWizardViewModel` holds a draft and writes it in one `commit()`:

1. `WelcomeController.noteSetupCompleted` — arms the company's checklist, and settles a pending Welcome that was really a new account's. First, because the company save below unmounts the screen.
2. The user's name (`enqueueUpdate`, `requiresPassword: true`) when the wizard asked for it.
3. **One** company PUT: name, currency, invoice language.
4. The logo upload — **after** the PUT, which carries the company's current `settings.company_logo`; an upload sent first would be cleared by it. `setup_wizard_flow_test` pins the order.

`commit()` captures every repository at construction and never notifies after its first write. A kill mid-wizard loses at most a minute of typing; the name is never half-saved.

**The finish moment comes first.** About 450 ms — the button turns into a check, the progress fills, a success haptic, the content fades — then the commit, because nothing can animate on a screen the router is already tearing down.

**The wizard is where the name is collected** — whenever `needsUserName` holds (hosted, either name missing). `PUT /users/{id}` is password-protected: a fresh email sign-up primes `PasswordCache` (`SignupViewModel`) and an OAuth user is exempt. When neither holds — a login that landed on `/setup`, or a primed password that lapsed (five minutes, or the app went to the background: an Android file picker is a full-screen activity, and `PasswordCacheLifecycleObserver` clears the cache on `paused`) — Finish checks `nameNeedsPassword` and shows the password sheet while the wizard is still up. Declining skips the name, never the company.

**No name dialog on a new account's first dashboard.** The shell's missing-name prompt skips the launch that finished `/setup` (`setupCompletedThisLaunch`), as it skips one the Welcome has. A run of the real app showed why: a wizard that left the name out handed the user straight to a "User Details" dialog over the checklist.

**The name lands in the session at once** (`AuthRepository.noteQueuedUserName`). The shell's missing-name prompt reads the session, and the PUT is at least a round trip away when the router reaches the dashboard — without the local patch a new user was asked for the name they had typed a second earlier. The PUT's response, or the next `/refresh`, replaces it.

**A placeholder name is refused** (`isPlaceholderCompanyName`: blank, "Untitled Company", "Untitled"): the gate reads it as "not named yet", so a save would leave `/setup` shut with the wizard frozen on its finish. As a backstop, a wizard still up two seconds after its commit hands its controls back.

**Keyed on the active company.** Switching to another unnamed company from the ⋮ menu keeps the same `/setup` page; the screen rebuilds its view model for the new company rather than naming the old one.

**Only admins are gated.** `isCompanySetupRequired` requires `isAdmin || isOwner`: an invited user on an unnamed company could only fail a save the server refuses them, and used to be trapped there.

**Other choices**

- Two steps, one required field. No time zone (a locale carries none — it is in Localization settings), no subdomain, no address, no theme: each costs a decision before the first invoice.
- Currency and invoice language are one summary row with **Change** — confirmable at a glance. A new company already carries both: the server seeds them (`CompanySettings::defaults`, then `CreateCompany::applyCountryDefaults` from the sign-up's IP country), so the row shows the server's guess; the device-locale guess in `setup_defaults.dart` is only the fallback for a company that has none. "Invoice language" because it is the language invoices are sent in, not the app's.
- Esc goes back a step only off step 1; on step 1 it belongs to the currency and language pickers.
- The preview is white paper in both themes, laid out left-to-right like the printed page (`// rtl: physical`); its total goes through `Formatter.money(currencyId:)`, so the format confirms the region.
- On any touch device — a phone, a landscape phone, an iPad — the logo step offers Photos and Files as two buttons (gated on `Env.isTouchPrimary`, never on width): a logo usually lives in Photos, which the iOS file picker cannot reach. On a narrow window the preview leads the step, its logo slot (44 px target) opening Photos.
- The step-2 primary is an outlined **Skip for Now** until a logo lands, then a filled **Finish Setup**: the heaviest button never says skip.
- Payments are a checklist row, not a step: Stripe and PayPal connect leave for the browser and would strand a user mid-wizard.
- `/setup` fades in (`CustomTransitionPage`) rather than sliding as a push with no back. The sign-up toast and the old "Welcome, :name!" toast are gone: sign-up into the wizard is one flow.
- `ValueKey('setup_company_name')` stays on step 1 and `ValueKey('setup_submit')` on the primary: the blocking CI smoke test finds them.

## The checklist reads its ticks from Drift, and a queued logo counts

The first child of both dashboard bodies, above the needs-attention band — and **always one child**, a zero-size box when off, for the same index-matching reason as `DashboardAttentionSlot`. It shows for an admin on a company whose `/setup` finished on this device, until hidden or done.

| Row | Done when |
|---|---|
| Set up your business | always — the wizard did it, so the bar starts with progress |
| Add your logo | the company has a logo, **or an `upload_logo` row is in the outbox** ("Uploading…"; `OutboxDao.watchLogoUploads` reads id and state only, never the base64 payload); a dead one shows **Retry**, which re-arms it as the Outbox screen does |
| Send your first invoice | an active invoice past draft (all invoices − drafts, through `watchBadgeCount`) |
| Get paid online | an active company gateway |
| Add your clients | an active client |

- Ordered for the first **sent** invoice — the moment that brings a freelancer back. Clients come last because the invoice editor creates one inline.
- Only the next row has a filled button; the rest are quiet rows that lead to their screens. Create rows go through the dashboard's `_create`, never a bare `go` that could reuse a seeded form. The buttons sit beside the text where there is room and under it where there isn't (a phone, a long locale, a large text size). Each row's tick and text are one screen-reader node carrying `checked`.
- A tick finished on another screen animates when the dashboard is next seen, once (`doneShown`).
- **Hide** collapses it, with Undo; Getting started (About, the palette) brings an incomplete one back.
- All five done: the record is marked complete at once (one success haptic, never again) and the card stays for that visit with **Done**; the next visit shows nothing.
- While it leads a **fresh** company (`ChecklistState.fresh`: set up by an account just created) with no invoices at all, the zero figures and empty panels step back (`HiddenEmptyPanelsBuilder.force`): a grid of $0.00 under it only dilutes the one thing to do. An old company named in `/setup` is never fresh — its invoices may be on the server but not yet on this device.

## The Welcome opens on arrival or not at all, and holds the other prompts back

**On arrival.** `WelcomeHost` sits outermost in `SyncEventListener.build`, so never over `/login`, `/lock` or `/setup`. It opens 400 ms after the shell's first frame if `QuietMomentCheck` passes; if the user is already busy it retries for about four seconds, then stands down for the launch (an attempt). A welcome that turns up forty seconds into work is a pop-up. A launch that arrived by a link (`DeepLinkRouter.arrivedThisLaunch`) stands down at once and spends nothing: the user came for something specific.

**Below 600 px it is a bottom sheet**, a dialog above. A swipe down is a deliberate close; ✕, Esc and **Let's go** are too — all mark it seen and set the server flag. A `null` result that wasn't a swipe is a teardown (a 401, the idle timeout: go_router replaces the shell page, which completes the Welcome's route without popping it, so `onPopInvokedWithResult` never fires) and leaves it pending. On a phone the footer is the list link above a full-width **Let's go**; wider, the link at the start and Let's go (a `PrimaryDialogAction`, autofocused on every device so a tablet's keyboard reaches Esc and Enter) at the end.

**Three rows a list**, best-in-class welcomes show three things and one button. What's changed leads with "All your data is already here" (the previous-app user's real question), showing sync progress while a pass runs. "Find anything fast" shows the command palette's **live** binding as caps — never ⌘K, which is Switch company — and nothing when unbound.

**The hold order.** While the Welcome may open, What's New stands down for the launch without spending an attempt (it would follow straight after); the Welcome's `markSeen` marks What's New read. The promo and the review prompt are held while it may open and for `kAutomaticPromptGap` (seven days) after it opens. The missing-name prompt skips a launch the Welcome has.

**Content** is `const` lists in `welcome_content.dart`, translated through `_app_pending.json` (unlike the English release notes), filtered by the release notes' `ReleaseNoteSurface` — no other store named on an Apple build, widgets only where there are widgets — plus `hideOnTouch` for the keyboard row (a phone browser is touch but not `nativePhone`), and gated by `welcomeActionReachable` (module, permission, admin). A row that opens a screen is a link to a screen reader; one that opens a dialog or the palette is a button. A sentence that names a screen takes its name from the app's own label (`titleTemplateKey` + `titleArgs`: "use :summary and :period" filled from the report gallery's keys). Nothing goes into `kReleaseNotes`. `welcome_content_test` resolves every route through the real router and checks every template placeholder has an argument.

**Its buttons have their own keys** (`setup_finish`, `setup_back`, `setup_change`, `welcome_lets_go`, `checklist_retry`): several shared Transifex keys render wrong on these first screens (es `lets_go` reads "Sign in", ja `finish_setup` "setup has completed"), and an overlay cannot replace a real — if wrong — bundle translation.

## Motion and haptics

The wizard, the checklist and the Welcome are the first surfaces built on `InMotion` and `InHaptics`; the rule, the tokens and their motion table are in docs/motion-and-haptics.md.

## On a phone

A mobile review of the real widgets (iOS / Android metrics, notch and home-indicator insets, keyboard up, 2x text, landscape, dark, RTL) set these; each is invisible on a desktop.

- **The wizard splits only when the window is wide *and* tall** (≥ 720 × 560). A landscape phone is wide enough but, with the keyboard up, would leave the form one field's height; it gets the single column with the pinned footer, capped to the form's width.
- **Photos is one full-width button, Files a link under it** below about 400 logical px (text scale included); side by side they wrapped on a 360 px phone and broke words at 2x. The preview's logo slot shows an add-photo glyph where it is the way to add one.
- **The currency / language card is one target**, and opening it drops the keyboard and scrolls the pickers into view.
- **Display headings clamp at 1.5x text** (the wizard's step title, the Welcome's title), as iOS large titles scale less than body text; past 1.3x the Welcome gives its icon's width back to the title.
- **The success haptic fires after the commit**, a light one on the tap: never success, then an error.
- **The Welcome is a sheet on any phone** — decided on `shortestSide`, not width, so a landscape phone is not handed a dialog a row and a half tall. On touch a tap on the scrim closes it, counted as read like a swipe. "Can't find something?" scrolls itself into view once both size animations have run.
- **The checklist is short on a phone**: finished steps fold into the progress line (an upload under way stays, to say so), steps after the next show their title alone, and the next step's words lead where its button does.

