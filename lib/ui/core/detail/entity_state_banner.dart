import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/dialogs/confirm_action_dialog.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/core/widgets/sync_first_banner.dart';
import 'package:admin/utils/formatting.dart';

/// The strip(s) a record screen pins above its body when the whole record is
/// in a state the user needs to know before they do anything with it:
///
///  * **not synced yet** — the existing [SyncFirstBanner];
///  * **deleted** — the record is read-only until restored;
///  * **archived** — still editable, but out of the active lists.
///
/// Returns null for an ordinary record, so the caller mounts nothing. Hand the
/// result to `EntityDetailScaffold.bannerForItem`, which keeps it outside the
/// scroll view: a banner that scrolled away with the header would stop
/// explaining a read-only screen at exactly the point the user starts wondering
/// why nothing can be changed.
///
/// A screen that shows this should pass `showStatePills: false` to its header —
/// "Deleted" in a banner and again in a pill under it is the word twice.
Widget? entityStateBanner({
  required String entityId,
  required bool isDeleted,
  required DateTime? archivedAt,
  required Formatter? formatter,
  VoidCallback? onRestore,
}) {
  final unsynced = isUnsynced(entityId);
  final archived = archivedAt != null;
  if (!unsynced && !isDeleted && !archived) return null;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (unsynced) SyncFirstBanner(entityId: entityId),
      // Deleted outranks archived, as it does in the header's pills: a
      // deleted record's archive date is not what the user needs to hear.
      if (isDeleted)
        _StateStrip.deleted(onRestore: onRestore)
      else if (archived)
        _StateStrip.archived(
          archivedAt: archivedAt,
          formatter: formatter,
          onRestore: onRestore,
        ),
    ],
  );
}

/// [entityStateBanner] for a record whose Restore is one of its own action
/// items — which is every entity. The banner's button is **that item**, found
/// in the same list the `⋮` menu renders and run through the same
/// confirmation gate, so it cannot offer a restore the menu would not: an
/// entity's `itemsFor` leaves Restore out for a user who may not edit the
/// record, and then the banner has no button.
Widget? recordStateBanner<A>(
  BuildContext context, {
  required List<EntityActionItem<A>> items,
  required A restoreKind,
  required String entityId,
  required bool isDeleted,
  required DateTime? archivedAt,
  required Formatter? formatter,
}) {
  final restore = findActionItem<A>(items, restoreKind);
  return entityStateBanner(
    entityId: entityId,
    isDeleted: isDeleted,
    archivedAt: archivedAt,
    formatter: formatter,
    onRestore: restore == null ? null : guardedOnTap<A>(context, restore),
  );
}

class _StateStrip extends StatelessWidget {
  const _StateStrip.deleted({this.onRestore})
    : _deleted = true,
      archivedAt = null,
      formatter = null;

  const _StateStrip.archived({
    required this.archivedAt,
    required this.formatter,
    this.onRestore,
  }) : _deleted = false;

  final bool _deleted;
  final DateTime? archivedAt;
  final Formatter? formatter;

  /// Null hides the button — a user who may not restore the record still
  /// needs to be told what state it is in.
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final tone = _deleted ? tokens.overdue : tokens.draft;
    return Material(
      color: _deleted ? tokens.overdueSoft : tokens.draftSoft,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: InSpacing.lg(context),
          vertical: InSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              _deleted ? Icons.delete_outline : Icons.archive_outlined,
              size: 18,
              color: tone,
            ),
            const SizedBox(width: InSpacing.sm),
            Expanded(
              child: Text(
                _message(context),
                // The message is the point of the strip; let it wrap rather
                // than lose its second half on a phone.
                style: TextStyle(color: tokens.ink, fontSize: 13),
              ),
            ),
            if (onRestore != null) ...[
              const SizedBox(width: InSpacing.sm),
              TextButton(
                onPressed: onRestore,
                style: TextButton.styleFrom(
                  foregroundColor: tokens.ink,
                  minimumSize: const Size(64, 36),
                ),
                child: Text(context.tr('restore')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _message(BuildContext context) {
    if (_deleted) return context.tr('record_deleted_read_only');
    final at = archivedAt;
    final f = formatter;
    if (at == null || f == null) return context.tr('archived');
    // "Archived At: <date>" — a label and a value, so there is no sentence
    // whose word order a translation could get wrong. The local calendar day,
    // as everywhere else a server timestamp is shown as a date.
    final day = f.date(at.toLocal().toIso8601String().split('T').first);
    return '${context.tr('archived_at')}: $day';
  }
}
