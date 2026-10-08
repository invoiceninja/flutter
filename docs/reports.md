# Reports

Companion to CLAUDE.md § Reports. The main file carries the rule for each behaviour; this doc carries the evidence — the server contract each rule rests on, the failure it shipped as, and the test that pins it.

**The shape of the feature.** `/reports` is a gallery (`ReportsGalleryScreen`): the reports the company may open, grouped by purpose, each card offering its *starter views* ("By month", "By client") as one-tap ways in, with *Recent* and *Saved views* above. `/reports/:report` is one report (`ReportScreen`): a header, one row of controls that scopes everything beneath it, a summary card whose figures pick the chart's measure, and a table. A report with rows comes from `<endpoint>?output=json`; one the server only writes as a file is read back from that file (§ File-only reports on screen). Everything after the fetch is local.

| Piece | Lives in |
|---|---|
| What a report is: endpoint, filters it honours, row id, default columns, headline figures, starter views | `lib/domain/reports/report_registry.dart` (`ReportDefinition`) |
| Rows → view (filter, search, sort, group, per-currency totals) | `report_engine.dart` |
| View → chart (trend / ranking / groups over time / top rows) | `report_chart_model.dart` |
| View → table lines (groups that open in place) | `report_table_model.dart` |
| File → document | `report_document.dart` |
| State, runs, memory, comparison, saved views | `lib/ui/features/reports/view_models/reports_view_model.dart` |
| Screens and widgets | `lib/ui/features/reports/views/`, `widgets/` |

## The date range filters a column the report never names

