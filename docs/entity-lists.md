# Entity lists — columns, status tabs, state filter, counters

Companion to CLAUDE.md §§ List columns, List status tabs, List state filter and Sidebar counters. The main file carries the registry shapes and the rule for each behaviour; this doc carries the evidence. Section headings here mirror the CLAUDE.md ones, so a bare `§ List status tabs` citation resolves in either file.

## List columns

`lib/domain/columns/<entity>_columns.dart` is one registry per entity: an ordered `kAll<Entity>Columns`, the `kDefault<Entity>Columns` subset shown out-of-the-box, and a `<entity>ColumnsById` map. The user's selection lives in `user_settings.table_columns` (**not** `nav_state`) in the same byte format the legacy admin-portal uses, so **renaming a column id silently drops a user's saved layout** — don't. (The one safe case is a constant no registry ever referenced, i.e. one that cannot be in anybody's stored list: that is why `ProjectFieldIds.customValue1..4` could become `custom1..4`.)

Hiding a column is **never** destructive: `_resolveColumns` drops an id it can't render while `_columnIds` (and `user_settings`) keep it, and `EntityColumnPickerSheet` re-inserts it at its original index on Done.

**Client and Vendor ids must also join `k<Entity>ColumnIds`** in `lib/domain/columns/ids/` — their DAOs guard `_sortExpression` on that set and degrade to name-order in release when an id is missing. `column_ids_match_registry_test` is the guard.

A user-facing label needs a placeholder-free key: use `user` for created-by, never `created_by` ("Created by :name").

### Every field the edit screen can set earns a column

**Every field the entity's edit screen can set earns a column** (that rule is
what invoiceninja/flutter#106 was about), plus the shared metadata block:
created / archived / state / deleted / documents / created-by / assigned user.
Build those with the factories in `lib/domain/columns/column_factories.dart`
rather than hand-rolling a fifteenth copy — including `colTags`, whose
`sortable` defaults to false because tags are payload-only everywhere except
Task and Project, which denormalize a `tag_names` column and pass `true`.
`test/lint/column_factories_used_test.dart` fails the build on a registry
that hand-rolls a `created` / `archived` / `tags` column. That lint exists
because Clients, Products and Vendors hand-rolled `created` and so never
picked up `colCreatedAt`'s epoch-0 guard: a row carrying 0 painted
"1 Jan 1970" on those three lists and an em-dash on the other eleven, and
nothing compared the fourteen definitions.

### Sortable means a real Drift column and a `_sortExpression` case

**Real Drift column ⇒ `sortable: true` plus a `_sortExpression` case in the
DAO. Derived or payload-only ⇒ `sortable: false` plus an entry in
`sortable_columns_test`'s `displayOnly` map.** Every header is a sort control,
and most DAOs throw on an unmapped field — `sortable_columns_test` detects the
gap by catching that throw, so a DAO that falls back silently instead makes
its own dead headers invisible (that is how `task.duration` shipped).
**`ClientDao`, `VendorDao` and `UserDao` are the exceptions**: the first two
assert against `k<Entity>ColumnIds` and then fall through to a generic
`json_extract(payload, '$.<id>')` — which is what legitimately sorts their
address / notes / contact columns, but also means the probe can never fail
for them. Adding a sortable client or vendor column means checking the
`_sortExpression` arm by hand; the id-set test only proves the id is *known*.

### Custom-field slots go through `customFieldColumns`

**Custom-field slots go through `customFieldColumns` (`custom_field_columns.dart`),
never a hand-written `custom1` column.** `GenericListViewModel.availableColumns`
then decorates them per company: the header and picker show the *configured*
label ("Region"), values format by configured type (date → company date
format, switch → localized Yes/No), and an unconfigured slot is dropped from
both. Read the label through `column.resolveLabel(context)` — a bare
`context.tr(labelKey)` loses it. Note the slot **prefix is not the entity
name**: quotes / credits / purchase orders / recurring invoices all read
`invoice1..4`, and recurring expenses read `expense1..4`.

## List status tabs

