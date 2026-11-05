import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/list/entity_actions_popup_button.dart';
import 'package:admin/ui/core/list/entity_list_top_row.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';

/// The selection chrome of an entity list: Cancel, "N selected", Select all
/// visible, and the bulk actions — spread inline on [wide] (collapsing into
/// "More" as the row runs out of room), one ⋮ menu otherwise.
///
/// The standalone list shows it in its header (`EntityListAppBar`); an
/// embedded list — a record screen's Invoices, Quotes, Payments… tab — has no
/// header of its own and swaps its slim toolbar for this while selecting.
/// Without it the rows there could be ticked with nothing to act on them
/// (invoiceninja/flutter#186).
class EntityListSelectionRow<T> extends StatelessWidget {
  const EntityListSelectionRow({
    super.key,
    required this.vm,
    required this.items,
    required this.wide,
  });

  final GenericListViewModel<T> vm;

  /// The bulk actions that apply to the current selection.
  final List<EntityActionItem<String>> items;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    // One first-row slot tall, like every sibling of the search field: its
    // 48-px touch buttons must not be what sets the row's height.
    return HeaderRowSlot(
      expand: true,
      child: Row(
        children: [
          selectionCloseButton(context, vm),
          const SizedBox(width: 8),
          if (wide)
            selectionCountText(context, vm)
          else
            Expanded(child: selectionCountText(context, vm)),
          const SizedBox(width: 8),
          selectAllVisibleButton(context, vm),
          if (wide) ...[
            const SizedBox(width: 8),
            // Bulk actions have no primary Edit, so they keep the
            // spread-inline-then-collapse-into-"More" overflow bar.
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: EntityOverflowActionBar<String>(items: items),
                ),
              ),
            ),
          ] else
            EntityActionsPopupButton<String>(items: items),
        ],
      ),
    );
  }
}

/// Leaves selection mode.
Widget selectionCloseButton(
  BuildContext context,
  GenericListViewModel<dynamic> vm,
) => IconButton(
  icon: const Icon(Icons.close),
  tooltip: context.tr('cancel'),
  onPressed: vm.clearSelection,
);

/// "N selected".
Widget selectionCountText(
  BuildContext context,
  GenericListViewModel<dynamic> vm,
) => Text(
  context.tr('count_selected', {'count': vm.countSelected.toString()}),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
);

/// Adds every loaded row to the selection.
Widget selectAllVisibleButton(
  BuildContext context,
  GenericListViewModel<dynamic> vm,
) => IconButton(
  icon: const Icon(Icons.checklist_outlined),
  tooltip: context.tr('select_all_visible'),
  onPressed: vm.selectAllVisible,
);
