import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/dialogs/confirm_action_dialog.dart';
import 'package:admin/ui/core/list/entity_actions_popup_button.dart';
import 'package:admin/ui/core/list/entity_bulk_message.dart';
import 'package:admin/ui/core/widgets/leading_select_slot.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/docuninja/view_models/docuninja_documents_view_model.dart';

final _log = Logger('DocuNinjaBulk');

/// One of React's bulk actions on a DocuNinja list (`DataTable`'s
/// `withResourcefulActions`): archive, restore or delete, sent for the whole
/// selection in one `POST <resource>/bulk {action, ids}`.
class DnBulkAction<T> {
  const DnBulkAction({
    required this.action,
    required this.icon,
    required this.eligible,
    required this.noun,
    this.confirm = false,
  });

  /// The API verb, which is also the label key: `archive`, `restore`,
  /// `delete`.
  final String action;
  final IconData icon;

  /// Whether a row can take it. Rows that can't are left out of the
  /// request and counted as skipped.
  final bool Function(T item) eligible;

  /// The resource's toast noun (`document`, `user`, `template`): the toasts
  /// are `<verb>d_<noun>` for one row and `<verb>d_<noun>s` for several.
  final String noun;

  /// Asks first while the user has Confirm actions on.
  final bool confirm;
}

/// React's three bulk actions, with its rule for Restore (shown only for
/// rows that are not active) and the app's for the others (archive an
/// active row, delete one not yet deleted). [locked] rows take none of them
/// (the DocuNinja owner and the signed-in user, on the users list).
List<DnBulkAction<T>> dnLifecycleBulkActions<T>({
  required String noun,
  required bool Function(T item) isActive,
  required bool Function(T item) isDeleted,
  bool Function(T item)? locked,
  bool confirmRestore = false,
}) {
  bool free(T item) => !(locked?.call(item) ?? false);
  return [
    DnBulkAction<T>(
      action: 'archive',
      icon: Icons.archive_outlined,
      eligible: (i) => free(i) && isActive(i),
      noun: noun,
      confirm: true,
    ),
    DnBulkAction<T>(
      action: 'restore',
      icon: Icons.restore_outlined,
      eligible: (i) => free(i) && !isActive(i),
      noun: noun,
      confirm: confirmRestore,
    ),
    DnBulkAction<T>(
      action: 'delete',
      icon: Icons.delete_outline,
      eligible: (i) => free(i) && !isDeleted(i),
      noun: noun,
      confirm: true,
    ),
  ];
}

/// The bulk actions as menu items: only those something in the selection can
/// take (as the entity lists do), off while one runs.
List<EntityActionItem<String>> dnBulkItems<T>(
  BuildContext context,
  DnListViewModel<T> vm,
  List<DnBulkAction<T>> actions, {
  VoidCallback? onDone,
}) {
  final selected = vm.selectedItems;
  return [
    for (final a in actions)
      if (selected.any(a.eligible))
        EntityActionItem<String>(
          kind: a.action,
          icon: a.icon,
          label: context.tr(a.action),
          enabled: !vm.bulkInFlight,
          disabledTooltipKey: null,
          isLifecycle: true,
          isDestructive: a.action == 'delete',
          onTap: () => runDnBulkAction(context, vm, a, onDone: onDone),
        ),
  ];
}

