# The activity timeline — what `/activity` can draw, and from what

Companion to CLAUDE.md § Design system, which carries the rule in one line. This doc carries the evidence: why the timeline covers only the loaded window, which filters each count leaves out, and why the chart is one colour.

The screen is `lib/ui/features/activity/views/activity_screen.dart`. The bucket and run arithmetic is a pure leaf, `lib/domain/activity/activity_timeline.dart`, so it is unit-tested without a widget (`test/domain/activity/activity_timeline_test.dart`).

## The `/activity` timeline charts only the loaded window, and each count leaves out its own filter

**The window is all there is.** The feed is `GET /api/v1/activities?reactv2&rows=N`: 250 rows (`kActivityFeedRows`), grown by Load more up to 1000 (below). The `reactv2` branch of `ActivityController::index` is `orderBy(created_at)->take($rows)` and nothing else: no page, no offset, no date filter (BACKEND.md § F3). The Activity report (`/reports/activities`) does take a date range, but `ActivityExport::buildActivityRow` returns rendered text (date, sentence, address, notes) with no `activity_type_id` and no record ids, so it can't draw a category or open a record. Everything on this screen is therefore computed on the device over the rows held. The resting readout says so: "N events since <oldest day>".

**Bucket width follows the window.** 250 rows is an afternoon on a busy account and years on a quiet one, so `bucketSizeFor` picks hour (≤ 2 days), day (≤ 62 days), week (≤ 1 year), month (≤ 5 years) or year, which keeps the bar count at or under about 63. Three rules hold the axis steady:

- **Empty periods are zero bars, never missing ones.** A quiet month is the thing the chart exists to show.
- **The axis is computed from the whole window (`spanOf`), not the filtered rows.** Ticking a filter must not rescale the bars under the pointer.
- **Week bars start on the company's first day of week**, else the locale's (`calendarFirstDayOfWeek`). Boundaries are built with `DateTime(y, m, d)`, never by subtracting a `Duration`, so a DST change can't move one off midnight.

**Each count leaves out its own filter — the facet rule.** `ActivityViewModel._recompute` makes one pass and fills three outputs:

| Output | Passes every filter except | Why |
|---|---|---|
| `timeline` | the date range | The bars keep their context while you pick a period; a picked range highlights its bars instead of deleting the rest. |
| `categoryCounts` | the categories | An unticked chip says what ticking it would add, rather than reading 0. |
| `entries` / `matchCount` | nothing | This is the feed. |

A category chip whose count is 0 and that isn't already on is disabled, because ticking it could only empty the feed.

**One series, one colour.** Stacking the bars by category would need seven separable hues. The tone palette paints `draft` and `neutral` the same grey (`ink3`), and the rest are status colours, which a chart may not reuse as series colours. Instead, the category filter redraws the bars as just that category. The feed underneath is the chart's table view.

**The readout line replaces a tooltip.** Hovering or dragging rewrites the line above the plot. A finger mid-drag can still read it, where a floating tooltip would sit under the finger.

**The chart sits outside the `SelectionArea`.** A mouse drag across the bars is a range pick. Inside the region it would race text selection for the same drag.

**On a short pane the chart is dropped, never the feed.** Below `kActivityTimelineMinBodyHeight` (420 px of body), the strip goes. That threshold is a landscape phone, which already spends half its height on the app bar, search and chips.

**The date range is stored as instants, not days.** A bar can be one hour, and a day-granular range could not say "the 3 PM bar". The range is `[from, until)` in local time, persisted as local ISO with no `Z` inside the shared `nav_state` filters blob, so no schema change is needed. A preset from the dashboard's `DateRangePickerButton` ("Last 30 days") is resolved to dates **when it is picked**. That gives the filter one shape, and its chip prints the dates it is actually applying. "All Time" is how the picker says "no range".

**Runs fold, and only safe ones.** `collapseRuns` folds consecutive rows that share an actor, activity type, target record (`activityDeepLinkTarget`) and local day into one row plus a `+N more` / `Collapse` toggle. Two kinds of row never fold:

- **A row with no target.** "Same type, same user" with no record to agree on is two different events that share a verb.
- **A comment.** Each one is different text.

The day header still counts every row in a run. Whether a run is open is view state: it isn't persisted, and it lasts across a refresh only while the run's newest row does.

## The activity cache row is merged, not replaced, and Load more grows it to 1000

**One row, two readers.** The `(company, activities)` row in `dashboard_cache` feeds both the dashboard's 5-row card and this screen. Every fetch used to replace it, so the card's next 250-row refresh would shrink a window the screen had grown. `DashboardRepository.refreshActivities` now merges each fetch into the row through `mergeActivityWindow` (`lib/data/repositories/activity_window.dart`). Older cached rows survive a fetch under two conditions:

- **The fetch must reach back to the newest cached row.** Otherwise both windows are missing something in between, and keeping the old rows would draw a quiet stretch that wasn't quiet. The fetch replaces the row instead.
- **Inside its own time span, the fetch wins.** A cached row there that the fetch no longer returns is dropped. Only rows older than everything fetched carry over, plus rows tied with its oldest second, which the fetch may have cut through.

The result is newest first, trimmed to `kActivityCursorWindowMax` (2500). That is the larger cap on purpose: a window paged back with the cursor (below) must survive the card's next refresh, and a fetch without the cursor never asks for more than `kActivityWindowMax` anyway.

**One refresh at a time.** Each refresh reads the row, merges and writes it back. Two interleaved refreshes would each merge onto the row as it was before the other, and the later write would drop the earlier one's rows. So `refreshActivities` chains its calls, and a failed call doesn't block the chain. `dashboard_repository_test` › activity window pins this with `peakInFlight == 1`.

**Without the server cursor, Load more grows the window.** On a server without `before` (below), `DashboardRepository.loadOlderActivities` asks for the newest `N + 250` rows, capped at `kActivityWindowMax` (1000). Each step re-sends every row before it, which is why the cap exists. The button appears both under the feed and in the timeline's header, since the chart is where the window visibly ends. It is offered only while the window is full: `canLoadMore`. Two things turn it off:

- **A short fetch.** Any fetch that returns fewer rows than it asked for means the history is complete, and the flag stays set.
- **The cap.** At the cap (`ActivityViewModel.windowMax`: 1000 without the cursor, 2500 with it) the footer points to the Activity report instead, and only when `openableReport` would let the route open.

**What the server offers, probed against `demo.invoiceninja.com` on 2026-10-18:**

- **`?reactv2&rows=N` takes any `N`** (`take($rows)` has no cap), at about 120 bytes per row on the demo.
- **The flat `?per_page=N&page=P` branch really pages** (`meta.pagination`), but it carries no labels. A sentence would read "User created invoice" with no number or name, unless every row also asks for `include=client,invoice,…`.
- **That flat branch likely errors for a restricted user** (BACKEND.md § F3, the `assigned_user_id` note). Not probed; the demo token is an admin.

The real fix is a keyset cursor on the `reactv2` branch (BACKEND.md § F3f), which the app already uses where the server has it — next section.

## With the server cursor, Load more pages back instead of re-downloading

**The cursor names an activity.** `GET /activities?reactv2&before=<hashed id>` returns the activities after that one in feed order (BACKEND.md § F3f). `loadOlderActivities` sends the hashed id of the oldest row held (`oldestActivityRow`) and appends the reply with `appendOlderActivities`, which skips rows already held by id. Each Load more then costs one page, so the cap rises to `kActivityCursorWindowMax` (2500), bounded by the cache row's size — every emission of it is decoded whole — rather than by re-download cost.

**Picking the cursor row inside a second is safe.** The payload's `created_at` is whole seconds; the server orders by the stored microseconds. Within the oldest second the app may name a row that isn't the feed's last, and the server then answers with a few rows already held. They are dropped by id; nothing older can be skipped, because everything older is after any row of that second.

**Support is read from the reply, not a version.** A server without the cursor ignores `before` and answers with the newest rows. `pageHonouredCursor` checks that no returned row is newer than the cursor row's second. If one is, the company is remembered as cursor-less for the session and Load more falls back to the growing window. Unknown counts as paged, so the first Load more past 1000 rows still asks. A reply that isn't a list falls back once without being remembered.

**A cursor row the server no longer has is dropped, not re-fetched around.**
- The server answers a `before` naming a deleted activity with a 422, `before: record_not_found`. Purging a client force-deletes all of its activities, so a run of tail rows often goes at once.
- `loadOlderActivities` drops the vanished row from the cache, keeping its `fetchedAt`, and asks again from the next oldest row, up to `DashboardRepository.kActivityCursorGoneHops` (5) times per call. Past that it rethrows, so the footer shows the failure, and the next tap continues from the smaller window.
- It used to re-fetch the newest window instead and let the merge drop the vanished row. A window deeper than that fetch (≥ ~1000 rows) carried every older row over, the vanished one included, so every Load more 422'd on the same row and the button never went away.

**Tests:** `activity_window_test` › paging back with the cursor, `dashboard_repository_test` › loadOlderActivities, `activity_view_model_test` › load more.