A one-tap status strip above every entity list — `All / Draft / Unpaid / Overdue` on Invoices, and so on for the other 13 entities that declare status counters (invoiceninja/flutter#98: reaching a draft through the search field's filter menu cost three or four taps). It is a **view over the sidebar-counter catalog**, not a second one: `lib/domain/list_status_tabs.dart` adds only the tab *order* (lifecycle, deliberately not the badge lists' "most actionable first") and the optional server translation. Labels, tones and the inventory gate all resolve from the entity's own `badgeModes` at render time.

### The count and the rows are one predicate

**The count and the rows are one predicate.** The badge reads `watchBadgeCount(modeId:)`; the list passes `badgeModeId:` down VM → repo → DAO, where `BaseEntityDao.badgeModeListFilter` applies the *same* `badgeModePredicate` inside `watchPage`'s WHERE (pre-`LIMIT`, so the Drift window stays aligned with the page count). `list_status_tab_filter_test` asserts `rows == count` for all 14 entities × every mode; that test is the feature.

### The whole state is `extraFilters['badge_mode']`

**The whole state is `extraFilters['badge_mode'] = {modeId}`** — one key, so `currentSnapshot()` carries it into `nav_state` and saved views for free, `clearAllFilters()` resets the strip without knowing it exists, and the strip's selection is always literally that value (no second source to drift). It is **app-private and never reaches the wire**: `_serverExtraFilters()` strips it and splices in the entity's real query params instead.

### Don't map a mode whose only superset is nearly the whole table

**Don't map a mode whose only superset is nearly the whole table.** Payment / credit `unapplied` were mapped once (`completed,partially_refunded` and every non-draft status): no useful narrowing, and `isNarrowedFetch` then costs the delta cursor too. Local-only plus the auto-chain is strictly better there. This is about supersets that buy nothing — an **exact** mapping pays the same cursor cost and it isn't a cost, because the fetch discards nothing after it lands, so a true offset page of precisely the tab's rows beats a delta slice.

### No strip on an embedded list

**No strip on an embedded list** (`widget.embedded`): the counts are company-wide, so "Draft 47" on one client's Invoices tab would be a flat lie.

### The strip renders whenever a tab is active, even with the device setting off

**The strip renders whenever a tab is active, even with the device setting off** — a `badge_mode` restored from `nav_state` or applied by a saved view is a live filter, and hiding its only control would leave the list narrowed with nothing but "Clear filters" to escape. `_hydrate` drops a `badge_mode` naming a mode this build no longer offers, for the same reason `_migrateLegacyUpdatedBetween` exists.

### Status-tab counts are active-only

Counts are **active-only**, so the badges stand down (tabs keep filtering) when the list is showing archived / deleted rows, and they carry the same local-cache under-reporting caveat as the rail. A zero renders in the neutral palette whatever the bucket's tone — a red `0` would claim urgency about the one outcome that means there's nothing to do. Device-toggleable, default **on**: Settings → Device Settings → Status tabs (`DevicePrefKeys.statusTabs`, `StatusTabsController`).

### A server mapping must return a superset of the local predicate

**A server mapping must return a SUPERSET of the local predicate.** Over-fetching is free (the local predicate discards the extras); under-fetching silently hides rows — the tab reads "Expired 12" over eight rows and the missing four never arrive. Where the obvious value is a subset, *widen* it (quotes send `client_status=expired,draft` because the app also counts a past-due draft as expired) rather than dropping to local-only. The unmapped modes each say why in `list_status_tabs.dart`, and `list_status_tabs_test` pins the exact set so mapping one later is a deliberate edit. The cleanest case is an **exact** mapping — clients send `balance=gt:0`, which is `ClientFilters::balance` clause-for-clause, so `widened` stays false and the chain stays off; note the operator lives in the *value* and the server parses it off the PREFIX, so a suffix `0:gt` silently runs `where('balance','=','gt')` (≈ "balance is zero"), the exact inverse of that tab.

### A widened mapping must be marked `widened: true`

**A widened mapping MUST be marked `widened: true`, and that flag is not bookkeeping.** `statusTabNarrowsLocally` — the gate on `localOnlyFilterActive`, i.e. on the auto-chain — is true for an unmapped tab **and** for a widened one, because in both the Drift predicate is still throwing rows away after the fetch lands. Gate the chain on "has no server mapping" instead and five tabs break the same way: a widened fetch fills page 1 with rows the local predicate discards (Quotes → Expired pulling 50 drafts to find 3 expired quotes), the emission is shorter than a page, there is no scroll extent for the load-more trigger, and the tab renders "Expired 3" over a false "No records found". Only an **exact** mapping — server clause and badge predicate select the same rows — leaves the chain off, **and only while nothing preempts it**: `_serverExtraFilters`' `putIfAbsent` lets a filter the user set by hand keep the tab's own server key, so the fetch is then whatever *they* asked for and the local predicate is discarding rows again however exact the spec is. `statusTabMappingPreempted` re-arms the chain for that case; it is reachable wherever a tab's server key doubles as a user-facing filter key (Clients `balance`, Invoices `status_id`).

### A tab reading another entity's table has to fetch that table too

**A tab whose predicate reads another entity's table has to fetch that table too, or it reads zero.** Clients → Overdue is `clients.id IN (SELECT client_id FROM invoices WHERE …)`, and login prefetches **page 1 only** per entity (`Services.prefetchSidebarEntities` — the 50 newest by the server's default `id DESC`), while a full `refreshAll` runs only from a **user-triggered** Sync. So on any account whose overdue invoices weren't among those 50 the tab read `Overdue 0` over a false "No records found" *and*, being local-only, armed the auto-chain to page through the whole client list for matches that could never appear (invoiceninja/flutter#119). `ClientListViewModel.fetchPage` now pages the invoice repo with `extraFilters: {'overdue': 'true'}` — the same filter Invoices → Overdue sends, and a superset of `invoiceOverdueFilter` — **before** fetching clients: gated on `page == 1` (every reset funnels there; `loadMore` and the auto-chain don't), bounded at 5 pages, latched to one attempt per data generation (the flag is set *before* the first await as a **concurrency** guard — two page-1 fetches can overlap — and released again on failure, since the auto-chain provably cannot reach the hydration: `loadMore` only ever fetches `loadedPages + 1`), re-armed by pull-to-refresh, and failing **silently** with the sidebar prefetch's log policy (`NetworkException` → `fine`, else `warning`) because the clients list the user actually asked for must still load. Three non-obvious parts: it is **awaited, not concurrent** — the base clears `isLoadingPage` in its `finally`, so a late arrival paints "No records found" for a beat and the auto-chain meanwhile spends its whole budget scanning clients against an empty invoice table; **nothing re-subscribes** afterwards, because drift puts a subquery's table in the outer query's `readsFrom` set, so the clients watch and the tab's count both re-emit on the invoice upsert (`sidebar_badge_count_test` already pins that reactivity); and the repo param is **nullable**, so deleting the `invoices: services.invoices` line in `client_list_screen.dart` reverts the tab to the bug in total silence — `status_tab_wiring_test` pins that one line. It fixes the *predicate*, not the local-cache ceiling: a client not yet in Drift still needs a scroll or a Sync, and the **sidebar badge** stays cache-bound since only the tab hydrates (a badge may never issue a network call). **Vendors' `unpaid_expenses` / `open_purchase_orders` have the identical shape against `expenses` / `purchase_orders` and are knowingly NOT fixed** — a second case is worth copying; a third should be promoted to a shared helper taking a `Future<bool> Function(int page)`, not to a `GenericListViewModel` virtual (the base already owns the "when": every fetch path funnels through `fetchPage`).

