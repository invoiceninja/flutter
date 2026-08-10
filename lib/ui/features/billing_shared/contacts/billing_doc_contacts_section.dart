import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/billing/billing_contact.dart';
import 'package:admin/l10n/localization.dart';

/// Re-usable invitations list. Renders one row per client contact with a
/// checkbox that toggles whether the contact is included in the billing
/// doc's `invitations` array.
///
/// Inputs are entity-agnostic — the caller (e.g. `InvoiceEditViewModel`)
/// maps the checkbox state to / from the underlying `Invitation` list and
/// supplies the contact list (typically from `client.contacts`).
class BillingDocContactsSection extends StatelessWidget {
  const BillingDocContactsSection({
    super.key,
    required this.contacts,
    required this.selectedContactIds,
    required this.onChanged,
    this.readOnly = false,
  });

  /// Available contacts to invite. Callers map their concrete contact
  /// type (`Contact` for clients; `VendorContact` for vendors) via the
  /// `.toBilling()` extension defined on [BillingContact].
  final List<BillingContact> contacts;

  /// Currently-included contact ids — the set carried inside the billing
  /// doc's `invitations[].client_contact_id` array.
  final Set<String> selectedContactIds;

  /// Fires with the new selection set whenever a checkbox toggles. The
  /// caller is responsible for mapping back to `Invitation` rows (i.e.
  /// adding/removing the corresponding row).
  final ValueChanged<Set<String>> onChanged;

  /// When true, render checkboxes disabled. Used during save/in-flight
  /// states to prevent racing changes mid-write.
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        child: Text(
          context.tr('no_contacts'),
          style: TextStyle(color: context.inTheme.ink3),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final contact in contacts)
          _ContactRow(
            contact: contact,
            selected: selectedContactIds.contains(contact.id),
            readOnly: readOnly,
            // Contact ids are server-minted, so an empty one means this
            // contact hasn't synced yet (its client was created offline, or
            // inline from a billing-doc picker). The server has no row to
            // attach an invitation to and would 422 the save, so the row is
            // shown disabled — not hidden, which would read as data loss on a
            // freshly created client.
            unsynced: contact.id.isEmpty,
            onTap: () {
              final next = Set<String>.from(selectedContactIds);
              if (next.contains(contact.id)) {
                next.remove(contact.id);
              } else {
                next.add(contact.id);
              }
              onChanged(next);
            },
          ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.contact,
    required this.selected,
    required this.readOnly,
    required this.unsynced,
    required this.onTap,
  });

  final BillingContact contact;
  final bool selected;
  final bool readOnly;

  /// Contact has no server id yet — selectable only once its client syncs.
  final bool unsynced;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final disabled = readOnly || unsynced;
    final fullName = [
      contact.firstName,
      contact.lastName,
    ].where((s) => s.isNotEmpty).join(' ');
    final displayName = fullName.isEmpty
        ? (contact.email.isEmpty ? context.tr('unnamed') : contact.email)
        : fullName;
    return InkWell(
      onTap: disabled ? null : onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: InSpacing.lg(context),
          vertical: 8,
        ),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: disabled ? null : (_) => onTap(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      color: unsynced ? tokens.ink3 : tokens.ink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (fullName.isNotEmpty && contact.email.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        contact.email,
                        style: TextStyle(color: tokens.ink3, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            if (unsynced) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: context.tr('contact_available_after_sync'),
                child: Icon(
                  Icons.cloud_upload_outlined,
                  size: 15,
                  color: tokens.ink3,
                ),
              ),
            ],
            if (contact.isLocked) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: context
                    .tr('user_unsubscribed')
                    .replaceAll(':link', '')
                    .trim(),
                child: Icon(
                  Icons.error_outline,
                  size: 15,
                  color: tokens.overdue,
                ),
              ),
            ],
            if (contact.isPrimary) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tokens.accentSoft,
                  borderRadius: BorderRadius.circular(InRadii.r1),
                ),
                child: Text(
                  context.tr('primary'),
                  style: TextStyle(
                    color: tokens.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
