# Performance tracking

Companion to CLAUDE.md § Strict rules. The rule there says a path users wait on gets a benchmark
and a budget; this doc carries how the suite measures, how a number is judged, where the history
lives, how an alert reaches someone, and the first recorded numbers. `docs/web-benchmarks.md` is
the other harness — release builds in a real browser, run by hand — and the two share their
inputs (`benchmark/workloads.dart`).

## What runs, and where

| Piece | Where |
|---|---|
| The benchmarks | `benchmark/perf/*_perf_test.dart` — plain `flutter test` files |
| The harness | `benchmark/perf/_perf.dart` — `benchmark`, `widgetBenchmark`, `perfCalibration` |
| Budgets and tolerances | `benchmark/perf/budgets.json` |
| Runner and judge | `tools/perf/main.dart` (`run` / `compare` / `budgets`), rules in `tools/perf/perf_compare.dart` |
| The rules' tests | `test/tools/perf_compare_test.dart` — part of the normal unit suite |
| CI | `.github/workflows/perf.yaml` — only by hand: Actions → Performance → Run workflow |

Locally:

```
dart tools/perf/main.dart run                       # ~80 s on an M2 Pro: two passes of the suite
dart tools/perf/main.dart compare                   # budgets only, without a history
dart tools/perf/main.dart compare --history h.json  # h.json = a `perf-history` artifact from CI
dart tools/perf/main.dart run --name invoice_edit   # only the ids matching a regex; compare expects only those
```

Results land in `build/perf/`: `run.json`, `summary.md` (also printed), `alerts.json`. Never run
`flutter test benchmark/perf` bare to get numbers: the runner forces `--concurrency=1`, and two
files timing at once on the same cores measure each other. Bare is fine for checking that one file
still passes.

## What is measured

Four files, by layer. Every id is `<area>.<what>`; the title is what a person reads in an alert.

| Area | Ids | What it stands for |
|---|---|---|
| Screens | `screens.invoice_list_open` / `_scroll` / `_resize` | The invoice list over 600 rows: mounting it until rows draw, one frame of a 240 px scroll, one frame of an 80 px window resize |
| | `screens.invoice_list_scroll_phone`, `screens.invoice_edit_items_tab_phone` | The same list at 390 × 844 (touch, narrow rows), and the phone editor's Items tab opening on a 50-line invoice — its lines are cards, built when the tab opens |
| | `screens.invoice_edit_open` / `_typing` | The invoice editor on a 50-line invoice: mounting it, and one keystroke in a line cell through the 250 ms debounce and the totals recompute |
| | `screens.client_record_open` | The client record screen until its standing card draws |
| Database | `invoices.list_first_page` / `_deep_scroll` / `_search` / `_status_tab` | The invoice list's Drift query over 5,000 rows, its rows already decoded (see the note below): page 1, ten loaded pages, a search, the Overdue tab. Fixture dates are all in the past, so "overdue" is the same rows every run |
| | `invoices.list_first_page_cold` | Page 1 with nothing decoded yet — the query plus fifty payload decodes (`jsonDecode` → `fromJson` → `fromApi`), what a first look at a page costs |
| | `invoices.page_write` | Storing a page of 50 from the server — DTO to companion to dirty-preserving upsert |
| | `invoices.save_edit` | An offline save: the row and its outbox entry, in one transaction |
| | `invoices.badge_counts`, `clients.list_first_page` / `_search` | The sidebar counts; the client list over 2,000 rows |
| | `expenses.` / `payments.` / `products.` / `transactions.list_first_page` | Each list's first page of 5,000, on the sort the app opens it with (see § Every list's default sort, measured) |
| | `sync.refresh_delta_apply` | Storing a `/refresh` delta of 200 changed invoices, upsert-only |
| | `sync.outbox_drain` | Back online with 25 offline edits: the real sync engine sends them to a server that answers each, and applies the replies. Each batch is checked landed — no edit dead, no invoice left dirty — before the next |
| Compute | `billing.invoice_totals` | `computeTotals` for one 50-line invoice |
| | `reports.group_and_sort` | `ReportEngine.compute` over 5,000 rows |
| | `rich_text.legacy_html_to_markdown`, `rich_text.notes_plain_text` | 40 KB of legacy notes HTML, both directions |
| | `startup.snapshot_load` | `jsonDecode` + `fromFullSnapshot` of a 3.4 MB cold-start `/refresh`. Nearly all SDK `jsonDecode`, which the calibration scales away — what it guards is that the full snapshot keeps dropping its 4,200 browsable rows before typing |
| | `sync.refresh_delta_parse`, `sync.invoice_page_parse` | Typing a delta `/refresh` (50 rows × 14 entities), and one list page |
| Startup | `startup.restore_session` | What `main()` awaits after the database opens: `Services.build`, restoring the session, preferences and recently viewed, warming the statics from their stored row, reading the saved route. The open itself is left out — an in-memory store is nothing like the encrypted file a device opens |