### The strip's edge fades are gated on scroll position

**The strip's edge fades are gated on the scroll position, like `EntityDetailTabs`'.** An unconditional trailing fade veils the **last tab's own count badge**: the scroller carries a `start:` `contentPadding` and no `end:` one, and the badge is the tab's final child behind only `InSpacing.md` (8 px on a phone), so once the strip reaches its end the number sits inside the 24 px gradient. Two ordinary routes get there — flicking the strip, and a `badge_mode` restored from `nav_state`, where `_revealSelection`'s one-shot `ensureVisible(alignment: 0.5)` clamps to `maxScrollExtent` and parks that tab flush against the edge. Three things follow the sibling strip — `EntityDetailTabs`, in `docs/comments-and-activity.md` § The record’s own history leads every detail strip — for the same reasons documented there: `hasContentDimensions` (not just `hasClients`, or reading extents pre-layout throws out of `ScrollPosition.minScrollExtent`); a **post-first-frame `setState`**, because `attach` adds the listener without notifying, so a strip nobody scrolls would never paint its trailing fade; and a `NotificationListener<ScrollMetricsNotification>`, because a width change that leaves `pixels` alone reaches no `ScrollController` listener. Unlike the sibling it uses `PositionedDirectional` + `AlignmentDirectional`, so the fades stay on the right physical edge in Arabic / Hebrew — which is why the two `_edgeFade` helpers are **not** shared. Note `_revealSelection` uses the *static* `Scrollable.ensureVisible`, which walks every enclosing scrollable; that is safe only because `_bodyWithBanner` mounts the strip as a plain `Column` sibling of the list. Move it inside a scroll view and it would drag the page vertically on launch.

## List state filter

