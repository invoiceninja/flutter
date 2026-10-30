import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/domain/self_update.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/external_url.dart';
import 'package:admin/ui/core/widgets/confirm_password_sheet.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/ltr_value.dart';
import 'package:admin/ui/core/widgets/notify.dart' show formatNotifyError;
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// Opens the self-hosted server update dialog — admin-portal's
/// `UpdateDialog`, reached from the sidebar's Update Available card and the
/// About dialog. Who may see it is `selfUpdateOffer`'s call; the server
/// refuses anyone else anyway.
Future<void> showSelfUpdateDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const SelfUpdateDialog(),
  );
}

enum _Phase { ready, running, done }

class SelfUpdateDialog extends StatefulWidget {
  const SelfUpdateDialog({super.key});

  @override
  State<SelfUpdateDialog> createState() => _SelfUpdateDialogState();
}

class _SelfUpdateDialogState extends State<SelfUpdateDialog> {
  _Phase _phase = _Phase.ready;

  // Read once: the refresh after a successful update brings the new
  // `current_version`, and the title must not turn into Force Update under
  // the success message.
  late final AuthSession? _session = context
      .read<Services>()
      .auth
      .session
      .value;
  late final SelfUpdateOffer _offer = selfUpdateOffer(_session);

  /// Set when the update was refused or failed; null on success.
  String? _error;

  Future<void> _update() async {
    final services = context.read<Services>();
    try {
      final message = await _withPassword(services, () {
        setState(() => _phase = _Phase.running);
        return services.system.selfUpdate();
      });
      if (!mounted) return;
      // Older servers answered a failed unpack with a 2xx and a message
      // saying so (admin-portal checked for the same word).
      if (message.toLowerCase().contains('failed')) {
        setState(() {
          _phase = _Phase.done;
          _error = message;
        });
        return;
      }
      setState(() {
        _phase = _Phase.done;
        _error = null;
      });
      // The server now reports its new `current_version`; a refresh brings
      // it in and takes the sidebar card down.
      unawaited(services.auth.refresh().catchError((Object _) {}));
    } on _Cancelled {
      if (mounted) setState(() => _phase = _Phase.ready);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.done;
        _error = formatNotifyError(e);
      });
    }
  }

  /// Runs [op], and on a missing password prompts once and retries. A
  /// password refused on the retry is cleared so the next try asks again.
  Future<T> _withPassword<T>(Services services, Future<T> Function() op) async {
    try {
      return await op();
    } on PasswordRequiredException {
      if (!mounted) throw const _Cancelled();
      // Nothing is running while the password is asked for.
      setState(() => _phase = _Phase.ready);
      // `afterRejection`: for an OAuth user the session calls exempt, this
      // is the server's 412 saying otherwise, so the sheet must ask.
      final ok = await showConfirmPasswordSheet(
        context,
        cache: services.passwordCache,
        afterRejection: true,
      );
      if (!ok || !mounted) throw const _Cancelled();
      try {
        return await op();
      } on PasswordRequiredException {
        services.passwordCache.clear();
        rethrow;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final installed = bareVersion(session?.serverCurrentVersion ?? '');
    final latest = bareVersion(session?.serverLatestVersion ?? '');
    final isDocker = session?.isDocker ?? false;
    final hasUpdate = _offer == SelfUpdateOffer.update;
    return PopScope(
      // The server is mid-update: closing would hide the outcome, not stop it.
      canPop: _phase != _Phase.running,
      child: AlertDialog(
        title: Text(
          context.tr(hasUpdate ? 'update_available' : 'force_update'),
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: switch (_phase) {
              _Phase.ready => _ReadyBody(
                hasUpdate: hasUpdate,
                installed: installed,
                latest: latest,
                isDocker: isDocker,
              ),
              _Phase.running => const _RunningBody(),
              _Phase.done => _DoneBody(error: _error),
            },
          ),
        ),
        actionsOverflowButtonSpacing: InSpacing.sm,
        actions: switch (_phase) {
          _Phase.running => const [],
          _Phase.done => [
            PrimaryDialogAction(
              label: context.tr('close'),
              onPressed: () => Navigator.of(context).pop(),
              showEnterHint: false,
            ),
          ],
          _Phase.ready => [
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('close')),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: () => unawaited(
                openExternalUrl(
                  context,
                  hasUpdate || installed.isEmpty
                      ? kServerReleaseNotesUrl
                      : serverChangesUrl(installed),
                ),
              ),
              child: Text(
                context.tr(
                  hasUpdate || installed.isEmpty
                      ? 'release_notes'
                      : 'view_changes',
                ),
              ),
            ),
            // A Docker install updates by pulling the image; the body shows
            // the commands instead.
            if (!isDocker)
              PrimaryDialogAction(
                label: context.tr('update_now'),
                onPressed: () => unawaited(_update()),
              ),
          ],
        },
      ),
    );
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({
    required this.hasUpdate,
    required this.installed,
    required this.latest,
    required this.isDocker,
  });

  final bool hasUpdate;
  final String installed;
  final String latest;
  final bool isDocker;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.tr(
            hasUpdate ? 'update_invoiceninja_available' : 'force_update_help',
          ),
        ),
        if (installed.isNotEmpty) ...[
          SizedBox(height: InSpacing.lg(context)),
          _VersionRow(label: context.tr('installed_version'), value: installed),
        ],
        if (hasUpdate) ...[
          const SizedBox(height: InSpacing.xs),
          _VersionRow(label: context.tr('latest_version'), value: latest),
        ],
        if (isDocker) ...[
          SizedBox(height: InSpacing.lg(context)),
          Text('${context.tr('to_update_run')}:'),
          const SizedBox(height: InSpacing.sm),
          CopyableValue(
            value: kDockerUpdateCommand,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(InSpacing.sm),
              decoration: BoxDecoration(
                color: tokens.surfaceAlt,
                borderRadius: BorderRadius.circular(InRadii.r1),
                border: Border.all(color: tokens.border),
              ),
              child: const LtrText(
                kDockerUpdateCommand,
                style: TextStyle(fontFamily: kMonoFontFamily, fontSize: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label: ', style: TextStyle(color: context.inTheme.ink3)),
        Flexible(child: LtrText('v$value')),
      ],
    );
  }
}

class _RunningBody extends StatelessWidget {
  const _RunningBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: LinearProgressIndicator(),
        ),
        Text('${context.tr('in_progress')}...'),
      ],
    );
  }
}

class _DoneBody extends StatelessWidget {
  const _DoneBody({required this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final message = error;
    if (message == null) return Text(context.tr('app_updated'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SelectableText(message),
        // admin-portal's hint: local edits to the code base are the usual
        // reason an unpack fails.
        if (message.toLowerCase().contains('failed')) ...[
          SizedBox(height: InSpacing.lg(context)),
          Text(context.tr('update_fail_help')),
          const SizedBox(height: InSpacing.sm),
          const LtrText(
            'git checkout .',
            style: TextStyle(fontFamily: kMonoFontFamily, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
