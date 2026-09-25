import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// Result of the confirm-before-switch / confirm-before-logout flow.
enum OutboxConfirmResult { proceed, cancelled }

/// CLAUDE.md rule: "Logout / company-switch with pending non-dead outbox
/// rows prompts the user (sync now / discard / cancel). Never silently
/// drops user data." This helper centralises that prompt.
///
/// Returns [OutboxConfirmResult.proceed] when:
///   * there were no pending rows to start with,
///   * the user picked "Sync first" and the flush succeeded,
///   * the user picked "Discard" and the rows were deleted.
/// Returns [OutboxConfirmResult.cancelled] otherwise — including when the
/// flush errors out and the user is sent back to the prompt via a SnackBar.
///
/// [checkAllCompanies] — FULL-logout callers set this: logout wipes the whole
/// DB, so pending rows anywhere count. The company set is derived from the
/// OUTBOX itself (`companiesWithActiveRows`), not `session.companies` — the
/// outbox is the ground truth for unsynced work, callers can't forget to
/// assemble a roster, and a company that vanished from the session envelope
/// still counts. Other companies can only be COUNTED and DISCARDED here,
/// never flushed — the drain sends requests under the ACTIVE company's token
/// (per-company tokens; `ApiClient` reads the live credentials), so flushing
/// another company would misroute its mutations. If "Sync first" leaves other
/// companies' rows behind, the flow cancels with a pointer to switch there
/// (or pick Discard). Company-SWITCH callers leave the flag off — switching
/// preserves the DB, so only the outgoing company matters.
Future<OutboxConfirmResult> confirmPendingOutboxIfAny(
  BuildContext context, {
  required String companyId,
  bool checkAllCompanies = false,
}) async {
  final services = context.read<Services>();
  final pending = await _confirmPendingRows(
    context,
    companyId: companyId,
    checkAllCompanies: checkAllCompanies,
  );
  if (pending == _PendingChoice.cancelled) return OutboxConfirmResult.cancelled;
  // Rows chosen for discard wait for the review below, and nothing drains
  // meanwhile: a reconnect's drain sent what the user had just discarded.
  // Always released — a caller may proceed and then fail to sign out.
  final holdDrains = checkAllCompanies && pending == _PendingChoice.discard;
  if (holdDrains) services.sync.holdDrains();
  final OutboxConfirmResult result;
  try {
    result = context.mounted
        ? await _reviewThenDiscard(
            context,
            services,
            companyId: companyId,
            pending: pending,
            checkAllCompanies: checkAllCompanies,
          )
        : OutboxConfirmResult.cancelled;
  } finally {
    if (holdDrains) services.sync.releaseDrains();
  }
  // Kept after all: send them now, as the drains the review held would have.
  if (holdDrains && result != OutboxConfirmResult.proceed) {
    unawaited(services.sync.drainOnce(companyId: companyId));
  }
  return result;
}

Future<OutboxConfirmResult> _reviewThenDiscard(
  BuildContext context,
  Services services, {
  required String companyId,
  required _PendingChoice pending,
  required bool checkAllCompanies,
}) async {
  // A company switch keeps the database, so only a full logout can destroy
  // failed rows — and only it needs to ask about them.
  if (checkAllCompanies) {
    final review = await _confirmFailedRows(context, companyId: companyId);
    if (review != OutboxConfirmResult.proceed) return review;
  }
  // Nothing the user chose to discard goes until every question is answered:
  // it used to go at once, so a Cancel in the review above cancelled the
  // sign-out with those changes already gone.
  if (pending == _PendingChoice.discard) {
    await services.sync.discardPendingFor(companyId);
    if (checkAllCompanies) {
      // Local-only work (discardOutboxRow + dispatcher fan-outs touch Drift,
      // never the network), so it is safe for non-active companies too.
      for (final id in await services.sync.companiesWithActiveRows()) {
        if (id.isNotEmpty && id != companyId) {
          await services.sync.discardPendingFor(id);
        }
      }
    }
  }
  return OutboxConfirmResult.proceed;
}

