/// How much room a scrollable has to leave at its bottom edge so its last row
/// can clear a floating action button — the one path shared by every entity
/// list, the three custom Tasks views and the narrow dashboard.
///
/// ## Why a list needs this at all
///
/// `Scaffold` does not inset its body for the FAB. The button floats over the
/// body's bottom-right corner, so a `ListView` that ends flush with the
/// viewport leaves its last row permanently underneath — and on a list row
/// that is exactly where the `⋮` overflow menu lives, so the row's whole
/// action menu becomes unreachable at any scroll offset
/// (invoiceninja/flutter#167, reported on Quotes; #164 was the same bug on the
/// dashboard).
///
/// ## The arithmetic
///
/// `FabFloatOffsetY.getOffsetY` (Flutter's
/// `floating_action_button_location.dart`) places `FloatingActionButtonLocation
/// .endFloat` at, with no `bottomNavigationBar` / bottom sheet / snack bar in
/// play:
///
/// ```text
/// safeMargin = max(16, minViewPadding.bottom - 0 + 16) = minViewPadding.bottom + 16
/// fabY       = contentBottom - 56 - safeMargin
/// ```
///
/// so the button covers the bottom `56 + 16 + bottomSafeInset` of the body.
/// [kFabClearance] is the fixed part; [fabScrollClearance] adds the inset and a
/// gap.
library;

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';

/// Pure geometry: how much of a body's bottom edge a floating action button
/// covers — the 56 px button plus Material's own [kFloatingActionButtonMargin].
///
/// This is the number to add to a gutter a surface already has. A scroll view
/// with no gutter of its own wants [fabScrollClearance] instead.
const double kFabClearance = 56 + kFloatingActionButtonMargin;

/// The bottom padding a scroll view sitting under a floating action button
/// needs, so its last row can scroll clear of the button.
///
/// Three terms, and two of them are the reason this is a function rather than a
/// constant at each call site:
///
/// * [kFabClearance], the button itself.
/// * [InSpacing.sm], so the last row does not land *flush* against the button.
///   At exactly [kFabClearance] the row's bottom edge is the button's top edge,
///   which puts the row's 44 px `⋮` target hard against the FAB's hit box and
///   makes a low mis-tap open a new record. Same 8 px, for the same reason,
///   that `kColActionsClusterGap` puts between the pencil and the `⋮`. It is
///   deliberately the `const` [InSpacing.sm] and not `InSpacing.md` / `.lg`:
///   those read `MediaQuery.sizeOf(context).width` — the **window** — so on a
///   700 px window with a sub-600 pane (rail up, which is a configuration that
///   *does* show the FAB) they would quietly return their wide value.
/// * The bottom safe inset, because the Scaffold measures the button up from it
///   too. A `BoxScrollView` applies that inset for itself, but **only while its
///   `padding` is null** (`BoxScrollView.build` wraps the sliver in the
///   MediaQuery padding in exactly that case, and `Scaffold` leaves the inset in
///   the body's MediaQuery unless there is a `bottomNavigationBar` or
///   `persistentFooterButtons`). So passing a padding at all means owning the
///   inset — drop it and every gesture-nav Android phone silently loses its
///   home-indicator gap. Pass `null`, never `EdgeInsets.zero`, on the branch
///   where there is no FAB.
///
/// `padding`, not `viewPadding`: it collapses to 0 behind an open keyboard,
/// which is exactly what the Scaffold's own FAB margin does
/// (`resizeToAvoidBottomInset` shrinks the body and the button rides above the
/// keyboard), and it is the same value `BoxScrollView` consumes — so the two
/// agree in every keyboard state.
///
/// A surface that already sits inside a `SafeArea` (the dashboard body) adds
/// [kFabClearance] to its own gutter instead of calling this; adding the inset
/// on top of a `SafeArea` that already removed it would leave a visible band.
double fabScrollClearance(BuildContext context) =>
    kFabClearance + InSpacing.sm + MediaQuery.paddingOf(context).bottom;
