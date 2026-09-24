# Sync — the non-obvious rules, with evidence

Companion to CLAUDE.md § Sync — non-obvious rules. The main file still states all 34 rules, one line each — it is the most-cited anchor in the repo. This doc carries the evidence behind the twenty-five that needed more than a line: the status-code map, the cursor and paging gates, the company-token guard, the offline-retry policy, and what a retry may safely repeat.

## A discard abandons the row, not the entity

**A discard abandons the *row*, not the *entity*.** `SyncRepository.discardOutboxRow` clears the record's local `is_dirty` once no `pending`/`in_flight` row is left for it — but `hasActiveRowsForEntity` cannot see a **dead** row, and a dead edit's dirty flag is what stops the next refresh (`upsertAllPreservingDirty` skips dirty ids) from clobbering the unsaved work the `SaveFailedBanner` is asking the user to retry. That was fine while the only discardable rows were the entity's own edits; it stopped being fine when `add_comment` shipped a Delete on eleven detail screens, because a note is enqueued under the **parent's** `entity_type`/`entity_id`, so discarding a queued comment released a dead edit's flag. `_reconcileDiscardedDirty` now carries the same `hasEditRowForEntity` guard as its sibling `_releaseDeadLifecycleDirty` (whose name is historical — it started as the three lifecycle verbs and now releases for every kind EXCEPT `create` / `update`, because `bulk_update` was falling through both it and `_clearReorderDirty` and freezing every row a bulk column edit touched). Unconditional, because the caller deletes the row *before* reconciling — so the probe can never match the row being discarded, and abandoning an entity's only dead edit still clears as it always did. The same row-vs-entity split decides **which row** `SaveFailedBanner`'s *Discard failed save* may abandon when the VM holds no cached id: `OutboxDao.findDiscardableForEntity` takes the newest `create`/`update` for that record in state `dead` **or** `pending` — never `in_flight` (`discardOutboxRow` deletes such a row while leaving its request on the wire), and never another kind, since a queued `add_comment` on the same record is unrelated user work. `findDeadForEntity` is the wrong query there and was the bug: only a 422 kills a row, so a 5xx or a lost connection leaves the banner up over a `pending` row that the dead-only lookup cannot see — the tap cleared the banner and left the write to apply anyway. Both edit scaffolds share it.

## 412 Precondition Failed means password-required

**412 Precondition Failed = password-required.** Body is `{"message":"Invalid Password", …}`. `ApiClient._raiseFromResponse` maps it to `PasswordRequiredException`; `SyncEventListener` surfaces `ConfirmPasswordSheet` for outbox-parked mutations. The 403 password-message sniff stays as a defensive fallback. `GET /api/v1/users/{id}` is 412-gated — User Details routes around it via `/refresh` (see § Strict rules). **`PasswordRequiredEvent` fires on a row's FIRST 412 only**, and the row then walks the normal backoff to `dead` — the sheet does no server-side validation, so re-prompting every retry turned a cancel (or a typo, or an OAuth-only account with no password) into a modal every 5 minutes forever. `OutboxDao.readyPasswordRows` resurrects `dead` + `requires_password` + 412 rows so a password supplied later still heals them.

## A rejected company token fails the switch, not the session