/// A full logout wipes the rows waiting on the user too: `dead` ones (the
/// changes the server rejected, waiting in the Outbox — and in their dirty
/// local rows, which the edit form reopens onto — for a fix and retry) and
/// `unconfirmed` ones (changes that may already have gone through, waiting
/// for a Check before Resend or Discard). The pending prompt can't cover
/// them — "Sync first" sends neither — so they used to go with no warning at
/// all. Ask separately, with the safe action focused: this dialog exists to
/// catch an accidental sign-out. View cancels the sign-out and opens the
/// Outbox, where each can be dealt with.
Future<OutboxConfirmResult> _confirmFailedRows(
  BuildContext context, {
  required String companyId,
}) async {
  final services = context.read<Services>();
  final int failed;
  try {
    failed = await services.sync.attentionCountEverywhere();
  } catch (e) {
    // Unknowable is not the same as none — refuse rather than wipe blind.
    if (context.mounted) {
      Notify.error(context, context.tr('an_error_occurred'), error: e);
    }
    return OutboxConfirmResult.cancelled;
  }
  if (failed == 0) return OutboxConfirmResult.proceed;
  if (!context.mounted) return OutboxConfirmResult.cancelled;

  final choice = await showDialog<_ReviewChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.tr('unsynced_changes')),
      content: Text(
        ctx.tr(
          failed == 1
              ? 'review_changes_sign_out_body_singular'
              : 'review_changes_sign_out_body_plural',
          {'count': failed.toString()},
        ),
      ),
      actions: [
        OutlinedButton(
          autofocus: true,
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: () => Navigator.of(ctx).pop(_ReviewChoice.cancel),
          child: Text(ctx.tr('cancel')),
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: () => Navigator.of(ctx).pop(_ReviewChoice.view),
          child: Text(ctx.tr('view')),
        ),
        PrimaryDialogAction(
          variant: DialogActionVariant.destructive,
          label: ctx.tr('discard'),
          // Never focused, never advertised — see `showConfirmActionDialog`.
          autofocus: false,
          showEnterHint: false,
          onPressed: () => Navigator.of(ctx).pop(_ReviewChoice.discard),
        ),
      ],
    ),
  );
  if (choice == _ReviewChoice.view && context.mounted) {
    final location = await outboxLocationNeedingAttention(
      services.sync,
      activeCompanyId: companyId,
    );
    if (context.mounted) context.go(location);
  }
  return choice == _ReviewChoice.discard
      ? OutboxConfirmResult.proceed
      : OutboxConfirmResult.cancelled;
}

/// Where the sign-out review's View goes: the active company's Outbox when it
/// holds a change that waits on the user, otherwise the Outbox of the first
/// company that does. The review counts every company, and the Outbox shows
/// one — so it used to open onto nothing to see.
@visibleForTesting
Future<String> outboxLocationNeedingAttention(
  SyncRepository sync, {
  required String activeCompanyId,
}) async {
  const here = '/sync/outbox';
  try {
    final ids = await sync.companiesWithAttentionRows();
    if (ids.isEmpty || ids.contains(activeCompanyId)) return here;
    return Uri(path: here, queryParameters: {'company': ids.first}).toString();
  } catch (_) {
    return here;
  }
}

enum _ReviewChoice { cancel, view, discard }

/// What the pending prompt settled on. Discard is the caller's to carry out,
/// once every other question has been answered.
enum _PendingChoice { proceed, cancelled, discard }

