import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/widgets/oauth_mailer_connect.dart';

/// Read-only picker for the user that owns the Gmail or Microsoft OAuth
/// token used as the email-sending identity.
///
/// Empty-state: when no eligible user is available, shows a small block
/// explaining that connecting an account happens in the browser. Except on
/// native iOS / macOS (a static "use the web app" blurb, matching
/// admin-portal), the "Connect" button opens the server's own flow — see
/// `oauth_mailer_connect.dart`.
class OauthUserPicker extends StatelessWidget {
  const OauthUserPicker({super.key, required this.provider});

  /// `'google'` or `'microsoft'`. The list filter and the connect URL both
  /// branch on this value.
  final String provider;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final host = context.watch<SettingsDraftHost>();
    // Source the company id from the auth session, not `host.draft?.id`:
    // at client scope `host.draft` is null (the cascade VM has no top-level
    // Company draft), but the OAuth picker should still render so the user
    // can override `gmail_sending_user_id` from the cascade.
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    if (companyId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<User>>(
      stream: services.user.watchEmailSendingUsers(
        companyId: companyId,
        provider: provider,
      ),
      builder: (context, snapshot) {
        final users = snapshot.data ?? const <User>[];
        final selectedId = host.settings.gmailSendingUserId;

        if (users.isEmpty) {
          return _ConnectEmptyState(provider: provider);
        }

        User? selected;
        if (selectedId != null && selectedId.isNotEmpty) {
          for (final u in users) {
            if (u.id == selectedId) {
              selected = u;
              break;
            }
          }
        }

        return SearchableDropdownField<User>(
          label: provider == 'microsoft'
              ? context.tr('microsoft_user')
              : context.tr('gmail_user'),
          items: users,
          initialValue: selected,
          displayString: _userLabel,
          idOf: (u) => u.id,
          onChanged: (u) {
            host.updateSettings(
              (s) => s.copyWith(gmailSendingUserId: u?.id ?? ''),
            );
          },
        );
      },
    );
  }

  static String _userLabel(User u) {
    final name = [u.firstName, u.lastName].where((s) => s.isNotEmpty).join(' ');
    if (name.isEmpty) return u.email;
    return u.email.isEmpty ? name : '$name • ${u.email}';
  }
}

class _ConnectEmptyState extends StatelessWidget {
  const _ConnectEmptyState({required this.provider});

  final String provider;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final isGoogle = provider != 'microsoft';
    final services = context.read<Services>();
    final session = services.auth.session.value;
    final baseUrl = session?.baseUrl ?? '';
    final canLaunch = canLaunchMailerConnect(baseUrl);
    final label = isGoogle
        ? context.tr('use_web_app_to_connect_gmail')
        : context.tr('use_web_app_to_connect_microsoft');

    return Container(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(InRadii.r2),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isGoogle ? Icons.email_outlined : Icons.mail_outline),
              SizedBox(width: InSpacing.md(context)),
              Expanded(child: Text(label)),
            ],
          ),
          if (canLaunch) ...[
            SizedBox(height: InSpacing.md(context)),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 40),
                ),
                icon: const Icon(Icons.open_in_new),
                label: Text(
                  isGoogle
                      ? context.tr('connect_gmail')
                      : context.tr('connect_microsoft'),
                ),
                onPressed: () => launchMailerConnect(
                  services.auth,
                  baseUrl,
                  isGoogle: isGoogle,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
