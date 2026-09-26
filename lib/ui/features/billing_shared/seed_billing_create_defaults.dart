import 'dart:async';

import 'package:admin/data/models/domain/billing/billing_doc_fields.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/view_models/billing_doc_edit_view_model.dart';

/// The settings cascade's `inclusive_taxes`, read leniently: the settings
/// blob is raw JSON, so the flag can arrive as a bool, an int or a string.
/// Absent means off — the server's own default.
bool inclusiveTaxesSetting(Map<String, dynamic> settings) =>
    switch (settings['inclusive_taxes']) {
      true || 1 || '1' || 'true' => true,
      _ => false,
    };

/// The inclusive-tax mode a new document gets: the client's cascade
/// (client → group → company) for a client document, the company's alone
/// without a [clientId]. For a producer that builds a document's lines before
/// the edit screen opens — a line's cost is a net or a gross amount depending
/// on this mode, so the producer must know it first and stage it on the
/// draft (the edit screen never re-seeds a draft that arrives with lines).
Future<bool> resolveCreateInclusiveTaxes(
  SettingsRepository settings, {
  required String companyId,
  String? clientId,
}) async => inclusiveTaxesSetting(
  await settings.resolved(
    companyId: companyId,
    clientId: (clientId == null || clientId.isEmpty) ? null : clientId,
  ),
);

/// Seed a new billing document's inclusive-tax mode from the settings
/// cascade, the way the server does on create.
///
/// `empty*()` hard-code `usesInclusiveTaxes: false` and the app always sends
/// the field, so it overrode the server's `$client->getSetting(
/// 'inclusive_taxes')` — every new document of an inclusive-tax company was
/// saved exclusive, and its totals added the tax on top of prices that
/// already carried it.
///
/// Only a document that opens with no priced line: a clone, a cross-clone, a
/// recurring → invoice or an expense → invoice arrives with lines priced in a
/// fixed mode, and a producer that builds lines stages the mode itself
/// ([resolveCreateInclusiveTaxes]).
///
/// The synchronous [SettingsRepository.resolvedIfReady] answer seeds the
/// first frame; the awaited `resolved()` — always run — then corrects it.
/// Both go through [BillingDocEditViewModel.seedUsesInclusiveTaxes], so
/// neither lands on an edit form, mid-save, after a save or a discard, once
/// the user flipped the switch, or once a line was priced; and neither makes
/// an untouched form dirty.
///
/// A client document re-resolves when its client changes (picked, seeded from
/// a project, cleared), under the same guards. A request token drops a late
/// answer for a client the user has already moved away from. A purchase
/// order reads the company layer only: the server cascades
/// `inclusive_taxes` through a client, and a vendor document has none.
void seedBillingCreateDefaults<T extends BillingDocFields>({
  required SettingsRepository settings,
  required String companyId,
  required BillingDocType type,
  required BillingDocEditViewModel<T> vm,
}) {
  if (!vm.canSeedInclusiveTaxes) return;
  final byClient = type.party == BillingDocParty.client;
  var token = 0;

  void resolve() {
    final clientId = byClient && vm.clientId.isNotEmpty ? vm.clientId : null;
    final companyLevel = clientId == null;
    final request = ++token;
    final guess = settings.resolvedIfReady(
      companyId: companyId,
      clientId: clientId,
    );
    if (guess != null) {
      vm.seedUsesInclusiveTaxes(
        inclusiveTaxesSetting(guess),
        companyLevel: companyLevel,
      );
    }
    unawaited(
      settings
          .resolved(companyId: companyId, clientId: clientId)
          .then((resolved) {
            if (request != token || vm.isDisposed) return;
            vm.seedUsesInclusiveTaxes(
              inclusiveTaxesSetting(resolved),
              companyLevel: companyLevel,
            );
          })
          .catchError((Object _) {}),
    );
  }

  resolve();
  if (!byClient) return;
  var lastClientId = vm.clientId;
  vm.addListener(() {
    final clientId = vm.clientId;
    if (clientId == lastClientId) return;
    lastClientId = clientId;
    // Whatever was asked for the previous client is stale now, even when
    // nothing is asked for this one.
    token++;
    if (vm.isDisposed || !vm.canSeedInclusiveTaxes) return;
    resolve();
  });
}
