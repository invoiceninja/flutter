import 'dart:async';

import 'package:collection/collection.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart' show VoidCallback;

import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/expense_repository.dart';
import 'package:admin/data/services/shared_intake_files.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/expenses/receipt_fill.dart';
import 'package:admin/domain/expenses/receipt_parser.dart';
import 'package:admin/domain/expenses/receipt_scanner.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';
import 'package:admin/utils/formatting.dart';

/// Drives the Expense edit + create screen. Optimistic — `save()` lands the
/// draft in Drift via the repo, returns the saved entity, and the outbox
/// handles the server round-trip.
class ExpenseEditViewModel extends GenericEditViewModel<Expense> {
  ExpenseEditViewModel({
    required this.repo,
    required this.companyId,
    Expense? existing,
    Expense? cloneFrom,
    super.sync,
    super.connectivity,
    super.useCommaAsDecimalPlace,
    List<UploadSource> initialDocuments = const [],
    Future<void> Function(Iterable<String> paths)? discardFiles,
    VoidCallback Function(
      String companyId,
      bool Function(List<UploadSource>) attach,
    )?
    registerShareTarget,
    ReceiptScanner? receiptScanner,
    Future<ReceiptFillContext> Function()? receiptFillContext,
  }) : _documents = existing == null ? [...initialDocuments] : [],
       _discardFiles = discardFiles,
       _receiptScanner = existing == null ? receiptScanner : null,
       _receiptFillContext = receiptFillContext,
       super(
         initialDraft: cloneFrom ?? existing ?? emptyExpense(),
         original: existing,
         companyId: companyId,
         prefilled: existing == null && cloneFrom != null,
       ) {
    // While a new expense is open, a file shared into the app joins it rather
    // than replacing it (`SharedFileIntake.registerAttachTarget`).
    if (isCreate) {
      _unregisterShareTarget = registerShareTarget?.call(
        companyId,
        addDocuments,
      );
    }
    final scanner = _receiptScanner;
    if (scanner != null) {
      unawaited(
        scanner.isSupported().then((ok) {
          if (!ok || isDisposed) return;
          _receiptSupported = true;
          notifyListeners();
        }),
      );
    }
  }

  final ExpenseRepository repo;
  final String companyId;

  /// Files attached to a new expense before it exists — picked on the form,
  /// or shared into the app from another one (invoiceninja/flutter#173).
  ///
  /// The list is the truth for every create attempt: each Save queues exactly
  /// these as uploads of the record (under its `tmp_` id — the outbox holds
  /// them behind the create and rewrites the id once it lands, so this works
  /// offline too), replacing whatever an earlier attempt left unsent
  /// (`BaseEntityRepository.replaceUnsentDocumentUploads`). The outbox rows
  /// can't be the truth: a rejected create's uploads die with it, and the
  /// save-failed banner's Discard deletes them with the record. Cleared only
  /// when a save succeeds. Create mode only — an existing expense uploads from
  /// its detail screen's Documents tab.
  final List<UploadSource> _documents;

  /// What the save in flight queued, and under which `tmp_` id — so a file
  /// shared into the form while that save is still out ([save]) can follow it.
  List<UploadSource>? _attemptBatch;
  String? _attemptTempId;

  /// Hands a file's app-owned copy back once the form lets go of it
  /// (`SharedIntakeFiles.delete`, which ignores every path outside its own
  /// folder and every copy an outbox row still names — so a picked file, or
  /// one an earlier attempt queued, is never touched).
  final Future<void> Function(Iterable<String> paths)? _discardFiles;

  VoidCallback? _unregisterShareTarget;

  List<UploadSource> get documents => List.unmodifiable(_documents);

  /// Whether the form can take more files: a new expense whose create isn't
  /// waiting on the user (unconfirmed — the card is locked) and hasn't already
  /// been made (every later Save is refused, so a file added then would be
  /// deleted on leave). A save in flight can: see [save].
  bool get acceptsDocuments =>
      isCreate &&
      !isDisposed &&
      unconfirmedRowId == null &&
      !failedSaveAlreadyCreated;

  /// Attach [sources]; false, with nothing attached, when the form can't take
  /// them ([acceptsDocuments]). A share then opens a New Expense of its own.
  bool addDocuments(Iterable<UploadSource> sources) {
    if (!acceptsDocuments) return false;
    if (sources.isEmpty) return true;
    final added = List<UploadSource>.of(sources);
    _documents.addAll(added);
    notifyListeners();
    unawaited(autoReadReceipt(added));
    return true;
  }

