import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/auth_repository.dart'
    show SwitchCompanyResult;
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

const kAccountManagementDangerZoneSearchKeys = <String>[
  'purge_data',
  'delete_company',
  'cancel_account',
];

class AccountManagementDangerZoneScreen extends StatelessWidget {
  const AccountManagementDangerZoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.read<Services>().auth.session;
    return ValueListenableBuilder(
      valueListenable: session,
      builder: (context, value, _) {
        // Demo gate fires before owner gate so a demo build run by a
        // non-owner doesn't leak the owner-only message.
        if (Env.demoMode) {
          return EmptyState(
            icon: Icons.science_outlined,
            title: context.tr('danger_zone'),
            subtitle: context.tr('demo_mode_disabled'),
          );
        }
        final currentCompany = value?.currentCompany;
        if (currentCompany == null || !currentCompany.isOwner) {
          return EmptyState(
            icon: Icons.lock_outline,
            title: context.tr('restricted'),
            subtitle: context.tr('only_owners_can_access'),
          );
        }
        return SettingsFormShell(
          sections: const [
            _ExportDataSection(),
            _PurgeSection(),
            _DeleteSection(),
          ],
        );
      },
    );
  }
}

/// GDPR data export — non-destructive. Reuses the same `/api/v1/export`
/// endpoint the Backup screen drives: the server queues a full company
/// export and emails a download link. No password gate, no outbox (read
/// side-effect only).
class _ExportDataSection extends StatefulWidget {
  const _ExportDataSection();

  @override
  State<_ExportDataSection> createState() => _ExportDataSectionState();
}

class _ExportDataSectionState extends State<_ExportDataSection> {
  bool _busy = false;

  Future<void> _runExport() async {
    final services = context.read<Services>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final fallback = context.tr('exported_data');
    setState(() => _busy = true);
    try {
      final result = await services.apiClient.postJson(
        '/api/v1/export',
        body: const {'send_email': true, 'report_keys': <String>[]},
      );
      String successMsg = fallback;
      if (result is Map && result['message'] is String) {
        final m = result['message'] as String;
        if (m.isNotEmpty) successMsg = m;
      }
      if (!mounted) return;
      Notify.success(context, successMsg, messenger: messenger);
    } on DemoModeException {
      if (!mounted) return;
      Notify.warning(
        context,
        context.tr('demo_mode_disabled'),
        messenger: messenger,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      Notify.error(
        context,
        context.tr('error_title'),
        error: e,
        messenger: messenger,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return FormSection(
      title: context.tr('export_data'),
      children: [
        Text(
          context.tr('export_data_help'),
          style: TextStyle(color: tokens.ink2),
        ),
        SizedBox(height: InSpacing.lg(context)),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: _busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
            label: Text(context.tr('export_data')),
            style: OutlinedButton.styleFrom(minimumSize: const Size(120, 44)),
            onPressed: _busy ? null : _runExport,
          ),
        ),
      ],
    );
  }
}

class _PurgeSection extends StatelessWidget {
  const _PurgeSection();

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return FormSection(
      title: context.tr('purge_data'),
      children: [
        Text(
          context.tr('purge_data_message'),
          style: TextStyle(color: tokens.ink2),
        ),
        SizedBox(height: InSpacing.lg(context)),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: Icon(Icons.delete_sweep_outlined, color: tokens.overdue),
            label: Text(
              context.tr('purge_data'),
              style: TextStyle(color: tokens.overdue),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(120, 44),
              side: BorderSide(color: tokens.overdue),
            ),
            onPressed: () =>
                _openDangerDialog(context, kind: _DangerKind.purge),
          ),
        ),
      ],
    );
  }
}

