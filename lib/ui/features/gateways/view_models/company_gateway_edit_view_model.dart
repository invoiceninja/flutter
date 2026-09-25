import 'dart:async';

import 'package:admin/data/models/domain/company_gateway.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/company_gateway_repository.dart';
import 'package:admin/domain/gateway_constants.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';

/// Edit ViewModel for a single CompanyGateway. Mirrors the
/// `<Entity>EditViewModel` shape — extends [GenericEditViewModel] so the
/// shared edit scaffold (Save button, dirty guard, 422 banner) just works.
class CompanyGatewayEditViewModel extends GenericEditViewModel<CompanyGateway> {
  CompanyGatewayEditViewModel({
    required this.repo,
    required this.companyId,
    CompanyGateway? existing,
    String? initialGatewayKey,
    super.sync,
    super.connectivity,
  }) : super(
         initialDraft:
             existing ??
             CompanyGateway(
               gatewayKey: initialGatewayKey ?? '',
               requireContactEmail: true,
               requirePostalCode: true,
               tokenBilling: kAutoBillAlways,
               acceptedCreditCards: kAllCreditCardTypes,
             ),
         original: existing,
         companyId: companyId,
       );

  final CompanyGatewayRepository repo;
  final String companyId;

  /// Empty draft factory for the discard-changes path. Seeds the same
  /// sensible defaults the constructor uses for a brand-new row.
  CompanyGateway emptyDraft({String? gatewayKey}) => CompanyGateway(
    gatewayKey: gatewayKey ?? draft.gatewayKey,
    requireContactEmail: true,
    requirePostalCode: true,
    tokenBilling: kAutoBillAlways,
    acceptedCreditCards: kAllCreditCardTypes,
  );

  /// Apply a freezed `copyWith` to the draft. Tab widgets call into this
  /// via small typed setters below; expose it directly for one-off edits.
  void mutate(CompanyGateway Function(CompanyGateway) edit) {
    updateDraft(edit(draft));
  }

  /// Update a single key in the credentials JSON blob without callers having
  /// to decode/encode it themselves.
  void updateConfigField(String name, Object? value) {
    final next = Map<String, dynamic>.from(draft.parsedConfig);
    if (value == null || (value is String && value.isEmpty)) {
      next.remove(name);
    } else {
      next[name] = value;
    }
    updateDraft(draft.withConfig(next));
  }

  /// Toggle a payment type's enabled flag.
  void setTypeEnabled(String typeId, bool enabled) {
    final next = Map<String, FeesAndLimits>.from(draft.feesAndLimits);
    final current = next[typeId];
    if (current == null) {
      if (enabled) {
        next[typeId] = const FeesAndLimits(isEnabled: true);
      }
    } else {
      next[typeId] = current.copyWith(isEnabled: enabled);
    }
    updateDraft(draft.copyWith(feesAndLimits: next));
  }

  /// Replace one payment type's fees & limits block wholesale.
  void updateFees(String typeId, FeesAndLimits fees) {
    final next = Map<String, FeesAndLimits>.from(draft.feesAndLimits);
    next[typeId] = fees;
    updateDraft(draft.copyWith(feesAndLimits: next));
  }

  /// Routes a field-error key to its tab slug. Used by the screen's
  /// `TabBar` to render a red dot when a 422 lands on a non-active tab.
  String? errorTabSlug() {
    if (fieldErrors.isEmpty) return null;
    for (final key in fieldErrors.keys) {
      if (key.startsWith('config')) return 'credentials';
      if (key.startsWith('require_')) return 'required_fields';
      if (key.startsWith('fees_and_limits') && !key.endsWith('.is_enabled')) {
        return 'limits_and_fees';
      }
      if (key == 'label' ||
          key == 'token_billing' ||
          key.startsWith('fees_and_limits')) {
        return 'settings';
      }
    }
    return 'credentials';
  }

  @override
  Future<SaveResult<CompanyGateway>> performSave() async {
    if (savesAsCreate) {
      final result = await repo.create(
        companyId: companyId,
        draft: draft,
        existingTempId: recoveryTempId,
      );
      rememberCreateTempId(result.entity.id);
      return result;
    }
    return repo.save(companyId: companyId, gateway: draft);
  }
}
