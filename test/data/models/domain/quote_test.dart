import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/quote_api_model.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/data/models/domain/quote_status.dart';

/// Builds a domain quote straight from the wire DTO so we also exercise
/// `Quote.fromApi` field mapping.
Quote q({
  required String statusId,
  String dueDate = '',
  String invoiceId = '',
  String projectId = '',
  Object partial = '0',
  String partialDueDate = '',
}) => Quote.fromApi(
  QuoteApi(
    statusId: statusId,
    dueDate: dueDate,
    invoiceId: invoiceId,
    projectId: projectId,
    partial: partial,
    partialDueDate: partialDueDate,
  ),
);

void main() {
  group('rejected status (id 5)', () {
    test('fromWire / labelKey map 5 → rejected (not the draft fallback)', () {
      expect(QuoteStatus.fromWire('5'), QuoteStatus.rejected);
      expect(QuoteStatus.rejected.labelKey, 'rejected');
      expect(quoteStatusLabelKey('5'), 'rejected');
    });

    test('a rejected quote reports isRejected and not the other states', () {
      final r = q(statusId: '5');
      expect(r.isRejected, isTrue);
      expect(r.isDraft, isFalse);
      expect(r.isSent, isFalse);
      expect(r.isApproved, isFalse);
      expect(r.isConverted, isFalse);
    });

    test('a past-due rejected quote is "rejected", never "expired"', () {
      final r = q(statusId: '5', dueDate: '2000-01-01');
      expect(r.isExpired, isFalse);
      expect(r.calculatedStatusId, QuoteStatus.rejected.wireId); // '5'
    });

    test('control: a past-due sent quote IS expired', () {
      final s = q(statusId: '2', dueDate: '2000-01-01');
      expect(s.isExpired, isTrue);
      expect(s.calculatedStatusId, QuoteStatusComputed.expired); // '-1'
    });
  });

  group('cancelled status (id 6)', () {
    test('fromWire / labelKey map 6 → cancelled (not the draft fallback)', () {
      expect(QuoteStatus.fromWire('6'), QuoteStatus.cancelled);
      expect(QuoteStatus.cancelled.labelKey, 'cancelled');
      expect(quoteStatusLabelKey('6'), 'cancelled');
    });

    test('a cancelled quote reports isCancelled and not the other states', () {
      final c = q(statusId: '6');
      expect(c.isCancelled, isTrue);
      expect(c.isDraft, isFalse);
      expect(c.isSent, isFalse);
      expect(c.isApproved, isFalse);
      expect(c.isRejected, isFalse);
      expect(c.isConverted, isFalse);
    });

    test('a past-due cancelled quote is "cancelled", never "expired"', () {
      final c = q(statusId: '6', dueDate: '2000-01-01');
      expect(c.isExpired, isFalse);
      expect(c.calculatedStatusId, QuoteStatus.cancelled.wireId); // '6'
    });
  });

  group('calculatedStatusId precedence', () {
    test('converted / approved / rejected trump computed states', () {
      expect(q(statusId: '4').calculatedStatusId, '4');
      expect(q(statusId: '3').calculatedStatusId, '3');
      expect(q(statusId: '5').calculatedStatusId, '5');
      // invoice_id linkage also reads as converted.
      expect(q(statusId: '2', invoiceId: 'inv_1').isConverted, isTrue);
    });
  });

  group('approve/convert eligibility inputs (getter matrix)', () {
    // The detail + bulk eligibility rules are pure functions of these getters:
    //   approve  → isDraft || isSent
    //   convert  → !isConverted
    // so verifying the getters locks the reconciled behaviour in place.
    bool canApprove(Quote x) => x.isDraft || x.isSent;
    bool canConvert(Quote x) => !x.isConverted;

    test('approve allowed only for draft + sent', () {
      expect(canApprove(q(statusId: '1')), isTrue); // draft
      expect(canApprove(q(statusId: '2')), isTrue); // sent
      expect(canApprove(q(statusId: '3')), isFalse); // approved
      expect(canApprove(q(statusId: '4')), isFalse); // converted
      expect(canApprove(q(statusId: '5')), isFalse); // rejected
    });

    test('convert allowed until converted (incl. drafts + rejected)', () {
      expect(canConvert(q(statusId: '1')), isTrue);
      expect(canConvert(q(statusId: '5')), isTrue);
      expect(canConvert(q(statusId: '4')), isFalse);
      expect(canConvert(q(statusId: '2', invoiceId: 'inv_1')), isFalse);
    });
  });

  group('field round-trip', () {
    test(
      'deposit (partial + partial_due_date) survives fromApi → toApiJson',
      () {
        final d = q(statusId: '2', partial: '50', partialDueDate: '2026-07-01');
        expect(d.partial, Decimal.fromInt(50));
        expect(d.partialDueDate?.toIso(), '2026-07-01');

        final json = d.toApiJson();
        expect(json['partial'], '50');
        expect(json['partial_due_date'], '2026-07-01');
      },
    );

    test(
      'last_sent_date / next_send_date are read-only (parsed, never sent)',
      () {
        final d = Quote.fromApi(
          const QuoteApi(
            statusId: '2',
            lastSentDate: '2026-06-01',
            nextSendDate: '2026-06-15',
          ),
        );
        expect(d.lastSentDate?.toIso(), '2026-06-01');
        expect(d.nextSendDate?.toIso(), '2026-06-15');

        final json = d.toApiJson();
        expect(json.containsKey('last_sent_date'), isFalse);
        expect(json.containsKey('next_send_date'), isFalse);
      },
    );
  });
}
