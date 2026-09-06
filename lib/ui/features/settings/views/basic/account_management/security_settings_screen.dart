import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/dialogs/confirm_sign_out_dialog.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/settings/views/basic/account_management/company_settings_gate.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';
import 'package:admin/ui/features/shell/widgets/confirm_pending_outbox.dart';

/// Timeout options in milliseconds. Mirrors admin-portal `account_management.dart`.
/// Sorted by ascending duration; `0` = never, sentinel.
class _TimeoutOption {
  const _TimeoutOption({required this.ms, required this.label});
  final int ms;
  final String label;
}

List<_TimeoutOption> _timeoutOptions(BuildContext context) {
  String mins(int v) =>
      context.tr('count_minutes').replaceAll(':count', v.toString());
  String hours(int v) =>
      context.tr('count_hours').replaceAll(':count', v.toString());
  String days(int v) =>
      context.tr('count_days').replaceAll(':count', v.toString());
  return [
    _TimeoutOption(ms: 1000 * 60 * 30, label: mins(30)),
    _TimeoutOption(ms: 1000 * 60 * 60 * 2, label: hours(2)),
    _TimeoutOption(ms: 1000 * 60 * 60 * 8, label: hours(8)),
    _TimeoutOption(ms: 1000 * 60 * 60 * 24, label: context.tr('count_day')),
    _TimeoutOption(ms: 1000 * 60 * 60 * 24 * 7, label: days(7)),
    _TimeoutOption(ms: 1000 * 60 * 60 * 24 * 30, label: days(30)),
    _TimeoutOption(ms: 0, label: context.tr('never')),
  ];
}

/// Snap an arbitrary stored value to the closest option so the dropdown
/// never lands on a value not in the list (Material throws an assertion in
/// that case). The server-side value is preserved on the company until the
/// user picks a different option.
int _snapToOption(int stored, List<_TimeoutOption> opts) {
  for (final o in opts) {
    if (o.ms == stored) return o.ms;
  }
  return 0; // fall back to "Never" rather than throwing.
}

class AccountManagementSecuritySettingsScreen extends StatefulWidget {
  const AccountManagementSecuritySettingsScreen({super.key});

  @override
  State<AccountManagementSecuritySettingsScreen> createState() =>
      _AccountManagementSecuritySettingsScreenState();
}

