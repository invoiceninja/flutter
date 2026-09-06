import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/contact.dart';
import 'package:admin/data/services/device_contacts_service.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/clients/view_models/client_edit_view_model.dart';
import 'package:admin/ui/core/edit/entity_custom_fields_section.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/core/widgets/labeled_switch_group.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';

/// "Contacts" card on the client edit screen. Renders every contact inline,
/// each with its own First/Last/Email/Phone block plus a header row carrying
/// the primary-toggle star and (when 2+ contacts) a delete button.
///
/// "+ Add contact" sits at the bottom of the card.
///
/// Each `_ContactEditor` is keyed by the contact's id (or list index when
/// the id is empty — fresh contacts haven't been allocated server-side yet)
/// so adding/removing siblings doesn't recycle a `TextEditingController`
/// onto a different contact's data.
class ClientEditContactsSection extends StatelessWidget {
  const ClientEditContactsSection({super.key, required this.vm});

  final ClientEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final services = context.read<Services>();
    // Drives the per-contact custom fields (gated by the company's
    // `contact1..4` labels), same source the Details card uses for `client*`.
    final companyStream = services.company.watchCompany(vm.companyId);
    final formatter = services.formatterIfReady(vm.companyId);
    final contacts = vm.draft.contacts;
    final canDelete = contacts.length > 1;
    return DashboardCardShell(
      title: context.tr('contacts'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (contacts.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: InSpacing.md(context)),
              child: Text(
                context.tr('no_contacts_yet'),
                style: TextStyle(color: tokens.ink3),
              ),
            )
          else
            for (var i = 0; i < contacts.length; i++) ...[
              if (i > 0) ...[
                const SizedBox(height: InSpacing.sm),
                Divider(height: 1, thickness: 1, color: tokens.border),
                const SizedBox(height: InSpacing.sm),
              ],
              _ContactEditor(
                key: ValueKey(_contactKey(contacts[i], i)),
                index: i,
                contact: contacts[i],
                canDelete: canDelete,
                companyStream: companyStream,
                formatter: formatter,
                onMakePrimary: () => vm.setContactPrimary(i),
                onDelete: () => vm.removeContact(i),
                onFirstName: (v) => vm.setContactFirstNameAt(i, v),
                onLastName: (v) => vm.setContactLastNameAt(i, v),
                onEmail: (v) => vm.setContactEmailAt(i, v),
                onPhone: (v) => vm.setContactPhoneAt(i, v),
                onSendEmail: (v) => vm.setContactSendEmailAt(i, v),
                onCcOnly: (v) => vm.setContactCcOnlyAt(i, v),
                onCanSign: (v) => vm.setContactCanSignAt(i, v),
                onPassword: (v) => vm.setContactPasswordAt(i, v),
                onCustomValue1: (v) => vm.setContactCustomValue1At(i, v),
                onCustomValue2: (v) => vm.setContactCustomValue2At(i, v),
                onCustomValue3: (v) => vm.setContactCustomValue3At(i, v),
                onCustomValue4: (v) => vm.setContactCustomValue4At(i, v),
              ),
            ],
          SizedBox(height: InSpacing.md(context)),
          FilledButton.tonalIcon(
            onPressed: vm.addContact,
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: Text(context.tr('add_contact')),
            style: FilledButton.styleFrom(
              backgroundColor: tokens.accentSoft,
              foregroundColor: tokens.accentInk,
            ),
          ),
          // Native address-book import (iOS). Hidden on web / non-iOS where the
          // device contacts service reports unavailable.
          if (services.deviceContacts.isAvailable) ...[
            const SizedBox(height: InSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => _importFromDevice(context),
              icon: const Icon(Icons.perm_contact_calendar_outlined, size: 18),
              label: Text(context.tr('add_from_contacts')),
            ),
          ],
        ],
      ),
    );
  }

  /// Launch the OS contact picker, merge the chosen contact into the draft
  /// (non-destructively), and report the outcome. The whole import is one draft
  /// mutation, so the toast's Undo restores everything at once.
  Future<void> _importFromDevice(BuildContext context) async {
    final services = context.read<Services>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final DeviceContactImport? picked;
    try {
      picked = await services.deviceContacts.pickContact();
    } catch (e) {
      if (context.mounted) {
        Notify.error(
          context,
          context.tr('add_from_contacts'),
          error: e,
          messenger: messenger,
        );
      }
      return;
    }
    if (picked == null) return; // user cancelled
    if (!context.mounted) return;

    final before = vm.draft;
    final countryId = resolveCountryId(
      services.statics.countries.values,
      iso2: picked.countryIso,
      name: picked.countryName,
    );
    final result = vm.applyImportedContact(picked, countryId: countryId);

    if (result.changedNothing) {
      Notify.warning(
        context,
        context.tr('no_contact_details_found'),
        messenger: messenger,
      );
      return;
    }

    final summary = _importSummary(context, result);
    final undo = NotifyAction(
      context.tr('undo'),
      () => vm.restoreDraft(before),
    );

    if (result.contactWasDuplicate) {
      // The picked person already exists, so don't claim we imported them.
      // Client fields may still have filled — offer Undo + a summary then.
      Notify.info(
        context,
        context.tr('already_a_contact', {'name': picked.displayLabel}),
        detail: result.appliedChanges ? summary : null,
        action: result.appliedChanges ? undo : null,
        messenger: messenger,
      );
      return;
    }

    // Not a duplicate → a person and/or client fields were imported.
    final title = picked.displayLabel.isNotEmpty
        ? context.tr('imported_contact', {'name': picked.displayLabel})
        : context.tr('add_from_contacts');
    Notify.success(
      context,
      title,
      detail: summary,
      action: undo,
      messenger: messenger,
    );
  }

  /// "Name · Address · Contact" — the fields the import filled, for the toast
  /// detail line. Tokens map to existing localization keys.
  String _importSummary(BuildContext context, ContactImportResult result) {
    final parts = <String>[
      for (final field in result.filledClientFields) context.tr(field),
      if (result.contactAdded) context.tr('contact'),
    ];
    return parts.join('  ·  ');
  }

  /// Stable key per contact row so the editor's internal text controllers
  /// follow the contact across sibling add/remove. Real contact ids are
  /// stable; brand-new contacts (id == '') fall back to `'new_<index>'`,
  /// which is fine because new rows are only ever appended at the end.
  String _contactKey(Contact c, int index) =>
      c.id.isNotEmpty ? c.id : 'new_$index';
}

