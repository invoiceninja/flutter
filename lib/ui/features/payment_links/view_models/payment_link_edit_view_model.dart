import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:admin/data/models/domain/payment_link.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/payment_link_repository.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';

/// Drives the Payment Link edit + create screen. Tab-aware: owns the
/// steps catalog state (async-fetched once) and the latest server-side
/// validation errors. Side-effect resets (turning off a toggle clears
/// the dependent field) live here so the draft stays coherent across
/// re-renders.
class PaymentLinkEditViewModel extends GenericEditViewModel<PaymentLink> {
  PaymentLinkEditViewModel({
    required this.repo,
    required this.companyId,
    PaymentLink? existing,
    PaymentLink? cloneFrom,
    super.useCommaAsDecimalPlace,
    super.sync,
    super.connectivity,
  }) : super(
         initialDraft: cloneFrom ?? existing ?? emptyPaymentLink(),
         original: existing,
         companyId: companyId,
       );

  final PaymentLinkRepository repo;
  final String companyId;

  // -------- Steps tab state --------

  List<PaymentLinkStep>? _availableSteps;
  bool _stepsLoading = false;
  String? _stepsError;
  List<String> _serverStepErrors = const <String>[];
  Timer? _checkDebounce;
  // Bumped every time a server check is (re)scheduled so a slow earlier
  // response can't overwrite the errors from a newer step edit.
  int _checkSeq = 0;

  /// Step catalog fetched from `GET /subscriptions/steps`. Null until
  /// the tab first opens; the screen kicks [loadSteps] in its initState.
  List<PaymentLinkStep>? get availableSteps => _availableSteps;
  bool get stepsLoading => _stepsLoading;
  String? get stepsError => _stepsError;

  /// Server-reported step ordering errors (the rare case the
  /// client-side dependency check doesn't cover). Refreshed on a 300ms
  /// debounce after every change to the step list.
  List<String> get serverStepErrors => _serverStepErrors;

  /// Test-only seam to bypass the network fetch. Lets unit tests assert
  /// `missingDependencyAt` against a known catalog.
  @visibleForTesting
  void seedStepsForTest(List<PaymentLinkStep> steps) {
    _availableSteps = steps;
    notifyListeners();
  }

  Future<void> loadSteps() async {
    if (_availableSteps != null || _stepsLoading) return;
    _stepsLoading = true;
    _stepsError = null;
    notifyListeners();
    try {
      _availableSteps = await repo.listSteps();
    } catch (e) {
      _stepsError = e.toString();
    } finally {
      _stepsLoading = false;
      // The screen may have unmounted while the fetch was in flight.
      if (!isDisposed) notifyListeners();
    }
  }

  /// Current draft's ordered step ids as a list. Mirrors the storage
  /// convention (comma-joined string).
  List<String> get orderedStepIds {
    final raw = draft.steps;
    if (raw.isEmpty) return const <String>[];
    return raw.split(',');
  }

  void setSteps(List<String> ids) {
    updateDraft(draft.copyWith(steps: ids.join(',')));
    _scheduleServerCheck(ids);
  }

  void addStep(String id) {
    final current = orderedStepIds;
    if (current.contains(id)) return;
    setSteps([...current, id]);
  }

  void removeStep(int index) {
    final current = orderedStepIds;
    if (index < 0 || index >= current.length) return;
    final next = [...current]..removeAt(index);
    setSteps(next);
  }

  void reorderStep(int oldIndex, int newIndex) {
    final current = [...orderedStepIds];
    if (oldIndex < 0 ||
        oldIndex >= current.length ||
        newIndex < 0 ||
        newIndex > current.length) {
      return;
    }
    final item = current.removeAt(oldIndex);
    current.insert(newIndex, item);
    setSteps(current);
  }

  /// Per-row missing-dependency check. Pure local — computed from the
  /// `dependencies` list returned by [loadSteps]. Returns the *first*
  /// missing dependency id for the given step at `index`, or null when
  /// the step is satisfied. The Steps tab renders a red dot + tooltip
  /// when this isn't null.
  String? missingDependencyAt(int index) {
    final ids = orderedStepIds;
    if (index < 0 || index >= ids.length) return null;
    final catalog = _availableSteps;
    if (catalog == null) return null;
    final stepId = ids[index];
    final step = catalog
        .where((s) => s.id == stepId)
        .cast<PaymentLinkStep?>()
        .firstWhere((_) => true, orElse: () => null);
    if (step == null) return null;
    final earlier = ids.sublist(0, index).toSet();
    for (final dep in step.dependencies) {
      if (!earlier.contains(dep)) return dep;
    }
    return null;
  }

