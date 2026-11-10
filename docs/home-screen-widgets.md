# Home-screen widgets

Companion to CLAUDE.md § Architecture — at a glance. Home-screen widgets on iOS, macOS and
Android: Business snapshot, Needs attention, and Running timer (with a one-tap Stop). CLAUDE.md
carries the rules; this doc carries the contract between the app and the native widget code, why
each part is shaped the way it is, and the traps.

```
App (Dart)                                         Widget (Swift / Kotlin)
 ├─ HomeWidgetReader      Drift → builder input     reads ONLY the snapshot file
 ├─ buildWidgetSnapshot   pure, display-ready  ──►   <App Group>/HomeWidgets/snapshot.json  (iOS, macOS)
 ├─ HomeWidgetPublisher   debounce · compare ·       noBackupFilesDir/home_widgets/snapshot.json (Android)
 │                        reload budget · sign-out
 └─ HomeWidgetCommands    applies queued Stops  ◄──  …/commands/<uuid>.json  (written by the widget's
                          through the outbox          own code: App Intent / non-exported receiver)
Taps ──► invoiceninja://app/<route>?company=<id> ──► the existing deep-link pipeline
```

Code: `lib/domain/home_widgets/` (schema, builder, command), `lib/app/home_widgets/` (reader,
publisher, consumer, host widget), `lib/data/services/home_widget_bridge.dart` (the channel
`invoice_ninja/home_widgets`). Golden fixtures: `test/fixtures/home_widgets/`.

## A home-screen widget reads only the app-written snapshot

**A home-screen widget reads only the app-written snapshot (no token, no network, no Dart), and
its taps are deep links through the trampoline.**

The old admin-portal widget (`macos/DashboardWidget`, disabled in Aug 2025) copied every
company's API token in plain text into shared `UserDefaults` and called `/charts/totals_v2` from
the extension. Here no credential ever leaves the app:

- **The Drift store is SQLCipher**, so a native widget can't read it. The app pushes a small
  display-ready snapshot instead.
- **No Dart runs for a widget**, a control or a shortcut. A headless engine would open the store
  a second time in the same process, which breaks the one-engine rule (`store_lock.dart`). So
  `home_widget`'s background callbacks and `workmanager` are both out.
- **The snapshot is display-ready.** Money is pre-formatted by the company's `Formatter` (both
  `text` and a `compact` form), and every label comes pre-translated in `strings`. A task's
  `description` is its title (`widgetTaskTitle`: the description, else `#number`, as the app
  names it everywhere), so a blank one never reaches a widget as a bare dash. Native code
  formats only a live clock and "N days late", and works the latter out from `lateSince` so it
  stays right after midnight.
- **Taps are deep links**, `invoiceninja://app/<route>?company=<id>`, through the existing
  pipeline. On Android a `PendingIntent` or shortcut targets `DeepLinkReceiverActivity`
  explicitly, never `MainActivity` (`docs/deep-links.md`). `ArrivalGate` holds a link while the
  app is locked or signed out, and `switchCompanyGuarded` switches company.
  `parseAppDeepLink` accepts `<root>/new` and `/dashboard` for this.

**Freshness is honest, not faked.** A widget is only as fresh as the last app session for its
company. Each figure set carries `fetchedAt`, taken from the `dashboard_cache` row and never from
the snapshot's write time: an offline launch rebuilds the snapshot from hours-old rows. The widget
shows a neutral "Updated 3 hr ago", turning amber with "Tap to refresh" only after the period has
rolled over or 72 h have passed.

## The snapshot contract

`WidgetSnapshot.toJson` in `lib/domain/home_widgets/widget_snapshot.dart` is the schema. The
rules:

- **Every field is optional on the native side.**
- **An unknown figure is absent, never `0`** (`docs/dashboard-panels.md` § Unknown is not zero).
- **A user without `view_dashboard` gets no `figures`**, and their Timer widget still works.
- **`pastDueAmount` is written only when proven**: every past-due invoice fetched, all in one
  currency (`NeedsAttention.pastDueSum`).
