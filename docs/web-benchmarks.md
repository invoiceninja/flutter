# Web benchmarks — WASM against JS

Companion to CLAUDE.md § Web. That section says the app ships to the web as a `--wasm` build; this
doc carries the harness that measures what that buys over the dart2js build, the rules that keep
its numbers honest, and the last recorded results.

## Running it

```
tools/web_bench/build.sh                                # two release builds, ~5 min
dart tools/web_bench/main.dart record                   # until it reports 0 upstream calls
dart tools/web_bench/main.dart run --phase startup --rounds 10
dart tools/web_bench/main.dart run --phase frames  --rounds 5
dart tools/web_bench/main.dart run --phase compute --rounds 5
dart tools/web_bench/main.dart report                   # build/bench/summary.md
```

`run` appends to `build/bench/results.jsonl` and resumes, so it can be called repeatedly; `--budget`
(seconds, default 450) stops it starting a sample it cannot finish. `--config iso` and
`--config iso-st` repeat a phase cross-origin isolated (below). `probe` does one cold load per
variant and prints what loaded — run it first on a new machine.

Nothing is installed: the harness is plain `dart:io` and drives the Chrome already on the machine
over the DevTools protocol. No chromedriver, no package, no npm.

Two things it needs from you: **no other `flutter` command while a build runs**, and **an idle
machine while it measures** — every sample records the load average, the report prints the range,
and `--max-load <n>` makes `run` wait for the machine to quieten before each sample.

## What is compared

One commit, one entrypoint (`benchmark/web_bench_main.dart`), one set of flags; the only difference
is `--wasm`.

| Variant | Compiler | Renderer | Release default |
|---|---|---|---|
| `js` | dart2js | CanvasKit | `-O4` |
| `wasm` | dart2wasm | skwasm | `-O2` |

The entrypoint installs a bridge on `globalThis.__inBench` and then calls the unmodified `main()`,
so the boot path, the Drift WASM store and every screen are the production ones. It must not touch
the Flutter binding itself: `main()` creates it inside `runZonedGuarded`, and a binding created by
the wrapper would live in the root zone.

A `--wasm` build also emits the dart2js fallback, and that `main.dart.js` is byte-identical to the
one a plain build produces (checked: same size, 22,712,738 bytes) — so the `js` variant is exactly
what a browser without WasmGC is served today.

## What is measured

| Phase | What | How |
|---|---|---|
| Size | What a first visit downloads | The harness server's own log of a cold load, gzip as sent |
| Startup | Navigation → first frame → dashboard loaded | `flutter-first-frame`, and the app's own `main.boot` marks, both stamped on the page clock |
| Frames | Build and raster time per frame | The engine's `FrameTiming`, through `addTimingsCallback` |
| Compute | Real app code, no widgets | `Stopwatch` around `computeTotals`, `ReportEngine.compute`, `LoginResponseApi.fromJson`, `jsonDecode`, `markdownFromLegacyHtml` |
| Memory | V8 heap after the session | `Runtime.getHeapUsage` after a forced GC |

The frames session: a cold load, a 15-screen navigation tour run twice (first visit, then steady
state — the shell is an indexed stack, so the second pass really is different work), wheel-scrolling
the dashboard, Expenses (78 rows, so the scroll fetches page 2) and Products, opening a client
record and the invoice editor, and dragging the window from 1440 px to 520 px and back.

## The rules that keep a number honest

### The network is recorded, not measured

A demo API call takes 0.35 s and sometimes 1.4 s, and a cold boot blocks its first frame on one. So
the builds are pointed at the harness's own origin (`IN_DEMO_API_URL=http://127.0.0.1:8791`), which
answers `/api/v1/*` from a recording: `record` forwards a request it has no answer for to
`demo.invoiceninja.com` once and stores it; `run` never goes upstream, and a request with no
recording is a **miss that discards the sample**. Same origin means no CORS preflight either.

- The replay key is method + path + sorted query + a hash of the body. One request is keyed on the
  wall clock — the delta `/refresh`, by last-sync time — and has that parameter dropped.
- **A recording is valid for one local calendar day.** The dashboard's "previous period" body is
  derived from today's date; `run` refuses a recording made on another day.
- **Run `record` until it reports zero upstream calls.** A list's second page-1 request carries a
  cursor only once the first has landed, so some requests exist only when responses are instant —
  which the first, slow, pass never sees.
- Chrome is launched with every host but `127.0.0.1` unresolvable, so nothing third-party (the
  company logo, a fallback font, pdf.js) can add noise.
