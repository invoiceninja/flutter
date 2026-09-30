import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/app/version.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/utils/external_url.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/auth/view_models/login_view_model.dart';
import 'package:admin/ui/features/auth/widgets/auth_fields.dart';
import 'package:admin/ui/features/auth/widgets/disable_two_factor_dialogs.dart';

/// The two-step login, mirroring React's `Login.tsx` (invoiceninja forum
/// #23570): the email first, then only the credentials that account needs.
///
/// Where this deliberately differs from React:
///  * the Hosted / Self-Hosted toggle and the server URL sit on step 1 — React
///    is served by its own server and never needs them; we need them before
///    the precheck can be asked;
///  * a precheck the server can't answer moves on with every optional field
///    shown instead of stopping (see [LoginViewModel.continueToCredentials]);
///  * "Forgot your password?" emails the address already on screen rather
///    than opening a separate page;
///  * errors on a request are toasts, like the rest of the app; errors on a
///    field render under that field and are never also toasted;
///  * the self-hosted secret is labelled "API secret" (React: "Secret" with
///    an "(optional)" placeholder), and shows — as optional — whenever the
///    precheck couldn't say whether it is needed;
///  * no "Login with a Passkey" button (passkeys are deferred: the server
///    binds them to the React app's domain) and no Microsoft sign-in (never
///    implemented in v2) — both tracked in FEATURES.md.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final LoginViewModel _vm;

  final _emailFocus = FocusNode(debugLabel: 'login_email');
  final _passwordFocus = FocusNode(debugLabel: 'login_password');
  final _otpFocus = FocusNode(debugLabel: 'login_otp');
  final _secretFocus = FocusNode(debugLabel: 'login_secret');

  /// Set by "Change" so the re-mounted email field takes focus. Not on first
  /// load: a keyboard popping over the platform toggle before the user has
  /// looked at the screen is worse than one tap.
  bool _returnedToEmail = false;

  @override
  void initState() {
    super.initState();
    _vm = LoginViewModel(auth: context.read<Services>().auth);
  }

  @override
  void dispose() {
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _otpFocus.dispose();
    _secretFocus.dispose();
    _vm.dispose();
    super.dispose();
  }

  // ── Handlers ────────────────────────────────────────────────────────

  /// Toast the request-level error, if there is one. Field-level errors are
  /// already on screen, so a failure that set only those stays silent here.
  void _toastRequestError() {
    final key = _vm.errorKey;
    final msg = key != null
        ? context.tr(key, _vm.errorParams)
        : _vm.errorMessage;
    if (msg != null) Notify.error(context, msg);
  }

  void _announce(String message) {
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  Future<void> _onContinue() async {
    final ok = await _vm.continueToCredentials();
    if (!mounted) return;
    if (ok) {
      _announce('${context.tr('password')} · ${_vm.email}');
    } else {
      _toastRequestError();
    }
  }

  void _onChangeEmail() {
    if (_vm.busy) return;
    _returnedToEmail = true;
    _vm.backToEmail();
    _announce(context.tr('email_address'));
  }

  Future<void> _onLogin() async {
    final ok = await _vm.submit();
    if (!mounted || ok) return;
    _toastRequestError();
    if (_vm.otpErrorKey != null ||
        _vm.fieldErrors.containsKey('one_time_password')) {
      _otpFocus.requestFocus();
    }
  }

  /// Enter moves to the first *required* field still empty, otherwise logs
  /// in — so a certain-to-fail login doesn't spend hosted's login throttle,
  /// while the common account (no 2FA, no secret) still submits on Enter. An
  /// optional field (precheck unanswered) never holds the submit back.
  void _onPasswordSubmitted() {
    if (_vm.otpConfirmed && _vm.oneTimePassword.isEmpty) {
      _otpFocus.requestFocus();
    } else if (_secretRequired && _vm.secret.isEmpty) {
      _secretFocus.requestFocus();
    } else {
      _onLogin();
    }
  }

  void _onOtpSubmitted() {
    if (_secretRequired && _vm.secret.isEmpty) {
      _secretFocus.requestFocus();
    } else {
      _onLogin();
    }
  }

  bool get _secretRequired => !_vm.isHosted && _vm.secretIsRequired;

  Future<void> _onRecover() async {
    final ok = await _vm.recover();
    if (!mounted) return;
    if (ok) {
      Notify.success(context, context.tr('password_reset_link_sent'));
      return;
    }
    _toastRequestError();
  }

  Future<void> _onGoogle() async {
    final ok = await _vm.submitGoogle();
    // A dismissed chooser returns false with no error — say nothing.
    if (mounted && !ok) _toastRequestError();
  }

  Future<void> _onApple() async {
    final ok = await _vm.submitApple();
    if (mounted && !ok) _toastRequestError();
  }

  Future<void> _onDisableTwoFactor() async {
    final sentTo = await showSendTwoFactorResetCodeDialog(context, vm: _vm);
    if (sentTo == null || !mounted) return;
    final disabled = await showConfirmTwoFactorResetDialog(
      context,
      vm: _vm,
      email: sentTo,
    );
    // The OTP field and this link are gone when the reset was for this
    // form's address; give focus somewhere that certainly still exists.
    if (disabled && mounted) _passwordFocus.requestFocus();
  }

  /// Hosted → in-app signup screen. Self-hosted doesn't offer it at all,
  /// matching React's hosted-only `/register` link.
  void _onSignup() => context.go('/signup');

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => PopScope(
        // Android back on step 2 returns to step 1 rather than leaving the
        // app. `/login` sits outside the shell, so `SystemBackGate` isn't
        // involved; go_router's `popRoute` → `maybePop` reaches this.
        canPop: _vm.step == LoginStep.email,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _onChangeEmail();
        },
        child: Scaffold(
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
                    child: _buildBody(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
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
          // One group for both steps, never keyed or rebuilt per step: its
          // default `onDisposeAction` is `commit`, so a group torn down on
          // "Change" would pop the OS "save password" prompt over a
          // half-typed password. It stays mounted until login leaves the
          // screen, which is exactly when the save prompt should fire.
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr('login'),
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: tokens.ink),
                ),
                SizedBox(height: InSpacing.lg(context)),
                if (_vm.step == LoginStep.email)
                  ..._emailStep(context)
                else
                  ..._credentialsStep(context),
                if (_vm.isHosted) ...[
                  const SizedBox(height: InSpacing.sm),
                  TextButton(
                    key: const ValueKey('login_signup'),
                    // Leaving mid-request would strand a login that still
                    // lands a session behind the signup screen.
                    onPressed: _vm.busy ? null : _onSignup,
                    child: Text(
                      context.tr('register_label'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_vm.isHosted) ...[
          SizedBox(height: InSpacing.md(context)),
          AuthSurfaceCard(
            shadow: tokens.shadow1,
            padding: const EdgeInsets.symmetric(vertical: InSpacing.xs),
            child: const _HostedLinks(),
          ),
        ],
        SizedBox(height: InSpacing.lg(context)),
        Text(
          'v${AppVersion.kClientVersion}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: tokens.ink3),
        ),
      ],
    );
  }

  /// Step 1: where to sign in, and who.
  List<Widget> _emailStep(BuildContext context) {
    final vm = _vm;
    final busy = vm.busy;
    final showSocial = vm.isHosted && (vm.googleEnabled || vm.appleEnabled);
    return [
      AuthEyebrowLabel(context.tr('select_platform').toUpperCase()),
      _SegmentedToggle<bool>(
        value: vm.isHosted,
        segments: [
          _Segment(value: true, label: context.tr('hosted')),
          _Segment(value: false, label: context.tr('self_hosted')),
        ],
        // Locked while Continue is in flight, so the answer can't land for a
        // server the user has already switched away from.
        onChanged: busy ? null : vm.setHosted,
      ),
      SizedBox(height: InSpacing.lg(context)),
      if (!vm.isHosted) ...[
        AuthField(
          key: const ValueKey('login_url'),
          label: context.tr('server_url'),
          hint: 'https://invoice.example.com  ·  http://192.168.0.10:8080',
          initialValue: vm.urlOverride,
          // Read-only rather than disabled while Continue is in flight: a
          // disabled field drops focus and doesn't give it back.
          readOnly: busy,
          keyboardType: TextInputType.url,
          autofillHints: const [AutofillHints.url],
          errorText: vm.urlErrorKey == null
              ? null
              : context.tr(vm.urlErrorKey!),
          textInputAction: TextInputAction.next,
          onChanged: vm.setUrlOverride,
          // Enter moves on to the email rather than submitting a form whose
          // email is still empty.
          onEditingComplete: () {},
          onSubmitted: (_) => _emailFocus.requestFocus(),
        ),
        SizedBox(height: InSpacing.md(context)),
      ],
      AuthField(
        key: const ValueKey('login_email'),
        label: context.tr('email_address'),
        focusNode: _emailFocus,
        autofocus: _returnedToEmail,
        initialValue: vm.email,
        keyboardType: TextInputType.emailAddress,
        errorText: vm.emailErrorKey != null
            ? context.tr(vm.emailErrorKey!)
            : vm.fieldErrors['email']?.first,
        autofillHints: const [AutofillHints.username, AutofillHints.email],
        // `next`, not `done`: Continue leads straight to the password field,
        // so the keyboard should stay up rather than close and reopen. The
        // no-op keeps the framework's own `nextFocus()` out of the way.
        textInputAction: TextInputAction.next,
        onEditingComplete: () {},
        onChanged: vm.setEmail,
        onSubmitted: (_) => _onContinue(),
      ),
      const SizedBox(height: InSpacing.xl),
      _PrimaryButton(
        buttonKey: const ValueKey('login_continue'),
        label: context.tr('continue'),
        spinning: vm.busyAction == LoginAction.continueToCredentials,
        onPressed: busy ? null : _onContinue,
      ),
      if (showSocial) ...[
        SizedBox(height: InSpacing.lg(context)),
        const AuthOrDivider(),
        SizedBox(height: InSpacing.lg(context)),
        // Google first, then Apple — React's order.
        if (vm.googleEnabled)
          OutlinedButton.icon(
            key: const ValueKey('login_google'),
            onPressed: busy ? null : _onGoogle,
            icon: vm.busyAction == LoginAction.google
                ? const _Spinner()
                : const Icon(Icons.account_circle_outlined, size: 18),
            label: Text(context.tr('sign_in_with_google')),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(InRadii.r2),
              ),
            ),
          ),
        if (vm.googleEnabled && vm.appleEnabled)
          SizedBox(height: InSpacing.md(context)),
        if (vm.appleEnabled)
          FilledButton.icon(
            key: const ValueKey('login_apple'),
            onPressed: busy ? null : _onApple,
            icon: vm.busyAction == LoginAction.apple
                ? _Spinner(color: context.inTheme.surface)
                : const Icon(Icons.apple, size: 18),
            label: Text(context.tr('sign_in_with_apple')),
            style: FilledButton.styleFrom(
              // Apple HIG: black-on-light, white-on-dark. `ink` already
              // inverts with brightness, so the button flips for free.
              backgroundColor: context.inTheme.ink,
              foregroundColor: context.inTheme.surface,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(InRadii.r2),
              ),
            ),
          ),
      ],
    ];
  }

  /// Step 2: only the credentials this account needs.
  List<Widget> _credentialsStep(BuildContext context) {
    final vm = _vm;
    final busy = vm.busy;
    final showOtp = vm.showOtpField;
    final showSecret = !vm.isHosted && vm.showSecretField;
    // `textInputAction` is fixed by which fields are *present*, never by what
    // they contain: EditableText only re-sends its configuration when
    // `obscureText` / `keyboardType` change, so an action that flipped while
    // the keyboard was up would never reach it. `next` only where a required
    // field follows; Enter then decides in `onSubmitted`.
    final passwordAction = (vm.otpConfirmed || _secretRequired)
        ? TextInputAction.next
        : TextInputAction.done;
    final otpAction = _secretRequired
        ? TextInputAction.next
        : TextInputAction.done;
    final otpLabel = '2FA - ${context.tr('one_time_password')}';
    return [
      // The address being signed in to, read-only. Still an autofill
      // participant, so the password manager pairs the password with this
      // username on save and fill — but `readOnly` rejects text an autofill
      // tries to write, the password-manager bug React fixed with a hidden
      // input (react 4beee0754).
      AuthField(
        key: const ValueKey('login_email_confirmed'),
        label: context.tr('email_address'),
        initialValue: vm.email,
        readOnly: true,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.username, AutofillHints.email],
        errorText: vm.fieldErrors['email']?.first,
        suffix: Padding(
          padding: const EdgeInsetsDirectional.only(end: InSpacing.xs),
          child: Tooltip(
            message: context.tr('change_email'),
            child: _LinkButton(
              buttonKey: const ValueKey('login_change'),
              label: context.tr('change'),
              onPressed: busy ? null : _onChangeEmail,
            ),
          ),
        ),
      ),
      SizedBox(height: InSpacing.md(context)),
      AuthPasswordField(
        key: const ValueKey('login_password'),
        label: context.tr('password'),
        focusNode: _passwordFocus,
        autofocus: true,
        initialValue: vm.password,
        errorText: vm.fieldErrors['password']?.first,
        textInputAction: passwordAction,
        // `onSubmitted` owns what Enter does. Without the no-op the framework
        // acts first: `next` runs `nextFocus()` (from here, the reveal
        // button) and `done` unfocuses, so a failed login would leave the
        // user typing into nothing.
        onEditingComplete: () {},
        onChanged: vm.setPassword,
        onSubmitted: (_) => _onPasswordSubmitted(),
        labelTrailing: _LinkButton(
          buttonKey: const ValueKey('login_forgot_password'),
          label: context.tr('forgot_password'),
          spinning: vm.busyAction == LoginAction.recover,
          onPressed: busy ? null : _onRecover,
        ),
      ),
      if (showOtp) ...[
        SizedBox(height: InSpacing.md(context)),
        AuthField(
          key: const ValueKey('login_otp'),
          // "(Optional)" only while the server hasn't said either way.
          label: vm.otpConfirmed
              ? otpLabel
              : '$otpLabel (${context.tr('optional')})',
          focusNode: _otpFocus,
          initialValue: vm.oneTimePassword,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          errorText: vm.otpErrorKey != null
              ? context.tr(vm.otpErrorKey!)
              : vm.fieldErrors['one_time_password']?.first,
          textInputAction: otpAction,
          // See the password field.
          onEditingComplete: () {},
          onChanged: vm.setOneTimePassword,
          onSubmitted: (_) => _onOtpSubmitted(),
        ),
        if (vm.isHosted && vm.otpConfirmed)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsets.only(top: InSpacing.xs),
              child: _LinkButton(
                buttonKey: const ValueKey('login_disable_2fa'),
                label: context.tr('disable_2fa'),
                onPressed: busy ? null : _onDisableTwoFactor,
              ),
            ),
          ),
      ],
      if (showSecret) ...[
        SizedBox(height: InSpacing.md(context)),
        // X-API-SECRET for self-hosted servers that set API_SECRET. Obscured
        // + reveal (config secrets are usually pasted). autofillHints null
        // excludes it from the login AutofillGroup so iOS/macOS won't offer
        // the saved account password here. Labelled required once the
        // precheck says so, "(Optional)" while it hasn't — but never blocked
        // client-side (see `LoginViewModel._missingRequiredOtp`).
        AuthPasswordField(
          key: const ValueKey('login_secret'),
          label: vm.secretIsRequired
              ? context.tr('api_secret')
              : '${context.tr('api_secret')} (${context.tr('optional')})',
          focusNode: _secretFocus,
          initialValue: vm.secret,
          autofillHints: null,
          textInputAction: TextInputAction.done,
          // See the password field.
          onEditingComplete: () {},
          onChanged: vm.setSecret,
          onSubmitted: (_) => _onLogin(),
        ),
      ],
      const SizedBox(height: InSpacing.xl),
      _PrimaryButton(
        buttonKey: const ValueKey('login_submit'),
        label: context.tr('login'),
        spinning: vm.busyAction == LoginAction.login,
        onPressed: busy ? null : _onLogin,
      ),
    ];
  }
}