**A rejected *company* token fails the switch, not the session.** A company switch installs a per-company token that has never been validated and then immediately fans out ~14 requests, so the first 401 arrived under the *live* credential set — indistinguishable from a genuine revocation, and escalated to a destructive global logout. That was the "logged out on every company switch" bug. `ApiClient` now consults `onUnauthorizedCandidate` (→ `AuthRepository.handleUnauthorized`) before `onUnauthorized`; returning false absorbs the 401. It refuses exactly one case — a 401 whose `creds.companyId` matches a company still on probation (`_unprovenActivation`, armed only by `_activateCompany`'s `switchCompany` callers, never by `restore`/login) — and responds by dropping the dead token, rolling back to the company it came from, and spending **one** self-heal `/refresh` to retry. A second rejection reports via `companySwitchRejected` (the shell raises the existing `failed_to_switch_company` toast); it never logs out. Four things are load-bearing: (1) the **rollback must fully complete inside the veto**, because once it returns `_logoutFuture` clears and the rest of the fan-out's 401s are only swallowed by the existing `isStaleCredential` guard — which works solely because `_credentials` no longer holds the rejected token; (2) the heal must be kicked **out of band** (`unawaited(Future(...))`), or its own 401 lands inside that same single-flight and is silently coalesced; (3) a **throwing veto falls through to logout** — absorbing a 401 must be an affirmative decision, never a side effect of an error; (4) `markCredentialProven` (wired to `onAuthenticatedResponse`) retires probation on the first 2xx, so a token revoked *later* logs out immediately instead of costing a spurious rollback; (5) the handling runs **outside the request's `RequestScope`** (`RequestScope.outside` in `_postFlight`): a 401 on a drained outbox row started it inside that row's scope, so the heal's `/refresh`, under the rolled-back company's token, was refused by `_requireCreds` as a company switch and never ran. `ApiCredentials.companyId` exists for this and must never gain an `operator ==` (it lives in the router's `refreshListenable`).

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

**A bulk re-download re-arms mounted lists.** `refreshAll` and the Sync pass write only to Drift; nothing else told a list VM its paging state was stale. `GenericListViewModel.bindResync` (wired by `EntityListScreenScaffold` in `initState` *and* `_onSessionChanged`) re-arms on the pass's falling edge for its own company, and `refresh()` does the same after pull-to-refresh. Re-arm only — never `_resetAndReload`, which would snap a deep-scrolled user back to page 1. Corollary invariant: **never call `resync.run()` from a `build`**, since every bound list VM notifies on that edge. The edge also fires for a *cancelled* pass, so anything written to *fetch* once a pass is over listens to `lastCompletion` instead — see § A screen that refetches after a Sync pass listens to `lastCompletion`. The re-arm is local with one known exception: its `_resubscribe` can drive the post-LIMIT auto-chain (`_maybeAutoChain` → `loadMore`) on a `tag:` / `stock:` list, which pages — after a cancelled logout pass too, and the entity repos' `companyStillActive` treats signed-out as a no-op. Moving the list VMs onto `lastCompletion` is the follow-up.

## Lists sort newest-first where the sort key is monotonic

**Lists sort newest-first where the sort key is monotonic.** `GenericListViewModel.defaultSortAscending` defaults to `true` (right for name/key-sorted lists); invoice / quote / credit / purchase order / recurring invoice (`number`), expense / payment / transaction (`date`), and task (`updatedAt`) override it to `false` so a new record lands on page 1 instead of the bottom of the list. Only affects a list the user has never sorted — a persisted `nav_state` blob or saved view always wins.

## A `tmp_` id is a display problem too, not just a wire problem

**A `tmp_` id is a *display* problem too, not just a wire problem.** `applyCreateResponseTemplate` inserts the real row and **deletes the tmp one** in a single transaction, so from the moment a create round-trips, every id the app is still holding names nothing. The wire is already safe (`SyncRepository._healResolvedTempRefs` rewrites queued payloads), which is exactly why this went unnoticed: a tag created inline on the Task screen rendered its chip as `tmp_1f3c…` for the life of the form, and only when online. So **any surface that renders a name from a stored id must resolve through `id_remap`** — `repo.watch(id)` already does (`watchByTempId` re-subscribes when the alias lands), which is why the `*NameLabel` widgets never had this; a *picker* resolving out of a materialized `items` list does not, and needs an alias map (`TagRepository.watchLookup` → `TagLookup`, built from `IdRemapDao.watchAliases`). Three corollaries. **No surface ever prints a raw id** — `ClientNameLabel` settled this ("a blank frame beats a flash of raw hashed id"), so it is a muted em dash plus `Semantics(label: id)`; `(no name)` is wrong here, since it means *resolved but nameless*. **The unresolved branch is reachable on the happy path**, because the tag row and the `id_remap` row are written in one commit and their two watches fire in no guaranteed order — so the placeholder is not defensive coding. And **comparisons must canonicalize while storage must not**: filtering a picker's pool by raw id re-offered a just-created tag under its new id and appended a second entry for the same tag, while a chip's ✕ has to remove exactly the id the draft holds. Correcting what is *stored* belongs at the repository save seam (`canonicalizeTagIds`, called from `Task`/`ProjectRepository` `create`/`save`, the only two entities with a denormalized `tag_names` sort key to repair), never from a widget: `GenericEditViewModel.isDirty` is `_draft != _original`, so an async draft rewrite makes a pristine form dirty and prompts to discard changes the user never made. **Residual, known:** the other twelve tag-bearing entities have no `TagNameResolver`, so a save made mid-drain still stores the dead `tmp_` id — display is healed by the lookup and the wire by `_healResolvedTempRefs`, but the *local* `tag:` filter mirror (`matchesTagIdFilter`, which compares raw ids) misses that row until the server echo lands.

## Offline never dead-letters

**Offline never dead-letters.** A `NetworkException` re-parks the row **budget-neutral** — `kOfflineRetryDelay` (60 s), `attempts` NOT incremented — because the normal backoff walks a row to `dead` after a handful of tries and "the user was on a train" is not a permanent rejection. A queued edit made in a tunnel used to be silently unsendable by the time they surfaced, with a `SaveFailedBanner` offering Retry on something that had never reached a server. Two consequences, both deliberate: the queue can hold a row indefinitely, so `pendingCountForCompany` stays non-zero and the logout / company-switch prompt keeps firing (right — that IS unsynced user work); and `NetworkException` also covers a **timeout**, so a payload that reliably times out re-fires every 60 s for ever. The Outbox's old-failures notice (`pruneDeadRows`, on the user's tap) is the pressure valve for the `dead` side only; there is deliberately no age-based death on the offline side, because the one thing worse than a stuck row is a discarded edit.

## A retry is only as safe as what the endpoint does twice

**A retry is only as safe as what the endpoint does twice.** Every outbox request carries a stable `Idempotency-Key`, and the engine was built on the assumption that it makes a re-send harmless. The server never reads it (BACKEND.md § Server-side `Idempotency-Key` dedupe — only a 1-second body-hash lock on two endpoints), and self-hosted servers on older versions never will. So whether a row may be re-sent after an attempt whose outcome is unknown — a timeout after the request left, a dropped response, the app killed mid-attempt — depends on the endpoint, and `MutationKind.deliverySafety` (`lib/domain/sync/mutation.dart`) records it for all 64 kinds as a wildcard-free switch: `idempotent` (a PUT of the full record, a state flag, an absolute value), `serverGuarded` (a replay is refused or ignored), or `nonIdempotent` (a new record, another email, a charge or refund, a compounding `increase_prices`). `deliverySafetyFor(kind, payload)` can only make a row stricter — a save whose `__save_query` marks paid, auto-bills or sends, or a company update that adds a document. `sendEInvoice` is deliberately non-idempotent despite a server guard: the guard is racy and the effect is a second legal e-invoice. `test/domain/sync/mutation_delivery_safety_test.dart` pins every verdict; change one there, on purpose.

**A create is the one kind that leaves proof it landed.** `recordCreateSuccess` writes the `id_remap` entry in the same transaction that applies the server's response, and `_attempt` deletes the outbox row in a separate statement after it. A create still `in_flight` at drain start whose `tmp_` id already maps died in that gap, so `SyncRepository._recoverOrphanedInFlight` retires it instead of re-arming it — re-sending it re-created the record. Any other orphan whose replay would repeat its effect goes `unconfirmed` (§ A change that may already have gone through waits for the user); the rest are re-armed as before (`sync_repository_test` › rows orphaned in flight).

## A transport failure is "never sent" only when it can be proven

**A transport failure is "never sent" only when it can be proven.** `NetworkException` used to cover both "offline, never sent" and "timed out after the request went out", and the drain retried both — re-running any non-idempotent mutation whose response was lost. Now `RequestNotSentException` (a subtype, so every `on NetworkException` "you're offline" path is unchanged) is raised only on proof: the request's body was never read (`_BodyProbe` in `api_client.dart` — `IOClient` opens the connection, DNS/TCP/TLS, *before* reading the body, so a failure while it is unread never reached the server; web's `BrowserClient` reads the body before `fetch`, so there every failure stays unknown), or — on web only, where the body probe is blind — the drain saw the device offline just before the attempt (`RequestScope.offlineBeforeSend`, from `ConnectivityWatcher.isOnline` — used to classify, never to skip the attempt, because `connectivity_plus` misreports "none" on some setups and a gate would stall the outbox). Natively that reading used to count too, and a misreported "none" then turned a sent write whose response was lost into "never sent", re-sent; now `ApiClient(offlineMeansUnsent:)` defaults to `kIsWeb` and `Services` wires `sync.isOnline` on web only, which also drops a platform call per drained row natively — up to 5 s each when the D-Bus probe stalls under Snap. A plain `NetworkException` now means *outcome unknown* — what the drain does with one is § A change that may already have gone through waits for the user. A timeout **aborts** the request (`http.Abortable`), where `.timeout()` alone left it running to land after its row was re-queued. Native uses `connectionTimeout` 15 s and `idleTimeout` 4 s (`http_client_factory_io.dart`): the first makes an unreachable host fail while still provably unsent, the second stays under Apache's 5 s keep-alive so a request is never written onto a socket the server just closed (that race fails *after* the body is read). Any 2xx to a non-GET marks the attempt `RequestScope.committed` before anything else can throw — an undecodable body or the client-too-old header after a committed write is not a failed send. Pinned by `api_client_test` › never sent vs outcome unknown.