class _DeleteSection extends StatelessWidget {
  const _DeleteSection();

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final session = context.read<Services>().auth.session;
    return ValueListenableBuilder(
      valueListenable: session,
      builder: (context, value, _) {
        final multi = (value?.companies.length ?? 0) > 1;
        final label = multi
            ? context.tr('delete_company')
            : context.tr('cancel_account');
        final message = multi
            ? context.tr('delete_company_message')
            : context.tr('cancel_account_message');
        return FormSection(
          title: label,
          children: [
            Text(message, style: TextStyle(color: tokens.ink2)),
            SizedBox(height: InSpacing.lg(context)),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: Icon(
                  Icons.delete_forever_outlined,
                  color: tokens.overdue,
                ),
                label: Text(label, style: TextStyle(color: tokens.overdue)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(120, 44),
                  side: BorderSide(color: tokens.overdue),
                ),
                onPressed: () =>
                    _openDangerDialog(context, kind: _DangerKind.delete),
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _DangerKind { purge, delete }

Future<void> _openDangerDialog(
  BuildContext context, {
  required _DangerKind kind,
}) async {
  final services = context.read<Services>();
  final narrow = MediaQuery.sizeOf(context).width < 600;
  if (narrow) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      // viewInsets.bottom lifts the sheet content above the keyboard — the
      // sheet host doesn't do this automatically when isScrollControlled.
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: InSpacing.lg(ctx),
          right: InSpacing.lg(ctx),
          top: InSpacing.lg(ctx),
          bottom: InSpacing.lg(ctx) + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: _DangerDialogBody(
          kind: kind,
          services: services,
          showTitle: true,
        ),
      ),
    );
  } else {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DangerDialogShell(kind: kind, services: services),
    );
  }
}

class _DangerDialogShell extends StatelessWidget {
  const _DangerDialogShell({required this.kind, required this.services});

  final _DangerKind kind;
  final Services services;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_titleFor(context, kind, services)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: _DangerDialogBody(kind: kind, services: services),
      ),
      contentPadding: EdgeInsets.fromLTRB(
        InSpacing.lg(context),
        InSpacing.md(context),
        InSpacing.lg(context),
        0,
      ),
    );
  }
}

class _DangerDialogBody extends StatefulWidget {
  const _DangerDialogBody({
    required this.kind,
    required this.services,
    this.showTitle = false,
  });

  final _DangerKind kind;
  final Services services;

  /// Render the action title at the top of the scroll body. The bottom-sheet
  /// (narrow) path uses this since it has no `AlertDialog` title chrome of its
  /// own; the wide `_DangerDialogShell` supplies the title via
  /// `AlertDialog.title` and leaves this false.
  final bool showTitle;

  @override
  State<_DangerDialogBody> createState() => _DangerDialogBodyState();
}

class _DangerDialogBodyState extends State<_DangerDialogBody> {
  final _confirmCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _feedbackCtrl = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _obscure = true;
  bool _busy = false;
  // Synchronous double-tap guard. `_busy` flips inside `setState` which is
  // microtask-deferred; a second tap before the next frame would otherwise
  // enqueue a second outbox row.
  bool _submitting = false;
  String? _passwordError;
  String? _feedbackError;
  // Non-password failure (409, 5xx, network, corrupt row, …) rendered as a
  // top-of-dialog banner. Reserves the password `errorText` for actual
  // password-specific issues.
  String? _topBannerError;

  String get _expectedConfirm =>
      widget.kind == _DangerKind.purge ? 'purge' : 'delete';

  bool get _canSubmit {
    if (_busy || _submitting) return false;
    if (_confirmCtrl.text.trim().toLowerCase() != _expectedConfirm) {
      return false;
    }
    if (_passwordCtrl.text.isEmpty) return false;
    return true;
  }

  /// Prevent back-gesture / barrier dismiss while the user has typed
  /// anything, and always while busy.
  bool get _canPop =>
      !_busy &&
      !_submitting &&
      _passwordCtrl.text.isEmpty &&
      _feedbackCtrl.text.isEmpty &&
      _confirmCtrl.text.isEmpty;

  @override
  void initState() {
    super.initState();
    _confirmCtrl.addListener(_onConfirmChanged);
    _passwordCtrl.addListener(_onPasswordChanged);
    _feedbackCtrl.addListener(_onFeedbackChanged);
  }

  void _onConfirmChanged() => setState(() {});

  void _onPasswordChanged() {
    if (_passwordError != null) {
      setState(() => _passwordError = null);
    } else {
      setState(() {});
    }
  }

