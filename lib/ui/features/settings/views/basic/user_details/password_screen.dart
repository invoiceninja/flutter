import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/features/settings/view_models/user_details_view_model.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

const kUserDetailsPasswordSearchKeys = <String>[
  'password',
  'new_password',
  'confirm_password',
];

class UserDetailsPasswordScreen extends StatefulWidget {
  const UserDetailsPasswordScreen({super.key});

  @override
  State<UserDetailsPasswordScreen> createState() =>
      _UserDetailsPasswordScreenState();
}

class _UserDetailsPasswordScreenState extends State<UserDetailsPasswordScreen> {
  late final TextEditingController _password;
  late final TextEditingController _confirm;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _password = TextEditingController();
    _confirm = TextEditingController();
    _password.addListener(_onChanged);
    _confirm.addListener(_onChanged);
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _onChanged() {
    final vm = context.read<UserDetailsViewModel>();
    final pw = _password.text;
    final cn = _confirm.text;
    final ready = pw.isNotEmpty && pw == cn && pw.length >= 8;
    vm.setPendingPassword(ready ? pw : null);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UserDetailsViewModel>();
    final fieldError = vm.fieldErrors['password']?.firstOrNull;
    final scope = FormSaveScope.maybeOf(context);
    return SettingsFormShell(
      sections: [
        // Correlates the pair so the OS offers to save the new password once,
        // rather than treating each field as an orphan. Wraps the *section*,
        // not its children: `FormSection._interleave` returns the list
        // untouched below two children, so collapsing the three children into
        // one AutofillGroup silently cut the gap between the fields from
        // 3x InSpacing.lg to 1x. AutofillGroup builds no RenderObject, so
        // wrapping out here changes no layout at all.
        AutofillGroup(
          child: FormSection(
            title: context.tr('password'),
            children: [
              TextField(
                controller: _password,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.visiblePassword,
                // `newPassword`, not `password`: this is a change-password form,
                // so the OS should offer to generate and save a new credential
                // rather than fill the existing one.
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: context.tr('new_password'),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    tooltip: _obscure
                        ? context.tr('show_password')
                        : context.tr('hide_password'),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  errorText: fieldError ?? _passwordError(),
                ),
                textInputAction: TextInputAction.next,
              ),
              SizedBox(height: InSpacing.lg(context)),
              TextField(
                controller: _confirm,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.visiblePassword,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: context.tr('confirm_password'),
                  errorText: _confirmError(),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: scope == null ? null : (_) => scope.trySubmit(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Client-side gate: minimum length only. Complexity (upper/lower/digit) is
  // left to the server's 422 so we never block a password the server accepts.
  String? _passwordError() {
    final pw = _password.text;
    if (pw.isEmpty) return null;
    if (pw.length < 8) return context.tr('password_is_too_short');
    return null;
  }

  String? _confirmError() {
    final pw = _password.text;
    final cn = _confirm.text;
    if (cn.isEmpty) return null;
    if (pw == cn) return null;
    return context.tr('passwords_do_not_match');
  }
}
