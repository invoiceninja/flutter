import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/invoice_status.dart';
import 'package:admin/domain/terminal/terminal_eligibility.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_edit_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sent = emptyInvoice().copyWith(
    id: 'inv_1',
    statusId: InvoiceStatus.sent,
  );

  TerminalAvailability availability({
    bool platformReady = true,
    bool canCreatePayment = true,
    Invoice? invoice,
    bool configEnabled = true,
    bool planOk = true,
    String? accountCountry = 'US',
    TerminalReaderChoice readers = TerminalReaderChoice.tapToPay,
  }) => terminalAvailability(
    platformReady: platformReady,
    canCreatePayment: canCreatePayment,
    invoice: invoice ?? sent,
    configEnabled: configEnabled,
    planOk: planOk,
    accountCountry: accountCountry,
    readers: (_) => readers,
  );

  test('offered on a payable invoice when everything lines up', () {
    expect(availability(), TerminalAvailability.available);
    expect(
      availability(invoice: sent.copyWith(statusId: InvoiceStatus.draft)),
      TerminalAvailability.available,
      reason: 'drafts are collected on site and marked sent by the server',
    );
    expect(
      availability(invoice: sent.copyWith(statusId: InvoiceStatus.partial)),
      TerminalAvailability.available,
    );
  });

  test('a hosted plan below Pro opens the upgrade instead', () {
    expect(availability(planOk: false), TerminalAvailability.upgrade);
  });

  test('every gate hides it', () {
    expect(availability(platformReady: false), TerminalAvailability.hidden);
    expect(availability(canCreatePayment: false), TerminalAvailability.hidden);
    expect(availability(configEnabled: false), TerminalAvailability.hidden);
    expect(availability(accountCountry: null), TerminalAvailability.hidden);
    expect(
      availability(readers: TerminalReaderChoice.none),
      TerminalAvailability.hidden,
    );
    for (final status in [
      InvoiceStatus.paid,
      InvoiceStatus.cancelled,
      InvoiceStatus.reversed,
    ]) {
      expect(
        availability(invoice: sent.copyWith(statusId: status)),
        TerminalAvailability.hidden,
        reason: '$status',
      );
    }
    expect(
      availability(invoice: sent.copyWith(isDeleted: true)),
      TerminalAvailability.hidden,
    );
    expect(
      availability(invoice: sent.copyWith(id: 'tmp_123')),
      TerminalAvailability.hidden,
      reason: 'the server has never seen it',
    );
  });

  group('reader choice', () {
    TerminalReaderChoice choice({
      bool tapToPayDevice = true,
      String country = 'US',
      bool bluetoothDevice = true,
      bool readerUsed = false,
    }) => terminalReaderChoice(
      tapToPayDevice: tapToPayDevice,
      accountCountry: country,
      bluetoothDevice: bluetoothDevice,
      readerUsed: readerUsed,
    );

    test('Tap to Pay on a capable phone in a supported country', () {
      expect(choice(), TerminalReaderChoice.tapToPay);
      expect(choice(country: 'GB'), TerminalReaderChoice.tapToPay);
    });

    test('Bluetooth only once a reader has been used here — not on every '
        'phone that has Bluetooth', () {
      expect(choice(tapToPayDevice: false), TerminalReaderChoice.none);
      expect(
        choice(tapToPayDevice: false, readerUsed: true),
        TerminalReaderChoice.bluetooth,
      );
      expect(
        choice(country: 'BR', readerUsed: true),
        TerminalReaderChoice.bluetooth,
        reason: 'Tap to Pay is not offered in Brazil',
      );
      expect(
        choice(tapToPayDevice: false, bluetoothDevice: false, readerUsed: true),
        TerminalReaderChoice.none,
      );
    });
  });
}
