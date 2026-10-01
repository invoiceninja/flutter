import 'dart:async';

import 'package:flutter/material.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/confirm_password_sheet.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// Whether a hosted account still needs the signed-in user's first and last
/// name (React #3341 — the hosted billing side wants both). Never on
/// self-hosted, and never in a demo.
bool needsUserName(AuthSession? s) =>
    s != null &&
    s.isHosted &&
    !s.isDemo &&
    s.userId.isNotEmpty &&
    (s.userFirstName.trim().isEmpty || s.userLastName.trim().isEmpty);

/// Asks for the user's first and last name and saves them. With [required]
/// (before an upgrade) the upgrade can't go ahead without them — Cancel backs
/// out of the upgrade; otherwise it is a dismissible nudge (Skip). True only
/// once the server has the names, so a caller can gate on it.
///
/// The save is the same whole-record user PUT User Details queues — and that
/// endpoint is password-protected, so the password is asked for **first**
/// when the cache is cold (unless the user is exempt). Asking afterwards
/// would surface a password sheet with no context, after the dialog had
/// already said "saved".
Future<bool> promptForUserName(
  BuildContext context,
  Services services, {
  bool required = false,
}) async {
  final session = services.auth.session.value;
  if (session == null) return false;
  final names = await showDialog<({String first, String last})>(
    context: context,
    builder: (_) => _NameDialog(
      first: session.userFirstName,
      last: session.userLastName,
      required: required,
    ),
  );
  if (names == null || !context.mounted) return false;
  if (!services.passwordCache.isPrimed) {
    final ok = await showConfirmPasswordSheet(
      context,
      cache: services.passwordCache,
    );
    if (!ok || !context.mounted) return false;
  }
  try {
    final companyId = session.currentCompanyId;
    final user = await services.user.get(
      companyId: companyId,
      userId: session.userId,
    );
    if (user == null) return false;
    final draft = user.copyWith(firstName: names.first, lastName: names.last);
    // Same body as `UserDetailsViewModel._buildBody`: the whole record, minus
    // a blank `language_id` (Laravel rejects "" for the foreign key).
    final body = Map<String, dynamic>.from(draft.toApi().toJson());
    if (draft.languageId.isEmpty) body.remove('language_id');
    await services.user.enqueueUpdate(
      companyId: companyId,
      draft: draft,
      body: body,
      // `PUT /users/{id}` is `password_protected`; without the flag the
      // password just asked for is never attached and the PUT 412s.
      requiresPassword: true,
    );
    // Through now, so a checkout that follows sees the names server-side.
    // `drainOnce` reports a failed row (offline, rejected) by count, not by
    // throwing, so success is read off the session — which the user PUT's
    // response patches (`AuthRepository.applyUserUpdate`). A drain already
    // under way returns its own pass and only re-drains after it, hence the
    // second try.
    for (var i = 0; i < 2 && needsUserName(services.auth.session.value); i++) {
      await services.sync.drainOnce(companyId: companyId);
    }
    if (!needsUserName(services.auth.session.value)) return true;
    if (context.mounted) Notify.error(context, context.tr('could_not_save'));
    return false;
  } catch (e) {
    if (context.mounted) {
      Notify.error(context, context.tr('could_not_save'), error: e);
    }
    return false;
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.first,
    required this.last,
    required this.required,
  });

  final String first;
  final String last;
  final bool required;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _first = TextEditingController(
    text: widget.first,
  );
  late final TextEditingController _last = TextEditingController(
    text: widget.last,
  );
  bool _tried = false;

  bool get _valid =>
      _first.text.trim().isNotEmpty && _last.text.trim().isNotEmpty;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_valid) {
      setState(() => _tried = true);
      return;
    }
    Navigator.of(
      context,
    ).pop((first: _first.text.trim(), last: _last.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    String? errorFor(TextEditingController c, String key) =>
        _tried && c.text.trim().isEmpty ? context.tr(key) : null;
    return FormSaveScope(
      onSubmit: _submit,
      child: AlertDialog(
        title: Text(context.tr('user_details')),
        content: SizedBox(
          width: 400,
          child: AutofillGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _first,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  // The signed-in user's own identity — autofill is right.
                  autofillHints: const [AutofillHints.givenName],
                  decoration: InputDecoration(
                    labelText: context.tr('first_name'),
                    errorText: errorFor(_first, 'please_enter_a_first_name'),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _last,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.familyName],
                  decoration: InputDecoration(
                    labelText: context.tr('last_name'),
                    errorText: errorFor(_last, 'please_enter_a_last_name'),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          // Before an upgrade this backs out of the upgrade; otherwise it
          // skips the nudge for this launch. Esc, back and a tap outside do
          // the same.
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr(widget.required ? 'cancel' : 'skip')),
          ),
          PrimaryDialogAction(
            label: context.tr('save'),
            autofocus: false,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