The lifecycle dimension (`is:` / `state:` — active / archived / deleted) is a **`Set<EntityState>` that is never empty**, and deleted rows therefore appear only when somebody asks for them. `normalizeListStates` (`lib/domain/entity_state.dart`) makes that true by construction at **three** writers, not one: `setStates` — which is the choke point for every *user gesture*, since the filter key's `clear` / `addValue` / `removeValue` back the chip `×`, the checkbox picker and Backspace-on-an-empty-search-box alike — plus `_applyDecoded` (nav_state hydrate and saved-view apply) and `_applyIntentState` (dashboard deep links), which assign `_states` directly and so normalize themselves. Keep the three in step. A fourth site writes the *snapshot* rather than the set — see `docs/entity-lists.md` § A snapshot on disk needs healing at every site that reads one.

### Why the empty set was a one-way trap (flutter#126)

It was invoiceninja/flutter#126, and the shape is worth keeping in mind because **the empty set looked like the *absence* of a decision while being the widest possible one**. At both seams `{}` means "no restriction": all 54 `if (states.isNotEmpty)` guards across the 29 DAOs emit no predicate, and `stateQueryParams` omits the `status` param, which the server answers with `QueryFilters::status('')` returning the builder untouched on top of an `apply()` that ends in `withTrashed()`. Three ordinary gestures reached it, all of which read as *stop filtering*: the `×` on the `State: Active` chip, the `×` on the aggregate chip, and Backspace in an empty search box (which removes the last chip). And it was a **one-way trap** — `tokensFrom` drew no chip for `{}`, `hasActiveFilters` deliberately treats `{}` and `{active}` alike, so the clear-filters button hid itself too: deleted rows, no explanation, no way back, persisted to `nav_state.filters_json` and restored on next launch. Both legacy clients land on active-only when the user has expressed no preference (admin-portal seeds `[EntityState.active]`; React sends `status=active` on first paint), so the raw permissive server default had never been exposed to a user before. "Show me everything" is still expressible — tick all three, which is also the only shape that keeps the fetch a cursor-advancing baseline.

### Normalize on the list VM only, never at the DAO or repository seam

**Normalize on the list VM only — never at the DAO or repository seam.** There `{}` is a first-class value that has to keep saying what it says: `refreshAllTemplate` sweeps `EntityState.values` (the sweep that puts deleted rows in the local cache at all), `stateQueryParams` and `isNarrowedFetch` fold `{}` and all-states into one "widest fetch" baseline that `pagination_rules_test.dart` pins directly, `entityStateFilter` asserts on empty, and ~15 non-list callers pass their own literal set (`user_management_screen.dart`, `kanban_view_model.dart`, `line_item_picker_body.dart`, five settings-entity repositories…). The `states:` parameter is a general-purpose API, not a list-VM channel. Rejected for the same family of reasons: making `{}` mean *active + archived* would emit `status=active,archived`, flipping `isNarrowedFetch` true for that view and costing it the delta cursor, and it needs a raw-vs-query `states` split threaded through ~28 per-entity `watchPage()` overrides.

### A key at its default renders no chip

**A key at its default renders no chip, and that guard must live in `TokenSearchController`, not in `tokensFrom`.** With the dimension non-empty, a `State: Active` chip's `×` could only reset to the value it already holds — a dead affordance — so `activeChips` and `activeTokens` skip a key reporting `isAtDefault`. Both, not just the first: `activeTokens` backs the Backspace-removes-the-last-chip path, which must not "remove" a chip nobody can see (it would announce a phantom removal to screen readers and swallow the key event). It is **not** done inside `IsFilterKey.tokensFrom` because `FilterSuggestionMenu` resolves its applied set from `tokensFrom` directly — the check icon and the toggle-vs-add decision — so an early return there would render **Active un-ticked on an active-only list**. The guard is a one-chip change only while `isAtDefault ⇒ tokensFrom` is empty for every other key — each of them projects a values set its own `isAtDefault` reports empty, and the one differently-shaped key (`InvoiceOverdueFilterKey`, whose default is "the set doesn't contain `true`") already early-returns on `isAtDefault` inside its own `tokensFrom`. **Don't pin that by sampling.** `uncovered_filter_keys_test.dart` walks every `build*FilterKeys` in `lib/` and asserts it per key, so a key added to any entity list is covered the day it ships; a key that broke the alignment would otherwise silently stop drawing a chip the user had applied, and nothing else in the suite would see it. Note the implication is one-way — `CustomFieldFilterKey` is `isAtDefault == false` with an empty `tokensFrom` when the company un-configures the column, which this guard is immune to but which makes "at default" and "has no chip" different questions. **The chip was also blocking the search placeholder, on all three surfaces.** `hintText` is gated on `active.isEmpty` in the wide field (`token_search_field.dart:853`) and the mobile filter sheet (`filter_entry_sheet.dart:481`), and the narrow collapsed summary bar switches its whole branch on it (`token_search_field.dart:1034` — `Text(hint-or-search-term)` versus a scrolling row of read-only chips). `IsFilterKey` is registered on every entity list, so before this `active` was **never** empty on an unfiltered list and the placeholder was unreachable everywhere: the phone's search bar rendered a read-only `State Active` pill where its hint belongs. That is a second, larger user-visible consequence than the dead `×`, and `filter_entry_sheet_results_test.dart` pins it, because a revert of the guard would silently take the hint away again. It also grows the wide field's intrinsic width, since `_RenderDecoration` sizes on `max(input, hint)`.