  void removeDocument(UploadSource source) {
    if (!_documents.remove(source)) return;
    if (_readingSource == source) cancelReceiptRead();
    _discard([source]);
    notifyListeners();
  }

  // ── Receipt reading (docs/receipt-ocr.md) ───────────────────────────

  final ReceiptScanner? _receiptScanner;
  final Future<ReceiptFillContext> Function()? _receiptFillContext;
  bool _receiptSupported = false;

  /// Bumped by every new read, cancel, reset and dispose. Native OCR can't
  /// be stopped, so a result whose generation is stale is dropped instead.
  int _receiptGeneration = 0;
  UploadSource? _readingSource;
  bool _autoReadPending = false;
  bool _receiptFailed = false;

  /// Bumped as each save starts: a read that began before one never lands.
  int _saveCount = 0;

  /// Every read that changed the form, oldest first. Undo takes back the
  /// newest only; the markers come from whichever read filled a field.
  final List<_AppliedReceiptRead> _reads = [];
  bool _receiptBannerVisible = false;

  /// Fields the user has focus in — a half-typed value isn't in the draft
  /// yet, so a read must leave it alone ([noteReceiptFieldFocus]).
  final Set<ReceiptFillField> _focused = {};

  /// Whether this form can read receipts: a device with an engine, a new
  /// expense, and a form not locked by a save.
  bool get canReadReceipt =>
      _receiptSupported && isCreate && !isSaving && acceptsDocuments;

  /// The file being read now, if any.
  UploadSource? get readingReceipt => _readingSource;
  bool get isReadingReceipt => _readingSource != null;

  /// Whether [source] has been read into the form (its row's Read button
  /// hides; Undo brings it back).
  bool receiptWasRead(UploadSource source) =>
      _reads.any((r) => r.source == source);

  /// Identifies the read the strip is about, so a screen reader hears each
  /// state of each read once.
  int get receiptReadId => _receiptGeneration;

  /// What the strip above the form says, if anything. Gone once the form
  /// can no longer take a receipt (saved, or the record already exists).
  ReceiptBannerState get receiptBannerState {
    if (!acceptsDocuments) return ReceiptBannerState.none;
    if (_readingSource != null) return ReceiptBannerState.reading;
    if (_receiptFailed) return ReceiptBannerState.failed;
    final last = _reads.lastOrNull;
    if (!_receiptBannerVisible || last == null) return ReceiptBannerState.none;
    return last.filled.isEmpty
        ? ReceiptBannerState.vendorOnly
        : ReceiptBannerState.filled;
  }

  bool get showsReceiptBanner => receiptBannerState != ReceiptBannerState.none;
  bool get receiptReadFailed => receiptBannerState == ReceiptBannerState.failed;

  /// The newest read, while the strip shows it.
  ReceiptRead? get lastReceiptRead =>
      showsReceiptBanner && !isReadingReceipt ? _reads.lastOrNull?.read : null;

  /// What the newest read filled, and the form as that read left it — the
  /// strip shows these, not the live draft the user may have changed since.
  Map<ReceiptFillField, ReceiptConfidence> get receiptFilledFields =>
      _reads.lastOrNull?.filled ?? const {};
  Expense? get receiptFilledDraft => _reads.lastOrNull?.after;

  /// The receipt's vendor line when it matched none of the company's
  /// vendors — offered as a create at the vendor field until one is picked.
  String? get unmatchedReceiptVendor {
    if (!acceptsDocuments) return null;
    final read = _reads.lastOrNull?.read;
    final name = read?.scan.vendorName;
    if (name == null || read?.vendorId != null) return null;
    return draft.vendorId.isEmpty ? name : null;
  }

  /// "From receipt" on [field] while it still holds what the read put there
  /// (or the user is still in it), with how sure the read was.
  ReceiptConfidence? receiptMarker(ReceiptFillField field) {
    if (!acceptsDocuments) return null;
    final read = _reads.lastWhereOrNull((r) => r.filled.containsKey(field));
    if (read == null) return null;
    final confidence = read.filled[field];
    if (_focused.contains(field)) return confidence;
    return _value(draft, field) == _value(read.after, field)
        ? confidence
        : null;
  }

  static Object? _value(Expense e, ReceiptFillField f) => switch (f) {
    ReceiptFillField.amount => e.amount,
    ReceiptFillField.date => e.date,
    ReceiptFillField.vendor => e.vendorId,
    ReceiptFillField.currency => e.currencyId,
    ReceiptFillField.tax1 => (e.taxName1, e.taxRate1, e.taxAmount1),
    ReceiptFillField.tax2 => (e.taxName2, e.taxRate2, e.taxAmount2),
    ReceiptFillField.tax3 => (e.taxName3, e.taxRate3, e.taxAmount3),
    ReceiptFillField.notes => e.privateNotes,
  };

