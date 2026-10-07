# Startup responsiveness

Companion to CLAUDE.md § Strict rules. The rule there says launch-time work is measured; this doc
carries what a cold start does, the numbers behind each change, and what was looked at and left
alone.

The report (October 2026, macOS): for a few seconds after the app starts, taps and clicks lag;
then it is fine. Build mode unknown.

## A cold start is measured, not guessed

**Time launch-time work with `traceSync` / `traceAsync` (`lib/utils/perf_trace.dart`) before
deciding it is slow, and again after changing it.**

The first pass at this report was three code-reading investigations and no measurement. They
agreed on a ranking, and the first two numbers taken afterwards rearranged it:

- A synthetic full snapshot of 14,000 fully-populated browsable rows parsed in **36 ms** once the
  parsers were warm (`login_response_full_snapshot_test`, which prints it). Reading the code, that
  parse had looked like the dominant cost.
- The real demo snapshot (2.88 MB, 376 browsable rows, one company) took **423 ms** on the
  *first* parse in a process and **2-8 ms** on every later one. The cost of the first one is the
  Dart VM compiling fourteen large generated `fromJson` graphs, not the rows.

So in a debug build the price of first use is compilation, and it is paid wherever the code first
runs; in a release build the same parse costs the warm figure and scales with row count. A
"slow, then fine" report from a debug run is largely that. Check a profile build
(`flutter run --profile -d macos`) before attributing a launch lag to app work.

**The spans.** Each is a `dart:developer` timeline span (DevTools → Performance, on a profile
build) and a FINE line on the `perf` logger (the debug console; spans under 1 ms are left out of
the log). A release build runs the body directly.

| Span | Where | What it covers |
|---|---|---|
| `http <METHOD> <path>` | `ApiClient._send` | the network round trip |
| `http.bodyDecode` | `ApiClient._send` | bytes → `String`, on the UI isolate |
| `json.decode` | `ApiClient._decodeBody` | `on: ui` at ≤ 256 KB, `on: isolate` above |
| `refresh.typedParse` | `AuthRepository._refreshSession` | `LoginResponseApi` from the decoded map |
| `refresh.persist` | `AuthRepository._refreshSession` | `_persistAndActivate`, waits included |
| `page.parse` | `BaseEntityApi.list` | one list page into DTOs |
| `page.map` / `page.write` | `ensurePageLoadedTemplate` | DTOs → companions; the upsert |
| `statics.decode` | `StaticsRepository` | the stored blob → typed views |
| `prefetch.sweep` | `_runSidebarPrefetch` | the whole 14-entity sweep |
| `dashboard.refresh` | `DashboardRepository._runJobs` | one dashboard refresh pass |

`main.dart`'s debug boot stopwatch (`main.boot`) gained a `first frame` mark, which times the gap
between the last awaited stage and the first paint.

## What runs at launch

Awaited before `runApp`, in order: the diagnostics log (debug only), the database open (store
lock, keychain key, isolate spawn, one `PRAGMA table_info` round trip per table), `Services.build`,
then `auth.restore()` alongside the device preferences, the statics warm-up, and the saved route.
`runApp` follows, and Flutter holds the first frame until the localization delegate resolves.

`restore()` also starts work nobody awaits, so it is already in flight when the first frame
paints:

- **The full `/refresh`** — `current_company=false&updated_at=0&first_load=true`, every company's
  whole dataset unless the server marks the company `is_large`. Decoded off the UI isolate, parsed
  and persisted on it.
- **The sidebar prefetch sweep** — page 1 of 14 entities, four at a time.
- A formatter and a settings cascade for the active company, and the tags.

The landing screen adds its own: the dashboard issues about ten requests through a separate
four-wide limiter. Each response of 256 KB or less is decoded on the UI isolate.

## A full snapshot is parsed without its browsable entity arrays

**A full snapshot — `/login`, an OAuth or token sign-in, a signup, a `/refresh` with
`updated_at=0` — goes through `LoginResponseApi.fromFullSnapshot`, which drops the fourteen
browsable arrays before parsing; a new delta field must join `kBrowsableDeltaJsonKeys`.**

invoiceninja/flutter#170 typed those arrays on `CompanyEnvelopeApi` so a *delta* refresh could top
the lists up. A full sync was deliberately excluded from applying them — every applier is wrapped
in `_deltaOnly` (`docs/sync.md` § The refresh delta tops up the browsable tables, invariant 4) —
but the envelope was still parsed whole. Every cold start therefore built a typed object for
every client, invoice, payment, … in the account, on the UI isolate, and discarded them all.

