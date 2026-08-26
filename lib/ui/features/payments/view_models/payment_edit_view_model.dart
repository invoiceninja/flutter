import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/payment_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';
import 'package:admin/utils/formatting.dart';

/// Translation key surfaced as a toast when [PaymentEditViewModel
/// .validateForSave] detects credits exceed invoices.
const String kPaymentValidationCreditExceedsInvoice = 'credit_payment_error';

/// Translation key surfaced when a payment is created with no allocations
/// while the company's `enable_applying_payments` flag is false.
const String kPaymentValidationMissingAllocations =
    'please_select_an_invoice_or_credit';

/// Drives the Payment edit + create screen. Optimistic — `save()` lands the
/// draft in Drift via the repo, returns the saved entity, and the outbox
/// handles the server round-trip.
///
/// [sendEmail] is a transient UI-only flag passed straight to the repository
/// (never persisted). On create the default mirrors the company setting
/// `client_manual_payment_notification`; on update the user toggles it
/// explicitly.
///
/// [enableApplyingPayments] reflects the active company's
/// `enable_applying_payments` setting at construction time. When false, the
/// save flow requires at least one paymentable on create (mirrors admin-
/// portal `payment_edit_vm.dart:105-115`).
class PaymentEditViewModel extends GenericEditViewModel<Payment> {
  PaymentEditViewModel({
    required this.repo,
    required this.companyId,
    Payment? existing,
    Payment? cloneFrom,
    bool defaultSendEmail = false,
    this.enableApplyingPayments = true,
    String Function(String key)? translate,
    super.sync,
    super.connectivity,
    super.useCommaAsDecimalPlace,
  }) : _sendEmail = defaultSendEmail,
       // Lock the dirty flag for both edit (`existing`) and clone-from
       // (`cloneFrom`) entry points — either carries a user-meaningful
       // amount we must not auto-sync over.
       _amountDirty =
           ((existing ?? cloneFrom)?.amount ?? Decimal.zero) != Decimal.zero,
       _translate = translate ?? _identity,
       super(
         initialDraft: cloneFrom ?? existing ?? emptyPayment(),
         original: existing,
         companyId: companyId,
       );

  final PaymentRepository repo;
  final String companyId;
  final bool enableApplyingPayments;

  /// Localizer used by [performSave] to throw a `ValidationException` whose
  /// `message` is already translated — the scaffold's "Could not save"
  /// toast shows the friendly text without round-tripping through
  /// `BuildContext` at error time. Callers pass `(key) => context.tr(key)`;
  /// tests can leave it null (defaults to identity).
  final String Function(String key) _translate;

  bool _sendEmail;

  bool get sendEmail => _sendEmail;

  set sendEmail(bool value) {
    if (_sendEmail == value) return;
    _sendEmail = value;
    notifyListeners();
  }

  /// `true` once the user (or a non-allocations code path) has touched the
  /// amount field. While false, [replacePaymentables] auto-syncs
  /// `draft.amount` to `invoiceTotal - creditTotal` so a user can pick
  /// invoices and have the payment amount follow without typing.
  bool _amountDirty;

  bool get isAmountDirty => _amountDirty;

  /// The amount the auto-fill cap may be measured against — `draft.amount`
  /// once the user has fixed it, `Decimal.zero` (= "no cap") while it is still
  /// auto-syncing to the allocation total.
  ///
  /// This distinction is the whole point: while [isAmountDirty] is false,
  /// `draft.amount` **equals** the allocated total by construction, so a cap
  /// built from it leaves zero headroom and every allocation after the first
  /// auto-fills 0.00 — a payment that silently applies nothing to the second
  /// invoice. Hand this to `PaymentAllocationsSection.paymentAmount`, never
  /// `draft.amount` directly.
  Decimal get autoFillCap => _amountDirty ? draft.amount : Decimal.zero;

  /// Sum of allocation amounts (invoices + credits). The footer surfaces
  /// the running total + a "$Y remaining" hint so the user catches a
  /// mismatch before the server rejects it.
  Decimal get allocatedTotal => draft.paymentables.fold<Decimal>(
    Decimal.zero,
    (sum, p) => sum + p.amount,
  );