  /// A field gained or lost focus. A read leaves a focused field alone, and
  /// its marker stays until the user leaves it — so the form doesn't shift
  /// under a finger mid-edit.
  void noteReceiptFieldFocus(ReceiptFillField field, bool focused) {
    final changed = focused ? _focused.add(field) : _focused.remove(field);
    if (changed && !focused && _reads.any((r) => r.filled.containsKey(field))) {
      notifyListeners();
    }
  }

  /// Whether the engine still answers; a later "unsupported" (no OCR
  /// language after all) hides the Read buttons.
  Future<bool> _engineReady(ReceiptScanner scanner) async {
    final ok = await scanner.isSupported();
    if (isDisposed) return false;
    if (ok != _receiptSupported) {
      _receiptSupported = ok;
      notifyListeners();
    }
    return ok;
  }

  /// Read the first readable file of [added] when nobody has typed into the
  /// form yet — however the file arrived (Scan Receipt, a share, a drop, the
  /// tiles). A form already holding the user's content, a clone, a prefilled
  /// draft, or one that has read a receipt already waits for the Read button.
  Future<void> autoReadReceipt(Iterable<UploadSource> added) async {
    final scanner = _receiptScanner;
    if (scanner == null || _autoReadPending) return;
    // Two batches arriving together (a share and a drop) read one file, not
    // two racing each other into the same blank fields.
    _autoReadPending = true;
    try {
      // The engine's answer may not be in yet when the form opens with a file.
      if (!await _engineReady(scanner)) return;
      bool pristine() =>
          !isDisposed &&
          canReadReceipt &&
          _readingSource == null &&
          _reads.isEmpty &&
          !prefilled &&
          draft == createBaseline;
      if (!pristine()) return;
      for (final source in added) {
        if (await ReceiptScanner.isReadable(source)) {
          if (!pristine() || !_documents.contains(source)) return;
          await readReceipt(source);
          return;
        }
      }
    } finally {
      _autoReadPending = false;
    }
  }

  /// Read [source] and fill the form's blank, untouched fields from it.
  Future<void> readReceipt(UploadSource source) async {
    final scanner = _receiptScanner;
    if (scanner == null || !await _engineReady(scanner)) return;
    if (!canReadReceipt) return;
    final generation = ++_receiptGeneration;
    final saves = _saveCount;
    _readingSource = source;
    _receiptFailed = false;
    // The strip is about this read now, not the one before it.
    _receiptBannerVisible = false;
    notifyListeners();
    final read = await scanner.scan(source, companyId);
    ReceiptFillContext? ctx;
    if (read != null) {
      try {
        ctx = await _receiptFillContext?.call();
      } catch (_) {
        ctx = null;
      }
    }
    if (generation != _receiptGeneration || isDisposed) return;
    _readingSource = null;
    // The form moved on while the engine read: a save started (or is done),
    // the record turned out to exist, the file was removed. Nothing lands.
    if (isSaving ||
        _saveCount != saves ||
        !acceptsDocuments ||
        !_documents.contains(source)) {
      notifyListeners();
      return;
    }
    if (read == null || ctx == null) {
      // A read that found nothing may be the engine latching off.
      if (read == null) await _engineReady(scanner);
      if (generation != _receiptGeneration || isDisposed) return;
      _receiptFailed = true;
      notifyListeners();
      return;
    }
    final before = draft;
    final result = fillExpenseFromReceipt(
      draft: before,
      baseline: createBaseline,
      prefilled: prefilled,
      read: read,
      ctx: ctx,
      paymentDateFollowsDate: _paymentDateFollowsDate,
      userChoseInclusive: _userTouchedInclusive,
      busy: _focused,
    );
    if (result.filled.isEmpty && _unmatchedVendorOf(read, before) == null) {
      _receiptFailed = true;
      notifyListeners();
      return;
    }
    _reads.add(
      _AppliedReceiptRead(
        source: source,
        read: read,
        filled: result.filled,
        before: before,
        after: result.draft,
        inclusiveTouchedBefore: _userTouchedInclusive,
      ),
    );
    _receiptBannerVisible = true;
    if (result.draft != before) {
      // Through updateDraft, not seedCreateDefault: what a receipt says is
      // the user's content, and makes the form dirty.
      updateDraft(result.draft);
    } else {
      notifyListeners();
    }
  }