  void _onFeedbackChanged() {
    if (_feedbackError != null) {
      setState(() => _feedbackError = null);
    }
  }

  @override
  void dispose() {
    _confirmCtrl.dispose();
    _passwordCtrl.dispose();
    _feedbackCtrl.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_canSubmit) return;
    setState(() => _submitting = true);
    try {
      await _submitInner();
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      } else {
        _submitting = false;
      }
    }
  }

  Future<void> _submitInner() async {
    final services = widget.services;
    final preSession = services.auth.session.value;
    final companyId = preSession?.currentCompanyId ?? '';
    if (companyId.isEmpty) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final purgeSuccessMsg = context.tr('purge_successful');
    final deleteSuccessMsg = context.tr('deleted_company');
    final pwIncorrectMsg = context.tr('password_error_incorrect');
    final fallbackErrMsg = context.tr('error_title');
    final alreadyDeletedMsg = context.tr('already_deleted_remote');
    final serverDidntRespondMsg = context.tr('server_didnt_respond');
    final isHosted = preSession?.isHosted ?? false;
    final isDelete = widget.kind == _DangerKind.delete;

    setState(() {
      _busy = true;
      _passwordError = null;
      _feedbackError = null;
      _topBannerError = null;
    });

    services.passwordCache.set(_passwordCtrl.text);

    try {
      if (!isDelete) {
        await services.apiClient.postJson(
          '/api/v1/companies/purge_save_settings/$companyId',
          body: {'cancellation_message': _feedbackCtrl.text},
          requiresPassword: true,
        );
        await services.db.wipeForCompany(companyId);
        try {
          // Local per-entity sync cursors were just wiped — force a full
          // snapshot so the purged company re-seeds instead of pulling an
          // empty delta.
          await services.auth.refreshSession(fullSync: true);
        } catch (_) {
          /* non-fatal */
        }
        if (!mounted) return;
        Navigator.of(context).pop();
        Notify.success(context, purgeSuccessMsg, messenger: messenger);
        context.go('/dashboard');
        return;
      }

      // Delete via outbox.
      final rowId = await services.company.deleteCompany(
        companyId: companyId,
        cancellationMessage: isHosted ? _feedbackCtrl.text : '',
      );
      await services.sync.drainOnce(companyId: companyId);
      final terminal = await services.db.outboxDao.byId(rowId);
      if (terminal != null) {
        services.passwordCache.clear();
        if (!mounted) return;
        _surfaceTerminal(
          terminal,
          pwIncorrectMsg: pwIncorrectMsg,
          alreadyDeletedMsg: alreadyDeletedMsg,
          serverDidntRespondMsg: serverDidntRespondMsg,
          fallbackErrMsg: fallbackErrMsg,
          messenger: messenger,
        );
        return;
      }

      // Row cleared → success. Re-read session AFTER the drain in case a
      // background `/refresh` updated `companies` mid-call.
      final postSession = services.auth.session.value;
      final remaining = (postSession?.companies ?? const [])
          .where((c) => c.id != companyId)
          .toList();
      try {
        await services.db.wipeForCompany(companyId);
      } catch (_) {
        /* non-fatal */
      }
      // A failed switch leaves the session pointed at the company we just
      // deleted and wiped, with no way back — fall through to the sign-out
      // branch so the user lands somewhere coherent instead of a dead shell.
      final switched =
          remaining.isNotEmpty &&
          (await services.auth.switchCompany(remaining.first.id)) ==
              SwitchCompanyResult.ok;
      if (switched) {
        try {
          // A company was just deleted + wiped locally; force a full
          // snapshot so the switched-to company's state is authoritative.
          await services.auth.refreshSession(fullSync: true);
        } catch (_) {
          /* non-fatal */
        }
        if (!mounted) return;
        Navigator.of(context).pop();
        Notify.success(context, deleteSuccessMsg, messenger: messenger);
        context.go('/dashboard');
      } else {
        await services.auth.logout();
        if (!mounted) return;
        Navigator.of(context).pop();
        context.go('/login');
      }
    } on PasswordRequiredException {
      _surface412(pwIncorrectMsg);
    } on ServerException catch (e) {
      services.passwordCache.clear();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _topBannerError = fallbackErrMsg;
      });
      Notify.error(context, fallbackErrMsg, error: e, messenger: messenger);
    } on ValidationException catch (e) {
      services.passwordCache.clear();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _feedbackError = e.fieldErrors['cancellation_message']?.firstOrNull;
        _passwordError = e.fieldErrors['password']?.firstOrNull;
        if (_feedbackError == null && _passwordError == null) {
          _topBannerError = e.message.isNotEmpty ? e.message : fallbackErrMsg;
        }
      });
    } on ApiException catch (e) {
      services.passwordCache.clear();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _topBannerError = fallbackErrMsg;
      });
      Notify.error(context, fallbackErrMsg, error: e, messenger: messenger);
    }
  }

  /// Map the terminal outbox row state into the right error slot.
  ///
  /// Password failures (403 / 412) → `_passwordError` + clear + refocus.
  /// Validation field errors (422 with recognised keys) → field `errorText`.
  /// Everything else (409 / 5xx / 429 / network / corrupt row / unknown) →
  /// `_topBannerError` so the password slot isn't misused.
  void _surfaceTerminal(
    OutboxRow terminal, {
    required String pwIncorrectMsg,
    required String alreadyDeletedMsg,
    required String serverDidntRespondMsg,
    required String fallbackErrMsg,
    required ScaffoldMessengerState? messenger,
  }) {
    final code = terminal.lastStatusCode;
    if (code == 403 || code == 412) {
      _surface412(pwIncorrectMsg);
      return;
    }
    // 422 — field errors. Only route to a specific field when the server
    // names one we render; otherwise treat as a top-of-dialog message so
    // the user isn't blamed for the wrong slot (e.g. "payload could not be
    // decoded" never belongs under the password field).
    if (terminal.fieldErrorsJson != null) {
      try {
        final errs =
            jsonDecode(terminal.fieldErrorsJson!) as Map<String, dynamic>;
        final pwErr = (errs['password'] as List?)?.cast<String>().firstOrNull;
        final fbErr = (errs['cancellation_message'] as List?)
            ?.cast<String>()
            .firstOrNull;
        if (pwErr != null || fbErr != null) {
          setState(() {
            _busy = false;
            _passwordError = pwErr;
            _feedbackError = fbErr;
          });
          return;
        }
        // Unknown field key — show the message at the top.
        final firstMsg = errs.values
            .whereType<List<dynamic>>()
            .map((v) => v.cast<String>())
            .where((v) => v.isNotEmpty)
            .map((v) => v.first)
            .firstOrNull;
        setState(() {
          _busy = false;
          _topBannerError = firstMsg ?? terminal.lastError ?? fallbackErrMsg;
        });
        return;
      } catch (_) {
        /* fall through to status-code branch */
      }
    }
    switch (code) {
      case 401:
        // Sync engine already routed this through onUnauthorized → /login.
        // Pop the dialog so the redirect lands on a clean route.
        Navigator.of(context).pop();
        Notify.warning(context, fallbackErrMsg, messenger: messenger);
        return;
      case 409:
        setState(() {
          _busy = false;
          _topBannerError = alreadyDeletedMsg;
        });
        return;
      case null:
        setState(() {
          _busy = false;
          _topBannerError = serverDidntRespondMsg;
        });
        return;
      default:
        if (code >= 500 || code == 429) {
          setState(() {
            _busy = false;
            _topBannerError = serverDidntRespondMsg;
          });
        } else {
          setState(() {
            _busy = false;
            _topBannerError = terminal.lastError?.isNotEmpty == true
                ? terminal.lastError
                : fallbackErrMsg;
          });
        }
    }
  }

  void _surface412(String msg) {
    widget.services.passwordCache.clear();
    // Detach the listener around the clear() so its `setState` doesn't race
    // with the one we're about to call — otherwise the error briefly clears
    // and re-asserts in the same frame.
    _passwordCtrl.removeListener(_onPasswordChanged);
    _passwordCtrl.value = TextEditingValue.empty;
    _passwordCtrl.addListener(_onPasswordChanged);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _passwordError = msg;
    });
    _passwordFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final services = widget.services;
    final session = services.auth.session.value;
    final companyName = session?.currentCompany?.displayName ?? '';
    final isHosted = session?.isHosted ?? false;
    final scope = _scopeText(
      context,
      kind: widget.kind,
      companyName: companyName,
    );
    final showFeedback =
        widget.kind == _DangerKind.purge ||
        (widget.kind == _DangerKind.delete && isHosted);
    final feedbackLabel = widget.kind == _DangerKind.purge
        ? context.tr('cancellation_message')
        : context.tr('reason_for_canceling');

    return PopScope(
      canPop: _canPop,
      child: FormSaveScope(
        onSubmit: _submit,
        enabled: _canSubmit,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showTitle) ...[
                Text(
                  _titleFor(context, widget.kind, services),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: InSpacing.md(context)),
              ],
              if (_topBannerError != null) ...[
                _ErrorBanner(message: _topBannerError!),
                SizedBox(height: InSpacing.md(context)),
              ],
              if (widget.kind == _DangerKind.delete &&
                  companyName.isNotEmpty) ...[
                Text(
                  companyName,
                  style: TextStyle(
                    color: tokens.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: InSpacing.md(context)),
              ] else if (scope.isNotEmpty) ...[
                Text(scope, style: TextStyle(color: tokens.ink2)),
                SizedBox(height: InSpacing.md(context)),
              ],
              TextField(
                autofocus: true,
                enabled: !_busy,
                controller: _confirmCtrl,
                decoration: InputDecoration(
                  labelText: context
                      .tr('please_type_to_confirm')
                      .replaceFirst(':value', _expectedConfirm),
                ),
                textInputAction: TextInputAction.next,
              ),
              if (showFeedback) ...[
                SizedBox(height: InSpacing.md(context)),
                TextField(
                  enabled: !_busy,
                  controller: _feedbackCtrl,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: feedbackLabel,
                    errorText: _feedbackError,
                  ),
                  // No textInputAction: a multi-line field must keep Return
                  // for newlines, and Flutter derives `newline` from
                  // maxLines. `.next` here made Return move focus instead.
                ),
              ],
              SizedBox(height: InSpacing.md(context)),
              TextField(
                enabled: !_busy,
                controller: _passwordCtrl,
                focusNode: _passwordFocus,
                obscureText: _obscure,
                keyboardType: TextInputType.visiblePassword,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: context.tr('password'),
                  errorText: _passwordError,
                  suffixIcon: Focus(
                    canRequestFocus: false,
                    child: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              SizedBox(height: InSpacing.lg(context)),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: InSpacing.md(context),
                runSpacing: InSpacing.sm,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 40),
                    ),
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: Text(context.tr('cancel')),
                  ),
                  PrimaryDialogAction(
                    variant: DialogActionVariant.destructive,
                    label: context.tr('continue'),
                    enabled: _canSubmit,
                    busy: _busy,
                    autofocus: false,
                    onPressed: _submit,
                  ),
                ],
              ),
              SizedBox(height: InSpacing.md(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      padding: EdgeInsets.all(InSpacing.md(context)),
      decoration: BoxDecoration(
        color: tokens.overdueSoft,
        borderRadius: BorderRadius.circular(InRadii.r2),
        border: Border.all(color: tokens.overdue.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: tokens.overdue, size: 18),
          SizedBox(width: InSpacing.sm),
          Expanded(
            child: Text(message, style: TextStyle(color: tokens.ink)),
          ),
        ],
      ),
    );
  }
}

String _titleFor(BuildContext context, _DangerKind kind, Services services) {
  if (kind == _DangerKind.purge) return context.tr('purge_data');
  final multi = (services.auth.session.value?.companies.length ?? 0) > 1;
  return multi ? context.tr('delete_company') : context.tr('cancel_account');
}

String _scopeText(
  BuildContext context, {
  required _DangerKind kind,
  required String companyName,
}) {
  if (kind == _DangerKind.purge) {
    return context.tr('purge_data_scope');
  }
  return '';
}