  /// Sum of allocation amounts for invoice-linked rows only.
  Decimal get invoiceAllocatedTotal => draft.paymentables
      .where((p) => p.invoiceId.isNotEmpty)
      .fold<Decimal>(Decimal.zero, (sum, p) => sum + p.amount);

  /// Sum of allocation amounts for credit-linked rows only. Credits SUBTRACT
  /// from the payment amount on the wire — they offset invoices.
  Decimal get creditAllocatedTotal => draft.paymentables
      .where((p) => p.creditId.isNotEmpty)
      .fold<Decimal>(Decimal.zero, (sum, p) => sum + p.amount);

  /// Difference between the payment amount and the running allocation total.
  /// Positive = under-allocated (more to spread); negative = over-allocated
  /// (the form should flag this red).
  Decimal get allocationRemainder => draft.amount - allocatedTotal;

  @override
  bool draftIsNonEmpty() {
    final d = draft;
    return d.clientId.isNotEmpty ||
        d.amount != Decimal.zero ||
        d.transactionReference.isNotEmpty ||
        d.privateNotes.isNotEmpty ||
        d.paymentables.isNotEmpty;
  }

  /// Returns a translation key if the draft fails a hard validation rule,
  /// or null when save can proceed. Mirrors admin-portal's
  /// `payment_edit_vm.dart:90-116`. The layout calls this *before*
  /// `vm.save()` so the toast text is owned by the UI layer (avoids the
  /// `Exception: …` wrapping that throwing from `performSave` produces).
  String? validateForSave() {
    // Credit total exceeding invoice total flips the wire-side amount math
    // negative on the server. Independent of `draft.amount`.
    if (creditAllocatedTotal > invoiceAllocatedTotal) {
      return kPaymentValidationCreditExceedsInvoice;
    }
    // When the workspace doesn't allow "payment without allocations", a
    // create payment must touch at least one invoice or credit.
    if (isCreate && !enableApplyingPayments && draft.paymentables.isEmpty) {
      return kPaymentValidationMissingAllocations;
    }
    return null;
  }

  @override
  Future<SaveResult<Payment>> performSave() async {
    final errorKey = validateForSave();
    if (errorKey != null) {
      // ValidationException routes through GenericEditViewModel.save's
      // catch block — `_submitError` becomes the (already-translated)
      // message and the scaffold surfaces it via Notify.error.
      throw ValidationException(_translate(errorKey), const {});
    }
    if (isCreate) {
      final result = await repo.create(
        companyId: companyId,
        draft: draft,
        sendEmail: _sendEmail,
        existingTempId: recoveryTempId,
      );
      rememberCreateTempId(result.entity.id);
      return result;
    }
    return repo.save(
      companyId: companyId,
      payment: draft,
      sendEmail: _sendEmail,
    );
  }

  void resetToEmpty() => reset(emptyDraft: emptyPayment());

  // ── Field setters ──────────────────────────────────────────────────

  /// Update the client id. Silent when the new value matches the current
  /// id (avoids a notify-loop when a picker stream re-emits during rebuild).
  void setClientId(String v) {
    if (draft.clientId == v) return;
    updateDraft(draft.copyWith(clientId: v));
  }

  /// Atomic "switch client + drop existing allocations" used by the edit
  /// layout after the user confirms in the "Change client?" dialog.
  void replaceClientAndClearPaymentables(String newClientId) {
    if (draft.clientId == newClientId && draft.paymentables.isEmpty) return;
    updateDraft(
      draft.copyWith(
        clientId: newClientId,
        paymentables: const <Paymentable>[],
      ),
    );
  }

