import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/resync_controller.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/auth_repository.dart'
    show CompanyCreatedNotActivatedException;
import 'package:admin/data/repositories/auth/auth_session.dart'
    show CanAddCompanyResult;
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/dialogs/confirm_sign_out_dialog.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/shell/widgets/confirm_pending_outbox.dart';

/// Shared user-flow helpers for settings screens. Keeps the confirmation
/// dialogs / error toasts consistent across the surfaces that expose them —
/// currently sign-out (shared by every surface that offers it — the company
/// picker, `User Details`), sync (`Account Management → Overview`,
/// `Device Settings → Data`, and the sidebar's Sync button), and add-company
/// (`Account Management → Overview` and the `CompanyPicker` sheet).
/// They're called from places that otherwise have no shared state, so static
/// methods rather than a ChangeNotifier are the right shape. (The one piece of
/// state force-resync *does* need — is a pass already running? — lives on
/// `Services.resync`, not here.)
class SettingsActions {
  SettingsActions._();

  /// Show the sign-out confirmation dialog; if the user confirms, wipe the
  /// session (Drift + secure storage). Caller surfaces the loading state.
  ///
  /// **The confirm runs first, before both guards, and that order is
  /// load-bearing**: each guard has a side effect that fires before it renders
  /// anything. `confirmIfDirty` invokes every dirty editor's `onDiscard` once
  /// the user picks Discard, and `confirmPendingOutboxIfAny` calls `flushNow`
  /// unconditionally when online. Ask second and a user who then taps Cancel
  /// has already had their drafts reset and their queued mutations sent.
  ///
  /// [onStart] fires once every guard has passed and immediately before the
  /// logout — the User Details button uses it to raise its spinner, so the
  /// spinner means "signing out", not "deciding whether to". Unlike
  /// [addCompany]'s callback of the same name, [context] stays valid after it:
  /// nothing here pops.
  ///
  /// Returns `true` when the user confirmed and the logout completed.
  static Future<bool> signOut(
    BuildContext context, {
    VoidCallback? onStart,
  }) async {
    final services = context.read<Services>();
    // Names the account, not the company: sign-out is account-wide (hence
    // `checkAllCompanies: true` below), and the picker this is most often
    // launched from is an account menu that never otherwise says whose it is.
    final confirmed = await showConfirmSignOutDialog(
      context,
      subject: services.auth.session.value?.userEmail,
    );
    if (!confirmed || !context.mounted) return false;
    // Warn about unsaved in-memory edits before wiping the session. No-op
    // (returns true) when nothing is dirty.
    if (!await services.unsavedChangesGuard.confirmIfDirty(context)) {
      return false;
    }
    if (!context.mounted) return false;
    // Then quiesce the outbox so an unsynced offline edit isn't silently
    // dropped on logout. (logout() settles in-flight requests but does NOT
    // drain still-pending rows before the Drift wipe, so without this they're
    // lost.) Full logout wipes EVERY company's rows, so the guard checks all
    // of them (outbox-derived).
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
    onStart?.call();
    await services.auth.logout();
    return true;
  }