### Two consequences that are the rule, not bugs

Two more consequences, both the rule rather than bugs: this **reverses** the old Sentry-style "`is:unresolved` shows as a chip" choice (Sentry's chip is removable and removing it genuinely widens; ours can't widen any more) — and it delivers what `FilterKey.isAtDefault`'s own doc had promised since it was written ("the search field uses this to suppress noise on a fresh load"), which nothing honoured until now. And the State picker's Active row goes **inert** on a default list: `_FilterCheckbox` is stateless and draws from `tokensFrom`, while `setStates` early-returns without notifying, so the tick never even flickers — the tap is silently ignored rather than refused. The dead `×` was traded for that, which at least sits behind a deliberate menu tap. Note `toggleState` has the same floor and no caller in `lib/`; don't bind a checkbox straight to it.

### A snapshot on disk needs healing at every site that reads one

**A snapshot already on disk needs healing at every site that reads one — three that compare, and one that writes.** `normalizeSnapshotStates` (`saved_views_repository.dart`, beside `kDisplayOnlySnapshotKeys`) mirrors `_applyDecoded`'s parse rather than just testing for `[]`: that loop keeps only names resolving to an `EntityState`, so `["foo"]`, a non-list, and a legacy blob with no `states` key at all hydrate to `{active}` exactly as `[]` does, and healing only the empty case leaves those disagreeing with the VM at one full page-1 refetch per read. The **fourth** site is `SavedViewsRepository.apply()`, which doesn't compare — it splices a stored snapshot straight back into `filters_json`, so without healing there, applying a pre-#126 view re-persists `"states": []`, and a stale view otherwise at its defaults then trips `_subscribeNavState`'s *second* dedupe guard, so the VM never re-applies, never re-persists, and the bad shape sits on disk indefinitely. Skip it and two things fail silently: a Saved View captured in the old empty state would apply correctly yet never match the live snapshot again, dropping the sidebar's active-view highlight and disabling `clearAppliedViewFilters` — exactly what `kDisplayOnlySnapshotKeys` exists to prevent — and `GenericListViewModel._subscribeNavState`, whose dedupe compares the on-disk slot against an already-normalized `_lastSeenSlot` / `currentSnapshot()`, would re-apply the slot and reload the list on the first unrelated `nav_state` touch (a route write is one). It returns **the argument itself** when there is nothing to heal, so `_matchSlot` copies before its `removeWhere` — without that it would strip `columnIds` out of the caller's live snapshot and out of `SavedView.snapshot`'s own map. `matchingView` gets the same treatment: two public matchers answering the same question must not disagree about whether a pre-#126 view is the one on screen.

## Quote `rejected` is a tab but not a chip

