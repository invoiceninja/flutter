# Sharing files into the app

Companion to CLAUDE.md § Deep links. "Share → Invoice Ninja" from another app (Mail, Gmail,
Photos, Files…) opens **New Expense** with the shared images / PDFs attached
(invoiceninja/flutter#173). The rule lives in CLAUDE.md; this doc carries the mechanism on each
platform, the traps each piece exists for, and the manual Apple setup the iOS half depends on.

```
Share sheet
 ├─ Android  ShareReceiverActivity (plain Activity, no Flutter engine)
 │            copies → <filesDir>/shared_intake/<uuid>/   (while it holds the read grant)
 │            └─ once resumed, starts MainActivity: ACTION_MAIN + CATEGORY_LAUNCHER,
 │               NEW_TASK|CLEAR_TOP|SINGLE_TOP, carrying only a Handoff token
 └─ iOS      ShareExtension (separate process)
              copies → <App Group>/SharedIntake/<uuid>/  + <uuid>.json (written last)
              └─ opens invoiceninja://share
MainActivity.kt / AppDelegate.swift  ── channel 'invoice_ninja/share_intake'  (takeShares; sharesAvailable)
AppShareIntake (lib/app)  ── pull → SharedFileIntake.receive
SharedFileIntake  ── ArrivalGate → create gate → plan gate → validate
                  → an open New Expense, in this company, that can take files? add to it
                  : unsaved-changes guard → stage → /expenses/new?view=full
ExpenseEditViewModel  ── documents; every Save queues exactly these (replacing what an earlier attempt left)
```

| Piece | File |
|---|---|
| Android share target | `android/app/src/main/kotlin/com/invoiceninja/admin/ShareReceiverActivity.kt` |
| Android hand-off + queue | `Handoff.kt`, `MainActivity.kt` (same folder) — shared with deep links' `DeepLinkReceiverActivity.kt` |
| iOS extension | `ios/ShareExtension/ShareViewController.swift` (+ `Info.plist`, entitlements, xcconfig) |
| iOS queue + channel | `ios/Runner/AppDelegate.swift` (`ShareIntake`) |
| Platform bridge | `lib/app/app_share_intake.dart` |
| Arrival choreography | `lib/app/shared_file_intake.dart`, `lib/app/arrival_gate.dart` |
| The copies on disk | `lib/data/services/shared_intake_files.dart` |
| The form | `ExpenseEditViewModel.documents`, `expense_edit_documents_section.dart` |
| Cross-language wiring | `test/lint/share_target_wiring_test.dart`, `test/lint/universal_links_test.dart` |

## A shared file reaches Flutter only as a copy, and never through MainActivity

**Never put a `SEND` filter on MainActivity.** The share sheet starts its target in the
*sender's* task (no `FLAG_ACTIVITY_NEW_TASK`). MainActivity is `singleTop` with
`taskAffinity=""`, and `singleTop` only reuses an instance that is on top of the *same* task — so
a share would start a **second MainActivity, with a second Flutter engine**, in the same process.
`holdStoreLock` cannot refuse it: `_held` (`lib/data/db/store_lock.dart`) is a per-isolate Dart
map, while POSIX record locks belong to the whole process, so the second isolate takes the "same"
lock and opens the SQLCipher store a second time. Every share-receiving package
(`receive_sharing_intent`, `share_handler`) puts the filter on MainActivity and fixes this with
`launchMode="singleTask"`, which changes every other flow (leaving the system file picker and
coming back through the launcher icon finishes the picker). Hand-rolled native code also needs no
F-Droid plugin audit (`docs/fdroid.md`).

So the target is **`ShareReceiverActivity`**: a plain `Activity`, translucent, `noHistory`,
`excludeFromRecents`, with `configChanges` (a recreation mid-copy throws the first copy away and
starts over). It starts no engine. `universal_links_test.dart` asserts the `SEND` filters are on it
and not on MainActivity. Deep links take the same route, for the same reason — see
`docs/deep-links.md` § Android delivers a link to a trampoline, never to MainActivity.

**It has to be the one that reads the files.** The read grant on a shared `content://` URI lasts
only as long as the activity it was delivered to. So it copies each file (on an executor, before
`finish()`) into `filesDir/shared_intake/<uuid>/<name>` — `filesDir` is what Dart's
`getApplicationSupportDirectory()` returns on Android. A copy longer than 300 ms shows a spinner
over a dim scrim (the platform spinner under `Theme.Translucent` is the old white one, invisible
over a light sender) and keeps the screen on; leaving mid-copy (Back, Home — `noHistory` finishes
it) cancels through a `CancellationSignal` passed to `openAssetFileDescriptor` and deletes what was
copied.

**The copy is handed on only while the activity is resumed.** A stopped activity's
`startActivity` is refused by the background-activity-start rules — silently, the share lost —
and a power-button lock stops it *without* finishing it: `ActivityRecord.stopIfPossible` skips the
no-history finish for an activity that is "just sleeping", so neither `cancelled` nor
`isFinishing` says so. A copy that ends while not resumed is parked; `onResume` (after the unlock)
delivers it and `onDestroy` (Home) deletes it. If the process dies while the screen is locked, the
recreated activity copies again — the read grant belongs to the activity record, not the process.

The provider's `SIZE` is checked
first, so a 30 MB file isn't downloaded to be refused. Malformed extras (non-`Uri` list items, an
unknown `Parcelable`) are survived, not crashed on: a crash here takes the whole process — and a
running MainActivity's unsaved edits — with it.

