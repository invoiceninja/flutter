import 'package:flutter/material.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/data/models/value/parsing.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/billing_shared/email/recipient_email_state.dart';

/// Loads the contacts of a document's client ([clientId]) or vendor
/// ([vendorId]) from the local cache, hydrating the party first when it was
/// never browsed. Null when it still can't be found (offline) — callers treat
/// that as [RecipientEmailState.unknown].
Future<Map<String, EmailContact>?> loadEmailContacts(
  Services services, {
  required String companyId,
  String clientId = '',
  String vendorId = '',
}) async {
  try {
    if (clientId.isNotEmpty) {
      await services.clients.ensureLoaded(companyId: companyId, id: clientId);
      final client = await services.clients
          .watch(companyId: companyId, id: clientId)
          .first;
      return emailContactsOfClient(client);
    }
    if (vendorId.isNotEmpty) {
      await services.vendors.ensureLoaded(companyId: companyId, id: vendorId);
      final vendor = await services.vendors
          .watch(companyId: companyId, id: vendorId)
          .first;
      return emailContactsOfVendor(vendor);
    }
  } catch (_) {
    // A failed hydrate is "can't tell", never "no email".
    return null;
  }
  return const <String, EmailContact>{};
}

/// Asks for the address [contactLabel] should be emailed at. Null on cancel.
Future<String?> showAddContactEmailDialog(
  BuildContext context, {
  required String contactLabel,
}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => _AddContactEmailDialog(
      controller: controller,
      contactLabel: contactLabel,
    ),
  );
  controller.dispose();
  return result;
}

class _AddContactEmailDialog extends StatefulWidget {
  const _AddContactEmailDialog({
    required this.controller,
    required this.contactLabel,
  });

  final TextEditingController controller;
  final String contactLabel;

  @override
  State<_AddContactEmailDialog> createState() => _AddContactEmailDialogState();
}

class _AddContactEmailDialogState extends State<_AddContactEmailDialog> {
  bool _invalid = false;

  void _submit() {
    final email = widget.controller.text.trim();
    if (!isLikelyEmailAddress(email)) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(email);
  }

