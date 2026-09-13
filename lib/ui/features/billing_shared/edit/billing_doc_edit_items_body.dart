import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_doc_edit_fab.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_editor.dart';

/// The narrow (tabbed) Items-tab body shared by all five billing-doc edit
/// layouts — invoice, quote, credit, purchase order and recurring invoice.
///
/// It owns the three things those five had hand-copied: the ⌘N picker
/// shortcut scope, the scroll host, and the picker FAB — which is now
/// conditional, and that is the point of the widget.
///
/// Six things here are load-bearing and every one of them fails silently.
///
/// **1. `StackFit.expand` is the fix for invoiceninja/flutter#141.** The
/// default `StackFit.loose` hands a non-positioned child `constraints
/// .loosen()`, so the scroll view shrink-wrapped to its content and the
/// `Stack` parked it at its default `AlignmentDirectional.topStart`. A
/// populated list hid that — its `ReorderableListView` fills the cross axis —
/// but the empty state collapsed to the width of its two buttons and hugged
/// the top-left corner, which is exactly what #141 screenshotted.
///
/// **2. The `Stack` stays mounted even with no FAB.** Dropping it on the
/// narrow branch would re-inflate the scroll view on every resize across
/// [kLineItemWideTableMinWidth] and lose the user's scroll position; a
/// conditional *child* costs nothing. The flip side is that `expand` needs a
/// **bounded** host, which is not a new requirement and so is not guarded: the
/// `SingleChildScrollView` below would throw "Vertical viewport was given
/// unbounded height" first. A `TabBarView` page is always bounded.
///
/// **3. The FAB follows the TABLE, not the layout branch.** The narrow layout
/// is used up to a 1024 px pane while [LineItemEditor] switches to the desktop
/// table at 700 px of content, so there is a band — an iPad Pro in portrait,
/// any desktop window around 964–1255 px with the rail up — where this tab
/// renders that table. The table has no inline picker affordance at all, so
/// removing the FAB there would leave those users no way to open the picker
/// and no ⌘N to fall back on. Below the threshold the mobile card list carries
/// `Add Items` in both its states, which is the same-verb substitute
/// CLAUDE.md's flutter#135 rule requires before a FAB may go.
///
/// **4. One width read, two consumers.** Both the FAB gate and the min-height
/// come off this single `LayoutBuilder`, and the gate subtracts the same
/// gutters the scroll view applies — so `contentWidth` here is the number
/// [LineItemEditor]'s own `LayoutBuilder` will see, to the pixel. Asking the
/// question twice from two different boxes is the trap CLAUDE.md's Tasks
/// filter-bar rule records.
///
/// **5. `minHeight` is ZERO on the wide-table branch.** `RenderFlex` ends in
/// `constraints.constrain(...)`, which honours `minHeight` whatever the
/// `mainAxisSize` — so applied there it stretches `LineItemTableDesktop`'s
/// *bordered* container to the full viewport and leaves a tall empty box below
/// the last row. The stretch is only ever wanted for the card list, whose
/// empty state centres inside it. A ternary rather than a conditional widget,
/// so the tree shape stays constant across the breakpoint.
///
/// **6. `SliverFillRemaining(hasScrollBody: false)` is the idiomatic-looking
/// alternative and is forbidden here.** It calls `getMaxIntrinsicHeight` on
/// its child, and this subtree contains [LineItemEditor]'s `LayoutBuilder`,
/// which throws on an intrinsic query in debug and answers 0 in release.
class BillingDocEditItemsBody extends StatelessWidget {
  const BillingDocEditItemsBody({
    super.key,
    required this.heroTag,
    required this.onPickItems,
    required this.child,
  });

  /// Distinct per entity (`'invoice_picker_fab_mobile'`, …) so two edit
  /// screens stacked in master-detail don't share a Hero.
  final String heroTag;

  /// Opens the bulk products / tasks / expenses picker. Backs the FAB, ⌘N and
  /// — through [child] — the card list's `Add Items` button.
  final VoidCallback onPickItems;

  /// The items section itself: `BillingDocItemsTabs`, or a bare
  /// [LineItemEditor] on purchase orders.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pad = InSpacing.lg(context);
    return BillingDocEditPickerShortcuts(
      onPickItems: onPickItems,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wideTable = lineItemEditorShowsWideTable(
            constraints.maxWidth - pad * 2,
          );
          final available = math.max(0.0, constraints.maxHeight - pad * 2);
          return Stack(
            fit: StackFit.expand,
            children: [
              SingleChildScrollView(
                padding: EdgeInsets.all(pad),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: wideTable ? 0 : available,
                  ),
                  child: child,
                ),
              ),
              if (wideTable)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: BillingDocEditFab(
                    heroTag: heroTag,
                    onPressed: onPickItems,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