- The demo account is shared: the builds set `IN_DEMO_MODE=true`, and the recorder refuses any
  non-GET outside a short list of read-only POSTs.

### A sample that loaded the wrong thing is thrown away

`flutter.js` silently falls back from dart2wasm + skwasm to dart2js + CanvasKit when WasmGC or
WebGL is missing, and a headless browser can silently render on a software GPU. Either would produce
plausible numbers for the wrong experiment. Every sample is discarded unless: the bridge reports
the expected compiler in release mode; exactly one of `window.flutterCanvasKit` /
`window._flutter_skwasmInstance` exists and it is the right one; the server log shows only that
variant's binary; WebGL's unmasked renderer is hardware; `crossOriginIsolated` matches the config;
the page navigated exactly once; the boot marks are all present and in order (a warm start has no
`demo token bootstrap`); the URL is where the step put it; and every screen went idle.

### Each cold start is a new browser profile

A cold sample launches Chrome on a new `--user-data-dir`, so no HTTP cache, compiled-code cache,
session or database carries over. A warm sample is the same profile revisited — and never a reload
in place: the harness leaves for `about:blank`, waits for the app's shared worker to die, then
navigates. Reloading over a live worker is what the app reports as "open in another tab".

### Variants are interleaved

`run` alternates which variant goes first each round, so a machine that warms up or gets busy
part-way through costs both the same. Figures are a median across samples of a per-sample
statistic, with the range beside it.

### Raster is not like-for-like

Build time is the Dart framework and is the compiler comparison. Raster time is the renderer, and
CanvasKit and skwasm divide their work differently, so the comparable frame figure is build +
raster. There is no stock way to run skwasm under dart2js, so the two cannot be separated further.

### Headless Chrome is fine here, and the harness checks

On macOS, `--headless=new` renders through ANGLE on Metal (the environment line of every report
shows the renderer string) and ticks at 60 Hz. It also never loses focus or gets occluded, which a
visible window can — and a focus change makes the app fire a refresh.

## The three hosting configs

skwasm only rasterises on a worker thread when the page is cross-origin isolated (COOP
`same-origin` + COEP `credentialless`). GitHub Pages cannot send those headers, so the live demo
runs skwasm single-threaded; `plain` measures that. `iso` sends them — to **both** variants, because
isolation also moves drift from IndexedDB to OPFS, and that would otherwise be credited to WASM.
`iso-st` keeps the headers but sets the loader's `forceSingleThreadedSkwasm`, which separates the
threading gain from the storage change.

There is deliberately no CPU-throttled pass: `Emulation.setCPUThrottlingRate` slows the page's main
thread only, which would flatter whichever config rasterises elsewhere.

## Traps the harness already handles

Each of these produced a wrong or unusable number before it was handled.

- **dart2js integers are JS doubles.** A generator that overflows 2^53 hands the two compilers
  different inputs — the first compute run compared 29 report groups against 60. The entrypoint's
  generator stays below 2^53, and every workload returns its result so the report can assert both
  compilers computed the same thing.
- **`jsonDecode` under dart2js is lazy.** It returns maps converted on first read, so re-reading a
  map that was already walked flatters it. The parse workload decodes afresh every iteration.
- **A focused text field never goes idle on macOS.** Its caret fades through an animation, so an
  edit screen draws at 60 fps forever. The invoice editor gets a fixed 2-second window instead of
  "wait until quiet".
- **The app draws one small frame about 500 ms after every navigation.** A quiet period shorter
  than that includes it for a slow build and misses it for a fast one. Navigations wait 700 ms, and
  "until drawn" is the end of the first run of frames, not the last frame seen.
- **A list's scroll extent is not known up front.** The app shows a window of rows and widens it —
  and fetches the next page — only as the scroll nears the edge. The scroll goes down until the
  extent stops growing.