### The forwarded intent is launcher-shaped, and carries only a token

**Whatever starts MainActivity becomes its task's base intent** — a cold start makes it the
root, and a CLEAR_TOP delivery to the root calls `Task.setIntent` (AOSP
`ActivityStarter.complyActivityFlags`). A later launcher tap is matched against that base intent
with `Intent.filterEquals`, which compares action and categories but not extras; when it fails
while another activity (a file picker, the camera, a Custom Tab) sits above MainActivity, the same
method takes `!targetTask.isSameIntentFilter(...)` → `mAddingToTask = true` and starts a **second
MainActivity** — the second-engine problem again, reached from the launcher. So the forward is
`ACTION_MAIN` + `CATEGORY_LAUNCHER` with `NEW_TASK | CLEAR_TOP | SINGLE_TOP`, exactly what a
launcher tap matches. (`NEW_TASK` finds the app's task by its root component rather than joining
the sender's; `CLEAR_TOP` + `SINGLE_TOP` deliver to the live instance's `onNewIntent` even with a
picker above it.) Verify with `adb shell dumpsys activity activities | grep -E "Hist #.*MainActivity"`:
one entry, after share → Add (picker) → Home → launcher icon.

The price of `CLEAR_TOP`: it finishes whatever sits above MainActivity — a document picker or the
camera the user left open (its plugin future returns null), or Play Billing's proxy activity in
the middle of a purchase. Without it the token never reaches `onNewIntent` while a picker is on
top; a share is an explicit "go there now", so the trade is accepted.

**The files never travel in that intent.** `ShareReceiverActivity` puts the JSON in `Handoff` — a
process-level map keyed by a random token — and the intent carries only the token. MainActivity
claims it (`onCreate`, `onNewIntent`) into a process-level queue Dart pulls.
Two reasons: MainActivity is exported, so an intent payload could be **forged** by any app to name
this app's own private files and have them attached and uploaded; and the intent outlives the
share (it is re-delivered on a Recents relaunch or a recreation), while a token is claimed once.
As defence in depth, `takeShares` drops any path that isn't inside `filesDir/shared_intake`, and
Dart refuses any path `SharedIntakeFiles.owns` doesn't recognise.