/// The pending (non-`dead`) half of [confirmPendingOutboxIfAny] — sync first,
/// discard, or cancel.
Future<_PendingChoice> _confirmPendingRows(
  BuildContext context, {
  required String companyId,
  required bool checkAllCompanies,
}) async {
  final services = context.read<Services>();
  final router = GoRouter.maybeOf(context);
  final others = !checkAllCompanies
      ? const <String>[]
      : [
          for (final id in await services.sync.companiesWithActiveRows())
            if (id.isNotEmpty && id != companyId) id,
        ];
  Future<int> pendingEverywhere() async {
    var total = await services.sync.pendingCountFor(companyId);
    for (final id in others) {
      total += await services.sync.pendingCountFor(id);
    }
    return total;
  }

  var pending = await pendingEverywhere();
  if (pending == 0) return _PendingChoice.proceed;

  // Online happy path: try to drain silently. If everything goes through
  // we skip the dialog entirely — the warning was only useful when we had
  // unsynced changes the user was about to abandon. The drain itself is
  // best-effort; any rows left behind (offline, 422 marked dead, conflict
  // parked) fall through to the dialog so the user still gets a chance
  // to cancel / discard before leaving the company.
  if (await services.connectivity.isOnline) {
    try {
      await services.sync.flushNow(companyId: companyId);
    } catch (_) {
      // Fall through to the dialog — the user should see why the implicit
      // flush failed rather than have us silently swallow it.
    }
    pending = await pendingEverywhere();
    if (pending == 0) return _PendingChoice.proceed;
  }

  if (!context.mounted) return _PendingChoice.cancelled;

  final choice = await showDialog<_Choice>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.tr('unsynced_changes')),
      content: Text(
        ctx.tr(
          pending == 1
              ? 'unsynced_changes_body_singular'
              : 'unsynced_changes_body_plural',
          {'count': pending.toString()},
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(_Choice.cancel),
          child: Text(ctx.tr('cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(_Choice.discard),
          child: Text(ctx.tr('discard')),
        ),
        PrimaryDialogAction(
          label: ctx.tr('sync_first_action'),
          onPressed: () => Navigator.of(ctx).pop(_Choice.sync),
        ),
      ],
    ),
  );

  if (choice == null || choice == _Choice.cancel) {
    return _PendingChoice.cancelled;
  }
  if (choice == _Choice.discard) return _PendingChoice.discard;

  // Sync first. Drain in a bounded loop rather than a single pass: an
  // offline-created parent + its dependent sync over CONSECUTIVE passes
  // (pass 1 dispatches the parent and re-arms the dependent — see
  // `OutboxDao.rewriteTempIdInPayloads` — pass 2 dispatches the dependent),
  // so a single `flushNow` + count check would cancel logout on a chain
  // that's actually healthy. Loop while the pending count keeps dropping;
  // stop as soon as a pass makes no progress (genuinely stuck: offline
  // backoff, conflict- or password-parked, or dead-referencing).
  var remaining = await services.sync.pendingCountFor(companyId);
  const maxPasses = 10; // backstop; real chains are 2-3 deep
  for (var pass = 0; pass < maxPasses && remaining > 0; pass++) {
    try {
      await services.sync.flushNow(companyId: companyId);
    } catch (e) {
      if (context.mounted) {
        Notify.error(context, context.tr('sync_failed'), error: e);
      }
      return _PendingChoice.cancelled;
    }
    final next = await services.sync.pendingCountFor(companyId);
    if (next == 0) break; // current company drained
    if (next >= remaining) break; // no progress this pass → stalled
    remaining = next;
  }
  // Rows still pending after the loop couldn't be sent — the current
  // company's are stalled (offline, parked, or referencing a failed record),
  // and other companies' can't be flushed from here at all (wrong token).
  // Proceeding would let the post-logout Drift wipe destroy them even though
  // the user asked to sync, so cancel: they can retry, resolve, switch to the
  // other company and sync, or come back and pick "Discard". Dead rows don't
  // count here — they're terminal and surfaced on the Outbox screen. When the
  // ACTIVE company drained fine and only another company holds rows, a bare
  // "Sync failed" is misleading — point at the actual recourse instead.
  final currentLeft = await services.sync.pendingCountFor(companyId);
  var othersLeft = 0;
  for (final id in others) {
    othersLeft += await services.sync.pendingCountFor(id);
  }
  if (currentLeft + othersLeft > 0) {
    // What is left may be waiting on another change — held behind one that
    // may already have gone through, or on a record that has not synced — and
    // no drain sends it until the user deals with that change. Say so, and
    // where, rather than a bare "Sync failed" every time.
    final waiting = currentLeft == 0
        ? 0
        : await services.sync.pendingWaitingOnAnotherCount(companyId);
    if (context.mounted) {
      final view = router == null || currentLeft == 0
          ? null
          : NotifyAction(context.tr('view'), () => router.go('/sync/outbox'));
      if (waiting > 0 && waiting == currentLeft) {
        Notify.warning(
          context,
          context.tr('sync_first_waiting_on_another_change'),
          action: view,
        );
      } else {
        Notify.error(
          context,
          context.tr(
            currentLeft == 0 ? 'unsynced_changes_other_company' : 'sync_failed',
          ),
          action: view,
        );
      }
    }
    return _PendingChoice.cancelled;
  }
  return _PendingChoice.proceed;
}

enum _Choice { cancel, discard, sync }
