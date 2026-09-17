# Pull-to-refresh

Companion to CLAUDE.md § Design system (v2) (the pull-to-refresh rule). Why a `RefreshIndicator` can sit on a list and still never start, and what keeps every refreshable list in the app pullable at any length.

## A controlled scroll view under a `RefreshIndicator` must ask for `AlwaysScrollableScrollPhysics`

**The symptom.** invoiceninja/flutter#163, on the Android beta: pull-to-refresh "works everywhere else" but did nothing on Quotes. Nothing about the Quotes screen was different — it is a plain `EntityListScreenScaffold` config, and its rows are the same `SelectableListRow` Invoices uses. The reporter simply had fewer quotes than fill a phone screen (a row is at least `kEntityListRowHeight` = 72 px, so about eight of them), and at that length **every** standalone entity list refused the pull. A long list hides the bug completely, which is why it read as a Quotes problem.

**The mechanism** (Flutter 3.44, `packages/flutter/lib/src/`):

- `RefreshIndicator` only starts on a drag. `_shouldStart` wants a `ScrollStartNotification` (or, in `anywhere` trigger mode, a `ScrollUpdateNotification`) with non-null `dragDetails`, at the leading edge (`material/refresh_indicator.dart`).
- A `Scrollable` only installs its drag recognizers when `physics.shouldAcceptUserOffset(position)` is true — `ScrollPositionWithSingleContext.applyNewDimensions` feeds it to `setCanDrag`. The base answer is `pixels != 0 || minScrollExtent != maxScrollExtent` (`widgets/scroll_physics.dart`): **no**, for content that fits. `AlwaysScrollableScrollPhysics` overrides it to `true`.
- `ScrollView` picks that physics for you only when `primary` is true or, with `primary` unset, when the view is vertical **and has no controller** (the `physics =` initializer in `widgets/scroll_view.dart`). Hand it a controller and it falls back to the platform physics — clamping on Android, bouncing on iOS — and neither accepts a drag on content that fits.

`EntityListScreenScaffold` gives its standalone `ListView.builder` the `_vScroll` controller (the load-more trigger) and left `physics` null. That one argument was the whole bug.

**What was already safe.** Every other refreshable surface passes no controller, so `ScrollView` already made it always-scrollable: the scaffold's own empty-state `ListView`, the activity feed (`activity_screen.dart` relies on this in a comment) and both dashboard bodies. Giving any of them a controller — for scroll-to-top, say — would bring the bug back there, which is what the lint below is for.

**The fix** is `physics: const AlwaysScrollableScrollPhysics()` on the standalone branch; embedded lists keep `NeverScrollableScrollPhysics`, since they grow with the detail page and have no pull-to-refresh of their own. Keep it **bare**. `ScrollableState._updatePosition` applies the widget's physics *over* the platform's (`physicsFromWidget.applyTo(platformPhysics)`), so Android still clamps and stretches and iOS still bounces; a hard-coded `ClampingScrollPhysics(parent: …)` would take the bounce away from iOS. It covers the wide table too, because `_wideTable` hosts the same list. Two side effects, both accepted: a short list now rubber-bands on iOS and macOS, as every controller-less list already did; and since `refresh()` re-arms paging (`hasMore = true`), the next scroll of a short list on iOS — a bounce moves `pixels`, a clamp does not — can fire one `loadMore()` that finds nothing, the same re-arm a long list pays at its bottom edge.

**What pins it.**

- `test/ui/core/list/entity_list_pull_to_refresh_test.dart` mounts the real scaffold against a real `Services` graph (`buildFixture`) on a 400×800 window, with a fake view model supplying the rows. A two-row list is flung down on Android and on iOS and must reach `refreshAll` — it did not before the fix. An empty list and a 30-row list are the controls; the long one proves the harness can drive a refresh at all, so a red short-list case is about the physics.
- `test/lint/refresh_indicator_physics_test.dart` scans every `lib/` file that builds a `RefreshIndicator` and fails on a vertical `ListView` / `GridView` / `CustomScrollView` / `SingleChildScrollView` that takes a `controller:` without naming `AlwaysScrollableScrollPhysics` in its own `physics:`. Opt out with `// lint: allow-controlled-refresh-scroll <reason>`. The scan is per file, so a scroll view built elsewhere and passed in as the indicator's child is invisible to it.