  /// Confirm and create a new company, then land the user on Company Details.
  ///
  /// Two entry points, and the second is why this lives here rather than inside
  /// `CompanyPicker`: the picker's "New company" row used to be the **only**
  /// route to `auth.addCompany()` in the whole app, which made a hidden picker
  /// a hard dead end for a one-company owner (issue #104 moved that picker's
  /// entry point into the drawer footer, where it is a 24-px unlabelled icon).
  /// Settings → Account Management now offers the same flow, and it is
  /// searchable there.
  ///
  /// The guards are not optional decoration. In order: confirm, then
  /// `unsavedChangesGuard` (in-memory edits are more recent than anything in
  /// the outbox and would be lost on the swap), then `confirmPendingOutboxIfAny`
  /// for the company being left. `addCompany` switches the active company and
  /// wipes Drift, so skipping either silently destroys user data.
  ///
  /// [onStart] fires once every guard has passed and before the barrier-locked
  /// busy dialog goes up — the picker uses it to mark itself busy and pop, so
  /// the dialog isn't stacked on a sheet. **Nothing may touch [context] after
  /// it**; the navigator, router, toast queue and strings are all captured up
  /// front for exactly that reason (a snackbar would auto-dismiss before the
  /// POST + refresh + wipe finish, and is hidden by the company switch anyway).
  static Future<void> addCompany(
    BuildContext context, {
    VoidCallback? onStart,
  }) async {
    final services = context.read<Services>();
    final loc = Localization.of(context);
    String tr(String key) => loc?.lookup(key) ?? key;
    final navState = Navigator.of(context, rootNavigator: true);
    // Captured, not read later: the surface that started this is routinely gone
    // by the time the round-trip lands. `Notify.capture` is the documented seam
    // — the queue is global and outlives any context.
    final toasts = Notify.capture(context);
    final router = GoRouter.maybeOf(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('add_company')),
        content: Text(ctx.tr('add_company_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.tr('cancel')),
          ),
          PrimaryDialogAction(
            label: ctx.tr('add_company'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    if (!await services.unsavedChangesGuard.confirmIfDirty(context)) return;
    if (!context.mounted) return;

    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId != null) {
      final outbox = await confirmPendingOutboxIfAny(
        context,
        companyId: companyId,
      );
      if (outbox == OutboxConfirmResult.cancelled || !context.mounted) return;
    }

    // Past here `context` may already be gone — see [onStart].
    final retryable = context.mounted;
    onStart?.call();
    // The root navigator's own context, not the caller's: it is what outlives
    // a picker that pops itself. Unmounted here means the app is tearing down,
    // and starting a company create into that is worse than doing nothing.
    final dialogContext = navState.context;
    if (!dialogContext.mounted) return;
    unawaited(
      showDialog<void>(
        context: dialogContext,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                Flexible(child: Text(tr('please_wait'))),
              ],
            ),
          ),
        ),
      ),
    );

    Object? error;
    try {
      await services.auth.addCompany();
    } catch (e) {
      error = e;
    } finally {
      navState.pop();
    }

    if (error == null) {
      // Land on Company Details so the user can name and configure the
      // brand-new company instead of staring at an empty dashboard. The shell
      // already reflects the switch, so no success toast is needed.
      router?.go('/settings/company_details');
      return;
    }
    toasts?.error(
      _addCompanyErrorMessage(error, tr),
      // Retry re-enters a flow that opens dialogs on this context, so only
      // offer it where the caller survived. Decide now rather than shipping a
      // button that does nothing when pressed.
      action: retryable && context.mounted
          ? NotifyAction(tr('retry'), () {
              if (context.mounted) addCompany(context, onStart: onStart);
            })
          : null,
    );
  }

  /// Why [addCompany] is unavailable, or null when it is allowed. Shared by
  /// the two surfaces that offer it so a blocked owner reads the same sentence
  /// in the picker sheet and in Account Management.
  ///
  /// [CanAddCompanyResult.hostedPlanLimit] deliberately gets a *reason* but not
  /// a block: both callers keep that case tappable and route it to
  /// `launchUpgrade`, because "you need a bigger plan" with no way to buy one
  /// is a dead end.
  static String? addCompanyBlockedReason(
    BuildContext context,
    CanAddCompanyResult reason,
  ) {
    switch (reason) {
      case CanAddCompanyResult.ok:
        return null;
      case CanAddCompanyResult.notOwner:
        return context.tr('not_owner_add_company');
      case CanAddCompanyResult.capReached:
        return context.tr('max_companies_reached');
      case CanAddCompanyResult.hostedPlanLimit:
        return context.tr('upgrade_to_add_company');
      case CanAddCompanyResult.demoMode:
        return context.tr('demo_mode_disabled');
    }
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

/// Translate the various API exception types into a single user-facing
/// message. Avoids leaking `DioException`/`ServerException` types.
String _addCompanyErrorMessage(Object error, String Function(String) tr) {
  // Not a failed create — the company exists on the server, we just couldn't
  // activate it. Saying "failed" here would push the user into creating a
  // duplicate.
  if (error is CompanyCreatedNotActivatedException) {
    return tr('company_created_switch_failed');
  }
  if (error is DemoModeException) return tr('demo_mode_disabled');
  if (error is ValidationException) {
    return '${tr('failed_to_add_company')}: ${error.message}';
  }
  if (error is ServerException) {
    return '${tr('failed_to_add_company')}: ${error.message}';
  }
  if (error is NetworkException) {
    return '${tr('failed_to_add_company')}: ${error.message}';
  }
  return tr('failed_to_add_company');
}
