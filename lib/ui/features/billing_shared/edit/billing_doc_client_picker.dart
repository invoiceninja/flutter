import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/client_picker_field.dart';
import 'package:admin/ui/core/widgets/locked_entity_field_row.dart';
import 'package:admin/ui/features/billing_shared/view_models/billing_doc_edit_view_model.dart';
import 'package:admin/ui/features/clients/widgets/client_create_dialog.dart';

/// The Client field for the billing documents that share one picker shape —
/// invoice, quote, credit and recurring invoice. Replaces four byte-identical
/// private `_ClientPicker` copies.
///
/// **Once the document exists the client is frozen**, and this is where all
/// four learn that. Every one of these four server UPDATE requests pins the
/// field to its current value —
/// `$rules['client_id'] = ['bail','sometimes','integer', Rule::in([$this->invoice->client_id])]`
/// (`UpdateInvoiceRequest`, and the identical shape in Quote / Credit /
/// RecurringInvoice) — so a changed client 422s with "The selected client id is
/// invalid", and the user is left with a `SaveFailedBanner` offering Retry and
/// Discard, neither of which can ever succeed. Worse, the optimistic Drift
/// write has already landed the new client, so the record reads wrong locally
/// until the dead row is discarded. That is invoiceninja/flutter#158; the fix
/// is to stop offering the edit and say why.
///
/// The predicate is `!vm.isCreate` and nothing else. It freezes only a record
/// that exists — including one created offline, whose queued `update` follows
/// rather than supersedes its queued `create`
/// (`BaseEntityRepository.dedupPendingMutations` keys on the mutation KIND), so
/// it reaches the server as an update and is rejected exactly the same way.
///
/// It deliberately does **not** also test `clientId.isNotEmpty`. That guard was
/// tried and removed: on a saved record the server pins the client to its
/// current value, so a live picker there can only ever 422 or be silently
/// discarded — offering one is a lie, not a rescue. An empty client renders a
/// muted em dash with no tap target, and the helper line still explains it, so
/// it is not the silent dead box `docs/pickers.md` § A picker's empty state has
/// to say something warns about. (`Store*Request` makes `client_id` required,
/// so a synced record cannot reach that state anyway.)
///
/// On the create path it adds the inline "create client" affordance on top of
/// [ClientPickerField] by supplying the create dialog and re-seeding
/// invitations once a just-created client's contacts come back from the server
/// with real ids.
class BillingDocClientPicker<T> extends StatelessWidget {
  const BillingDocClientPicker({
    super.key,
    required this.vm,
    required this.companyId,
    this.createClient,
  });

  final GenericBillingDocEditViewModel<T> vm;

  /// Passed explicitly: each concrete billing VM declares its own
  /// `companyId`, so the shared base can't expose one.
  final String companyId;

  /// Opens the create UI. Defaults to [showClientCreateDialog]; overridden in
  /// tests so the create → commit → contacts-land sequence can be driven
  /// without standing up the whole dialog.
  @visibleForTesting
  final Future<Client?> Function(BuildContext context, String initialName)?
  createClient;

  @override
  Widget build(BuildContext context) {
    if (!vm.isCreate) {
      return LockedClientFieldRow(
        clientId: vm.clientId,
        // Clone is the way to bill a different client, and it exists on all
        // four of these. A bare prohibition is a dead end — naming the exit is
        // what #158 actually asked for.
        helperText: context.tr('locked_after_save_clone'),
        errorText: vm.fieldErrorFor('client_id'),
      );
    }
    // Only the create path needs the stateful half, so the locked row never
    // mounts the contacts watch or the inline-create machinery at all.
    return _EditableClientPicker<T>(
      vm: vm,
      companyId: companyId,
      createClient: createClient,
    );
  }
}

class _EditableClientPicker<T> extends StatefulWidget {
  const _EditableClientPicker({
    required this.vm,
    required this.companyId,
    this.createClient,
  });

  final GenericBillingDocEditViewModel<T> vm;
  final String companyId;
  final Future<Client?> Function(BuildContext context, String initialName)?
  createClient;

  @override
  State<_EditableClientPicker<T>> createState() =>
      _EditableClientPickerState<T>();
}

class _EditableClientPickerState<T> extends State<_EditableClientPicker<T>> {
  StreamSubscription<Client?>? _contactWatch;

  /// Id of the inline-created client whose contacts we're waiting on. Held so
  /// the `onSelected` that immediately follows the create — the picker commits
  /// the new client the moment the dialog returns — doesn't cancel the watch it
  /// just armed.
  String? _watchedClientId;

  @override
  void dispose() {
    _cancelWatch();
    super.dispose();
  }

  void _cancelWatch() {
    _contactWatch?.cancel();
    _contactWatch = null;
    _watchedClientId = null;
  }

  /// A client created inline has contacts with no ids yet (the server mints
  /// them), so `selectClient` deliberately seeds no invitations — shipping one
  /// with a blank `client_contact_id` 422s the document save.
  ///
  /// That leaves the Contacts tab conspicuously empty compared with every
  /// other client, so watch this one client until its contacts land and seed
  /// then. `watch` resolves the tmp id through `id_remap`, so it keeps
  /// tracking across the create's sync.
  void _reseedInvitationsWhenContactsLand(String clientId, Services services) {
    _cancelWatch();
    _watchedClientId = clientId;
    _contactWatch = services.clients
        .watch(companyId: widget.companyId, id: clientId)
        .listen((client) {
          if (!mounted || client == null) return;
          if (!client.contacts.any((c) => c.id.isNotEmpty)) return;
          // The user may have moved on to a different client, or ticked
          // contacts by hand — never clobber either.
          if (widget.vm.clientId != clientId || widget.vm.hasInvitations) {
            _cancelWatch();
            return;
          }
          _cancelWatch();
          // Safe to notify straight from here: Drift delivers stream events on
          // the event loop, never inside a build/layout pass. Deferring to a
          // post-frame callback would be worse than useless — nothing has
          // marked the tree dirty, so no frame is necessarily coming and the
          // seed could simply never run.
          widget.vm.seedClientInvitationsIfEmpty(client.contacts);
        });
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    return ClientPickerField(
      companyId: widget.companyId,
      selectedClientId: vm.clientId,
      label: context.tr('client'),
      errorText: vm.fieldErrorFor('client_id'),
      onSelected: (c) {
        // Picking a *different* client abandons the pending re-seed; the
        // commit that immediately follows an inline create must not.
        if (c?.id != _watchedClientId) _cancelWatch();
        vm.selectClient(c?.id ?? '', c?.contacts ?? const []);
      },
      onCreateRequested: (ctx, initialName) async {
        // Resolved before the await — `ctx` must not be used across it.
        final services = context.read<Services>();
        final open = widget.createClient;
        final created = open != null
            ? await open(ctx, initialName)
            : await showClientCreateDialog(
                ctx,
                companyId: widget.companyId,
                initialName: initialName,
              );
        if (created != null && mounted) {
          _reseedInvitationsWhenContactsLand(created.id, services);
        }
        return created;
      },
    );
  }
}
