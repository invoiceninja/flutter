import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/services/google_oauth.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/settings/view_models/user_details_view_model.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

const kUserDetailsConnectSearchKeys = <String>[
  'connect_google',
  'connect_microsoft',
  'connect_gmail',
  'connect_email',
  'disconnect',
];

class UserDetailsConnectScreen extends StatelessWidget {
  const UserDetailsConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UserDetailsViewModel>();
    if (!vm.isLoaded || !vm.draftReady) {
      return const Center(child: CircularProgressIndicator());
    }
    final user = vm.user;
    if (user == null) return const SizedBox.shrink();

    if (user.oauthProviderId.isNotEmpty) {
      // Deliberately *not* host-gated: a self-hosted instance with its own
      // OAuth credentials can have a connected account, and taking the
      // Disconnect button away would strand it. Same split React makes.
      return SettingsFormShell(
        sections: [_ConnectedSection(provider: user.oauthProviderId)],
      );
    }
    // Connecting is hosted-only — the client ids the app ships belong to the
    // hosted Google/Microsoft projects, and React gates the same buttons on
    // `isHosted()` (`Connect.tsx`). Offering "Connect Google" on a
    // self-hosted instance advertised something that could not work
    // (invoiceninja/flutter#79); say why instead.
    final isHosted =
        context.read<Services>().auth.session.value?.isHosted ?? true;
    return SettingsFormShell(
      sections: isHosted
          ? const [_ConnectSection()]
          : const [_SelfHostedNotice()],
    );
  }
}

/// Stands in for [_ConnectSection] on a self-hosted instance: the tab still
/// exists (a connected account has to stay disconnectable, and a vanishing
/// tab is its own confusion) but says plainly that there is nothing to do here.
class _SelfHostedNotice extends StatelessWidget {
  const _SelfHostedNotice();

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return FormSection(
      title: context.tr('oauth_mail'),
      children: [
        Text(
          context.tr('connect_hosted_only_hint'),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: tokens.ink2),
        ),
      ],
    );
  }
}

/// Provider id → display label. The wire values match admin-portal's
/// `kOAuthProvider*` constants; new providers go here when the server
/// gains them.
String _providerLabel(BuildContext context, String id) {
  switch (id) {
    case 'google':
      return 'Google';
    case 'microsoft':
      return 'Microsoft';
    case 'apple':
      return 'Apple';
    default:
      return id.isEmpty ? context.tr('oauth_mail') : id;
  }
}

class _ConnectedSection extends StatelessWidget {
  const _ConnectedSection({required this.provider});
  final String provider;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UserDetailsViewModel>();
    final user = vm.user;
    final label = _providerLabel(context, provider);
    return FormSection(
      title: context.tr('oauth_mail'),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${context.tr('connected_to')}: $label',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: () => _onDisconnect(context, 'disconnect_oauth'),
              child: Text(context.tr('disconnect')),
            ),
          ],
        ),
        if (user != null && user.oauthUserRefreshToken.isNotEmpty) ...[
          SizedBox(height: InSpacing.lg(context)),
          const Divider(height: 1),
          SizedBox(height: InSpacing.lg(context)),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('send_and_receive_email'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 40),
                ),
                onPressed: () => _onDisconnect(context, 'disconnect_mailer'),
                child: Text(context.tr('disconnect')),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _onDisconnect(BuildContext context, String action) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final vm = context.read<UserDetailsViewModel>();
    // Connect/disconnect are immediate, full-user mutations on this same
    // entity; running one while the profile draft is dirty risks the pending
    // save re-sending the stale oauth state and undoing it. Match the legacy
    // app: make the user save or discard first.
    if (vm.isDirty) {
      Notify.info(context, context.tr('error_unsaved_changes'));
      return;
    }
    final successLabel = context.tr('saved_settings');
    final errorLabel = context.tr('error_refresh_page');
    try {
      await vm.enqueueDisconnect(action: action);
      if (context.mounted) Notify.success(context, successLabel);
    } catch (e) {
      if (context.mounted) {
        Notify.error(
          context,
          errorLabel,
          detail: e.toString(),
          messenger: messenger,
        );
      }
    }
  }
}

/// Not-yet-connected state: an in-app "Connect Google" action (reuses the
/// same `GoogleOAuth` helper as Google sign-in — access-token path, no
/// browser round-trip) plus an honest note that Microsoft connect is
/// web-only (no native MSAL on this client). Connecting enqueues a
/// `connect_oauth` outbox row; the server then reports the account as
/// connected and [_ConnectedSection] takes over (with its working
/// Disconnect).
class _ConnectSection extends StatefulWidget {
  const _ConnectSection();

  @override
  State<_ConnectSection> createState() => _ConnectSectionState();
}

class _ConnectSectionState extends State<_ConnectSection> {
  bool _busy = false;

  Future<void> _connectGoogle() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final vm = context.read<UserDetailsViewModel>();
    // See _onDisconnect: don't connect over a dirty draft.
    if (vm.isDirty) {
      Notify.info(context, context.tr('error_unsaved_changes'));
      return;
    }
    final successLabel = context.tr('saved_settings');
    final errorLabel = context.tr('error_refresh_page');
    setState(() => _busy = true);
    try {
      var accessToken = '';
      final ok = await GoogleOAuth.signIn((_, token) {
        accessToken = token;
      });
      if (!ok || accessToken.isEmpty) {
        return; // chooser dismissed / no token — nothing to surface
      }
      await vm.enqueueConnect(provider: 'google', accessToken: accessToken);
      if (mounted) Notify.success(context, successLabel);
    } catch (e) {
      if (mounted) {
        Notify.error(
          context,
          errorLabel,
          detail: e.toString(),
          messenger: messenger,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final googleEnabled = GoogleOAuth.isEnabled;
    return FormSection(
      title: context.tr('oauth_mail'),
      children: [
        Text(
          context.tr('connect_google_account'),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: tokens.ink2),
        ),
        SizedBox(height: InSpacing.md(context)),
        Row(
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
              onPressed: (!googleEnabled || _busy) ? null : _connectGoogle,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.account_circle_outlined, size: 18),
              label: Text(context.tr('connect_google')),
            ),
          ],
        ),
        SizedBox(height: InSpacing.lg(context)),
        const Divider(height: 1),
        SizedBox(height: InSpacing.lg(context)),
        Text(
          context.tr('connect_microsoft_web_hint'),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: tokens.ink3),
        ),
      ],
    );
  }
}
