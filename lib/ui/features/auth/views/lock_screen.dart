import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/dialogs/confirm_sign_out_dialog.dart';
import 'package:admin/ui/features/auth/view_models/lock_view_model.dart';
import 'package:admin/ui/features/shell/widgets/confirm_pending_outbox.dart';

/// Cold-launch biometric gate. Shown by the router when
/// `AuthRepository.requiresBiometricUnlock` is true. Auto-prompts on mount
/// (matching admin-portal `main_app.dart:228-229`); the user can retry via
/// the Unlock button or fall back to Sign out.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  late final LockViewModel _vm;

  @override
  void initState() {
    super.initState();
    final services = context.read<Services>();
    _vm = LockViewModel(auth: services.auth, biometric: services.biometric);
    // Auto-trigger on mount, but defer past the first frame so the
    // Localization delegate has resolved.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _vm.unlock(context.tr('please_authenticate'));
    });
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _onUnlock() async {
    await _vm.unlock(context.tr('please_authenticate'));
  }

  Future<void> _onSignOut() async {
    // Resolved before the first await so the confirm below doesn't push a
    // `context` read past one (`use_build_context_synchronously`).
    final services = context.read<Services>();
    // Cannot delegate to `SettingsActions.signOut`: `LockViewModel.signOut()`
    // owns the `busy` flag that gates both buttons on this screen.
    if (!await showConfirmSignOutDialog(context)) return;
    if (!mounted) return;
    // The button was enabled when tapped, but the dialog is an await, and
    // `LocalAuthBiometricService` prompts with `persistAcrossBackgrounding`,
    // so a resumed app can land back here with `busy` true — and
    // `LockViewModel.signOut()` opens with `if (_busy) return;`, dropping the
    // request. This bails early rather than walking the user through the
    // outbox prompt first and discarding the answer at the end. It does NOT
    // rescue the sign-out: the request is lost either way, and the user's
    // signal is the buttons going disabled behind the biometric prompt.
    if (_vm.busy) return;
    // Signing out here runs a FULL logout, which wipes the whole local DB —
    // including every company's still-pending outbox rows. Quiesce them first
    // with the same prompt every other sign-out entry point uses, or the lock
    // screen silently destroys the offline edits the idle-timeout preserve
    // path deliberately kept alive. Credentials are live on /lock (restore()
    // set them before the gate), so the prompt's "sync now" path works here.
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId != null) {
      final outbox = await confirmPendingOutboxIfAny(
        context,
        companyId: companyId,
        checkAllCompanies: true,
      );
      if (outbox == OutboxConfirmResult.cancelled || !mounted) return;
    }
    await _vm.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: InSpacing.xl,
                vertical: InSpacing.xxl,
              ),
              child: ListenableBuilder(
                listenable: _vm,
                builder: (context, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, size: 64, color: tokens.accent),
                      SizedBox(height: InSpacing.lg(context)),
                      Text(
                        context.tr('biometric_authentication'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: tokens.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: InSpacing.sm),
                      Text(
                        context.tr('please_authenticate'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: tokens.ink2, height: 1.4),
                      ),
                      const SizedBox(height: InSpacing.xxl),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton(
                            key: const ValueKey('lock_sign_out'),
                            onPressed: _vm.busy ? null : _onSignOut,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(120, 40),
                            ),
                            child: Text(context.tr('sign_out')),
                          ),
                          SizedBox(width: InSpacing.md(context)),
                          FilledButton.icon(
                            key: const ValueKey('lock_unlock'),
                            onPressed: _vm.busy ? null : _onUnlock,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(120, 44),
                            ),
                            icon: _vm.busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.fingerprint, size: 18),
                            label: Text(context.tr('unlock')),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
