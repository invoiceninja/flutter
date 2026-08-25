/// Shared column-width constants for entity list data tables.
///
/// The screen-level column header strip ([EntityListColumnHeaders]) and the
/// per-entity row tiles (`ClientListTile`, `ProductListTile`, …) read these
/// so headers and rows stay column-aligned. Don't drift them apart.
library;

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/domain/columns/column_definition.dart';

/// Reserved width for the trailing pill (status badge) slot on the
/// header. Row tiles that don't render a pill should still reserve this
/// width so the header columns line up with the row cells.
const double kColWPillSlot = 96;

/// Rendered side length of one row-action icon button in the wide table's
/// leading slot: [InSizes.touchTarget] on a touch device, 32 with a pointer.
/// Same split `NavHistoryButtons._HistoryButton` uses.
///
/// [EntityActionsPopupButton] pins its buttons to this with
/// `IconButton.styleFrom(fixedSize:)` + `tapTargetSize: shrinkWrap` rather
/// than letting Flutter size them, so [colWMoreMenu] can be *derived* from the
/// same number instead of predicting framework internals. Left implicit, an
/// `IconButton`'s layout box is floored at `kMinInteractiveDimension` + the
/// visual-density adjustment whenever `ThemeData.materialTapTargetSize` is
/// `padded` (its default on Android/iOS) — 48 − 8 = 40 under
/// `VisualDensity.compact` — which is both wider than the slot allowed for and
/// *under* the app's own 44 px touch floor. See invoiceninja/flutter#89.
double actionButtonSize() => Env.isTouchPrimary ? InSizes.touchTarget : 32;

/// Gap between the circled edit pencil and the `…` overflow menu. Material
/// wants >= 8 dp between adjacent touch targets, and these two do very
/// different things (navigate away vs. open a menu), so a boundary mis-tap is
/// costly — this is the knob to turn if the cluster ever reads too tight,
/// never [actionButtonSize].
const double kColActionsClusterGap = InSpacing.sm;

/// Width of the leading row-actions slot. In the wide data table this holds
/// the circled edit pencil + [kColActionsClusterGap] + the `…` overflow menu.
/// The column-header strip, every wide row tile and [computeTableMinWidth]
/// all read this, and they must stay in lockstep or the table misaligns.
///
/// * touch:   44 + 8 + 44 = **96**, exactly the cluster.
/// * pointer: 32 + 8 + 32 = 72, held at **80** — 8 px of deliberate slack, so
///   fixing the mobile overflow doesn't shift every desktop table's columns.
///
/// A function, not a `const` or a top-level `final`: a `final` would freeze
/// the first-read platform for the whole test process and make any
/// `debugDefaultTargetPlatformOverride` test order-dependent.
double colWMoreMenu() =>
    Env.isTouchPrimary ? actionButtonSize() * 2 + kColActionsClusterGap : 80;

/// Width of the avatar / select-all checkbox slot.
const double kColLeadingWidth = 32;

/// Stable minimum height for every entity-list row.
///
/// Applied as a `minHeight` floor by the list scaffold so a row never
/// changes height when its leading slot swaps between avatar and selection
/// checkbox — toggling a row's checkbox must not reflow the list. Slightly
/// taller than the previous content-driven ~64 px so short rows breathe and
/// tall rows (2-line identity + money column) are never clipped. Also used
/// for the master-detail auto-scroll estimate.
const double kEntityListRowHeight = 72;

/// Horizontal gap between cells in the table grid.
const double kColCellGap = 12;

/// Gap between the leading row-actions slot ([colWMoreMenu]) and the
/// avatar / select-checkbox slot. Intentionally tighter than the 12 px
/// inter-column [kColCellGap] so the action cluster sits flush against the
/// checkbox. Used by the header strip and every wide row tile at exactly
/// that one position so they stay column-aligned. (The actions slot already
/// hugs its cluster — [colWMoreMenu] = edit + gap + menu on touch, plus 8 px
/// of slack with a pointer — so 0 here keeps the checkbox tight to the menu.)
const double kColActionsLeadingGap = 0;

/// Minimum width for a flex column when the table sums its min widths to
/// decide whether to engage the horizontal scroller. Today only one column
/// per entity flexes (typically the identity / name column).
const double kColumnFlexMinWidth = 220;

/// Total minimum width the wide-mode data-table needs to lay out without
/// overflowing. Add up the slot widths used by every row tile and column
/// header so the scaffold can decide when to engage the horizontal
/// scroller. Mirrors the (previously duplicated) `_computeTableMinWidth`
/// helper that lived in each list screen.
double computeTableMinWidth(List<ColumnDefinition<dynamic>> columns) {
  var total = colWMoreMenu() + kColActionsLeadingGap; // actions + tight gap
  total += kColLeadingWidth + kColCellGap; // avatar/checkbox + gap
  for (final c in columns) {
    total += c.isFlex ? kColumnFlexMinWidth : c.width!;
    total += kColCellGap;
  }
  total += kColWPillSlot;
  // Mirror the row's horizontal padding (`EdgeInsetsDirectional.fromSTEB(16, _, 16, _)`).
  return total + 32;
}
