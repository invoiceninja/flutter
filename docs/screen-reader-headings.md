# Screen-reader headings

Companion to CLAUDE.md § Design system (v2), which carries the one-line rule. This doc carries the
mechanism and the evidence.

## A screen-reader heading sets both header and headingLevel

Every `Semantics(header: true, …)` in `lib/` also passes `headingLevel:`. Use `1` for a dialog or
sheet title and `2` for a section heading inside a screen. `test/lint/semantics_heading_level_test.dart`
fails the build on a `header: true` with no level.

**Why both.** Flutter 3.47 split the two properties by platform, and neither works everywhere on its own:

| Platform | Reads | Source (3.47.7) |
|---|---|---|
| iOS | `headingLevel` only (`> 0` → `UIAccessibilityTraitHeader`, plus `accessibilityHeadingLevel`) | `SemanticsObject.mm` |
| Android | `headingLevel` only (`> 0` → `View.setHeading(true)`) | `AccessibilityBridge.java` |
| macOS, Windows, Linux | `header` (`is_header` → `ax::mojom::Role::kHeader`); `heading_level` is passed along, not used for the role | `engine/src/flutter/shell/platform/common/accessibility_bridge.cc`, `SetRoleFromFlutterUpdate` |
| Web | `header` for the role, `headingLevel` 1–6 for `<h1>`–`<h6>` | `packages/flutter/lib/src/semantics/semantics.dart` (`isHeader && kIsWeb`) |

The change is [Semantics `header` vs `headingLevel`](https://docs.flutter.dev/release/breaking-changes/semantics-header-heading-level).
It landed in 3.45.0-0.1.pre and shipped in stable 3.47, which says `header` "behaves as a no-op on iOS and
Android". The guide's own example *replaces* `header: true` with `headingLevel: 1`. On a desktop build
that would remove the heading role, so this app keeps both.

**How it fails.** Silently. `header: true` still compiles, isn't deprecated, and no widget test asserts
`isHeader`. On 3.47 the nine headings we had (the What's New and mobile-promo dialog titles, the dashboard
create sheet, list section headers, the needs-attention band, the report gallery and report document
headings, and the project analytics headings) stopped being headings for VoiceOver and TalkBack. Rotor
and heading navigation skipped them, and nothing told us.

**What the lint reads.** Top-level arguments of `Semantics(` and `SemanticsProperties(` calls, with
comments stripped. A nested call's `headingLevel:` doesn't count for the outer one, because it belongs to
a different node. A `header: true` passed to anything else is not a semantics call and isn't flagged:
`report_document_view.dart`'s `cell()` takes one as a style flag.
