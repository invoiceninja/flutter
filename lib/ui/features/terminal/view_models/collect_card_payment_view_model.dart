import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:store_services/store_services.dart';
import 'package:uuid/uuid.dart';

import 'package:admin/app/terminal_controller.dart';
import 'package:admin/data/models/api/terminal_models.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/repositories/terminal_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/terminal_platform.dart';
import 'package:admin/data/services/terminal_server_error.dart';
import 'package:admin/domain/terminal/terminal_eligibility.dart';

final _log = Logger('CollectCardPayment');

/// Where a collection stands (docs/in-person-payments.md).
enum CollectStage {
  /// Amount, surcharge and reader; nothing created yet.
  configure,

  /// Creating the PaymentIntent.
  creating,

  /// Another attempt left a collection open on this invoice.
  openCollection,

  /// Reading the card (or reading it again).
  waiting,

  /// The server is deciding the amount for the card just read.
  finalizing,

  /// Charging: nothing can stop it now.
  processing,

  /// The card was declined or couldn't be read; another card may be tried.
  declined,

  /// The server recorded the charge.
  approved,

  /// Charged; the server is still recording it.
  recording,

  /// Nobody can say yet whether the card was charged.
  checking,

  /// Charged, but the server couldn't record it.
  unrecorded,

  cancelled,
}

/// Something to tell the person at the counter: an SDK code, a server code,
/// or neither (a generic failure with [message]).
@immutable
class CollectProblem {
  const CollectProblem({
    this.code,
    this.serverCode,
    this.message = '',
    this.data = const {},
  });

  final TerminalErrorCode? code;
  final String? serverCode;
  final String message;
  final Map<String, dynamic> data;
}

/// Why the reader isn't ready.
enum ReaderState {
  idle,
  permissions,
  blocked,
  connecting,
  needsReader,
  ready,
  failed,
}

/// Drives one "Collect card payment" screen: one invoice, one collection at a
/// time. The server owns every figure; this decides only when to ask it.
///
/// Money rules (Invariants, docs/in-person-payments.md):
/// - A new `collection_id` per attempt; the same one only to retry a create
///   whose outcome is unknown.
/// - Every read is followed by `finalize`, and a confirm charges only that
///   read at the latest `amount_minor` (the facade refuses anything else).
/// - Nothing cancels a confirm or the `complete` after it, and "not charged"
///   is said only when the server answered `canceled` or the card was
///   declined.
class CollectCardPaymentViewModel extends ChangeNotifier {
  CollectCardPaymentViewModel({
    required this.companyId,
    required Invoice invoice,
    required TerminalController terminal,
    required TerminalRepository repository,
    required this.isAdmin,
    required this.merchantDisplayName,
    required this.precision,
    this.clientEmail = '',
    DateTime Function()? clock,
    String Function()? newId,
    this.pollDelay = const Duration(seconds: 2),
  }) : _invoice = invoice,
       _terminal = terminal,
       _repo = repository,
       _clock = clock ?? DateTime.now,
       _newId = newId ?? (() => const Uuid().v4()) {
    amount = defaultAmount(invoice);
  }

  final String companyId;
  final bool isAdmin;
  final String merchantDisplayName;

  /// The client currency's decimals.
  final int precision;
  final String clientEmail;
  final Duration pollDelay;
  final TerminalController _terminal;
  final TerminalRepository _repo;
  final DateTime Function() _clock;
  final String Function() _newId;

  /// Stripe allows 30 s between reading a card and charging it; past this
  /// the card is read again instead.
  static const confirmWindow = Duration(seconds: 25);

  /// Base, raised, lowered: a card is read at most this often in a row.
  static const maxReads = 3;

  final Invoice _invoice;
  Invoice get invoice => _invoice;

  CollectStage get stage => _stage;
  CollectStage _stage = CollectStage.configure;

  CollectProblem? get problem => _problem;
  CollectProblem? _problem;

  TerminalGatewayConfig? get gateway => _gateway;
  TerminalGatewayConfig? _gateway;
  TerminalLocation? _location;

  bool get livemode => _gateway?.livemode ?? true;

  late Decimal amount;
  bool applySurcharge = false;

  TerminalQuote? get quote => _quote;
  TerminalQuote? _quote;
  bool get quoting => _quoting;
  bool _quoting = false;
  int _quoteSeq = 0;

