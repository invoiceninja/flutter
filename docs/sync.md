# Sync — the non-obvious rules, with evidence

Companion to CLAUDE.md § Sync — non-obvious rules. The main file still states all 28 rules, one line each — it is the most-cited anchor in the repo. This doc carries the evidence behind the eighteen that needed more than a line: the status-code map, the cursor and paging gates, the company-token guard, and the offline-retry policy.

## A discard abandons the row, not the entity

**A discard abandons the *row*, not the *entity*.** `SyncRepository.discardOutboxRow` clears the record's local `is_dirty` once no `pending`/`in_flight` row is left for it — but `hasActiveRowsForEntity` cannot see a **dead** row, and a dead edit's dirty flag is what stops the next refresh (`upsertAllPreservingDirty` skips dirty ids) from clobbering the unsaved work the `SaveFailedBanner` is asking the user to retry. That was fine while the only discardable rows were the entity's own edits; it stopped being fine when `add_comment` shipped a Delete on eleven detail screens, because a note is enqueued under the **parent's** `entity_type`/`entity_id`, so discarding a queued comment released a dead edit's flag. `_reconcileDiscardedDirty` now carries the same `hasEditRowForEntity` guard as its sibling `_releaseDeadLifecycleDirty` (whose name is historical — it started as the three lifecycle verbs and now releases for every kind EXCEPT `create` / `update`, because `bulk_update` was falling through both it and `_clearReorderDirty` and freezing every row a bulk column edit touched). Unconditional, because the caller deletes the row *before* reconciling — so the probe can never match the row being discarded, and abandoning an entity's only dead edit still clears as it always did. The same row-vs-entity split decides **which row** `SaveFailedBanner`'s *Discard failed save* may abandon when the VM holds no cached id: `OutboxDao.findDiscardableForEntity` takes the newest `create`/`update` for that record in state `dead` **or** `pending` — never `in_flight` (`discardOutboxRow` deletes such a row while leaving its request on the wire), and never another kind, since a queued `add_comment` on the same record is unrelated user work. `findDeadForEntity` is the wrong query there and was the bug: only a 422 kills a row, so a 5xx or a lost connection leaves the banner up over a `pending` row that the dead-only lookup cannot see — the tap cleared the banner and left the write to apply anyway. Both edit scaffolds share it.

## 412 Precondition Failed means password-required

**412 Precondition Failed = password-required.** Body is `{"message":"Invalid Password", …}`. `ApiClient._raiseFromResponse` maps it to `PasswordRequiredException`; `SyncEventListener` surfaces `ConfirmPasswordSheet` for outbox-parked mutations. The 403 password-message sniff stays as a defensive fallback. `GET /api/v1/users/{id}` is 412-gated — User Details routes around it via `/refresh` (see § Strict rules). **`PasswordRequiredEvent` fires on a row's FIRST 412 only**, and the row then walks the normal backoff to `dead` — the sheet does no server-side validation, so re-prompting every retry turned a cancel (or a typo, or an OAuth-only account with no password) into a modal every 5 minutes forever. `OutboxDao.readyPasswordRows` resurrects `dead` + `requires_password` + 412 rows so a password supplied later still heals them.

## A rejected company token fails the switch, not the session

