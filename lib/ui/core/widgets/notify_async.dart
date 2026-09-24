import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';

/// Runs an async repo mutation and surfaces success / failure via
/// [Notify]. Shared between every per-entity `*Actions.dispatch` so the
/// archive / restore / delete arms don't reinvent the try-catch +
/// `context.mounted` dance per entity.
///
/// Callers pass the resolved success message (so locale + entity-specific
/// strings like `archived_client` stay at the call site). Failures show a
/// generic `could_not_save` snackbar with the formatted error as detail —
/// matching the inline pattern this replaces.
Future<void> runMutationWithNotify(
  BuildContext context,
  Future<void> Function() op, {
  required String successMsg,
  NotifyAction? successAction,
}) async {
  try {
    await op();
    if (!context.mounted) return;
    Notify.success(context, successMsg, action: successAction);
  } catch (e) {
    if (!context.mounted) return;
    // Offer Retry only for transient failures (network / rate-limit / 5xx);
    // re-running the op on a validation / conflict / auth error just re-fails.
    // Retry re-enters this wrapper so a repeated failure shows feedback (and
    // another Retry) rather than silently re-running the op.
    Notify.error(
      context,
      context.tr('could_not_save'),
      error: e,
      retryOp: isTransientError(e)
          ? () => runMutationWithNotify(context, op, successMsg: successMsg)
          : null,
    );
  }
}

/// Like [runMutationWithNotify], but for an outbox-queued *action* that should
/// confirm against the server before claiming success when the user is online
/// (e.g. reactivate-email, where the server can legitimately reject with
/// "Bounce ID not found"). [enqueue] writes the outbox row and returns its id.
///
///   * **online** — awaits the row's terminal outcome. `success` / `timeout`
///     (still draining in the background) → [successMsg]. A real failure shows
///     nothing here: the shell `SyncEventListener` surfaces it (a modal while
///     online), which is why we pass `callerWillDisplayFailure: false` — the
///     row is left "unhandled" so the modal fires instead of being suppressed.
///   * **offline** — shows [successMsg] optimistically; the outbox drains and
///     the shell reports any failure when connectivity returns.
///
/// A throw from [enqueue] itself (a local/enqueue error) surfaces inline.
Future<void> runQueuedActionWithNotify(
  BuildContext context, {
  required Services services,
  required String companyId,
  required Future<int> Function() enqueue,
  required String successMsg,
}) async {
  try {
    final rowId = await enqueue();
    final online = await services.connectivity.isOnline;
    if (!context.mounted) return;
    if (!online) {
      Notify.success(context, successMsg);
      return;
    }
    final outcome = await services.sync.awaitRow(
      rowId: rowId,
      companyId: companyId,
      callerWillDisplayFailure: false,
    );
    if (!context.mounted) return;
    switch (outcome.outcome) {
      case SyncRowOutcome.success:
      case SyncRowOutcome.timeout:
        Notify.success(context, successMsg);
      case SyncRowOutcome.serverError:
      case SyncRowOutcome.validationFailed:
        break; // surfaced by the shell SyncEventListener (modal while online)
      case SyncRowOutcome.unconfirmed:
        // This row going unconfirmed is surfaced by the shell like a death.
        // Queued behind an earlier unconfirmed change to the same record, it
        // raised nothing — say why it hasn't gone.
        if (outcome.unconfirmedRowId != rowId) {
          Notify.warning(
            context,
            context.tr('waiting_on_unconfirmed_change'),
            detail: context.tr('may_have_been_sent_help'),
            action: NotifyAction(context.tr('view'), () {
              if (context.mounted) context.go('/sync/outbox');
            }),
          );
        }
    }
  } catch (e) {
    if (!context.mounted) return;
    Notify.error(context, context.tr('could_not_save'), error: e);
  }
}