- **A period carries its concrete `name` and `endsOn`** ("October", `2026-10-31`). Once the clock
  passes `endsOn` the widget shows the name, so last month's numbers never sit under "This Month".
- **A trend (`deltaPct`, `good`) is left out** for a period's first 5 days (it shows from day 6), and wherever
  `percentDelta` has nothing to divide by.
- **`today.doneSeconds` is finished work only, clipped to the device's day `today.date`.** The
  widget adds each listed running timer (`now - max(runningSince, midnight)`), so the "Today"
  total ticks without a write, and hides the line once its local day is not `date`. It ticks only
  with exactly one timer running; two would need a clock at twice the rate.
- **`outstanding.pastDueShare` (0–1) is written only when `pastDueAmount` is**, in the same
  currency as the Outstanding bucket and with Outstanding above zero. It draws the past-due bar.
- **`timers` holds the newest three (`kWidgetMaxTimers`); `runningCount` counts them all.** The
  Timer widget's "+N running" and its medium capacity read `runningCount`: counted from the
  capped list, a fourth timer could never be mentioned.
- **Bump `kWidgetSnapshotVersion` only for a change an older widget would misread.** Adding a
  field is not one. A widget meeting a newer `v` shows "Update Invoice Ninja".

The golden fixtures in `test/fixtures/home_widgets/` are written by
`widget_snapshot_builder_test.dart` (regenerate with `UPDATE_WIDGET_FIXTURES=1`). The Swift and
Kotlin decoder tests read the same files, so a schema change fails all three until each side is
updated.

## The snapshot is rebuilt from Drift, never merged

The publisher rebuilds the whole snapshot from Drift on each change: the active company plus every
company a widget is pinned to. It never patches the previous file, so a company switch, a purge
or a sign-out can't leave a stale fragment behind.

- **Only the active company is fetched.** Every dashboard fetch is bound to the active token
  (`_ensureStillActive`). A widget pinned to company B shows B's cached figures with B's own
  stamp, and "Open B to update".
- **The widget's filter is the dashboard's saved filter with only the date range swapped**:
  same currency, same drafts setting, same fiscal year. So the widget never disagrees with the
  dashboard for the same period.
- **Fetches skip anything fresher than a minute** (`maxAge`), and join a request already in
  flight for the same row (`DashboardRepository._coalesced`). The dashboard and the publisher
  listen to the same signals (Sync completion, a realtime push, a resume), so most widget
  fetches cost nothing. The rule is not symmetric: a "fetch now" caller (the dashboard, with no
  `maxAge`) arriving during a flight **re-fetches once it ends**. The request in flight may have
  left before the change that prompted the call, and joining it would put the old figures back.
- **The base snapshot is written even with no widget installed**: signed-in state, companies,
  App Lock. The widget gallery, the company picker and "Hide amounts: Automatic" read it before
  any widget exists. Figures and fetches wait for `installed()`.

## Writes are debounced, compared and budgeted

- **Debounced 2 s** (`kWidgetWriteDebounce`), so a Sync pass is one write.
- **Compared without `writtenAt`** (`WidgetSnapshot.comparable`). Otherwise every write looks
  changed and every widget reloads on the clock.
- **Flushed on the way to the background**: paused, hidden, inactive, and a desktop quit
  (`HomeWidgetsHost`). iOS suspends the app before a 2 s timer fires, and the widget would keep
  a timer the user had just stopped.
