import 'package:store_services/store_services.dart';

/// The card reader as the app sees it: `StripeTerminal` (store_services)
/// behind an interface the tests fake (docs/in-person-payments.md).
abstract interface class TerminalPlatform {
  bool get isAvailable;

  Future<TerminalDeviceSupport> deviceSupport();

  Future<TerminalPermission> requestPermissions(TerminalReaderKind kind);

  Future<bool> openSettings();

  Future<void> initialize({
    required String account,
    required Future<String> Function() fetchToken,
  });

  Future<void> reset();

  Stream<List<TerminalReader>> discover(
    TerminalReaderKind kind, {
    bool simulated,
  });

  Future<TerminalReader> connect(
    TerminalReader reader, {
    required String locationId,
    required String merchantDisplayName,
    required bool tosAcceptancePermitted,
  });

  Future<TerminalReader?> connectedReader();

  Future<void> disconnect();

  /// Where reader prompts go; the collecting screen sets and clears it.
  set events(TerminalReaderEvents events);

  TerminalPaymentSession beginPayment(String clientSecret);
}

/// One payment on one PaymentIntent — `TerminalPayment`, whose constructor
/// is private to store_services.
abstract interface class TerminalPaymentSession {
  bool get isFinished;

  bool get isCancelled;

  Future<TerminalCollected> collect();

  Future<TerminalPaymentOutcome> confirm({
    required String paymentIntentId,
    required int amount,
  });

  void cancel();
}

class StoreTerminalPlatform implements TerminalPlatform {
  const StoreTerminalPlatform();

  @override
  bool get isAvailable => StripeTerminal.isAvailable;

  @override
  Future<TerminalDeviceSupport> deviceSupport() =>
      StripeTerminal.deviceSupport();

  @override
  Future<TerminalPermission> requestPermissions(TerminalReaderKind kind) =>
      StripeTerminal.requestPermissions(kind);

  @override
  Future<bool> openSettings() => StripeTerminal.openSettings();

  @override
  Future<void> initialize({
    required String account,
    required Future<String> Function() fetchToken,
  }) => StripeTerminal.initialize(account: account, fetchToken: fetchToken);

  @override
  Future<void> reset() => StripeTerminal.reset();

  @override
  Stream<List<TerminalReader>> discover(
    TerminalReaderKind kind, {
    bool simulated = false,
  }) => StripeTerminal.discover(kind, simulated: simulated);

  @override
  Future<TerminalReader> connect(
    TerminalReader reader, {
    required String locationId,
    required String merchantDisplayName,
    required bool tosAcceptancePermitted,
  }) => StripeTerminal.connect(
    reader,
    locationId: locationId,
    merchantDisplayName: merchantDisplayName,
    tosAcceptancePermitted: tosAcceptancePermitted,
  );

  @override
  Future<TerminalReader?> connectedReader() => StripeTerminal.connectedReader();

  @override
  Future<void> disconnect() => StripeTerminal.disconnect();

  @override
  set events(TerminalReaderEvents events) => StripeTerminal.events = events;

  @override
  TerminalPaymentSession beginPayment(String clientSecret) =>
      _StorePaymentSession(StripeTerminal.beginPayment(clientSecret));
}

class _StorePaymentSession implements TerminalPaymentSession {
  _StorePaymentSession(this._payment);

  final TerminalPayment _payment;

  @override
  bool get isFinished => _payment.isFinished;

  @override
  bool get isCancelled => _payment.isCancelled;

  @override
  Future<TerminalCollected> collect() => _payment.collect();

  @override
  Future<TerminalPaymentOutcome> confirm({
    required String paymentIntentId,
    required int amount,
  }) => _payment.confirm(paymentIntentId: paymentIntentId, amount: amount);

  @override
  void cancel() => _payment.cancel();
}
