import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/auth/view_models/login_view_model.dart';
import 'package:admin/ui/features/auth/widgets/auth_fields.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final LoginViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = LoginViewModel(auth: context.read<Services>().auth);
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.inTheme.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: InSpacing.xl,
            vertical: InSpacing.xxl,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: ListenableBuilder(
                  listenable: _vm,
                  builder: (context, _) => _LoginBody(vm: _vm),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginBody extends StatelessWidget {
  const _LoginBody({required this.vm});

  final LoginViewModel vm;

  String? _resolveError(BuildContext context) {
    if (vm.errorKey != null) return context.tr(vm.errorKey!, vm.errorParams);
    return vm.errorMessage;
  }

  Future<void> _onEmailSubmit(BuildContext context) async {
    final ok = await vm.submit();
    if (!context.mounted) return;
    final msg = _resolveError(context);
    if (!ok && msg != null) {
      Notify.error(context, msg);
    }
  }

  Future<void> _onAppleSubmit(BuildContext context) async {
    final ok = await vm.submitApple();
    if (!context.mounted) return;
    final msg = _resolveError(context);
    if (!ok && msg != null) {
      Notify.error(context, msg);
    }
  }

  Future<void> _onGoogleSubmit(BuildContext context) async {
    final ok = await vm.submitGoogle();
    if (!context.mounted) return;
    final msg = _resolveError(context);
    if (!ok && msg != null) {
      Notify.error(context, msg);
    }
  }

  Future<void> _onRecover(BuildContext context) async {
    final ok = await vm.recover();
    if (!context.mounted) return;
    if (ok) {
      Notify.success(context, context.tr('password_reset_link_sent'));
    } else {
      Notify.error(context, _resolveError(context) ?? context.tr('failed'));
    }
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Hosted → in-app signup screen. Self-hosted → external web page
  /// (in-app signup isn't a validated self-hosted path; mirrors React's
  /// hosted-only `/register` gating).
  void _onSignup(BuildContext context) {
    if (vm.isHosted) {
      context.go('/signup');
    } else {
      _openExternal(kSignupUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tokens = context.inTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Image.asset(
          isDark
              ? 'assets/images/logo_dark.png'
              : 'assets/images/logo_light.png',
          height: 48,
        ),
        const SizedBox(height: InSpacing.xl),
        AuthSurfaceCard(
          shadow: tokens.shadow2,
          padding: const EdgeInsets.all(InSpacing.xl),
          child: _LoginForm(
            vm: vm,
            onEmailSubmit: () => _onEmailSubmit(context),
            onAppleSubmit: () => _onAppleSubmit(context),
            onGoogleSubmit: () => _onGoogleSubmit(context),
            onSignup: () => _onSignup(context),
          ),
        ),
        SizedBox(height: InSpacing.md(context)),
        AuthSurfaceCard(
          shadow: tokens.shadow1,
          padding: const EdgeInsets.symmetric(vertical: InSpacing.xs),
          child: _RecoverStatusActions(
            onRecover: vm.busy ? null : () => _onRecover(context),
            onStatus: () => _openExternal(kStatusUrl),
          ),
        ),
      ],
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.vm,
    required this.onEmailSubmit,
    required this.onAppleSubmit,
    required this.onGoogleSubmit,
    required this.onSignup,
  });

  final LoginViewModel vm;
  final VoidCallback onEmailSubmit;
  final VoidCallback onAppleSubmit;
  final VoidCallback onGoogleSubmit;
  final VoidCallback onSignup;

  @override
  Widget build(BuildContext context) {
    final method = vm.method;
    final isApple = method == LoginMethod.apple;
    final isGoogle = method == LoginMethod.google;
    final isEmail = method == LoginMethod.email;
    final tokens = context.inTheme;
    // Wrap the form in AutofillGroup so the OS / password manager treats the
    // email + password (+ OTP) as a connected login form and offers to save
    // / fill them together. Without this, the hints below still work but the
    // pair isn't correlated, so "save password" prompts don't fire.
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthEyebrowLabel(context.tr('select_platform').toUpperCase()),
          _SegmentedToggle<bool>(
            value: vm.isHosted,
            segments: [
              _Segment(value: true, label: context.tr('hosted')),
              _Segment(value: false, label: context.tr('self_hosted')),
            ],
            onChanged: vm.setHosted,
          ),
          if (vm.isHosted) ...[
            SizedBox(height: InSpacing.lg(context)),
            AuthEyebrowLabel(context.tr('select_method').toUpperCase()),
            _SegmentedToggle<LoginMethod>(
              value: vm.method,
              segments: [
                _Segment(value: LoginMethod.email, label: context.tr('email')),
                if (vm.appleEnabled)
                  _Segment(
                    value: LoginMethod.apple,
                    label: context.tr('apple'),
                  ),
                if (vm.googleEnabled)
                  _Segment(
                    value: LoginMethod.google,
                    label: context.tr('google'),
                  ),
              ],
              onChanged: vm.setMethod,
            ),
          ],
          SizedBox(height: InSpacing.lg(context)),
          if (!vm.isHosted) ...[
            AuthField(
              label: context.tr('server_url'),
              hint: 'https://invoice.example.com  ·  http://192.168.0.10:8080',
              keyboardType: TextInputType.url,
              autofillHints: const [AutofillHints.url],
              onChanged: vm.setUrlOverride,
            ),
            SizedBox(height: InSpacing.md(context)),
          ],
          if (isEmail) ...[
            AuthField(
              label: context.tr('email'),
              initialValue: vm.email,
              keyboardType: TextInputType.emailAddress,
              errorText: vm.fieldErrors['email']?.first,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              onChanged: vm.setEmail,
            ),
            SizedBox(height: InSpacing.md(context)),
            AuthPasswordField(
              label: context.tr('password'),
              initialValue: vm.password,
              errorText: vm.fieldErrors['password']?.first,
              onChanged: vm.setPassword,
              onSubmitted: vm.busy ? null : (_) => onEmailSubmit(),
            ),
            SizedBox(height: InSpacing.md(context)),
            AuthField(
              label: context.tr('two_factor_otp_optional'),
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              onChanged: vm.setOneTimePassword,
            ),
          ],
          const SizedBox(height: InSpacing.xl),
          FilledButton.icon(
            key: const ValueKey('login_submit'),
            onPressed: vm.busy
                ? null
                : (isApple
                      ? onAppleSubmit
                      : isGoogle
                      ? onGoogleSubmit
                      : onEmailSubmit),
            icon: vm.busy
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        // Spinner matches the button's foreground.
                        isApple ? tokens.surface : Colors.white,
                      ),
                    ),
                  )
                : Icon(
                    isApple
                        ? Icons.apple
                        : isGoogle
                        ? Icons.account_circle_outlined
                        : Icons.mail_outline,
                    size: 18,
                  ),
            label: Text(
              isApple
                  ? context.tr('sign_in_with_apple')
                  : isGoogle
                  ? context.tr('sign_in_with_google')
                  : context.tr('login_with_email'),
            ),
            style: FilledButton.styleFrom(
              // Apple HIG: black-on-light, white-on-dark. `ink` already
              // inverts with brightness, so the button flips for free.
              // Google + email share the accent treatment.
              backgroundColor: isApple ? tokens.ink : tokens.accent,
              foregroundColor: isApple ? tokens.surface : Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(InRadii.r2),
              ),
            ),
          ),
          const SizedBox(height: InSpacing.sm),
          TextButton(
            onPressed: onSignup,
            child: Text(context.tr('create_your_account')),
          ),
        ],
      ),
    );
  }
}

