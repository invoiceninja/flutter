import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/domain/sync/sync_event.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// Resolution chosen by the user when [showConflictResolutionSheet] returns.
///
/// The caller decides what each option means in concrete terms — the sheet
/// itself just collects the user's intent.
enum ConflictResolution {
  /// Keep the local row's pending changes, re-enqueue them as a fresh
  /// outbox mutation (the original parked row is discarded).
  useMine,

  /// Drop the local pending changes; the next sync pull will surface the
  /// server's version.
  discardMine,

  /// Open the entity's detail screen so the user can inspect the diff
  /// themselves before deciding.
  openEntity,

  /// User dismissed the sheet without choosing. Caller should leave the
  /// outbox row parked for now and prompt again on the next event.
  none,
}

/// Modal sheet shown when [SyncRepository] emits a [ConflictEvent]. Two
/// variants, keyed on [ConflictEvent.isDeletedServerSide]:
///   * **stale data (409)** — open / discard / use-mine.
///   * **deleted server-side** — a "record deleted on the server" message +
///     discard-locally + keep-for-later. There is no "use my changes":
///     re-sending the update would fail forever (the record is gone).
///     Note this variant's discard hard-deletes the local row, so it must
///     stay reserved for a genuinely-missing entity — see
///     [ConflictEvent.isDeletedServerSide].
///
/// The sheet doesn't touch the outbox or the database — the caller wires the
/// choice to `repo.save(...)` / `discardPendingFor(...)` / `context.go(...)`.
Future<ConflictResolution> showConflictResolutionSheet(
  BuildContext context, {
  required ConflictEvent event,
}) async {
  final deleted = event.isDeletedServerSide;
  final result = await showDialog<ConflictResolution>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final tokens = ctx.inTheme;
      return AlertDialog(
        title: Text(
          ctx.tr(
            deleted
                ? 'record_deleted_on_server_title'
                : 'conflict_detected_title',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              ctx.tr(
                deleted
                    ? 'record_deleted_on_server_message'
                    : 'conflict_detected_message',
              ),
              style: TextStyle(color: tokens.ink2),
            ),
            // The raw entity-missing body ("No query results for model …")
            // adds nothing for the deleted case; only surface the server
            // message for a genuine stale-data conflict.
            if (!deleted && event.message.isNotEmpty) ...[
              const SizedBox(height: InSpacing.sm),
              Text(
                event.message,
                style: TextStyle(color: tokens.ink3, fontSize: 12),
              ),
            ],
          ],
        ),
        actions: deleted
            ? [
                TextButton(
                  onPressed: () =>
                      Navigator.of(ctx).pop(ConflictResolution.none),
                  child: Text(ctx.tr('keep_for_later')),
                ),
                PrimaryDialogAction(
                  label: ctx.tr('discard_my_changes'),
                  onPressed: () =>
                      Navigator.of(ctx).pop(ConflictResolution.discardMine),
                ),
              ]
            : [
                TextButton(
                  onPressed: () =>
                      Navigator.of(ctx).pop(ConflictResolution.openEntity),
                  child: Text(ctx.tr('open_entity')),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 40),
                  ),
                  onPressed: () =>
                      Navigator.of(ctx).pop(ConflictResolution.discardMine),
                  child: Text(ctx.tr('discard_my_changes')),
                ),
                PrimaryDialogAction(
                  label: ctx.tr('use_my_changes'),
                  onPressed: () =>
                      Navigator.of(ctx).pop(ConflictResolution.useMine),
                ),
              ],
      );
    },
  );
  return result ?? ConflictResolution.none;
}
