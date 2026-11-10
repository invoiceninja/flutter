import 'package:admin/data/services/api_exception.dart';

/// A refusal from an in-person card payment endpoint, read from the
/// `{message, error_code, ...}` body the server sends for the states the app
/// branches on (docs/in-person-payments.md). [data] carries the rest of the
/// body — `collection_open` names the PaymentIntent, its user and its age.
class TerminalServerError implements Exception {
  const TerminalServerError(this.code, this.message, [this.data = const {}]);

  /// The server's `error_code`, or [fieldErrors] for a plain 422 whose
  /// message is in [message].
  final String code;
  final String message;
  final Map<String, dynamic> data;

  static const disabled = 'disabled';
  static const planRequired = 'plan_required';
  static const notEnabled = 'not_enabled';
  static const unsupportedCurrency = 'unsupported_currency';
  static const collectionOpen = 'collection_open';
  static const collectionClosed = 'collection_closed';
  static const alreadyPaid = 'already_paid';
  static const balanceChanged = 'balance_changed';
  static const amountMismatch = 'amount_mismatch';
  static const feeNotAllowed = 'fee_not_allowed';
  static const sendInvoiceFirst = 'send_invoice_first';
  static const notCollected = 'not_collected';
  static const locationAddressRequired = 'location_address_required';

  /// A 422 with field errors and no `error_code` (`amount`, `invoice`).
  static const fieldErrors = 'field_errors';

  /// Every code the app has words for; anything else reads as a generic
  /// failure with the server's message.
  static const known = {
    disabled,
    planRequired,
    notEnabled,
    unsupportedCurrency,
    collectionOpen,
    collectionClosed,
    alreadyPaid,
    balanceChanged,
    amountMismatch,
    feeNotAllowed,
    sendInvoiceFirst,
    notCollected,
    locationAddressRequired,
    fieldErrors,
  };

  /// The terminal error inside an API failure, or null when [error] isn't
  /// one (a network failure, a 500, a plan or password prompt).
  static TerminalServerError? from(Object error) {
    final (body, message) = switch (error) {
      ConflictException(:final body, :final message) => (body, message),
      ServerException(statusCode: 403, :final body, :final message) => (
        body,
        message,
      ),
      ValidationException(:final body, :final message) => (body, message),
      _ => (null, ''),
    };
    final code = body?['error_code'];
    if (code is String && code.isNotEmpty) {
      return TerminalServerError(code, message, {
        for (final e in body!.entries)
          if (e.key != 'message' && e.key != 'error_code') e.key: e.value,
      });
    }
    if (error is ValidationException) {
      final first = error.fieldErrors.values.expand((v) => v).firstOrNull;
      return TerminalServerError(fieldErrors, first ?? error.message);
    }
    return null;
  }

  /// `collection_open`: the PaymentIntent another attempt left open.
  String? get openPaymentIntentId {
    final id = data['payment_intent_id'];
    return id is String && id.isNotEmpty ? id : null;
  }

  @override
  String toString() => 'TerminalServerError($code): $message';
}