  ReaderState get readerState => _readerState;
  ReaderState _readerState = ReaderState.idle;
  TerminalReaderChoice get readerChoice => _readerChoice;
  TerminalReaderChoice _readerChoice = TerminalReaderChoice.none;
  TerminalReader? get reader => _reader;
  TerminalReader? _reader;
  TerminalPermission? _permission;
  TerminalPermission? get permission => _permission;

  /// The gateway's surcharge, before an invoice is involved.
  bool get surchargeOffered =>
      kCardPresentSurcharge && (_gateway?.surcharge.allowed ?? false);
  bool get surchargeNeedsAcknowledgement =>
      kCardPresentSurcharge &&
      (_gateway?.surcharge.needsAcknowledgement ?? false);

  String? _collectionId;
  TerminalIntent? get intent => _intent;
  TerminalIntent? _intent;
  TerminalPaymentSession? _session;

  TerminalCollected? get collected => _collected;
  TerminalCollected? _collected;
  TerminalFinalize? get finalized => _finalized;
  TerminalFinalize? _finalized;
  int _reads = 0;

  /// Set once this payment was given up — by Cancel or a failed finalize.
  /// A read still answering afterwards is ignored, whatever the server's
  /// answer to the cancel made of the stage.
  bool _abandoned = false;

  /// The surcharge changed the amount and the card must be read again.
  bool get readAgain => _readAgain;
  bool _readAgain = false;

  TerminalCompletion? get completion => _completion;
  TerminalCompletion? _completion;

  bool get receiptSent => _receiptSent;
  bool _receiptSent = false;

  bool _disposed = false;

  /// From finalize to an answer, Back and every other way out are held.
  bool get locked =>
      _stage == CollectStage.finalizing || _stage == CollectStage.processing;

  /// Past the point where leaving would leave a PaymentIntent behind.
  bool get inProgress => switch (_stage) {
    CollectStage.creating ||
    CollectStage.waiting ||
    CollectStage.finalizing ||
    CollectStage.processing ||
    CollectStage.declined => true,
    _ => false,
  };

  bool get canCollect =>
      _stage == CollectStage.configure &&
      _quote != null &&
      !_quoting &&
      _readerState == ReaderState.ready &&
      amount > Decimal.zero;

  /// What a deposit or a balance suggests: the deposit if one is due, a
  /// draft's amount, else the balance.
  static Decimal defaultAmount(Invoice invoice) =>
      invoice.partial > Decimal.zero &&
          invoice.partial < invoice.balanceOrAmount
      ? invoice.partial
      : invoice.balanceOrAmount;

  // ---------------------------------------------------------------- setup

  /// Loads the company's gateway, quotes, and gets the reader ready in
  /// parallel, so the customer isn't kept waiting after "Collect".
  Future<void> start() async {
    var config = _terminal.configFor(companyId);
    if (config == null) {
      try {
        config = await _terminal.refreshConfig(companyId);
      } catch (_) {}
    }
    final gateway = config?.usableGateway;
    if (gateway == null) {
      _fail(const CollectProblem(serverCode: TerminalServerError.notEnabled));
      return;
    }
    _gateway = gateway;
    _readerChoice = _terminal.readerChoiceFor(gateway.accountCountry);
    _notify();
    await Future.wait([requote(), prepareReader()]);
  }

  /// Permissions, the Location, the SDK and the reader.
  Future<void> prepareReader() async {
    final gateway = _gateway;
    if (gateway == null) return;
    if (_readerChoice == TerminalReaderChoice.none) {
      // A phone without Tap to Pay that has never had a reader: the sheet.
      _readerChoice = kCardPresentBluetooth
          ? TerminalReaderChoice.bluetooth
          : TerminalReaderChoice.none;
    }
    final kind = _readerChoice == TerminalReaderChoice.tapToPay
        ? TerminalReaderKind.tapToPay
        : TerminalReaderKind.bluetooth;
    _setReader(ReaderState.permissions);
    _permission = await _terminal.platform.requestPermissions(kind);
    if (_permission != TerminalPermission.granted) {
      _setReader(
        _permission == TerminalPermission.blocked
            ? ReaderState.blocked
            : ReaderState.failed,
        const CollectProblem(code: TerminalErrorCode.permissionDenied),
      );
      return;
    }
    final location = await _ensureLocation(gateway);
    if (location == null) return;
    _setReader(ReaderState.connecting);
    try {
      await _terminal.prepare(
        companyId: companyId,
        gateway: gateway,
        location: location,
      );
      final connected = await _terminal.connectedReader();
      if (connected != null) {
        _reader = connected;
        _setReader(ReaderState.ready);
        return;
      }
      if (_readerChoice == TerminalReaderChoice.tapToPay) {
        _reader = await _terminal.connectTapToPay(
          gateway: gateway,
          location: location,
          merchantDisplayName: merchantDisplayName,
          isAdmin: isAdmin,
        );
        _setReader(ReaderState.ready);
      } else {
        _setReader(ReaderState.needsReader);
      }
    } catch (e) {
      _setReader(ReaderState.failed, _problemOf(e));
    }
  }