## A change that may already have gone through waits for the user

**A change that may already have gone through waits for the user.** An attempt whose outcome was unknown used to be retried like any failure, which for a non-idempotent row — a create, an email, a payment, a refund — risks doing it twice. `SyncRepository._attempt` now settles a failed attempt by what reached the server *before* it reads the exception:

- **The server accepted the write** (`RequestScope.committed`) → the change is done, whatever failed after it: decoding the reply, the client-too-old header (a 2xx carrying it used to re-park the row for an hour and send the write again, every hour), a follow-up read, applying the response, a company switch before the follow-up. No handler makes a second write — each is one write plus a read or a local step — so `_settleCommitted` deletes the row, releases the record's dirty flag and re-fetches it (`refreshRecord`, wired to the repo's `refreshByIds`). Except a create whose reply never reached `applyCreateResponse` (no `id_remap`): the server has the record under an id this device never learned, a re-send duplicates it and a delete strands the local copy and its dependents, so it goes `unconfirmed`.
- **A write went out with no answer** (`RequestScope.writeSent` without `committed`) — a plain `NetworkException`, a 500 / 502 / 504 / 520 / 524 (`kOutcomeUnknownStatuses`; a 503 means nothing ran), or an unclassified throw → a row whose replay repeats its effect (`deliverySafetyFor`) goes `unconfirmed`; the rest keep their old retry. A 500 that also carries the client-too-old header counts: `_postFlight` checks the header before the status, so `ClientTooOldException.statusCode` carries it to the drain, whose arm used to re-park every such row an hour out and send it again every hour. `writeSent` is set when the transport starts reading a non-GET's body, so a follow-up read failing, or a throw before the request, proves nothing changed.
- **Provably never sent** (`RequestNotSentException`) and every typed rejection (the 4xx arms) → unchanged. **Orphaned `in_flight` at drain start** → a non-idempotent row goes `unconfirmed`, after the create-with-remap check.

**`unconfirmed` is a state, not a retry schedule** (`OutboxState`; `outbox.state` is TEXT with no CHECK, so no migration). No drain sends it. It is left out of the "Sync first" counts with `dead` (`pendingCountForCompany`, `companiesWithActiveRows` — counting it would leave that button waiting forever) and counted with `dead` as needing the user (`attentionCountAll`, `watchAttentionCount` → the sidebar badge, and the full-sign-out review prompt). It **holds back later changes to the same record** in `hasEarlierActiveRowForEntity`, parked or not — unless it is a document upload (§ A document upload holds nothing back): Resend puts it back in line, and a full-record PUT sent ahead of it would then be overwritten by the older one. A row held behind one re-parks a minute at a time, budget untouched (`_drainOnceImpl`), because it waits on the user for as long as they take: left due, held rows came back in every 50-row `nextReady` snapshot and could starve everything queued after them. It counts as a local edit still in charge (`hasActiveRows*`), heals its temp ids without being re-armed (`rewriteTempIdInPayloads`), and a banner Discard may abandon it (`findDiscardableForEntity`).