**A `rejected` *tab* on Quotes is safe where the `rejected` *chip* was not, and the difference is whether the value reaches the wire.** `QuoteClientStatusFilterKey` deliberately omits `rejected` (`quote_filter_keys.dart`), and its comment records why: offering it "showed locally-cached rows that a refresh then wiped". That is `QuoteFilters::client_status` having no `rejected` branch — the value hits the global silent-no-op and the server returns the **unfiltered** set, so the chip narrowed the cache, the next fetch overwrote it, and the rows vanished. A status tab is the other shape: `statusTabServerFilters` returns null for an empty `serverFilters`, so **nothing is sent**, the fetch stays unnarrowed, and only `badgeModePredicate` narrows — exactly how `product/low_stock`, `project/overdue`, `vendor/unpaid_expenses` and `client/overdue` already ship. The cost is the ordinary local-only one: the count under-reports until the cache holds those rows, which for a terminal status nobody browses can be indefinitely. Two mitigations, neither of which is the chip's mistake: the dashboard panel's top-up sweeps unnarrowed pages with `ignoreCursor: true` for a local-only tab (a cursor'd page-1 fetch returns the delta, which a quote rejected three months ago is not in), and the panel's footer link lands on the Quotes list with the same `badge_mode`, which is local-only *there* too — so the two surfaces under-report identically and the user never gets two different answers to one question. `BACKEND.md` § F1 requests the server branch; when it ships, swap in `client_status` and drop the entry from `list_status_tabs_test`'s `localOnly` set. `quoteClientStatusFilter` already models `rejected` (`status_id = '5'`) and its `notTerminal` clause excludes '5', so `rejected` is provably disjoint from `expired` and `upcoming` — no new SQL, and no double-counting.

`cancelled` (`status_id = '6'`, shipped with the quote cancel action 2026-09-22) is the same *kind* of status and gets the opposite treatment — a tab **and** a chip — which is this rule working rather than an exception to it. The rule was never "quote statuses don't get chips"; it is "a chip must be a dimension the server can honour". `QuoteFilters::client_status` grew a `cancelled` branch, so the value narrows the fetch instead of hitting the no-op, the tab declares `client_status: {'cancelled'}` (exact, not `widened`), and it stays **out** of `list_status_tabs_test`'s `localOnly` set — that set is an allowlist of tabs that send nothing, so a server-backed tab listed there inverts the assertion. `rejected` is still local-only and `BACKEND.md` § F1 is still open for it alone. The `notTerminal` clause excludes '6' alongside '5', so `cancelled` is likewise disjoint from `expired` / `upcoming`.

## Sidebar counters

`lib/domain/sidebar_badge_modes.dart` is the single source of truth for what each sidebar row's count badge can count (`total` / `overdue` / `low_stock` / `assigned_to_me` / …, plus `none` to hide it). Every mode is answerable from columns already in Drift — **the badge never issues a network call**. The catalog now drives **two** surfaces — the rail's badge and the list's status tabs (below) — so adding or changing a mode is four coordinated edits:

1. the per-entity `SidebarBadgeMode` list here (+ its `badgeModes:` reference in `kWiredEntityModules`),
2. a case in that DAO's `badgeModePredicate` (`BaseEntityDao`; `BankTransactionDao` hand-rolls the same hook),
3. the mode's `labelKey`, plus an entry in `kSidebarBadgeModeSearchKeys` if it is a *specific* word worth surfacing in settings search (the generic status words — `draft` / `sent` / `approved` / `rejected` — are deliberately excluded, so most modes need no edit here),
4. a `ListStatusTabSpec` in `lib/domain/list_status_tabs.dart` — `list_status_tabs_test` fails the build if the two catalogs disagree, so a new mode can't quietly ship as a counter with no way to filter by it.


`sidebar_badge_count_test` fails the build if a declared mode has no predicate — the failure mode otherwise is silent, since a null predicate makes the badge count *every* row and still look like it works. Both pickers (the row's right-click menu and Settings → Device Settings → Sidebar counters) read the same registry list through `availableBadgeModes(...)`, so they can't drift apart.

Note `BaseEntityDao.watchBadgeCount` counts **active** rows (`archived_at IS NULL`), unlike the older `watchCount`, which is archived-inclusive and still backs list empty-states.

### Counts come from the local Drift cache, so they can under-report

Counts come from the **local Drift cache**, which after login holds page 1 per entity and fills in as the user browses (or runs Sync) — so on a large account a counter can under-report, exactly as the plain total always has. Making it exact needs a server-side count; `ApiClient.getList` currently discards the response `meta`.

### Date-sensitive counters go stale past midnight

Second known staleness: `Date.today()` is baked into the SQL when a badge stream is built, and a sidebar stream lives for the whole session — so **leaving the app open past midnight keeps the date-sensitive counters (invoice/client/project `overdue`, quote `expired`) on yesterday's date** until a restart or company switch. The list filter chip has always had this property; it's just more visible on a permanent surface. Fixing it needs a date-rollover trigger to re-key the streams — deliberately not built. A rolling date filter (`date,rel:m0s,rel:m0e` — `docs/list-search-field.md` § A rolling date is one token per bound) has the same property: its bounds are resolved when the list's watch is built.

## Tab counts on a record screen are not sidebar counters

The badge beside a record's related tab ("Invoices 12") looks like a sidebar counter and is the opposite trade. A sidebar counter is answered from Drift and never issues a request, so it can under-report until the user browses or syncs. A tab count is a **server total** — one `per_page=1` request per tab, read for `meta.pagination.total` — because the tab's list pages in fifty at a time and the local table only knows how many rows it has fetched. Unknown (offline, an unsynced record, a failed request) draws no badge. `docs/detail-screen-layout.md` § Tab counts are server totals, and unknown is not zero.

## A count stream is distinct, so a cache in front of it must replay

**`watchBadgeCount` ends in `.distinct()`, and anything that caches one of these streams behind a broadcast controller has to replay its latest value to a new listener — `CachedStream` does.**

Drift re-runs a watched query on every write to a table it reads, with no debounce, and a sync writes a page at a time. So every count stream re-emitted its unchanged number once per page landed, and each emission rebuilt the sidebar row or status tab showing it. `distinct` at the DAO seam (`BaseEntityDao.watchBadgeCount`, and the hand-rolled twin on `BankTransactionDao`) stops that for every consumer at once: the sidebar, the list status tabs, the settings preview and the dashboard's Invoices & Quotes panel.

**Why it is safe for a consumer that holds the stream itself.** A Drift query stream is a `Stream.multi` that hands each new listener its latest value, and `distinct` keeps its "previous" per subscription. A `StreamBuilder` that re-listens — the status strip does, whenever `showCounts` flips — still gets a first value. `sidebar_badge_count_test` › the count stream pins both halves: quiet through a write that leaves the count alone, and a first value for every listener.

**Why the sidebar needed more.** The sidebar keeps its streams behind a broadcast controller, so that a rebuild does not re-subscribe every row and a replaced generation can cancel its Drift query. A bare broadcast controller hands a late listener nothing until the source next emits. That gap was always there — a `StreamBuilder` re-created when the rail collapses or a row moves in the menu started empty — and was hidden by how often the source re-emitted. With `distinct`, "the next emission" can be the next time the number changes, so the badge could stay blank indefinitely. `CachedStream` (`lib/ui/features/shell/widgets/cached_stream.dart`) therefore replays its latest value on listen and exposes it as `latest`, which the two badge builders pass as `initialData` so a re-created row paints its count on the first frame. `cached_stream_test`.

The same pass narrowed the stream that rebuilds every row of the menu. It watched the whole `companies` row for one bool, and that row is rewritten on every `/refresh`; it is now `trackInventory` alone, `distinct`.

## Several clients go on the wire as `client_ids`

**A client filter with two or more clients is sent as `client_ids`, never as a comma-joined `client_id`** (`clientScopeForWire`, applied in `ensurePageLoadedTemplate`). The server's base `QueryFilters::client_id` decodes ONE hashid; `client_id=a,b` decodes nothing, and every list answered it with an empty page — measured on the demo server (5.13.47) for all nine client-scoped lists, while `client_ids=a,b` returned the sum of the two. Local storage stays `client_id`, which `parseClientIdFilter` reads, so no saved filter needed migrating. A `tmp_` id beside real ones is left off the wire (it would not decode either); an all-`tmp_` scope is left for the template's own nothing-to-fetch check. Servers before 5.13.13 ignore `client_ids` and answer unfiltered — a superset the local predicate narrows, which is better than the empty page every version gave before. Pinned by `test/data/repositories/client_scope_wire_test.dart`.

## A comparison the server can't make is translated, not stripped

**On a list whose server filters a date only by window, a single-date comparator travels as the window that means the same** (`singleDatesAsServerWindows`): `date=gte:2026-05-14` becomes `date_range=date,2026-05-14,9999-12-31`, `lt` ends the day before, `eq` is a one-day window. Purchase orders, expenses, payments and bank transactions are the four — `PurchaseOrderFilters`, `ExpenseFilters`, `PaymentFilters` and `BankTransactionFilters` have no `date()` / `due_date()` method, so the comparator was skipped and every page came back unfiltered. A window is exact on a DATE column, so the fetch narrows exactly what the local predicate will and needs no auto-chain. Payments and bank transactions used to strip their `date` from the fetch and lean on `localOnlyFilterActive` instead: a filter for one day in 2019 chained page after page of recent payments to find it. The translation lives in each repository's `ensurePageLoaded`, so every caller — the list, an embedded tab, a Sync pass — sends the same wire. Pinned by `test/data/repositories/filter_key_parity_test.dart` and `test/ui/features/transactions/transaction_list_filters_test.dart`.

The server's timestamp windows have the opposite gap: `created_between` / `updated_between` read a bare end date as 00:00 and lost the last day, so `timestampWindowsForServer` stretches it to `23:59:59` (`BACKEND.md` § Two base `QueryFilters` gaps the client works around).

## A list that finds nothing offers the narrowing it can undo

**The no-match empty state offers All statuses, then Show archived, then Clear filters — each shown only when it applies** (`NoMatchActions`, `lib/ui/core/list/no_match_actions.dart`, shared by `EntityListEmptyState` and the scaffold's own fallback). Clear filters alone threw the typed search away with everything else, so someone who searched `acme` on the Overdue tab, or for a client archived last year, had to type it again on a wider list.

- **All statuses** drops only the status tab (`setBadgeMode(null)`). It is hidden when the tab is the only narrowing, because Clear filters does exactly the same then.
- **Show archived** adds archived to the State filter through `setStates`, the seam the `is:` key's picker uses. It lands as a chip that can be removed: every list on `EntityListScreenScaffold` declares that key — except Documents, which has no lifecycle, so `GenericListViewModel.hasEntityStates` is false there and the button is not offered. It was, until the footer below was built: the Documents watch ignores `states` and its repo sends none, so the click did nothing.
- **A `Wrap`, not a `Row`.** Three German labels do not fit at 360 px.

Pinned by `test/ui/core/list/entity_list_empty_state_test.dart`.

## The end of a narrowed list says what the State filter hid

**A searched or filtered list that reaches its last row with archived records excluded ends with "Archived records are hidden · Show archived"** (`ArchivedHiddenFooter`, `lib/ui/core/list/archived_hidden_footer.dart`, returned by the scaffold's `_footer()`). The beta report was "There is no Active / Archived / Deleted choices in the new version! I use this to see if certain invoices were archived." v1 had that dropdown beside the search box. In v2 it is the State key inside the search box, and its default renders no chip (§ A key at its default renders no chip), so nothing on screen said anything was hidden. The no-match empty state above already offered Show archived, but it needs zero rows: the reporter's client search matched four drafts, so the archived invoices it was looking for went unmentioned.

- **The gate is `ArchivedHiddenFooter.shows`**, kept pure so a test can pin each term. The list has a lifecycle (`hasEntityStates`) and rows. No page is loading and `canLoadMore` is false, so this is the true end; while more can load, the archived rows' absence says nothing yet. Archived is not already in `states`. And the user narrowed the list: `search` or `hasActiveFilters`, which counts a status tab, since Paid is where archived invoices go.
- **Only on a narrowed list.** An un-narrowed list that fits the screen would carry the line forever.
- **No embedded carve-out.** A detail tab's parent scope is applied inside its VM's `fetchPage` (`invoice_list_view_model.dart`'s `client_id`), not through the filter maps, so `hasActiveFilters` does not read true on every embedded list.
- **The wording is true with `{active, deleted}` too**, and the click keeps `deleted`: it is `setStates({...states, archived})`, the seam `NoMatchActions` uses, so it also lands as the State chip. That chip is how the user learns where the control lives now.
- **Start-aligned, never centred.** In the wide layout the `ListView` sits inside `_wideTable`'s horizontal scroller at the table's full width, so a centred line drifts off-screen once the columns outgrow the pane. The 16 px gutter is the rows'. It is a `Wrap`, because the sentence and the button do not fit one line at 320 px.
- **It needs the server to have answered.** Offline, a failed page fetch leaves `hasMore` true, so the line does not show — Show archived could only reach cached rows then anyway.
- **Rows still do not say they are archived** on most lists. Clients and Vendors carry an Archived / Deleted pill; every other list shows its own status (an archived invoice reads Paid), and the State column is opt-in through Columns. v1 and React replace the status with Archived / Deleted. That was left out of this change on purpose and is the obvious follow-up.

Pinned by `test/ui/core/list/archived_hidden_footer_test.dart`, which also mounts the real scaffold so dropping the `_footer()` branch fails.

## A purchase order's Sent status is exact only from 5.13.44

**A Status chip that includes Sent is sent to the server only when it answers `client_status=sent` exactly — hosted, or self-hosted from 5.13.44 (`ServerFeatures.purchaseOrderSentStatus`).** Before that the server's clause was an unnested `orWhere` that dropped a sent purchase order past its due date: a SUBSET of the rows, which no local predicate can put back. On an older or not-yet-known server the chip is applied locally only — `client_status` is stripped from the fetch and `localOnlyFilterActive` chains pages (`PurchaseOrderListViewModel`). Received has no server branch at all, so no chip offers it. The status tabs are consts and cannot be version-gated, so the Sent *tab* stays local everywhere. Pinned by `test/ui/features/purchase_orders/purchase_order_sent_status_test.dart`.