class _AccountManagementSecuritySettingsScreenState
    extends State<AccountManagementSecuritySettingsScreen> {
  bool _endingSessions = false;

  @override
  void initState() {
    super.initState();
    // Pull the canonical company from GET /companies/{id} before the user can
    // edit anything. The login envelope omits the SMTP / expense / task-
    // invoicing / enable_applying_payments / convert_*_currency columns, so the
    // cached row carries table defaults for them; saving a timeout dropdown
    // PUTs draft.toApiJson() (all top-level fillable fields) and would clobber
    // the server's real values. Mirrors the DraftStreamHost.load -> kickRefresh
    // mount refresh every VM-backed cascade settings page already does, and
    // system_logs_screen.dart's post-frame mount refresh. Errors are swallowed
    // inside refresh() (logged only); the page still renders from the cache.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final services = context.read<Services>();
      final companyId = services.auth.session.value?.currentCompanyId;
      if (companyId == null || companyId.isEmpty) return;
      services.company.refresh(companyId);
    });
  }

  Future<void> _onEndAllSessions() async {
    final services = context.read<Services>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final successMsg = context.tr('ended_all_sessions');
    final errorMsg = context.tr('error_refresh_page');
    // Confirm FIRST, before either guard: `confirmIfDirty` resets every dirty
    // editor on Discard and `confirmPendingOutboxIfAny` flushes when online,
    // so asking second means a Cancel has already done both.
    //
    // Its own copy, not the sign-out default: verified against the server,
    // `LogoutController::index` rotates every `is_system` token on the
    // *company*, so this signs out every user of it on all their devices —
    // a wider blast radius than the verb suggests. Unconditional, like every
    // other sign-out prompt; `showConfirmActionDialog` would be wrong here
    // because its non-item callers all gate on the Confirm-actions
    // preference, which must not be able to disable this.
    if (!await showConfirmSignOutDialog(
      context,
      title: context.tr('end_all_sessions'),
      message: context.tr('end_all_sessions_warning'),
      destructive: true,
    )) {
      return;
    }
    if (!mounted) return;
    // endAllSessions() rotates every token server-side BEFORE the local
    // logout wipes Drift — once that POST lands, pending outbox rows can
    // never be synced. Quiesce unsaved edits and the outbox first (CLAUDE.md:
    // logout with pending rows must prompt, never silently drop user data).
    if (!await services.unsavedChangesGuard.confirmIfDirty(context)) {
      return;
    }
    if (!mounted) return;
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId != null && companyId.isNotEmpty) {
      final outbox = await confirmPendingOutboxIfAny(
        context,
        companyId: companyId,
        // The token rotation + wipe hits every company — check them all.
        checkAllCompanies: true,
      );
      if (outbox == OutboxConfirmResult.cancelled || !mounted) return;
    }
    setState(() => _endingSessions = true);
    try {
      // Matches React: POST /api/v1/logout with no password gate. The server
      // rotates every token on the account (ending all sessions); we then run
      // the local logout so this device drops to /login.
      await services.auth.endAllSessions();
      if (!mounted) return;
      Notify.success(context, successMsg, messenger: messenger);
      // Brief delay so the snackbar paints before the forced redirect to
      // /login (logout() flips credentials, which the router watches).
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      Notify.error(context, errorMsg, error: e, messenger: messenger);
    } finally {
      if (mounted) setState(() => _endingSessions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return CompanySettingsGate(
      companyId: companyId,
      builder: (context, ready) => StreamBuilder<Company?>(
        stream: services.company.watchCompany(companyId),
        builder: (context, snapshot) {
          final company = snapshot.data;
          if (company == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildForm(context, services, company, ready);
        },
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    Services services,
    Company company,
    bool ready,
  ) {
    final opts = _timeoutOptions(context);
    final passwordTimeoutValue = _snapToOption(
      company.defaultPasswordTimeout,
      opts,
    );
    final sessionTimeoutValue = _snapToOption(company.sessionTimeout, opts);

    Future<void> applyAndSave(Company draft) async {
      try {
        await services.company.updateCompany(draft: draft);
      } catch (e) {
        if (!context.mounted) return;
        Notify.error(context, context.tr('error_refresh_page'), error: e);
      }
    }

    return SettingsFormShell(
      sections: [
        // Gated until the canonical company is fetched (see
        // CompanySettingsGate): these controls PUT the whole company, so
        // saving before the local row holds real server state would clobber
        // it. The login/refresh envelope now carries every top-level column,
        // so this is a backstop for a row that was never fetched at all (a
        // company first seen offline), not the routine case it once was.
        if (!ready) const CompanySettingsLockedBanner(),
        FormSection(
          title: context.tr('security_settings'),
          children: [
            DropdownButtonFormField<int>(
              initialValue: passwordTimeoutValue,
              decoration: InputDecoration(
                labelText: context.tr('password_timeout'),
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final o in opts)
                  DropdownMenuItem<int>(value: o.ms, child: Text(o.label)),
              ],
              onChanged: ready
                  ? (v) {
                      if (v == null) return;
                      applyAndSave(company.copyWith(defaultPasswordTimeout: v));
                    }
                  : null,
            ),
            DropdownButtonFormField<int>(
              initialValue: sessionTimeoutValue,
              decoration: InputDecoration(
                labelText: context.tr('web_session_timeout'),
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final o in opts)
                  DropdownMenuItem<int>(value: o.ms, child: Text(o.label)),
              ],
              onChanged: ready
                  ? (v) {
                      if (v == null) return;
                      applyAndSave(company.copyWith(sessionTimeout: v));
                    }
                  : null,
            ),
            // Two-choice field → radio group (CLAUDE.md § Forms), so both
            // options stay visible instead of hiding one behind a tap.
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: InSpacing.sm),
                Text(
                  context.tr('require_password_with_social_login'),
                  style: TextStyle(color: context.inTheme.ink2),
                ),
                // RadioGroup.onChanged is non-nullable (can't disable via
                // null like the dropdowns), so gate it with IgnorePointer +
                // Opacity until the canonical company is fetched.
                IgnorePointer(
                  ignoring: !ready,
                  child: Opacity(
                    opacity: ready ? 1 : 0.5,
                    child: RadioGroup<bool>(
                      groupValue: company.oauthPasswordRequired,
                      onChanged: (v) {
                        if (v == null) return;
                        applyAndSave(
                          company.copyWith(oauthPasswordRequired: v),
                        );
                      },
                      child: Column(
                        children: [
                          RadioListTile<bool>(
                            value: true,
                            title: Text(context.tr('yes')),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                          RadioListTile<bool>(
                            value: false,
                            title: Text(context.tr('no')),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        FormSection(
          title: context.tr('end_all_sessions'),
          children: [
            Text(
              context.tr('end_all_sessions_help'),
              style: TextStyle(color: context.inTheme.ink2),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: Icon(Icons.logout, color: context.inTheme.overdue),
                label: Text(
                  context.tr('end_all_sessions'),
                  style: TextStyle(color: context.inTheme.overdue),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(160, 44),
                  side: BorderSide(color: context.inTheme.overdue),
                ),
                onPressed: _endingSessions ? null : _onEndAllSessions,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