**What the user sees.** `UnconfirmedEvent` (sealed `SyncEvent`) escalates like a death: a toast when an open form surfaces it, otherwise a modal while online. The Outbox tile says "May have been sent" and what to do, with **Check** (`SyncRepository.recheck` re-fetches the record, or for a create the newest page of its list, then opens it — the server-fetched Activity says whether the email went or the payment was recorded), **Resend** (always confirms, Cancel focused; same idempotency key, fresh budget) and Discard — never Retry. `awaitRow` returns `SyncRowOutcome.unconfirmed` at once, for the row itself or for one queued behind it (`unconfirmedRowAhead`), and the edit form stays open on `SaveFailedBanner`'s unconfirmed variant: Check / Resend / Discard for the record's own create or update, View for another change it waits behind; `hydrateUnconfirmed` restores it when the form reopens. A re-save of a new record whose create is unconfirmed throws `UnconfirmedPriorMutationException` from `dedupPendingMutations`, inside the save transaction, so it cannot queue a second create; Resend clears the hold but keeps the VM's `recoveryTempId`, or the next Save would mint a new one. **A resent create leaves its form** for the entity's list, as Check does, marked clean first (`markSaved`) so the route's exit guard doesn't ask to discard what was just sent: left open, a second Save queued another create while the resent one was in flight, or after it had landed under an id the form never learned — two records. The client quick-create dialog has no banner, so an unconfirmed create closes it with a warning toast and hands back no client. The banner's Discard abandons the unconfirmed save row ahead of any dead row cached when the form opened (`_resolveDiscardableRowId`), and the Outbox's Retry re-arms only a `dead` or `pending` row (`retryDead`), so a row that went unconfirmed while its menu was open is never re-sent without Resend's confirmation. **Discarding an unconfirmed create** drops its local record and rows as for a never-sent ghost, but what was made offline against it — an invoice for that client — is kept, dead, saying the record may already exist on the server (`_ParentGone.discardedUnconfirmed`): it used to cascade like a ghost and delete that work. The comment feed and the Sends tab show the state instead of a spinner that would never stop. Pinned by `sync_repository_test` › an outcome the server never confirmed, `outbox_dao_test` › unconfirmed rows, `outbox_screen_unconfirmed_test`, `save_failed_banner_test`, `generic_edit_view_model_test`, `sync_event_listener_test`, `confirm_pending_outbox_test`, `client_repository_test` › re-creating is refused, `save_failed_banner_resend_test`, `client_create_dialog_test` › a create that may already have gone through, and `settings_entity_edit_scaffold_save_failure_test` › Discard on a save held as unconfirmed.

## A document upload holds nothing back

**A document upload holds nothing back — no later save of its record, no `/refresh` of the company — because it writes no field of the record.** An `unconfirmed` row holds back later changes to its record (§ A change that may already have gone through waits for the user) because Resend would put an older full-record PUT behind a newer one. An upload can't do that: it attaches a document and changes no field. Yet uploads are the likeliest rows to go `unconfirmed` — large bodies, slow links, the request timing out after the body went out — and one used to hold every later save of its record until the user dealt with it in the Outbox. For the company that was silent and total: every settings screen saves the one company record, the settings save path shows no banner, and `hasActiveRowsFor` also made `/refresh` withhold the company's columns for as long as the upload waited. `isDocumentUploadRow` (`lib/domain/sync/mutation.dart`) names the rows — a `document_upload`, or the company's `update` whose payload carries `"_action":"upload_document"` (`kUploadDocumentActionJson`; `jsonEncode` escapes the quotes in a user's own text, so no field can forge it, and the codebase avoids `json_extract`) — and `OutboxDao._isDocumentUpload` is its SQL twin. Five places consult them, and they must agree: `hasEarlierActiveRowForEntity` and the drain's in-pass `blockedEntities` latch (the drain's own comment warns against two gates answering the same question differently), `unconfirmedRowAhead` and `findUnconfirmedForEntity` (which explain a held save — there is none to explain), and `hasActiveRowsFor` (the refresh skip). An upload still waits *behind* an earlier save, and behind its record's `tmp_` create. Check routes an upload to Company Details → Documents, and another user's `user` row to `/settings/users/<id>` rather than the signed-in user's own profile; `refreshRecord` fetches the company whole and re-reads users through `auth.refresh()` (the roster comes in the envelope; `GET /users/{id}` is 412-gated) — both used to be no-ops. Pinned by `outbox_dao_test` › a document upload holds nothing back, `sync_repository_test` › a document upload that fails holds back no later save, and `unconfirmed_row_destination_test`.

## A server copy never overwrites a newer queued edit

**A server copy never overwrites a newer queued edit.** Every `applyUpdateResponse` was a plain upsert with `is_dirty=false`, and `deletePendingForEntity` deliberately leaves an `in_flight` row alone — so with v1 in flight and v2 saved behind it, v1's echo put v1 back over the local v2 and cleared its dirty flag. If v2 then failed validation the edit form reopened on v1 and v2 survived only in the dead row's payload, breaking the invariant the failed-save flow rests on ("the local row is where the user's unsaved work lives"). Now every single-record server copy goes through `BaseEntityRepository.applyEchoTemplate`, which skips the write when `hasNewerLocalEdit` finds a create/update row for the record — pending, in flight or dead — newer than the row being dispatched. "Newer" is measured against the dispatching row only when that row is for the same record (`RequestScope.sourceRowId` / `isFor`; the drain sets them in `_attempt`); a response for a related record, or one applied outside the drain (`CompanyRepository.refresh`, `peppolSetupDirect`), yields to ANY queued edit — which also stops the Company Details refresh from overwriting a settings edit still in the outbox. A create response while an edit saved mid-create is queued re-keys the local `tmp_` row to the real id with its content intact (`BaseEntityDao.rekeyRow`, needs `localDao`) instead of replacing it — the `payload` JSON's `id` included, since `_fromRow` reads the model's id from the payload, not the column, and moving only the column left the record calling itself by its temp id; that path runs only while the drain dispatches that same create. Credit, purchase order and recurring invoice moved onto `applyCreateResponseTemplate` to get it. `test/lint/echo_apply_guard_test.dart` pins both routes; the repository contract (`_base_entity_repository_contract.dart` › a server copy never overwrites a newer queued edit) proves the behaviour for every registered repository. A test that simulates the drain confirming a save must apply the response inside the dispatch scope of that save's row (see `client_repository_test`'s `asDrainFor`).

## A failed change is still unsynced work

