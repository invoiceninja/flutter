import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/resync_controller.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/shell/widgets/confirm_pending_outbox.dart';

/// Shared user-flow helpers for settings screens. Keeps the confirmation
/// dialogs / error toasts consistent across the surfaces that expose them —
/// currently sign-out (`User Details`) and sync (`Account Management →
/// Overview`, `Device Settings → Data`, and the sidebar header's Sync button).
/// They're called from places that otherwise have no shared state, so static
/// methods rather than a ChangeNotifier are the right shape. (The one piece of
/// state force-resync *does* need — is a pass already running? — lives on
/// `Services.resync`, not here.)
class SettingsActions {
  SettingsActions._();

  /// Show the sign-out confirmation dialog; if the user confirms, wipe the
  /// session (Drift + secure storage). Caller surfaces the loading state.
  ///
  /// Returns `true` when the user confirmed and the logout completed.
  static Future<bool> signOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('sign_out_question')),
        content: Text(ctx.tr('sign_out_warning')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.tr('cancel')),
          ),
          PrimaryDialogAction(
            variant: DialogActionVariant.tonal,
            label: ctx.tr('sign_out'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return false;
    final services = context.read<Services>();
    // Warn about unsaved in-memory edits before wiping the session — mirrors
    // the company picker's sign-out guard. No-op (returns true) when nothing
    // is dirty.
    if (!await services.unsavedChangesGuard.confirmIfDirty(context)) {
      return false;
    }
    if (!context.mounted) return false;
    // Then quiesce the outbox so an unsynced offline edit isn't silently
    // dropped on logout — same guard the company picker applies. (logout()
    // settles in-flight requests but does NOT drain still-pending rows before
    // the Drift wipe, so without this they're lost.) Full logout wipes EVERY
    // company's rows, so the guard checks all of them (outbox-derived).
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId != null) {
      final outbox = await confirmPendingOutboxIfAny(
        context,
        companyId: companyId,
        checkAllCompanies: true,
      );
      if (outbox == OutboxConfirmResult.cancelled || !context.mounted) {
        return false;
      }
    }
    await services.auth.logout();
    return true;
  }

  /// Push queued offline edits, then re-download all data for the active
  /// company (see [Services.syncNow]). Backs all three entry points: the
  /// sidebar header's Sync button, the Device Settings "Sync" action, and the
  /// Account Management overview's "Force full sync" recovery path.
  /// Non-destructive to unsynced offline edits.
  ///
  /// One action, one vocabulary: every surface reports the same
  /// `sync_complete` / `sync_failed` outcome, so the toast doesn't depend on
  /// which button the user happened to press. Before issue #15 the same pass
  /// toasted "Download complete" from Device Settings and "Resync complete"
  /// from the overview (whose tile read "Force full resync").
  ///
  /// Routed through [Services.resync], so a second call while a pass is running
  /// joins it rather than starting a competing one — and only the call that
  /// *started* the pass reports the outcome, so one user action means one toast.
  ///
  /// Caller surfaces the in-flight state from `services.resync`; `await`ing
  /// this returns when the work is done.
  static Future<void> forceResync(BuildContext context) async {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) return;
    // Resolve the toast queue and every string BEFORE the first await. The pass
    // runs for tens of seconds and the surface that started it (a sidebar
    // button, a settings card) is routinely gone by the time it lands — the
    // toast host is global and outlives any context, so the result still shows.
    final toasts = Notify.capture(context);
    final success = context.tr('sync_complete');
    final failure = context.tr('sync_failed');
    final busy = context.tr('sync_in_progress');

    final result = await services.resync.run(companyId);
    switch (result.disposition) {
      case ResyncDisposition.busy:
        toasts?.info(busy);
      case ResyncDisposition.joined:
      case ResyncDisposition.cancelled:
        // The call that started the pass owns the toast; a cancelled pass was
        // cut short by logout, where a toast would be noise.
        break;
      case ResyncDisposition.completed:
        final error = result.error;
        if (result.isClean) {
          toasts?.success(success);
        } else {
          // Some entities landed, some didn't — report failure rather than a
          // misleading "complete" (the auth refresh + the rest still applied).
          toasts?.error(
            failure,
            detail: error == null ? null : formatNotifyError(error),
          );
        }
    }
  }
}