- **Reloads are per kind and budgeted.** iOS gives a widget roughly 40–70 reloads a day, and a Mac
  left open refetches the dashboard every few minutes. A timer change reloads the Timer widget
  at once; a figure change reloads Snapshot and Attention at most every 5 min
  (`kWidgetReloadGap`). A change of signed-in state, company or strings reloads everything.
  **A first fill never waits:** a figure part a widget draws "not loaded" without (the figures,
  Outstanding, a period, the attention lists — `figureParts`) appearing since the last figure
  reload goes through at once. The app's first write lands before the dashboard has loaded, so
  without this a freshly added widget said "Open Invoice Ninja to load your data" for up to
  5 min with the app open (Apple doesn't budget a foreground app's reloads anyway).
- **Started after `restore()`** (`main.dart`). Earlier, a cold start's not-yet-restored session
  reads as signed out and blanks every widget for a moment. After a restore that failed or
  timed out, `start(sessionKnown: false)` leaves the widgets alone until a session arrives,
  because there "no session" means "not known yet", not "signed out".
- **One rebuild at a time, the latest always run.** Two overlapping rebuilds can finish out of
  order and write the older data last, for example showing a timer that was just stopped as
  running again.
- **A rebuild re-checks the sign-out generation after its write too.** Otherwise a write that
  was in flight during a sign-out re-arms the "nothing changed" cache, and the same user
  signing back in is left looking at "Sign in".
- **Only what an installed widget shows is read.** Task and client names leave the encrypted
  store only for a Timer widget, and figures only for a Snapshot or Attention widget.
- **The strings are the bundled words** (`lookupBundled`), never the active company's Custom
  Labels. There is one `strings` map for every widget, and a widget pinned to another company
  would read the wrong company's words.

## Every session end leaves the widget snapshot signed out

**Every session end leaves the widget snapshot signed out, after cancelling any pending write.**

- **`AuthRepository.onBeforeLogout`** covers every end, including a 401 and an idle re-lock that
  keep the data. It calls `HomeWidgetPublisher.signOut()`, which:
  - cancels the pending write;
  - bumps a generation, so a rebuild already in flight can't write the figures back;
  - writes the `signedIn: false` stub;
  - keeps queued commands. A 401 that keeps the data is the same user coming back, and deleting
    their Stop there left the timer running and billing with nothing said. A command is applied
    only for the user who queued it, and only while fresh, so a kept one can't act for anyone else.
- **The stub is written, not the file deleted.** A missing file reads as "Open Invoice Ninja to
  load your data"; the stub reads as "Sign in".
- **`LocalDataDisposer.onWipeAll`** does the same, and deletes the queued commands
  (`signOut(dropCommands: true)`): they name records the wipe just removed. Its single slot is
  shared with the shared-intake purge, so both run from one closure.
- **A cold start with no session** also writes the stub, which covers a logout that crashed half
  way.
- **Never name a bridge method `wipe`.** `local_data_disposal_test` greps for `.wipe(` and would
  claim it.

## The only write is a queued command

**The only write a widget makes is a queued command that only the app's own code can create (never
a URL), applied by the app through the outbox — a Stop at the time of the tap, a Start through the
task's own start once the app has opened on it.** Two commands, `stop` and `start`.

- **Why not a URL:** any app or web page can fire a URL, and a URL that stops or starts timers is
  a forged mutation away. A `?start=1` link would have been the short way to Start, and is exactly
  this. The command is written by an App Intent, or on Android by the non-exported
  `WidgetCommandReceiver` (Stop) or `WidgetStartActivity` (Start), into storage only the app can
  reach.
- **`at` is the tap time.** `TaskRepository.stopRunningTimer(stopAt:)` stamps it, clamped to the
  entry's start and to now. Stamping `now` when the app gets round to it would bill the hours in
  between.
- **`runningSince` guards against change elsewhere.** If the task was stopped and restarted on
  another device since, the running entry starts somewhere else and the stop is dropped with a
  toast (`widget_stop_not_applied`). That is the only outcome that toasts. A second tap (already
  stopped), a missing task or a permission refusal is skipped quietly
  (`TimerStopResult`).
- **A pass re-reads the session before every command, and stops once it changes.** A stop must
  never be written under a session that has ended, into a database about to be wiped.