  /// The vendor line [read] offers to create on [d], if any.
  static String? _unmatchedVendorOf(ReceiptRead read, Expense d) =>
      read.vendorId == null && d.vendorId.isEmpty ? read.scan.vendorName : null;

  /// Stop waiting for the read in progress; its result will be dropped.
  void cancelReceiptRead() {
    _receiptGeneration++;
    _readingSource = null;
    notifyListeners();
  }

  /// Close the strip; the fields keep their values and markers.
  void dismissReceiptBanner() {
    _receiptBannerVisible = false;
    _receiptFailed = false;
    notifyListeners();
  }

  /// Put back what the newest read changed — each field only while it still
  /// holds the read's value, so an edit made since is kept — together with
  /// what came with it (tax mode, the inclusive switch, the exchange rate,
  /// a payment date that followed the date). An earlier read stays.
  void undoReceiptRead() {
    if (isSaving || _reads.isEmpty) return;
    final r = _reads.removeLast();
    final before = r.before;
    final after = r.after;
    var d = draft;
    bool same(ReceiptFillField f) =>
        r.filled.containsKey(f) && _value(d, f) == _value(after, f);
    if (same(ReceiptFillField.amount)) {
      d = d.copyWith(amount: before.amount);
      if (d.invoiceCurrencyId.isNotEmpty) {
        d = d.copyWith(foreignAmount: d.amount * d.exchangeRate);
      }
    }
    if (same(ReceiptFillField.date)) {
      d = d.copyWith(date: before.date);
      if (d.paymentDate == after.paymentDate) {
        d = d.copyWith(paymentDate: before.paymentDate);
      }
    }
    if (same(ReceiptFillField.vendor)) {
      d = d.copyWith(vendorId: before.vendorId);
    }
    if (same(ReceiptFillField.currency)) {
      d = d.copyWith(currencyId: before.currencyId);
      // The rate the read moved goes back only if nobody set one since; the
      // converted amount follows whatever amount the form holds now.
      if (d.exchangeRate == after.exchangeRate) {
        d = d.copyWith(exchangeRate: before.exchangeRate);
      }
      if (d.invoiceCurrencyId.isNotEmpty) {
        d = d.copyWith(foreignAmount: d.amount * d.exchangeRate);
      }
    }
    final taxSlots = [
      ReceiptFillField.tax1,
      ReceiptFillField.tax2,
      ReceiptFillField.tax3,
    ].where(r.filled.containsKey).toList();
    if (taxSlots.isNotEmpty) {
      // Every slot the read filled still as it left it: the whole tax block
      // goes back, mode and switch with it. One slot edited since: only the
      // untouched slots clear, and the mode the user is working in stays.
      final untouched = taxSlots.where(same).toList();
      for (final slot in untouched) {
        d = switch (slot) {
          ReceiptFillField.tax1 => d.copyWith(
            taxName1: before.taxName1,
            taxRate1: before.taxRate1,
            taxAmount1: before.taxAmount1,
          ),
          ReceiptFillField.tax2 => d.copyWith(
            taxName2: before.taxName2,
            taxRate2: before.taxRate2,
            taxAmount2: before.taxAmount2,
          ),
          _ => d.copyWith(
            taxName3: before.taxName3,
            taxRate3: before.taxRate3,
            taxAmount3: before.taxAmount3,
          ),
        };
      }
      if (untouched.length == taxSlots.length) {
        if (d.calculateTaxByAmount == after.calculateTaxByAmount) {
          d = d.copyWith(calculateTaxByAmount: before.calculateTaxByAmount);
        }
        if (_userTouchedInclusive == r.inclusiveTouchedBefore &&
            d.usesInclusiveTaxes == after.usesInclusiveTaxes) {
          d = d.copyWith(usesInclusiveTaxes: before.usesInclusiveTaxes);
        }
      }
    }
    if (same(ReceiptFillField.notes)) {
      d = d.copyWith(privateNotes: before.privateNotes);
    }
    _receiptBannerVisible = false;
    _receiptFailed = false;
    updateDraft(d);
  }

  void _clearReceiptRead() {
    _reads.clear();
    _receiptBannerVisible = false;
    _receiptFailed = false;
  }

  void _discard(Iterable<UploadSource> sources) {
    final paths = sources.map(SharedIntakeFiles.localPathOf).nonNulls.toList();
    if (paths.isEmpty) return;
    unawaited(_discardFiles?.call(paths));
  }

