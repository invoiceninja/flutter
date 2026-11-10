import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mek_stripe_terminal/mek_stripe_terminal.dart' as mek;

typedef _TokenSource = Future<String> Function();

/// Stripe Terminal — in-person card payments on Tap to Pay or a Bluetooth
/// reader — behind a narrow API of plain values (docs/in-person-payments.md).
///
/// Nothing the SDK returns crosses this boundary: a mek `PaymentIntent` and a
/// mek `TerminalException` both print the PaymentIntent's client secret, so
/// every result is copied into the types below and every error becomes a
/// [TerminalError].
///
/// The server decides everything about money; this only reads the card.
/// [initialize] → [discover] → [connect] once, then per payment
/// [beginPayment] → [TerminalPayment.collect] → (server) →
/// [TerminalPayment.confirm].
class StripeTerminal {
  StripeTerminal._();

  /// Whether this build carries the SDK at all (false on the F-Droid build).
  static const bool isStoreBuild = true;

  /// Whether Stripe Terminal can run here: Android and iOS only.
  static bool get isAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// What the connected reader asks the app to show. Read when each event
  /// arrives, so the screen that is collecting sets it and clears it.
  static TerminalReaderEvents events = const TerminalReaderEvents();

  /// The device check and permissions: `StripeTerminalPlugin` on Android,
  /// `StripeTerminalBridge` in Runner on iOS.
  static const MethodChannel _channel = MethodChannel(
    'invoice_ninja/stripe_terminal',
  );

  static const Duration _stepTimeout = Duration(seconds: 10);

  static _TokenSource? _fetchToken;
  static String? _account;

  /// Bumped by every [reset]: a token fetched for an earlier account is
  /// thrown away instead of handed to the SDK.
  static int _generation = 0;

  /// The last [reset] could not clear the SDK, so the next [initialize]
  /// tries again whatever the account.
  static bool _dirty = false;

  static Future<void>? _initializing;
  static Future<void> _lock = Future.value();

  /// What the last [discover] found, with the kind it was looking for: a
  /// reader's own `deviceType` can be null.
  static final Map<String, (mek.Reader, TerminalReaderKind)> _readers = {};

  static TerminalPayment? _payment;

