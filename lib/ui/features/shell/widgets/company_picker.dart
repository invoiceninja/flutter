import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/domain/upgrade/upgrade_launcher.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/shell/widgets/company_avatar.dart';
import 'package:admin/ui/features/shell/widgets/confirm_pending_outbox.dart';
import 'package:admin/ui/features/shell/widgets/switch_company_guarded.dart';

/// Overlay content: list of companies, a placeholder "New company" action,
/// and the only Sign out entry in the new shell.
///
/// Used by `showCompanyPicker` — either inside a desktop popup or a mobile
/// modal bottom sheet. Closes itself with `Navigator.of(context).maybePop()`.
class CompanyPicker extends StatefulWidget {
  const CompanyPicker({this.fillWidth = false, super.key});

  /// Modal bottom sheets want the picker to take their full width; the
  /// desktop popup wants a fixed 320 px.
  final bool fillWidth;

  @override
  State<CompanyPicker> createState() => _CompanyPickerState();
}

class _CompanyPickerState extends State<CompanyPicker> {
  final _activeRowKey = GlobalKey();

  /// Company id currently being switched into, or null when idle. Held as an id
  /// rather than a bool so the row the user tapped can show a spinner: the
  /// switch can pause on a healing `/refresh` (see `AuthRepository.switchCompany`),
  /// and a picker that just sits there reads as a hang.
  String? _switchingId;

