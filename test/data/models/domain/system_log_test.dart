import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/system_log_api_model.dart';
import 'package:admin/data/models/domain/system_log.dart';

SystemLog _log({
  required int categoryId,
  required int eventId,
  required int typeId,
}) => SystemLog.fromApi(
  SystemLogApi(
    id: 'x',
    companyId: 'c1',
    eventId: eventId,
    categoryId: categoryId,
    typeId: typeId,
    createdAt: 1700000000,
    updatedAt: 1700000000,
  ),
);

void main() {
  group('SystemLog.categoryKey', () {
    test(
      'every documented React category id maps to the same translation key',
      () {
        // Mirrors `SystemLog.tsx:76-82`.
        const expectations = <int, String>{
          1: 'gateway_id',
          2: 'email',
          3: 'webhook',
          4: 'pdf',
          5: 'security',
          // Beyond React (stops at 5) — covers the server's full enum.
          6: 'log',
          7: 'verifactu',
          8: 'peppol',
        };
        for (final entry in expectations.entries) {
          expect(
            _log(categoryId: entry.key, eventId: 0, typeId: 0).categoryKey,
            entry.value,
            reason: 'category ${entry.key}',
          );
        }
      },
    );

    test('unknown ids fall back to "unknown"', () {
      expect(
        _log(categoryId: 99, eventId: 0, typeId: 0).categoryKey,
        'unknown',
      );
    });
  });

  group('SystemLog.eventKey', () {
    test('every React event id maps to its translation key', () {
      // Mirrors `SystemLog.tsx:84-101` — deliberately uses React's keys
      // (`success`, `failure`, `email_delivery`, `opened`, `login_failure`)
      // rather than v1's (`gateway_success`, `email_delivered`, …).
      const expectations = <int, String>{
        10: 'payment_failure',
        11: 'payment_success',
        21: 'success',
        22: 'failure',
        23: 'error',
        30: 'email_send',
        31: 'email_retry_queue',
        32: 'email_bounced',
        33: 'email_spam_complaint',
        34: 'email_delivery',
        35: 'opened',
        40: 'webhook_response',
        41: 'webhook_success',
        42: 'webhook_failure',
        50: 'pdf',
        60: 'login_failure',
        61: 'user',
        // Beyond React — server enum 62 + Verifactu/Peppol (70-73 reuse the
        // generic success/failure labels; the category cell carries context).
        62: 'inbound_mail_blocked',
        70: 'failure',
        71: 'success',
        72: 'failure',
        73: 'success',
      };
      for (final entry in expectations.entries) {
        expect(
          _log(categoryId: 0, eventId: entry.key, typeId: 0).eventKey,
          entry.value,
          reason: 'event ${entry.key}',
        );
      }
    });
  });

  group('SystemLog.tone', () {
    test('success/failure/warning/neutral assignments are stable', () {
      SystemLogTone toneOf(int id) =>
          _log(categoryId: 0, eventId: id, typeId: 0).tone;
      // Successes (incl. Verifactu/Peppol success 71/73)
      for (final id in [11, 21, 34, 35, 41, 71, 73]) {
        expect(toneOf(id), SystemLogTone.success, reason: 'event $id');
      }
      // Failures (incl. webhook_failure 42, inbound-mail 62, Verifactu/Peppol
      // failure 70/72)
      for (final id in [10, 22, 32, 33, 42, 60, 62, 70, 72]) {
        expect(toneOf(id), SystemLogTone.failure, reason: 'event $id');
      }
      // Warnings
      for (final id in [23, 31]) {
        expect(toneOf(id), SystemLogTone.warning, reason: 'event $id');
      }
      // Everything else
      for (final id in [30, 40, 50, 61, 99]) {
        expect(toneOf(id), SystemLogTone.neutral, reason: 'event $id');
      }
    });

    test('a neutral event falls back to the outcome on the type', () {
      // The email that made this a bug: EVENT_MAIL_SEND (30) is neutral, and
      // the "Failure" lived on TYPE_FAILURE (303) — so the row painted grey
      // and the outcome hid in the muted type caption
      // (invoiceninja/flutter#58, #59).
      SystemLogTone toneOf(int typeId) =>
          _log(categoryId: 2, eventId: 30, typeId: typeId).tone;

      expect(toneOf(303), SystemLogTone.failure); // TYPE_FAILURE
      expect(toneOf(401), SystemLogTone.failure); // TYPE_UPSTREAM_FAILURE
      expect(toneOf(600), SystemLogTone.failure); // TYPE_PDF_FAILURE
      expect(toneOf(801), SystemLogTone.failure); // TYPE_LOGIN_FAILURE
      expect(toneOf(601), SystemLogTone.success); // TYPE_PDF_SUCCESS
      expect(toneOf(800), SystemLogTone.success); // TYPE_LOGIN_SUCCESS
      // Recoverable — the server queues the mail for retry.
      expect(toneOf(400), SystemLogTone.warning); // TYPE_QUOTA_EXCEEDED
      // A gateway name carries no outcome.
      expect(toneOf(301), SystemLogTone.neutral); // TYPE_STRIPE
    });

    test('the event wins over the type when it says something', () {
      // A gateway success logged against TYPE_FAILURE would be contradictory
      // data, but the event is the more specific statement either way.
      expect(
        _log(categoryId: 1, eventId: 21, typeId: 303).tone,
        SystemLogTone.success,
      );
      expect(
        _log(categoryId: 1, eventId: 22, typeId: 601).tone,
        SystemLogTone.failure,
      );
    });
  });

  group('SystemLog.typeDisplay', () {
    test('translation-key types', () {
      final mapping = <int, String>{
        300: 'paypal',
        301: 'payment_type_stripe',
        302: 'ledger',
        303: 'failure',
        304: 'checkout_com',
        306: 'custom',
        309: 'wepay',
        321: 'gocardless',
        323: 'paypal',
      };
      for (final entry in mapping.entries) {
        final result = _log(
          categoryId: 0,
          eventId: 0,
          typeId: entry.key,
        ).typeDisplay();
        expect(result.isKey, isTrue, reason: 'type ${entry.key} should be key');
        expect(result.value, entry.value, reason: 'type ${entry.key}');
      }
    });

    test('literal-name types', () {
      final mapping = <int, String>{
        305: 'auth.net',
        307: 'Braintree',
        310: 'PayFast',
        311: 'PayTrace',
        312: 'Mollie',
        313: 'eWay',
        314: 'Forte',
        320: 'Square',
        322: 'Razorpay',
        400: 'Quota exceeded',
        401: 'Upstream failure',
        500: 'Webhook response',
        600: 'PDF Failure',
        // Deliberately corrected: React ships the typo 'PDF Sucess'
        // (SystemLog.tsx:125); we diverge to show the user the right word.
        601: 'PDF Success',
        701: 'Modified',
        702: 'Deleted',
        800: 'Login Success',
        801: 'Login Failure',
        // Beyond React — newer gateways + generic + Verifactu/Peppol types.
        324: 'BTCPay',
        325: 'Rotessa',
        326: 'Blockonomics',
        327: 'Powerboard',
        328: 'LawPay',
        329: 'Payware',
        900: 'Generic',
        1000: 'Verifactu Cancellation',
        1001: 'Verifactu Invoice',
        1002: 'Verifactu Rectification',
        1100: 'Peppol Send',
        1101: 'Peppol Receive',
      };
      for (final entry in mapping.entries) {
        final result = _log(
          categoryId: 0,
          eventId: 0,
          typeId: entry.key,
        ).typeDisplay();
        expect(
          result.isKey,
          isFalse,
          reason: 'type ${entry.key} should be literal',
        );
        expect(result.value, entry.value, reason: 'type ${entry.key}');
      }
    });

    test('unknown type falls back to "Undefined Type"', () {
      final result = _log(
        categoryId: 0,
        eventId: 0,
        typeId: 9999,
      ).typeDisplay();
      expect(result.isKey, isFalse);
      expect(result.value, 'Undefined Type');
    });
  });

  group('SystemLog.fromApi', () {
    test('unix seconds → UTC DateTime', () {
      final log = SystemLog.fromApi(
        const SystemLogApi(
          id: 'a',
          companyId: 'c',
          eventId: 30,
          categoryId: 2,
          typeId: 303,
          createdAt: 1700000000,
          updatedAt: 1700000100,
        ),
      );
      expect(log.createdAt.isUtc, isTrue);
      expect(log.createdAt.millisecondsSinceEpoch, 1700000000 * 1000);
      expect(log.updatedAt.millisecondsSinceEpoch, 1700000100 * 1000);
    });
  });
}
