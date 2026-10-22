import 'dart:async';

import 'package:decimal/decimal.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/billing_doc_fields.dart';
import 'package:admin/data/models/value/money.dart';
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

/// The document-level tax tiers a new document gets: slot `1..enabled`
/// takes the cascade's `tax_name<N>` / `tax_rate<N>` (the Tax Settings →
/// Default Tax Rate pickers, overridable per group and client), and a
/// tax-exempt client clears all three. A tier with no name is no tax, whatever
/// rate it carries. Slots past [enabledTaxRates] are left out, so the draft
/// keeps them.
///
/// The server does none of this: `InvoiceFactory` blanks every tier and the
/// store path never reads the default, so a client app that leaves the tiers
/// blank saves an untaxed document.
Map<int, ({String name, Decimal rate})> defaultTaxTiers(
  Map<String, dynamic> settings, {
  required int enabledTaxRates,
  required bool clientTaxExempt,
}) {
  // [billingPartyTaxExempt] — a vendor counts as the client here.
  if (clientTaxExempt) {
    return {for (var n = 1; n <= 3; n++) n: (name: '', rate: Decimal.zero)};
  }
  final tiers = <int, ({String name, Decimal rate})>{};
  for (var n = 1; n <= enabledTaxRates.clamp(0, 3); n++) {
    final name = (settings['tax_name$n'] ?? '').toString().trim();
    tiers[n] = name.isEmpty
        ? (name: '', rate: Decimal.zero)
        : (name: name, rate: parseMoney(settings['tax_rate$n']));
  }
  return tiers;
}

/// Whether a billing document's party — its client, or a purchase order's
/// vendor — is tax exempt. The server zeroes every document and line tax of
/// an exempt party when it totals the document (`InvoiceSum` /
/// `InvoiceItemSum`, `$invoice->client ?? $invoice->vendor`), so a default
/// tax the app puts on one would show in the totals and vanish on save. False
/// with no party, or one not in Drift.
Future<bool> billingPartyTaxExempt(
  Services services, {
  required String companyId,
  String clientId = '',
  String vendorId = '',
}) async {
  if (clientId.isNotEmpty) {
    final client = await services.clients
        .watch(companyId: companyId, id: clientId)
        .first;
    return client?.isTaxExempt ?? false;
  }
  if (vendorId.isNotEmpty) {
    final vendor = await services.vendors
        .watch(companyId: companyId, id: vendorId)
        .first;
    return vendor?.isTaxExempt ?? false;
  }
  return false;
}

/// The two facts [defaultTaxTiers] needs that the settings cascade does not
/// carry. [BillingTaxFacts.of] reads them from Drift.
class BillingTaxFacts {
  const BillingTaxFacts({
    required this.enabledTaxRates,
    required this.partyTaxExempt,
  });

  factory BillingTaxFacts.of(Services services, String companyId) =>
      BillingTaxFacts(
        enabledTaxRates: () async =>
            (await services.company.get(companyId))?.enabledTaxRates ?? 0,
        partyTaxExempt: ({clientId = '', vendorId = ''}) =>
            billingPartyTaxExempt(
              services,
              companyId: companyId,
              clientId: clientId,
              vendorId: vendorId,
            ),
      );

  /// The company's `enabled_tax_rates`: how many document-level tiers it uses.
  final Future<int> Function() enabledTaxRates;

  /// [billingPartyTaxExempt].
  final Future<bool> Function({String clientId, String vendorId})
  partyTaxExempt;
}