- **A Stop re-checks it again just before it saves (`stillCurrent`).** The stop first refreshes the
  task from the server (up to 8 s), and a sign-out landing in that wait used to wipe the database
  under it: the refresh then wrote the task back, and the save queued an outbox row for the
  outgoing user into the database the next user signs into. The app's `stopTimer` throws
  `WidgetSessionEndedException` instead, which keeps the command (`failed`) for the next session.
  The refresh's own upsert is not guarded (it is a plain read, outside the outbox's
  `RequestScope`), so the task's cached row can still land; nothing is queued from it.
- **A command is checked before it is applied.** It must be:
  - this user's (`userId`);
  - for a company the session lists;
  - no older than 7 days (`kWidgetCommandMaxAge`);
  - for a task this user may edit (`canEditRecord`).

  The Timer widget shows only the user's own timers and tasks (created by or assigned to them),
  so a teammate's timer never appears with a Stop an admin could press. `canStop` is still sent,
  for a task the user may not edit.
- **A command for another company is deferred**, not dropped: the outbox and the edit rule
  belong to the active company. It is applied when that company becomes active again.
- **The file is deleted only once the command has been handled**, and each id is applied once
  per run of the app, so a delete that failed can't stop a timer twice.
- **A Start opens the app, and the app starts the timer.** `planTaskStart` can return
  `needsConfirmation` for a booking claim, a question only the app can ask. So a recent task's ▶
  in the idle Timer widget queues `{kind: "start", taskId, companyId, userId, at}` *and* opens
  the app:
  - **iOS / macOS:** `StartTaskIntent` (in `WidgetIntents.swift`, so it is compiled into the
    Runner as well) has `openAppWhenRun`, and posts the Darwin notification the bridge now
    observes on both platforms. The intent may land after the app's resume pass.
  - **Android:** `WidgetStartActivity`, not exported and engine-free, writes the file, pings a
    running app and launches it. An activity, not the receiver: Android 10+ refuses an activity
    start from a background receiver.
  - **The app:** `HomeWidgetCommands` hands a start to `startTask` (set by `main.dart`), which
    opens the task's own deep link — so the lock screen holds it and a company switch runs its
    guards — with a `then` (`DeepLinkRouter.open`) that runs `TaskActions.startFromWidget` once
    the record is on screen: a bounded refresh, then the record's own start, with its booking
    question, In-progress status and Undo. A running, invoiced, unsynced or uneditable task is
    left alone; the record on screen says why.
  - **Not deferred like a Stop**, because its link switches company itself, and **dropped after
    10 minutes** (`kWidgetStartMaxAge`): a timer that started an hour after the tap would bill an
    hour nobody worked. It starts when applied, a second or two after the tap.
  - A `tmp_` task can't be started (no server id); its row keeps the history glyph and opens
    the tasks list.

## Platform notes

### Android

The code is in `android/app/src/main/kotlin/com/invoiceninja/admin/homewidgets/`. It uses
hand-rolled `RemoteViews` and adds no Gradle runtime dependency, so the F-Droid build is
unchanged. JUnit and `org.json` are `testImplementation` only.

