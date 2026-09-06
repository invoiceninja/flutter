import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/dialogs/confirm_sign_out_dialog.dart';

/// Rendered when the server's `x-minimum-client-version` exceeds our
/// `kClientVersion`. No Retry — the next request would just bounce the same
/// way. The user's only useful actions are "update the app" (out of band)
/// and "sign out" (in case they want to point at a different server).
class ClientTooOldScreen extends StatelessWidget {
  const ClientTooOldScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<({String minRequired, String current})?>(
          valueListenable: services.clientTooOld,
          builder: (context, info, _) {
            final theme = Theme.of(context);
            final min = info?.minRequired ?? '?';
            final current = info?.current ?? '?';
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.system_update_alt,
                        size: 72,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.tr('update_required_title'),
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.tr('update_required_body', {
                          'current': current,
                          'min': min,
                        }),
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.logout),
                        label: Text(context.tr('sign_out')),
                        onPressed: () async {
                          // Same rule as the 401 path: a destructive logout
                          // wipes the outbox, so preserve the local DB while
                          // unsynced edits are still queued. Resolved once,
                          // up front, because it picks the copy as well as
                          // the call.
                          final preserve = await services.sync
                              .hasUnsyncedWork();
                          if (!context.mounted) return;
                          // On the preserve path nothing is cleared, so the
                          // default warning would be false in exactly the
                          // case that matters.
                          if (!await showConfirmSignOutDialog(
                            context,
                            message: preserve
                                ? context.tr('sign_out_keep_unsynced_warning')
                                : null,
                          )) {
                            return;
                          }
                          if (!context.mounted) return;
                          // Only now. `clientTooOld` sits in the router's
                          // refreshListenable, so clearing it redirects off
                          // /too-old on the next frame — do it before the
                          // prompt and a CANCEL strands the user on the
                          // dashboard of a server that rejects every request.
                          services.clientTooOld.value = null;
                          await services.auth.logout(
                            preserveLocalData: preserve,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