  /// A save the server confirmed (or that went out optimistically) hands the
  /// files to the record for good; a rejected one keeps them on the form, to
  /// be queued again — the same list — by the next attempt.
  ///
  /// A file shared into the form while the save was out (up to the 30 s
  /// online wait) missed that attempt's batch. It follows the record when the
  /// attempt's create row stands — saved, or waiting on the user — and stays
  /// on the form for the next attempt otherwise. Cleared with the rest, it
  /// was never queued at all.
  @override
  Future<Expense?> save() async {
    _saveCount++;
    final saved = await super.save();
    final batch = _attemptBatch;
    final tempId = _attemptTempId;
    _attemptBatch = null;
    _attemptTempId = null;
    if (batch != null &&
        tempId != null &&
        (saved != null || unconfirmedRowId != null)) {
      final arrived = [
        for (final source in _documents)
          if (!batch.contains(source)) source,
      ];
      for (final source in arrived) {
        await repo.uploadDocument(
          companyId: companyId,
          entityId: tempId,
          source: source,
        );
      }
    }
    if (saved != null) _documents.clear();
    return saved;
  }

  @override
  void dispose() {
    _receiptGeneration++;
    _unregisterShareTarget?.call();
    // Left without saving: copies nothing queued belong to no record. Not
    // mid-save — the rows being written would name them; the boot sweep
    // collects anything that really was left behind.
    if (!isSaving) _discard(_documents);
    _documents.clear();
    super.dispose();
  }

  /// Dirty is "differs from what the untouched form held", for every field
  /// at once — the billing view models' rule. The hand-kept list this
  /// replaced missed the date, the number and the assignee, so a new expense
  /// holding only those left without the Discard prompt. A form opened on a
  /// staged draft (a clone, a "New expense" from a vendor) holds unsaved
  /// content from the start, and so does one holding attached files.
  @override
  bool draftIsNonEmpty() =>
      draft != createBaseline || prefilled || _documents.isNotEmpty;

  @override
  Future<SaveResult<Expense>> performSave() async {
    if (savesAsCreate) {
      // Set when this re-sends a create that didn't land — after a rejected
      // Save on this form, or on a failed record reopened from the Outbox.
      // (Captured, not read after: [rememberCreateTempId] overwrites it.)
      final retryingTempId = recoveryTempId;
      // Snapshot before any await: a dispose meanwhile (a sign-out, the `/new`
      // route re-keyed) clears the list, and a file shared meanwhile belongs
      // to [save]'s follow-up, not to this batch.
      final batch = isCreate ? List<UploadSource>.of(_documents) : null;
      final result = await repo.create(
        companyId: companyId,
        draft: draft,
        existingTempId: recoveryTempId,
      );
      final tempId = result.entity.id;
      rememberCreateTempId(tempId);
      if (batch != null) {
        final replaced = await repo.replaceUnsentDocumentUploads(
          companyId: companyId,
          tempId: tempId,
          enqueue: () async {
            for (final source in batch) {
              await repo.uploadDocument(
                companyId: companyId,
                entityId: tempId,
                source: source,
              );
            }
          },
        );
        _attemptBatch = batch;
        _attemptTempId = tempId;
        // A file removed from the form after an earlier attempt: its row
        // named it until now, so the ✕ couldn't hand it back then.
        final kept = batch.map(SharedIntakeFiles.localPathOf).nonNulls.toSet();
        final dropped = replaced.where((p) => !kept.contains(p)).toList();
        if (dropped.isNotEmpty) unawaited(_discardFiles?.call(dropped));
      } else if (retryingTempId != null) {
        // An edit form re-sending a failed create holds no files of its own:
        // move the earlier attempt's uploads behind this create.
        await repo.requeueUnsentDocumentUploads(
          companyId: companyId,
          tempId: retryingTempId,
        );
      }
      return result;
    }
    return repo.save(companyId: companyId, expense: draft);
  }

  void resetToEmpty() => reset(emptyDraft: emptyExpense());

  @override
  void reset({required Expense emptyDraft}) {
    _userTouchedInclusive = false;
    _receiptGeneration++;
    _readingSource = null;
    _clearReceiptRead();
    // As in [dispose]: a save in flight is writing rows that name them.
    if (!isSaving) _discard(_documents);
    _documents.clear();
    super.reset(emptyDraft: emptyDraft);
    // The only way a rebased blank draft carries a payment date is the
    // company's mark-paid default being re-applied, which follows the date.
    // An edit form's reset restores the stored record, whose payment date is
    // the user's and never follows.
    _paymentDateFollowsDate = isCreate && draft.paymentDate != null;
  }

  bool _userTouchedInclusive = false;

