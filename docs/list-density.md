# List density

Companion to CLAUDE.md § Design system (v2). This doc covers the Normal / Compact list
density: what Compact changes, why it is built the way it is, and what it deliberately
leaves alone. The guard is `test/lint/list_row_density_wiring_test.dart`. No CLAUDE.md
bullet is needed, because the lint test enforces the rule; the touch-target Quick Index
row points here.

## Why it exists

A beta tester reported that a full-screen desktop window showed about 12 invoices, where
the old app showed 20 or more.

- **The cause was the row floor.** `kEntityListRowHeight` puts a 72 px floor under every
  row, but a wide row's content needs only 52 px with a pointer: 10 px padding, the 32 px
  action buttons, and 10 px padding.
- **The old app's rows were smaller.** Its `DataTable` rows were 48 px
  (`kMinInteractiveDimension`).
- **The chrome above the rows adds up.** It takes about 222 px on web or macOS: header
  band 69, status tabs ~46, card inset 24 + 1, column headers 57, then 1 + 24 below.
- **The result:** (1100 − 222) / 72 ≈ 12 rows.

Normal stays the default and is unchanged, because the tester liked the look. Compact is
opt-in.

| Window height (pointer) | Normal | Compact |
|---|---|---|
| 1100 px | 12 rows | about 23 rows |
| 950 px | 10 rows | about 19 rows |

On a phone, the two-line tile goes from 72 px to about 57 px per row.

## Where the setting lives

- **The preference.** It is `DevicePrefKeys.listDensity` (`list_density`), with values
  `normal` and `compact`. Its scope is `PrefScope.device`, like text size: it is how the
  app looks on this screen, so a sign-out keeps it and a desktop can be Compact while the
  phone stays Normal.
- **The controller.** `ListDensityController` (`lib/app/list_density_controller.dart`)
  owns the preference.
  - Read it through `isCompact`. A stored value this build doesn't know, such as one
    written by a newer build, then still resolves to Normal.
  - The settings control's selection is derived from `isCompact`, so it is never empty.
- **The scope.** `ListDensityScope` (`lib/ui/core/list/list_density_scope.dart`) is an
  `InheritedNotifier`. It is mounted once, in `main.dart`'s `MaterialApp.builder`, around
  the router's child inside `WindowFrame`, so it sits above the router's Navigator.
  - Every route, dialog, sheet and master-detail pane is therefore under it. The toast
    host, hint bar and call-log prompter beside it are not, and none of them reads it.
  - It wraps only that one child so its `main.dart` diff is a few lines, not a re-indent
    of the whole builder.
  - A flip rebuilds only the widgets that read it, never `MaterialApp`.
  - With no scope above (most widget tests), every reader gets Normal. That is why the
    lint test pins that `main.dart` mounts it: nothing else would notice it was missing.
- **The one control.** Device Settings → Theme → List density, a `SegmentedSettingRow`
  under Font Size, the other "how much fits on screen" control. It is searchable and
  works at every width.
  - There is deliberately no toggle in the list toolbar. One shipped briefly beside the
    Columns button and was removed: a setting changed once per device does not earn a
    permanent slot in every list's header, and the slot cost the search field width it
    could not spare (the Tasks toolbar's view switcher left no room below a ~1036 px
    pane).

## What Compact changes

| Surface | Normal | Compact |
|---|---|---|
| Entity-list row floor (`EntityListRowFloor`) | 72 | 40 pointer / 52 touch |
| Entity-list tile padding (`listRowPadding`), vertical | 10; 14 embedded; Client and Vendor 14 | 4 |
| Detail record rows (`listRowVerticalPadding`): activity, document history, pending comment, sends, email history — vertical padding | 14 | 4 |
| The same detail rows' floor (`entityListRowHeight`) | 72 | 40 pointer / 52 touch |
| Column-header strip, vertical | 12 | 6 |
| Status-tab strip (`dense:`), vertical | `InSpacing.md` | `InSpacing.sm` |
| Group section header, top / bottom | `lg` / `sm` | `sm` / `xs` |
| Standalone table card inset (`entityListCardInset`) | 24 all round | 24 horizontal, 12 vertical |

The detail record rows also tighten in the overview's Comments card, which hosts the same
row widgets. That is intended: the card shows the same records.

## Why it is built this way

**`ThemeData.visualDensity` is not the lever.** No list row is a `ListTile` or a
`DataTable`, and the row action buttons pin their own `fixedSize` with `shrinkWrap`
(`entity_actions_popup_button.dart`), because their width feeds `colWMoreMenu()`. Changing
the theme density would move nothing in a row.

**The Compact floor is derived, not chosen.** `entityListRowHeight` returns
`max(40, actionButtonSize() + 2 × 4)`.
- **Pointer: 40.** Compact keeps the floor's original job, so a row does not reflow when
  its leading slot swaps between avatar and checkbox: the tallest thing a row always holds
  is a 32 px button, and 32 + 8 = 40.
- **Touch: 52.** The 44 px touch target wins (CLAUDE.md § Design system — touch targets
  are gated on the platform). The floor says so, so that the scaffold's scroll-to-row
  estimate is not 12 px short per row on a tablet.

**The card inset loses only vertical space.** Its horizontal 24 lines the table up with:
- the header band's row (`entity_list_app_bar.dart`, "aligns … with the table card below")
- the status-tab strip's start (`_statusTabsFor`, `start: wide ? 24`)
- the frameless desktop title bar's nav arrows

The header band is out of scope, so cutting the card's horizontal inset would break that
alignment.

**The status tabs take a `dense` parameter instead of reading the scope.** The dashboard's
Invoices & Quotes panel uses the same widget in its `wrap: true` form, and the dashboard is
out of scope. A parameter set only by the list scaffold keeps it that way, and keeps the
widget presentational.

**Floors, never heights.** Every change is padding or a `minHeight`. A larger text scale,
or a two-line tile, still grows the row instead of clipping it (CLAUDE.md § Design system,
rule 1).

## Out of scope

- **The header band (search row).** Its height is shared with the sidebar's company row
  across the seam (`InSizes.headerBand`).
- **The embedded list toolbar.** It keeps its 16 / 16 gap.
- **The dashboard.** That includes its `DashboardRecordRow` lists and the wrapped status
  strip.
- **Forms, the sidebar, and reports.**
- **The settings-hosted lists** (tax rates, payment terms, groups, users, …). They are
  `ListTile`s in a `FormSection` (`SettingsEntityListScaffold`), with no 72 px floor to
  remove.

## The guard

`test/lint/list_row_density_wiring_test.dart` fails the build if:
- a `*_list_tile.dart` hard-codes its vertical padding (`fromSTEB(16, 10|14, …)`) instead
  of calling `listRowPadding`
- code anywhere in `lib/` outside `entity_list_constants.dart` reads `kEntityListRowHeight`
  (comments excepted) — as a `minHeight:`, a `SizedBox(height:)`, an `itemExtent:` or
  anything else — instead of `entityListRowHeight(context)` / `EntityListRowFloor`
- `lib/main.dart` stops mounting `ListDensityScope` (a commented-out mount counts as
  missing)
- any `EntityListStatusTabs(` call other than the list scaffold's passes `dense:`, which
  is what keeps the dashboard strip out of scope

`test/ui/core/list/list_density_test.dart` measures the actual rows: 72 under Normal, 40
with a pointer and 52 on touch under Compact. It also checks that a dense strip is 8 px
shorter, and that the card inset keeps its horizontal 24. The column-header,
section-header and activity-row tests each carry a Compact case of their own.
