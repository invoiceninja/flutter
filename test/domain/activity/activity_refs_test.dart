import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/activity.dart';
import 'package:admin/domain/activity/activity_refs.dart';
import 'package:admin/domain/entity_type.dart';

Activity _a(Map<String, ActivityRef> refs, {int typeId = 19}) => Activity(
  id: 'a1',
  activityTypeId: typeId,
  notes: '',
  createdAt: DateTime.utc(2026, 5, 18, 12),
  ip: '',
  refs: refs,
);

const _quote = ActivityRef(label: '0092', type: EntityType.quote, id: 'q1');
const _invoice = ActivityRef(label: '0012', type: EntityType.invoice, id: 'i1');
const _payment = ActivityRef(label: '0001', type: EntityType.payment, id: 'p1');
const _client = ActivityRef(label: 'Acme', type: EntityType.client, id: 'c1');

void main() {
  group('activityRowTargetRef (invoiceninja/flutter#143)', () {
    test('opens the document the sentence names', () {
      // The reported row: `activity_19` = ":user updated quote :quote", read on
      // the client's Activity tab.
      expect(
        activityRowTargetRef(
          _a({'user': const ActivityRef(label: 'Jane'), 'quote': _quote}),
          host: 'client',
          namedTokens: {'user', 'quote'},
        ),
        _quote,
      );
    });

    test('a ref the sentence never names is never the target', () {
      // `RefundPayment::createActivity` stamps `invoice_id` on a
      // REFUNDED_PAYMENT row whose template names only `:payment`. Priority
      // alone would open an invoice this row does not mention.
      expect(
        activityRowTargetRef(
          _a({'payment': _payment, 'invoice': _invoice}, typeId: 40),
          host: 'client',
          namedTokens: {'payment'},
        ),
        _payment,
      );
      // And the mirror image: `InvoicePaidActivity` stamps `payment_id` on a
      // ":user paid invoice :invoice" row.
      expect(
        activityRowTargetRef(
          _a({'payment': _payment, 'invoice': _invoice}, typeId: 54),
          host: 'client',
          namedTokens: {'invoice'},
        ),
        _invoice,
      );
    });

    test('both named: priority decides, and invoice wins (activity_10)', () {
      // ":user entered payment :payment for invoice :invoice for :client" —
      // either is a record the row names, so the tie-break is safe. Invoice
      // matches `activityDeepLinkTarget`, so /activity and the tab agree.
      expect(
        activityRowTargetRef(
          _a({'payment': _payment, 'invoice': _invoice, 'client': _client}),
          host: 'client',
          namedTokens: {'payment', 'invoice', 'client'},
        ),
        _invoice,
      );
    });

    test('the record on screen is never the target', () {
      expect(
        activityRowTargetRef(
          _a({'quote': _quote}),
          host: 'quote',
          namedTokens: {'quote'},
        ),
        isNull,
      );
    });

    test('skipping the host still reaches another named document', () {
      expect(
        activityRowTargetRef(
          _a({'payment': _payment, 'invoice': _invoice}),
          host: 'invoice',
          namedTokens: {'payment', 'invoice'},
        ),
        _payment,
      );
    });

    test('a party is never a target, however prominently it is named', () {
      expect(
        activityRowTargetRef(
          _a({'client': _client}),
          host: 'invoice',
          namedTokens: {'client'},
        ),
        isNull,
      );
    });

    test('a ref with no route is not a target', () {
      expect(
        activityRowTargetRef(
          _a({'payment': const ActivityRef(label: '0001')}),
          host: 'client',
          namedTokens: {'payment'},
        ),
        isNull,
        reason: 'no type — goEntityRecord would have nowhere to go',
      );
      expect(
        activityRowTargetRef(
          _a({
            'payment': const ActivityRef(
              label: '0001',
              type: EntityType.payment,
            ),
          }),
          host: 'client',
          namedTokens: {'payment'},
        ),
        isNull,
        reason: 'empty id',
      );
    });

    test('a sentence that names nothing is inert', () {
      // `activity_unknown` — no template, so no tokens were substituted.
      expect(
        activityRowTargetRef(
          _a({'quote': _quote}),
          host: 'client',
          namedTokens: const {},
        ),
        isNull,
      );
    });

    test('an expense the sentence NAMES survives on an alias host', () {
      // The mirror of the note rule below. `kExpenseIdAliasHosts` exists
      // because `note()` harvests refs nobody wrote; a template that spells
      // `:expense` (activity_34/35/36/37/47/139/148) is the opposite case, so
      // applying that skip here would strand a real expense with no chevron,
      // no row tap and — on touch — no link either.
      const expense = ActivityRef(
        label: '7',
        type: EntityType.expense,
        id: 'e1',
      );
      for (final host in kExpenseIdAliasHosts) {
        expect(
          activityRowTargetRef(
            _a({'expense': expense}),
            host: host,
            namedTokens: {'expense'},
          ),
          expense,
          reason: '$host: the sentence names it, so it is a real relation',
        );
      }
    });
  });

  group('activityNoteSourceRef (invoiceninja/flutter#121, #123)', () {
    test('names the document a note was filed against', () {
      expect(
        activityNoteSourceRef(
          _a({'invoice': _invoice, 'client': _client}, typeId: 141),
          host: 'client',
        ),
        _invoice,
      );
    });

    test('takes a label-only ref — a note has no links to hang', () {
      const labelOnly = ActivityRef(label: '0012');
      expect(
        activityNoteSourceRef(
          _a({'invoice': labelOnly}, typeId: 141),
          host: 'client',
        ),
        labelOnly,
      );
    });

    test('skips the record on screen, and blank labels', () {
      expect(
        activityNoteSourceRef(
          _a({'invoice': _invoice}, typeId: 141),
          host: 'invoice',
        ),
        isNull,
      );
      expect(
        activityNoteSourceRef(
          // `ClientContactRepository::save` writes a literal single space.
          _a({'invoice': const ActivityRef(label: ' ')}, typeId: 141),
          host: 'client',
        ),
        isNull,
      );
    });

    test('drops the expense alias on a PO / recurring-expense screen', () {
      final refs = {
        'expense': const ActivityRef(label: '7', type: EntityType.expense),
      };
      for (final host in kExpenseIdAliasHosts) {
        expect(
          activityNoteSourceRef(_a(refs, typeId: 141), host: host),
          isNull,
          reason: '$host writes its own id into activities.expense_id',
        );
      }
      expect(
        activityNoteSourceRef(_a(refs, typeId: 141), host: 'client'),
        isNotNull,
        reason: 'on any other screen the expense ref is a real relation',
      );
    });

    test('a null host disables the suffix', () {
      expect(
        activityNoteSourceRef(
          _a({'invoice': _invoice}, typeId: 141),
          host: null,
        ),
        isNull,
      );
    });
  });
}
