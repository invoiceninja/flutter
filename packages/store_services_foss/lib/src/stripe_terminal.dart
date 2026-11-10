/// FOSS stub: Stripe Terminal's SDK is non-free, so the F-Droid build takes
/// no in-person card payments (docs/in-person-payments.md).
///
/// [isStoreBuild] and [isAvailable] are false, so the app never shows the
/// action and nothing below is reached; each call fails as an unsupported
/// device if it ever is.
class StripeTerminal {
  StripeTerminal._();

  static const bool isStoreBuild = false;

  static bool get isAvailable => false;

  static TerminalReaderEvents events = const TerminalReaderEvents();

  static Future<TerminalDeviceSupport> deviceSupport() async =>
      TerminalDeviceSupport.none;

  static Future<TerminalPermission> requestPermissions(
    TerminalReaderKind kind,
  ) async => TerminalPermission.denied;

  static Future<bool> openSettings() async => false;

  static Future<void> initialize({
    required String account,
    required Future<String> Function() fetchToken,
  }) async => throw _unsupported;

  static Future<void> reset() async {}

  static Stream<List<TerminalReader>> discover(
    TerminalReaderKind kind, {
    bool simulated = false,
    Duration timeout = const Duration(seconds: 30),
  }) => Stream.error(_unsupported);

  static Future<TerminalReader> connect(
    TerminalReader reader, {
    required String locationId,
    required String merchantDisplayName,
    required bool tosAcceptancePermitted,
  }) async => throw _unsupported;

  static Future<TerminalReader?> connectedReader() async => null;

  static Stream<TerminalConnectionStatus> get connectionStatus =>
      const Stream.empty();

  static Future<void> disconnect() async {}

  static Future<bool> isTapToPayAccountLinked() async => false;

  static Future<void> installAvailableUpdate() async => throw _unsupported;

  static TerminalPayment beginPayment(String clientSecret) =>
      throw _unsupported;
}

/// FOSS stub: never constructed.
class TerminalPayment {
  TerminalPayment._();

  bool get isFinished => true;

  bool get isCancelled => false;

  Future<TerminalCollected> collect() async => throw _unsupported;

  Future<TerminalPaymentOutcome> confirm({
    required String paymentIntentId,
    required int amount,
  }) async => throw _unsupported;

  void cancel() {}
}

const _unsupported = TerminalError(TerminalErrorCode.unsupportedDevice);

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
