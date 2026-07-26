# Integration tests

`integration_test/app_smoke_test.dart` boots the real `InvoiceNinjaApp` with in-memory Drift + `InMemoryTokenStorage` and a `MockClient`. Scenarios cover: boot to `/login` with no creds, boot to `/lock` when biometric is enabled, lock-screen sign-out, post-auth redirect to `/dashboard` vs `/clients` (driven by `view_dashboard` permission), and a full login → refresh round-trip. Guards the DI graph, router, theme, and localization wiring.

**Don't run integration tests locally unless the user explicitly asks** — they take over the foreground app and interrupt the developer's session. Never run them proactively or as incidental verification. When the user explicitly asks, run them in an isolated worktree (see **Running locally on request** below).

**On CI** (`.github/workflows/ci.yaml`, manual `workflow_dispatch`) only the `integration-web` job runs — `app_smoke_test.dart` on **Chrome** (`-d web-server --browser-name=chrome`), to guard the web build. It is **blocking**: it carried `continue-on-error: true` while the headless-Chrome path was unproven, but it has since caught real regressions (the shortcut-hint notify-during-build crash, the Inter Tight font-overflow `RenderFlex`), so the flag was removed. Don't re-add it to quiet a red run — a failure there is a genuine web regression. The **macOS-desktop** suite is **not** run on CI: a headless hosted `macos-26` runner has no Metal device (`MTLCreateSystemDefaultDevice()` returns nil), so the desktop app can't create its renderer and dies at launch ("The log reader stopped unexpectedly") before the VM-service line. Re-enabling it there was tried (Metal-toolchain install + Impeller→Skia fallback) and removed as insufficient — so the full per-file desktop suite (incl. the live `demo/*` CRUD files) runs **locally/manually** via `tools/run_integration_local.sh --include-demo`, never on CI. The live `demo/*` suite and any filesystem/secure-storage/`pruneBrokenDbFiles` unit tests are `@TestOn('vm')` / macOS-only — they don't run under the web job either.

**Multi-file desktop runs need the per-file workaround.** `flutter test integration_test/ -d macos` (the bare glob) only ever works for the *first* file that launches the app on desktop — [flutter/flutter#135673](https://github.com/flutter/flutter/issues/135673): the tool reuses a debug-connection stream that breaks on the second app launch, so every later file dies with `Error waiting for a debug connection: The log reader stopped unexpectedly, or never started.` → `Unable to start the app on the device.` Both CI and local runs therefore use `tools/run_integration_local.sh` — one `flutter test` invocation per file (the upstream workaround), with per-file timeouts and straggler-process cleanup; mocked suite only by default, `--include-demo` adds the live `demo/*` files (which self-skip via `skipIfUnreachable` in `integration_test/support/demo_harness.dart` when `demo.invoiceninja.com` is unreachable, and otherwise create/edit/delete `ZZ-CLAUDE-IT`-marked rows cleaned up in teardown).

**Running locally on request.** Only when the user explicitly asks. The run is long (tens of minutes with `--include-demo`) and the repo is live-edited during sessions, so run against an isolated git worktree on a throwaway branch — concurrent edits to the main checkout then can't perturb the code under test — and tear the worktree + branch down afterward, even on failure. Note the macOS run still grabs the foreground app window; the worktree isolates the *code*, not the screen, so it's still strictly on-request.

```bash
ts=$(date +%Y%m%d-%H%M%S)
root=$(git rev-parse --show-toplevel)
wt="$root/../in-itest-$ts"          # sibling of the main checkout, not nested in it
br="itest/$ts"
# Non-destructive WIP snapshot: `git stash create` does NOT touch the working
# tree or the stash list (this is NOT `git stash` — see the "never git stash to
# experiment" rule). Empty when the tree is clean → falls back to HEAD.
snap=$(git -C "$root" stash create)
git -C "$root" worktree add -b "$br" "$wt" "${snap:-HEAD}"
# `git stash create` omits untracked-but-not-ignored files — copy them in too:
git -C "$root" ls-files --others --exclude-standard -z \
  | rsync -a --from0 --files-from=- "$root/" "$wt/"
# Guarantee teardown even on failure / interrupt:
trap 'git -C "$root" worktree remove --force "$wt"; git -C "$root" branch -D "$br"' EXIT
( cd "$wt" && flutter pub get && bash tools/run_integration_local.sh --include-demo )
```

Run it as a script (so the `trap` fires) or, if invoking step-by-step, always finish with `git worktree remove --force "$wt" && git branch -D "$br"` even when the run fails. `git worktree list` afterward must not show a leftover `in-itest-*`. This worktree-on-a-temp-branch flow is the **sole exception** to the "never create/switch branches in this checkout" strict rule — it branches inside an isolated sibling worktree, never the main checkout.

Stable widget keys (`login_submit`, `lock_unlock`, `lock_sign_out`) keep assertions locale-independent. Add similar keys when extending the test.

When adding scenarios, mock both `/api/v1/login` and `/api/v1/refresh` if the flow authenticates — `_persistAndActivate` calls refresh after a successful login, and `restore()` fires a best-effort refresh too. The shared `_silentNetwork()` helper returns a 500-MockClient for scenarios that don't care about the wire.