**MainActivity strips every extra before Flutter reads the intent.** `FlutterFragmentActivity`
takes its launch configuration from the extras of whatever starts it — the initial `route` (which
would replace the restored location and bypass `DeepLinkRouter`, since `GoRouter` honours the
platform's default route), a cached engine id, `dart_entrypoint_args`, and about twenty engine
flags through `FlutterShellArgs.fromIntent` (software rendering, the Impeller toggle,
trace-to-file…). The app sets none of them, so `sanitize` reads the token (inside `runCatching`:
before API 33 any extras read unparcels the whole bundle, and a forged unknown `Parcelable` would
throw) and then `replaceExtras(null)` — in `onCreate` and `onNewIntent`, before the superclass.
Nothing legitimate is lost: `app_links` reads only the action and data, the sign-in and billing
plugins answer through activity results, and the app has no notification or shortcut plugin.

**File theft through the share itself is refused too.** A `file://` URI, or a `content://` URI
served by one of *this app's* own providers (plugins register several FileProviders, readable by
our own process even though they aren't exported), could name the app's private files. Only
another app's `content://` is accepted, checked before anything else touches the URI. The check
matches our own authorities (`GET_PROVIDERS | MATCH_DISABLED_COMPONENTS`, cross-profile `user@`
prefix parsed as the platform does, by the last `@`) rather than asking who owns the URI's
authority: since Android 11, package visibility can hide the sender's provider from that query.

`app_links` doesn't interfere: `AppLinksHelper.getUrl` returns `null` for
`SEND`/`SEND_MULTIPLE`/`SENDTO`, and the forwarded intent has no data either.

### A dot is not an extension

The server and Dart's validation read a file's type from its extension, and a sender's display
name is not a file name: "Receipt 12.05.2024" or "Inv. 42" for a PDF has a dot and no extension.
Both native sides keep a trailing word as the extension only when it names the type the sender
reports (Android: `MimeTypeMap` against the provider's MIME type, `image/jpg` treated as
`image/jpeg`; iOS: `UTType(filenameExtension:)` conforming to the item's type); otherwise the
whole name is kept and the type's own extension appended — except on iOS, where a trailing word
that names a *different* declared type is dropped (`IMG_1.HEIC` taken as JPEG is `IMG_1.jpeg`).
Only the base is truncated (150 bytes of UTF-8, never mid-character) — never the extension, and a
base of nothing but dots becomes `shared_N`.

On Android the type is the provider's, or — when it names none, or only `application/octet-stream`
or a wildcard — the share intent's own when that one is specific. A wildcard `image/*` never
decides a conversion: the extension does, or a JPEG would be re-encoded and a PNG lose its
transparency.

### iOS: the App Group, and opening the app

An extension runs in its own process and can't write into the app's sandbox. It writes each
share's copies to `<App Group>/SharedIntake/<uuid>/`, then `SharedIntake/<uuid>.json` listing
them — atomically and **last**, one manifest per share, so the Runner never reads a share that is
still being written. The inbox folder is created before anything else, so a share whose every
file was rejected still writes its manifest (and the app can say why) on a fresh install.
`ShareIntake.takeShares` (`AppDelegate.swift`) moves every listed share into
`Application Support/shared_intake/<uuid>/` — what `getApplicationSupportDirectory()` returns on
iOS — so an outbox `local_path` points into the app's own sandbox, not the shared container. What a
killed extension leaves behind (a share folder with no manifest, an interrupted atomic write's
temporary file) is pruned after a day.

**Copies run one at a time.** The item providers call back on queues of their own, concurrently;
every copy runs on one serial queue, each in its own `autoreleasepool`, so unique names are chosen
without a race and only one image is decoded at a time — a share extension gets about 120 MB, and
a 24 MP HEIC decoded in full is nearly that on its own. Conversion goes through ImageIO's
thumbnail path (`CGImageSourceCreateThumbnailAtIndex`, long edge 3072, `…WithTransform`), which
decodes straight to the target size, bakes the orientation into the pixels, and copies no
metadata — so a *converted* image carries no location. A JPEG / PNG / GIF / WebP passes through
untouched, EXIF (and GPS) included; Photos' share-sheet Options → Location is what controls that.

**Not every sender has a file.** When `loadFileRepresentation` yields none (the screenshot editor,
an app sharing a `UIImage`), the extension falls back to `loadItem`, inside the same handler: a
file URL is copied, `Data` written, a `UIImage` encoded as JPEG.

It then opens `invoiceninja://share` by walking the responder chain to the process's
`UIApplication` and calling `open(_:options:completionHandler:)` (`UIApplication.shared` is
unavailable to extensions; `open` is not marked extension-unavailable in the iOS 26.4 SDK — the
same approach current share plugins took after iOS 18 stopped honouring `openURL:`). Opening the
containing app is not a promised API (Apple's extension guide reserves it for Today widgets — an
App Review risk accepted for the smoother flow), so the design never depends on it: the app
**also pulls on every resume**, and if `open` says no — or neither it nor the host app going to the
background (`NSExtensionHostDidEnterBackground`, which settles a slow cold start whose answer is
late) has happened within 3 s — the extension tells the user to open the app, by its home-screen
name (the containing app's `CFBundleDisplayName`, "Ninja Beta" — not the share sheet's "Invoice
Ninja"). The URL carries nothing; `AppDeepLinks` recognises it
(`isShareHandoffLink`) and pulls instead of handing it to `DeepLinkRouter`, which would toast
`invalid_url`.

## The handover is a pull

Both native sides only *queue*; Dart's `AppShareIntake` pulls (`takeShares`) at construction (the
cold-start share), on Android's `sharesAvailable` ping (`onNewIntent`), on every
`AppLifecycleState.resumed`, and on the iOS hand-off URL. A push would race Dart's handler
registration on a cold start; a pull doesn't care when the share arrived. Pulls are serialised and
an empty queue is a no-op, so the redundant triggers cost nothing.

## Arrival waits behind the same gate as a deep link

`SharedFileIntake` is `DeepLinkRouter`'s sibling and shares its `ArrivalGate`: held while signed
out, biometric-locked or — share only — while the company still needs `/setup` (the router would
redirect New Expense there and the share would be lost); replayed in the frame after the gate
opens. A share before `attach` or before the first frame is held too. The gate listens to
`credentials` as well as `session` for the reason given on `ArrivalGate` (session is assigned
first).

**A held share belongs to whoever signs in next.** The session's end is split in two:
`endSession()` (from `onBeforeLogout`) aborts a share being handled — one waiting on the
unsaved-changes prompt included — but keeps the held ones; `dropHeld()` (from `onSessionReset`,
which only a real `logout()` runs) deletes them, together with any create draft staged but never
opened (`Services.clearStagedCreateDraft`). The difference matters because the identity-change
wipe — a different user signing in on this device — runs `onBeforeLogout` but not
`onSessionReset`, then purges the folder sparing `SharedFileIntake.heldPaths`.

Then, in order: the dashboard's create gate (`quickCreateEntities` — route, module,
`create_expense`), refused with `module_disabled_notice` when the Expenses module is off and
`not_allowed` otherwise; the attachments gate (`AuthSession.canAttachDocuments` — Enterprise on
hosted, trial-aware; the one copy the Documents tab, New Expense's card and the intake share):
without it New Expense still opens, but with no files and no Documents card
(`showsExpenseDocumentsCard` — no upsell on every new expense), and a `requires_an_enterprise_plan`
toast says why the receipt didn't come along; validation through `validateDocumentSources` (after
`SharedIntakeFiles.owns`), so the reject toasts are the words every upload surface uses.

**A New Expense already open takes the files.** Start an expense, go to Photos, share the
receipt: the open form registers itself (`registerAttachTarget`, from its view model, with its
company) and the files are added to it — no prompt, no lost draft. Two exceptions send the share
to a New Expense of its own instead:

- **The form belongs to another company.** The create screen binds its company once, at mount,
  and a company switch keeps other branches' stacks (`BranchCompanyGate` resets one only on
  re-entry), so a New Expense left open in company A is still registered after switching to B —
  joining it would save the receipt into A. Staging bumps the seed generation, which re-keys that
  stale page. It is always clean: the unsaved-changes guard covers offstage editors, so a dirty
  one prompted at the switch.
