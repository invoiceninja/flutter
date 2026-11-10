import 'package:store_services/store_services.dart';

import 'package:admin/data/services/terminal_server_error.dart';
import 'package:admin/ui/features/terminal/view_models/collect_card_payment_view_model.dart';

/// The words the counter sees for every way taking a card can go wrong
/// (docs/in-person-payments.md). One exhaustive switch per source, so a new
/// SDK code fails to compile until it has words; `terminal_error_text_test`
/// walks both.

/// The translation key for an SDK [code].
String terminalErrorKey(TerminalErrorCode code) => switch (code) {
  TerminalErrorCode.canceled => 'terminal_error_canceled',
  TerminalErrorCode.declined => 'terminal_error_declined',
  TerminalErrorCode.outcomeUnknown => 'terminal_checking_help',
  TerminalErrorCode.invalidState => 'terminal_error_invalid_state',
  TerminalErrorCode.timeout => 'terminal_error_timeout',
  TerminalErrorCode.cardNotRead => 'terminal_error_card_not_read',
  TerminalErrorCode.termsNotAccepted => 'terminal_error_terms_not_accepted',
  TerminalErrorCode.unsupportedDevice => 'terminal_error_unsupported_device',
  TerminalErrorCode.unsupportedOs => 'terminal_error_unsupported_os',
  TerminalErrorCode.debugNotSupported ||
  TerminalErrorCode.insecureEnvironment => 'terminal_error_insecure',
  TerminalErrorCode.deviceTampered => 'terminal_error_device_tampered',
  TerminalErrorCode.pinUnavailable => 'terminal_error_pin_unavailable',
  TerminalErrorCode.passcodeNotEnabled => 'terminal_error_passcode',
  TerminalErrorCode.phoneCallInProgress => 'terminal_error_phone_call',
  TerminalErrorCode.accountNotEnabled => 'terminal_error_account_not_enabled',
  TerminalErrorCode.permissionDenied => 'terminal_error_permission',
  TerminalErrorCode.locationServicesDisabled => 'terminal_error_location_off',
  TerminalErrorCode.nfcDisabled => 'terminal_error_nfc_off',
  TerminalErrorCode.bluetoothOff => 'terminal_error_bluetooth_off',
  TerminalErrorCode.alreadyConnected ||
  TerminalErrorCode.readerBusy => 'terminal_error_reader_busy',
  TerminalErrorCode.readerDisconnected => 'terminal_error_reader_disconnected',
  TerminalErrorCode.updateRequired => 'terminal_error_update_required',
  TerminalErrorCode.batteryLow => 'terminal_error_battery_low',
  TerminalErrorCode.network => 'terminal_error_network',
  TerminalErrorCode.sessionExpired => 'terminal_error_session_expired',
  TerminalErrorCode.cancelFailed => 'terminal_error_cancel_failed',
  TerminalErrorCode.entitlementMissing => 'terminal_error_unsupported_device',
  TerminalErrorCode.unknown => 'terminal_error_unknown',
};

/// The translation key for a server `error_code`, or null for one the app
/// has no words for (the server's own message is shown then).
String? terminalServerErrorKey(String code) => switch (code) {
  TerminalServerError.disabled => 'terminal_server_disabled',
  TerminalServerError.planRequired => 'terminal_server_plan_required',
  TerminalServerError.notEnabled => 'terminal_server_not_enabled',
  TerminalServerError.unsupportedCurrency =>
    'terminal_server_unsupported_currency',
  TerminalServerError.collectionOpen => 'terminal_server_collection_open',
  TerminalServerError.collectionClosed => 'terminal_error_unknown',
  TerminalServerError.alreadyPaid => 'terminal_server_already_paid',
  TerminalServerError.balanceChanged => 'terminal_server_balance_changed',
  TerminalServerError.amountMismatch => 'terminal_server_amount_mismatch',
  TerminalServerError.feeNotAllowed => 'terminal_server_fee_not_allowed',
  TerminalServerError.sendInvoiceFirst => 'terminal_server_send_invoice_first',
  TerminalServerError.notCollected => 'terminal_error_card_not_read',
  TerminalServerError.locationAddressRequired =>
    'terminal_server_location_address',
  'collection_starting' => 'terminal_collection_starting',
  'location_needs_admin' => 'terminal_ask_admin_location',
  _ => null,
};

/// [tr] is `context.tr`; the result is a translated sentence, never a raw
/// SDK message.
String terminalProblemText(
  CollectProblem problem,
  String Function(String key, [Map<String, String>? params]) tr,
) {
  final server = problem.serverCode;
  if (server != null) {
    if (server == TerminalServerError.fieldErrors &&
        problem.message.isNotEmpty) {
      return problem.message;
    }
    final key = terminalServerErrorKey(server);
    if (key != null) {
      return switch (server) {
        TerminalServerError.collectionOpen when problem.data['age'] is! num =>
          tr('terminal_server_collection_open_no_age', {
            'user': '${problem.data['user'] ?? ''}'.trim().isEmpty
                ? tr('terminal_someone')
                : '${problem.data['user']}',
          }),
        TerminalServerError.collectionOpen => tr(key, {
          'user': '${problem.data['user'] ?? ''}'.trim().isEmpty
              ? tr('terminal_someone')
              : '${problem.data['user']}',
          'minutes': '${((problem.data['age'] as num? ?? 0) / 60).ceil()}',
        }),
        // The server names the currency in its own message.
        TerminalServerError.unsupportedCurrency =>
          problem.message.isNotEmpty ? problem.message : tr(key),
        _ => tr(key),
      };
    }
    return problem.message.isNotEmpty
        ? problem.message
        : tr('terminal_error_unknown');
  }
  final code = problem.code;
  if (code != null) return tr(terminalErrorKey(code));
  return problem.message.isNotEmpty
      ? problem.message
      : tr('terminal_error_unknown');
}