**The date range filters a column the report never used to name, and that column is not always one you can group by.** Each export declares `public string $date_key` server-side (`created_at` for clients / contacts / vendors / products / activity / documents / credits — and for `client_balance_report` / `user_sales_report`, where it means the **invoice's** created date, since both pass table `'invoices'` to `addDateRange`; `date` for the billing docs and expenses; `calculated_start_date` for tasks), mirrored on `ReportDefinition.dateRangeKey` and surfaced read-only under the Date Range control via `reportDateKeyLabelKey`. It is **read-only on purpose**: `ClientExport.php` passes its table name to `addDateRange` as `' clients'` with a leading space, so `columnExists` always fails there and a caller-supplied `date_key` can never override `created_at` — a picker would be a lie on the one report it matters most for. Four reports declare **no** key: `profitloss` and `tax_period_report` own their date semantics, while `ProjectReport::getPdf()` and `ARSummaryReport` both document `date_range` in their input contracts and never call `addDateRange` — so those two ranges are inert server-side (AR Summary's only date predicate is the aging buckets' `whereBetween('due_date', …)`). Naming nothing there is the honest outcome; `report_registry_date_keys_test.dart` pins the set. `ReportFilterField.dateColumn` used to exist for this and rendered **nothing** on the 12 reports that declared it — `_FiltersSection` filtered it out before `_FilterControl` was ever built, so its `case` arm was unreachable padding. It is retired.

## Asking for a column the server omits

**A column the server omits can still be asked for, and that is how "new clients per month" works at all.** `BaseExport::$client_report_keys` carries no `created_at` (no entity key map does — `DocumentExport` is the lone exception in the whole export layer), so the clients report has no date column to group by even though its range filters on one. `ReportDefinition.optionalDateColumnId` (`client` → `client.created_at`) opts into asking for it: the preview then sends the server's **own returned column set plus that one**, never a subset — `runReport`'s comment explains why a subset is unrecoverable. Verified live: the server honours an arbitrary `client.*` key because `buildRow()` falls through to the transformed model, the value arrives as **epoch seconds** (already handled — `_parseTyped` reads `value is num` for a `*_at` column) and the header as the literal string **`"texts."`** (`ctrans` on a key with no entry), which `_relabelOptionalDateColumn` replaces from `optionalDateColumnLabel`, fed by the screen. Five things are load-bearing. It is **strip-then-append, never skip-if-present** — after the first augmented run the preview *contains* the column, so a `contains` guard sends `[]` on the second run and the column vanishes, a bug invisible until you press Run twice. It must be **added to `_visibleColumnIds` explicitly**, because `_reconcileWithColumns` deliberately never un-hides a column and the switch would otherwise appear to do nothing. `serverReportKeys()` strips it from export / email / schedule **and so must `group_by`** (`serverGroupBy`), because `GenericReportRequest::prepareForValidation` unshifts a `group_by` back into `report_keys` — stripping the key alone puts the column straight back into the file, as a raw epoch, grouped one-per-row (`BaseExport::groupRows` buckets on the exact value). The flag joins **`isParamDirty` by hand**, since it changes the fetch without touching the payload and the Run button would keep reading "Run report". And `_serverColumnIds` is **persisted** so a restored grouping survives the cold run that would otherwise drop it. The entry point is the **Group by dropdown**, which is gated on `hasPreview` — that is what guarantees a live column list to augment, with no cold-start case — and which runs the report itself; the switch beside it is the state display and the way back out (a non-empty `report_keys` *pins* the column set).

## A period with no rows has no bucket

**A period with no rows has no bucket, so a chart plotting buckets by index closes the gap.** `_bucket` only emits a bucket for a date that has rows: January and March draw as neighbours and the empty February is not a zero, it is gone. `ReportEngine.dateBucketSpan` supplies the contiguous keys and `ReportsViewModel.chartBucketKeys` decides when to use them — **interior only** (never the selected range, or "This year" in March asserts zeros for months that haven't happened), only when the subgroup is **declared** (a null one means the granularity is unknown, and `_dateBucket` would silently assume days), and capped at `kMaxReportChartBuckets` (750, the dashboard's own `_maxRenderBuckets` — a span that *reaches* it is refused, not truncated, and the caller then plots the raw buckets rather than coarsening, since the user picked this granularity). A real time axis would make gaps free but is wrong here: these x-values are *period buckets*, so February must be one step, not a shorter one.

## The count series, and bucket keys as identity

**`GroupTotals.count` is a chart series, and bucket keys are identity.** `kReportCountSeriesId` rides ahead of every numeric column in the chart's picker; `defaultReportSeriesId` picks it when there is nothing numeric (which used to be the `no_numeric_values_to_chart` dead end — that string still ships, and is still reachable when a numeric column's group totals are all zero) or when the grouping is the optional date column, and the first numeric column otherwise, so an invoice report grouped by date still charts Amount. A count has no currency and its y-axis skips fractional ticks, or a max of 7 renders "2.4". Group keys stay raw ISO — `ReportEngine.compute` re-derives them from each row's own cell to match `selectedGroup` on drill-down, so a key whose format changes stops matching — and only the **display** is formatted, at all four render sites (chart axis, wide group row and its semantics label, drill breadcrumb, narrow card list), through `reportGroupDisplayLabel`. Month / quarter / year go through `DateFormat` **skeletons** (`yMMMM` / `yQQQ` / `y`), never a literal pattern; day and week through `Formatter.date`. `setGroup`'s `subgroup` parameter means "keep" when null, not "clear".

## A non-date grouping splits by period through a composite key

