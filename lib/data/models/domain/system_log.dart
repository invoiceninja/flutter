import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/system_log_api_model.dart';
import 'package:admin/data/models/value/parsing.dart';

part 'system_log.freezed.dart';

/// Tone for the event badge color. The visible label always comes from
/// [SystemLog.eventKey]; the tone is purely a chrome hint.
enum SystemLogTone { success, warning, failure, neutral }

/// Server-side system log row backing Settings → System Logs. Read-only —
/// no outbox / mutation surface.
@freezed
abstract class SystemLog with _$SystemLog {
  const SystemLog._();

  const factory SystemLog({
    required String id,
    required String companyId,
    required String userId,
    required String clientId,
    required int eventId,
    required int categoryId,
    required int typeId,
    required String log,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _SystemLog;

  factory SystemLog.fromApi(SystemLogApi a) => SystemLog(
    id: a.id,
    companyId: a.companyId,
    userId: a.userId,
    clientId: a.clientId,
    eventId: a.eventId,
    categoryId: a.categoryId,
    typeId: a.typeId,
    log: a.log,
    createdAt: epochSecondsToUtc(a.createdAt),
    updatedAt: epochSecondsToUtc(a.updatedAt),
  );

  /// Translation key for the category cell. Mirrors React's
  /// `SystemLog.tsx:76-82` mapping, and extends past it to cover the server's
  /// full enum: `6=log`, `7=verifactu`, `8=peppol` (React stops at 5 and
  /// renders the rest as "Undefined Category").
  String get categoryKey {
    switch (categoryId) {
      case 1:
        return 'gateway_id';
      case 2:
        return 'email';
      case 3:
        return 'webhook';
      case 4:
        return 'pdf';
      case 5:
        return 'security';
      case 6:
        return 'log';
      case 7:
        return 'verifactu';
      case 8:
        return 'peppol';
      default:
        return 'unknown';
    }
  }

  /// Translation key for the event badge. Mirrors React's
  /// `SystemLog.tsx:84-101` mapping. Deliberately uses React's `success`
  /// / `failure` / `email_delivery` / `opened` / `login_failure` keys —
  /// v1's `system_log_model.dart` uses different (less translated) keys
  /// like `email_delivered` and `authentication_failure`.
  String get eventKey {
    switch (eventId) {
      case 10:
        return 'payment_failure';
      case 11:
        return 'payment_success';
      case 21:
        return 'success';
      case 22:
        return 'failure';
      case 23:
        return 'error';
      case 30:
        return 'email_send';
      case 31:
        return 'email_retry_queue';
      case 32:
        return 'email_bounced';
      case 33:
        return 'email_spam_complaint';
      case 34:
        return 'email_delivery';
      case 35:
        return 'opened';
      case 40:
        return 'webhook_response';
      case 41:
        return 'webhook_success';
      case 42:
        return 'webhook_failure';
      case 50:
        return 'pdf';
      case 60:
        return 'login_failure';
      case 61:
        return 'user';
      case 62:
        return 'inbound_mail_blocked';
      // Verifactu (70/71) and Peppol (72/73) reuse the generic success /
      // failure labels — the category cell already reads "Verifactu" /
      // "PEPPOL", exactly like gateway success/failure under "Gateway".
      // These extend past React, which leaves 62 and 70-73 undefined.
      case 70:
        return 'failure';
      case 71:
        return 'success';
      case 72:
        return 'failure';
      case 73:
        return 'success';
      default:
        return 'unknown';
    }
  }

  /// Tone for the event badge colour, read from the event **and** the type.
  ///
  /// The outcome is not always on the event: an email that failed to send is
  /// `event = EVENT_MAIL_SEND (30)` — neutral — with `type = TYPE_FAILURE
  /// (303)`. Reading only the event painted that row grey and buried the word
  /// "Failure" in the muted type/time caption, so a failure looked like every
  /// other line and the success/failure cue moved column depending on
  /// category (invoiceninja/flutter#58, #59). The event wins when it says
  /// something; otherwise the type does.
  SystemLogTone get tone {
    final fromEvent = _eventTone;
    return fromEvent == SystemLogTone.neutral ? _typeTone : fromEvent;
  }

  /// Outcome carried by `type_id`, for the types that encode one. Everything
  /// else — a gateway name, "Webhook response", "Peppol Send" — is neutral.
  SystemLogTone get _typeTone {
    switch (typeId) {
      case 601: // TYPE_PDF_SUCCESS
      case 800: // TYPE_LOGIN_SUCCESS
        return SystemLogTone.success;
      case 303: // TYPE_FAILURE
      case 401: // TYPE_UPSTREAM_FAILURE
      case 600: // TYPE_PDF_FAILURE
      case 801: // TYPE_LOGIN_FAILURE
        return SystemLogTone.failure;
      // A quota block is recoverable — the server queues the mail for retry
      // (`EVENT_MAIL_RETRY_QUEUE`, itself warning-toned), so it reads amber
      // rather than red.
      case 400: // TYPE_QUOTA_EXCEEDED
        return SystemLogTone.warning;
      default:
        return SystemLogTone.neutral;
    }
  }

  SystemLogTone get _eventTone {
    switch (eventId) {
      case 11:
      case 21:
      case 34:
      case 35:
      case 41:
      case 71:
      case 73:
        return SystemLogTone.success;
      case 10:
      case 22:
      case 32:
      case 33:
      case 42:
      case 60:
      case 62:
      case 70:
      case 72:
        return SystemLogTone.failure;
      case 23:
      case 31:
        return SystemLogTone.warning;
      default:
        return SystemLogTone.neutral;
    }
  }
}

extension SystemLogType on SystemLog {
  /// Display name for the type column. Some ids have translation keys
  /// (returned as `'tr:<key>'` so the UI can `context.tr(...)`); others are
  /// literal vendor names (returned as `'lit:<text>'`). React keeps both
  /// forms inline (`SystemLog.tsx:103-130`) — encoding here keeps the
  /// branching out of the widget.
  ({bool isKey, String value}) typeDisplay() {
    switch (typeId) {
      case 300:
        return (isKey: true, value: 'paypal');
      case 301:
        return (isKey: true, value: 'payment_type_stripe');
      case 302:
        return (isKey: true, value: 'ledger');
      case 303:
        return (isKey: true, value: 'failure');
      case 304:
        return (isKey: true, value: 'checkout_com');
      case 305:
        return (isKey: false, value: 'auth.net');
      case 306:
        return (isKey: true, value: 'custom');
      case 307:
        return (isKey: false, value: 'Braintree');
      case 309:
        return (isKey: true, value: 'wepay');
      case 310:
        return (isKey: false, value: 'PayFast');
      case 311:
        return (isKey: false, value: 'PayTrace');
      case 312:
        return (isKey: false, value: 'Mollie');
      case 313:
        return (isKey: false, value: 'eWay');
      case 314:
        return (isKey: false, value: 'Forte');
      case 320:
        return (isKey: false, value: 'Square');
      case 321:
        return (isKey: true, value: 'gocardless');
      case 322:
        return (isKey: false, value: 'Razorpay');
      case 323:
        return (isKey: true, value: 'paypal');
      case 324:
        return (isKey: false, value: 'BTCPay');
      case 325:
        return (isKey: false, value: 'Rotessa');
      case 326:
        return (isKey: false, value: 'Blockonomics');
      case 327:
        return (isKey: false, value: 'Powerboard');
      case 328:
        return (isKey: false, value: 'LawPay');
      case 329:
        return (isKey: false, value: 'Payware');
      case 400:
        return (isKey: false, value: 'Quota exceeded');
      case 401:
        return (isKey: false, value: 'Upstream failure');
      case 500:
        return (isKey: false, value: 'Webhook response');
      case 600:
        return (isKey: false, value: 'PDF Failure');
      case 601:
        return (isKey: false, value: 'PDF Success');
      case 701:
        return (isKey: false, value: 'Modified');
      case 702:
        return (isKey: false, value: 'Deleted');
      case 800:
        return (isKey: false, value: 'Login Success');
      case 801:
        return (isKey: false, value: 'Login Failure');
      case 900:
        return (isKey: false, value: 'Generic');
      case 1000:
        return (isKey: false, value: 'Verifactu Cancellation');
      case 1001:
        return (isKey: false, value: 'Verifactu Invoice');
      case 1002:
        return (isKey: false, value: 'Verifactu Rectification');
      case 1100:
        return (isKey: false, value: 'Peppol Send');
      case 1101:
        return (isKey: false, value: 'Peppol Receive');
      default:
        return (isKey: false, value: 'Undefined Type');
    }
  }
}