| Piece | What it is |
|---|---|
| `WidgetStore` | The snapshot and command files, under **`noBackupFilesDir/home_widgets/`**. The app's backup rules exclude only the widget settings file, so `filesDir` would be backed up in plaintext. Writes go to a temp file, then a rename. |
| `WidgetSnapshot` | The lenient decoder (every field optional; a newer `v` sets `tooNew`). `WidgetSnapshotTest` decodes the Dart golden fixtures. |
| `HomeWidgetsChannel` | The channel's Android half, registered by `MainActivity`, with file work off the main thread. `active` is how a widget's Stop or a reconfigure reaches a running app; it holds only the application context. |
| `Snapshot`/`Attention`/`TimerWidgetProvider` | The three providers, all `exported="false"`: the system still delivers their updates. |
| `WidgetCommandReceiver` | The Stop button. **Not exported and with no intent filter**, so only this app's own `PendingIntent`s reach it. It writes the command, redraws the Timer widget (which shows "Stopped 9:41 · syncs…" while the command waits), and pings a running app. It never starts an engine. |
| `WidgetStartActivity` | A recent task's ▶. **Not exported, no intent filter, `Theme.NoDisplay`**: it writes the start command (only for the user the row was drawn for), pings a running app, launches the app with no extras, and finishes. `WidgetManifestTest` pins both command entry points' export state. |
| `WidgetRolloverReceiver` | An inexact alarm at the next moment a widget's text changes on its own (local midnight, a 72 h stale threshold, a 12 h old timer snapshot), plus `TIME_SET` / `TIMEZONE_CHANGED`. There is no `updatePeriodMillis` polling. |
| `WidgetConfigureActivity` | Plain Views, no engine. It is exported because the launcher starts it, so **it checks the widget id belongs to this package** before saving, or another app could turn a widget's masking off. `reconfigurable|configuration_optional`: a widget works with no setup. |
| `xml/shortcuts.xml` | The app-icon quick actions (New Invoice / Task / Expense). They are declared on the launcher activity, but each intent targets `DeepLinkReceiverActivity`. |

The traps:

- **A `Chronometer` counts from `elapsedRealtime`**, which restarts at boot. Its base is worked
  out from `runningSince` on every render and never stored.
- **Date arithmetic is plain day numbers** (`HomeWidgets.epochDay`), not `java.time`. It was
  written when minSdk was 24, below `java.time`'s API 26; minSdk is 26 now, so either works.
- **A bare `View` is not allowed in a `RemoteViews` layout.** Spacers are empty `FrameLayout`s.
- **Every tap is a distinct `requestCode`** (widget id × 100 + region). Otherwise Android hands
  back one `PendingIntent` for all of them.
- **Text the OS shows before any snapshot exists** (picker names, settings, states, quick-action
  labels) is in `values*/widget_strings.xml`, in all 44 languages, by the *device's* language.
  Everything else comes from the snapshot's `strings`, in the app's language.
- **App-wide manifest changes the widgets needed:**
  - `android:supportsRtl="true"`, without which a widget can't lay out right to left (Flutter
    draws its own UI, so only native views are affected).
  - `fullBackupContent` / `dataExtractionRules`, exclude-only: everything backed up before still
    is, except `home_widget_settings.xml`. Widget ids are per device, so a restored
    "N.hide=off" would attach to whatever new widget got id N.
- **Before Android 12** `configuration_optional` and `reconfigurable` don't exist: the settings
  screen opens when a widget is placed (Back removes it), and the only way back to it later is a
  "Choose a company" tap. Changing Hide amounts there means removing and re-adding the widget.
- **Every widget-thread task catches and logs.** An exception escaping an executor task kills
  the process, a foreground Flutter app included.
- **Row heights come from the device's real font metrics, not guessed per line.** A layout's
  capacity (rows, the Outstanding block, the "Due soon" label) is worked out from the measured
  widget height (`HomeWidgetsLayoutTest`), and at the smallest sizes the vertical padding gives
  way, never below 4dp, before content is dropped.
- **`@android:dimen/system_app_widget_internal_padding` does not exist.** It was withdrawn before
  Android 12 shipped and a build referencing it fails; `values-v31/widget_dimens.xml` uses its old
  value, 16dp.