  void setClientContactId(String v) =>
      updateDraft(draft.copyWith(clientContactId: v));
  void setVendorId(String v) => updateDraft(draft.copyWith(vendorId: v));
  void setProjectId(String v) => updateDraft(draft.copyWith(projectId: v));
  void setCurrencyId(String v) => updateDraft(draft.copyWith(currencyId: v));
  void setExchangeCurrencyId(String v) =>
      updateDraft(draft.copyWith(exchangeCurrencyId: v));
  void setTypeId(String v) => updateDraft(draft.copyWith(typeId: v));
  void setStatusId(String v) => updateDraft(draft.copyWith(statusId: v));
  void setAssignedUserId(String v) =>
      updateDraft(draft.copyWith(assignedUserId: v));
  void setNumber(String v) => updateDraft(draft.copyWith(number: v));
  void setTagIds(List<String> ids) => updateDraft(draft.copyWith(tagIds: ids));
  void setDate(Date? d) => updateDraft(draft.copyWith(date: d));
  void setTransactionReference(String v) =>
      updateDraft(draft.copyWith(transactionReference: v));
  void setPrivateNotes(String v) =>
      updateDraft(draft.copyWith(privateNotes: v));
  void setIsManual(bool v) => updateDraft(draft.copyWith(isManual: v));

  /// Manual amount edit. Flips `_amountDirty` so the auto-sync from
  /// allocations stops — the user has made their intent explicit.
  void setAmount(String input) {
    _amountDirty = true;
    updateDraft(
      draft.copyWith(
        amount:
            parseDecimal(
              input,
              useCommaAsDecimalPlace: useCommaAsDecimalPlace,
            ) ??
            Decimal.zero,
      ),
    );
  }

  void setExchangeRate(String input) => updateDraft(
    draft.copyWith(
      exchangeRate:
          parseDecimal(
            input,
            zeroIsNull: true,
            useCommaAsDecimalPlace: useCommaAsDecimalPlace,
          ) ??
          Decimal.one,
    ),
  );
  void setCustomValue1(String v) =>
      updateDraft(draft.copyWith(customValue1: v));
  void setCustomValue2(String v) =>
      updateDraft(draft.copyWith(customValue2: v));
  void setCustomValue3(String v) =>
      updateDraft(draft.copyWith(customValue3: v));
  void setCustomValue4(String v) =>
      updateDraft(draft.copyWith(customValue4: v));

  /// Replace the entire paymentables list. Auto-syncs `draft.amount` to
  /// `invoiceTotal - creditTotal` while the user hasn't touched the amount
  /// field — the visible amount stays in lockstep with the allocations
  /// without forcing the user to type the same number twice.
  void replacePaymentables(List<Paymentable> next) {
    final unmodifiable = List<Paymentable>.unmodifiable(next);
    if (_amountDirty) {
      updateDraft(draft.copyWith(paymentables: unmodifiable));
      return;
    }
    final invoiceTotal = unmodifiable
        .where((p) => p.invoiceId.isNotEmpty)
        .fold<Decimal>(Decimal.zero, (sum, p) => sum + p.amount);
    final creditTotal = unmodifiable
        .where((p) => p.creditId.isNotEmpty)
        .fold<Decimal>(Decimal.zero, (sum, p) => sum + p.amount);
    final syncedAmount = invoiceTotal - creditTotal;
    updateDraft(
      draft.copyWith(paymentables: unmodifiable, amount: syncedAmount),
    );
  }
}

String _identity(String key) => key;

/// Empty draft for new payments. Defaults: `exchange_rate = 1`, `date = today`,
/// `is_manual = true` (gateway-paid payments come back from server-side
/// callbacks, not user creates).
Payment emptyPayment() => Payment(
  id: '',
  number: '',
  statusId: '',
  typeId: '',
  clientId: '',
  clientContactId: '',
  companyGatewayId: '',
  gatewayTypeId: '',
  projectId: '',
  vendorId: '',
  invitationId: '',
  currencyId: '',
  exchangeCurrencyId: '',
  transactionReference: '',
  transactionId: '',
  privateNotes: '',
  customValue1: '',
  customValue2: '',
  customValue3: '',
  customValue4: '',
  userId: '',
  createdUserId: '',
  assignedUserId: '',
  date: Date.today(),
  amount: Decimal.zero,
  applied: Decimal.zero,
  refunded: Decimal.zero,
  exchangeRate: Decimal.one,
  isManual: true,
  isDeleted: false,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  archivedAt: null,
);