  /// What this device can do, without starting the SDK or asking for any
  /// permission. Safe to call while deciding whether to show the action.
  static Future<TerminalDeviceSupport> deviceSupport() async {
    if (!isAvailable) return TerminalDeviceSupport.none;
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>(
        'deviceSupport',
      );
      if (raw == null) return TerminalDeviceSupport.none;
      return TerminalDeviceSupport(
        tapToPay: raw['tapToPay'] == true,
        bluetooth: raw['bluetooth'] == true,
        nfcEnabled: raw['nfcEnabled'] != false,
        locationServicesEnabled: raw['locationServicesEnabled'] != false,
        tapToPayBlocker: _codeNamed(raw['tapToPayBlocker']),
      );
    } on PlatformException {
      return TerminalDeviceSupport.none;
    } on MissingPluginException {
      return TerminalDeviceSupport.none;
    }
  }

  /// Asks for what [kind] needs: location for both, and Bluetooth (Android
  /// 12+ "Nearby devices") for a Bluetooth reader only. Concurrent calls
  /// share one request. [TerminalPermission.blocked] means the system won't
  /// ask again: offer [openSettings].
  static Future<TerminalPermission> requestPermissions(
    TerminalReaderKind kind,
  ) {
    if (!isAvailable) return Future.value(TerminalPermission.denied);
    return _permissionRequest ??= _requestPermissions(
      kind,
    ).whenComplete(() => _permissionRequest = null);
  }

  static Future<TerminalPermission>? _permissionRequest;

  static Future<TerminalPermission> _requestPermissions(
    TerminalReaderKind kind,
  ) async {
    try {
      final answer = await _channel.invokeMethod<String>('requestPermissions', {
        'kind': kind.name,
      });
      return TerminalPermission.values.asNameMap()[answer] ??
          TerminalPermission.denied;
    } on PlatformException {
      return TerminalPermission.denied;
    } on MissingPluginException {
      return TerminalPermission.denied;
    }
  }

  /// Opens this app's page in the system settings, where a blocked
  /// permission can be granted. False when it couldn't.
  static Future<bool> openSettings() async {
    if (!isAvailable) return false;
    try {
      return await _channel.invokeMethod<bool>('openSettings') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Starts the SDK for [account] (the company), with [fetchToken] answering
  /// its connection-token requests. The SDK starts once per process and
  /// caches a token and a reader session, so another account [reset]s
  /// first; the same account only swaps the source. Never call it during a
  /// payment.
  static Future<void> initialize({
    required String account,
    required Future<String> Function() fetchToken,
  }) => _serialized(() async {
    if (_dirty || (_account != null && _account != account)) await _reset();
    _account = account;
    _fetchToken = fetchToken;
    await (_initializing ??= _start());
  });

  /// Forgets the payment in progress, the reader, the cached connection
  /// token and the token source, for a sign-out or a company switch. Never
  /// throws, and every step is bounded: a session end always completes.
  static Future<void> reset() => _serialized(_reset);

  /// The readers in range, updated as they're found. Tap to Pay finds this
  /// phone; a Bluetooth scan ends with a [TerminalErrorCode.timeout] error
  /// after [timeout]. One scan at a time: cancelling the subscription stops
  /// it, and a second [discover] replaces the first.
  static Stream<List<TerminalReader>> discover(
    TerminalReaderKind kind, {
    bool simulated = false,
    Duration timeout = const Duration(seconds: 30),
  }) async* {
    final configuration = switch (kind) {
      TerminalReaderKind.tapToPay => mek.TapToPayDiscoveryConfiguration(
        isSimulated: simulated,
      ),
      TerminalReaderKind.bluetooth => mek.BluetoothDiscoveryConfiguration(
        isSimulated: simulated,
        timeoutInSeconds: timeout.inSeconds,
      ),
    };
    try {
      final terminal = _terminal;
      await for (final readers in terminal.discoverReaders(configuration)) {
        _readers
          ..clear()
          ..addEntries(readers.map((r) => MapEntry(r.serialNumber, (r, kind))));
        yield [for (final r in readers) _reader(r, kind)];
      }
    } catch (e, s) {
      Error.throwWithStackTrace(_error(e), s);
    }
  }

  /// Connects [reader] (one [discover] returned) at the Stripe Location
  /// [locationId]. [merchantDisplayName] is shown on the Tap to Pay sheet;
  /// [tosAcceptancePermitted] lets an admin accept Apple's terms here — the
  /// SDK's own default is true, so it is never left to it.
  static Future<TerminalReader> connect(
    TerminalReader reader, {
    required String locationId,
    required String merchantDisplayName,
    required bool tosAcceptancePermitted,
  }) async {
    final (found, _) =
        _readers[reader.serialNumber] ??
        (throw const TerminalError(TerminalErrorCode.readerDisconnected));
    final mek.ConnectionConfiguration configuration = switch (reader.kind) {
      TerminalReaderKind.tapToPay => mek.TapToPayConnectionConfiguration(
        locationId: locationId,
        merchantDisplayName: merchantDisplayName,
        tosAcceptancePermitted: tosAcceptancePermitted,
        readerDelegate: _TapToPayDelegate(),
      ),
      TerminalReaderKind.bluetooth => mek.BluetoothConnectionConfiguration(
        locationId: locationId,
        readerDelegate: _BluetoothDelegate(),
      ),
    };
    final connected = await _guard(
      () => _terminal.connectReader(found, configuration: configuration),
    );
    return _reader(connected, reader.kind);
  }

  /// The connected reader, or null.
  static Future<TerminalReader?> connectedReader() async {
    if (!mek.Terminal.isInitialized) return null;
    final reader = await _guard(mek.Terminal.instance.getConnectedReader);
    if (reader == null) return null;
    return _reader(reader, _readers[reader.serialNumber]?.$2);
  }

  /// Whether a reader is connected, connecting, reconnecting or scanning.
  /// Empty until [initialize] has finished.
  static Stream<TerminalConnectionStatus> get connectionStatus =>
      mek.Terminal.isInitialized
      ? mek.Terminal.instance.onConnectionStatusChange.map(
          (s) => TerminalConnectionStatus.values.byName(s.name),
        )
      : const Stream.empty();

  static Future<void> disconnect() async {
    if (!mek.Terminal.isInitialized) return;
    await _guard(mek.Terminal.instance.disconnectReader);
  }

  /// Whether this Stripe account has already accepted Apple's Tap to Pay
  /// terms (iPhone), so a non-admin can connect.
  static Future<bool> isTapToPayAccountLinked() =>
      _guard(() => _terminal.isTapToPayAccountLinked());

  /// Installs the update a Bluetooth reader announced; progress arrives on
  /// [TerminalReaderEvents.onUpdateProgress].
  static Future<void> installAvailableUpdate() =>
      _guard(() => _terminal.installAvailableUpdate());

  /// Starts a payment for the PaymentIntent behind [clientSecret]. One at a
  /// time: while another is unfinished this throws
  /// [TerminalErrorCode.readerBusy].
  static TerminalPayment beginPayment(String clientSecret) {
    if (_payment case final payment? when !payment.isFinished) {
      throw const TerminalError(TerminalErrorCode.readerBusy);
    }
    return _payment = TerminalPayment._(clientSecret);
  }

  static Future<void> _start() async {
    try {
      await _guard(() => mek.Terminal.init(fetchToken: _token));
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  /// The SDK's token source. Every failure is a [TerminalError]: the plugin
  /// relays it to native code, which can't take a null message.
  static Future<String> _token() async {
    final generation = _generation;
    final fetch = _fetchToken;
    if (fetch == null) {
      throw const TerminalError(TerminalErrorCode.sessionExpired, 'no source');
    }
    final String token;
    try {
      token = await fetch();
    } catch (e) {
      throw TerminalError(
        TerminalErrorCode.network,
        'connection token: ${e.runtimeType}',
      );
    }
    if (generation != _generation) {
      throw const TerminalError(TerminalErrorCode.sessionExpired, 'stale');
    }
    return token;
  }

  static Future<void> _reset() async {
    _generation++;
    _fetchToken = null;
    _account = null;
    _readers.clear();
    final payment = _payment;
    _payment = null;
    if (payment != null) await payment._abandon();
    if (!mek.Terminal.isInitialized) {
      _dirty = false;
      return;
    }
    final terminal = mek.Terminal.instance;
    var cleared = false;
    try {
      if (await terminal.getConnectedReader().timeout(_stepTimeout) != null) {
        await terminal.disconnectReader().timeout(_stepTimeout);
      }
      final result = await terminal.clearCachedCredentials().timeout(
        _stepTimeout,
      );
      cleared = result.isSuccessful;
    } catch (_) {}
    _dirty = !cleared;
  }

  static Future<T> _serialized<T>(Future<T> Function() body) {
    final result = _lock.then((_) => body());
    _lock = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  static mek.Terminal get _terminal => mek.Terminal.isInitialized
      ? mek.Terminal.instance
      : throw const TerminalError(
          TerminalErrorCode.unknown,
          'StripeTerminal.initialize was not called',
        );

  static Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } catch (e, s) {
      Error.throwWithStackTrace(_error(e), s);
    }
  }

  static TerminalError _error(Object e) {
    if (e is TerminalError) return e;
    if (e is mek.TerminalException) {
      return TerminalError(_codeFor(e.code), e.message);
    }
    // Code and message only: a PlatformException's details can carry the
    // PaymentIntent.
    if (e is PlatformException) {
      return TerminalError(
        TerminalErrorCode.unknown,
        '${e.code}: ${e.message}',
      );
    }
    if (e is MissingPluginException) {
      return const TerminalError(TerminalErrorCode.unsupportedDevice);
    }
    if (e is StateError) {
      return TerminalError(TerminalErrorCode.unknown, e.message);
    }
    if (e is TimeoutException) {
      return const TerminalError(TerminalErrorCode.timeout);
    }
    return const TerminalError(TerminalErrorCode.unknown);
  }

  static TerminalReader _reader(mek.Reader r, TerminalReaderKind? kind) =>
      TerminalReader(
        serialNumber: r.serialNumber,
        label: r.label ?? r.deviceType?.name ?? r.serialNumber,
        kind:
            kind ??
            (r.deviceType == mek.DeviceType.tapToPay
                ? TerminalReaderKind.tapToPay
                : TerminalReaderKind.bluetooth),
        simulated: r.simulated,
        batteryLevel: r.batteryLevel,
        hasAvailableUpdate: r.availableUpdate,
      );

  static TerminalErrorCode? _codeNamed(Object? name) => name is String
      ? TerminalErrorCode.values.asNameMap()[name] ?? TerminalErrorCode.unknown
      : null;
}

/// One payment on one PaymentIntent, from [StripeTerminal.beginPayment].
///
/// [collect] reads the card without charging it; the server then decides the
/// amount, and if it changed the PaymentIntent the card is read again with
/// another [collect]. [confirm] charges, and only the card [collect] read for
/// the amount it expects. [cancel] works until [confirm] starts and is never
/// lost: a payment cancelled between steps refuses every later step.
class TerminalPayment {
  TerminalPayment._(this._clientSecret);

  final String _clientSecret;
  mek.PaymentIntent? _collected;
  mek.CancelableFuture<mek.PaymentIntent>? _operation;
  bool _busy = false;
  bool _confirming = false;
  bool _finished = false;
  bool _cancelled = false;

  /// Cancelled, charged, or possibly charged: nothing more can be done with
  /// it here, and a new payment can begin.
  bool get isFinished => _finished;

  bool get isCancelled => _cancelled;

  /// Reads a card and attaches it to the PaymentIntent on Stripe, without
  /// charging it. [confirm] (or [cancel]) must follow within 30 seconds.
  /// Called again after the server changed the PaymentIntent — Stripe needs
  /// a fresh read then — and after a decline, for another card.
  Future<TerminalCollected> collect() async {
    _enter();
    _collected = null;
    try {
      final intent = await StripeTerminal._guard(
        () => StripeTerminal._terminal.retrievePaymentIntent(_clientSecret),
      );
      _throwIfCancelled();
      final operation = StripeTerminal._terminal.collectPaymentMethod(
        intent,
        skipTipping: true,
        shouldUpdatePaymentIntent: true,
      );
      _operation = operation;
      // Started now: mek starts an operation on its first await, and a
      // cancel before that would be lost.
      final collected = await StripeTerminal._guard(() => operation.result);
      _throwIfCancelled();
      _collected = collected;
      final details =
          collected.paymentMethod?.cardPresent ??
          collected.paymentMethod?.interactPresent;
      return TerminalCollected(
        paymentIntentId: collected.id,
        amount: collected.amount.round(),
        currency: collected.currency,
        method: collected.paymentMethod?.interactPresent != null
            ? 'interac_present'
            : 'card_present',
        funding: details?.funding?.name,
        brand: _brand(details?.brand),
        last4: details?.last4,
      );
    } finally {
      _operation = null;
      _busy = false;
    }
  }

  /// Charges the card [collect] read, for [paymentIntentId] at [amount] (the
  /// minor units the server last answered) — anything else throws
  /// [TerminalErrorCode.invalidState] without charging. Once this starts,
  /// [cancel] does nothing. A failure that may have charged the card is
  /// [TerminalErrorCode.outcomeUnknown]: ask the server.
  Future<TerminalPaymentOutcome> confirm({
    required String paymentIntentId,
    required int amount,
  }) async {
    _enter();
    final collected = _collected;
    if (collected == null ||
        collected.id != paymentIntentId ||
        collected.amount.round() != amount) {
      _busy = false;
      throw const TerminalError(
        TerminalErrorCode.invalidState,
        'not the card that was read for this amount',
      );
    }
    _confirming = true;
    _collected = null;
    try {
      // Never kept for cancel: a cancel can't undo a charge.
      final confirmed = await StripeTerminal._terminal
          .confirmPaymentIntent(collected)
          .result;
      _finished = true;
      return TerminalPaymentOutcome(
        paymentIntentId: confirmed.id,
        status: _snake(confirmed.status.name),
      );
    } catch (e) {
      final error = StripeTerminal._error(e);
      final status = e is mek.TerminalException
          ? e.paymentIntent?.status
          : null;
      // Not charged, and the PaymentIntent takes another card.
      if (error.code == TerminalErrorCode.declined ||
          status == mek.PaymentIntentStatus.requiresPaymentMethod) {
        _confirming = false;
        throw error;
      }
      _finished = true;
      throw TerminalError(TerminalErrorCode.outcomeUnknown, error.message);
    } finally {
      _busy = false;
    }
  }

  /// Stops this payment before [confirm]. Fire and forget: the SDK's cancel
  /// can hang, so it is bounded, and the server's cancel is what closes the
  /// PaymentIntent. Does nothing once [confirm] has started.
  void cancel() {
    if (_confirming || _finished) return;
    _cancelled = true;
    _finished = true;
    _collected = null;
    final operation = _operation;
    if (operation != null) {
      unawaited(
        operation
            .cancel()
            .timeout(const Duration(seconds: 5))
            .catchError((_) {}),
      );
    }
  }

  Future<void> _abandon() async {
    if (_confirming || _finished) return;
    final operation = _operation;
    cancel();
    if (operation != null) {
      await operation.result
          .timeout(const Duration(seconds: 5))
          .then<void>((_) {}, onError: (_) {});
    }
  }

  void _enter() {
    _throwIfCancelled();
    if (_finished || _busy || _confirming) {
      throw const TerminalError(TerminalErrorCode.invalidState);
    }
    _busy = true;
  }

  void _throwIfCancelled() {
    if (_cancelled) throw const TerminalError(TerminalErrorCode.canceled);
  }

  static String _snake(String name) =>
      name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

  /// Stripe's own brand names, as the server and the API use them.
  static String? _brand(mek.CardBrand? brand) => switch (brand) {
    null => null,
    mek.CardBrand.amex => 'amex',
    mek.CardBrand.dinersClub => 'diners',
    mek.CardBrand.discover => 'discover',
    mek.CardBrand.jcb => 'jcb',
    mek.CardBrand.masterCard => 'mastercard',
    mek.CardBrand.unionPay => 'unionpay',
    mek.CardBrand.visa => 'visa',
    mek.CardBrand.interac => 'interac',
    mek.CardBrand.eftposAu => 'eftpos_au',
  };
}

/// Maps a Stripe Terminal error code (mek's `TerminalExceptionCode`, so a
/// renamed code is a compile error) to the few states the app tells apart.
TerminalErrorCode _codeFor(mek.TerminalExceptionCode code) => switch (code) {
  mek.TerminalExceptionCode.canceled => TerminalErrorCode.canceled,
  mek.TerminalExceptionCode.declinedByStripeApi ||
  mek.TerminalExceptionCode.declinedByReader => TerminalErrorCode.declined,
  mek.TerminalExceptionCode.cardReadTimedOut ||
  mek.TerminalExceptionCode.bluetoothScanTimedOut => TerminalErrorCode.timeout,
  mek.TerminalExceptionCode.cardInsertNotRead ||
  mek.TerminalExceptionCode.cardSwipeNotRead ||
  mek.TerminalExceptionCode.cardSwipeNotAvailable ||
  mek.TerminalExceptionCode.cardRemoved ||
  mek.TerminalExceptionCode.cardLeftInReader ||
  mek.TerminalExceptionCode.missingEmvData => TerminalErrorCode.cardNotRead,
  mek.TerminalExceptionCode.tapToPayReaderTOSAcceptanceRequiresiCloudSignIn ||
  mek.TerminalExceptionCode.tapToPayReaderTOSAcceptanceCanceled ||
  mek.TerminalExceptionCode.tapToPayReaderTOSNotYetAccepted ||
  mek.TerminalExceptionCode.tapToPayReaderTOSAcceptanceFailed =>
    TerminalErrorCode.termsNotAccepted,
  mek.TerminalExceptionCode.tapToPayUnsupportedDevice ||
  mek.TerminalExceptionCode.tapToPayReaderDeviceBanned ||
  mek.TerminalExceptionCode.unsupportedMobileDeviceConfiguration ||
  mek.TerminalExceptionCode.tapToPayUnsupportedProcessor ||
  mek.TerminalExceptionCode.bluetoothLowEnergyUnsupported ||
  mek.TerminalExceptionCode.incompatibleReader =>
    TerminalErrorCode.unsupportedDevice,
  mek.TerminalExceptionCode.tapToPayUnsupportedOperatingSystemVersion =>
    TerminalErrorCode.unsupportedOs,
  mek.TerminalExceptionCode.tapToPayDebugNotSupported =>
    TerminalErrorCode.debugNotSupported,
  mek.TerminalExceptionCode.tapToPayInsecureEnvironment =>
    TerminalErrorCode.insecureEnvironment,
  mek.TerminalExceptionCode.tapToPayDeviceTampered ||
  mek.TerminalExceptionCode.readerTampered => TerminalErrorCode.deviceTampered,
  mek.TerminalExceptionCode.tapToPayPinUnavailable =>
    TerminalErrorCode.pinUnavailable,
  mek.TerminalExceptionCode.passcodeNotEnabled =>
    TerminalErrorCode.passcodeNotEnabled,
  mek.TerminalExceptionCode.commandNotAllowedDuringCall =>
    TerminalErrorCode.phoneCallInProgress,
  mek.TerminalExceptionCode.tapToPayReaderMerchantBlocked ||
  mek.TerminalExceptionCode.tapToPayReaderInvalidMerchant ||
  mek.TerminalExceptionCode.tapToPayReaderAccountDeactivated ||
  mek.TerminalExceptionCode.featureNotEnabledOnAccount =>
    TerminalErrorCode.accountNotEnabled,
  mek.TerminalExceptionCode.bluetoothPermissionDenied =>
    TerminalErrorCode.permissionDenied,
  mek.TerminalExceptionCode.locationServicesDisabled =>
    TerminalErrorCode.locationServicesDisabled,
  mek.TerminalExceptionCode.nfcDisabled => TerminalErrorCode.nfcDisabled,
  mek.TerminalExceptionCode.bluetoothDisabled => TerminalErrorCode.bluetoothOff,
  mek.TerminalExceptionCode.alreadyConnectedToReader =>
    TerminalErrorCode.alreadyConnected,
  mek.TerminalExceptionCode.readerBusy ||
  mek.TerminalExceptionCode.connectFailedReaderIsInUse ||
  mek.TerminalExceptionCode.readerConnectedToAnotherDevice ||
  mek.TerminalExceptionCode.bluetoothAlreadyPairedWithAnotherDevice =>
    TerminalErrorCode.readerBusy,
  mek.TerminalExceptionCode.notConnectedToReader ||
  mek.TerminalExceptionCode.bluetoothDisconnected ||
  mek.TerminalExceptionCode.bluetoothConnectTimedOut ||
  mek.TerminalExceptionCode.bluetoothReconnectStarted ||
  mek.TerminalExceptionCode.bluetoothError ||
  mek.TerminalExceptionCode.bluetoothPeerRemovedPairingInformation ||
  mek.TerminalExceptionCode.readerCommunicationError ||
  mek.TerminalExceptionCode.readerNotAccessibleInBackground ||
  mek.TerminalExceptionCode.readerMissingEncryptionKeys ||
  mek.TerminalExceptionCode.tapToPayReaderFailedToPrepare =>
    TerminalErrorCode.readerDisconnected,
  mek.TerminalExceptionCode.unsupportedReaderVersion ||
  mek.TerminalExceptionCode.readerSoftwareUpdateFailed ||
  mek.TerminalExceptionCode.readerSoftwareUpdateFailedReaderError ||
  mek.TerminalExceptionCode.readerSoftwareUpdateFailedServerError ||
  mek.TerminalExceptionCode.readerSoftwareUpdateFailedInterrupted ||
  mek.TerminalExceptionCode.readerSoftwareUpdateFailedExpiredUpdate =>
    TerminalErrorCode.updateRequired,
  mek.TerminalExceptionCode.readerSoftwareUpdateFailedBatteryLow ||
  mek.TerminalExceptionCode.readerBatteryCriticallyLow =>
    TerminalErrorCode.batteryLow,
  mek.TerminalExceptionCode.notConnectedToInternet ||
  mek
      .TerminalExceptionCode
      .notConnectedToInternetAndOfflineBehaviorRequireOnline ||
  mek.TerminalExceptionCode.requestTimedOut ||
  mek.TerminalExceptionCode.stripeApiConnectionError ||
  mek.TerminalExceptionCode.internalNetworkError ||
  mek.TerminalExceptionCode.connectionTokenProviderError ||
  mek.TerminalExceptionCode.connectionTokenProviderTimedOut =>
    TerminalErrorCode.network,
  mek.TerminalExceptionCode.sessionExpired => TerminalErrorCode.sessionExpired,
  mek.TerminalExceptionCode.confirmInvalidPaymentIntent ||
  mek.TerminalExceptionCode.invalidClientSecret ||
  mek.TerminalExceptionCode.paymentIntentNotRecovered =>
    TerminalErrorCode.invalidState,
  mek.TerminalExceptionCode.cancelFailed ||
  mek.TerminalExceptionCode.cancelFailedUnavailable =>
    TerminalErrorCode.cancelFailed,
  _ => TerminalErrorCode.unknown,
};

/// Tap to Pay (this phone) or a Bluetooth reader (Stripe M2).
enum TerminalReaderKind { tapToPay, bluetooth }

/// The answer to [StripeTerminal.requestPermissions].
enum TerminalPermission { granted, denied, blocked }

/// The SDK's reader connection state.
enum TerminalConnectionStatus {
  notConnected,
  connected,
  connecting,
  discovering,
  reconnecting,
}

/// What this device can take payments with, from a native check that starts
/// nothing and asks for nothing.
class TerminalDeviceSupport {
  const TerminalDeviceSupport({
    required this.tapToPay,
    required this.bluetooth,
    this.nfcEnabled = true,
    this.locationServicesEnabled = true,
    this.tapToPayBlocker,
  });

  static const none = TerminalDeviceSupport(tapToPay: false, bluetooth: false);

  /// The phone itself can read cards (it may still need NFC switched on).
  final bool tapToPay;

  /// The phone can pair a Bluetooth reader.
  final bool bluetooth;

  final bool nfcEnabled;

  /// Stripe takes no payment with device location off.
  final bool locationServicesEnabled;

  /// Why [tapToPay] is false, when there's something to tell the user.
  final TerminalErrorCode? tapToPayBlocker;
}

/// A reader [StripeTerminal.discover] found.
class TerminalReader {
  const TerminalReader({
    required this.serialNumber,
    required this.label,
    required this.kind,
    required this.simulated,
    required this.batteryLevel,
    required this.hasAvailableUpdate,
  });

  final String serialNumber;
  final String label;
  final TerminalReaderKind kind;
  final bool simulated;

  /// 0–1, or -1 when unknown; meaningless for Tap to Pay.
  final double batteryLevel;
  final bool hasAvailableUpdate;
}

/// What the connected reader asks of the person at the counter, while it
/// reads a card or updates. Set on [StripeTerminal.events].
class TerminalReaderEvents {
  const TerminalReaderEvents({
    this.onDisplayMessage,
    this.onInputOptions,
    this.onUpdateAvailable,
    this.onUpdateProgress,
    this.onUpdateFinished,
    this.onReconnecting,
    this.onReconnected,
    this.onDisconnected,
    this.onLowBattery,
  });

  final void Function(TerminalDisplayMessage message)? onDisplayMessage;
  final void Function(List<TerminalInputOption> options)? onInputOptions;
  final void Function()? onUpdateAvailable;

  /// 0–1 while an update installs.
  final void Function(double progress)? onUpdateProgress;

  /// An update ended: null when it installed, else why it didn't.
  final void Function(TerminalError? error)? onUpdateFinished;
  final void Function()? onReconnecting;
  final void Function()? onReconnected;
  final void Function()? onDisconnected;
  final void Function()? onLowBattery;
}

/// A prompt a Bluetooth reader asks the app to show.
enum TerminalDisplayMessage {
  retryCard,
  insertCard,
  insertOrSwipeCard,
  swipeCard,
  removeCard,
  multipleContactlessCardsDetected,
  tryAnotherReadMethod,
  tryAnotherCard,
  cardRemovedTooEarly,
  checkMobileDevice,
}

/// How the reader is ready to take the card.
enum TerminalInputOption { insertCard, swipeCard, tapCard }

/// The card [TerminalPayment.collect] read: never charged yet.
class TerminalCollected {
  const TerminalCollected({
    required this.paymentIntentId,
    required this.amount,
    required this.currency,
    required this.method,
    this.funding,
    this.brand,
    this.last4,
  });

  final String paymentIntentId;

  /// In the currency's minor units, as the PaymentIntent stood when read.
  final int amount;

  /// Lower-case ISO code, as Stripe reports it.
  final String currency;

  /// `card_present` or `interac_present`.
  final String method;

  /// `credit`, `debit` or `prepaid`, when the card says. Shown only — the
  /// server reads it from Stripe itself.
  final String? funding;

  /// Stripe's brand name: `visa`, `mastercard`, `amex`, …
  final String? brand;
  final String? last4;
}

/// What [TerminalPayment.confirm] got back from Stripe.
class TerminalPaymentOutcome {
  const TerminalPaymentOutcome({
    required this.paymentIntentId,
    required this.status,
  });

  final String paymentIntentId;

  /// Stripe's PaymentIntent status, e.g. `succeeded` or `processing`.
  final String status;
}

/// The states the app tells apart; everything else is [unknown].
enum TerminalErrorCode {
  /// Cancelled at the counter or by the app — the customer cancelling on the
  /// Tap to Pay sheet reports this too.
  canceled,

  /// Not charged: the PaymentIntent takes another card.
  declined,

  /// A confirm failed in a way that may still have charged the card. Only
  /// the server can say.
  outcomeUnknown,

  /// A step out of order: a confirm without a read for that amount, a
  /// second step while one runs, or a PaymentIntent Stripe no longer takes.
  invalidState,
  timeout,
  cardNotRead,
  termsNotAccepted,
  unsupportedDevice,
  unsupportedOs,
  debugNotSupported,
  insecureEnvironment,
  deviceTampered,
  pinUnavailable,

  /// Tap to Pay on iPhone needs a device passcode.
  passcodeNotEnabled,
  phoneCallInProgress,
  accountNotEnabled,
  permissionDenied,
  locationServicesDisabled,
  nfcDisabled,
  bluetoothOff,
  alreadyConnected,
  readerBusy,
  readerDisconnected,
  updateRequired,
  batteryLow,
  network,
  sessionExpired,
  cancelFailed,

  /// Tap to Pay on iPhone needs Apple's entitlement, which this build lacks.
  entitlementMissing,
  unknown,
}

/// A failed Stripe Terminal call. Carries no PaymentIntent and no secret.
class TerminalError implements Exception {
  const TerminalError(this.code, [this.message = '']);

  final TerminalErrorCode code;

  /// Stripe's own text, for the diagnostics log; never shown as-is.
  final String message;

  @override
  String toString() => message.isEmpty
      ? 'TerminalError(${code.name})'
      : 'TerminalError(${code.name}): $message';
}

class _BluetoothDelegate extends mek.MobileReaderDelegate {
  TerminalReaderEvents get _events => StripeTerminal.events;

  @override
  void onReportAvailableUpdate(mek.ReaderSoftwareUpdate update) =>
      _events.onUpdateAvailable?.call();

  @override
  void onStartInstallingUpdate(
    mek.ReaderSoftwareUpdate update,
    mek.Cancellable cancelUpdate,
  ) => _events.onUpdateProgress?.call(0);

  @override
  void onReportReaderSoftwareUpdateProgress(double progress) =>
      _events.onUpdateProgress?.call(progress);

  @override
  void onFinishInstallingUpdate(
    mek.ReaderSoftwareUpdate? update,
    mek.TerminalException? exception,
  ) => _events.onUpdateFinished?.call(
    exception == null ? null : StripeTerminal._error(exception),
  );

  @override
  void onRequestReaderDisplayMessage(mek.ReaderDisplayMessage message) {
    final mapped = TerminalDisplayMessage.values.asNameMap()[message.name];
    if (mapped != null) _events.onDisplayMessage?.call(mapped);
  }

  @override
  void onRequestReaderInput(List<mek.ReaderInputOption> options) =>
      _events.onInputOptions?.call([
        for (final o in options)
          ?TerminalInputOption.values.asNameMap()[o.name],
      ]);

  @override
  void onReaderReconnectStarted(
    mek.Reader reader,
    mek.Cancellable cancelReconnect,
    mek.DisconnectReason reason,
  ) => _events.onReconnecting?.call();

  @override
  void onReaderReconnectSucceeded(mek.Reader reader) =>
      _events.onReconnected?.call();

  @override
  void onReaderReconnectFailed(mek.Reader reader) =>
      _events.onDisconnected?.call();

  @override
  void onDisconnect(mek.DisconnectReason reason) =>
      _events.onDisconnected?.call();

  @override
  void onReportLowBatteryWarning() => _events.onLowBattery?.call();
}

class _TapToPayDelegate extends mek.TapToPayReaderDelegate {
  TerminalReaderEvents get _events => StripeTerminal.events;

  @override
  void onStartInstallingUpdate(
    mek.ReaderSoftwareUpdate update,
    mek.Cancellable cancelUpdate,
  ) => _events.onUpdateProgress?.call(0);

  @override
  void onReportReaderSoftwareUpdateProgress(double progress) =>
      _events.onUpdateProgress?.call(progress);

  @override
  void onFinishInstallingUpdate(
    mek.ReaderSoftwareUpdate? update,
    mek.TerminalException? exception,
  ) => _events.onUpdateFinished?.call(
    exception == null ? null : StripeTerminal._error(exception),
  );

  @override
  void onRequestReaderDisplayMessage(mek.ReaderDisplayMessage message) {}

  @override
  void onRequestReaderInput(List<mek.ReaderInputOption> options) {}

  @override
  void onReaderReconnectStarted(
    mek.Reader reader,
    mek.Cancellable cancelReconnect,
    mek.DisconnectReason reason,
  ) => _events.onReconnecting?.call();

  @override
  void onReaderReconnectSucceeded(mek.Reader reader) =>
      _events.onReconnected?.call();

  @override
  void onReaderReconnectFailed(mek.Reader reader) =>
      _events.onDisconnected?.call();

  @override
  void onDisconnect(mek.DisconnectReason reason) =>
      _events.onDisconnected?.call();
}