**A non-date grouping splits by period through a composite key, derived in one place.** "Hours per user per month" was the ask: before this you could group the Task report by Assigned User *or* by Start Date → Month, never both. `ReportUiState.periodColumn` names a date / dateTime column. When the group column is **not** itself a date, each bucket key becomes `<group>␟<period>`, where `␟` is `kReportGroupKeySeparator` (U+001F, which can't occur in a display value) and the period is the same ISO bucket start a date grouping at `subgroup` would produce (month when null). `splitReportGroupKey` splits it.

Four things are load-bearing:

- **One key function.** `ReportEngine._rowGroupKeyFn` is the only place a row's key is derived. `_bucket` builds groups with it and the drill-down filter matches `selectedGroup` with it. That is the same keys-as-identity rule as § The count series, and bucket keys as identity: two derivations would drift, and a drill would show "No results".
- **Fallback.** A period column that is missing from the preview, or not a date, gives the **plain** key. A date group column ignores `periodColumn`. So a stale persisted value degrades to ordinary grouping instead of emptying the table. The VM also clears the value: `setGroup` clears it for a date or null group (but keeps it across two non-date columns), `_reconcileWithColumns` clears it when the column vanishes, and `setIncludeDateColumn(false)` clears it when it was the optional column.
- **Labels.** Every render site already goes through `reportGroupDisplayLabel`, which detects the separator and renders `<group> · <period>`. A row with no date renders as the group alone, and an empty group as the period alone. Ordering is group first (numeric-aware, as before), then chronological, with the undated bucket last. The chart gets no gap-filling here (`chartBucketKeys` returns `[]` for a non-date group column), because interleaved users aren't a timeline.
- **Local-only.** `serverGroupBy` never sends the period: `BaseExport::groupRows` groups on one exact value. A CSV/PDF downloaded from a user × month view is therefore grouped by user alone.

**The optional date column is also a period candidate**, reusing the Group by machinery in § Asking for a column the server omits. Picking it from the Subgroup dropdown opts in and runs the report. The contact / vendor / product reports now declare `optionalDateColumnId` too. All three omit `created_at` from their report-key maps, and each was probed live on 2026-09-23: the value comes back as epoch seconds under the header `"texts."`, exactly as for clients. The candidate list puts the column the date range filters on first (`calculated_start_date` → `task.start_date`).

For tasks, bucketing on `task.start_date` is exact per time entry: `TaskExport` emits one row per log entry. The Date Range, though, filters on the **task's** `calculated_start_date`. So a task that spans a month boundary contributes entries on both sides, and a range of exactly one month can include or exclude neighbouring entries. Widen the range and read the monthly buckets.

## A report runs itself

**Opening a report runs it; there is no Run button.** `ReportScreen` calls `ReportsViewModel.open(id)`, which switches to the report (putting the previous one's state away, taking this one's back out) and then `_showOrRun()`. Every change that alters the rows — the range, a server filter, the optional date column — schedules the same call.

Because nothing asks the reader's permission, the run is hedged five ways, and each is a failure that was reachable without it:

- **Debounced and superseding.** `_scheduleAutoRun` waits `autoRunDebounce` (400 ms) and a run is stranded by `_runEpoch`: `setReport` bumps the epoch, because a run only ever checked its own epoch and one switched away from mid-flight still landed — its rows appearing under the new report's name and columns (`reports_memory_and_auto_run_test`).
- **Never while offline or behind the plan gate.** `_mayRun` is `isOnline && canRun()`. A run that could not be made is *owed* (`_autoRunOwed`) and made when the connection or the plan comes back (`_onOnlineChanged`, `retryOwed`). The report routes are throttled to 20 a minute, and a screen that retried on its own would spend them.
- **Not when the result on screen is still good.** `freshFor` (5 min): reopening a report shows what it showed.
- **From disk first.** The last result for a request is kept in the cache-class `dashboard_cache` table under kind `report` (`ReportCacheStore`, keyed on the report and its canonical request JSON, capped at 12 entries and 2 MB each) and shown at once with its age while the run behind it replaces it. A refresh that fails leaves it there, under a notice saying when it is from (`ReportNotice`) — never an error page over a result the reader already had.
- **A 429 is a state, not a retry.** `ReportErrorKind.rateLimited` draws the notice and waits to be asked.

**The view model lives above the routes.** `ReportsHost` is a `ShellRoute` over the gallery and the report route and owns the one `ReportsViewModel`. A view model per route would be two writers flushing one `nav_state` blob during every switch, and a result thrown away each time the reader glanced at the gallery. The report route is *nested* under `/reports`, not a sibling: a report restored on a cold start has no history behind it, and Android's back must then go up to the gallery rather than leave the app. A report this company may not open — a stale restored address, a typed one — is redirected to the gallery by the same predicate the gallery and the command palette filter with (`helpers/report_access.dart`).

**`open` must not be called from a build.** Once the saved state has loaded, `open` notifies synchronously. `didChangeDependencies` and `didUpdateWidget` both run inside a build, so the screen defers it with `scheduleMicrotask`; the frame in between draws the skeleton. The first render harness for the screen found this as an assertion.

**State is remembered per report**, inside `nav_state.filters_json[companyId]['reports']` (no schema change): the current report's keys at the top level (which is what an older build reads), a `reports` map of the eight most recently opened, and a `recent` list. A report never opened gets its *opening view* — its first starter view — instead of an empty table.

## Every request says whether to email

**`send_email` is written on every report request, `false` included.** `GenericReportRequest::prepareForValidation` (and the product-sales and project request classes) set a *missing* `send_email` to `true`, and every report controller then takes the email branch unless the request also carries `output` — it dispatches `SendToAdmin` and answers `{"message": "working..."}`. A preview is safe by accident (`?output=json`); a file request is not.

The payload used to write the key only when it was true. So every request for a report's file was emailed to the user instead of answered, and the reply — in the same `message` key a job id arrives in — was polled as an id for a hundred seconds of 404s. That was the real reason the old Export button "timed out", and once file-only reports were fetched on opening (§ File-only reports on screen) it meant **looking at a report sent it to the reader's inbox**. Found by the first person to open one in the running app; the demo-server probes had all sent `send_email: false` by hand and so never saw it.

Two things keep it from coming back, and the second does not depend on the first:

- `ReportPayload.toJson` always writes `send_email` (`report_payload_test`, and the repository tests for a preview and an export).
- `ReportsApi._postForHash` refuses a reply that is not a single token and throws `ReportEmailedInstead` rather than poll it — the server can still force the email branch on its own (it does for a user with neither admin rights nor `view_reports`). That surfaces as `ReportErrorKind.emailedInstead`: a notice saying the report was emailed, **with no Retry** (each retry is another email), and the view model does not auto-run that request again (`_emailedFor`) — only the reader pressing refresh, or a changed request, asks again.

## What a figure may add up

Four separate things were wrong with the totals, and each was a number on screen that was not true.

**A cell's `id` is its field name.** `BaseExport::processMetaData` writes `id` as the column key (`"number"`) and puts the related record's id in `hashed_id` — which is null for the row's *own* entity. Tapping an invoice row opened `/invoices/number`. Related cells (a client, a vendor) now link through `hashed_id`; a row opens its own record only when the report declares a `rowIdKey` (`invoice.id`, `product.hashed_id`, …), which is requested as an ordinary column, then **stripped off the table and onto the row** by `withRowRecords` so it is never offered in the column picker, grouped by, searched or exported. It is fetched in a silent second request the first time, because a non-empty `report_keys` pins the server's column set and the app does not know that set until a plain run has returned it.

**Cells carry no currency.** Every total landed in one bucket and was shown in the company's. Each report declares the column that holds its row's ISO code (`client.currency_id`, `payment.currency`, …); `withRowCurrencies` stamps `ReportRow.currencyId`, and the engine totals per currency. A result holding several is **read in one at a time** — `ReportView.currencyId`, resolved once by the engine (`resolveViewCurrency`: the reader's choice, else the company's, else the most common) because the engine uses it: a sort by an amount ranks groups by their totals *in that currency*, and a group with nothing in it sorts last rather than at whatever its bare number happens to be. In the table, a group that is entirely in another currency shows its own total in its own notation, quieter (`_figureOf`); a blank there said the client had no invoices. **The row count is never scoped by currency** — it is not an amount, and scoping it left the figure above the table at odds with the table.

**A line-item report repeats its parent's amounts on every line**, and the task report emits a row per time entry. `ReportAggregation` classes every column: `sum`, `none` (a rate, a unit price — there is no "tax rate by month"), or `oncePerRecord`, which is deduplicated by `ReportRow.recordId` and not totalled at all when the rows carry no id (`report_totals_test`).

**Numbers arrive formatted, in the company's notation.** `parseFormattedMoney` is given the company currency's separators and precision (`FormattedNumberStyle`); without them `1.234` is ambiguous, and a client balance of 3,125.00 was read as 3. Cells then render through `Formatter` from their typed value — the server's string is shown only for text.

## The table is slivers of the page

The report has **one vertical scroll**: the summary scrolls away, the header and the totals line pin (`PinnedHeaderSliver`), and the rows are a `SliverFixedExtentList` beneath them, so a result of fifty thousand rows is laid out by arithmetic. A table with its own scroll inside a scrolling page is the arrangement where the wheel stops working halfway down.

Columns scroll sideways through **one shared `ViewportOffset`** (`ReportTableHorizontalScroll`), with every line shifting its own cells by a `Transform` and the first column held in place — no two-dimensional viewport, no package. `ReportTableLayout` decides the widths: sized to what the column usually holds, spare room given to the text columns, and a table that misses its pane by under 12 % is squeezed to fit rather than scrolled for forty pixels.

- **Totals sit at the top**, under the headers they total and pinned with them, not at the foot of a list that may be thousands of rows away.
- **Groups open in place** (`buildReportTableLines`); a grouping split by period nests the periods under each group.
- **A category grouping opens ranked.** Grouped by client, the chart above is a ranking; a table beneath it in alphabetical order is a second, different list of the same things. `_syncRanking` sets an ordinary, visible sort on the charted figure, descending — only in place of no sort or of a ranking it set itself, and it takes it off again for a date grouping. The flag is persisted with the sort: restored looking like a choice, it would survive a switch to "by month" and list the months largest first.
- **On a narrow pane a group line is one figure** (`ReportTableSummary`). A phone shows the held column and about one more, so a group line laid out on the columns showed a name and no numbers. It is drawn full width — name, count, and the total of the figure the chart is of — and the rows inside a group are still a table.
- **Under a finger the whole header opens the column menu**, which leads with the two sorts. A header that sorted on tap and also carried a 44 px menu button spent a third of a phone's table on buttons. With a pointer the header sorts, shift-click adds a second key, and the menu button appears on hover.

The export that honours all of this is the local one (`report_csv.dart`): machine values, a formula-injection guard, a BOM. The server's file knows nothing of a column filter or the row search.

## File-only reports on screen

Ten reports have no JSON form. Eight of them — profit and loss, the aged-receivable pair, client balance, client sales, tax summary, user sales, product sales — the server writes as a CSV (`ReportDefinition.readsAsDocument`), and those files are not arbitrary: each is some sequence of a **heading** (a line of one cell), **facts** (a label and its value), and a **table** (a header and rows, captioned `Currency,GBP` where the server writes one table per currency), separated by blank lines or rules of dashes. `parseReportDocument` reads that grammar and nothing more specific. `test/domain/reports/fixtures/` holds what the demo server answered for each; the parser is tested against those files, not against a guess at them.

What makes it safe to do generically:

- **Nothing matches on a header's text.** Headers are in the server's language. The aging buckets are "every money column but the last"; the ranking column of a client report is a position.
- **A column's kind is read from its cells.** One cell that is not a number makes it text. `0004` is an identifier, not four — a leading zero followed by a digit is the tell — so client and invoice numbers are neither right-aligned nor summed. Only a column whose cells carry a currency symbol is totalled: a column of tax rates has no meaningful sum, and nothing in the file says which bare numbers are counts.
- **A word beside a number is not a currency.** `July-2026` is a column header in the client sales file; read as "−2026 in the currency July" it stopped being a header, and three of that file's nine tables were read as loose lines. Letters around a figure count as a currency only as an ISO code (`USD 100`) or beside a figure formatted as an amount (`kr 1 250,00`), and never across a hyphen. Found by running the app's own requests against the demo server — the fixture for that report had been trimmed above the tables that showed it, so it is now the whole file.
- **A per-currency table is read in that currency's notation** (`€1.717,00` under `Currency,EUR` is 1,717).
- **The picture is of the tables a report opens with.** A file may break the same figures down again under a heading ("Invoices by month"); those tables are drawn as tables, with no ranking over each.
- **A preamble line may be followed by a table with no blank line between** — the server writes `"Created On"` straight over the first `Currency,` caption. The first version peeled only leading headings and lost the whole first table into the file's metadata.
- **A lone two-word line inside the report is the header of a table with no rows** ("Tax Name, Tax Amount" when no tax was charged), and is dropped rather than shown as a fact.
- **It returns null for a file it cannot make blocks of**, and for a file that is not a CSV at all; `documentUnreadable` then shows the download the report always had.

The cells shown are the server's own strings. The app adds what the file lacks: a total under each column of amounts, an aging bar (one hue, lighter to darker with lateness, the not-yet-due bucket neutral, every bucket also in words), and a ranking for the client and user reports. Tables are not lazily built — they scroll sideways as one piece — so one is shown by its first 200 rows with the count and a pointer to the download.

Projects (a PDF) and the tax period report (XLSX) remain downloads.

## Compared with the period before

Opt-in, beside the range. It is a **second run** of the same report over the earlier window (`_runCompare`): quiet — no spinner, no error — because a comparison that could not be had is simply not shown.

**The window is the dashboard's, not a second rule** (`DashboardFilter.comparison`): a period still in progress is compared with the same elapsed span of the one before, so the 8th of October sets this year to date against last year to the 8th of October. Whole-window-shifted-back made every figure fall steeply until the period was nearly over. "All time" has no period before, and the control is not offered.

**Periods are paired by position, never by index.** This year's rows may start in March while last year's start in January; by index March would be set against January. `previousPeriodOf` answers "which earlier bucket is this one's counterpart" by counting buckets from each window's start at the report's granularity. An earlier period with no rows is a real zero; a period with no counterpart (the earlier window was shorter) is nothing (`report_chart_model_test`).

What it draws: a delta under each figure, with the good direction decided by what the figure is (a rising unpaid balance or expense is red, not green); a delta on each line of a ranking, where a group that did not exist before shows a dash rather than an infinite rise; and in a trend, the earlier period beside each column in neutral ink, with a legend that says the earlier period in dates.

Known limit: the current figures are of the whole selected range, so a range holding future-dated documents is compared with slightly less than itself.

## Saved report views

A view is the report's whole arrangement — range, filters, columns, grouping, sort, charted figure, comparison — under a name (`ReportsViewModel.reportViewState`, which leaves out what is the device's business: column widths, and which view it is).

**They are rows of the existing `saved_views` table with `entity_type = 'report'`** (`kReportSavedViewType`). That is not an `EntityType` — a report is not an entity — and the column is text, so there is no migration. The two kinds never meet: every entity-typed read skips a `report` row (silently; it used to be logged as an unknown entity on every emission of the sidebar's stream), and every report read asks for exactly that type.

The header's bookmark says which view the report *is* (`viewId`, remembered with the report): filled when it is one, with a dot when it has been changed since. Nothing is lost by ignoring the dot — the report keeps its own state either way. The gallery lists them; `?saved=<id>` opens a report in one and is stripped from the address once applied, as `?starter=` is. (Not `?view=`: that key already means a layout on Tasks and full-screen on every list.)