// ─── Buttons ─────────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.buttonKey,
    required this.label,
    required this.spinning,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final bool spinning;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return FilledButton(
      key: buttonKey,
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: tokens.accent,
        foregroundColor: tokens.onAccent,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(InRadii.r2),
        ),
      ),
      child: spinning ? _Spinner(color: tokens.onAccent) : Text(label),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner({this.color, this.size = 16});

  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: color == null ? null : AlwaysStoppedAnimation(color),
      ),
    );
  }
}

/// A text link that is a real button (reachable by Tab, activatable by a
/// screen reader) — "Change", "Forgot your password?", "Disable 2FA".
///
/// Sized for the input device (docs/touch-targets.md): on touch it is laid
/// out at the app's 44 px floor ([InSizes.touchTarget]) — `shrinkWrap`, or
/// the `padded` theme would lay it out at 48; with a pointer it shrink-wraps
/// to its label so the label row it sits on stays one text line tall.
class _LinkButton extends StatelessWidget {
  const _LinkButton({
    required this.buttonKey,
    required this.label,
    required this.onPressed,
    this.spinning = false,
  });

  final Key buttonKey;
  final String label;
  final VoidCallback? onPressed;

  /// Shows a small spinner before the label while this link's own request is
  /// in flight — every control is disabled then, so without it the tap looks
  /// like it did nothing.
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    final touch = Env.isTouchPrimary;
    return TextButton(
      key: buttonKey,
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: context.inTheme.accentInk,
        // Derived from the theme, never a bare `TextStyle`: a button's
        // `textStyle` replaces the theme's outright, so a bare one drops the
        // app font family and the label falls back to the platform font.
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        padding: touch
            ? const EdgeInsets.symmetric(horizontal: InSpacing.sm)
            : const EdgeInsets.symmetric(horizontal: InSpacing.xs),
        minimumSize: touch
            ? const Size(InSizes.touchTarget, InSizes.touchTarget)
            : Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: touch ? VisualDensity.standard : VisualDensity.compact,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spinning) ...[
            _Spinner(size: 12, color: context.inTheme.accentInk),
            const SizedBox(width: InSpacing.xs),
          ],
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ─── Hosted links ────────────────────────────────────────────────────────

/// React's `HostedLinks` card, less "Applications" — the user is already in
/// one.
class _HostedLinks extends StatelessWidget {
  const _HostedLinks();

  @override
  Widget build(BuildContext context) {
    final status = TextButton.icon(
      key: const ValueKey('login_check_status'),
      onPressed: () => openExternalUrl(context, kStatusUrl),
      icon: const Icon(Icons.shield_outlined, size: 16),
      label: Text(context.tr('check_status')),
    );
    final docs = TextButton.icon(
      key: const ValueKey('login_documentation'),
      onPressed: () => openExternalUrl(context, kDocsUrl),
      icon: const Icon(Icons.menu_book_outlined, size: 16),
      label: Text(context.tr('documentation')),
    );
    if (Breakpoints.isGlobalNavVisible(context)) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [status, docs],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [status, docs],
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

  /// Null disables the toggle.
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final onChanged = this.onChanged;
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
                onTap: onChanged == null ? null : () => onChanged(s.value),
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
  final VoidCallback? onTap;

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
