import 'dart:async';

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/data/models/domain/activity.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/list/entity_actions_popup_button.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';

/// The verbs a comment row can actually perform. Deliberately short: the API
/// has no update or delete route for an activity note (`routes/api.php:181-184`
/// registers `GET activities`, `POST activities/entity`, `POST activities/notes`
/// and `GET activities/download_entity/{activity}`, and nothing else), the
/// `activities` table has neither `deleted_at` nor `is_deleted`, and every
/// `$activity->save()` server-side is on a fresh `new Activity()`. So a synced
/// note is immutable, and this menu must never imply otherwise — see
/// BACKEND.md § F3d for the standing ask.
enum CommentRowAction { copy, viewRecord, delete }

/// The `⋯` menu on a comment row, shared by the synced [ActivityRecordRow] and
/// the optimistic `PendingCommentRow` so the two cannot drift apart the way the
/// twin add-comment dialogs once did.
///
/// This is the answer to invoiceninja/flutter#123 ("doesn't seem interactive").
/// The row was inert: no tap, no menu, no copy — on React and the legacy Flutter
/// app too, where an activity row is a hover colour and a navigation-only
/// `ListTile` respectively. What it can honestly offer is *not* Edit and Delete,
/// so it offers what exists instead, and the add-comment dialog says once, up
/// front, that a saved comment is permanent.
///
/// **Owns its own leading gap and renders nothing when it has no items.** A
/// caller cannot predict emptiness without building this — the item list
/// depends on the note text, the refs and the outbox state — so a gap left
/// outside would strand 8 px at the end of a row with no button, the mirror of
/// the double-gap trap CLAUDE.md records for the detail cards grids. A comment
/// with no text and no source ref, on a synced row, mounts nothing at all
/// (invoiceninja/flutter#111's rule for the list-row call button).
class CommentRowMenu extends StatelessWidget {
  const CommentRowMenu({
    super.key,
    required this.text,
    this.source,
    this.onDelete,
  });

  /// The note exactly as the row displays it — a call note's marker already
  /// stripped, so Copy yields what the user can see rather than the wire form.
  final String text;

  /// The record the note was filed against, when that isn't the one on screen.
  ///
  /// `ActivityRecordRow` prints this in the meta line as **text**, because the
  /// note bypass strips the templated sentence and with it the per-token
  /// `TapGestureRecognizer` that would otherwise have to be built and disposed.
  /// A menu item needs neither, so this is where that ref becomes reachable.
  final ActivityRef? source;

  /// Discards a still-queued note. Null once it is on the wire or synced —
  /// which is most of the time, and is the point: see `PendingCommentRow`.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final body = text.trim();
    final ref = source;
    final onDeleteTap = onDelete;
    final items = <EntityActionItem<CommentRowAction>>[
      if (body.isNotEmpty)
        EntityActionItem(
          kind: CommentRowAction.copy,
          icon: Icons.copy_outlined,
          label: context.tr('copy'),
          enabled: true,
          // The one thing that helps with a typo on a note nothing can edit:
          // copy it, fix it, post it again.
          onTap: () => unawaited(copyToClipboard(context, body)),
        ),
      if (ref != null && ref.isLink)
        EntityActionItem(
          kind: CommentRowAction.viewRecord,
          icon: Icons.open_in_new,
          // `view_record`, not the per-entity `view_*` keys: `view_expense` is
          // "View expense # :expense" and would render the raw token.
          label: context.tr('view_record'),
          enabled: true,
          onTap: () => goEntityRecord(context, ref.type!, ref.id),
        ),
      if (onDeleteTap != null)
        EntityActionItem(
          kind: CommentRowAction.delete,
          icon: Icons.delete_outline,
          label: context.tr('delete'),
          enabled: true,
          // Fires a mutation with no further UI step and destroys what the user
          // typed, so it takes the Confirm-actions gate. `menuChildrenFor`
          // wires it through `guardedOnTap`, which reads the preference at tap
          // time — an untagged item never touches `Services` at all.
          confirm: true,
          isDestructive: true,
          // Names the note in the prompt. A card shows two rows and the tab
          // shows every one; without this the dialog can't say which.
          confirmSubject: body.isEmpty ? null : body,
          onTap: onDeleteTap,
        ),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsetsDirectional.only(start: InSpacing.sm),
      child: EntityActionsPopupButton<CommentRowAction>(items: items),
    );
  }
}