Measured on the demo snapshot above: first parse in a process **423 ms → 52 ms**, later parses
**2-8 ms → under 1 ms**. The warm figure is what a release build pays, about 13 µs a row, so it is
small for a small account and grows with the data.

Three things hold it in place:

- **One list of keys.** `kBrowsableDeltaJsonKeys` sits beside the delta parsers.
  `login_response_full_snapshot_test` classifies every list-valued field on the envelope as a
  browsable delta or a reference bundle, so a fifteenth delta field fails the build until it is
  placed; `refresh_delta_coverage_test` holds the list to the applier count.
- **The envelope is copied, not edited.** `withoutBrowsableEntityArrays` rebuilds the maps it
  changes, so a caller's map — or an unmodifiable one in a test — is untouched.
- **`fromJson` is unchanged**, and a delta `/refresh` still uses it. `auth_repository_test` pins
  both sides: the bundle hook sees zero invoices on a full refresh and all of them on a delta.

## A response body is decoded once

**`ApiClient._send` reads `response.body` into a local.** `http.Response.body` is an uncached
getter (`http` 1.6.0: `_encodingForHeaders(headers).decode(bodyBytes)`), and `_send` evaluated it
twice per request: once as an argument to the debug capture store, which is always constructed
and drops the body while capture is off, and once for the return value.

## Statics are decoded once

**`StaticsRepository.ensureLoaded` returns after reading one integer once the blob is in memory;
the row's `fetched_at` is what tells it to decode again.**

It used to read the stored payload, `jsonDecode` it and rebuild all ten typed views on every
call, and a cold start calls it several times over: `main()`, `AppLocaleResolver` on each session
change, each company's formatter.

The fast path compares the stored stamp (`StaticsDao.fetchedAt`) with the stamp the in-memory
blob was loaded under. That choice, rather than trusting memory alone, is what keeps one case
working: after a destructive sign-out and a new sign-in in the same process, the login envelope
carries no statics, and `ensureLoaded` finding no row is what refetches them. `AppDatabase.wipe`
deletes the row, so the stamp reads null and no wipe hook has to remember to tell the repository.
Unforced calls also share one in-flight load. `statics_repository_test` › ensureLoaded.

## The localization bundles start loading before the database opens

**`main()` calls `Localization.prewarm()` right after logging is up, and the delegate starts all
three of its loads before awaiting any.**

Flutter builds nothing under `Localizations` until an asynchronous delegate resolves. The
delegate loaded English (304 KB), then the pending bundle (75 KB), then the locale's own, one
after another — each a file read and an isolate hop — and only began once `runApp` had built the
tree. `prewarm` is never awaited and cannot throw (both loaders already swallow their own
failure), so it cannot keep boot from reaching `runApp`. `localization_prewarm_test`.

## Looked at and left alone

- **Holding the prefetch sweep until after the first frame.** It moves work rather than removing
  it: part of the sweep currently runs behind the splash, and a delay would push all of it into
  the window where the user is clicking. Decide between a gate and lower concurrency from the
  `prefetch.sweep` and `page.*` spans.
- **Value equality on `AuthSession` / `ApiCredentials`.** Each `/refresh` notifies every session
  listener. `ApiCredentials` documents why it has no `==` (every assignment must reach the
  router), and `AppLocaleResolver` uses the per-refresh notify to pick up a language change.
- **A delta instead of a full snapshot at cold start.** It would remove a multi-megabyte download
  per launch, but `isFullSync` currently means both "the company set is authoritative" and "the
  entities are a snapshot" inside `_persistAndActivate`; splitting those is its own change.
- **Deduplicating identical page-1 fetches**, and one transaction for a page's upsert and its
  cursor write. Mostly database-isolate time.
- **WAL journal mode and new indexes.** A persistent change to the store and a schema migration,
  for time that is not spent on the UI isolate.
- **Impeller on macOS.** macOS renders with Skia (no `FLTEnableImpeller`), so first-use shader
  compilation is a plausible share of a launch lag. `--enable-impeller` is the diagnostic.

**Read in the code, not reproduced:** a cold-start full sync stamps `lastSyncAt` for every
company while applying no entity rows, and a list's own delta fetch returns one page of 50. If
more than 50 rows of one entity changed while the app was closed, the rest arrive only when the
user scrolls to them or runs Sync. The cold-start delta above would close that.