  /// Whether [setDate] also moves the payment date. Set whenever the app fills
  /// the payment date in from the expense date — [markPaid], the company's
  /// mark-paid default in [seedCompanyDefaults], and that default's
  /// re-application on Discard ([reset]) — so never for a stored payment date
  /// on an existing expense. Cleared the moment the user edits the payment
  /// date themselves ([setPaymentDate]) or unticks Mark paid.
  bool _paymentDateFollowsDate = false;

  /// Seed a new expense from the company's Expense Settings — what React's
  /// `Create.tsx` and admin-portal's `ExpenseEntity` constructor do, and what
  /// the server does NOT do for a manually created expense (it applies these
  /// only in bank matching and the recurring cron). Without it every one of
  /// those settings toggles was inert here.
  ///
  /// The edit screen calls this only for a genuine new expense — never for a
  /// clone, which copies its source. Each default goes through
  /// [seedCreateDefault], so an untouched form stays clean and a Discard
  /// re-applies it, and each is skipped once the user has changed the field
  /// it would set.
  void seedCompanyDefaults(Company company) {
    final base = createBaseline;
    // An amount is net or gross by the mode it was typed in, so the mode is
    // the user's once there is one.
    if (!_userTouchedInclusive && draft.amount == Decimal.zero) {
      seedCreateDefault(
        (d) => d.copyWith(usesInclusiveTaxes: company.expenseInclusiveTaxes),
      );
    }
    // Same reasoning for rate vs amount entry: once a tax is entered, the
    // mode it was entered in is what it means.
    if (draft.calculateTaxByAmount == base.calculateTaxByAmount &&
        !_hasTaxEntered(draft)) {
      seedCreateDefault(
        (d) => d.copyWith(
          calculateTaxByAmount: company.calculateExpenseTaxByAmount,
        ),
      );
    }
    if (draft.shouldBeInvoiced == base.shouldBeInvoiced) {
      seedCreateDefault(
        (d) => d.copyWith(shouldBeInvoiced: company.markExpensesInvoiceable),
      );
    }
    if (draft.invoiceDocuments == base.invoiceDocuments) {
      seedCreateDefault(
        (d) => d.copyWith(invoiceDocuments: company.invoiceExpenseDocuments),
      );
    }
    if (company.markExpensesPaid && !draft.isPaid) {
      final typeId = _usablePaymentTypeId(
        company.settings.defaultExpensePaymentTypeId,
      );
      final applied = seedCreateDefault((d) => _markedPaid(d, typeId));
      if (applied) _paymentDateFollowsDate = true;
    }
  }

  /// Tick "Mark paid": the payment date defaults to the expense's own date
  /// (today when it has none) — a receipt back-dated to last week was paid
  /// last week far more often than today — and the payment type to the
  /// company's default expense payment type. Until the user edits the
  /// payment date, changing the expense date moves it too ([setDate]).
  void markPaid({String? defaultPaymentTypeId}) {
    if (draft.paymentDate == null) _paymentDateFollowsDate = true;
    updateDraft(_markedPaid(draft, _usablePaymentTypeId(defaultPaymentTypeId)));
  }

  /// Untick "Mark paid": clears the whole payment-metadata triple.
  void unmarkPaid() {
    _paymentDateFollowsDate = false;
    updateDraft(
      draft.copyWith(
        paymentDate: null,
        paymentTypeId: '',
        transactionReference: '',
      ),
    );
  }

  static Expense _markedPaid(Expense d, String defaultPaymentTypeId) =>
      d.copyWith(
        paymentDate: d.paymentDate ?? d.date ?? Date.today(),
        paymentTypeId: d.paymentTypeId.isEmpty
            ? defaultPaymentTypeId
            : d.paymentTypeId,
      );

  /// The server's "no default" is `'0'` (`CompanySettings::
  /// $default_expense_payment_type_id`), not an empty string.
  static String _usablePaymentTypeId(String? id) =>
      (id == null || id.isEmpty || id == '0') ? '' : id;

  static bool _hasTaxEntered(Expense d) => [
    d.taxRate1,
    d.taxRate2,
    d.taxRate3,
    d.taxAmount1,
    d.taxAmount2,
    d.taxAmount3,
  ].any((v) => v != Decimal.zero);

  // ── Field setters ──────────────────────────────────────────────────

  void setVendorId(String v) => updateDraft(draft.copyWith(vendorId: v));
  void setTagIds(List<String> ids) => updateDraft(draft.copyWith(tagIds: ids));
  void setClientId(String v) => updateDraft(draft.copyWith(clientId: v));
  void setProjectId(String v) => updateDraft(draft.copyWith(projectId: v));
  void setCategoryId(String v) => updateDraft(draft.copyWith(categoryId: v));
  void setCurrencyId(String v) => updateDraft(draft.copyWith(currencyId: v));