**A failed change is still unsynced work.** A `dead` row is a change the server rejected, parked together with its dirty local row so the edit form reopens onto it with a `SaveFailedBanner` (fix, then Retry). The logout / company-switch prompt counts only non-`dead` rows — right for its "Sync first" button, which cannot send a row the server refused — but every *involuntary* session end read that same count, so an idle timeout, a client-too-old sign-out, `restore()` finding no company rows, or a failed Danger Zone switch wiped rejected edits with no prompt at all. Now: `SyncRepository.hasUnsyncedWork()` reads `OutboxDao.companiesWithUnsyncedRows()` (any state), so idle timeout and client-too-old preserve the store for a dead row too; `AuthRepository.restore()` with missing account/company rows ends the session but keeps the store when the outbox holds anything (no re-lock gate — nothing was unlocked); Danger Zone's fallback logout keeps it when another company has unsynced work, and `restore()` now ignores a persisted company id that no longer names a company it holds (that fallback can leave one pointing at the deleted company). A full sign-out (`confirmPendingOutboxIfAny(checkAllCompanies: true)`) asks separately, after the pending prompt, about every row that needs the user — `dead`, and `unconfirmed` (§ A change that may already have gone through waits for the user) — with Cancel focused and View opening the Outbox; a company switch never does, because the database survives it. Pinned by `sync_repository_test` › hasUnsyncedWork, `auth_repository_test` › "a stale token with queued outbox work…", and `confirm_pending_outbox_test`.

## Local data is destroyed only by its owners

**Local data is destroyed only by its owners.** The store is the only home of the user's unsynced work, and a call that destroys it compiles, runs and passes every other test — the user just finds their changes gone. Three owners, pinned by `test/lint/local_data_disposal_test.dart` (which, run against the code before it, flagged six sites):

- **Whole-database and per-company wipes** go through `LocalDataDisposer` (`lib/data/repositories/local_data_disposer.dart`), with a `DisposalReason` — `sessionEnded`, `identityChanged`, `companyGoneOnServer` — logged at WARNING with a count of the unsynced outbox rows going with it: the first line to look for when a user says their changes vanished. The Danger Zone used to call `db.wipeForCompany` from UI code; it goes through `services.auth.localData` now.
- **Outbox rows** are deleted by the sync engine — a delivered row, a superseded save, a discard the user asked for, an old failure the user chose to drop — and by a repository's own save replacing its pending row (`dedupPendingMutations`). The edit screen and the new-client dialog used to delete "the record's newest failed row" after any successful save, and `findDeadForEntity` matched every kind — so a rejected email or payment on the same invoice vanished, and the reopened form showed its error as if the save had failed. `findDeadSaveForEntity` and `SyncRepository.supersedeDeadSave` now touch only the record's own failed create / update.
- **`AuthRepository.logout` takes a required `LocalDataPolicy`** (`keep` — a 401, an idle timeout with unsynced work; `keepUnlocked` — no re-lock gate; `destroy` — only after `confirmPendingOutboxIfAny(checkAllCompanies: true)` or with nothing unsynced). The old `preserveLocalData = false` default meant a caller that never thought about it wiped every company's work; now the compiler asks every caller.

**Old failures are the user's call.** Failed rows older than 90 days (`kOldFailureAge`) used to be deleted at every launch, silently. The Outbox now heads its list with "N failed changes are more than 90 days old" and a Discard that always asks (`pruneDeadRows(companyId:)`, which still releases each row's dirty flag). **Deferred:** a different identity signing in still wipes the previous identity's unsynced rows (`_wipeIfIdentityChanged`) — they cannot be sent under the new token, and holding them for that identity's return needs a store the new session cannot read.

## A page or mutation is bound to the company whose token fetched it

**A page or a mutation is bound to the company whose token fetched it, and the binding is a `throw`.** A company switch swaps the API token under ~14 in-flight requests; a response that lands after the swap carries company A's rows and would be written under company B's id by `upsertAllPreservingDirty(companyId:)`, which takes the id from the *caller*, not the payload. `BaseEntityRepository.companyStillActive()` + `CompanySwitchedException` guard the seam for pages; for **mutations** the binding moved into the transport — `SyncRepository._attempt` runs each row's dispatch in a `RequestScope(row.companyId)` and `ApiClient._requireCreds()` throws `CompanySwitchedException` before sending anything under another company's credentials (a switch can land after the drain's per-row check, or between a handler's two requests); the drain re-queues the row budget-neutral, or — if a write already committed in that attempt — retires it rather than re-sending. The page guard is applied once in `ensurePageLoadedTemplate` (every paginated repo now routes through it) and by hand only in `tag_repository`, which has no `ensurePageLoaded` at all — its `refreshAll` pages `api.list` directly across every entity type at once; `test/lint/company_scoped_write_guard_test.dart` fails the build on a repo that calls `upsertAllPreservingDirty` with neither. **It must stay an exception, not a bool** — both bool answers are wrong: returning "success" makes the list think it has a page it never wrote, and returning "failure" routes a benign switch into the retry / error machinery. The corollary is that every caller must expect it: `GenericListViewModel` swallows it as benign at `_flashError` **and** at all three `initialError` sites (a first-page or reset in flight is the likeliest way a user meets it, and it renders full-pane), the drain breaks the pass at `fine`, and `payment_unapplied_band`'s `_autoApplyOldest` had to gain a try/catch first — it discards its future from an `onPressed`, so the throw would have surfaced as an unhandled async error on a money action.

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
both surfaces were stale together, and both are fixed by one write. (Their "Updated N ago" labels
were not — each was a stamp only its own screen's refresh set. See § A screen that refetches after
a Sync pass listens to `lastCompletion`.)

**The three caches, and why each needed its own line.**