- **Each root view is `@android:id/background`**, which the launcher animates into the app on a
  tap (Android's widget quality criterion WS-5).
- **A `ForegroundColorSpan` colour is fixed when the text is drawn.** The red past-due part of a
  caption takes a light/dark switch at the next redraw, not at once.
- **A task still on a local `tmp_` id** (created offline) links to the tasks list, and its Stop
  resolves to the server id in the app before it is applied.

### iOS

The extension's sources are in `ios/HomeWidgets/`, the target is `HomeWidgets`
(`com.invoiceninja.admin.HomeWidgets`, iOS 17+), and it was added by
`tools/add_home_widgets_target.rb`, an idempotent `xcodeproj` script, not by hand.

| Piece | What it is |
|---|---|
| `WidgetFiles` | The App Group paths and file rules. It is compiled into the extension **and** the Runner. The snapshot is written atomically with `.completeFileProtectionUntilFirstUserAuthentication`, so a widget can read it while the phone is locked. |
| `WidgetSnapshot` | The lenient decoder: plain dictionaries, nothing force-unwrapped (the old widget force-unwrapped and crashed). `tools/widget_snapshot_contract.sh` decodes the Dart golden fixtures with it, and CI runs that in the `apple` job. |
| `WidgetIntents` | The configuration intents (company, period, figure, Hide amounts Automatic / On / Off). They are compiled into the Runner too, which reads a placed widget's settings back through `widgetConfigurationIntent(of:)` for `installed()`. |
| `StopTimerIntent` | Its own file, **compiled into the extension only** (`share_target_wiring_test` pins it). In the Runner too, the app would register it, and iOS could run a Stop in the app's process, starting Flutter for a widget. It writes the command into the App Group and reloads the Timer widget. `authenticationPolicy = .requiresAuthentication` means a lock-screen or StandBy tap asks for an unlock first. |
| `Snapshot` / `Attention` / `TimerWidget` | SwiftUI widgets that use `containerBackground`, `widgetAccentable` and `privacySensitive`. A glyph accompanies every past-due colour, because tinted and StandBy modes drop colour. Timer: `Text(timerInterval:)` ticks without reloads. Lock screen: Snapshot gets rectangular, circular (the past-due count) and inline; Timer gets rectangular and inline. |
| `Runner/HomeWidgetsBridge.swift` | The channel, registered in `didInitializeImplicitFlutterEngine`. File work runs on **one serial queue**, so a sign-out's stub lands after any earlier write. |

Traps:

- **The background and the tint are set in code** (`WidgetColor.background`, `WidgetColor.brand`
  = the app's #2F7DC3). The extension has no asset catalog, so `.tint` would otherwise be the
  system blue, and the template's translucent `.fill.tertiary` all but hid the `.quaternary` row
  cards. Tinted and clear modes remove the background themselves.
- **A hero figure is `fixedSize` vertically.** With `minimumScaleFactor` alone, a medium a few
  points short of its content shrank the hero to the size of the figure under it.
- **Every `·` between two pieces is its own `Text`.** In a right-to-left layout the HStack
  reverses whole children; a `"· $3.1K"` string kept its dot on the wrong side.
- **Off-device renders:** the views can be drawn with `ImageRenderer` in a Mac Catalyst harness
  (swap `\.widgetFamily` for a stand-in environment key). That is how the timer rows that
  overflowed a medium and the small caption split into columns were found; a green build
  says nothing about layout.
- **A small (or lock-screen) widget is one tap target.** Its `Link`s are ignored and only
  `widgetURL` counts, so each small widget's URL is its one visible action: the figure's list,
  the running task, or `/tasks/new` when idle.
- **Measured, not guessed:** a medium widget's content area is about 126 pt, enough for the
  Needs attention header, **two** rows and the footer.
- **Never white text on `.tint`.** iOS 18's tinted mode drops colour and the label disappears; use
  tinted text on a quiet fill.
- **The gallery gets sample data (`context.isPreview`), a real user never does.** No snapshot
  means the "Open Invoice Ninja" message.
- **The snapshot folder is excluded from device backups.** Command files are ordered by their own
  `at`, never a file timestamp, which is a "required reason" API that would need a privacy
  manifest.

The OS-shown text (gallery names and descriptions, the Edit Widget options, the controls) is in
`Localizable.xcstrings` in all 44 languages, by the device's language. Everything a widget draws
comes from the snapshot's `strings`, in the app's language.

Signing: for the GitHub workflows the extension needs its own App ID (both platforms), App Store profiles and secrets (`docs/store-deployment-setup.md` §3E); until then each App Store workflow stops at the profile step with that message. Local simulator and device builds and an Xcode **Product → Archive** need none of it: Automatic signing registers the App ID and group itself. Open the HomeWidgets target's Signing & Capabilities once before the first archive.

### macOS

The same three widgets, from the same Swift sources: `ios/HomeWidgets/*.swift` are referenced by
the macOS `HomeWidgets` target (macOS 14+), which `tools/add_home_widgets_macos_target.rb` adds.
The Mac-only files (Info.plist, entitlements, xcconfig) are in `macos/HomeWidgets/`. The
Runner compiles `ios/Runner/HomeWidgetsBridge.swift` too, one file for both platforms, and
registers it in `MainFlutterWindow.awakeFromNib`.

- **The App Group is team-prefixed** (`NPC44Y2C98.com.invoiceninja.admin.widgets`, required for
  a sandboxed Mac App Store app below macOS 15), in the extension and both Runner
  entitlements. `share_target_wiring_test` pins all four strings. Adding it to the Runner
  invalidated its Mac App Store profile (`docs/store-deployment-setup.md` §3E).
- **A Stop applies at once:** a Mac app is usually running, so `StopTimerIntent` posts a Darwin
  notification and the bridge asks Dart to run the commands now.
- **Signing is per target** (`tools/ci_macos_target_profiles.rb`), for the same reason as iOS.
- **No lock-screen families or Control Center controls** on macOS; `#if os(iOS)` keeps them
  out.
- **The group container has no file protection and survives the app's deletion.** Only what an
  installed widget shows is written (task rows only for a Timer widget).

### Quick actions, controls and Siri (iOS)

- **App-icon quick actions:** Info.plist `UIApplicationShortcutItems` (New Invoice / Task /
  Expense), each carrying an `invoiceninja://app/…` link that `SceneDelegate.open` opens
  through the system. It arrives through app_links like any link, so DeepLinkRouter validates
  it, holds it while locked, and switches company.
- **Siri / Shortcuts / Spotlight:** `ios/Runner/AppShortcuts.swift` (`openAppWhenRun` intents
  that open the same links). Nothing in it writes: Stop timer stays the widget's.
- **Control Center controls (iOS 18):** New Invoice and New Task (`ios/HomeWidgets/Controls.swift`),
  each returning an `OpenURLIntent` for its link, and **Stop timer** (`StopTimerControl` in
  `StopTimerIntent.swift`). Stop queues the same command as the widget's button, for the newest
  stoppable timer of the current company, so it is extension-only like `StopTimerIntent`. With
  nothing running it does nothing.
- **Translations:** String Catalogs, with the device's language deciding:
  - `ios/HomeWidgets/Localizable.xcstrings` (gallery, Edit Widget, controls);
  - `ios/Runner/InfoPlist.xcstrings` (quick-action titles);
  - `ios/Runner/Localizable.xcstrings` (Siri action titles);
  - `ios/Runner/<lang>.lproj/AppShortcuts.strings` (Siri phrases, each with `${applicationName}`
    exactly once). Not a String Catalog: Xcode accepts an AppShortcuts catalog only for an
    iOS 17 deployment target, and the app's is 15.

### Telling people the widgets exist

Device Settings → **Home-screen widgets** (`HomeWidgetsSection`; iPhone, iPad, Android and Mac, each with its own instructions) explains how to
add one. On Android it has an Add button per widget, which calls `requestPinAppWidget` through
`HomeWidgetBridge.pin`; a launcher that refuses gets the by-hand instructions. A release-note
bullet about the widgets is `hiddenOn: {ReleaseNoteSurface.withoutHomeWidgets}` (web, Windows,
Linux).