- **The form can't take files** (`addDocuments` returns false): its create is `unconfirmed` (the
  card is locked) or the record already exists (every later Save is refused). A save merely *in
  flight* still takes them — see "Uploads queue against the `tmp_` id".

Otherwise the app-wide unsaved-changes guard
runs (its Discard clears the dirty editor, so the edit route's own `onExit` doesn't prompt a
second time), then the files are staged for a fresh New Expense. A second share before that form
has mounted is staged together with the first rather than replacing it. If the prompt goes away
because the app locked, not because the user said no, the share is held for the unlock. Every
exit that doesn't hand the files to a form deletes them.

## The server's upload rule decides what gets converted

`App\Http\Requests\Request::$file_validation` is
`mimes:png,ai,jpeg,tiff,pdf,gif,psd,txt,doc,xls,ppt,xlsx,docx,pptx,webp,xml,zip,csv,ods,odt,odp,txt`
— no `heic`, `heif`, `bmp` or `svg`, and Laravel's `mimes` rule checks the content's guessed type.
A HEIC from an iPhone or a Samsung camera would queue fine and die as a 422 on upload. (TIFF the
server takes, but the app's own `kDocumentAllowedExtensions` doesn't.) So both native sides
re-encode any image that isn't JPEG / PNG / GIF / WebP as JPEG, keeping orientation:
Android via `ImageDecoder` (API 28+, long edge 4096; `BitmapFactory` before that, which can't read
HEIF; a bitmap `compress` can't encode, like 10-bit, is converted first, and a failed encode is
reported, not passed on as an empty file), iOS via the thumbnail path above. An image neither can
decode (SVG) comes back as `issue: unsupported` and is toasted as an invalid file type. Over 25 MB
(`kDocumentMaxBytes`) the copy is abandoned as `tooLarge`.

