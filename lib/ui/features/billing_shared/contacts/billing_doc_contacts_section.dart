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
    this.canSignByContactId,
    this.onCanSignChanged,
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

  /// DocuNinja's per-invitation "Authorized to sign" (`can_sign`), by contact
  /// id: null turns the row off (DocuNinja is off for the company), as React
  /// shows it only on `company.enable_modules`. A contact missing from the map
  /// is not invited; a null value is an invitation whose `can_sign` the app
  /// has not read yet, drawn as a dash rather than claimed false.
  final Map<String, bool?>? canSignByContactId;

  /// Fires when "Authorized to sign" toggles on an invited contact. React
  /// ignores a click on a contact that is not invited, and so does this.
  final void Function(String contactId, bool canSign)? onCanSignChanged;

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
            showCanSign: canSignByContactId != null,
            canSign: canSignByContactId?[contact.id],
            onCanSignChanged:
                onCanSignChanged == null ||
                    !selectedContactIds.contains(contact.id)
                ? null
                : (v) => onCanSignChanged!(contact.id, v),
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
    this.showCanSign = false,
    this.canSign,
    this.onCanSignChanged,
  });

  final BillingContact contact;
  final bool selected;
  final bool readOnly;
  final bool showCanSign;
  final bool? canSign;

  /// Null while the contact is not invited: the control then stays put, as
  /// React's does, and its label is dimmed.
  final ValueChanged<bool>? onCanSignChanged;

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
                  if (showCanSign)
                    _CanSignRow(
                      value: selected ? canSign : false,
                      invited: selected,
                      onChanged: readOnly ? null : onCanSignChanged,
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

/// React's "Authorized to sign" checkbox under an invited contact
/// (`ClientSelector.tsx`): which contacts DocuNinja asks to sign. Its label is
/// dimmed while the contact is not invited, and a tap on it then does nothing,
/// as in React. Its own tap target, so it never toggles the invitation.
class _CanSignRow extends StatelessWidget {
  const _CanSignRow({
    required this.value,
    required this.invited,
    required this.onChanged,
  });

  /// Null is an invitation whose `can_sign` the app has not read yet.
  final bool? value;
  final bool invited;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final label = context.tr('authorized_to_sign');
    final active = invited && onChanged != null;
    void toggle() => onChanged?.call(!(value ?? false));
    // Opaque and always claiming the tap: an inert row must still swallow it,
    // or it falls through to the contact row and invites the contact.
    return Semantics(
      container: true,
      label: label,
      checked: value ?? false,
      mixed: value == null,
      enabled: active,
      onTap: active ? toggle : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: active ? null : () {},
        child: InkWell(
          onTap: active ? toggle : null,
          borderRadius: BorderRadius.circular(InRadii.r1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AbsorbPointer(
                absorbing: !active,
                child: Checkbox(
                  tristate: value == null,
                  value: value,
                  onChanged: active ? (_) => toggle() : null,
                ),
              ),
              Flexible(
                child: Opacity(
                  opacity: invited ? 1 : 0.5,
                  child: Text(
                    label,
                    style: TextStyle(color: tokens.ink2, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