  Future<TerminalLocation?> _ensureLocation(
    TerminalGatewayConfig gateway,
  ) async {
    final existing = _location ?? gateway.locations.firstOrNull;
    if (existing != null) return _location = existing;
    if (!isAdmin) {
      // Only an admin can create the Stripe Location.
      _setReader(
        ReaderState.failed,
        const CollectProblem(serverCode: 'location_needs_admin'),
      );
      return null;
    }
    try {
      return _location = await _repo.createLocation(
        companyId,
        companyGatewayId: gateway.companyGatewayId,
      );
    } catch (e) {
      _setReader(ReaderState.failed, _problemOf(e));
      return null;
    }
  }

  /// Bluetooth readers in range, for the reader sheet.
  Stream<List<TerminalReader>> discoverReaders() {
    final gateway = _gateway;
    return gateway == null
        ? const Stream.empty()
        : _terminal.discoverBluetooth(gateway);
  }

  /// The reader the person picked in the sheet.
  Future<void> connectReader(TerminalReader reader) async {
    final location = _location;
    if (location == null) return;
    _setReader(ReaderState.connecting);
    try {
      _reader = await _terminal.connectBluetooth(
        reader,
        location: location,
        merchantDisplayName: merchantDisplayName,
      );
      _readerChoice = TerminalReaderChoice.bluetooth;
      _setReader(ReaderState.ready);
    } catch (e) {
      _setReader(ReaderState.needsReader, _problemOf(e));
    }
  }

  Future<bool> openSettings() => _terminal.platform.openSettings();

  void _setReader(ReaderState state, [CollectProblem? problem]) {
    _readerState = state;
    if (problem != null) _problem = problem;
    if (state == ReaderState.ready && _problem?.code != null) _problem = null;
    _notify();
  }

  // -------------------------------------------------------------- amount

  void setAmount(Decimal value) {
    if (_stage != CollectStage.configure) return;
    amount = _round(value);
    _collectionId = null;
    unawaited(requote());
  }

  void setSurcharge(bool value) {
    if (_stage != CollectStage.configure || !surchargeOffered) return;
    applySurcharge = value;
    _collectionId = null;
    unawaited(requote());
  }

  /// The server's figures for the current amount; the only source of what
  /// the screen shows.
  Future<void> requote() async {
    final gateway = _gateway;
    if (gateway == null) return;
    final seq = ++_quoteSeq;
    _quoting = true;
    _notify();
    try {
      final quote = await _repo.quote(
        companyId,
        invoiceId: _invoice.id,
        companyGatewayId: gateway.companyGatewayId,
        amount: amount,
        applyFee: applySurcharge && surchargeOffered,
      );
      if (seq != _quoteSeq) return;
      _quote = quote;
      if (_problem?.serverCode != null && _stage == CollectStage.configure) {
        _problem = null;
      }
    } catch (e) {
      if (seq != _quoteSeq) return;
      _quote = null;
      _problem = _problemOf(e);
    } finally {
      if (seq == _quoteSeq) {
        _quoting = false;
        _notify();
      }
    }
  }

  /// An admin accepted the surcharge rules.
  Future<void> acknowledgeSurcharge() async {
    final gateway = _gateway;
    if (gateway == null || !isAdmin) return;
    try {
      await _repo.acknowledgeSurcharge(
        companyId,
        companyGatewayId: gateway.companyGatewayId,
      );
      final config = await _terminal.refreshConfig(companyId);
      _gateway = config?.usableGateway ?? gateway;
      _notify();
    } catch (e) {
      _problem = _problemOf(e);
      _notify();
    }
  }

  // ------------------------------------------------------------ collect

  /// The PaymentIntent of another attempt this screen is settling ("Cancel it
  /// and start again"), for Check again and the receipt.
  String? _settlingPaymentIntentId;

  String? get _paymentIntentId =>
      _intent?.paymentIntentId ?? _settlingPaymentIntentId;