## The copies outlive the form, and only `SharedIntakeFiles` deletes them

A copy is what an outbox upload row's `local_path` names, and the native upload handler
dead-letters a row whose file is gone ("The attached file is no longer available…"). The
invariants live in `SharedIntakeFiles`, not in its callers:

- **Never outside the folder** (`p.isWithin`): a file the user picked from their own storage is
  never touched.
- **Never one an outbox row names.** `delete` checks `OutboxDao.referencedLocalPaths` (any state
  — a dead row can still be re-sent) and skips those copies, so a form, a discard or an intake
  exit can hand back whatever it held without having to know what was queued.
- **Gone once uploaded.** `deleteUploaded` runs from the expense upload handler
  (`documentMutationHandlers`' `onUploaded`) right after a successful upload — a receipt is
  personal data, and otherwise lingered until a later sweep. It skips the row check: the row naming
  it is the one completing.
- **Matched by `<uuid>/<name>`**, not by absolute path: a row's `local_path` is absolute, and the
  prefix can move under it (an iOS data container on an app update; `/var` vs `/private/var`).
  The upload itself goes through the same key: `SharedIntakeFiles.resolve` (the expense upload
  handler's `resolveSource`) re-finds a copy whose queued path no longer exists under today's
  root, so a receipt queued offline survives an App Store update.
- `sweep` runs once per launch (`main.dart`) and deletes `<uuid>` folders older than 24 h that no
  row references. 24 h is safe because a `/x/new` form is never restored across launches.
- `purgeAll` runs on `LocalDataDisposer.wipeAll`, after the rows are gone (a shared receipt is the
  account's data), sparing `SharedFileIntake.heldPaths` — see the gate section.

## Uploads queue against the `tmp_` id — and the form's list is the truth

New Expense's Documents card holds files before the expense exists. On Save,
`ExpenseEditViewModel.performSave` creates the record, then queues one `documentUpload` per file
under its `tmp_` id. The outbox already supports this chain: `hasEarlierActiveRowForEntity` holds
an upload behind its record's create, and `rewriteTempIdInPayloads` rewrites `entity_id` once the
create lands (`sync_repository_test.dart` "an upload queued against a record that does not exist
yet…"). A later re-save can't drop the uploads: `dedupPendingMutations` replaces create/update
rows only.

**The outbox rows can't be the truth for a create form; its list is.** A 422 on the create runs
`_failTmpDependents(…, failed)`, which marks every pending row naming the temp id dead — the
uploads included — and nothing revives them: the re-sent create's landing re-keys dead rows but
leaves them dead, and `deleteOlderDeadSaves` skips uploads. The save-failed banner's Discard goes
further: on a record the server never saw it deletes every row with it (the ghost path) and
clears `recoveryTempId`, so the next Save mints a new temp id. And the user may add or remove files
in between. So every create attempt queues exactly the form's `documents`, through
`BaseEntityRepository.replaceUnsentDocumentUploads`: in one transaction it deletes the record's
`pending` / `dead` uploads (`OutboxDao.unsentUploadsForEntity`; never `in_flight` / `unconfirmed`,
which an unresolved temp id can't have) and enqueues the list — **after** the create, so the same
drain pass sends them once it lands. (Re-arming the old rows in place would not do: they are older
than the re-sent create, so the pass defers them on the unresolved temp id, and `drainOnce` runs
one pass per kick — they'd wait for the next trigger, days on a desktop left open.) The list is
snapshotted before `repo.create` — a dispose during it (a sign-out, the `/new` route re-keyed)
clears the list, and neither it nor a reset hands copies back while a save is out — and cleared
only when a save succeeds. A file removed after a failed attempt is handed back once the next
attempt's replace drops the row that still named it.

The card locks while a save is in flight, waiting on the user, or refused as already created, so
the user can't make it drift from what an attempt queued. **A file *shared* in mid-save still
lands**: the save can wait up to 30 s on the server, and the share comes from outside the form.
It missed that attempt's batch, so `save()` queues it after, under the attempt's `tmp_` id, when
the attempt's create row stands (saved, or `unconfirmed`); otherwise (a 422, a 5xx) it stays on
the form for the next attempt. A late `tmp_` reference is safe even once the create has landed:
`SyncRepository._healResolvedTempRefs` rewrites it through `id_remap`.

Two other ways back to a failed create keep the uploads alive too: an edit form reopened from the
Outbox to re-send it holds no files of its own, so it moves the earlier attempt's uploads behind
its create (`requeueUnsentDocumentUploads`); and Retry on the dead create in the Outbox re-arms
its dead uploads with it (`OutboxDao.retryDeadUploadsFor` — they were queued after the create,
so ordering is already right).

**A rejected create is one error, not one per attachment.** `_failTmpDependents` doesn't announce
a dead upload of the parent record itself (`announce: false` for `dep.entityId == parentTmpId`
and an upload): each would otherwise raise its own `DeadEvent` — a "Could not save" modal plus
toasts — on top of the form's inline error.

## iOS signing and the Apple portal

The extension is a second signed target (`com.invoiceninja.admin.ShareExtension`) with the App
Group `group.com.invoiceninja.admin` on both App IDs. Local Automatic signing registers both on
first build — for an account with the Admin or App Manager role. CI signs manually, and a
`PROVISIONING_PROFILE_SPECIFIER` on the `xcodebuild` command line applies to every target — so
`tools/ci_ios_target_profiles.rb` pins each target's profile in the runner's copy of the project
instead, and `ios/ExportOptions.plist` maps both bundle ids. **macOS shares the
`com.invoiceninja.admin` App ID** (`macos/Runner/Configs/AppInfo.xcconfig`), so enabling App
Groups on it invalidates the macOS App Store profile too. The portal steps and the new secret are
in `docs/store-deployment-setup.md` §3E.

The Runner embeds the extension in an "Embed Foundation Extensions" phase ordered **before**
Flutter's "Thin Binary" script — the documented fix for Xcode's "Cycle inside Runner" with app
extensions; `share_target_wiring_test.dart` pins the order. The extension inherits the project's
deployment target, and its version comes from `$(FLUTTER_BUILD_NAME)` / `$(FLUTTER_BUILD_NUMBER)`
via `ShareExtension.xcconfig` (`#include? "../Flutter/Generated.xcconfig"`), because App Store
validation rejects an extension whose version differs from the app's.

## Known and accepted

- **Sharing from Invoice Ninja to itself** — a PDF from the app's own share sheet, sent back
  into it — is refused by the file-theft guard (the URI is one of this app's own providers) and
  reads as "You can't upload files of this type." Harmless; the guard is the point.
- **URIs the app can read through its own grants** (MediaStore with a storage permission, SAF
  grants) aren't refused by that guard. Bounded: the user sees the file on the form and has to
  tap Save.
- **A shared-file form stays dirty after every file is removed.** It was staged with an
  `emptyExpense()` seed, which marks the form prefilled. Minor.
- **The share lands in the active company**, and nothing on the form says which one.
- **`CreateAlreadyLandedException` during a re-save** strands files attached after the failure
  (the form takes no shares from then on). Rare.
- **Leaving a failed save with Discard** leaves its copies until the boot sweep: the form resets
  (handing them back while the dead rows still name them) before `discardFailedSave` deletes the
  rows.
- **Discarding an `unconfirmed` create** (it may already exist on the server) leaves its uploads
  dead under the old temp id; the form queues the files again under the new one, and the old rows
  send only if retried from the Outbox.
- **The tmp expense's Documents tab says "save to upload" while its uploads are queued** — it
  needs an outbox count to say better.
- **iOS display names**: "Ninja Beta" on the home screen, "Invoice Ninja" in the share sheet. The
  open-the-app hint uses the home-screen name; the failure alert names the share-sheet entry the
  user just tapped. Neither is localized.
- **The CI profile script needs the `xcodeproj` gem.** It ships with CocoaPods; the step installs
  it if it is ever missing.
- **A picked file's pending upload can still lose its file across an iOS update** — `resolve`
  only re-finds the shared-intake copies.
- **A held share is lost on process death.** Dart empties the native queue when it pulls; a share
  then held behind the gate (signed out, locked, `/setup`) lives only in that isolate. The same is
  true of a held deep link.
- **Past the 20th file, the rest of a share is dropped** without a notice.
- **App Review**: the review account needs attachments (Enterprise on hosted), or the reviewer sees
  New Expense with no files and the enterprise-plan toast.