**A rejected *company* token fails the switch, not the session.** A company switch installs a per-company token that has never been validated and then immediately fans out ~14 requests, so the first 401 arrived under the *live* credential set — indistinguishable from a genuine revocation, and escalated to a destructive global logout. That was the "logged out on every company switch" bug. `ApiClient` now consults `onUnauthorizedCandidate` (→ `AuthRepository.handleUnauthorized`) before `onUnauthorized`; returning false absorbs the 401. It refuses exactly one case — a 401 whose `creds.companyId` matches a company still on probation (`_unprovenActivation`, armed only by `_activateCompany`'s `switchCompany` callers, never by `restore`/login) — and responds by dropping the dead token, rolling back to the company it came from, and spending **one** self-heal `/refresh` to retry. A second rejection reports via `companySwitchRejected` (the shell raises the existing `failed_to_switch_company` toast); it never logs out. Four things are load-bearing: (1) the **rollback must fully complete inside the veto**, because once it returns `_logoutFuture` clears and the rest of the fan-out's 401s are only swallowed by the existing `isStaleCredential` guard — which works solely because `_credentials` no longer holds the rejected token; (2) the heal must be kicked **out of band** (`unawaited(Future(...))`), or its own 401 lands inside that same single-flight and is silently coalesced; (3) a **throwing veto falls through to logout** — absorbing a 401 must be an affirmative decision, never a side effect of an error; (4) `markCredentialProven` (wired to `onAuthenticatedResponse`) retires probation on the first 2xx, so a token revoked *later* logs out immediately instead of costing a spurious rollback. `ApiCredentials.companyId` exists for this and must never gain an `operator ==` (it lives in the router's `refreshListenable`).

## A forced logout logs a WARNING naming the request

**A forced logout logs a WARNING naming the request.** `logout()` and the 401→logout branch of `_postFlight` used to be completely silent, so the app's only involuntary session-ending path left no trace in the diagnostics log — it surfaced only as the unattributable downstream `Not authenticated` failures of whatever ran next. `_postFlight` takes `method` + `uri` purely to name the culprit; tokens are logged as an 8-char SHA-256 fingerprint and the query string is dropped (it can carry a user's `filter=`). The **stale-credential** branch deliberately stays at `fine` so switch-race noise stays off disk — `api_client_test.dart` pins both.

## The server does not 404 for a missing entity — it 400s

**This server does not 404 for a missing entity — it 400s.** `app/Exceptions/Handler.php` renders `ModelNotFoundException` as **400** `{"message":"No query results for model [App\\Models\\Quote] <id>"}` and emits **404 only** for `NotFoundHttpException` / `MethodNotAllowedHttpException` (`"Route does not exist"` / `"Method not supported for this route"`) — i.e. a 404 means *we* built a bad URL or verb. So `ApiClient._raiseFromResponse` sniffs the 400 body (`kEntityMissingMessageFragment`) to raise `NotFoundException`, and a bare 404 is a plain permanent `ServerException`. Getting this backwards was invoiceninja/flutter#36: any 404 opened the "record deleted on the server" sheet whose only forward option, Discard, **hard-deletes the local row** (`SyncEventListener._handleConflict` → `deleteLocalRecord`) — a client-side routing bug that destroyed user data. That branch is now gated on the explicit `ConflictEvent.isDeletedServerSide` flag, never on a status code; keep it that way. Entity-missing on drain still parks as a conflict (sheet: "delete locally" / "recreate"); on a delete/purge/archive the dispatcher still treats it as idempotent success.

## A soft-deleted record can't be edited; an archived one can

**A soft-deleted record can't be edited; an archived one can.** The server's guard (`ChecksEntityStatus::entityIsDeleted`, in 19 controllers) reads `is_deleted` **only**, so `PUT` on an *archived* row returns 200 and stays archived (verified live) — never add a client-side gate on editing archived records. A *deleted* row gets **400** `{"message":"Record is deleted and cannot be edited. Restore the record to enable editing"}` → `RecordDeletedException` → the row is marked dead carrying that message, and both the Outbox row and `SaveFailedBanner` drop the futile Retry and show the server's instruction. `isRecordDeletedRejection(statusCode, message)` re-derives this from a persisted row.

## A rejected save must never be a dead end

**A rejected save must never be a dead end.** `SaveFailedBanner` renders whenever the VM holds a rejection (not just when `fieldErrors` is non-empty), always states the reason (`submitError` + every field-error message, including keys no field on the form renders), and offers **Retry** beside Discard. `GenericEditViewModel` keeps the 422's top-level message instead of nulling it, and `_hydrateFailedSync` replays a dead row's `last_error` / `last_status_code`, not only its `field_errors_json` — otherwise a non-422 death left the reopened form looking clean.

## Server-side list ordering and the cursor

**Server-side list ordering / cursor.** `ApiClient.getList` reads `data.last` as a keyset high-water mark (`updated_at` + `id`). Caveat verified against the server source: the default list order is actually `id DESC` (`QueryFilters::ensureDefaultOrder`), **not** ascending `updated_at`, and `since_id` has no server handler — so the load-bearing paging mechanism is plain **offset** (`page`/`per_page`), and the cursor's `updated_at` is applied only as a `>=` delta filter (it narrows, never reorders). Page-by-page lists converge via id-keyed upserts + periodic full `refreshAll`; don't assume the cursor alone guarantees completeness.

## A narrowed fetch neither reads nor advances the cursor

**A narrowed fetch neither reads nor advances the cursor** — one predicate, `BaseEntityRepository.isNarrowedFetch`, backs both `shouldReadCursor` and `shouldAdvanceCursor`. Narrowing = parent scope, active search, any non-empty `extraFilters`, or a `states` set that isn't a baseline (`{active}`, `{}`, or all-states). Reading the cursor on a narrowed page ANDs `updated_at >= W` onto the user's filter, so the server returns only slice rows changed since the last sync — and after a Sync (W ≈ now) essentially nothing, leaving a false "No records found" a short list has no scroll extent to page out of. Advancing from one walks the shared watermark past rows the filter excluded. **No repo hand-rolls `ensurePageLoaded` any more** — all 28 delegate to `ensurePageLoadedTemplate`, which is the only place the gate expression exists. Six used to (invoice, quote, credit, recurring invoice, purchase order, group setting), each carrying a ~95-line copy that differed from the template only in its DAO name; five of them also carried a comment reading "same gate as `ensurePageLoadedTemplate`" while never calling it. `list_pagination_wiring_test` now fails the build on a repo that declares `ensurePageLoaded` without delegating — it matches the CALL, not the import, for exactly that reason. The two gates disagreed once and that was flutter#32.

## `hasMore` is not the gate for widening the Drift window

**`hasMore` is not the gate for widening the Drift window.** It answers "does the *server* have another page?", but the list renders entirely from Drift under `LIMIT pageSize * loadedPages` — so widening is gated on `GenericListViewModel.canLoadMore` (`hasMore || canWidenLocally`), where `canWidenLocally` means the last emission filled the window. Without it a filtered list latches `hasMore = false` early (a filter narrows the set, so page 2 comes back short) and can never widen again: a Sync lands rows in Drift the list can't reach, and only clearing the filter — which resets `loadedPages`/`hasMore` — brings them back. A local widen skips the network entirely. Under-counts for post-LIMIT filters (`tag_ids`, products `stock`), which converge via the auto-chain instead. A list VM's `pageSize` **must** equal its repo's (`=> repo.pageSize`) or the saturation check is wrong.

## A bulk re-download re-arms mounted lists

**A bulk re-download re-arms mounted lists.** `refreshAll` and the Sync pass write only to Drift; nothing else told a list VM its paging state was stale. `GenericListViewModel.bindResync` (wired by `EntityListScreenScaffold` in `initState` *and* `_onSessionChanged`) re-arms on the pass's falling edge for its own company, and `refresh()` does the same after pull-to-refresh. Re-arm only — never `_resetAndReload`, which would snap a deep-scrolled user back to page 1. Corollary invariant: **never call `resync.run()` from a `build`**, since every bound list VM notifies on that edge.

## Lists sort newest-first where the sort key is monotonic

**Lists sort newest-first where the sort key is monotonic.** `GenericListViewModel.defaultSortAscending` defaults to `true` (right for name/key-sorted lists); invoice / quote / credit / purchase order / recurring invoice (`number`), expense / payment / transaction (`date`), and task (`updatedAt`) override it to `false` so a new record lands on page 1 instead of the bottom of the list. Only affects a list the user has never sorted — a persisted `nav_state` blob or saved view always wins.

## A `tmp_` id is a display problem too, not just a wire problem

**A `tmp_` id is a *display* problem too, not just a wire problem.** `applyCreateResponseTemplate` inserts the real row and **deletes the tmp one** in a single transaction, so from the moment a create round-trips, every id the app is still holding names nothing. The wire is already safe (`SyncRepository._healResolvedTempRefs` rewrites queued payloads), which is exactly why this went unnoticed: a tag created inline on the Task screen rendered its chip as `tmp_1f3c…` for the life of the form, and only when online. So **any surface that renders a name from a stored id must resolve through `id_remap`** — `repo.watch(id)` already does (`watchByTempId` re-subscribes when the alias lands), which is why the `*NameLabel` widgets never had this; a *picker* resolving out of a materialized `items` list does not, and needs an alias map (`TagRepository.watchLookup` → `TagLookup`, built from `IdRemapDao.watchAliases`). Three corollaries. **No surface ever prints a raw id** — `ClientNameLabel` settled this ("a blank frame beats a flash of raw hashed id"), so it is a muted em dash plus `Semantics(label: id)`; `(no name)` is wrong here, since it means *resolved but nameless*. **The unresolved branch is reachable on the happy path**, because the tag row and the `id_remap` row are written in one commit and their two watches fire in no guaranteed order — so the placeholder is not defensive coding. And **comparisons must canonicalize while storage must not**: filtering a picker's pool by raw id re-offered a just-created tag under its new id and appended a second entry for the same tag, while a chip's ✕ has to remove exactly the id the draft holds. Correcting what is *stored* belongs at the repository save seam (`canonicalizeTagIds`, called from `Task`/`ProjectRepository` `create`/`save`, the only two entities with a denormalized `tag_names` sort key to repair), never from a widget: `GenericEditViewModel.isDirty` is `_draft != _original`, so an async draft rewrite makes a pristine form dirty and prompts to discard changes the user never made. **Residual, known:** the other twelve tag-bearing entities have no `TagNameResolver`, so a save made mid-drain still stores the dead `tmp_` id — display is healed by the lookup and the wire by `_healResolvedTempRefs`, but the *local* `tag:` filter mirror (`matchesTagIdFilter`, which compares raw ids) misses that row until the server echo lands.

## Offline never dead-letters

**Offline never dead-letters.** A `NetworkException` re-parks the row **budget-neutral** — `kOfflineRetryDelay` (60 s), `attempts` NOT incremented — because the normal backoff walks a row to `dead` after a handful of tries and "the user was on a train" is not a permanent rejection. A queued edit made in a tunnel used to be silently unsendable by the time they surfaced, with a `SaveFailedBanner` offering Retry on something that had never reached a server. Two consequences, both deliberate: the queue can hold a row indefinitely, so `pendingCountForCompany` stays non-zero and the logout / company-switch prompt keeps firing (right — that IS unsynced user work); and `NetworkException` also covers a **timeout**, so a payload that reliably times out re-fires every 60 s for ever. `pruneDeadRows` is the pressure valve for the `dead` side only; there is deliberately no age-based death on the offline side, because the one thing worse than a stuck row is a discarded edit.

## A page or mutation is bound to the company whose token fetched it

**A page or a mutation is bound to the company whose token fetched it, and the binding is a `throw`.** A company switch swaps the API token under ~14 in-flight requests; a response that lands after the swap carries company A's rows and would be written under company B's id by `upsertAllPreservingDirty(companyId:)`, which takes the id from the *caller*, not the payload. `BaseEntityRepository.companyStillActive()` + `CompanySwitchedException` guard the seam, applied once in `ensurePageLoadedTemplate` (every paginated repo now routes through it) and by hand only in `tag_repository`, which has no `ensurePageLoaded` at all — its `refreshAll` pages `api.list` directly across every entity type at once; `test/lint/company_scoped_write_guard_test.dart` fails the build on a repo that calls `upsertAllPreservingDirty` with neither. **It must stay an exception, not a bool** — both bool answers are wrong: returning "success" makes the list think it has a page it never wrote, and returning "failure" routes a benign switch into the retry / error machinery. The corollary is that every caller must expect it: `GenericListViewModel` swallows it as benign at `_flashError` **and** at all three `initialError` sites (a first-page or reset in flight is the likeliest way a user meets it, and it renders full-pane), the drain breaks the pass at `fine`, and `payment_unapplied_band`'s `_autoApplyOldest` had to gain a try/catch first — it discards its future from an `onPressed`, so the throw would have surfaced as an unhandled async error on a money action.

## A different identity on the same device wipes the local database

**A different identity on the same device wipes the local database, and only the login entry points check.** An involuntary logout (401, or an idle timeout with unsynced work) deliberately PRESERVES Drift — right for the same user coming back, and the only thing standing between one user's cached invoices, payments and drafts and the next person to sign in on a shared device. `_wipeIfIdentityChanged` compares the persisted `(userId, accountId, baseUrl)` against the incoming session and wipes on a difference; it runs from `login` / `oauthLogin` / `loginWithToken` / `signup` and deliberately **not** from `refresh()`, which is the same session. The predicate is conservative — both sides non-empty and different — so an upgrading install is never wiped and a same-user re-login keeps its outbox. `baseUrl` is in the tuple because self-hosted instances mint hashids from small sequential ids, so user #1 / account #1 on two different servers commonly encode identically.

## The server's rounding scale is a two-level map, not one precision

**The server's rounding scale is a two-level map, not one precision.** Line totals and the per-item tax base round at **2**; the subtotal and each grouped *line* tax round at the currency's `precision`; invoice-level tax tiers round at **2** and live in a **separate** map from the line-tax groups (`InvoiceSum::$total_tax_map` vs `$tax_map`), merged only for display — so a line tax and an invoice-level tax sharing a name ("VAT" on both, the normal case) must not be summed and re-rounded together. The final total is **not** re-rounded at precision. Deriving `taxAmount` and `total` from two different sums is how they came to contradict each other on a JPY invoice. Parity is proven, not argued: `tool/totals_oracle.php` runs the REAL `InvoiceSum` / `InvoiceItemSum` / their inclusive twins out of the canonical server checkout (dispatching on `uses_inclusive_taxes`, mirroring `Invoice::calc()`), and `test/domain/billing/totals_parity_test.dart` asserts `computeTotals` against it. Careful hand-derivation disagreed with the real code on one of four cases; a full green suite certified a cent-level error on the default currency. **Change nothing in `totals_calculator.dart` without running the oracle** — and note it reports as *skipped*, never passed, when the server source is absent.

## A Sync pass re-downloads the entity tables and nothing else

`Services.syncNow` pushes the outbox, then `resyncAllEntities` walks the fourteen types in
`_resyncSteps` — and for a long time that was the whole pass. Three caches hang off exactly the
rows it rewrites, and none of them were re-seeded, which shipped as
[invoiceninja/flutter#160](https://github.com/invoiceninja/flutter/issues/160): tapping **Sync
now** left the Activity screen showing pre-sync rows, and the AppBar refresh button was the only
way out. The reporter's users were told new information was available, checked Activity, and saw
nothing.

**Why it was a dead end rather than a delay.** `ActivityViewModel` calls `refresh()` only in its
constructor, and the shell is a `StatefulShellRoute.indexedStack` (`router.dart`) — so once
`/activity` has been visited the screen stays mounted for the whole session and that constructor
never runs again. Navigating away and back does not re-fetch. The dashboard's Activity card reads
the *same* `dashboard_cache` row (kind `activities`, filter hash `kDashboardListFilterHash`), so
both surfaces were stale together, and both are fixed by one write.

**The three caches, and why each needed its own line.**

1. **`dashboard_cache`** — server-fed rows, refreshed by `DashboardRepository.refreshListCards`.
   It covers all of `DashboardKind.listKinds`, not just `activities`: Past due, Upcoming invoices,
   Recent payments, Expired/Upcoming quotes and Upcoming recurring are the identical mechanism, so
   fixing activities alone would have left a stale card on the very screen beside the fixed one.
   The filter-keyed half (totals, chart, configured cards) is deliberately excluded — it is keyed
   by a `DashboardFilter` that is UI state owned by `DashboardViewModel`, and a caller with no
   dashboard mounted would have to invent one and would write a row under a hash nothing watches.
   Those keep the dashboard's own Refresh button.
2. **`ActivitiesApi._feedCache`** — the in-memory per-record feed behind the Activity / Comments
   tabs, dropped with `clearCache()`. This fixes the *next* record opened; a tab already on screen
   is not repainted, because `EntityActivityViewModel` has no Drift subscription for synced rows
   (it re-kicks only on an outbox tick for its own record). Doing that properly needs a broadcast
   sync-generation notifier, which is not built.
3. **The memoized `Formatter` and the resolved-settings cascade** — `invalidateFormatter` /
   `settings.clearResolvedCache`. `invalidateFormatter`'s own contract is "call after writing the
   company's settings **or after a statics refresh**", and the pass does both:
   `auth.refresh(fullSync: true)` sends `include_static=true` and rewrites the `companies` row,
   and `company.refresh` rewrites it again. Nothing else covers it —
   `CompanyRepository.onSettingsWritten` fires only on a local *save*, and the company-activation
   warm-up hooks are gated on an actual company *change*, so a pass for the current company
   re-runs none of them. Without these two lines a date format or currency changed on another
   device downloads but never renders until logout or a company switch.

**Why the tail runs last.** The rows the user is chasing are written by server-side queued jobs
the push kicks off — an email send logs its activity when the job runs, not when the HTTP request
returns — so `flushNow` returning is not "the rows exist". The later the 250-row window
(`kActivityFeedRows`) is taken, the more of them it holds; running it first is the position most
likely to miss the very rows in the bug report. It also keeps the cards consistent with the entity
tables the pass just rewrote, and lets cancellation fall out for free. Same precedent as
`contactsSync.run`, which runs "off the back of the pass that just refreshed the data it reads".

**Why it is best-effort, and excluded from the failed-entity list.** `syncNow`'s return value names
*entity* downloads that failed and drives the `sync_failed` toast. A 500 from one dashboard card
endpoint is not an entity download failure and must not report the whole sync as failed, so
`refreshListCards`' per-kind errors are logged and swallowed. `refreshListCards` folds failures
into a map rather than throwing; the `try` around it guards that contract changing.

**Why `onProgress`'s `total` is not extended by one.** `total` is the module-filtered *entity*
plan and is what the failed-entity list is counted against; a phantom step would make
`resyncAllEntities` report a step it does not own. While the tail runs, progress is parked at
`(n, n)` and the pass is still `isRunning`, so the Sync button stays inert and spinning — and its
spinner is indeterminate on purpose even once `total` is known. This is already the status quo:
`contactsSync.run` has run past 100% since it shipped.

**The residual company-switch window.** The list-card fetches are issued in parallel, so there is
no boundary to poll `isCancelled` at once they are on the wire; a switch landing mid-flight files
the new company's rows under the old id. `resync.cancel()` on a company switch plus the tail's
pre-flight poll leave roughly a 1–2 s window, and `dashboard_cache` is a single overwritable
snapshot per `(company, kind, hash)` rather than an accumulating table, so the next refresh
repairs it — worst observable symptom is one frame of the wrong company's rows.
`company_scoped_write_guard_test` does not catch this: it fires only on repos calling
`upsertAllPreservingDirty`, and `DashboardRepository` writes via `_dao.upsert`. Closing it properly
means giving that repo the `activeCompanyId` / `companyStillActive` hook every entity repo has.

**One concurrency trap the fix had to design around.** `refreshAll` and `refreshFilterKeyed` each
used to construct their own `_Semaphore(_maxConcurrent)`, so writing `refreshAll` as "filter-keyed,
then list cards" would have silently run the dashboard at a multiple of the cap — invisible in
review, visible only as a burst of parallel requests on a slow connection. Only one private driver
(`_runJobs`) may construct a semaphore now; the public methods compose *job lists*, never each
other. `dashboard_repository_test` pins it with a peak-in-flight counter, asserted two-sidedly so
it cannot pass vacuously. Note the cap is on *jobs*: `refreshTotals` deliberately fires its current
and previous periods in parallel inside its single slot, so the fetch-level peak sits exactly one
above the job-level cap.

**A note for whoever debugs a test fixture later.** A Sync pass now also issues
`/api/v1/activities` and the six sibling card paths (`/api/v1/invoices`, `/api/v1/payments`,
`/api/v1/quotes`, `/api/v1/recurring_invoices`), so a strict `MockClient` that 404s unknown paths
will see them where it previously did not.
