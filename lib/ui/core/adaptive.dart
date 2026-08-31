import 'package:flutter/widgets.dart';

import 'package:admin/app/env.dart';

/// App-wide responsive breakpoints. Use [Breakpoints.isWide] inside a
/// [LayoutBuilder] so layout decisions reflect the parent's allocated width,
/// not the device or window size.
class Breakpoints {
  Breakpoints._();

  /// At or above this width we show two-pane layouts and the persistent
  /// `InSidebar`. Below it we collapse to single-pane, and each top-level
  /// screen supplies its own `AppDrawer` + hamburger — there is no bottom
  /// navigation bar (this doc used to claim one; it never shipped).
  static const double wide = 600;

  static bool isWide(BoxConstraints constraints) =>
      constraints.maxWidth >= wide;

  /// Minimum width for the `/settings` master-detail two-pane layout. The
  /// settings shell carries a fixed 280 px `SettingsListSidebar`, so the
  /// generic [wide] (600) threshold leaves the right pane cramped on tablets
  /// (a 700 px window would give the content barely ~420 px). Below this we
  /// fall through to single-pane full-screen navigation, which has its own
  /// section list + push nav. 280 sidebar + ~600 content ≈ 880.
  ///
  /// Two sites split the same shell width against this value and MUST stay in
  /// agreement: `SettingsShell`'s `LayoutBuilder` gate (shows the sidebar) and
  /// `settingsIndexRedirect` in `router.dart` (sends `/settings` straight to
  /// Company Details). If they diverge, the in-between band redirects the user
  /// past the list while the sidebar is still hidden — leaving no menu.
  static const double settingsTwoPane = 880;

  /// True when the global persistent `InSidebar` is visible (i.e. the
  /// window is ≥ [wide]). Use this — not [isWide] — to decide whether a
  /// per-screen Scaffold should attach its own `AppDrawer` +
  /// `DrawerHamburger`. The local `LayoutBuilder` constraints can fall
  /// below [wide] even when the global sidebar is visible (e.g. medium
  /// window widths after the InSidebar + SettingsListSidebar take their
  /// share), which would otherwise produce a redundant hamburger menu
  /// that opens a duplicate of the global nav.
  static bool isGlobalNavVisible(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wide;

  /// True on a **phone** — a touch-primary platform (iOS / Android, native or
  /// mobile browser) whose window is narrower than [wide] on its *short* edge.
  /// Orientation-independent by construction: a handset reports the same
  /// `shortestSide` held either way. A tablet reports under 600 only when the
  /// OS hands the app a small multi-window slice (Android split-screen, iPad
  /// Slide Over) — which wants the phone layout anyway, so the rule is right
  /// there too.
  ///
  /// The only gate here that reads the device rather than the box it was handed,
  /// and the app's second platform-gated rule after `InSizes.touchTarget`. Width
  /// is normally the right question and has no answer for a phone in landscape:
  /// the window is then ~890 px, so the persistent rail comes up and its 232
  /// still leaves the content pane ~660 — which reads as "desktop" on a viewport
  /// only ~412 px tall, and a wide layout spends that width on full-label chrome
  /// the handset can't carry (flutter#51).
  ///
  /// [Env.isTouchPrimary], not `isMobile`, for the same reason touch sizing uses
  /// it: a phone browser is still a phone, and `defaultTargetPlatform` is
  /// derived from the browser's OS there. Without it a short desktop window
  /// (890x412) would match on `shortestSide` alone.
  ///
  /// Wire this in **per screen, deliberately**. It is not applied app-wide;
  /// [isWide] stays the default gate and the callers are a small, deliberate
  /// set — `DashboardScreen` and `showCommandPalette`, which uses it to pick
  /// its whole presentation (a full-screen page on a phone, the floating
  /// Spotlight card everywhere else) along with its keyboard-only hints: both
  /// are questions about the device, not the window.
  static bool isPhone(BuildContext context) =>
      Env.isTouchPrimary && MediaQuery.sizeOf(context).shortestSide < wide;

  /// At or above this **window** width the entity routes render as a
  /// slide-over panel: the list stays at full width and the detail /
  /// edit / create floats on top, pinned to the right edge with a
  /// drop shadow. Below this threshold the routes render full-screen
  /// exactly as they do today (no slide-over).
  ///
  /// Picked at 1024 so the **full-width** list keeps wide-mode column
  /// rendering (`Breakpoints.isWide = 600` on the list itself, not on
  /// a post-sidebar slice) at common laptop widths (1280, 1366, 1440).
  /// Below 1024, the slide-over would crowd the list — full-page nav
  /// is the better experience there.
  static const double slideOver = 1024;

  /// True when the current window is wide enough to host the slide-over
  /// pane (see [slideOver]).
  static bool isSlideOver(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= slideOver;

  /// Two-column ⇄ single-column threshold for entity edit / detail card
  /// layouts (client / product / expense / vendor / …). At or above this
  /// width the body splits into a main column + 360 px sidebar (or a 2–3
  /// column detail grid); below it the body collapses to a single column
  /// centered and capped at [kEntityFormMaxWidth] so fields don't stretch
  /// edge-to-edge.
  ///
  /// Picked at 1000 — not 1100 — so a **full-width** pane on a ~1280 px
  /// window (content ≈ 1048 px after the 232 px nav rail) shows two
  /// columns rather than one stretched column. The slide-over pane
  /// (440–560 px) always falls below this, so it stays single-column.
  ///
  /// Task edit/detail deliberately keep their own 1100 threshold: the
  /// time-log table needs ~792 px in the main column, which 1000 would
  /// starve.
  ///
  /// Trade-off: just above this width the main column (≈ width − 360 px
  /// sidebar − padding) is still under the 600 px `ClientEditFieldPair`
  /// threshold, so paired fields stack for a narrow (~36 px) window band
  /// before going side-by-side — accepted in favor of two columns sooner.
  static const double entityFormMultiColumn = 1000;

  /// Width thresholds for the Reports screen's three-tier responsive
  /// rendering. The Reports table carries more chrome (sticky header,
  /// per-column filter row, drill-down breadcrumb) than a typical entity
  /// list, so it needs its own breakpoints — and below 600 px it switches
  /// to a card-list layout entirely.
  static const double reportTableMedium = 600;
  static const double reportTableWide = 1024;

  /// Reports body tier for the current viewport, given the body's
  /// available width [maxWidth] (typically `constraints.maxWidth` inside
  /// a [LayoutBuilder]).
  ///
  /// - `wide` (≥1024): full table with every column.
  /// - `medium` (600–1024): pinned-first-column table with horizontal
  ///   scroll for the rest.
  /// - `narrow` (<600): switch to a [ReportCardRow] list; filter row is
  ///   only reachable through the toolbar overflow.
  static ReportLayoutTier reportTier(double maxWidth) {
    if (maxWidth >= reportTableWide) return ReportLayoutTier.wide;
    if (maxWidth >= reportTableMedium) return ReportLayoutTier.medium;
    return ReportLayoutTier.narrow;
  }
}

enum ReportLayoutTier { narrow, medium, wide }
