import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';

/// State holder for Settings → Payment Types: the company's
/// `settings.hidden_payment_types` and its payment-type names in
/// `settings.translations` (docs/payment-types.md). Company scope only. All
/// lifecycle plumbing lives on [SettingsDraftViewModel].
class PaymentTypesSettingsViewModel extends SettingsDraftViewModel {
  PaymentTypesSettingsViewModel({
    required super.repo,
    required super.companyId,
  });
}
