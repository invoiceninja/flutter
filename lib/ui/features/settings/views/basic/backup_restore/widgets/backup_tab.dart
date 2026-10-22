import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

/// Search keys rendered by this tab. See
/// `kCompanyDetailsDetailsSearchKeys` for the colocation pattern.
const kBackupTabSearchKeys = <String>['backup', 'export'];

/// Backup tab body — one-shot `POST /api/v1/export` that asks the server to
/// build a zip of the active company and email the user a download link.
/// There's no in-app download path; legacy admin-portal and the React client
/// both rely on the email flow.
class BackupTabBody extends StatefulWidget {
  const BackupTabBody({super.key});

  @override
  State<BackupTabBody> createState() => _BackupTabBodyState();
}

class _BackupTabBodyState extends State<BackupTabBody> {
  bool _busy = false;

  Future<void> _runBackup() async {
    final services = context.read<Services>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    // Capture the fallback text upfront so we don't reach back into context
    // across the post-await gap.
    final fallback = context.tr('exported_data');
    setState(() => _busy = true);
    try {
      final result = await services.apiClient.postJson(
        '/api/v1/export',
        body: const {'send_email': true, 'report_keys': <String>[]},
      );
      // Server returns `{message: "..."}` — surface its text when present so a
      // localized rate-limit / queue message reaches the user; fall back to
      // the help-text key otherwise.
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
    final session = context.read<Services>().auth.session;
    final tokens = context.inTheme;

    return ValueListenableBuilder(
      valueListenable: session,
      builder: (context, value, _) {
        final email = value?.userEmail ?? '';
        return SettingsFormShell(
          sections: [
            FormSection(
              title: context.tr('backup'),
              children: [
                // Personalised email line carries the same meaning as
                // `exported_data` ("we'll email a link") + the destination,
                // so we drop the generic explanation and keep just this one.
                if (email.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.alternate_email,
                          size: 18,
                          color: tokens.ink3,
                        ),
                      ),
                      SizedBox(width: InSpacing.sm),
                      Expanded(
                        // No ellipsis: long emails wrap to a second line
                        // rather than silently clipping the user's own
                        // address.
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${context.tr('backup_sent_to_email')} ',
                                style: TextStyle(color: tokens.ink2),
                              ),
                              TextSpan(
                                text: email,
                                style: TextStyle(
                                  color: tokens.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          softWrap: true,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    context.tr('exported_data'),
                    style: TextStyle(color: tokens.ink2),
                  ),
                SizedBox(height: InSpacing.lg(context)),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton.icon(
                    // Fixed 18×18 leading slot so the button width is stable
                    // across idle/busy states.
                    icon: SizedBox(
                      width: 18,
                      height: 18,
                      child: _busy
                          ? const CircularProgressIndicator(strokeWidth: 2)
                          : const Icon(Icons.cloud_download_outlined, size: 18),
                    ),
                    label: Text(context.tr('export')),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(120, 44),
                    ),
                    onPressed: _busy ? null : _runBackup,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
