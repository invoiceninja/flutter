import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/value/language.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_custom_fields_section.dart';
import 'package:admin/ui/core/widgets/markdown_text_field.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/settings/settings_actions.dart';
import 'package:admin/ui/features/settings/view_models/user_details_view_model.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';
import 'package:admin/ui/features/settings/widgets/settings_text_field.dart';

/// Search keys for the Settings > User Details > Details tab. Colocated so
/// the search catalog stays in sync with what this screen renders — see
/// `lib/ui/features/settings/settings_search_catalog.dart`.
const kUserDetailsDetailsSearchKeys = <String>[
  'first_name',
  'last_name',
  'email',
  'phone',
  'document_language',
  'signature',
  'sign_out',
];

class UserDetailsDetailsScreen extends StatelessWidget {
  const UserDetailsDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserDetailsViewModel>(
      builder: (context, vm, _) {
        if (!vm.isLoaded || !vm.draftReady) {
          return const Center(child: CircularProgressIndicator());
        }
        return SettingsFormShell(
          sections: [
            FormSection(
              title: context.tr('profile'),
              children: const [_DetailsForm()],
            ),
            const _SignOutSection(),
          ],
        );
      },
    );
  }
}

class _DetailsForm extends StatelessWidget {
  const _DetailsForm();

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final vm = context.watch<UserDetailsViewModel>();
    final user = vm.user;
    if (user == null) return const SizedBox.shrink();

    final languages = services.statics.languages.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final activeLanguage = languages
        .where((l) => l.id == user.languageId)
        .cast<Language?>()
        .firstWhere((_) => true, orElse: () => null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NameRow(user: user, vm: vm),
        SizedBox(height: InSpacing.lg(context)),
        SettingsTextField(
          labelText: context.tr('email'),
          initialValue: user.email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          // The signed-in user's own record, so OS autofill is correct here.
          // A client / vendor / contact field must NEVER carry hints — the
          // platform would offer the admin's own details for someone else.
          autofillHints: const [AutofillHints.email],
          errorText: vm.fieldErrors['email']?.firstOrNull,
          onChanged: (v) => vm.updateUser((u) => u.copyWith(email: v.trim())),
        ),
        SizedBox(height: InSpacing.lg(context)),
        SettingsTextField(
          labelText: context.tr('phone'),
          initialValue: user.phone,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          errorText: vm.fieldErrors['phone']?.firstOrNull,
          onChanged: (v) => vm.updateUser((u) => u.copyWith(phone: v.trim())),
        ),
        SizedBox(height: InSpacing.lg(context)),
        SearchableDropdownField<Language>(
          label: context.tr('document_language'),
          items: languages,
          initialValue: activeLanguage,
          displayString: (l) => l.name,
          idOf: (l) => l.id,
          onChanged: (l) =>
              vm.updateUser((u) => u.copyWith(languageId: l?.id ?? '')),
          errorText: vm.fieldErrors['language_id']?.firstOrNull,
        ),
        SizedBox(height: InSpacing.lg(context)),
        MarkdownTextField(
          label: context.tr('signature'),
          initialValue: user.signature,
          height: 180,
          onChanged: (v) => vm.updateUser((u) => u.copyWith(signature: v)),
        ),
        // User custom fields (`user1..4`) — type-aware, gated by the company's
        // configured labels; renders nothing when none are set.
        EntityCustomFieldsSection(
          keyPrefix: 'user',
          companyStream: services.company.watchCompany(
            services.auth.session.value?.currentCompanyId ?? '',
          ),
          formatter: services.formatterIfReady(
            services.auth.session.value?.currentCompanyId ?? '',
          ),
          wrapInCard: false,
          values: [
            user.customValue1,
            user.customValue2,
            user.customValue3,
            user.customValue4,
          ],
          onChanged: [
            (v) => vm.updateUser((u) => u.copyWith(customValue1: v)),
            (v) => vm.updateUser((u) => u.copyWith(customValue2: v)),
            (v) => vm.updateUser((u) => u.copyWith(customValue3: v)),
            (v) => vm.updateUser((u) => u.copyWith(customValue4: v)),
          ],
        ),
      ],
    );
  }
}

/// First name + last name share a row on wide screens, stack on narrow.
class _NameRow extends StatelessWidget {
  const _NameRow({required this.user, required this.vm});
  final dynamic user;
  final UserDetailsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final firstField = SettingsTextField(
      labelText: context.tr('first_name'),
      initialValue: user.firstName as String,
      errorText: vm.fieldErrors['first_name']?.firstOrNull,
      onChanged: (v) => vm.updateUser((u) => u.copyWith(firstName: v.trim())),
      textCapitalization: TextCapitalization.words,
      autofillHints: const [AutofillHints.givenName],
    );
    final lastField = SettingsTextField(
      labelText: context.tr('last_name'),
      initialValue: user.lastName as String,
      errorText: vm.fieldErrors['last_name']?.firstOrNull,
      onChanged: (v) => vm.updateUser((u) => u.copyWith(lastName: v.trim())),
      textCapitalization: TextCapitalization.words,
      autofillHints: const [AutofillHints.familyName],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              firstField,
              SizedBox(height: InSpacing.lg(context)),
              lastField,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: firstField),
            SizedBox(width: InSpacing.md(context)),
            Expanded(child: lastField),
          ],
        );
      },
    );
  }
}

/// Right-aligned Sign Out section. Wrapped in its own FormSection so it
/// reads as a discrete area below the profile fields.
class _SignOutSection extends StatefulWidget {
  const _SignOutSection();

  @override
  State<_SignOutSection> createState() => _SignOutSectionState();
}

class _SignOutSectionState extends State<_SignOutSection> {
  bool _busy = false;

  Future<void> _onSignOutPressed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(dialogCtx.tr('sign_out')),
          content: Text(dialogCtx.tr('are_you_sure')),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(dialogCtx.tr('cancel')),
            ),
            PrimaryDialogAction(
              variant: DialogActionVariant.destructive,
              label: dialogCtx.tr('sign_out'),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    await SettingsActions.signOut(context);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: context.tr('sign_out'),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _onSignOutPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
              minimumSize: const Size(64, 40),
            ),
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            label: Text(context.tr('sign_out')),
          ),
        ),
      ],
    );
  }
}