**What a widget-test number is.** `flutter test` runs a debug build — JIT, asserts on — and a test
binding never rasterises. So a screen figure is the Dart work of a frame (build, layout, paint
recording), several times what a release build pays. That is the part an app change moves, and the
part a regression check needs; "is it smooth on a phone" is a profile-build question this suite
does not answer. The database figures are real SQLite and the compute figures are real Dart; both
are also debug-mode numbers.

**Semantics is off in the screen benchmarks** (`widgetBenchmark` passes `semanticsEnabled:
false`). An app builds its semantics tree only when an assistive technology asks for it, so
`flutter_test`'s default — on — timed work most sessions never do. It also tripped a framework
assertion on the invoice editor about one run in five (`!childSemantics.renderObject._needsLayout`,
in the semantics pass, after every sample had been measured). Worth a look on its own: a screen
reader on that screen may meet it too. The screen figures in § First numbers and § Fixed since the
first numbers were taken with semantics on, so today's are lower — a keystroke on a 50-line
invoice reads ~39 ms rather than ~58.

**The list reads time a re-read.** Every sample after the first finds its rows already decoded
(`BaseEntityRepository.decodeRow`), which is what each change to a mounted list costs; a page seen
for the first time also pays its decode, about 0.1 ms a row in debug.

## How a number is judged

### Every time is put on the reference machine's scale

