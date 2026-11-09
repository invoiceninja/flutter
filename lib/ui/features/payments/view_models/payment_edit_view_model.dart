import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/payment_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/data/repositories/document_bearing_repository.dart';

/// Translation key surfaced as a toast when [PaymentEditViewModel
/// .validateForSave] detects credits exceed invoices.
const String kPaymentValidationCreditExceedsInvoice = 'credit_payment_error';

/// Translation key surfaced when a payment is created with no allocations
/// while the company's `enable_applying_payments` flag is false.
const String kPaymentValidationMissingAllocations =
    'please_select_an_invoice_or_credit';

/// Translation key surfaced when the invoices are allocated more than the
/// payment amount plus its credits — the server's `PaymentAmountsBalanceRule`
/// rejects that save with this same message.
const String kPaymentValidationAmountsDoNotBalance = 'amounts_do_not_balance';

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

  /// Files picked on the create form upload under the new record's id on
  /// Save (docs/attaching-documents.md).
  @override
  PendingUploadsRepository get documentUploadRepository => repo;
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

  /// Open amount (balance) of each invoice the allocations editor has offered,
  /// keyed by invoice id — the most a following allocation may grow to. Fed by
  /// [noteInvoiceOpenAmounts] / [startFromInvoice]; an invoice missing here
  /// (a clone, a restored draft) switches [setAmount]'s follow off.
  final Map<String, Decimal> _invoiceOpenAmounts = {};

  /// `true` once the user has typed an invoice allocation's own amount. From
  /// then on the allocations are theirs and [setAmount] leaves them alone.
  bool _allocationsEdited = false;

  /// Record the open amounts of invoices the allocations editor knows.
  void noteInvoiceOpenAmounts(Map<String, Decimal> openAmounts) =>
      _invoiceOpenAmounts.addAll(openAmounts);

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
    // The server's balance rule: a zero amount is derived from the
    // allocations, anything else must cover the invoices with the credits —
    // compared, as the server does, at two decimals (a 3-decimal currency's
    // 99.999 covers 100.00 there).
    if (savesAsCreate &&
        draft.amount != Decimal.zero &&
        invoiceAllocatedTotal.round(scale: 2) >
            (draft.amount + creditAllocatedTotal).round(scale: 2)) {
      return kPaymentValidationAmountsDoNotBalance;
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
    if (savesAsCreate) {
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
  ///
  /// The invoice allocations follow the typed amount (see
  /// [_allocationsFollowing]): pick a $1,250 invoice, type 625, and the
  /// invoice is allocated 625 — a partial payment, not a save the server
  /// rejects because the invoices outweigh the payment.
  void setAmount(String input) {
    _amountDirty = true;
    final amount =
        parseDecimal(input, useCommaAsDecimalPlace: useCommaAsDecimalPlace) ??
        Decimal.zero;
    updateDraft(
      draft.copyWith(
        amount: amount,
        paymentables:
            _allocationsFollowing(amount, draft.paymentables) ??
            draft.paymentables,
      ),
    );
  }

  /// The invoice allocations re-spread over [amount] (plus the credits, which
  /// pay invoices too): in list order, each up to its invoice's open amount,
  /// any excess left unapplied. Null — leave them as they are — on an edit,
  /// once the user has typed an allocation themselves, while any invoice's
  /// open amount is unknown, or for an amount that is not positive.
  ///
  /// The last is load-bearing: an emptied Amount field parses to zero, which
  /// the server reads as "derive the amount from the allocations" — and
  /// `Payment.toApiJson` drops zero-amount rows, so zeroed allocations would
  /// save an unapplied $0 payment instead of paying the invoice.
  List<Paymentable>? _allocationsFollowing(
    Decimal amount,
    List<Paymentable> paymentables,
  ) {
    if (!isCreate || _allocationsEdited || amount <= Decimal.zero) {
      return null;
    }
    final invoices = paymentables.where((p) => p.invoiceId.isNotEmpty);
    if (invoices.isEmpty ||
        invoices.any((p) => !_invoiceOpenAmounts.containsKey(p.invoiceId))) {
      return null;
    }
    var left = paymentables
        .where((p) => p.creditId.isNotEmpty)
        .fold<Decimal>(amount, (sum, p) => sum + p.amount);
    final next = <Paymentable>[];
    for (final p in paymentables) {
      if (p.invoiceId.isEmpty) {
        next.add(p);
        continue;
      }
      final open = _invoiceOpenAmounts[p.invoiceId]!;
      final share = left <= Decimal.zero
          ? Decimal.zero
          : (left < open ? left : open);
      left -= share;
      next.add(p.copyWith(amount: share));
    }
    return List<Paymentable>.unmodifiable(next);
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

  /// The converted amount, typed. The payment stores only the rate, so this
  /// sets the rate that turns [Payment.amount] into it — what React and v1
  /// both do. Beta feedback: with the converted figure read-only, a user
  /// holding the bank's settled amount had to work the rate out by hand.
  ///
  /// The rate is rounded to the six places the server keeps
  /// (`decimal(20,6)`), so the amount × rate the payment shows afterwards can
  /// differ from what was typed by a cent only on very large amounts. A blank
  /// or zero entry, or a zero amount to divide by, leaves the rate alone.
  void setConvertedAmount(String input) {
    final amount = draft.amount;
    if (amount == Decimal.zero) return;
    final converted = parseDecimal(
      input,
      zeroIsNull: true,
      useCommaAsDecimalPlace: useCommaAsDecimalPlace,
    );
    if (converted == null) return;
    final rate = (converted / amount)
        .toDecimal(scaleOnInfinitePrecision: 12)
        .round(scale: 6);
    if (rate <= Decimal.zero) return;
    updateDraft(draft.copyWith(exchangeRate: rate));
  }

  void setCustomValue1(String v) =>
      updateDraft(draft.copyWith(customValue1: v));
  void setCustomValue2(String v) =>
      updateDraft(draft.copyWith(customValue2: v));
  void setCustomValue3(String v) =>
      updateDraft(draft.copyWith(customValue3: v));
  void setCustomValue4(String v) =>
      updateDraft(draft.copyWith(customValue4: v));

  /// Start the payment from one invoice — the form's Invoice picker, React's
  /// "client *or* invoice". Sets the invoice's client and makes [allocation]
  /// the payment's only invoice; the amount follows it as any allocation does
  /// (see [replacePaymentables]).
  ///
  /// Credits stay while the client does. A different client starts the
  /// allocations afresh and seeds the currency from [clientCurrencyId] when
  /// none is set, as picking the client directly does. (The picker lists only
  /// the chosen client's invoices, so in practice "different" means "none
  /// yet".)
  void startFromInvoice({
    required String clientId,
    required String clientCurrencyId,
    required Paymentable allocation,
    Decimal? openAmount,
  }) {
    if (openAmount != null) {
      _invoiceOpenAmounts[allocation.invoiceId] = openAmount;
    }
    final sameClient = draft.clientId == clientId;
    if (!sameClient) {
      updateDraft(
        draft.copyWith(
          clientId: clientId,
          currencyId: draft.currencyId.isEmpty
              ? clientCurrencyId
              : draft.currencyId,
          paymentables: const <Paymentable>[],
        ),
      );
    }
    replacePaymentables([
      allocation,
      ...draft.paymentables.where((p) => p.creditId.isNotEmpty),
    ]);
    // A fresh pick replaces the invoice allocations, so the amount may lead
    // them again — even when it re-picked the same invoice.
    _allocationsEdited = false;
  }

  /// Drop every invoice allocation, keeping credits — the Invoice picker
  /// cleared.
  void clearInvoiceAllocations() => replacePaymentables([
    ...draft.paymentables.where((p) => p.invoiceId.isEmpty),
  ]);

  /// Replace the entire paymentables list. Auto-syncs `draft.amount` to
  /// `invoiceTotal - creditTotal` while the user hasn't touched the amount
  /// field — the visible amount stays in lockstep with the allocations
  /// without forcing the user to type the same number twice.
  void replacePaymentables(List<Paymentable> next) {
    final unmodifiable = List<Paymentable>.unmodifiable(next);
    _trackAllocationEdits(unmodifiable);
    if (_amountDirty) {
      // The amount is fixed, so a credit added, changed or removed (or an
      // invoice dropped) re-spreads the invoices over it — else the save
      // stops balancing until the amount is retyped.
      updateDraft(
        draft.copyWith(
          paymentables:
              _allocationsFollowing(draft.amount, unmodifiable) ?? unmodifiable,
        ),
      );
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

  /// A kept invoice whose amount changed was typed by the user — stop the
  /// amount leading the allocations. Adding, removing or swapping an invoice
  /// is not that. Allocations starting from none — however the last ones
  /// went (dropped here, a client change, a reset) — hand the lead back.
  void _trackAllocationEdits(List<Paymentable> next) {
    final before = {
      for (final p in draft.paymentables)
        if (p.invoiceId.isNotEmpty) p.invoiceId: p.amount,
    };
    final invoices = next.where((p) => p.invoiceId.isNotEmpty);
    if (invoices.isEmpty || before.isEmpty) {
      _allocationsEdited = false;
    } else if (invoices.any(
      (p) => before.containsKey(p.invoiceId) && before[p.invoiceId] != p.amount,
    )) {
      _allocationsEdited = true;
    }
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