// ─── Recover / Status actions ────────────────────────────────────────────

class _RecoverStatusActions extends StatelessWidget {
  const _RecoverStatusActions({
    required this.onRecover,
    required this.onStatus,
  });

  final VoidCallback? onRecover;
  final VoidCallback onStatus;

  @override
  Widget build(BuildContext context) {
    final recover = TextButton.icon(
      onPressed: onRecover,
      icon: const Icon(Icons.lock_outline, size: 16),
      label: Text(context.tr('recover_password')),
    );
    final status = TextButton.icon(
      onPressed: onStatus,
      icon: const Icon(Icons.shield_outlined, size: 16),
      label: Text(context.tr('check_status')),
    );
    if (Breakpoints.isGlobalNavVisible(context)) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [recover, status],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [recover, status],
    );
  }
}

// ─── Segmented toggle ────────────────────────────────────────────────────

class _Segment<T> {
  const _Segment({required this.value, required this.label});
  final T value;
  final String label;
}

class _SegmentedToggle<T> extends StatelessWidget {
  const _SegmentedToggle({
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  final T value;
  final List<_Segment<T>> segments;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(InRadii.r2),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          for (final s in segments)
            Expanded(
              child: _SegmentButton(
                label: s.label,
                selected: s.value == value,
                onTap: () => onChanged(s.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(InRadii.r1),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? tokens.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(InRadii.r1),
            border: Border.all(
              color: selected ? tokens.borderStrong : Colors.transparent,
            ),
            boxShadow: selected ? tokens.shadow1 : const [],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? tokens.ink : tokens.ink3,
            ),
          ),
        ),
      ),
    );
  }
}
