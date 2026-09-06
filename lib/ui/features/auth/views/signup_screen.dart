import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/auth/view_models/signup_view_model.dart';
import 'package:admin/ui/features/auth/widgets/auth_fields.dart';

/// In-app account creation. Hosted-only (the login screen only routes here
/// when "Hosted" is selected; self-hosted keeps the external link). On
/// success the session activates and the router's auth-page redirect lands
/// the now-logged-in user on the post-login route automatically.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  late final SignupViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = SignupViewModel(auth: context.read<Services>().auth);
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
                  builder: (context, _) => _SignupBody(vm: _vm),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignupBody extends StatelessWidget {
  const _SignupBody({required this.vm});

  final SignupViewModel vm;

  String? _resolveError(BuildContext context) {
    if (vm.errorKey != null) return context.tr(vm.errorKey!, vm.errorParams);
    return vm.errorMessage;
  }

  Future<void> _onSubmit(BuildContext context) async {
    final ok = await vm.submit();
    if (!context.mounted) return;
    if (ok) {
      Notify.success(context, context.tr('account_created'));
      return; // router redirect lands the now-authenticated user
    }
    final msg = _resolveError(context);
    if (msg != null) Notify.error(context, msg);
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
          child: FormSaveScope(
            onSubmit: () => _onSubmit(context),
            enabled: !vm.busy,
            // Correlates email + password so the OS / password manager offers
            // to save them together. Without it the hints below still fill,
            // but the "save password" prompt never fires — same reasoning as
            // `login_screen.dart`, which has had this since it shipped.
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthEyebrowLabel(context.tr('create_account').toUpperCase()),
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
                    errorText: vm.fieldErrors['password']?.first,
                    onChanged: vm.setPassword,
                    // `newPassword`, not the widget's `password` default: this
                    // is account creation, so the OS should offer to generate
                    // and save rather than fill an existing credential.
                    autofillHints: const [AutofillHints.newPassword],
                  ),
                  SizedBox(height: InSpacing.md(context)),
                  AuthPasswordField(
                    label: context.tr('confirm_password'),
                    onChanged: vm.setConfirmPassword,
                    onSubmitted: vm.busy ? null : (_) => _onSubmit(context),
                    autofillHints: const [AutofillHints.newPassword],
                  ),
                  SizedBox(height: InSpacing.md(context)),
                  _TermsCheckbox(
                    value: vm.acceptedTerms,
                    onChanged: vm.setAcceptedTerms,
                  ),
                  const SizedBox(height: InSpacing.xl),
                  FilledButton.icon(
                    key: const ValueKey('signup_submit'),
                    onPressed: vm.busy ? null : () => _onSubmit(context),
                    icon: vm.busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.person_add_alt_1, size: 18),
                    label: Text(context.tr('sign_up')),
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(InRadii.r2),
                      ),
                    ),
                  ),
                  const SizedBox(height: InSpacing.sm),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: Text(context.tr('login')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(InRadii.r1),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
            const SizedBox(width: InSpacing.xs),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '${context.tr('i_agree')} '
                  '(${context.tr('terms_of_service')} · '
                  '${context.tr('privacy_policy')})',
                  style: TextStyle(fontSize: 13, color: tokens.ink2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
