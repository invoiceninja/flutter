import 'package:flutter/material.dart';

import 'package:admin/app/mdi_icons.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/dialogs/confirm_action_dialog.dart';
import 'package:admin/ui/core/list/embedded_list_scope.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';

/// List-row trailing popup that consumes the same [EntityActionItem] list
/// the detail header renders. Mirrors the disabled-styled menu rows that
/// the detail header's `_MoreMenu` overflow uses, so the two surfaces feel
/// identical when an action is a "coming soon" placeholder.
class EntityActionsPopupButton<A> extends StatelessWidget {
  const EntityActionsPopupButton({
    super.key,
    required this.items,
    this.icon = Icons.more_vert,
    this.splitEditAction = false,
    this.editEnabled = true,
  });

  final List<EntityActionItem<A>> items;
  final IconData icon;

  /// When true (wide data-table rows), the primary "Edit" action is pulled
  /// out of the overflow menu and rendered as a dedicated leading icon
  /// button to the left of the `…` menu. The detail header (which shares
  /// the same [items] list via a different widget) is unaffected.
  final bool splitEditAction;

  /// Gates the standalone edit button. `false` for soft-deleted rows —
  /// the pencil renders greyed and non-tappable. Archived rows stay
  /// editable. Ignored unless [splitEditAction] is true.
  final bool editEnabled;

  /// Pins both icon buttons to exactly [actionButtonSize] — 44 on touch, 32
  /// with a pointer — so the pair sits close together like the old
  /// admin-portal data table *and* the fixed [colWMoreMenu] slot the wide row
  /// tiles put this in can be derived from the same number.
  ///
  /// `fixedSize` + `tapTargetSize: shrinkWrap` rather than
  /// `constraints:` + `visualDensity:`: with the size left implicit,
  /// `ThemeData.materialTapTargetSize` (`padded` on Android/iOS) floors the
  /// button's **layout** box — not just its hit area — at
  /// `kMinInteractiveDimension` plus the density adjustment, i.e. 48 − 8 = 40.
  /// Two of those plus the gap made 88 inside an 80 px slot: a silent 8 px
  /// overflow that painted across the neighbouring select slot and put the
  /// `…` button's right edge outside its parent's bounds, where it can't be
  /// hit-tested. They were also 40, under the app's own 44 px touch floor.
  /// Both halves of invoiceninja/flutter#89's "no way to delete" report.
  ///
  /// Three details make this exact rather than approximate, and dropping any
  /// one of them silently changes the size instead of failing:
  ///
  /// * `visualDensity` stays **off**. `IconButton` merges the `style:` over
  ///   its defaults, but the `visualDensity:` *field* still wins, and the
  ///   density adjustment is applied to the constraints before `fixedSize`.
  /// * `minimumSize: Size.zero` / `maximumSize: Size.infinite`, because
  ///   `fixedSize` is *clamped by* those — and the M3 default `minimumSize`
  ///   is `kMinInteractiveDimension`, so a 32 would come back out as 40 on a
  ///   desktop theme. Zeroing them makes `fixedSize` the only input.
  /// * `tapTargetSize: shrinkWrap`, so the pinned box isn't re-inflated. Safe
  ///   for touch precisely because [actionButtonSize] already is 44 there —
  ///   `shrinkWrap` on its own, with the size left implicit, would not be.
  static ButtonStyle _buttonStyle(double side) => IconButton.styleFrom(
    fixedSize: Size(side, side),
    minimumSize: Size.zero,
    maximumSize: Size.infinite,
    padding: EdgeInsets.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  @override
  Widget build(BuildContext context) {
    // Embedded detail-tab lists adopt the Client-datatable vertical menu
    // regardless of the icon a tile passes for its standalone screen; split
    // mode (wide tables) likewise always uses the vertical 3-dot menu next
    // to the circled pencil, matching the old app.
    final effectiveIcon = (EmbeddedListScope.of(context) || splitEditAction)
        ? Icons.more_vert
        : icon;

    // Pull the primary (Edit, by convention) item out into its own button
    // when asked. `isPrimary` is only ever set by `editActionItem`, so this
    // is the Edit action across every entity. Read-only entities have no
    // primary item — fall through to the plain popup.
    EntityActionItem<A>? primary;
    var menuItems = items;
    if (splitEditAction) {
      final idx = items.indexWhere((i) => i.isPrimary);
      if (idx != -1) {
        primary = items[idx];
        menuItems = [
          for (var i = 0; i < items.length; i++)
            if (i != idx) items[i],
        ];
      }
    }

    final style = _buttonStyle(actionButtonSize());

    final popup = MenuAnchor(
      // Match the old PopupMenuButton: an outside tap only dismisses the
      // menu, it doesn't also activate the row/widget underneath.
      consumeOutsideTap: true,
      menuChildren: EntityActionItem.menuChildrenFor<A>(context, menuItems),
      builder: (context, controller, _) => IconButton(
        icon: Icon(effectiveIcon),
        tooltip: context.tr('actions'),
        style: style,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );

    if (primary == null) return popup;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          // Edit affordance carried over from the old admin-portal data table.
          icon: Icon(MdiIcons.circleEditOutline),
          tooltip: context.tr('edit'),
          style: style,
          // Null onPressed gives the standard greyed disabled state for
          // soft-deleted rows.
          onPressed: (editEnabled && primary.enabled)
              ? guardedOnTap<A>(context, primary)
              : null,
        ),
        // Same gap `colWMoreMenu()` budgets for — keep them in step.
        const SizedBox(width: kColActionsClusterGap),
        popup,
      ],
    );
  }
}
