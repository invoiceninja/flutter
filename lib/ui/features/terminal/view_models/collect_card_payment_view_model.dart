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

  /// A credit card was read: the customer is told the surcharge before the
  /// second tap, and may say no.
  surchargeNotice,

  /// Asking the server about a payment (Check again, a cancel): no card is
  /// being read or charged.
  settling,

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
    Future<String?> Function()? chargeCurrency,
    DateTime Function()? clock,
    String Function()? newId,
    this.pollDelay = const Duration(seconds: 2),
  }) : _invoice = invoice,
       _terminal = terminal,
       _repo = repository,
       _chargeCurrency = chargeCurrency,
       _clock = clock ?? DateTime.now,
       _newId = newId ?? (() => const Uuid().v4()) {
    amount = defaultAmount(invoice);
  }

  final String companyId;
  final bool isAdmin;
  final String merchantDisplayName;

  /// The charged currency's decimals. The screen corrects it once the
  /// formatter is ready and the server has said which currency it charges.
  int precision;
  final String clientEmail;
  final Duration pollDelay;

  /// The ISO 4217 code the invoice is charged in (the client's, its
  /// group's, else the company's), or null when it can't be told — then the
  /// first gateway that takes cards is used and the server has the last word.
  final Future<String?> Function()? _chargeCurrency;
  final TerminalController _terminal;
  final TerminalRepository _repo;
  final DateTime Function() _clock;
  final String Function() _newId;

  /// Stripe allows 30 s between reading a card and charging it; past this
  /// the card is read again instead.
  static const confirmWindow = Duration(seconds: 25);

  /// Base, raised, lowered — plus one read that went stale: a card is read
  /// at most this often in a row.
  static const maxReads = 4;

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

  /// Why a configured surcharge won't be added, for the line under the
  /// switch: the business's state or country, "adjust fee percent", or this
  /// invoice (locked, over the cap, …). Null when it will be, or when none is
  /// configured.
  String? get surchargeRefusal {
    if (!kCardPresentSurcharge) return null;
    final configured = _gateway?.surcharge;
    if (configured == null) return null;
    if (!configured.allowed) {
      return switch (configured.reason) {
        'region' || 'adjust_fee_percent' => configured.reason,
        _ => null,
      };
    }
    final quote = _quote;
    if (applySurcharge && quote != null && quote.feeGross <= Decimal.zero) {
      return quote.reason ?? 'invoice';
    }
    return null;
  }

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

  /// "Try another card" on a PaymentIntent the surcharge raised: the next
  /// customer's card is read at the raised amount, so they are told first.
  bool _noticeAgain = false;

  TerminalCompletion? get completion => _completion;
  TerminalCompletion? _completion;

  bool get receiptSent => _receiptSent;
  bool _receiptSent = false;

  bool _disposed = false;

  /// From finalize to an answer, Back and every other way out are held.
  bool get locked =>
      _stage == CollectStage.finalizing ||
      _stage == CollectStage.processing ||
      _stage == CollectStage.settling;

  /// Past the point where leaving would leave a PaymentIntent behind.
  bool get inProgress => switch (_stage) {
    CollectStage.creating ||
    CollectStage.waiting ||
    CollectStage.finalizing ||
    CollectStage.surchargeNotice ||
    CollectStage.processing ||
    CollectStage.settling ||
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
  ///
  /// Also "Retry" while there is no gateway yet: a failed fetch is a
  /// connection problem, not "Card present is off".
  Future<void> start() async {
    if (_starting || _stage != CollectStage.configure) return;
    _starting = true;
    _problem = null;
    _notify();
    final bool found;
    try {
      found = await _loadGateway();
    } finally {
      _starting = false;
      _notify();
    }
    // Never a permission prompt or a reader over a screen that has closed.
    if (!found || _disposed) return;
    await Future.wait([requote(), prepareReader()]);
  }

  bool _starting = false;

  /// Loading the company's gateway, before there is one to quote with.
  bool get starting => _starting;

  /// The company's config and the gateway for the client's currency; false
  /// (with the problem set) when there is none to collect with.
  Future<bool> _loadGateway() async {
    var config = _terminal.configFor(companyId);
    if (config == null) {
      try {
        config = await _terminal.refreshConfig(companyId);
      } catch (_) {}
    }
    if (config == null) {
      // Never answered (offline, a timeout): say so, and let Retry ask again.
      _fail(
        _terminal.configState(companyId) == TerminalConfigState.serverTooOld
            ? const CollectProblem(serverCode: TerminalServerError.notEnabled)
            : const CollectProblem(code: TerminalErrorCode.network),
      );
      return false;
    }
    String? currency;
    try {
      currency = await _chargeCurrency?.call();
    } catch (_) {}
    final gateway = config.gatewayFor(currency);
    if (gateway == null) {
      _fail(
        config.usableGateway == null
            ? const CollectProblem(serverCode: TerminalServerError.notEnabled)
            : CollectProblem(
                serverCode: 'no_gateway_for_currency',
                data: {'currency': currency?.toUpperCase() ?? ''},
              ),
      );
      return false;
    }
    _gateway = gateway;
    _readerChoice = _terminal.readerChoiceFor(gateway.accountCountry);
    return true;
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
    if (_disposed) return;
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
    if (location == null || _disposed) return;
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
      _setReader(
        ReaderState.failed,
        _problemOf(_terminal.takeTokenError() ?? e),
      );
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
      _location = await _repo.createLocation(
        companyId,
        companyGatewayId: gateway.companyGatewayId,
      );
      // The cached config lists no Location yet: without this, every
      // collection opened in the next five minutes would create another
      // (and, keyed on it, drop the reader).
      unawaited(_terminal.refreshConfig(companyId));
      return _location;
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
      _setReader(
        ReaderState.needsReader,
        _problemOf(_terminal.takeTokenError() ?? e),
      );
    }
  }

  Future<bool> openSettings() => _terminal.platform.openSettings();

  /// The Bluetooth reader went away (switched off, out of range, battery):
  /// before a collection starts, ask for it again rather than claim "ready".
  ///
  /// Mid-collection the read fails on its own (declined → the screen offers
  /// to connect a reader before trying again).
  void readerDisconnected() {
    if (_readerChoice != TerminalReaderChoice.bluetooth) return;
    _reader = null;
    _setReader(ReaderState.needsReader);
  }

  /// Bound to the company it was started in: from the first server call to
  /// the server's final answer, a company switch would strand it.
  bool get bindsCompany =>
      inProgress ||
      _stage == CollectStage.checking ||
      _stage == CollectStage.recording;

  void _setReader(ReaderState state, [CollectProblem? problem]) {
    _readerState = state;
    if (problem != null) _problem = problem;
    if (state == ReaderState.ready && _problem?.code != null) _problem = null;
    _notify();
  }

  // -------------------------------------------------------------- amount

  /// Rounded to the currency; true when it changed the amount.
  bool setAmount(Decimal value) {
    if (_stage != CollectStage.configure) return false;
    final rounded = _round(value);
    if (rounded == amount) return false;
    amount = rounded;
    _collectionId = null;
    unawaited(requote());
    return true;
  }

  void setSurcharge(bool value) {
    if (_stage != CollectStage.configure || !surchargeOffered) return;
    applySurcharge = value;
    _collectionId = null;
    unawaited(requote());
  }

  /// "Retry" under the figures: loads the gateway again if that is what
  /// failed, else quotes again.
  Future<void> retry() => _gateway == null ? start() : requote();

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
      // The same gateway, with its surcharge now acknowledged.
      _gateway =
          config?.gateways
              .where((g) => g.companyGatewayId == gateway.companyGatewayId)
              .firstOrNull ??
          gateway;
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

  /// Settling another attempt's PaymentIntent ("Cancel it and start
  /// again"): none of this screen's figures are that payment's.
  bool get settlingAnother =>
      _intent == null && _settlingPaymentIntentId != null;

  /// The PaymentIntent support finds in Stripe, once there is one.
  String? get paymentReference => _paymentIntentId;

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
          // Only a fee the server actually quoted: one that rounds to
          // nothing is refused at create (`fee_not_allowed`).
          applyFee:
              applySurcharge &&
              quote.surchargeAllowed &&
              quote.feeGross > Decimal.zero,
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
    _stage = CollectStage.settling;
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
      if (!_settle(result)) {
        _stage = CollectStage.checking;
        _notify();
      }
      if (_stage == CollectStage.checking || _stage == CollectStage.recording) {
        // That attempt may have been charged: until the server answers,
        // recording a payment by hand on this invoice warns.
        await _terminal.notePending(
          companyId: companyId,
          invoiceId: _invoice.id,
          paymentIntentId: pi,
        );
      }
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
      if (_disposed) {
        // Never a reader prompt over a screen that has closed.
        await _abandon();
        return;
      }
      final raised = _finalized;
      if (raised != null &&
          raised.surcharge > Decimal.zero &&
          ((_readAgain && raised.recollect) || _noticeAgain)) {
        _noticeAgain = false;
        // Card brands want the surcharge shown before the charge, with a way
        // to say no (pay with a debit card, or not at all).
        _stage = CollectStage.surchargeNotice;
        _notify();
        final decision = _surchargeDecision = Completer<bool>();
        if (!await decision.future) {
          await _abandon();
          return;
        }
        if (_abandoned) return;
      }
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
    // Remembered before the charge, so a crash can't lose it.
    await _terminal.notePending(
      companyId: companyId,
      invoiceId: _invoice.id,
      paymentIntentId: intent.paymentIntentId,
    );
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
      if (e.code == TerminalErrorCode.canceled || session.isCancelled) {
        // A reset took the payment before the charge: not charged.
        await _abandon();
        return false;
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

  Completer<bool>? _surchargeDecision;

  /// "Continue" on the surcharge notice: read the card again at the raised
  /// amount.
  void continueWithSurcharge() {
    final decision = _surchargeDecision;
    if (_stage != CollectStage.surchargeNotice || decision == null) return;
    _surchargeDecision = null;
    decision.complete(true);
  }

  void _declineSurcharge() {
    final decision = _surchargeDecision;
    _surchargeDecision = null;
    if (decision != null && !decision.isCompleted) decision.complete(false);
  }

  void _declined(TerminalError e) {
    // Not charged: nothing left to check.
    final pi = _intent?.paymentIntentId;
    if (pi != null) unawaited(_terminal.clearPending(pi));
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
    // The PaymentIntent still carries the surcharge the last card was told
    // about; whoever presents the next card is told again.
    _noticeAgain = (_finalized?.surcharge ?? Decimal.zero) > Decimal.zero;
    await _read();
  }

  /// Asks the server what happened, a few times: a charge Stripe has just
  /// made can take a moment to show.
  ///
  /// When every attempt fails the screen goes to [unanswered]: Checking,
  /// unless the server already said it holds the charge (Recording).
  Future<void> _check(
    String paymentIntentId, {
    CollectStage unanswered = CollectStage.checking,
  }) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final result = await _repo.complete(
          companyId,
          paymentIntentId,
          invoiceId: _invoice.id,
        );
        if (_settle(result)) return;
        if (result.status == 'requires_payment_method' &&
            (_abandoned || _intent?.paymentIntentId != paymentIntentId)) {
          // Not charged, and nobody is taking another card on it: close it.
          await _cancelPaymentIntent(paymentIntentId, afterConfirm: false);
          return;
        }
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
    _stage = unanswered;
    _notify();
  }

  /// "Check again" from Recording / Checking.
  Future<void> checkAgain() async {
    final pi = _paymentIntentId;
    if (pi == null) return;
    if (_stage != CollectStage.checking && _stage != CollectStage.recording) {
      return;
    }
    // A failed check never takes back "charged, being recorded".
    final unanswered = _stage == CollectStage.recording
        ? CollectStage.recording
        : CollectStage.checking;
    _stage = CollectStage.settling;
    _notify();
    await _terminal.guardCharge(() => _check(pi, unanswered: unanswered));
  }

  /// "Cancel the payment" from Checking: safe even if it was charged — the
  /// server then records it instead — and it frees the invoice at once.
  Future<void> cancelUnconfirmed() async {
    final pi = _paymentIntentId;
    if (pi == null || _stage != CollectStage.checking) return;
    _stage = CollectStage.settling;
    _notify();
    await _terminal.guardCharge(
      () => _cancelPaymentIntent(pi, afterConfirm: true),
    );
  }

  /// Maps a `complete` / `cancel` answer; false when it says nothing final.
  bool _settle(TerminalCompletion result) {
    _completion = result;
    final pi = _paymentIntentId;
    if (pi != null && TerminalController.isFinalCompletion(result.status)) {
      unawaited(_terminal.clearPending(pi));
    }
    switch (result.status) {
      case 'recorded' || 'unapplied':
        _stage = CollectStage.approved;
        _problem = null;
        _collectionId = null;
      // The server holds the charge and is recording it.
      case 'recording':
        _stage = CollectStage.recording;
      case 'rejected' || 'orphaned':
        _stage = CollectStage.unrecorded;
      // `failed`: the server never got a PaymentIntent from Stripe.
      case 'canceled' || 'failed':
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
      case CollectStage.surchargeNotice:
        // [_read] gives the payment up when the notice is declined.
        _declineSurcharge();
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
      case CollectStage.surchargeNotice:
        _declineSurcharge();
      default:
    }
    super.dispose();
  }
}