class _ContactEditor extends StatelessWidget {
  const _ContactEditor({
    super.key,
    required this.index,
    required this.contact,
    required this.canDelete,
    required this.companyStream,
    required this.formatter,
    required this.onMakePrimary,
    required this.onDelete,
    required this.onFirstName,
    required this.onLastName,
    required this.onEmail,
    required this.onPhone,
    required this.onSendEmail,
    required this.onCcOnly,
    required this.onCanSign,
    required this.onPassword,
    required this.onCustomValue1,
    required this.onCustomValue2,
    required this.onCustomValue3,
    required this.onCustomValue4,
  });

  final int index;
  final Contact contact;
  final bool canDelete;
  final Stream<Company?> companyStream;
  final Formatter? formatter;
  final VoidCallback onMakePrimary;
  final VoidCallback onDelete;
  final ValueChanged<String> onFirstName;
  final ValueChanged<String> onLastName;
  final ValueChanged<String> onEmail;
  final ValueChanged<String> onPhone;
  final ValueChanged<bool> onSendEmail;
  final ValueChanged<bool> onCcOnly;
  final ValueChanged<bool> onCanSign;
  final ValueChanged<String> onPassword;
  final ValueChanged<String> onCustomValue1;
  final ValueChanged<String> onCustomValue2;
  final ValueChanged<String> onCustomValue3;
  final ValueChanged<String> onCustomValue4;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final headerLabel = contact.isPrimary
        ? context.tr('primary_contact')
        : context.tr('contact_with_index', {'index': '${index + 1}'});
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: context.tr(
                contact.isPrimary ? 'primary_contact' : 'make_primary',
              ),
              onPressed: contact.isPrimary ? null : onMakePrimary,
              icon: Icon(
                contact.isPrimary ? Icons.star : Icons.star_border,
                size: 20,
                color: contact.isPrimary ? tokens.accent : tokens.ink3,
              ),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              // 40px min touch target (icon stays small; the tap area grows
              // toward the 44px platform minimum without bloating the header).
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
            const SizedBox(width: InSpacing.xs),
            Expanded(
              child: Text(
                headerLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.ink3,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            if (canDelete)
              IconButton(
                tooltip: context.tr('remove_contact'),
                onPressed: onDelete,
                icon: Icon(Icons.close, size: 18, color: tokens.overdue),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                // 40px min touch target (icon stays small; the tap area grows
                // toward the 44px platform minimum without bloating the header).
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
          ],
        ),
        const SizedBox(height: InSpacing.xs),
        EntityEditField(
          label: context.tr('first_name'),
          initial: contact.firstName,
          onChanged: onFirstName,
          textCapitalization: TextCapitalization.words,
        ),
        EntityEditField(
          label: context.tr('last_name'),
          initial: contact.lastName,
          onChanged: onLastName,
          textCapitalization: TextCapitalization.words,
        ),
        EntityEditField(
          label: context.tr('email'),
          initial: contact.email,
          onChanged: onEmail,
          keyboardType: TextInputType.emailAddress,
        ),
        EntityEditField(
          label: context.tr('phone'),
          initial: contact.phone,
          onChanged: onPhone,
          keyboardType: TextInputType.phone,
        ),
        // Portal password is only meaningful when the company enables portal
        // passwords — React + admin-portal both gate this field on
        // `enable_client_portal_password`. Hidden until the company resolves,
        // so it never flickers in for a workspace that has the feature off.
        // (An already-set password is preserved on save regardless — it stays
        // in the draft and `Contact.toApiJson` still emits it.)
        StreamBuilder<Company?>(
          stream: companyStream,
          builder: (context, snapshot) {
            final portalPasswordEnabled =
                snapshot.data?.settings.enableClientPortalPassword ?? false;
            if (!portalPasswordEnabled) return const SizedBox.shrink();
            return EntityEditField(
              label: context.tr('password'),
              initial: contact.password,
              onChanged: onPassword,
              // The contact's portal credential, not the signed-in user's:
              // obscured behind a reveal toggle, and deliberately NO
              // autofillHints — the OS must not offer the admin's own saved
              // password here, nor offer to save this one as theirs.
              obscureText: true,
              keyboardType: TextInputType.visiblePassword,
              autocorrect: false,
            );
          },
        ),
        // Per-contact custom fields (contact1..4). Renders inline, gated by
        // the company's configured labels — invisible when none are set.
        EntityCustomFieldsSection(
          keyPrefix: 'contact',
          companyStream: companyStream,
          formatter: formatter,
          wrapInCard: false,
          values: [
            contact.customValue1,
            contact.customValue2,
            contact.customValue3,
            contact.customValue4,
          ],
          onChanged: [
            onCustomValue1,
            onCustomValue2,
            onCustomValue3,
            onCustomValue4,
          ],
        ),
        StreamBuilder<Company?>(
          stream: companyStream,
          builder: (context, snapshot) {
            // "Authorized to sign" is only meaningful when the company requires
            // an e-signature somewhere (invoice / quote / PO). Hidden otherwise
            // — the value is preserved on save regardless (it stays in the
            // draft and `Contact.toApiJson` still emits `can_sign`).
            final settings = snapshot.data?.settings;
            final eSignEnabled =
                (settings?.requireInvoiceSignature ?? false) ||
                (settings?.requireQuoteSignature ?? false) ||
                (settings?.requirePurchaseOrderSignature ?? false);
            return LabeledSwitchGroup(
              items: [
                LabeledSwitchItem(
                  label: context.tr('add_to_invoices'),
                  value: contact.sendEmail,
                  // CC-only and send_email are mutually exclusive; greyed out
                  // (onChanged: null) while CC-only is on.
                  onChanged: contact.ccOnly ? null : onSendEmail,
                ),
                LabeledSwitchItem(
                  label: context.tr('cc_only'),
                  value: contact.ccOnly,
                  onChanged: onCcOnly,
                ),
                if (eSignEnabled)
                  LabeledSwitchItem(
                    label: context.tr('authorized_to_sign'),
                    value: contact.canSign,
                    onChanged: onCanSign,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