**A run's times are multiplied by `reference.calibrationMs / this run's calibration` before
anything compares them.** GitHub's `ubuntu-latest` is not one machine: hosts differ by a third or
more in single-thread speed, so raw milliseconds from two runs cannot be compared, and a budget
in raw milliseconds would trip whenever a slower host came up.

`perfCalibration()` times a fixed workload — building, JSON-encoding, decoding and sorting 4,000
small maps, the shape of most of this app's work — at the start and at the end of every file; the
run's calibration is the median of those fastest-of-nine times, across files and passes. Both
ends, because a machine that slows down half-way through a file looks steady to a sample taken only
before it; on a steady M2 Pro the two ends agree within 5%. The workload is
plain `dart:core` + `dart:convert`, so no app change can move it — only the machine, the SDK, or a
busy neighbour can.

- **Never change `calibrationWorkload`.** It is the unit. A different workload rescales the whole
  history.
- The history keeps raw medians plus each run's calibration, never scaled values, so the reference
  can be changed later without rewriting anything.
- The scaling assumes a slower machine is uniformly slower. It is not exactly — SQLite, layout and
  JSON do not scale identically between an M2 and an EPYC — which is one reason budgets carry
  3× headroom until CI's own runs replace them. The run-to-run checks are unaffected: they compare
  like with like on one runner type.
- **Each pass is scaled by its own calibration** before the faster one is kept, so a pass slowed
  throughout competes on its own scale rather than the run's average.
- **A run whose calibration samples spread more than 30% is `noisy`.** Something shared the machine
  part-way through. A noisy run checks budgets only; the alerts it cannot re-judge stay open, and
  it is left out of later baselines.

### Too slow: the budget

**`budgetMs` in `budgets.json` is a ceiling in reference milliseconds; over it is an
`over_budget` alert, from the very first run — and it fails every run until fixed (§ What fails
the run).** The first budgets are this Mac's medians × 3, rounded up to two significant figures:
generous, because a budget set on one machine and scaled to another by the calibration is only as
good as the scaling, and an `over_budget` that is really a scaling error would turn every run
red. After a week of CI runs, re-derive them from CI's own history:

```
dart tools/perf/main.dart budgets --history perf-history/history.json --headroom 2.5 > b.json
```

and commit the result after reading the diff. `budgets` keeps every other field, and prints its
warnings on stderr, so the redirect captures only the file.

### Slower: the recent baseline

**A run more than `regression` (25%; 30% for screens) above the median of the last ten clean main
runs that were not themselves alerting is a `regression` alert — unless the rise is inside the
baseline's own noise or under `minDeltaMs`.** The threshold is `max(regression, 3 × MAD / median)`
of those ten runs: a benchmark that wanders ±15% from run to run must not page anyone at +20%.
`minDeltaMs` (0.1 ms) keeps a microsecond benchmark from alerting on a doubling that is still
noise. Fewer than three earlier runs: no regression check, only the budget.

**While a regression is open the baseline does not move.** The runs that alerted are left out of
it. Were they counted, five slow runs would put the median half-way up and widen the noise
threshold with it, and the alert would clear itself — "No performance alerts remain" — with nothing
fixed. So an open regression stays open until the benchmark comes back down, or until somebody
accepts the slowdown:

```json
"screens.invoice_edit_open": { "budgetMs": 1600, "regression": 0.3, "since": "2026-11-02" }
```

**`since` is the acceptance: runs before it are not compared with, by any check.** Set it to the
day you accept; the benchmark is then checked against its budget only, until three runs have built
the new baseline, and from then on that baseline is guarded like the old one. `budgets` honours it
too. Raise `budgetMs` in the same commit if the new normal is over it.

**`defaults.since` accepts every benchmark at once** — the step after a Flutter bump or a runner
change, which moves every number together and would otherwise leave each benchmark's regression
open until it had its own `since`. A benchmark's own `since` wins when it is later.

Each pass's median is kept and the run takes the **lowest** — a pass slowed by a neighbour loses
to the one that was not. Two passes in separate processes, because a transient slowdown usually
hits one.

### Slower over time: drift

**The median of the last five runs more than `drift` (40%) above the median of the runs 30–90
days old (leaving out any that were alerting) is a `drift` alert.** It is not asked while a
regression of the same benchmark is open — that would be one slowdown listed twice. A run-to-run check cannot see a slowdown made of small steps: +2%
a run across a month of runs never trips +25% against the ten runs before it, and the baseline climbs with
it. `test/tools/perf_compare_test.dart` › drift pins exactly that case. Past 90 days nothing is
compared; the budget is the backstop.

### Did not run: an alert, not a silence

**Every id in `budgets.json` is expected on every run; one missing is a `failed` alert.** A
benchmark that throws — a renamed widget, a seed that no longer loads — otherwise just disappears
from the table, and the coverage erodes without anybody deciding it should. A failed benchmark's
earlier alerts stay open: unknown is not resolved. A run limited with `--name` expects only the
ids its regex matches, and leaves the alerts of the rest as they were.

## Where the history lives

**The history is the `perf-history` artifact, carried from each main run to the next.** A run
downloads the newest unexpired one uploaded by a main run, appends itself (main only, `--record`),
and uploads the result. No branch, no external service, nothing to provision.

- **It only grows when someone runs it.** The workflow has no schedule, so the baseline (ten
  runs), the drift check (runs 30–90 days old) and the history itself all depend on running it on
  main regularly — after merging something that could matter, and before a release. Artifacts
  expire after 90 days: ninety days with no main run loses the history, and the suite falls back
  to budgets until three runs build a baseline again.
- Runs on main never overlap (`concurrency`): two at once would both read the same history and
  the second upload would drop the first's entry. GitHub keeps one pending run per group, so a third
  arrival cancels the waiting one, which loses nothing: the run that goes measures the newer
  commit.
- A branch run reads main's history and records nothing.
- **A history that exists but cannot be listed, downloaded or read fails the run on main.**
  Carrying on would record a one-entry history and upload it as the newest, and every later run
  would chain from it. Only "there is no history yet" falls back to budgets. Every step runs under
  `bash -eo pipefail` for the same reason — without `pipefail` a failed artifact listing read as an
  empty one. `compare --record` refuses an unreadable file; a branch run, which records nothing,
  warns and judges by budgets. A schema bump therefore needs a reader for the old schema — or the
  `perf-history` artifacts deleted, on purpose.
- **A commit already in the history is judged against what preceded its first measurement.** The
  last commit measured again (a re-run, or a second dispatch at the same commit)
  replaces its own entry and announces nothing it already announced. An older commit measured
  again — a late re-run of an old job — is judged but not recorded, and leaves the issue alone.
- **The history is uploaded after the issue step, and only if it succeeded.** It records which
  alerts are open; uploaded first, a failed issue step would leave a new alert recorded as open and
  never announced.
- The history keeps the newest 500 runs (`kPerfHistoryCap`).

## How an alert reaches someone

- **On main, alerts live in one open issue titled "Performance regressions", labelled
  `perf-regression`.** The first alert opens it; each later run rewrites its body to the current
  alerts; an alert that was not up on the previous run adds a comment — except a `drift` taking
  over from an open `regression` of the same benchmark (a partial fix can bring it inside the
  regression threshold while it is still well over a month ago), which is the same news; the run
  that clears the last alert closes it with a comment. One thread, so a regression that persists
  across several runs is one notification, not several.
- **A new alert's comment tags `@hillelcoren`.** The repository variable `PERF_NOTIFY` (Settings →
  Secrets and variables → Actions → Variables) replaces that when set — e.g. `@octocat @hubot`.
  An @mention notifies whatever the person's watch settings are.
- **The run goes red** by the rule in § What fails the run, so the Actions page and GitHub's
  failed-run email to whoever started it say so too. Run Performance on a branch to ask "is this
  branch slower than main?"
  before merging, and read the job summary — rebased first: the branch is judged against main's
  recent runs, so a branch that predates a speed-up on main reads as having lost it.
- Every run writes the full table, with a trend sparkline per benchmark, to the job summary, and
  uploads `run.json` / `summary.md` as `perf-run-<run id>-<attempt>`.

## What fails the run

**A run fails for every new alert, and — new or not — for every benchmark over its budget or
that failed to run.** `PerfComparison.failingKeys` is the rule, `compare --fail-on gate` applies
it, and the workflow's Verdict step turns each failing key into an error on the run page.

- **New** means not open after the previous main run. On a branch that is "an alert main does not
  already have", so a branch is not blamed for main's own open slowdowns.
- **Over budget and failed stay red on every run.** A budget is the line nobody crosses quietly,
  and a benchmark that stopped running is a hole in the suite; both stay red until fixed, or the
  budget is raised in a reviewed commit (§ Too slow: the budget).
- **A regression or drift is red the run it appears in**, then lives in the issue — a slowdown that
  stays does not turn every run red. It stays open in the issue until fixed or accepted with
  `since` (§ Slower: the recent baseline). A `drift` taking over from an open `regression` of the
  same benchmark is not new; a `regression` appearing while a `drift` is open is — a step on top
  of the creep.
- **A stale run** (a late re-run of an older commit) fails nothing.

**Proven end to end, 15 October 2026:** a 30 ms busy-wait added to `computeTotals` and 3 ms to
`ReportEngine.compute`, the real benchmarks run, compared against a history of genuine runs.
`billing.invoice_totals` came out over budget and +169%, `reports.group_and_sort` +53%; `compare
--fail-on gate` exited 1, and the workflow's Verdict step, run verbatim, printed an error per key
and exited 1. `test/tools/perf_compare_test.dart` › what fails the run pins the rule.

## Adding a benchmark

**A path users wait on gets a benchmark in `benchmark/perf/` and a budget in `budgets.json`; a
benchmark id is never renamed — its history and budget are filed under it.**

- Pick the file by layer (screens / data / compute / startup). A new file must call `perfCalibration()` first
  thing in `main`, and end in `_perf_test.dart`.
- **A benchmark that measures nothing must fail.** Assert the seed in `setUp` — row counts, a
  parsed field — the way `data_perf_test` checks its 5,000 invoices landed and
  `compute_perf_test` checks the delta really holds 50 invoices of 8 lines. An empty table queries
  in microseconds and passes forever.
- **A Drift read benchmark opens its database with `closeStreamsSynchronously: true` and runs each
  read through `_query`.** Drift keeps a cancelled query stream alive until the event loop turns,
  and a re-listen before then replays its last result without running SQL. A loop of
  `watchPage(...).first` turns only on microtasks, so with the default every sample after the
  first timed the row mapping alone. That shipped in this suite's first version and read 5 ms for
  a 25 ms query; `_query` counts the SELECTs that reach SQLite and throws if a sample ran none.
- `benchmark(run:)` times its whole body; use `batch` when one operation is under a millisecond,
  and `reset` when each run leaves something to tear down (a `Services` graph) outside the timing.
  `widgetBenchmark(run:)` times only what goes through `PerfTimer.time` — keep `runAsync` waits
  for Drift outside it.
- Keep the timed part off the network and away from timers that fire mid-sample. The scroll
  benchmark stays short of the list's 600 px load-more threshold for that reason: crossing it
  starts a page fetch whose failure re-renders the list and leaves a toast timer behind.
- Inputs come from `benchmark/workloads.dart` and are seeded, so every run measures the same work.
- Then run `dart tools/perf/main.dart run --name <id>` and `budgets`, and add the new entry.

## Changing a benchmark

A change to what a benchmark *does* — more rows, a different screen size — is a step in its
history that will read as a regression or an improvement. Either give it a new id (the old one's
history simply stops; drop its budget) or keep the id and say so in the commit, expecting one
alert. The same goes for `workloads.dart`, which the web harness shares.

A Flutter bump moves every number a little, and the calibration does not absorb it — the SDK is
part of what is measured. The alerts it opens stay open, because the baseline leaves alerting runs
out: set `defaults.since` to the bump's date in the same commit (§ Slower: the recent baseline),
and re-derive the budgets once three runs exist.

The runner image is pinned (`runs-on: ubuntu-24.04` in `perf.yaml`), not `ubuntu-latest`: a new
image changes the kernel, libc and the toolchain that builds sqlite3mc all at once, and the
calibration corrects for CPU speed only. Bumping it is a runner change: same commit, same
`defaults.since`.

## Not measured yet

Paths users wait on that no benchmark covers, roughly by how much they are waited on:

- **The dashboard.** Its figures come from server endpoints, so a benchmark needs a fake server
  answering every panel's request; over the offline fixture it would time empty and error states.
- **The rest of a cold start:** the encrypted database open, and the first frame of the shell on a
  populated store. `startup.restore_session` covers what `main()` awaits in between.
- **Typing in a notes field** (`MarkdownTextField`, super_editor). The editor takes text through
  its own IME client, so a benchmark needs `flutter_test_robots`' typing (a transitive
  dependency today, not a direct one) or a test hook into the editor.
- **The Tasks kanban and calendar views**, and a full-sync page sweep (the delta apply and the
  outbox drain are measured).
- **Anything a release build or the GPU decides** — raster, shader compilation, web.
  `docs/web-benchmarks.md` measures those by hand.

## Every list's default sort, measured

**A list whose default order no index serves sorts the whole table to show fifty rows — and that
is cheap or not depending on how wide the rows are.** After the invoice list's 20 ms turned out to
be exactly that, every list's real page-1 statement was planned. Eight more sort every row:
clients and vendors (`name`), products (`LOWER(product_key)`), projects (`LOWER(name)`), payments,
expenses and bank transactions (`date`), recurring expenses (`next_send_date`). Timed at 5,000
rows, the four high-volume ones open in 1.4–2.5 ms: their rows are small, where an invoice carries
its line items. So no index was added for them — a schema change for two milliseconds — and the
`*.list_first_page` benchmarks are what will say if that changes.

## First numbers — 15 October 2026

The working tree on top of `86a460f4`, Flutter 3.44.1, Apple M2 Pro (the reference machine;
calibration 9.4 ms when the budgets were first set, 9.5–10.2 ms across the sixteen samples of the
run below), two passes. Debug-mode `flutter test` figures for screens and compute; the database
figures are a native SQLite query, which the debug build does not slow, plus the row decoding
around it, which it does.

| Benchmark | Median | |
|---|--:|---|
| `screens.invoice_edit_open` | 659 ms | Opening a 50-line invoice |
| `screens.invoice_list_open` | 176 ms | |
| `screens.invoice_edit_typing` | 149 ms | One keystroke on a 50-line invoice |
| `invoices.list_deep_scroll` | 88.9 ms | Every change re-reads all loaded pages |
| `screens.client_record_open` | 52.4 ms | |
| `screens.invoice_list_resize` | 45.0 ms | |
| `invoices.list_search` | 41.9 ms | |
| `startup.snapshot_load` | 32.1 ms | |
| `screens.invoice_list_scroll` | 26.4 ms | |
| `invoices.list_first_page` | 25.3 ms | See below |
| `billing.invoice_totals` | 18.5 ms | Per 50-line invoice |
| `invoices.list_status_tab` | 17.1 ms | |
| `startup.restore_session` | 6.87 ms | |
| `reports.group_and_sort` | 5.85 ms | |
| `invoices.badge_counts` | 5.42 ms | Five counts |
| `invoices.page_write` | 5.34 ms | |
| `rich_text.notes_plain_text` | 3.63 ms | |
| `rich_text.legacy_html_to_markdown` | 2.50 ms | |
| `clients.list_first_page` / `_search` | 2.43 / 2.29 ms | |
| `sync.refresh_delta_parse` | 1.39 ms | 700 rows |
| `invoices.save_edit` | 1.12 ms | |
| `sync.invoice_page_parse` | 0.249 ms | |

The two passes agreed within 10% for every benchmark.

**What these said, and what was done about it** — see § Fixed since the first numbers.

## Fixed since the first numbers

Three hotspots the first run showed, fixed the same week. Same machine, same suite; the
figures before are the table above.

| Benchmark | Before | After | What changed |
|---|--:|--:|---|
| `screens.invoice_edit_typing` | 149 ms | 60 ms | Unchanged table rows are reused |
| `invoices.list_first_page` | 25.3 ms | 1.7 ms | Sort index, and rows decoded once |
| `invoices.list_deep_scroll` | 88.9 ms | 15.0 ms | Rows decoded once, and the sort index |
| `invoices.list_search` | 41.9 ms | 12.9 ms | Sort index |
| `invoices.list_status_tab` | 17.1 ms | 1.8 ms | Sort index, and rows decoded once |

- **The invoice editor rebuilt every line-item row on every committed edit.** The edit view
  model notifies on each change, and the desktop table built a new `_Row` for all fifty lines to
  change one. A row now hands back the widget it was built as while its inputs (`_RowInputs`:
  its props, plus the values its callbacks capture) compare equal, and Flutter skips the subtree.
  That needed value equality on `LineItemColumnConfig` and its parts, rebuilt every frame by
  `forCompany`. `line_item_table_row_reuse_test` counts row builds. What is left of a keystroke
  (~50 ms here) is the totals recompute (~18 ms) and the rest of the editor's frame — headers,
  notes, the totals card, layout and paint — spread a few milliseconds each.
- **Every list re-decoded its whole window on every change.** `BaseEntityRepository.decodeRow`
  keeps each record's last decoded entity with the row it came from — one entry per record, so an
  edit replaces its old version; least-recently-used, 1,000 records; dropped on logout with the
  peek seeds and when the OS reports memory pressure (`Services.releaseMemory`, through
  `MemoryPressureObserver`). Drift's row classes compare every column, so a changed row is
  decoded fresh. Correct only while each row decoder is a pure function of its row:
  `test/lint/row_decoder_purity_test.dart` holds every `_decode` to that. A window past the cap,
  re-read in order, misses on every row — it then costs what decoding did before, plus a lookup.
  `decoded_row_cache_test`, `services_release_memory_test`.
- **The billing documents' default sort had no index.** Schema v13 adds
  `idx_<table>_company_number` on `(company_id, LOWER(number))` for invoices, quotes, credits,
  purchase orders and recurring invoices (`createListSortIndexes`). The v13 dump is identical to
  v12 — drift does not model these indexes — so `migration_test` checks instead that an upgraded
  v12 database has them and that each list's real page-1 statement plans onto its index.

**Still open:** `billing.invoice_totals` (18 ms a 50-line invoice, exact decimal arithmetic —
already computed once per edit; a rewrite needs the totals oracle), `screens.invoice_edit_open`
(~700 ms, building 212 text fields up front), and `invoices.list_search` (a `LIKE` over the
payload, now 13 ms).