  @override
  Widget build(BuildContext context) {
    return FormSaveScope(
      onSubmit: _submit,
      child: AlertDialog(
        title: Text(context.tr('add_email')),
        content: TextField(
          controller: widget.controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: context.tr('email'),
            helperText: widget.contactLabel.isEmpty
                ? null
                : widget.contactLabel,
            errorText: _invalid ? context.tr('email_is_invalid') : null,
          ),
          onChanged: (_) {
            if (_invalid) setState(() => _invalid = false);
          },
          onSubmitted: (_) => _submit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('cancel')),
          ),
          PrimaryDialogAction(
            label: context.tr('save'),
            // The field owns focus and submits on Enter.
            autofocus: false,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

/// Writes [email] onto contact [contactId] of the client / vendor through the
/// ordinary save — so it is queued in the outbox **ahead of** the send that
/// needs it (strict FIFO per company), works offline, and turns the
/// document's existing invitation deliverable. Returns false (having told the
/// user) when the party or contact can't be found or the save fails.
Future<bool> saveContactEmail(
  BuildContext context,
  Services services, {
  required String companyId,
  String clientId = '',
  String vendorId = '',
  required String contactId,
  required String email,
}) async {
  try {
    if (clientId.isNotEmpty) {
      final client = await services.clients
          .watch(companyId: companyId, id: clientId)
          .first;
      if (client == null) return false;
      await services.clients.save(
        companyId: companyId,
        client: client.copyWith(
          contacts: [
            for (final c in client.contacts)
              c.id == contactId ? c.copyWith(email: email) : c,
          ],
        ),
      );
      return true;
    }
    if (vendorId.isNotEmpty) {
      final vendor = await services.vendors
          .watch(companyId: companyId, id: vendorId)
          .first;
      if (vendor == null) return false;
      await services.vendors.save(
        companyId: companyId,
        vendor: vendor.copyWith(
          contacts: [
            for (final c in vendor.contacts)
              c.id == contactId ? c.copyWith(email: email) : c,
          ],
        ),
      );
      return true;
    }
  } catch (e) {
    if (context.mounted) {
      Notify.error(context, context.tr('could_not_save'), error: e);
    }
  }
  return false;
}

/// Runs the whole inline fix: ask for an address for the contact the
/// document is addressed to, then save it. True once it is saved.
Future<bool> addMissingRecipientEmail(
  BuildContext context,
  Services services, {
  required String companyId,
  String clientId = '',
  String vendorId = '',
  required Iterable<Invitation> invitations,
  required Map<String, EmailContact> contacts,
}) async {
  final target = contactToAddEmailTo(invitations, contacts);
  if (target == null) return false;
  final email = await showAddContactEmailDialog(
    context,
    contactLabel: target.label,
  );
  if (email == null || !context.mounted) return false;
  return saveContactEmail(
    context,
    services,
    companyId: companyId,
    clientId: clientId,
    vendorId: vendorId,
    contactId: target.id,
    email: email,
  );
}

enum _NoEmailChoice { addEmail, edit, proceed }

/// Gate for a send that fires **without** the compose screen (recurring Send
/// Now, a payment receipt): when the recipient has no email, says so and
/// offers the two ways forward — add one inline (then continue), or open the
/// client / vendor. True when the send may go ahead. Unknown never blocks.
///
/// [invitations] null means the send has none and goes to the client's
/// primary contact instead — a payment receipt (`EmailPayment` picks the
/// contact ordered `is_primary desc`).
///
/// [allowProceed] adds a third way forward, **Send anyway**, for a send that
/// does more than email: recurring Send Now always creates the invoice and
/// only emails it when there is an address, so a client billed on paper
/// must still be able to use it.
Future<bool> ensureRecipientEmail(
  BuildContext context,
  Services services, {
  required String companyId,
  String clientId = '',
  String vendorId = '',
  required Iterable<Invitation>? invitations,
  bool allowProceed = false,
}) async {
  final contacts = await loadEmailContacts(
    services,
    companyId: companyId,
    clientId: clientId,
    vendorId: vendorId,
  );
  final addressed = invitations ?? _primaryContactInvitation(contacts);
  if (!context.mounted) return false;
  return _ensureRecipientEmail(
    context,
    services,
    companyId: companyId,
    clientId: clientId,
    vendorId: vendorId,
    invitations: addressed,
    contacts: contacts,
    allowProceed: allowProceed,
  );
}

/// A stand-in invitation for the contact a send without invitations goes to
/// — the primary one, else the first.
List<Invitation> _primaryContactInvitation(
  Map<String, EmailContact>? contacts,
) {
  if (contacts == null || contacts.isEmpty) return const [];
  final primary = contacts.values.firstWhere(
    (c) => c.isPrimary,
    orElse: () => contacts.values.first,
  );
  return [Invitation(id: '', clientContactId: primary.id)];
}

Future<bool> _ensureRecipientEmail(
  BuildContext context,
  Services services, {
  required String companyId,
  required String clientId,
  required String vendorId,
  required Iterable<Invitation> invitations,
  required Map<String, EmailContact>? contacts,
  required bool allowProceed,
}) async {
  final state = recipientEmailState(
    invitations: invitations,
    contacts: contacts,
  );
  if (state != RecipientEmailState.none) return true;
  if (!context.mounted || contacts == null) return false;
  final isVendor = clientId.isEmpty && vendorId.isNotEmpty;
  final canAdd = contactToAddEmailTo(invitations, contacts) != null;
  final choice = await showDialog<_NoEmailChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        ctx.tr(isVendor ? 'vendor_email_not_set' : 'client_email_not_set'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(ctx.tr('cancel')),
        ),
        if (allowProceed)
          TextButton(
            key: const ValueKey('no_email_send_anyway'),
            onPressed: () => Navigator.of(ctx).pop(_NoEmailChoice.proceed),
            child: Text(ctx.tr('send_anyway')),
          ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: () => Navigator.of(ctx).pop(_NoEmailChoice.edit),
          child: Text(ctx.tr(isVendor ? 'edit_vendor' : 'edit_client')),
        ),
        if (canAdd)
          PrimaryDialogAction(
            label: ctx.tr('add_email'),
            onPressed: () => Navigator.of(ctx).pop(_NoEmailChoice.addEmail),
          ),
      ],
    ),
  );
  if (!context.mounted) return false;
  switch (choice) {
    case _NoEmailChoice.addEmail:
      return addMissingRecipientEmail(
        context,
        services,
        companyId: companyId,
        clientId: clientId,
        vendorId: vendorId,
        invitations: invitations,
        contacts: contacts,
      );
    case _NoEmailChoice.proceed:
      return true;
    case _NoEmailChoice.edit:
      goEntityEdit(
        context,
        isVendor ? '/vendors' : '/clients',
        isVendor ? vendorId : clientId,
      );
      return false;
    case null:
      return false;
  }
}