  /// Set the invoice currency. Clearing it resets the conversion (rate → 1,
  /// foreign → 0); setting it recomputes the foreign amount from the current
  /// rate. Mirrors React `AdditionalInfo` useEffect on `invoice_currency_id`.
  /// The edit screen separately seeds the exchange rate from the two
  /// currencies' base rates via [setExchangeRate].
  void setInvoiceCurrencyId(String v) {
    if (v.isEmpty) {
      updateDraft(
        draft.copyWith(
          invoiceCurrencyId: '',
          exchangeRate: Decimal.one,
          foreignAmount: Decimal.zero,
        ),
      );
      return;
    }
    final d = draft.copyWith(invoiceCurrencyId: v);
    updateDraft(d.copyWith(foreignAmount: d.amount * d.exchangeRate));
  }

  void setAssignedUserId(String v) =>
      updateDraft(draft.copyWith(assignedUserId: v));
  void setNumber(String v) => updateDraft(draft.copyWith(number: v));
  void setDate(Date? d) {
    var next = draft.copyWith(date: d);
    if (_paymentDateFollowsDate && d != null && next.paymentDate != null) {
      next = next.copyWith(paymentDate: d);
    }
    updateDraft(next);
  }

  /// The user's own payment date — from here on it no longer follows the
  /// expense date.
  void setPaymentDate(Date? d) {
    _paymentDateFollowsDate = false;
    updateDraft(draft.copyWith(paymentDate: d));
  }

  void setPaymentTypeId(String v) =>
      updateDraft(draft.copyWith(paymentTypeId: v));
  void setTransactionReference(String v) =>
      updateDraft(draft.copyWith(transactionReference: v));
  void setTransactionId(String v) =>
      updateDraft(draft.copyWith(transactionId: v));
  void setBankId(String v) => updateDraft(draft.copyWith(bankId: v));
  void setAmount(String input) {
    final amount =
        parseDecimal(input, useCommaAsDecimalPlace: useCommaAsDecimalPlace) ??
        Decimal.zero;
    var d = draft.copyWith(amount: amount);
    // Keep the converted (foreign) amount in step with the entered amount.
    if (d.invoiceCurrencyId.isNotEmpty) {
      d = d.copyWith(foreignAmount: amount * d.exchangeRate);
    }
    updateDraft(d);
  }

  /// Editing the foreign amount back-computes the exchange rate
  /// (`foreign / amount`) — mirrors React's `foreign_amount` onChange.
  void setForeignAmount(String input) {
    final foreign =
        parseDecimal(input, useCommaAsDecimalPlace: useCommaAsDecimalPlace) ??
        Decimal.zero;
    var d = draft.copyWith(foreignAmount: foreign);
    if (d.amount != Decimal.zero) {
      d = d.copyWith(
        exchangeRate: (foreign / d.amount).toDecimal(
          scaleOnInfinitePrecision: 10,
        ),
      );
    }
    updateDraft(d);
  }

  void setExchangeRate(String input) {
    final rate =
        parseDecimal(
          input,
          zeroIsNull: true,
          useCommaAsDecimalPlace: useCommaAsDecimalPlace,
        ) ??
        Decimal.one;
    var d = draft.copyWith(exchangeRate: rate);
    if (d.invoiceCurrencyId.isNotEmpty) {
      d = d.copyWith(foreignAmount: d.amount * rate);
    }
    updateDraft(d);
  }

