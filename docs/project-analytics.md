# The project Analytics tab

Companion to CLAUDE.md § Detail screens. This doc owns the project record's Analytics tab — `lib/ui/features/projects/widgets/detail/analytics/` and `ProjectAnalyticsViewModel`, over `POST /charts/project_analytics/{id}` and `/charts/project_burnup/{id}`. CLAUDE.md is at its size cap, so these rules are indexed from `docs/README.md` rather than from a bullet there.

## One scrolling tab, in React's order

**Forecast, Burn-up, Money, Time, Expenses — one tab, nothing behind a sub-tab.** React's main branch has separate Money / Time / Expenses / Burn up tabs; its develop branch folds the first three into one Charts tab, and a record screen hides nothing behind a disclosure (`docs/detail-screen-layout.md`). Each section is an `AnalyticsSection` card; a section with nothing to say is left out of the column, never drawn empty.

## Who gets the tab, and how much of it

**No tab before server 5.13.27; `view_dashboard` on 5.13.27; anyone who can view the project from 5.13.28** (`ProjectDetailTabs.analyticsOffered`, `ServerFeatures.projectAnalytics` / `projectAnalyticsForEveryone`). The endpoints arrived in `0f649ea6dc` gated on `view_dashboard`; `401fc79bb6` commented that gate out and added `metadata.can_view_financials`. Never for a `tmp_` project — the routes take the server id.

- **A user who may not see the money gets `forecast_completion` alone**, every other block `[]`, and the burn-up without its money series. The tab shows the Forecast and the burn-up in hours, and leaves Money, Time and Expenses out. "Include drafts" is money too and is hidden, as in React.
- **For that user both are built from their own time** (`ProjectAnalyticsService::tasks` and `ProjectBurnUpService::applyTaskLogs` narrow to `user_id`), while the hours still to go are the whole project's. The Forecast says "Based on the time you logged" and leaves out days ahead/behind: one person's pace against the project's whole remaining budget shows a slip that is not there.
- **Missing metadata reads as "may see the money".** A 5.13.27 server sends none, and only answers a `view_dashboard` user at all.

## The server's zeros are not all zeros

**Every figure goes through a check of what it is divided by** (`analytics_figures.dart`). The service answers every block for every project:

- `ratio()` returns 0 for a zero denominator — margin with nothing invoiced, unbilled share with no work value, budget used with no money budget. These render as a dash.
- Remaining hours are `max(budgeted − logged, 0)`, and the forecast finish is *today* once nothing remains. So a project with no hours budget "finishes today", and one 150% over budget "finishes today, N days ahead". `forecastVerdict` turns those into "Set budgeted hours…" and "Over budget by N h".
- Health is docked at most 25 for a budget overrun, so a project 50% over its money budget still scores a green 87.5. The score is shown as **Good / Fair / Poor**, never "On track": the standing card above the tabs says On track / Over budget about the hours, and the two would contradict each other.
- One row comes back per block even for a new project, so "no rows" never happens. Emptiness is decided from the content (`analyticsHasActivity`). Before, a new project showed a page of zeros and a green 100.
- Velocity is the average over days *with* logs, and its series carries only those days. The chart zero-fills the gaps (`velocityBuckets`), and cumulative spend holds its last total across them (`spendBuckets`), weekly past 60 days.

## The analytics endpoint reads no dates

**Only the burn-up has a window, so its range control sits in the burn-up section.** `ProjectAnalyticsService` never reads `start_date` / `end_date`, so every figure in Forecast, Money, Time and Expenses is lifetime. The old tab-wide range control changed only the chart, and its "All time" sent today minus 20 years, which the burn-up dutifully bucketed. By default the burn-up request now sends no dates, and the server spans created → the later of today and the due date (`ShowProjectBurnUpRequest::prepareForValidation`). The bucket follows the span (`BurnupBucket.forSpan`: daily to 90 days, weekly to two years, then monthly) until the user picks one.

## The tab keeps itself current, and keeps what it had

**A completed Sync pass, a pushed change, a change leaving the outbox, or the project row changing all trigger a refetch** — the dashboard's three signals plus `didUpdateWidget`. A tab stays mounted once opened, so without these the figures stayed as they were at first open while time was logged in the Tasks tab beside them.

**A failed refetch keeps the last good figures** with a banner above them. The failure keeps its type (`ProjectAnalyticsFailure`): offline says "need a connection" with Retry, a 404 says the server does not have it, a refusal has no Retry. Before, every failure — offline included — read "Analytics aren't available from this server yet".

## Charts

Velocity and cumulative spend go through `ReportSeriesPlot`. Rankings (team, tasks, categories, health shares) and the money comparisons use `BarList` (`lib/ui/core/charts/bar_list.dart`, moved from reports): real labels, the figure at the end of each bar, top 8 plus "Other". The burn-up shows one measure at a time, hours or money, never two scales on one plot. Its colours follow the line, not its position, so switching one off repaints nothing else; its callbacks are State tear-offs. Pinned by `test/ui/features/projects/project_analytics_*_test.dart`, `analytics_figures_test.dart`, and the analytics sweep in `test/ui/responsive_regression_test.dart` (320–1200 px, 1.0× and 1.4× text).