  /// "Collect $X": creates the PaymentIntent and reads the card.
  Future<void> collect() async {
    if (!canCollect) return;
    _problem = null;
    _completion = null;
    _collectionId ??= _newId();
    _stage = CollectStage.creating;
    _notify();
    final intent = await _create();
    if (intent == null) return;
    _intent = intent;
    if (_stage == CollectStage.cancelled || _disposed) {
      // Cancelled (or the screen closed) while the server was creating it.
      await _cancelIntent(intent);
      return;
    }
    if (!_startSession(intent)) {
      await _abandon();
      return;
    }
    _reads = 0;
    await _read();
  }

  bool _startSession(TerminalIntent intent) {
    try {
      _session = _terminal.platform.beginPayment(intent.clientSecret);
      return true;
    } catch (e) {
      _problem = _problemOf(e);
      return false;
    }
  }

  Future<TerminalIntent?> _create() async {
    final gateway = _gateway!;
    final quote = _quote!;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await _repo.createPaymentIntent(
          companyId,
          invoiceId: _invoice.id,
          companyGatewayId: gateway.companyGatewayId,
          amount: amount,
          applyFee: applySurcharge && quote.surchargeAllowed,
          collectionId: _collectionId!,
          expectedTotal: quote.total,
        );
      } on TerminalServerError catch (e) {
        if (e.code == TerminalServerError.collectionClosed && attempt == 0) {
          _collectionId = _newId();
          continue;
        }
        _collectionId = null;
        return _refused(e);
      } on RequestNotSentException catch (e) {
        _collectionId = null;
        return _backToConfigure(_problemOf(e));
      } catch (e) {
        // The server may have created it: only this collection_id may be
        // retried, and the server answers with the same PaymentIntent.
        if (attempt < 2 && _unknownOutcome(e)) {
          await Future<void>.delayed(pollDelay);
          continue;
        }
        return _backToConfigure(_problemOf(e));
      }
    }
    return null;
  }

  static bool _unknownOutcome(Object e) =>
      e is NetworkException ||
      e is TimeoutException ||
      e is RateLimitedException ||
      (e is ServerException && e.statusCode >= 500);

  TerminalIntent? _refused(TerminalServerError e) {
    if (_stage == CollectStage.cancelled) return null;
    final problem = CollectProblem(
      serverCode: e.code,
      message: e.message,
      data: e.data,
    );
    if (e.code == TerminalServerError.collectionOpen) {
      _problem = problem;
      _stage = CollectStage.openCollection;
      _notify();
      return null;
    }
    _backToConfigure(problem);
    // The figures moved under us: ask again.
    unawaited(requote());
    return null;
  }

  TerminalIntent? _backToConfigure(CollectProblem problem) {
    if (_stage == CollectStage.cancelled) return null;
    _problem = problem;
    _stage = CollectStage.configure;
    _notify();
    return null;
  }

  /// `collection_open`: cancel the PaymentIntent that attempt left, then
  /// start again. If it was charged after all, the server records it, and
  /// this screen shows that payment.
  Future<void> cancelOpenCollection() async {
    if (_stage != CollectStage.openCollection) return;
    final pi = _problem?.data['payment_intent_id'];
    if (pi is! String || pi.isEmpty) {
      // Still being created on the server; it can't be cancelled yet.
      _problem = const CollectProblem(serverCode: 'collection_starting');
      _notify();
      return;
    }
    _settlingPaymentIntentId = pi;
    _stage = CollectStage.processing;
    _notify();
    try {
      final result = await _repo.cancel(companyId, pi, invoiceId: _invoice.id);
      if (result.status == 'canceled') {
        _settlingPaymentIntentId = null;
        _problem = null;
        _collectionId = null;
        _stage = CollectStage.configure;
        _notify();
        await requote();
        return;
      }
      if (_settle(result)) return;
      _stage = CollectStage.checking;
      _notify();
    } catch (e) {
      _settlingPaymentIntentId = null;
      _stage = CollectStage.openCollection;
      _problem = _problemOf(e);
      _notify();
    }
  }

  /// Reads the card, then lets the server decide; again while it asks.
  Future<void> _read() async {
    final session = _session!;
    final intent = _intent!;
    while (true) {
      if (_abandoned) return;
      _stage = CollectStage.waiting;
      _notify();
      final TerminalCollected collected;
      try {
        collected = await session.collect();
      } on TerminalError catch (e) {
        if (_abandoned) return;
        if (_disposed || session.isCancelled) {
          // Nobody is watching, or a reset took the reader: not charged.
          await _abandon();
          return;
        }
        _declined(e);
        return;
      }
      if (_abandoned) return;
      if (_disposed) {
        await _abandon();
        return;
      }
      _collected = collected;
      final readAt = _clock();
      // From here to the server's answer, nothing resets the SDK.
      final again = await _terminal.guardCharge(
        () => _finalizeAndConfirm(session, intent, readAt),
      );
      if (!again) return;
    }
  }

  /// Finalize, then confirm. True: read the card again.
  Future<bool> _finalizeAndConfirm(
    TerminalPaymentSession session,
    TerminalIntent intent,
    DateTime readAt,
  ) async {
    _stage = CollectStage.finalizing;
    _notify();
    final TerminalFinalize finalized;
    try {
      finalized = await _repo.finalize(companyId, intent.paymentIntentId);
    } catch (e) {
      // Never confirm on a guess.
      _problem = _problemOf(e);
      await _abandon();
      return false;
    }
    _finalized = finalized;
    _reads++;
    if (_abandoned) return false;
    if (_disposed) {
      // The screen closed while the server decided: nobody would see a
      // charge, so there is none.
      await _abandon();
      return false;
    }
    if (finalized.recollect || _clock().difference(readAt) > confirmWindow) {
      return _readAgainOrStop();
    }
    _readAgain = false;
    _stage = CollectStage.processing;
    _notify();
    try {
      await session.confirm(
        paymentIntentId: intent.paymentIntentId,
        amount: finalized.amountMinor,
      );
    } on TerminalError catch (e) {
      if (e.code == TerminalErrorCode.invalidState) {
        // The read no longer matches the server's amount: read again.
        return _readAgainOrStop();
      }
      if (e.code != TerminalErrorCode.outcomeUnknown) {
        _declined(e);
        return false;
      }
      // May have been charged: only the server can say.
    }
    await _check(intent.paymentIntentId);
    return false;
  }

  Future<bool> _readAgainOrStop() async {
    if (_reads >= maxReads) {
      _problem = const CollectProblem(code: TerminalErrorCode.cardNotRead);
      await _abandon();
      return false;
    }
    _readAgain = true;
    return true;
  }

  void _declined(TerminalError e) {
    _problem = CollectProblem(code: e.code, message: e.message);
    _stage = CollectStage.declined;
    _notify();
    // A decline nobody will see must not hold the reader or the invoice.
    if (_disposed) unawaited(_abandon());
  }

  /// "Try another card": the same PaymentIntent, read again — on a new
  /// payment session when the old one ended without a charge.
  Future<void> tryAnotherCard() async {
    final intent = _intent;
    if (_stage != CollectStage.declined || intent == null) return;
    final session = _session;
    if (session == null || session.isFinished) {
      if (!_startSession(intent)) {
        await _abandon();
        return;
      }
    }
    _problem = null;
    _reads = 0;
    await _read();
  }

  /// Asks the server what happened, a few times: a charge Stripe has just
  /// made can take a moment to show.
  Future<void> _check(String paymentIntentId) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final result = await _repo.complete(
          companyId,
          paymentIntentId,
          invoiceId: _invoice.id,
        );
        if (_settle(result)) return;
        if (result.status == 'requires_payment_method') {
          // The charge failed: the PaymentIntent takes another card.
          _problem = const CollectProblem(code: TerminalErrorCode.declined);
          _stage = CollectStage.declined;
          _notify();
          if (_disposed) unawaited(_abandon());
          return;
        }
      } catch (e) {
        _log.warning('complete failed: ${e.runtimeType}');
      }
      if (attempt < 2) await Future<void>.delayed(pollDelay);
    }
    _stage = CollectStage.checking;
    _notify();
  }

  /// "Check again" from Recording / Checking.
  Future<void> checkAgain() async {
    final pi = _paymentIntentId;
    if (pi == null) return;
    if (_stage != CollectStage.checking && _stage != CollectStage.recording) {
      return;
    }
    _stage = CollectStage.processing;
    _notify();
    await _terminal.guardCharge(() => _check(pi));
  }

  /// "Cancel the payment" from Checking: safe even if it was charged — the
  /// server then records it instead — and it frees the invoice at once.
  Future<void> cancelUnconfirmed() async {
    final pi = _paymentIntentId;
    if (pi == null || _stage != CollectStage.checking) return;
    _stage = CollectStage.processing;
    _notify();
    await _terminal.guardCharge(
      () => _cancelPaymentIntent(pi, afterConfirm: true),
    );
  }

  /// Maps a `complete` / `cancel` answer; false when it says nothing final.
  bool _settle(TerminalCompletion result) {
    _completion = result;
    switch (result.status) {
      case 'recorded' || 'unapplied':
        _stage = CollectStage.approved;
        _problem = null;
        _collectionId = null;
      case 'processing':
        _stage = CollectStage.recording;
      case 'rejected' || 'orphaned':
        _stage = CollectStage.unrecorded;
      case 'canceled':
        _stage = CollectStage.cancelled;
        _collectionId = null;
      default:
        return false;
    }
    _notify();
    return true;
  }

  // -------------------------------------------------------------- cancel

  /// Cancel, from any step before the charge. The server's cancel is what
  /// closes the PaymentIntent; if it was charged after all, its answer says
  /// so.
  Future<void> cancel() async {
    if (locked) return;
    switch (_stage) {
      case CollectStage.configure || CollectStage.openCollection:
        _stage = CollectStage.cancelled;
        _notify();
        return;
      case CollectStage.creating:
        _stage = CollectStage.cancelled;
        _notify();
        // [collect] cancels the PaymentIntent once the server answers.
        return;
      case CollectStage.waiting || CollectStage.declined:
        await _abandon();
        return;
      default:
        return;
    }
  }

  /// Gives up before any charge: the reader stops, and the server cancels
  /// the PaymentIntent.
  Future<void> _abandon() async {
    if (_abandoned) return;
    _abandoned = true;
    _session?.cancel();
    _stage = CollectStage.cancelled;
    _notify();
    final intent = _intent;
    if (intent != null) await _cancelIntent(intent);
  }

  Future<void> _cancelIntent(TerminalIntent intent) =>
      _cancelPaymentIntent(intent.paymentIntentId, afterConfirm: false);

  Future<void> _cancelPaymentIntent(
    String paymentIntentId, {
    required bool afterConfirm,
  }) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final result = await _repo.cancel(
          companyId,
          paymentIntentId,
          invoiceId: _invoice.id,
        );
        if (_settle(result)) return;
        // Stripe wouldn't cancel it (a charge in flight): it's a check now.
        _stage = CollectStage.checking;
        _notify();
        return;
      } catch (e) {
        if (attempt < 2) await Future<void>.delayed(pollDelay);
      }
    }
    // The server cancels it after 20 minutes if nobody does. Before a
    // confirm, the card wasn't charged; after one, nobody knows yet.
    _log.warning('could not cancel $paymentIntentId');
    _stage = afterConfirm ? CollectStage.checking : CollectStage.cancelled;
    _notify();
  }

  // ------------------------------------------------------------- receipt

  bool get sendingReceipt => _sendingReceipt;
  bool _sendingReceipt = false;

  Future<bool> sendReceipt(String email) async {
    final pi = _paymentIntentId;
    if (pi == null || _sendingReceipt || !(_completion?.isRecorded ?? false)) {
      return false;
    }
    _sendingReceipt = true;
    _problem = null;
    _notify();
    try {
      await _repo.receipt(companyId, pi, email: email);
      _receiptSent = true;
      return true;
    } catch (e) {
      _problem = _problemOf(e);
      return false;
    } finally {
      _sendingReceipt = false;
      _notify();
    }
  }

  // ------------------------------------------------------------- helpers

  void _fail(CollectProblem problem) {
    _problem = problem;
    _notify();
  }

  Decimal _round(Decimal value) =>
      value.round(scale: precision < 0 ? 2 : precision);

  CollectProblem _problemOf(Object e) => switch (e) {
    TerminalServerError(:final code, :final message, :final data) =>
      CollectProblem(serverCode: code, message: message, data: data),
    TerminalError(:final code, :final message) => CollectProblem(
      code: code,
      message: message,
    ),
    NetworkException() ||
    TimeoutException() => const CollectProblem(code: TerminalErrorCode.network),
    PlanRequiredException() => const CollectProblem(
      serverCode: TerminalServerError.planRequired,
    ),
    ApiException(:final message) => CollectProblem(message: message),
    _ => const CollectProblem(),
  };

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// The screen closed. Before a charge the payment is given up; while the
  /// server decides, [_finalizeAndConfirm] gives it up when it answers; a
  /// charge in flight finishes, and the server records it.
  @override
  void dispose() {
    _disposed = true;
    switch (_stage) {
      case CollectStage.waiting || CollectStage.declined:
        unawaited(_abandon());
      default:
    }
    super.dispose();
  }
}