- **Chrome runs a service worker of its own** (a built-in extension's) for about 25 seconds. Only
  workers on the app's origin are waited for before a warm reload.
- **`print` is silent in a dart2wasm release build.** The boot marks reach the console through
  `web.console.log` (`lib/app/boot_log_web.dart`); the harness wraps `console.log` in the page, so
  each mark is stamped on the same clock as the frame timings.
- **Another job on the machine wrecks the tails.** A video encode started mid-run took the load
  average from 6 to 68 and a cold start from 0.5 s to 9.8 s. `--max-load <n>` holds each sample
  until the 1-minute load average is below `n`.

## Results — 8 October 2026

Commit `7e608cf1`, Flutter 3.44.1 / Dart 3.12.1, Chrome 154 headless (ANGLE on Metal), Apple M2 Pro,
1440×900 at 2×. Plain hosting, as the live demo is served. Medians; lower is better. The machine was
shared with other work throughout (load average 3–32 on 12 cores), so read the ratios rather than
the absolute times, and re-run on an idle machine before quoting a tail figure.

| | JS | WASM | WASM vs JS |
|---|---|---|---|
| Cold start → first frame (23 loads each) | 933 ms | 542 ms | 1.72× faster |
| — until Dart `main` (download, compile, engine start) | 574 ms | 203 ms | 2.83× faster |
| — `main` → first frame | 361 ms | 342 ms | 1.06× faster |
| Cold start → dashboard loaded and drawn | 1,639 ms | 1,156 ms | 1.42× faster |
| Return visit → first frame (1st / 2nd / 3rd) | 486 / 332 / 388 ms | 247 / 281 / 255 ms | 1.2–2.0× faster |
| Open a screen for the first time, until drawn | 146 ms | 89 ms | 1.65× faster |
| Open a screen again, until drawn | 61 ms | 43 ms | 1.43× faster |
| Navigation, average frame (build + raster) | 16.4 ms | 7.8 ms | 2.11× faster |
| Navigation, p99 frame | 55.0 ms | 27.5 ms | 2.00× faster |
| Navigation, frames over 16.7 ms | 34% | 18% | |
| Scroll Expenses, average frame | 2.7 ms | 1.9 ms | 1.45× faster |
| — build only | 2.0 ms | 1.1 ms | 1.92× faster |
| — raster only | 0.7 ms | 0.8 ms | 1.19× slower |
| Resize the window, average frame | 164 ms | 70 ms | 2.34× faster |
| Invoice totals, one 50-line invoice | 33.5 ms | 10.6 ms | 3.17× faster |
| Report engine, 5,000 rows | 14.3 ms | 8.0 ms | 1.79× faster |
| `jsonDecode` + `fromJson`, 3 MB login response | 5.2 ms | 10.2 ms | 1.97× slower |
| `jsonDecode` alone | 2.4 ms | 9.1 ms | 3.77× slower |
| HTML → Markdown, 40 KB (regex) | 0.4 ms | 1.4 ms | 3.22× slower |
| V8 heap after the session | 211 MB | 144 MB | 1.47× smaller |
| App code, raw | 22.71 MB | 13.51 MB | −41% |
| App code, gzip | 4.17 MB | 4.49 MB | +8% |
| Whole first load, gzip | 7.52 MB | 7.18 MB | −5% |

What the numbers say:

- **The compiler shows in build time, not raster.** Build is 2–2.4× faster everywhere; raster is
  level, and single-threaded skwasm is 12–24% *slower* than CanvasKit on a plain scroll.
- **The biggest single win is before `main` runs** — 370 ms of the 390 ms cold-start gap is
  download, compile and engine start.
- **Scrolling was never the problem.** Both variants scroll at 2–3 ms a frame; the gain there is CPU
  headroom, not smoothness. Navigation and resize are where frames go over budget.
- **WASM loses where dart2js leans on V8's native code**: JSON and regular expressions. Both are a
  few milliseconds here, against hundreds gained at startup.
- **Size is close to a wash once compressed**, and nothing in the app is deferred-loaded yet.
- **Cross-origin isolation costs about 400 ms of cold start here**, for both compilers (first frame
  1,432 ms JS / 961 ms WASM over 5 loads each): the headers move drift from IndexedDB to OPFS, whose
  first open is slower. Worth knowing before adding COOP/COEP for the raster worker.
- **Not measured: frame times with the raster worker.** The `iso` and `iso-st` frame sessions ran
  while another job saturated the machine (the OPFS open alone took 3–8 s) and were set aside, so
  whether multi-threaded skwasm closes the raster gap is still open. `run --phase frames --config
  iso` and `--config iso-st` on an idle machine answer it; the report then adds a single-thread
  against worker table.

## Files

- `benchmark/web_bench_main.dart` — the entrypoint and the bridge (frame timings, a hit-test scroll
  probe, the compute workloads).
- `tools/web_bench/build.sh` — the two builds. `BENCH_SRC` points it at a clean export when the
  working tree has edits in flight.
- `tools/web_bench/main.dart` — the CLI and the scripted session.
- `tools/web_bench/server.dart` — static files (gzip, `max-age=600`, as GitHub Pages serves them)
  and the record/replay API.
- `tools/web_bench/cdp.dart` — Chrome launch and the DevTools protocol client.
- `tools/web_bench/report.dart` — `results.jsonl` → `summary.md` + `summary.json`.