  void _scheduleServerCheck(List<String> ids) {
    _checkDebounce?.cancel();
    final seq = ++_checkSeq;
    if (ids.isEmpty) {
      _serverStepErrors = const <String>[];
      notifyListeners();
      return;
    }
    _checkDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final errors = await repo.checkSteps(ids);
        // Drop a response superseded by a newer step edit, and never
        // notify after the screen has been disposed.
        if (seq != _checkSeq || isDisposed) return;
        _serverStepErrors = errors;
        notifyListeners();
      } catch (_) {
        // Swallow — client-side per-row markers are the primary surface.
      }
    });
  }

  @override
  void dispose() {
    _checkDebounce?.cancel();
    super.dispose();
  }

  // -------- Overview tab setters --------

  void setName(String v) => setStr((d, n) => d.copyWith(name: n), v);
  void setGroupId(String v) => setStr((d, n) => d.copyWith(groupId: n), v);
  void setAssignedUserId(String v) =>
      setStr((d, n) => d.copyWith(assignedUserId: n), v);
  void setProductIds(String v) =>
      setStr((d, n) => d.copyWith(productIds: n), v);
  void setRecurringProductIds(String v) =>
      setStr((d, n) => d.copyWith(recurringProductIds: n), v);
  void setOptionalProductIds(String v) =>
      setStr((d, n) => d.copyWith(optionalProductIds: n), v);
  void setOptionalRecurringProductIds(String v) =>
      setStr((d, n) => d.copyWith(optionalRecurringProductIds: n), v);

  // -------- Settings tab setters --------

  void setFrequencyId(String v) =>
      setStr((d, n) => d.copyWith(frequencyId: n), v);
  void setRemainingCycles(int v) =>
      updateDraft(draft.copyWith(remainingCycles: v));
  void setAutoBill(String v) => setStr((d, n) => d.copyWith(autoBill: n), v);
  void setPromoCode(String v) => setStr((d, n) => d.copyWith(promoCode: n), v);
  void setPromoDiscount(String input) =>
      setDec((d, n) => d.copyWith(promoDiscount: n), input);
  void setPromoDiscountDecimal(Decimal v) =>
      updateDraft(draft.copyWith(promoDiscount: v));
  void setIsAmountDiscount(bool v) =>
      updateDraft(draft.copyWith(isAmountDiscount: v));
  void setRegistrationRequired(bool v) =>
      updateDraft(draft.copyWith(registrationRequired: v));
  void setUseInventoryManagement(bool v) =>
      updateDraft(draft.copyWith(useInventoryManagement: v));
  void setAllowQueryOverrides(bool v) =>
      updateDraft(draft.copyWith(allowQueryOverrides: v));
  void setAllowPlanChanges(bool v) =>
      updateDraft(draft.copyWith(allowPlanChanges: v));

  /// When the user turns Allow Cancellation off, zero the dependent
  /// refund period so a previously-set value doesn't silently round-trip.
  void setAllowCancellation(bool v) {
    updateDraft(
      draft.copyWith(
        allowCancellation: v,
        refundPeriod: v ? draft.refundPeriod : 0,
      ),
    );
  }

  void setRefundPeriod(int v) => updateDraft(draft.copyWith(refundPeriod: v));

  /// Same pattern as [setAllowCancellation] — turning the toggle off
  /// zeros the trial duration.
  void setTrialEnabled(bool v) {
    updateDraft(
      draft.copyWith(
        trialEnabled: v,
        trialDuration: v ? draft.trialDuration : 0,
      ),
    );
  }

  void setTrialDuration(int v) => updateDraft(draft.copyWith(trialDuration: v));

  /// Same — turning per-seat off zeros the seat limit.
  void setPerSeatEnabled(bool v) {
    updateDraft(
      draft.copyWith(
        perSeatEnabled: v,
        maxSeatsLimit: v ? draft.maxSeatsLimit : 0,
      ),
    );
  }

  void setMaxSeatsLimit(String input) =>
      setInt((d, n) => d.copyWith(maxSeatsLimit: n), input);

  // -------- Webhook tab setters --------

  void setReturnUrl(String v) {
    updateDraft(
      draft.copyWith(
        webhookConfiguration: draft.webhookConfiguration.copyWith(returnUrl: v),
      ),
    );
  }

  void setWebhookUrl(String v) {
    updateDraft(
      draft.copyWith(
        webhookConfiguration: draft.webhookConfiguration.copyWith(
          postPurchaseUrl: v,
        ),
      ),
    );
  }

  void setWebhookRestMethod(String v) {
    updateDraft(
      draft.copyWith(
        webhookConfiguration: draft.webhookConfiguration.copyWith(
          postPurchaseRestMethod: v,
        ),
      ),
    );
  }

  void setWebhookHeaders(Map<String, String> headers) {
    updateDraft(
      draft.copyWith(
        webhookConfiguration: draft.webhookConfiguration.copyWith(
          postPurchaseHeaders: Map.unmodifiable(headers),
        ),
      ),
    );
  }

  void addWebhookHeader(String key, String value) {
    if (key.isEmpty) return;
    final next = Map<String, String>.from(
      draft.webhookConfiguration.postPurchaseHeaders,
    )..[key] = value;
    setWebhookHeaders(next);
  }

  void removeWebhookHeader(String key) {
    final next = Map<String, String>.from(
      draft.webhookConfiguration.postPurchaseHeaders,
    )..remove(key);
    setWebhookHeaders(next);
  }

  // -------- Lifecycle --------

  @override
  bool draftIsNonEmpty() => draft.name.trim().isNotEmpty;

  @override
  Future<SaveResult<PaymentLink>> performSave() async {
    if (savesAsCreate) {
      final result = await repo.create(
        companyId: companyId,
        draft: draft,
        existingTempId: recoveryTempId,
      );
      rememberCreateTempId(result.entity.id);
      return result;
    }
    return repo.save(companyId: companyId, paymentLink: draft);
  }

  void resetToEmpty() => reset(emptyDraft: emptyPaymentLink());
}
