import 'dart:async';

import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/ui/features/payments/view_models/payment_edit_view_model.dart';

/// The settings cascade's `payment_type_id` (Settings → Online Payments →
/// Default Payment Type) as a payment type id, or `''` for none. The server's
/// "no default" is `'0'` (`CompanySettings::$payment_type_id`), and the blob
/// is raw JSON, so an int arrives too.
String defaultPaymentTypeId(Map<String, dynamic> settings) {
  final raw = settings['payment_type_id'];
  final id = raw == null ? '' : raw.toString().trim();
  return id == '0' ? '' : id;
}

/// Seed a new payment's Type from the settings cascade — the client's
/// (client → group → company) once a client is chosen, the company's before.
///
/// The server never applies `payment_type_id` itself: a payment saved with a
/// blank type stays blank. v1 seeded it on every new payment
/// (`PaymentEntity` → `settings.defaultPaymentTypeId`) and React on the
/// create page (`company.settings.payment_type_id`); without this the user
/// picked "Check" on every payment though Check was their default.
///
/// Only a form that opens with no type seeds — a clone keeps its source's.
/// Every seed goes through [PaymentEditViewModel.seedTypeId], so none lands
/// on an edit form, mid-save, after a save, or once the user picked a type,
/// and none makes an untouched form dirty. The synchronous
/// [SettingsRepository.resolvedIfReady] answer seeds the first frame; the
/// awaited `resolved()` then corrects it.
///
/// The type follows the client while the user has not picked one: choosing
/// a client whose cascade names another type switches to it. A request token
/// drops a late answer for a client the user has already moved away from.
void seedPaymentCreateDefaults({
  required SettingsRepository settings,
  required String companyId,
  required PaymentEditViewModel vm,
}) {
  if (!vm.isCreate || vm.draft.typeId.isNotEmpty) return;
  var token = 0;

  void resolve() {
    final clientId = vm.draft.clientId.isEmpty ? null : vm.draft.clientId;
    final companyLevel = clientId == null;
    final request = ++token;
    final guess = settings.resolvedIfReady(
      companyId: companyId,
      clientId: clientId,
    );
    if (guess != null) {
      vm.seedTypeId(defaultPaymentTypeId(guess), companyLevel: companyLevel);
    }
    unawaited(
      settings
          .resolved(companyId: companyId, clientId: clientId)
          .then((resolved) {
            if (request != token || vm.isDisposed) return;
            vm.seedTypeId(
              defaultPaymentTypeId(resolved),
              companyLevel: companyLevel,
            );
          })
          .catchError((Object _) {}),
    );
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