  /// True while any picker action is in flight — switching, adding, or signing
  /// out. Gates every row so a second tap can't race the first.
  bool get _switching => _switchingId != null || _busy;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Scroll the active company into view once the list is laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _activeRowKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 120),
          alignment: 0.5,
        );
      }
    });
  }

  Future<void> _pick(AuthCompany c, AuthSession session) async {
    if (_switching) return;
    if (c.id == session.currentCompanyId) {
      unawaited(Navigator.of(context).maybePop());
      return;
    }
    // Capture everything context-derived *before* the await, so nothing past
    // it touches `context` (also what keeps `use_build_context_synchronously`
    // quiet). `companySafeLocation` strips an entity-id path back to its list
    // root (`/clients/<old-id>/edit` -> `/clients`) and passes every other
    // route through unchanged, so the user stays on the same logical page in
    // the new company. The shell's KeyedSubtree handles the same-route
    // refresh. `maybeOf` because widget tests pump the picker without a
    // router.
    final services = context.read<Services>();
    final router = GoRouter.maybeOf(context);
    final currentLocation =
        router?.routerDelegate.currentConfiguration.uri.toString() ??
        '/clients';
    final routePaths = services.entityRegistry.uiRoutePaths;
    final nav = Navigator.of(context);
    // Hold the picker open until the switch resolves, rather than dismissing
    // first. The happy path is local — session + credentials + one keychain
    // write — so the dismiss still looks immediate. But a switch into a
    // company whose token is missing pauses on a healing `/refresh`, and
    // dismissing up front left the user staring at an unchanged shell for the
    // length of a full sync before an error toast finally arrived. The tapped
    // row shows a spinner for that window.
    final outcome = await switchCompanyGuarded(
      context,
      c.id,
      companyName: c.displayName,
      // Clear before popping so a picker that can't pop (pumped inline rather
      // than routed) doesn't latch every row, New company and Sign out
      // disabled with no way back.
      onSwitchStart: () {
        if (mounted) setState(() => _switchingId = c.id);
      },
      onSwitchEnd: () {
        if (mounted) setState(() => _switchingId = null);
      },
    );
    // Cancelled at the unsaved-changes or pending-outbox guard: the picker
    // stays open and the user stays put.
    if (outcome == null) return;
    // Only pop what is still ours. Deferring the dismiss means the route can
    // disappear underneath us — a 401 during the healing refresh logs out and
    // the router replaces the stack — and popping a captured NavigatorState
    // then would take a route off the /login stack instead. The toast raised
    // inside `switchCompanyGuarded` still fires either way.
    if (mounted) unawaited(nav.maybePop());
    if (outcome == SwitchCompanyResult.ok) {
      router?.go(companySafeLocation(currentLocation, routePaths));
    }
  }

  Future<void> _handleNewCompany(AuthSession session) async {
    if (_switching) return;

    // Capture every context-derived dependency BEFORE any await so we can
    // safely use them after async gaps without tripping
    // `use_build_context_synchronously`. The mounted checks below guard
    // BuildContext usage (e.g. confirmPendingOutboxIfAny).
    final services = context.read<Services>();
    final loc = Localization.of(context);
    String tr(String key) => loc?.lookup(key) ?? key;
    final navState = Navigator.of(context, rootNavigator: true);
    // The picker pops itself at step 3 below, so whether this State outlives
    // the `addCompany` round-trip is a race between the pop animation and the
    // network. Don't depend on it: capture the toast queue up front (the
    // documented `Notify.capture` seam — the queue is global and outlives any
    // context) so the error can't go unreported on the slow-network ordering.
    final toasts = Notify.capture(context);
    final router = GoRouter.maybeOf(context);

    // 1. Confirm the action in-place. The picker stays open — cancelling
    //    should leave the user where they were.
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
    if (confirmed != true || !mounted) return;

    // 2a. Confirm in-memory unsaved edits first — they're more recent than
    //     anything in the outbox and would be silently lost on the swap.
    if (!await services.unsavedChangesGuard.confirmIfDirty(context)) return;
    if (!mounted) return;

    // 2b. Quiesce the outbox for the currently-active company so an unsynced
    //     edit isn't silently abandoned when we swap into the new company.
    final outbox = await confirmPendingOutboxIfAny(
      context,
      companyId: session.currentCompanyId,
    );
    if (outbox == OutboxConfirmResult.cancelled || !mounted) return;

    // 3. Pop the picker and show a barrier-locked busy dialog. A snackbar
    //    would auto-dismiss before the POST + refresh + Drift wipe complete
    //    and would be hidden by the company switch anyway.
    setState(() => _busy = true);
    unawaited(Navigator.of(context).maybePop());
    unawaited(
      showDialog<void>(
        context: navState.context,
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
      // Dismiss the busy dialog regardless of outcome.
      navState.pop();
    }

    if (error == null) {
      // Land the user on Company Details so they can immediately name and
      // configure the brand-new company instead of staring at an empty
      // dashboard. The shell's top bar already reflects the new company,
      // so no success snackbar is necessary.
      router?.go('/settings/company_details');
    } else {
      toasts?.error(
        _addCompanyErrorMessage(error, tr),
        // Retry re-enters a flow that opens dialogs on this State's context,
        // so it only works while the picker is still mounted — which, after the
        // pop above, it usually isn't. Decide now rather than offering a button
        // that does nothing when pressed.
        action: mounted
            ? NotifyAction(tr('retry'), () {
                if (mounted) _handleNewCompany(session);
              })
            : null,
      );
    }

    if (mounted) setState(() => _busy = false);
  }

  Future<void> _signOut(AuthSession session) async {
    if (_switching) return;
    final guard = context.read<Services>().unsavedChangesGuard;
    if (!await guard.confirmIfDirty(context)) return;
    if (!mounted) return;
    final result = await confirmPendingOutboxIfAny(
      context,
      companyId: session.currentCompanyId,
      // Full logout wipes every company's rows — check them all.
      checkAllCompanies: true,
    );
    if (result == OutboxConfirmResult.cancelled || !mounted) return;
    setState(() => _busy = true);
    await context.read<Services>().auth.logout();
    // Router redirects to /login. Close the picker overlay first so it
    // doesn't sit over the login screen.
    if (mounted) {
      setState(() => _busy = false);
      unawaited(Navigator.of(context).maybePop());
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final auth = context.read<Services>().auth;
    return ValueListenableBuilder<AuthSession?>(
      valueListenable: auth.session,
      builder: (context, session, _) {
        if (session == null) return const SizedBox.shrink();
        final companies = session.companies;
        final width = widget.fillWidth ? double.infinity : 320.0;
        return Material(
          color: Colors.transparent,
          child: Container(
            width: width,
            constraints: const BoxConstraints(maxHeight: 520),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(InRadii.r3),
              boxShadow: widget.fillWidth ? null : tokens.shadow2,
              border: Border.all(color: tokens.border),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: companies.isEmpty
                      ? const _EmptyState()
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: companies.length,
                          itemBuilder: (context, i) {
                            final c = companies[i];
                            final isActive = c.id == session.currentCompanyId;
                            return _CompanyRow(
                              key: isActive ? _activeRowKey : null,
                              company: c,
                              isActive: isActive,
                              isSwitching: _switchingId == c.id,
                              onTap: _switching
                                  ? null
                                  : () => _pick(c, session),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 6),
                Divider(height: 1, color: tokens.border),
                const SizedBox(height: 6),
                Builder(
                  builder: (rowCtx) {
                    final reason = session.canAddCompany;
                    // The plan-limit case is not a dead end: make the row
                    // tappable and route it to the upgrade flow instead of
                    // greying it out with no recourse.
                    final isPlanLimit =
                        reason == CanAddCompanyResult.hostedPlanLimit;
                    final enabled =
                        (reason == CanAddCompanyResult.ok || isPlanLimit) &&
                        !_switching;
                    final reasonText = _reasonText(rowCtx, reason);
                    return _ActionRow(
                      icon: isPlanLimit ? Icons.lock_outline : Icons.add,
                      label: rowCtx.tr('new_company'),
                      subtitle: reasonText,
                      tooltip: reasonText,
                      enabled: enabled,
                      onTap: isPlanLimit
                          ? () => launchUpgrade(rowCtx)
                          : () => _handleNewCompany(session),
                    );
                  },
                ),
                const SizedBox(height: 6),
                Divider(height: 1, color: tokens.border),
                const SizedBox(height: 6),
                _ActionRow(
                  icon: Icons.logout,
                  label: context.tr('logout'),
                  onTap: _switching ? null : () => _signOut(session),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String? _reasonText(BuildContext context, CanAddCompanyResult reason) {
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

/// Translate the various API exception types into a single user-facing
/// snackbar string. Avoids leaking `DioException`/`ServerException` types.
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

class _CompanyRow extends StatelessWidget {
  const _CompanyRow({
    required this.company,
    required this.isActive,
    required this.onTap,
    this.isSwitching = false,
    super.key,
  });

  final AuthCompany company;
  final bool isActive;

  /// The switch into this company is in flight. Swaps the trailing slot for a
  /// spinner — the switch can pause on a healing `/refresh`, and without it the
  /// picker looks frozen.
  final bool isSwitching;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final displayName = company.displayName;
    // Long names truncate with an ellipsis; reveal the full name on hover.
    // Threshold mirrors kCompanyNameTooltipThreshold in company_switcher_button.
    final nameText = Text(
      displayName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: tokens.ink,
      ),
    );
    return Material(
      color: isActive ? tokens.accentSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(InRadii.r2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(InRadii.r2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              CompanyAvatar(
                name: company.displayName,
                seed: company.id,
                size: 28,
                logoUrl: company.logoUrl,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    displayName.length > 22
                        ? Tooltip(message: displayName, child: nameText)
                        : nameText,
                    if (isActive)
                      Text(
                        context.tr('active'),
                        style: TextStyle(fontSize: 11, color: tokens.ink3),
                      ),
                  ],
                ),
              ),
              if (isSwitching)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: tokens.accent,
                  ),
                )
              else if (isActive)
                Icon(Icons.check, size: 16, color: tokens.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// Optional secondary line below the label — used to surface the reason a
  /// disabled row is disabled (e.g. "Only the account owner can add
  /// companies"). On mobile, tooltips don't fire on disabled `InkWell`s, so
  /// this is the only way the reason reaches the user there.
  final String? subtitle;

  /// When false, dims the row, blocks taps, and shows a "forbidden" cursor on
  /// desktop. `onTap` is ignored regardless of its value.
  final bool enabled;

  /// Desktop hover hint. Mobile users see the [subtitle] inline instead.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final effectiveOnTap = enabled ? onTap : null;
    final foreground = enabled ? tokens.ink2 : tokens.ink3;
    final iconColor = enabled ? tokens.ink3 : tokens.ink3.withValues(alpha: .5);

    final row = Padding(
      // Bumped to ~48px tap target for accessibility (was 14px icon + 14px
      // padding ≈ 28px tall). `InSpacing` is brightness-independent.
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 13, color: foreground),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: TextStyle(fontSize: 11, color: tokens.ink3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    final ink = InkWell(
      onTap: effectiveOnTap,
      borderRadius: BorderRadius.circular(InRadii.r2),
      child: row,
    );

    Widget child = Semantics(
      button: true,
      enabled: enabled,
      label: label,
      hint: subtitle,
      child: MouseRegion(
        cursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.forbidden,
        child: ink,
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      child = Tooltip(message: tooltip!, child: child);
    }

    return child;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Text(
        context.tr('no_companies'),
        style: TextStyle(fontSize: 12.5, color: tokens.ink3),
      ),
    );
  }
}
