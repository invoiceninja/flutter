import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/client_picker_field.dart';
import 'package:admin/ui/features/billing_shared/view_models/billing_doc_edit_view_model.dart';
import 'package:admin/ui/features/clients/widgets/client_create_dialog.dart';

/// The Client field for the billing documents that share one picker shape —
/// invoice, quote, credit and recurring invoice. Replaces four byte-identical
/// private `_ClientPicker` copies.
///
/// Adds the inline "create client" affordance on top of [ClientPickerField]
/// by supplying the create dialog and re-seeding invitations once a
/// just-created client's contacts come back from the server with real ids.
class BillingDocClientPicker<T> extends StatefulWidget {
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
  State<BillingDocClientPicker<T>> createState() =>
      _BillingDocClientPickerState<T>();
}

class _BillingDocClientPickerState<T> extends State<BillingDocClientPicker<T>> {
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
