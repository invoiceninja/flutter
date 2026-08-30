import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/shell/widgets/confirm_pending_outbox.dart';

/// Switch the active company the way the user is entitled to expect: never
/// past an unsaved form, never past unsynced outbox rows, and never silently
/// on failure.
///
/// Extracted from `CompanyPicker._pick` so the deep-link router can't fork it.
/// A link that lands on a record in another company runs the *same* guards a
/// tap in the picker does — CLAUDE.md § Sync makes the pending-outbox prompt
/// non-negotiable, and skipping it would drop user data.
///
/// Returns:
///   * `null` — the user cancelled at one of the two guards. Caller does
///     nothing (they're still in the old company, which is what they chose).
///   * [SwitchCompanyResult.ok] — switched; caller navigates.
///   * anything else — already reported to the user (except `noSession`,
///     which is deliberately silent because a logout is already redirecting
///     to `/login` and the "no token" explanation would be a lie). Caller
///     must not navigate.
///
/// [companyName] is only used for the failure toast; pass the display name
/// when the caller has one. [onSwitchStart] / [onSwitchEnd] bracket the
/// `switchCompany` await itself (not the guards), so a caller can show a
/// spinner for exactly the window that can pause on a healing `/refresh`.
Future<SwitchCompanyResult?> switchCompanyGuarded(
  BuildContext context,
  String companyId, {
  String? companyName,
  VoidCallback? onSwitchStart,
  VoidCallback? onSwitchEnd,
}) async {
  final services = context.read<Services>();
  // Confirm unsaved / unsynced changes while the caller's surface is still up,
  // so these dialogs resolve against a Services-bearing context and a cancel
  // leaves that surface open.
  if (!await services.unsavedChangesGuard.confirmIfDirty(context)) return null;
  if (!context.mounted) return null;
  final currentCompanyId = services.auth.session.value?.currentCompanyId;
  if (currentCompanyId != null) {
    final outbox = await confirmPendingOutboxIfAny(
      context,
      companyId: currentCompanyId,
    );
    if (outbox == OutboxConfirmResult.cancelled || !context.mounted) {
      return null;
    }
  }
  // Capture everything context-derived *before* the await, so nothing past it
  // touches `context` (also what keeps `use_build_context_synchronously`
  // quiet). `Notify.capture` is the documented seam for raising a toast after
  // an await; the queue is global and outlives any context.
  final toasts = Notify.capture(context);
  final loc = Localization.of(context);
  onSwitchStart?.call();
  final SwitchCompanyResult outcome;
  try {
    outcome = await services.auth.switchCompany(companyId);
  } finally {
    onSwitchEnd?.call();
  }
  if (outcome == SwitchCompanyResult.ok) return outcome;
  // A logout raced the switch; the router is already heading to /login and the
  // "no token for that company" explanation below would be a lie.
  if (outcome == SwitchCompanyResult.noSession) return outcome;
  // Navigating on a failed switch would reset the route while leaving the user
  // in the old company — indistinguishable from the app ignoring the tap,
  // which is how issue #16 presented. Stay put and say so.
  toasts?.error(
    loc?.lookup('failed_to_switch_company', {
          'company': companyName ?? loc.lookup('company'),
        }) ??
        'failed_to_switch_company',
    detail: loc?.lookup('failed_to_switch_company_help'),
  );
  return outcome;
}