/// Runs [action] on the selection: asks first where it should, sends one
/// request for the rows that can take it, then says what happened.
///
/// [onDone] runs once the request has been answered, whether it worked or
/// not (the users list re-counts its seats).
Future<void> runDnBulkAction<T>(
  BuildContext context,
  DnListViewModel<T> vm,
  DnBulkAction<T> action, {
  VoidCallback? onDone,
}) async {
  if (vm.bulkInFlight) return;
  // Captured now for the dialog's count; read again after it (below).
  var selected = vm.countSelected;
  var ids = vm.selectedIdsWhere(action.eligible);
  if (ids.isEmpty) {
    Notify.info(context, context.tr('no_records_selected'));
    return;
  }
  var skipped = selected - ids.length;
  final services = context.read<Services>();
  if (action.confirm && services.confirmActions.value) {
    final ok = await showConfirmActionDialog(
      context,
      title: context.tr(action.action),
      subject: context.tr('count_records_selected', {'count': '${ids.length}'}),
      destructive: action.action == 'delete',
    );
    if (!ok || !context.mounted) return;
    // Read again: a refresh while the dialog was up (a teammate's change,
    // a return from the browser) may have taken rows out of the list, and
    // a bulk never reaches a record no longer shown.
    selected = vm.countSelected;
    ids = vm.selectedIdsWhere(action.eligible);
    skipped = selected - ids.length;
    if (ids.isEmpty) {
      Notify.info(context, context.tr('no_records_selected'));
      return;
    }
  }
  try {
    // Another bulk already running: nothing was sent, so nothing to say.
    if (!await vm.applyBulk(action.action, ids)) return;
  } on Object catch (e, st) {
    _log.warning('DocuNinja bulk ${action.action} failed', e, st);
    onDone?.call();
    if (context.mounted) {
      Notify.error(context, context.tr('an_error_occurred_try_again'));
    }
    return;
  }
  onDone?.call();
  if (!context.mounted) return;
  final verb = '${action.action}d';
  Notify.success(
    context,
    formatBulkMessage(
      context,
      singleKey: '${verb}_${action.noun}',
      pluralKey: '${verb}_${action.noun}s',
      nothingKey: 'no_records_selected',
      result: (ok: ids.length, skipped: skipped, failed: 0),
    ),
  );
}

/// The selection header that replaces a DocuNinja list's search row while
/// selecting: Cancel, "N selected", Select all visible, and the bulk
/// actions (spread inline when [wide]; narrower, icon buttons when
/// [inlineActions], one `⋮` otherwise), as the entity lists' selection row
/// has.
class DnSelectionBar<T> extends StatelessWidget {
  const DnSelectionBar({
    super.key,
    required this.vm,
    required this.actions,
    required this.wide,
    this.onDone,
    this.inlineActions = false,
  });

  final DnListViewModel<T> vm;
  final List<DnBulkAction<T>> actions;
  final bool wide;

  /// Runs once a bulk request has been answered.
  final VoidCallback? onDone;

  /// On a narrow bar, each action as an icon button with its tooltip
  /// instead of behind a `⋮`: the three lifecycle actions fit beside the
  /// count on a phone, and a second `⋮` there read as the app bar's.
  final bool inlineActions;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final items = dnBulkItems(context, vm, actions, onDone: onDone);
      final count = Text(
        context.tr('count_selected', {'count': '${vm.countSelected}'}),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: context.tr('cancel'),
              onPressed: vm.clearSelection,
            ),
            const SizedBox(width: 8),
            if (wide) count else Expanded(child: count),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.checklist_outlined),
              tooltip: context.tr('select_all_visible'),
              onPressed: vm.selectAllVisible,
            ),
            if (wide)
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: EntityOverflowActionBar<String>(items: items),
                ),
              )
            else if (inlineActions)
              for (final item in items)
                IconButton(
                  icon: Icon(item.icon),
                  tooltip: item.label,
                  onPressed: item.enabled
                      ? guardedOnTap<String>(context, item)
                      : null,
                )
            else if (items.isNotEmpty)
              EntityActionsPopupButton<String>(items: items),
          ],
        ),
      );
    },
  );
}

/// A selectable row's checkbox slot: on a wide pane it is always there (its
/// checkbox shows on hover, as the entity lists' does); on a narrow one only
/// while selecting, where it is the checkbox. Null when there is none.
Widget? dnSelectLeading({
  required bool wide,
  required bool selecting,
  required bool selected,
  required VoidCallback onToggle,
}) {
  if (!wide && !selecting) return null;
  return Padding(
    padding: const EdgeInsetsDirectional.only(end: InSpacing.sm),
    child: LeadingSelectSlot(
      selecting: selecting,
      selected: selected,
      onSelectTap: onToggle,
      defaultChild: const SizedBox.shrink(),
    ),
  );
}

/// The width [dnSelectLeading] takes on a wide pane, for a header to line up.
const double kDnSelectSlotWidth = 32 + InSpacing.sm;

/// [actions] this user's DocuNinja role allows: archive and restore need
/// edit, delete needs delete. React offers all three and lets DocuNinja
/// refuse; the app leaves out what would be refused.
List<DnBulkAction<T>> dnPermittedBulkActions<T>(
  List<DnBulkAction<T>> actions, {
  required bool canEdit,
  required bool canDelete,
}) => [
  for (final a in actions)
    if (a.action == 'delete' ? canDelete : canEdit) a,
];