/// Bulk-send preflight for [EntityListBulkAction.preflight]: drops the
/// documents whose recipient has no email (invoiceninja/ui#3400) and says
/// which, so the user doesn't compose an email for twenty invoices and have
/// three go nowhere. Skip-and-continue, not stop-at-first: one client without
/// an address shouldn't hold the rest of the batch hostage. Unknown never
/// drops. Null when the user cancels, or when nothing is left to send.
Future<List<Object?>?> preflightRecipientEmails<T>(
  BuildContext context,
  Services services, {
  required String companyId,
  required List<Object?> eligible,
  required String Function(T doc) clientIdOf,
  String Function(T doc)? vendorIdOf,
  required List<Invitation> Function(T doc) invitationsOf,
  required String Function(T doc) numberOf,
  bool keepUnaddressed = false,
}) async {
  final byParty = <String, Map<String, EmailContact>?>{};
  final kept = <Object?>[];
  final dropped = <T>[];
  for (final item in eligible) {
    final doc = item as T;
    final clientId = clientIdOf(doc);
    final vendorId = clientId.isEmpty ? (vendorIdOf?.call(doc) ?? '') : '';
    final key = clientId.isNotEmpty ? 'client:$clientId' : 'vendor:$vendorId';
    final contacts = byParty.containsKey(key)
        ? byParty[key]
        : byParty[key] = await loadEmailContacts(
            services,
            companyId: companyId,
            clientId: clientId,
            vendorId: vendorId,
          );
    final state = recipientEmailState(
      invitations: invitationsOf(doc),
      contacts: contacts,
    );
    (state == RecipientEmailState.none ? dropped : kept).add(doc);
  }
  if (dropped.isEmpty) return kept;
  if (!context.mounted) return null;
  // Recurring Send Now creates every invoice whether or not it can email it:
  // say which won't be emailed, and keep them all.
  if (keepUnaddressed) {
    final go = await _confirmUnaddressed(context, dropped, numberOf);
    return go ? [...kept, ...dropped] : null;
  }
  final proceed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.tr('no_email_on_file')),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ctx.tr('no_email_will_be_skipped')),
              const SizedBox(height: 8),
              for (final doc in dropped)
                Text(numberOf(doc).isEmpty ? '•' : '• #${numberOf(doc)}'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(ctx.tr(kept.isEmpty ? 'close' : 'cancel')),
        ),
        if (kept.isNotEmpty)
          PrimaryDialogAction(
            label: ctx.tr('continue'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
      ],
    ),
  );
  return proceed == true ? kept : null;
}

Future<bool> _confirmUnaddressed<T>(
  BuildContext context,
  List<T> unaddressed,
  String Function(T doc) numberOf,
) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.tr('no_email_on_file')),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ctx.tr('no_email_invoices_not_emailed')),
              const SizedBox(height: 8),
              for (final doc in unaddressed)
                Text(numberOf(doc).isEmpty ? '•' : '• #${numberOf(doc)}'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(ctx.tr('cancel')),
        ),
        PrimaryDialogAction(
          label: ctx.tr('continue'),
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
  return go == true;
}