  void setTaxName1(String v) => updateDraft(draft.copyWith(taxName1: v));
  void setTaxName2(String v) => updateDraft(draft.copyWith(taxName2: v));
  void setTaxName3(String v) => updateDraft(draft.copyWith(taxName3: v));
  void setTaxRate1(String input) => updateDraft(
    draft.copyWith(
      taxRate1:
          parseDecimal(input, useCommaAsDecimalPlace: useCommaAsDecimalPlace) ??
          Decimal.zero,
    ),
  );
  void setTaxRate2(String input) => updateDraft(
    draft.copyWith(
      taxRate2:
          parseDecimal(input, useCommaAsDecimalPlace: useCommaAsDecimalPlace) ??
          Decimal.zero,
    ),
  );
  void setTaxRate3(String input) => updateDraft(
    draft.copyWith(
      taxRate3:
          parseDecimal(input, useCommaAsDecimalPlace: useCommaAsDecimalPlace) ??
          Decimal.zero,
    ),
  );
  void setTaxAmount1(String input) => updateDraft(
    draft.copyWith(
      taxAmount1:
          parseDecimal(input, useCommaAsDecimalPlace: useCommaAsDecimalPlace) ??
          Decimal.zero,
    ),
  );
  void setTaxAmount2(String input) => updateDraft(
    draft.copyWith(
      taxAmount2:
          parseDecimal(input, useCommaAsDecimalPlace: useCommaAsDecimalPlace) ??
          Decimal.zero,
    ),
  );
  void setTaxAmount3(String input) => updateDraft(
    draft.copyWith(
      taxAmount3:
          parseDecimal(input, useCommaAsDecimalPlace: useCommaAsDecimalPlace) ??
          Decimal.zero,
    ),
  );
  void setUsesInclusiveTaxes(bool v) {
    _userTouchedInclusive = true;
    updateDraft(draft.copyWith(usesInclusiveTaxes: v));
  }

  void setCalculateTaxByAmount(bool v) =>
      updateDraft(draft.copyWith(calculateTaxByAmount: v));
  void setShouldBeInvoiced(bool v) =>
      updateDraft(draft.copyWith(shouldBeInvoiced: v));
  void setInvoiceDocuments(bool v) =>
      updateDraft(draft.copyWith(invoiceDocuments: v));
  void setPublicNotes(String v) => updateDraft(draft.copyWith(publicNotes: v));
  void setPrivateNotes(String v) =>
      updateDraft(draft.copyWith(privateNotes: v));
  void setCustomValue1(String v) =>
      updateDraft(draft.copyWith(customValue1: v));
  void setCustomValue2(String v) =>
      updateDraft(draft.copyWith(customValue2: v));
  void setCustomValue3(String v) =>
      updateDraft(draft.copyWith(customValue3: v));
  void setCustomValue4(String v) =>
      updateDraft(draft.copyWith(customValue4: v));
}

/// Empty draft for new expenses. Defaults match admin-portal's create
/// factory: `exchange_rate = 1`, `date = today`, and the rest are zero /
/// empty until the user picks values. Currency cascades are seeded in the
/// edit screen's identity section: the vendor's currency → `currencyId` and
/// the client's currency → `invoiceCurrencyId` (each only when still empty).
Expense emptyExpense() => Expense(
  id: '',
  userId: '',
  assignedUserId: '',
  vendorId: '',
  invoiceId: '',
  clientId: '',
  bankId: '',
  invoiceCurrencyId: '',
  expenseCurrencyId: '',
  currencyId: '',
  categoryId: '',
  paymentTypeId: '',
  recurringExpenseId: '',
  privateNotes: '',
  publicNotes: '',
  transactionReference: '',
  transactionId: '',
  date: Date.today(),
  number: '',
  paymentDate: null,
  customValue1: '',
  customValue2: '',
  customValue3: '',
  customValue4: '',
  taxName1: '',
  taxName2: '',
  taxName3: '',
  projectId: '',
  entityType: '',
  amount: Decimal.zero,
  foreignAmount: Decimal.zero,
  exchangeRate: Decimal.one,
  taxAmount1: Decimal.zero,
  taxAmount2: Decimal.zero,
  taxAmount3: Decimal.zero,
  taxRate1: Decimal.zero,
  taxRate2: Decimal.zero,
  taxRate3: Decimal.zero,
  isDeleted: false,
  shouldBeInvoiced: false,
  invoiceDocuments: false,
  usesInclusiveTaxes: false,
  calculateTaxByAmount: false,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  archivedAt: null,
);

/// What the strip above New Expense says about a receipt read.
enum ReceiptBannerState {
  none,
  reading,

  /// The read filled fields.
  filled,

  /// The read filled nothing but found a vendor the company doesn't have.
  vendorOnly,

  /// Nothing could be read.
  failed,
}

/// One read that changed the form: what it filled, and the form either side
/// of it, for the markers, the strip and Undo.
class _AppliedReceiptRead {
  _AppliedReceiptRead({
    required this.source,
    required this.read,
    required this.filled,
    required this.before,
    required this.after,
    required this.inclusiveTouchedBefore,
  });

  final UploadSource source;
  final ReceiptRead read;
  final Map<ReceiptFillField, ReceiptConfidence> filled;
  final Expense before;
  final Expense after;

  /// Whether the user had set the inclusive switch when the read landed —
  /// a change since means Undo leaves the switch alone.
  final bool inclusiveTouchedBefore;
}
