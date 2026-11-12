import 'dart:async';

import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/ui/features/payments/view_models/payment_edit_view_model.dart';

/// The settings cascade's `payment_type_id` (Settings → Online Payments →
/// Default Payment Type) as a payment type id, or `''` for none. The server's
/// "no default" is `'0'` (`CompanySettings::$payment_type_id`), and the blob
/// is raw JSON, so an int arrives too.
String defaultPaymentTypeId(Map<String, dynamic>? settings) {
  final raw = settings?['payment_type_id'];
  final id = raw == null ? '' : raw.toString().trim();
  return id == '0' ? '' : id;
}

/// What [seedPaymentCreateDefaults] reads about the chosen client, beyond
/// the settings cascade. Each is a seam so the precedence can be tested
/// without a database or a server.
class PaymentClientLookups {
  const PaymentClientLookups({
    required this.clientOverride,
    required this.lastPaymentType,
    required this.refreshLastPayment,
    this.hiddenTypeIds,
  });

  /// The client's OWN `payment_type_id` (its sparse settings, not the
  /// cascade) — `''` when it sets none.
  final Future<String> Function(String clientId) clientOverride;

  /// The type of the client's latest manual payment on this device
  /// (`PaymentRepository.lastManualTypeForClient`).
  final Future<String?> Function(String clientId) lastPaymentType;

  /// Pull the client's newest payments from the server; true when it ran
  /// (`PaymentRepository.refreshLatestForClient`).
  final Future<bool> Function(String clientId) refreshLastPayment;

  /// Types the company hides from the pickers — a hidden last payment type is
  /// passed over for the settings default.
  final Set<String> Function()? hiddenTypeIds;
}

/// Seed a new payment's Type — the server never fills it in: a payment saved
/// with a blank type stays blank.
///
/// Precedence (invoiceninja/flutter#191, docs/payment-types.md):
///
///  1. a Default Payment Type set on the CLIENT itself;
///  2. the type of the client's last manual payment (unless the company
///     hides that type);
///  3. the settings cascade — the client's group, then the company.
///
/// Without a client, only 3 (the company's). v1 seeded 3 on every new
/// payment and React the company's; neither remembered the client's last.
///
/// Each client change starts one chain that works out the winner and seeds
/// it; a request token drops the chain of a client the user has already
/// moved away from, so answers arriving in any order can't overturn the
/// precedence. Step 2 reads Drift first (so it works offline), then once per
/// client per session asks the server for the client's newest payments and
/// reads again — the device may never have paged them in.
///
/// Only a form that opens with no type seeds — a clone keeps its source's.
/// Every seed goes through [PaymentEditViewModel.seedTypeId], so none lands
/// on an edit form, mid-save, after a save, or once the user picked a type,
/// and none makes an untouched form dirty. The synchronous
/// [SettingsRepository.resolvedIfReady] answer seeds the first frame from
/// the cascade; the chain then corrects it.
void seedPaymentCreateDefaults({
  required SettingsRepository settings,
  required String companyId,
  required PaymentEditViewModel vm,
  PaymentClientLookups? client,
}) {
  if (!vm.isCreate || vm.draft.typeId.isNotEmpty) return;
  var token = 0;

  Future<void> run(int request, String? clientId) async {
    bool stale() => request != token || vm.isDisposed;
    final companyLevel = clientId == null;

    String cascade;
    try {
      cascade = defaultPaymentTypeId(
        await settings.resolved(companyId: companyId, clientId: clientId),
      );
    } catch (_) {
      cascade = '';
    }
    if (stale()) return;

    void seedCascade() => vm.seedTypeId(cascade, companyLevel: companyLevel);

    final lookups = client;
    if (clientId == null || lookups == null) return seedCascade();

    // 1. The client's own setting — the cascade already resolved it.
    String override;
    try {
      override = await lookups.clientOverride(clientId);
    } catch (_) {
      override = '';
    }
    if (stale()) return;
    if (override.isNotEmpty && override != '0') return seedCascade();

    // 2. The client's last manual payment, else 3. the cascade.
    final hidden = lookups.hiddenTypeIds?.call() ?? const <String>{};
    Future<bool> seedLast() async {
      String? last;
      try {
        last = await lookups.lastPaymentType(clientId);
      } catch (_) {
        last = null;
      }
      if (stale()) return false;
      if (last == null || last.isEmpty || hidden.contains(last)) {
        seedCascade();
      } else {
        vm.seedTypeId(
          last,
          companyLevel: false,
          source: last == cascade
              ? PaymentTypeSeedSource.settings
              : PaymentTypeSeedSource.lastPayment,
        );
      }
      return true;
    }

    if (!await seedLast()) return;
    bool refreshed;
    try {
      refreshed = await lookups.refreshLastPayment(clientId);
    } catch (_) {
      refreshed = false;
    }
    if (refreshed && !stale()) await seedLast();
  }

  void resolve() {
    final clientId = vm.draft.clientId.isEmpty ? null : vm.draft.clientId;
    final request = ++token;
    final guess = settings.resolvedIfReady(
      companyId: companyId,
      clientId: clientId,
    );
    if (guess != null) {
      vm.seedTypeId(
        defaultPaymentTypeId(guess),
        companyLevel: clientId == null,
      );
    }
    unawaited(run(request, clientId));
  }

  resolve();
  var lastClientId = vm.draft.clientId;
  vm.addListener(() {
    final clientId = vm.draft.clientId;
    if (clientId == lastClientId) return;
    lastClientId = clientId;
    // Whatever was asked for the previous client is stale now.
    token++;
    if (vm.isDisposed || !vm.canSeedTypeId) return;
    resolve();
  });
}