1. **`dashboard_cache`** — server-fed rows, refreshed by `DashboardRepository.refreshListCards`.
   It covers all of `DashboardKind.listKinds`, not just `activities`: Past due, Upcoming invoices,
   Recent payments, Expired/Upcoming quotes and Upcoming recurring are the identical mechanism, so
   fixing activities alone would have left a stale card on the very screen beside the fixed one.
   The filter-keyed half (totals, chart, configured cards) is deliberately excluded — it is keyed
   by a `DashboardFilter` that is UI state owned by `DashboardViewModel`, and a caller with no
   dashboard mounted would have to invent one and would write a row under a hash nothing watches.
   A *mounted* dashboard refetches them itself once the pass completes
   ([invoiceninja/flutter#162](https://github.com/invoiceninja/flutter/issues/162)) — see § A screen
   that refetches after a Sync pass listens to `lastCompletion`.
2. **`ActivitiesApi._feedCache`** — the in-memory per-record feed behind the Activity / Comments
   tabs, dropped with `clearCache()`. This fixes the *next* record opened; a tab already on screen
   is not repainted, because `EntityActivityViewModel` has no Drift subscription for synced rows
   (it re-kicks only on an outbox tick for its own record). The broadcast signal that would fix it
   now exists — `ResyncController.lastCompletion`, built for #162 — but `EntityActivityViewModel`
   does not listen to it yet (it is constructed on eleven detail screens).
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

**The company-switch window, now closed at the write.** The list-card fetches are issued in
parallel, so there is no boundary to poll `isCancelled` at once they are on the wire; a switch
landing mid-flight used to file the new company's rows under the old id.
`company_scoped_write_guard_test` does not catch that — it fires only on repos calling
`upsertAllPreservingDirty`, and `DashboardRepository` writes via `_dao.upsert` — so #162 gave
the repo its own `activeCompanyId` hook and `_ensureStillActive`, checked before every fetch and
every write. See § A screen that refetches after a Sync pass listens to `lastCompletion`.

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

## A screen that refetches after a Sync pass listens to `lastCompletion`

[invoiceninja/flutter#162](https://github.com/invoiceninja/flutter/issues/162), the follow-on to
#160: after **Sync now** the dashboard still read *"… · UPDATED 2H AGO"*, and its KPIs, chart and
configured cards were pre-sync. The #160 tail had refreshed the seven list cards and deliberately
left the filter-keyed half to the dashboard's Refresh button — and that stamp,
`DashboardViewModel.lastRefreshed`, lives in memory and is written only by the view model's own
clean `refresh()`. The branch stays mounted all session (`StatefulShellRoute.indexedStack`), so
its constructor and its boot refresh never run again, and nothing told it a pass had finished.

**The signal.** `ResyncController.lastCompletion` is a `ValueListenable<ResyncCompletion?>`,
published once per pass, after `value` returns to idle and before `run()` resolves — and only
for a pass that ran to its end. `announce` is decided at the top of `run()`'s `.then`, before
`_cancelled` is reset, on two terms, each covering what the other can't:

- **Not cancelled.** Logout or a company switch asked the pass to stop. The flag subsumes the
  disposition — `_run` reports `cancelled` off this same flag, and nothing clears it before
  `.then` — and it also catches a runner that *threw* after the cancel, which `_run`'s catch
  reports as `completed`. That is the usual shape of a 401: its logout cancels the pass and pulls
  the token from under it.
- **No error.** A prologue that failed with nobody cancelling — offline, a 5xx, a bad envelope —
  downloaded nothing and never reached the tail, so there is nothing to follow up.

Joined and busy calls start no pass, so they never get here. `ResyncCompletion`'s equality is its
`serial` alone, so two back-to-back passes for one company both notify. `ValueNotifier` drops an
equal value silently — the same trap `ResyncProgress`'s `==` is written around.

**Why not the falling edge.** `GenericListViewModel.bindResync` uses `isRunningFor` going false,
and that edge fires identically for a cancelled pass. For a fetch that is wrong: on logout,
`_onSessionChanged` returns early on a null session, so the old view model stays alive until the
router swaps the shell, and its requests would race the Drift wipe. (The list re-arm has its own
exception — § A bulk re-download re-arms mounted lists.)

**A company switch is not cancellation's job.** `_activateCompany` sets the session — which
synchronously disposes the old dashboard view model and builds one for B — then sets the
credentials, awaits secure storage, and only then fires the hook that calls `resync.cancel()`. So
a pass for A can finish *uncancelled* after the switch began, and be published. What keeps it
out is the `companyId` check in `DashboardViewModel._onResyncCompleted`: a view model for company
X exists only while the session is X.

**Who listens, and how.** `DashboardScreen._buildVm` passes `resync.lastCompletion` into the
view model. It is the single construction site, so the company-switch rebuild keeps the wiring,
and `dashboard_panel_wiring_test` scans for it (comments stripped). The view model ignores a
completion that is for another company, that carries an error (the controller already withholds
those; this check is what keeps a request off a logout if that rule ever loosens), or that reaches
it after dispose. A pass with failed *entity* downloads still refetches: its tail ran, and none of
the dashboard's own endpoints read the entity tables.

**A completion during the boot refresh is deferred, not dropped.** `ValueNotifier` never replays
one, and the boot refresh can have read the server *before* the pass pushed its edits — one slow
request holds it open for up to a minute. Running the refetch alongside it instead would drop the
shared `isAnyRefreshing` early and flash "Not yet loaded", which `_init` goes out of its way to
avoid. So `_onResyncCompleted` sets `_refetchAfterBoot`, and `_init` runs one refetch when the boot
refresh returns — one, however many passes landed meanwhile.

**Why a full refetch, list cards included.** It re-sends the seven list-card GETs the tail
finished a moment earlier — about seven repeat requests per Sync while the dashboard is mounted,
the 250-row activity feed among them. What that buys is one code path, the Refresh button's, and a
`lastRefreshed` whose "every section landed" promise holds without carrying the tail's per-card
failures across the pass boundary. The alternative — the filter-keyed half plus only the list
kinds the tail failed on — needs the pass result to carry those kinds. (Re-reading the feed "later"
buys nothing: with contacts sync off, the default, nothing runs between the tail and the
completion.)

**Why `globalError` is left alone.** `_runRefresh(reportGlobalError: false)` never touches it.
`globalError` is the toast detail that `_refreshWithFeedback` reads straight after its *own*
`refresh()`, so an overlapping after-sync run that cleared or overwrote it would hand that toast
another run's error. The after-sync run shows no toast (the Sync toast already reported the pass);
its failure shows as `lastRefreshed` staying put, plus the error state of the sections that render
one — configured cards, and list cards with nothing cached. The KPI row and the chart render none.

**The Drift-backed panels re-arm off their own nonce.** The Invoices & Quotes and task-calendar
panels refetch their own server window when their `refreshNonce` changes from one non-null value to
another; a first stamp is their initial load. That nonce used to be `lastRefreshed`, so every clean
Sync cleared their loaded flags, re-downloaded pages the pass had just fetched in full, and blinked
the calendar's "nothing booked" caption. It is now `DashboardViewModel.panelRefreshNonce`: it moves
with `lastRefreshed` on the boot refresh and on the Refresh button, and after a pass only when the
pass failed an `invoice`, `quote` or `task` download. `dashboard_panel_wiring_test` pins both bodies
to it.

**A dashboard fetch is bound to the live company.** Every `DashboardRepository` refresh writes
under the `companyId` it was called with while `ApiClient` sends whatever token is live, and the
after-sync refetch is outside the pass `resync.cancel()` stops. "Sync now, then Sign out" is a
natural flow: a response landing after `logout()` had cleared the credentials, wiped the database
and forgotten the identity survived — and the next sign-in's identity check could no longer see
it, so another user of that company would be shown the feed. `Services.build` now binds the repo's
`activeCompanyId` like every entity repo's, and `_ensureStillActive` runs before each fetch and
each write, throwing `CompanySwitchedException` (logged at `fine`, folded into the error map). One
difference from `companyStillActive`: a bound hook answering null means signed out and blocks too —
nothing on the dashboard fetches before a session exists.

**A dashboard left open past midnight re-subscribes first.** A preset resolves against today, so
its `filterHash` moves at midnight — and again at a month or year boundary — while the filter-keyed
watches keep the hash they were opened with. The refetch a Sync starts on exactly such a
long-mounted dashboard used to write under the new hash and leave every section on the old rows
beneath a fresh "Updated just now"; the Refresh button and a retry did the same.
`_resubscribeIfRolledOver` reopens the watches at the top of every refetch and retry (the
view model takes a `today` clock for the test).

**The decoded watches skip unchanged rows.** Drift re-runs every watch on any `dashboard_cache`
write, and a Sync now issues two rounds of them, so each write re-decoded every section — the
250-row feed in both of its view models included. `_watchDecoded`, `_watchList` and
`watchCalculatedField` apply `distinct` to the *row* before decoding; the generated row `==`
compares payload and `fetched_at`, so a real rewrite still comes through. As a side effect an
unrelated write no longer re-emits a section, which used to clear its error state.

**`/activity` follows the row instead.** That screen reads exactly one `dashboard_cache` row, so
its label is the row's `fetched_at` (`DashboardRepository.watchActivitiesFetchedAt`, also
`distinct`). It moves for every writer of that row with no signal wiring: the screen's own
refresh, the #160 tail, and every dashboard load of the feed — boot and company switch, the
Refresh button, a card retry, and the after-sync refetch. The stamp it replaced was set only by
the screen's own refresh. One provisional stamp remains: `refresh()` sets `_lastRefreshed ??= now`
on success, because Drift delivers the new row's time asynchronously and the `finally` would
otherwise paint "Not yet loaded" over a fetch that had just succeeded; the row's time replaces it.
Accepted trade-off: on a cold start with a cached row, the label shows that row's age while the
first refresh runs, rather than "Loading…".

**Residuals, known.**

- **`isAnyRefreshing` is one shared bool.** An after-sync run overlapping a user refresh or a card
  retry can clear it early. This predates #162. Don't "fix" it by skipping the after-sync run while
  the flag is set: a single-card retry would then suppress the stamp, and the bug would be back.
- **The screen's own `_formatter` isn't reloaded.** The tail invalidates the memoized `Formatter`,
  but `DashboardScreen` keeps the instance it already holds, and doesn't re-run
  `setFiscalYearStart`, until a company switch. The list screens' `loadFormatter` has the same gap,
  so a date format or fiscal-year change made on another device reaches neither until then.
- **The list re-arm can page after a cancelled pass** — § A bulk re-download re-arms mounted lists.

## The refresh delta tops up the browsable tables

**A `/refresh` delta carries the fourteen browsable entity tables too, and they are applied as an
upsert-only top-up — never on a full sync, and never over a newer local row.**

Shipped as [invoiceninja/flutter#170](https://github.com/invoiceninja/flutter/issues/170): an iOS
beta user was chasing invoices that had already been marked paid, days earlier. Tapping **Sync**
revealed the discrepancy; nothing else would have.

**Two causes compounded, and only one of them was obvious.** First, nothing re-fetches a *mounted*
list: the shell is a `StatefulShellRoute.indexedStack` (`router.dart`), so once a branch has been
visited its `GenericListViewModel` lives for the session and `_loadInitialPage()` never runs again.
Within one long session a list only re-fetches on pull-to-refresh, a filter/sort/tab change, or a
manual Sync — the same structural reason `ActivityViewModel` went stale in
[#160](https://github.com/invoiceninja/flutter/issues/160). Second, the refresh that *was* already
running carried the answer and threw it away.

**The bytes were always on the wire.** `RefreshScheduler` fires `auth.refresh()` every
`kRefreshInterval` (5 min) plus once on resume, sending
`current_company=true&updated_at=(lastSyncAt/1000 − kUpdatedAtBufferSeconds)`. Server-side,
`POST /api/v1/refresh` → `LoginController::refresh` → `BaseController::refreshResponse()`, which
calls `$this->manager->parseIncludes($this->first_load)` **unconditionally** — the `first_load`
array is not gated on the `first_load` query param, which only steers `buildManager()`. So every
delta response already contains clients, products, invoices, recurring invoices, quotes, credits,
payments, tasks, projects, expenses, recurring expenses, vendors, purchase orders and bank
transactions, each filtered `where('updated_at', '>=', $updated_at)`. `CompanyEnvelopeApi` declared
only the thirteen *reference* bundles, so freezed's `fromJson` dropped every entity array on the
floor. Consuming them costs **zero additional requests**.

**This was a regression from v1, not a missing feature.** admin-portal ran the same 5-minute timer
(`main_app.dart` → `RefreshData()`) and every entity reducer absorbed the arrays —
`_setLoadedCompany` → `invoiceState.loadInvoices(company.invoices)` (`invoice_reducer.dart`), and
the same shape for each sibling. v1 stayed fresh *because* it consumed these deltas. (v1 also gated
its tick on `uiState.hasRecentActivity`, last interaction within 24 h; v2 stops the pump entirely
while backgrounded, which is a stronger gate on mobile, so that was not carried over.)

**Four invariants, each invisible at a call site.**

1. **`tolerantList` is load-bearing here, not stylistic.** These fields share an envelope with the
   session, the token and the reference bundles. Parsed strictly, one malformed invoice would throw
   out of `LoginResponseApi.fromJson` and take the whole refresh with it — a far worse failure than
   the dropped row it replaces. The same reasoning as the `*ListApi` envelopes, with higher stakes.
2. **`wasFullSync: false` is not a parameter.** `applyRefreshDeltaTemplate` hard-codes it, so a call
   site cannot mark a browsable entity's cursor "full" from a partial delta — doing so would stop
   that entity's own pagination back-filling.
3. **A row older than the stored one is dropped.** The `/refresh` body is computed server-side
   *before* it is persisted here, so an outbox echo landing in between holds a **newer** row than
   the delta does — and that echo has already cleared `is_dirty`, so `upsertAllPreservingDirty`
   will not skip it. Without the guard the user's just-saved change visibly reverts until the next
   tick. `BaseEntityDao.updatedAtAmong` (hand-rolled on `BankTransactionDao`, which does not extend
   the base) supplies the comparison; equal-or-newer still applies, so a legitimate update is never
   suppressed. Leaving `updatedAtColumn` unbound silently disables the guard, which is why
   `refresh_delta_coverage_test` pins the binding.
4. **A full sync skips the whole map.** Every entry is wrapped in `_deltaOnly`
   (`services_entity_wiring.dart`). A full-sync envelope is the entire dataset for *every* company
   (`current_company=false&updated_at=0&first_load=true`); `Services.resyncAllEntities` already owns
   that path, and applying it here would turn a cold start into one very long write inside the
   per-company transaction. Note the server only truncates for large accounts when `updated_at == 0`
   (`is_large` in `BaseController`), so a large company **does** receive full deltas every tick.

**A delta is unbounded, so the `IN (...)` helpers had to be chunked.** Both
`BaseEntityDao.updatedAtAmong` (the guard above) and the pre-existing `_dirtyIdsAmong` behind
`upsertAllPreservingDirty` build a `WHERE id IN (...)` over every candidate id. That was safe while
the only callers were page-sized (<= 50 rows); a delta hands them every row changed since the last
sync. Measured: 5 000 ids fine, 60 000 throws `SqliteException(1): while preparing statement, too
many SQL variables` — SQLite caps host parameters at `SQLITE_MAX_VARIABLE_NUMBER` (32 766). Both
now slice through `chunkIdsForSqlIn` (500 per statement), as do `BankTransactionDao`'s hand-rolled
twins. `sql_in_chunking_test` pins it with a 40 000-row delta applied twice.

**Why a quiet tick is free.** `applyBundleUpsertOnly` returns early on an empty bundle and
`upsertAllPreservingDirty` is empty-safe, so a refresh where nothing changed leaves every entity
table untouched and their watch streams quiet. (The refresh itself still writes — `_persistAndActivate`
stamps each company's `lastSyncAt` unconditionally — but nothing a list is watching.) That is what
stops every mounted list repainting on a timer; it is pinned by a test because it is invisible in
review.

**Each delta applier is isolated, and the reference bundles are not.** The whole `onPersistBundles`
hook runs inside one `_db.transaction` whose only try/catch sits *outside* it, so an uncaught throw
from any applier rolls the lot back. That was tolerable while the hook only carried thirteen small
settings payloads; it is not once fourteen appliers are writing arbitrary volumes of user data, where
one malformed row would silently stop task statuses and gateways updating too. The fan-out therefore
wraps each delta applier in its own try/catch, naming the entity — `applyBundleUpsertOnly` opens a
nested transaction, so drift rolls back exactly that entity's SAVEPOINT. Same shape as
`resyncAllEntities`, which collects per-entity failures rather than aborting the pass.

**Two things deliberately not done.** Purged rows are still never pruned (`refreshAll` is
upsert-only too); archive and soft-delete *are* covered, since both bump `updated_at` and arrive
with their flags set. And the envelope's `company.activities` / `company.locations` arrays still
have no consumer — activities is the interesting one, given #160.

**Fixed, and worth knowing why the note that used to sit here was wrong.** The bundle fan-out ran
between `_persistAndActivate`'s two `expectedGeneration` guards with none of its own, so a logout
landing in that window wrote these rows into a database `logout()` had already wiped. This note
previously signed that off as *"not a cross-user leak — `_wipeIfIdentityChanged` still fires when a
different identity signs in."* **That was false on the only path that wipes.** The destructive
branch of `logout()` deletes `kAuthUserIdKey` / `kAuthAccountIdKey` — reasoning, reasonably, that
"the database goes with this logout" — and `_wipeIfIdentityChanged` requires *both* the stored and
the incoming id to be non-empty, so with them gone every `*Changed` flag is false and it returns
without wiping. `refreshAll` being upsert-only then means nothing ever prunes the resurrected rows:
the next person to sign in on that device, **a colleague in the same company**, which is precisely
the case the identity check exists for, inherits records that were never theirs — including ones
the server's own permission filter would have withheld.

Reachable with no user action: the idle-timeout controller takes the *destructive* branch whenever
the outbox is empty. The window was pre-existing and used to leak only the thirteen small reference
bundles; adding the fourteen browsable entity tables to it is what turned it into user data.
`_persistAndActivate` now re-checks the generation immediately before the fan-out **and once per
company inside it**, since each iteration awaits its own transaction.