/// Seed a new billing document's inclusive-tax mode and default tax tiers
/// from the settings cascade.
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
/// Every create form, priced lines or not, also gets the resolved settings as
/// [BillingDocEditViewModel.createCascade], so it can show the terms, footer
/// and payment terms the server will fill in for a blank field.
///
/// The synchronous [SettingsRepository.resolvedIfReady] answer seeds the
/// first frame; the awaited `resolved()` — always run — then corrects it.
/// Both go through [BillingDocEditViewModel.seedUsesInclusiveTaxes], so
/// neither lands on an edit form, mid-save, after a save or a discard, once
/// the user flipped the switch, or once a line was priced; and neither makes
/// an untouched form dirty. Those guards are the inclusive-tax mode's only:
/// the cascade itself ([BillingDocEditViewModel.setCreateCascade]) is set on
/// every create, clone and priced form included, discard or not, and cleared
/// while a new party's answer is still out.
///
/// The tax tiers ([defaultTaxTiers]) are seeded from the awaited answer only,
/// through [BillingDocEditViewModel.seedTaxRates]: on any create form that
/// opened with every tier blank — a draft built with priced lines (from a
/// product, a task, an expense, a project) included, as in admin-portal and
/// React — except an [isClone] one, which copies its source's taxes, blank or
/// not (`Services.stageCreateDraft`'s `isClone`). Until the user types in a
/// tier. They need [taxFacts], and are skipped
/// without it. The exempt party is the client, or a purchase order's vendor.
///
/// A client document re-resolves when its client changes (picked, seeded from
/// a project, cleared), and a purchase order when its vendor does, under the
/// same guards. A request token drops a late
/// answer for a client the user has already moved away from. A purchase
/// order reads the company layer only: the server cascades
/// `inclusive_taxes` through a client, and a vendor document has none.
void seedBillingCreateDefaults<T extends BillingDocFields>({
  required SettingsRepository settings,
  required String companyId,
  required BillingDocType type,
  required BillingDocEditViewModel<T> vm,
  BillingTaxFacts? taxFacts,
  bool isClone = false,
}) {
  if (!vm.isCreate) return;
  // A clone or a produced draft keeps the mode it arrived with for good —
  // even once its lines are deleted — so only a form that opened seedable
  // ever seeds. The cascade itself is shown on every create.
  final seedsTaxes = vm.canSeedInclusiveTaxes;
  final d = vm.draft;
  final seedsTiers =
      !isClone &&
      taxFacts != null &&
      d.taxName1.isEmpty &&
      d.taxName2.isEmpty &&
      d.taxName3.isEmpty &&
      d.taxRate1 == Decimal.zero &&
      d.taxRate2 == Decimal.zero &&
      d.taxRate3 == Decimal.zero;
  final byClient = type.party == BillingDocParty.client;
  var token = 0;

  // The client, or a purchase order's vendor.
  String partyId() => byClient ? vm.clientId : vm.draft.vendorId;

  void resolve() {
    final clientId = byClient && vm.clientId.isNotEmpty ? vm.clientId : null;
    final companyLevel = clientId == null;
    final party = partyId();
    final request = ++token;
    final guess = settings.resolvedIfReady(
      companyId: companyId,
      clientId: clientId,
    );
    // No guess drops the previous party's cascade rather than leaving it on
    // screen as this one's until — or, on a failed fetch, for good.
    vm.setCreateCascade(guess);
    if (guess != null && seedsTaxes) {
      vm.seedUsesInclusiveTaxes(
        inclusiveTaxesSetting(guess),
        companyLevel: companyLevel,
      );
    }
    unawaited(
      settings
          .resolved(companyId: companyId, clientId: clientId)
          .then((resolved) async {
            if (request != token || vm.isDisposed) return;
            vm.setCreateCascade(resolved);
            if (seedsTaxes) {
              vm.seedUsesInclusiveTaxes(
                inclusiveTaxesSetting(resolved),
                companyLevel: companyLevel,
              );
            }
            final facts = taxFacts;
            if (!seedsTiers || facts == null) return;
            final enabled = await facts.enabledTaxRates();
            final exempt =
                party.isNotEmpty &&
                await (byClient
                    ? facts.partyTaxExempt(clientId: party)
                    : facts.partyTaxExempt(vendorId: party));
            if (request != token || vm.isDisposed) return;
            vm.seedTaxRates(
              defaultTaxTiers(
                resolved,
                enabledTaxRates: enabled,
                clientTaxExempt: exempt,
              ),
              // A Discard clears the party, so only a party-free answer is
              // the blank form's.
              companyLevel: party.isEmpty,
            );
          })
          .catchError((Object _) {}),
    );
  }

  resolve();
  // A purchase order's cascade is the company's whatever the vendor, but the
  // vendor decides whether its tax tiers stay blank.
  if (!byClient && !seedsTiers) return;
  var lastPartyId = partyId();
  vm.addListener(() {
    final party = partyId();
    if (party == lastPartyId) return;
    lastPartyId = party;
    // Whatever was asked for the previous party is stale now, even when
    // nothing is asked for this one.
    token++;
    // `seedUsesInclusiveTaxes` guards itself (behind [seedsTaxes]); the
    // cascade follows the client for as long as the form is a create.
    if (vm.isDisposed || !vm.isCreate) return;
    resolve();
  });
}
