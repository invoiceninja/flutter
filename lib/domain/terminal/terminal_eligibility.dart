import 'package:admin/data/models/domain/invoice.dart';

/// Whether an invoice offers "Collect card payment", decided from plain
/// facts so every gate is testable (docs/in-person-payments.md). A leaf: no
/// services, no SDK.

/// Build-time switches, all on: `--dart-define=IN_CARD_PRESENT=false` removes
/// the feature, the other two remove one part of it.
const bool kCardPresentEnabled = bool.fromEnvironment(
  'IN_CARD_PRESENT',
  defaultValue: true,
);
const bool kCardPresentBluetooth = bool.fromEnvironment(
  'IN_CARD_PRESENT_BLUETOOTH',
  defaultValue: true,
);
const bool kCardPresentSurcharge = bool.fromEnvironment(
  'IN_CARD_PRESENT_SURCHARGE',
  defaultValue: true,
);

/// Account countries where Stripe offers Tap to Pay on Android, generally
/// available or in public preview (docs.stripe.com/terminal/payments/
/// setup-reader/tap-to-pay?platform=android, read 2026-11-10).
const Set<String> kTapToPayAndroidCountries = {
  'AT', 'AU', 'BE', 'CA', 'CH', 'DE', 'DK', 'FI', 'FR', 'GB', 'IE', //
  'IT', 'MY', 'NL', 'NO', 'NZ', 'PL', 'PT', 'SE', 'SG', 'US', //
  'BG', 'CY', 'CZ', 'EE', 'ES', 'GI', 'HK', 'HR', 'HU', 'JP', //
  'LI', 'LT', 'LU', 'LV', 'MT', 'MX', 'RO', 'SI', 'SK', //
};

enum TerminalAvailability {
  hidden,

  /// Shown, and opens the upgrade flow: a hosted plan below Pro.
  upgrade,
  available,
}

/// How the app may read a card here.
enum TerminalReaderChoice { tapToPay, bluetooth, none }

/// [tapToPayDevice]: this phone can do Tap to Pay. [readerUsed]: a Bluetooth
/// reader has been connected in this app before — the action isn't offered
/// to every phone that merely has Bluetooth.
TerminalReaderChoice terminalReaderChoice({
  required bool tapToPayDevice,
  required String accountCountry,
  required bool bluetoothDevice,
  required bool readerUsed,
}) {
  if (tapToPayDevice && kTapToPayAndroidCountries.contains(accountCountry)) {
    return TerminalReaderChoice.tapToPay;
  }
  if (kCardPresentBluetooth && bluetoothDevice && readerUsed) {
    return TerminalReaderChoice.bluetooth;
  }
  return TerminalReaderChoice.none;
}

/// [platformReady]: the build has the feature, this is the mobile app with
/// Stripe's SDK, and not the demo. [configEnabled] / [planOk] /
/// [accountCountry] come from the server's `terminal/config`; a null
/// [accountCountry] means no usable gateway (or no answer).
TerminalAvailability terminalAvailability({
  required bool platformReady,
  required bool canCreatePayment,
  required Invoice invoice,
  required bool configEnabled,
  required bool planOk,
  required String? accountCountry,
  required TerminalReaderChoice Function(String accountCountry) readers,
}) {
  if (!platformReady || !canCreatePayment) return TerminalAvailability.hidden;
  if (invoice.isDeleted ||
      invoice.isPaid ||
      invoice.isCancelled ||
      invoice.isReversed ||
      invoice.id.isEmpty ||
      invoice.id.startsWith('tmp_')) {
    return TerminalAvailability.hidden;
  }
  if (!configEnabled || accountCountry == null) {
    return TerminalAvailability.hidden;
  }
  if (readers(accountCountry) == TerminalReaderChoice.none) {
    return TerminalAvailability.hidden;
  }
  return planOk ? TerminalAvailability.available : TerminalAvailability.upgrade;
}
