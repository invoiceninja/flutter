import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/settings/views/basic/user_details/view_models/two_factor_view_model.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

/// Settings → User Details → Two-Factor Authentication.
///
/// Drives [TwoFactorViewModel] for the state machine; the screen is mostly
/// section gating + form bindings. Rendered as a tab body inside the
/// `UserDetailsShell` — chrome (AppBar, padding) comes from the surrounding
/// scaffold.

const kUserDetailsTwoFactorSearchKeys = <String>[
  'enable_two_factor',
  'two_factor_authentication',
];

class UserDetailsTwoFactorScreen extends StatefulWidget {
  const UserDetailsTwoFactorScreen({super.key});

  @override
  State<UserDetailsTwoFactorScreen> createState() =>
      _UserDetailsTwoFactorScreenState();
}

class _UserDetailsTwoFactorScreenState
    extends State<UserDetailsTwoFactorScreen> {
  TwoFactorViewModel? _vm;

  @override
  void dispose() {
    _vm?.dispose();
    super.dispose();
  }

  TwoFactorViewModel _buildVm(BuildContext context, AuthSession session) {
    final services = context.read<Services>();
    return TwoFactorViewModel(
      repo: services.twoFactor,
      isHosted: session.isHosted,
      email: session.userEmail,
      initiallyEnabled: session.googleTwoFactorEnabled,
      initiallyVerifiedPhone: session.verifiedPhoneNumber,
      initialPhone: session.userPhone,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AuthSession?>(
      valueListenable: context.read<Services>().auth.session,
      builder: (context, session, _) {
        if (session == null) {
          return const Center(child: CircularProgressIndicator());
        }
        // First non-null session builds the VM. Subsequent session changes
        // (e.g. background `/refresh` after restore, or another device
        // flipping the bit) flow through `syncFromSession` so the screen
        // updates without the user having to leave and re-enter.
        if (_vm == null) {
          _vm = _buildVm(context, session);
        } else {
          _vm!.syncFromSession(session);
        }
        return ListenableBuilder(
          listenable: _vm!,
          builder: (context, _) => _Body(vm: _vm!),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.vm});

  final TwoFactorViewModel vm;

  @override
  Widget build(BuildContext context) {
    final enabled = vm.enabled;
    return SettingsFormShell(
      sections: [
        FormSection(
          title: context.tr('two_factor_authentication'),
          children: [
            Text(
              context.tr('two_factor_about_body'),
              style: TextStyle(color: context.inTheme.ink2, height: 1.4),
            ),
            SizedBox(height: InSpacing.md(context)),
            _StatusRow(enabled: enabled),
          ],
        ),
        if (enabled) _DisableSection(vm: vm) else ..._enableSections(context),
      ],
    );
  }

  List<Widget> _enableSections(BuildContext context) {
    switch (vm.step) {
      case TwoFactorStep.idle:
        return [_EnableCta(vm: vm)];
      case TwoFactorStep.phoneEntry:
        return [_PhoneEntry(vm: vm)];
      case TwoFactorStep.smsVerify:
        return [_SmsVerify(vm: vm)];
      case TwoFactorStep.qrLoading:
        return [
          FormSection(
            title: context.tr('two_factor_setup'),
            children: const [
              SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
        ];
      case TwoFactorStep.qrShow:
        return [_QrShow(vm: vm)];
      case TwoFactorStep.disabling:
        return const [];
    }
  }
}

// ─── Status row ────────────────────────────────────────────────────────────

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final color = enabled ? tokens.paid : tokens.ink3;
    return Row(
      children: [
        Icon(
          enabled ? Icons.shield_outlined : Icons.shield,
          color: color,
          size: 20,
        ),
        const SizedBox(width: InSpacing.sm),
        Expanded(
          child: Text(
            context.tr(
              enabled
                  ? 'two_factor_status_enabled'
                  : 'two_factor_status_disabled',
            ),
            style: TextStyle(color: color, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

// ─── Enable CTA (idle, not enabled) ───────────────────────────────────────

class _EnableCta extends StatelessWidget {
  const _EnableCta({required this.vm});

  final TwoFactorViewModel vm;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: context.tr('enable_two_factor'),
      children: [
        Text(
          context.tr('enable_two_factor_help'),
          style: TextStyle(color: context.inTheme.ink2, height: 1.4),
        ),
        SizedBox(height: InSpacing.lg(context)),
        Row(
          children: [
            FilledButton.icon(
              onPressed: vm.busy ? null : () => _onEnable(context),
              icon: const Icon(Icons.shield_outlined, size: 18),
              label: Text(context.tr('enable')),
              style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            ),
          ],
        ),
      ],
    );
  }

  /// Tapping Enable can fail fast on hosted when no phone is on file — surface
  /// that (`enter_phone_to_enable_two_factor`) since the idle screen has no
  /// inline error slot.
  Future<void> _onEnable(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await vm.startEnable();
    if (!context.mounted) return;
    if (vm.errorMessage != null) {
      Notify.error(context, vm.errorMessage!, messenger: messenger);
    } else if (vm.errorKey != null) {
      Notify.error(context, context.tr(vm.errorKey!), messenger: messenger);
    }
  }
}

// ─── Disable section (idle, enabled) ──────────────────────────────────────

class _DisableSection extends StatelessWidget {
  const _DisableSection({required this.vm});

  final TwoFactorViewModel vm;

  Future<void> _confirmDisable(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('disable_two_factor_question')),
        content: Text(ctx.tr('disable_two_factor_warning')),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            child: Text(ctx.tr('cancel')),
          ),
          PrimaryDialogAction(
            variant: DialogActionVariant.destructive,
            label: ctx.tr('disable'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final services = context.read<Services>();
    await vm.disable();
    if (!context.mounted) return;
    if (vm.needsPassword) {
      final pw = await _promptForPassword(context);
      if (pw == null || pw.isEmpty || !context.mounted) return;
      services.passwordCache.set(pw);
      await vm.disable();
      if (!context.mounted) return;
    }
    if (vm.errorMessage != null) {
      Notify.error(context, vm.errorMessage!, messenger: messenger);
    } else if (!vm.enabled) {
      Notify.success(
        context,
        context.tr('disabled_two_factor'),
        messenger: messenger,
      );
    }
  }

  Future<String?> _promptForPassword(BuildContext context) async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.tr('please_type_password')),
          content: TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            keyboardType: TextInputType.visiblePassword,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(labelText: ctx.tr('password')),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              child: Text(ctx.tr('cancel')),
            ),
            PrimaryDialogAction(
              label: ctx.tr('confirm'),
              autofocus: false,
              onPressed: () => Navigator.of(ctx).pop(controller.text),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FormSection(
      title: context.tr('disable_two_factor'),
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: vm.busy ? null : () => _confirmDisable(context),
              icon: vm.busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.shield_outlined, size: 18),
              label: Text(context.tr('disable_two_factor')),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error),
                minimumSize: const Size(64, 40),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Phone entry (hosted, !verifiedPhone) ─────────────────────────────────

class _PhoneEntry extends StatelessWidget {
  const _PhoneEntry({required this.vm});

  final TwoFactorViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return FormSection(
      title: context.tr('verify_phone_number'),
      children: [
        Text(
          context.tr('two_factor_verify_phone_help'),
          style: TextStyle(color: tokens.ink2, height: 1.4),
        ),
        SizedBox(height: InSpacing.md(context)),
        // Phone is read-only here — it's sourced from (and edited in) the
        // Details tab; the server texts whatever number is on file.
        Row(
          children: [
            Icon(Icons.phone_outlined, size: 18, color: tokens.ink3),
            const SizedBox(width: InSpacing.sm),
            Expanded(
              child: Text(
                vm.phone,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
        SizedBox(height: InSpacing.lg(context)),
        Row(
          children: [
            OutlinedButton(
              onPressed: vm.busy ? null : vm.cancel,
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              child: Text(context.tr('cancel')),
            ),
            SizedBox(width: InSpacing.md(context)),
            FilledButton(
              onPressed: vm.busy ? null : () => _onSend(context),
              style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
              child: vm.busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(context.tr('send_code')),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _onSend(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await vm.sendSmsCode();
    if (!context.mounted) return;
    if (vm.errorMessage != null) {
      Notify.error(context, vm.errorMessage!, messenger: messenger);
    } else if (vm.errorKey != null) {
      Notify.error(context, context.tr(vm.errorKey!), messenger: messenger);
    }
  }
}

// ─── SMS verify ───────────────────────────────────────────────────────────

class _SmsVerify extends StatelessWidget {
  const _SmsVerify({required this.vm});

  final TwoFactorViewModel vm;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: context.tr('sms_code'),
      children: [
        Text(
          context.tr('enter_sms_code'),
          style: TextStyle(color: context.inTheme.ink2, height: 1.4),
        ),
        SizedBox(height: InSpacing.md(context)),
        _LabeledField(
          label: context.tr('sms_code'),
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          // Server validates the SMS code under `code` (Confirm2faRequest).
          errorText: vm.fieldErrors['code']?.first,
          onChanged: vm.setSmsCode,
        ),
        SizedBox(height: InSpacing.lg(context)),
        Row(
          children: [
            OutlinedButton(
              onPressed: vm.busy ? null : vm.cancel,
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              child: Text(context.tr('cancel')),
            ),
            SizedBox(width: InSpacing.md(context)),
            TextButton(
              onPressed: vm.busy ? null : () => _onResend(context),
              child: Text(context.tr('resend_code')),
            ),
            const Spacer(),
            FilledButton(
              onPressed: vm.busy ? null : () => _onVerify(context),
              style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
              child: vm.busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(context.tr('verify')),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _onVerify(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await vm.verifySmsCode();
    if (!context.mounted) return;
    if (vm.errorMessage != null) {
      Notify.error(context, vm.errorMessage!, messenger: messenger);
    } else if (vm.errorKey != null) {
      Notify.error(context, context.tr(vm.errorKey!), messenger: messenger);
    }
  }

  Future<void> _onResend(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await vm.sendSmsCode();
    if (!context.mounted) return;
    if (vm.errorMessage != null) {
      Notify.error(context, vm.errorMessage!, messenger: messenger);
    }
  }
}

// ─── QR + secret + confirm ────────────────────────────────────────────────

class _QrShow extends StatelessWidget {
  const _QrShow({required this.vm});

  final TwoFactorViewModel vm;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: context.tr('two_factor_setup'),
      children: [
        Text(
          context.tr('scan_qr_code_with_app'),
          style: TextStyle(color: context.inTheme.ink2, height: 1.4),
        ),
        SizedBox(height: InSpacing.lg(context)),
        Center(child: _QrImage(qrData: vm.qrCode)),
        SizedBox(height: InSpacing.lg(context)),
        Text(
          context.tr('or_enter_code_manually'),
          style: TextStyle(color: context.inTheme.ink3, fontSize: 12),
        ),
        const SizedBox(height: InSpacing.xs),
        _SecretRow(secret: vm.secret),
        SizedBox(height: InSpacing.lg(context)),
        _LabeledField(
          label: context.tr('one_time_password'),
          hint: context.tr('enter_six_digit_code'),
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          errorText: vm.fieldErrors['one_time_password']?.first,
          onChanged: vm.setOneTimePassword,
        ),
        SizedBox(height: InSpacing.lg(context)),
        Row(
          children: [
            OutlinedButton(
              onPressed: vm.busy ? null : vm.cancel,
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              child: Text(context.tr('cancel')),
            ),
            SizedBox(width: InSpacing.md(context)),
            FilledButton(
              onPressed: vm.busy ? null : () => _onConfirm(context),
              style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
              child: vm.busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(context.tr('enable')),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _onConfirm(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await vm.confirmEnable();
    if (!context.mounted) return;
    if (vm.enabled) {
      Notify.success(
        context,
        context.tr('enabled_two_factor'),
        messenger: messenger,
      );
    } else if (vm.errorMessage != null) {
      Notify.error(context, vm.errorMessage!, messenger: messenger);
    }
  }
}

class _QrImage extends StatelessWidget {
  const _QrImage({required this.qrData});

  /// The `otpauth://totp/...` URL the server returns under `data.qrCode`
  /// (Laravel `Google2FA::getQRCodeUrl`). It's a URL string, not an image, so
  /// we render it client-side — matching the legacy app (`QrImageView(data:)`)
  /// and React (`<QRCode value={...} />`).
  final String qrData;

  @override
  Widget build(BuildContext context) {
    // Empty payload (server hiccup) → 220px placeholder so the layout doesn't
    // jump; the secret below stays available for manual entry.
    if (qrData.isEmpty) {
      return Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          border: Border.all(color: context.inTheme.border),
          borderRadius: BorderRadius.circular(InRadii.r2),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.qr_code, size: 64),
      );
    }
    return Container(
      padding: const EdgeInsets.all(InSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(InRadii.r2),
        border: Border.all(color: context.inTheme.border),
      ),
      // Force black-on-white so the code scans regardless of theme.
      child: QrImageView(
        data: qrData,
        version: QrVersions.auto,
        size: 220,
        backgroundColor: Colors.white,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      ),
    );
  }
}

class _SecretRow extends StatelessWidget {
  const _SecretRow({required this.secret});

  final String secret;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SelectableText(
            secret,
            style: const TextStyle(
              fontFamily: kMonoFontFamily,
              fontSize: 14,
              letterSpacing: 1,
            ),
          ),
        ),
        IconButton(
          tooltip: context.tr('copy'),
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: secret));
            if (!context.mounted) return;
            Notify.info(
              context,
              context.tr('copied_to_clipboard', {'value': secret}),
            );
          },
        ),
      ],
    );
  }
}

// ─── Field with above-the-field label (matches login screen's `_InField`) ─

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    this.hint,
    this.keyboardType,
    this.errorText,
    this.autofillHints,
    this.onChanged,
  });

  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final String? errorText;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: context.inTheme.ink3,
            ),
          ),
        ),
        TextFormField(
          decoration: InputDecoration(hintText: hint, errorText: errorText),
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
