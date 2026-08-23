import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/mdi_icons.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/dialogs/confirm_action_dialog.dart';
import 'package:admin/ui/core/list/embedded_list_scope.dart';

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

  /// Compact, shrink-wrapped icon sizing so the edit pencil and the `…`
  /// menu sit close together like the old admin-portal data table, instead
  /// of each claiming Flutter's default 48×48 tap target.
  static const _tightConstraints = BoxConstraints(minWidth: 36, minHeight: 36);

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

    final popup = MenuAnchor(
      // Match the old PopupMenuButton: an outside tap only dismisses the
      // menu, it doesn't also activate the row/widget underneath.
      consumeOutsideTap: true,
      menuChildren: EntityActionItem.menuChildrenFor<A>(context, menuItems),
      builder: (context, controller, _) => IconButton(
        icon: Icon(effectiveIcon),
        tooltip: context.tr('actions'),
        // Zero padding keeps the icon flush with the row's `kColWMoreMenu`
        // slot so it stays aligned with the column header's `…` cell.
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: _tightConstraints,
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
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: _tightConstraints,
          // Null onPressed gives the standard greyed disabled state for
          // soft-deleted rows.
          onPressed: (editEnabled && primary.enabled)
              ? guardedOnTap<A>(context, primary)
              : null,
        ),
        const SizedBox(width: InSpacing.sm),
        popup,
      ],
    );
  }
}
