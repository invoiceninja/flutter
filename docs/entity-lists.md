# Entity lists — columns, status tabs, state filter, counters

Companion to CLAUDE.md §§ List columns, List status tabs, List state filter and Sidebar counters. The main file carries the registry shapes and the rule for each behaviour; this doc carries the evidence. Section headings here mirror the CLAUDE.md ones, so a bare `§ List status tabs` citation resolves in either file.

## List columns

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

### A server mapping must return a superset of the local predicate

**A server mapping must return a SUPERSET of the local predicate.** Over-fetching is free (the local predicate discards the extras); under-fetching silently hides rows — the tab reads "Expired 12" over eight rows and the missing four never arrive. Where the obvious value is a subset, *widen* it (quotes send `client_status=expired,draft` because the app also counts a past-due draft as expired) rather than dropping to local-only. The unmapped modes each say why in `list_status_tabs.dart`, and `list_status_tabs_test` pins the exact set so mapping one later is a deliberate edit. The cleanest case is an **exact** mapping — clients send `balance=gt:0`, which is `ClientFilters::balance` clause-for-clause, so `widened` stays false and the chain stays off; note the operator lives in the *value* and the server parses it off the PREFIX, so a suffix `0:gt` silently runs `where('balance','=','gt')` (≈ "balance is zero"), the exact inverse of that tab.

### A widened mapping must be marked `widened: true`

**A widened mapping MUST be marked `widened: true`, and that flag is not bookkeeping.** `statusTabNarrowsLocally` — the gate on `localOnlyFilterActive`, i.e. on the auto-chain — is true for an unmapped tab **and** for a widened one, because in both the Drift predicate is still throwing rows away after the fetch lands. Gate the chain on "has no server mapping" instead and five tabs break the same way: a widened fetch fills page 1 with rows the local predicate discards (Quotes → Expired pulling 50 drafts to find 3 expired quotes), the emission is shorter than a page, there is no scroll extent for the load-more trigger, and the tab renders "Expired 3" over a false "No records found". Only an **exact** mapping — server clause and badge predicate select the same rows — leaves the chain off, **and only while nothing preempts it**: `_serverExtraFilters`' `putIfAbsent` lets a filter the user set by hand keep the tab's own server key, so the fetch is then whatever *they* asked for and the local predicate is discarding rows again however exact the spec is. `statusTabMappingPreempted` re-arms the chain for that case; it is reachable wherever a tab's server key doubles as a user-facing filter key (Clients `balance`, Invoices `status_id`).

### A tab reading another entity's table has to fetch that table too

**A tab whose predicate reads another entity's table has to fetch that table too, or it reads zero.** Clients → Overdue is `clients.id IN (SELECT client_id FROM invoices WHERE …)`, and login prefetches **page 1 only** per entity (`Services.prefetchSidebarEntities` — the 50 newest by the server's default `id DESC`), while a full `refreshAll` runs only from a **user-triggered** Sync. So on any account whose overdue invoices weren't among those 50 the tab read `Overdue 0` over a false "No records found" *and*, being local-only, armed the auto-chain to page through the whole client list for matches that could never appear (invoiceninja/flutter#119). `ClientListViewModel.fetchPage` now pages the invoice repo with `extraFilters: {'overdue': 'true'}` — the same filter Invoices → Overdue sends, and a superset of `invoiceOverdueFilter` — **before** fetching clients: gated on `page == 1` (every reset funnels there; `loadMore` and the auto-chain don't), bounded at 5 pages, latched to one attempt per data generation (the flag is set *before* the first await as a **concurrency** guard — two page-1 fetches can overlap — and released again on failure, since the auto-chain provably cannot reach the hydration: `loadMore` only ever fetches `loadedPages + 1`), re-armed by pull-to-refresh, and failing **silently** with the sidebar prefetch's log policy (`NetworkException` → `fine`, else `warning`) because the clients list the user actually asked for must still load. Three non-obvious parts: it is **awaited, not concurrent** — the base clears `isLoadingPage` in its `finally`, so a late arrival paints "No records found" for a beat and the auto-chain meanwhile spends its whole budget scanning clients against an empty invoice table; **nothing re-subscribes** afterwards, because drift puts a subquery's table in the outer query's `readsFrom` set, so the clients watch and the tab's count both re-emit on the invoice upsert (`sidebar_badge_count_test` already pins that reactivity); and the repo param is **nullable**, so deleting the `invoices: services.invoices` line in `client_list_screen.dart` reverts the tab to the bug in total silence — `status_tab_wiring_test` pins that one line. It fixes the *predicate*, not the local-cache ceiling: a client not yet in Drift still needs a scroll or a Sync, and the **sidebar badge** stays cache-bound since only the tab hydrates (a badge may never issue a network call). **Vendors' `unpaid_expenses` / `open_purchase_orders` have the identical shape against `expenses` / `purchase_orders` and are knowingly NOT fixed** — a second case is worth copying; a third should be promoted to a shared helper taking a `Future<bool> Function(int page)`, not to a `GenericListViewModel` virtual (the base already owns the "when": every fetch path funnels through `fetchPage`).

### The strip's edge fades are gated on scroll position

**The strip's edge fades are gated on the scroll position, like `EntityDetailTabs`'.** An unconditional trailing fade veils the **last tab's own count badge**: the scroller carries a `start:` `contentPadding` and no `end:` one, and the badge is the tab's final child behind only `InSpacing.md` (8 px on a phone), so once the strip reaches its end the number sits inside the 24 px gradient. Two ordinary routes get there — flicking the strip, and a `badge_mode` restored from `nav_state`, where `_revealSelection`'s one-shot `ensureVisible(alignment: 0.5)` clamps to `maxScrollExtent` and parks that tab flush against the edge. Three things follow the sibling strip — `EntityDetailTabs`, in `docs/comments-and-activity.md` § The record’s own history leads every detail strip — for the same reasons documented there: `hasContentDimensions` (not just `hasClients`, or reading extents pre-layout throws out of `ScrollPosition.minScrollExtent`); a **post-first-frame `setState`**, because `attach` adds the listener without notifying, so a strip nobody scrolls would never paint its trailing fade; and a `NotificationListener<ScrollMetricsNotification>`, because a width change that leaves `pixels` alone reaches no `ScrollController` listener. Unlike the sibling it uses `PositionedDirectional` + `AlignmentDirectional`, so the fades stay on the right physical edge in Arabic / Hebrew — which is why the two `_edgeFade` helpers are **not** shared. Note `_revealSelection` uses the *static* `Scrollable.ensureVisible`, which walks every enclosing scrollable; that is safe only because `_bodyWithBanner` mounts the strip as a plain `Column` sibling of the list. Move it inside a scroll view and it would drag the page vertically on launch.

## List state filter

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

## Sidebar counters

### Counts come from the local Drift cache, so they can under-report

Counts come from the **local Drift cache**, which after login holds page 1 per entity and fills in as the user browses (or runs Sync) — so on a large account a counter can under-report, exactly as the plain total always has. Making it exact needs a server-side count; `ApiClient.getList` currently discards the response `meta`.

### Date-sensitive counters go stale past midnight

Second known staleness: `Date.today()` is baked into the SQL when a badge stream is built, and a sidebar stream lives for the whole session — so **leaving the app open past midnight keeps the date-sensitive counters (invoice/client/project `overdue`, quote `expired`) on yesterday's date** until a restart or company switch. The list filter chip has always had this property; it's just more visible on a permanent surface. Fixing it needs a date-rollover trigger to re-key the streams — deliberately not built.
