import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/dashboard/dashboard_list_rows.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/email/billing_doc_email_sheet.dart';
import 'package:admin/ui/features/dashboard/helpers/needs_attention.dart';

/// A fixed "today", nowhere near a month edge so `addDays` reads plainly.
const _today = Date(2026, 10, 14);

DashboardInvoiceRow _inv(
  String id, {
  Date? due,
  String balance = '100',
  String currency = '',
  String? partial,
  Date? partialDue,
  Date? reminded,
  int reminders = 0,
  Date? viewed,
  bool sent = false,
}) => DashboardInvoiceRow(
  id: id,
  number: id,
  clientId: 'c',
  clientName: 'Client',
  dueDate: due,
  balance: Decimal.parse(balance),
  amount: Decimal.parse(balance),
  statusId: 2,
  currencyId: currency,
  partial: partial == null ? null : Decimal.parse(partial),
  partialDueDate: partialDue,
  lastReminderDate: reminded,
  remindersSent: reminders,
  lastViewed: viewed,
  wasSent: sent,
);

DashboardQuoteRow _quote(String id, {Date? validUntil}) => DashboardQuoteRow(
  id: id,
  number: id,
  clientId: 'c',
  clientName: 'Client',
  date: const Date(2026, 9, 1),
  validUntil: validUntil,
  amount: Decimal.fromInt(50),
  statusId: 2,
  currencyId: '',
);

void main() {
  group('past due', () {
    test('counts with the server total and sums what is late', () {
      final a = needsAttention(
        pastDue: DashboardRows([
          _inv('1', due: const Date(2026, 10, 1), balance: '120'),
          _inv('2', due: const Date(2026, 10, 10), balance: '30.50'),
        ], total: 2),
        upcomingInvoices: const [],
        upcomingQuotes: const [],
        today: _today,
      );
      expect(a.pastDueCount, const AttentionCount(2, exact: true));
      expect(a.pastDueSum, Decimal.parse('150.50'));
      expect(a.tabs, [AttentionTab.pastDue]);
    });

    test('a page that is not the whole list gives no sum', () {
      final a = needsAttention(
        pastDue: DashboardRows([
          _inv('1', due: const Date(2026, 10, 1)),
          _inv('2', due: const Date(2026, 10, 2)),
        ], total: 80),
        upcomingInvoices: const [],
        upcomingQuotes: const [],
        today: _today,
      );
      // The count is still exact — the server said how many.
      expect(a.pastDueCount, const AttentionCount(80, exact: true));
      expect(a.pastDueSum, isNull);
    });

    test('mixed currencies give no sum', () {
      final a = needsAttention(
        pastDue: DashboardRows([
          _inv('1', due: const Date(2026, 10, 1), currency: '1'),
          _inv('2', due: const Date(2026, 10, 2), currency: '2'),
        ], total: 2),
        upcomingInvoices: const [],
        upcomingQuotes: const [],
        today: _today,
      );
      expect(a.pastDueSum, isNull);
    });

    test('no override and the company currency are one currency', () {
      final a = needsAttention(
        pastDue: DashboardRows([
          _inv('1', due: const Date(2026, 10, 1), currency: ''),
          _inv('2', due: const Date(2026, 10, 2), currency: '1'),
        ], total: 2),
        upcomingInvoices: const [],
        upcomingQuotes: const [],
        today: _today,
        companyCurrencyId: '1',
      );
      expect(a.pastDueSum, Decimal.fromInt(200));
      expect(a.pastDueCurrencyId, '1');
    });

    test('a payload cached before totals: a short page is still whole', () {
      final a = needsAttention(
        pastDue: [_inv('1', due: const Date(2026, 10, 1))],
        upcomingInvoices: const [],
        upcomingQuotes: const [],
        today: _today,
      );
      expect(a.pastDueCount, const AttentionCount(1, exact: true));
      expect(a.pastDueSum, Decimal.fromInt(100));
    });

    test('a full page with no total is "at least", with no sum', () {
      final a = needsAttention(
        pastDue: [
          for (var i = 0; i < 50; i++) _inv('$i', due: const Date(2026, 10, 1)),
        ],
        upcomingInvoices: const [],
        upcomingQuotes: const [],
        today: _today,
      );
      expect(a.pastDueCount, const AttentionCount(50, exact: false));
      expect('${a.pastDueCount}', '50+');
      expect(a.pastDueSum, isNull);
    });

    test(
      'only the deposit is late while the invoice itself is not yet due',
      () {
        final deposit = _inv(
          '1',
          due: const Date(2026, 11, 30),
          balance: '10000',
          partial: '1000',
          partialDue: const Date(2026, 10, 7),
        );
        final a = needsAttention(
          pastDue: DashboardRows([deposit], total: 1),
          upcomingInvoices: const [],
          upcomingQuotes: const [],
          today: _today,
        );
        expect(a.pastDueSum, Decimal.fromInt(1000));
        // Measured from the deposit's date, not the invoice's (which is ahead).
        expect(daysLate(deposit, _today), 7);
      },
    );

    test('once the invoice itself is due the whole balance is late', () {
      final row = _inv(
        '1',
        due: const Date(2026, 10, 10),
        balance: '10000',
        partial: '1000',
        partialDue: const Date(2026, 10, 1),
      );
      expect(lateAmountOfRow(row, _today), Decimal.fromInt(10000));
      expect(daysLate(row, _today), 4);
    });

    test('nothing late on the row is zero days', () {
      expect(daysLate(_inv('1', due: _today), _today), 0);
      expect(daysLate(_inv('1'), _today), 0);
    });
  });

  group('due soon', () {
    test('today through seven days out, soonest first', () {
      final a = needsAttention(
        pastDue: const [],
        upcomingInvoices: DashboardRows([
          _inv('later', due: const Date(2026, 10, 21)),
          _inv('beyond', due: const Date(2026, 10, 22)),
          _inv('today', due: _today),
          _inv('undated'),
          _inv('soon', due: const Date(2026, 10, 16)),
        ], total: 5),
        upcomingQuotes: const [],
        today: _today,
      );
      expect(a.dueSoon.map((r) => r.id), ['today', 'soon', 'later']);
      expect(a.dueSoonCount, const AttentionCount(3, exact: true));
    });

    test('a deposit due this week counts, at its own date', () {
      final a = needsAttention(
        pastDue: const [],
        upcomingInvoices: DashboardRows([
          _inv('plain', due: const Date(2026, 10, 18)),
          _inv(
            'deposit',
            due: const Date(2026, 12, 1),
            partial: '50',
            partialDue: const Date(2026, 10, 15),
          ),
        ], total: 2),
        upcomingQuotes: const [],
        today: _today,
      );
      expect(a.dueSoon.map((r) => r.id), ['deposit', 'plain']);
    });

    test('a partial page makes the count a lower bound', () {
      final a = needsAttention(
        pastDue: const [],
        upcomingInvoices: DashboardRows([
          _inv('1', due: const Date(2026, 10, 15)),
        ], total: 120),
        upcomingQuotes: const [],
        today: _today,
      );
      expect(a.dueSoonCount, const AttentionCount(1, exact: false));
    });

    test('the next invoice due is named even when it is weeks away', () {
      final a = needsAttention(
        pastDue: const [],
        upcomingInvoices: [
          _inv('far', due: const Date(2026, 12, 1)),
          _inv('nearer', due: const Date(2026, 11, 20)),
          _inv('undated'),
        ],
        upcomingQuotes: const [],
        today: _today,
      );
      expect(a.dueSoon, isEmpty);
      expect(a.nextDue?.id, 'nearer');
      expect(a.isEmpty, isTrue);
    });
  });

  group('quotes expiring', () {
    test('valid until within the week, soonest first', () {
      final a = needsAttention(
        pastDue: const [],
        upcomingInvoices: const [],
        upcomingQuotes: DashboardRows([
          _quote('b', validUntil: const Date(2026, 10, 20)),
          _quote('far', validUntil: const Date(2026, 11, 20)),
          _quote('a', validUntil: const Date(2026, 10, 15)),
          _quote('open'),
        ], total: 4),
        today: _today,
      );
      expect(a.quotesExpiring.map((q) => q.id), ['a', 'b']);
      expect(a.quotesExpiringCount, const AttentionCount(2, exact: true));
      expect(a.tabs, [AttentionTab.quotesExpiring]);
    });
  });

  group('gates and loading', () {
    test('a module that is off contributes nothing, whatever was fetched', () {
      final a = needsAttention(
        pastDue: [_inv('1', due: const Date(2026, 10, 1))],
        upcomingInvoices: [_inv('2', due: const Date(2026, 10, 15))],
        upcomingQuotes: [_quote('q', validUntil: const Date(2026, 10, 15))],
        today: _today,
        invoices: false,
        quotes: false,
      );
      expect(a.isEmpty, isTrue);
      expect(a.tabs, isEmpty);
      expect(a.nextDue, isNull);
    });

    test('a list that has not loaded has no tab, and claims nothing', () {
      final a = needsAttention(
        pastDue: null,
        upcomingInvoices: null,
        upcomingQuotes: null,
        today: _today,
      );
      expect(a.isEmpty, isTrue);
      expect(a.pastDueSum, isNull);
    });

    test('tabs come in a fixed order', () {
      final a = needsAttention(
        pastDue: [_inv('1', due: const Date(2026, 10, 1))],
        upcomingInvoices: [_inv('2', due: const Date(2026, 10, 15))],
        upcomingQuotes: [_quote('q', validUntil: const Date(2026, 10, 15))],
        today: _today,
      );
      expect(a.tabs, AttentionTab.values);
      expect(a.countFor(AttentionTab.dueSoon).value, 1);
    });
  });

  group('what the row knows', () {
    test('the most recent of reminded and viewed wins', () {
      expect(
        attentionFact(
          _inv(
            '1',
            reminded: const Date(2026, 10, 5),
            viewed: const Date(2026, 10, 2),
          ),
        ),
        const AttentionFact(AttentionFactKind.reminded, Date(2026, 10, 5)),
      );
      expect(
        attentionFact(
          _inv(
            '1',
            reminded: const Date(2026, 10, 1),
            viewed: const Date(2026, 10, 2),
          ),
        ),
        const AttentionFact(AttentionFactKind.viewed, Date(2026, 10, 2)),
      );
    });

    test('sent and never opened says so; never sent says nothing', () {
      expect(
        attentionFact(_inv('1', sent: true)),
        const AttentionFact(AttentionFactKind.notOpened),
      );
      expect(attentionFact(_inv('1')), isNull);
    });

    test('the next reminder is the first one not yet sent', () {
      expect(nextInvoiceReminderTemplate(_inv('1')), 'reminder1');
      expect(nextInvoiceReminderTemplate(_inv('1', reminders: 1)), 'reminder2');
      expect(nextInvoiceReminderTemplate(_inv('1', reminders: 2)), 'reminder3');
      expect(
        nextInvoiceReminderTemplate(_inv('1', reminders: 3)),
        'reminder_endless',
      );
    });

    // The Send Email screen opens on the template it is asked for only when
    // that template is one it offers; anything else falls back, silently, to
    // the first — the *initial invoice* email, which is exactly what a
    // "Remind" tap must not send. So every id the band can pass has to be in
    // the screen's own list.
    test('every reminder the band asks for is one the email screen has', () {
      final invoiceTemplates = BillingEmailTemplate.forType(
        BillingDocType.invoice,
      ).map((t) => t.value).toSet();
      for (var sent = 0; sent <= 6; sent++) {
        expect(
          invoiceTemplates,
          contains(nextInvoiceReminderTemplate(_inv('1', reminders: sent))),
          reason: '$sent reminders sent',
        );
      }
      expect(
        BillingEmailTemplate.forType(BillingDocType.quote).map((t) => t.value),
        contains(kQuoteReminderTemplate),
      );
    });
  });

  group('rows from the wire', () {
    test('an invoice row reads the facts the band needs', () {
      final row = DashboardInvoiceRow.fromJson({
        'id': 'i1',
        'number': '0042',
        'client_id': 'c1',
        'client': {
          'display_name': 'Acme',
          'settings': {'currency_id': '2'},
        },
        'due_date': '2026-11-30',
        'balance': 10000,
        'amount': 10000,
        'status_id': '2',
        'partial': 1000,
        'partial_due_date': '2026-10-07',
        'user_id': 'u1',
        'assigned_user_id': 'u2',
        'reminder1_sent': '2026-10-08',
        'reminder2_sent': '',
        'reminder3_sent': '',
        'reminder_last_sent': '2026-10-08',
        'invitations': [
          {'sent_date': '2026-10-01 09:00:00', 'viewed_date': ''},
          // Midday UTC is the same calendar day from UTC−11 to UTC+11.
          {'sent_date': '', 'viewed_date': '2026-10-02 12:00:00'},
        ],
      });
      expect(row.partial, Decimal.fromInt(1000));
      expect(row.partialDueDate, const Date(2026, 10, 7));
      expect(row.userId, 'u1');
      expect(row.assignedUserId, 'u2');
      expect(row.lastReminderDate, const Date(2026, 10, 8));
      expect(row.remindersSent, 1);
      expect(row.wasSent, isTrue);
      expect(row.lastViewed, const Date(2026, 10, 2));
      expect(row.currencyId, '2');
    });

    test('a row with none of it is plain', () {
      final row = DashboardInvoiceRow.fromJson({
        'id': 'i1',
        'due_date': '',
        'partial': 0,
        'partial_due_date': '',
      });
      expect(row.partial, isNull);
      expect(row.partialDueDate, isNull);
      expect(row.lastReminderDate, isNull);
      expect(row.remindersSent, 0);
      expect(row.wasSent, isFalse);
      expect(row.lastViewed, isNull);
    });

    test('a quote reads valid-until from due_date', () {
      final q = DashboardQuoteRow.fromJson({
        'id': 'q1',
        'date': '2026-10-01',
        'due_date': '2026-10-20',
      });
      expect(q.validUntil, const Date(2026, 10, 20));
    });

    test('a list keeps the paginator total; a bare list has none', () {
      final withTotal = DashboardInvoiceRow.listFromJson({
        'rows': [
          {'id': 'a'},
          {'id': 'b'},
        ],
        'total': 80,
      });
      expect(withTotal, hasLength(2));
      expect(withTotal.serverTotal, 80);
      expect(withTotal.isCompleteList, isFalse);

      final bare = DashboardInvoiceRow.listFromJson([
        {'id': 'a'},
      ]);
      expect(bare, hasLength(1));
      expect(bare.serverTotal, isNull);
      expect(bare.isCompleteList, isFalse);

      final whole = DashboardInvoiceRow.listFromJson({
        'rows': [
          {'id': 'a'},
        ],
        'total': 1,
      });
      expect(whole.isCompleteList, isTrue);
    });
  });

  // Who gets which of the band's columns on a wide screen. Columns stay
  // narrow; a list with more rows than fit takes more of them.
  group('attentionSlots', () {
    List<int> slots(double width, List<int> counts) =>
        attentionSlots(width: width, counts: counts);

    test('how many columns a width has room for', () {
      expect(attentionMaxSlots(0), 0);
      expect(attentionMaxSlots(299), 0);
      expect(attentionMaxSlots(599), 1);
      expect(attentionMaxSlots(600), 2);
      expect(attentionMaxSlots(899), 2);
      expect(attentionMaxSlots(900), 3);
      // Never more than three, however wide: a fourth would only stretch rows.
      expect(attentionMaxSlots(2400), 3);
      expect(attentionMaxSlots(double.infinity), 0);
    });

    test('three lists take a column each', () {
      expect(slots(1160, [4, 2, 6]), [1, 1, 1]);
      expect(slots(900, [1, 1, 1]), [1, 1, 1]);
    });

    test('three lists that do not fit fall back to tabs', () {
      expect(slots(899, [4, 2, 6]), isEmpty);
      expect(slots(700, [4, 2, 6]), isEmpty);
    });

    test('one list takes the columns it has rows for', () {
      expect(slots(1160, [9]), [3]);
      expect(slots(1160, [6]), [3]);
      expect(slots(1160, [3]), [3]);
      expect(slots(1160, [2]), [2]);
      // One row cannot use a second column — and is not stretched over three.
      expect(slots(1160, [1]), [1]);
      expect(slots(700, [8]), [2]);
    });

    test('with two lists the spare column goes to the taller one', () {
      expect(slots(1160, [4, 6]), [1, 2]);
      expect(slots(1160, [12, 2]), [2, 1]);
      expect(slots(1160, [2, 3]), [1, 2]);
      // A tie goes to the more urgent list, which comes first.
      expect(slots(1160, [5, 5]), [2, 1]);
      // Neither can use it: it stays empty rather than widening both.
      expect(slots(1160, [1, 1]), [1, 1]);
      expect(slots(700, [4, 6]), [1, 1]);
    });

    test('room for fewer than two columns is always tabs', () {
      expect(slots(599, [8]), isEmpty);
      expect(slots(599, [1, 1]), isEmpty);
      expect(slots(0, [3]), isEmpty);
    });

    test('no lists, no columns', () {
      expect(slots(1160, const []), isEmpty);
    });

    test('never hands out more columns than there are', () {
      for (final width in const [600.0, 760.0, 900.0, 1160.0, 1600.0]) {
        final max = attentionMaxSlots(width);
        for (var a = 1; a <= 12; a++) {
          for (var b = 0; b <= 12; b++) {
            final counts = [a, if (b > 0) b];
            final got = slots(width, counts);
            if (got.isEmpty) continue;
            expect(got.length, counts.length);
            expect(got.reduce((x, y) => x + y), lessThanOrEqualTo(max));
            for (var i = 0; i < got.length; i++) {
              expect(got[i], greaterThanOrEqualTo(1));
              // A list is never given a column it has no row for.
              expect(got[i], lessThanOrEqualTo(counts[i]));
            }
          }
        }
      }
    });
  });

  group('attentionFlow', () {
    test('fills column by column, balanced', () {
      expect(attentionFlow(6, 3), [2, 2, 2]);
      expect(attentionFlow(8, 3), [3, 3, 2]);
      expect(attentionFlow(7, 3), [3, 2, 2]);
      expect(attentionFlow(3, 2), [2, 1]);
      expect(attentionFlow(3, 3), [1, 1, 1]);
      expect(attentionFlow(5, 1), [5]);
    });

    test('never uses more columns than there are rows', () {
      expect(attentionFlow(2, 3), [1, 1]);
      expect(attentionFlow(1, 3), [1]);
      expect(attentionFlow(0, 3), isEmpty);
    });

    test('places every row exactly once', () {
      for (var rows = 1; rows <= 20; rows++) {
        for (var columns = 1; columns <= 3; columns++) {
          final flow = attentionFlow(rows, columns);
          expect(flow.reduce((a, b) => a + b), rows);
          final sorted = [...flow]..sort();
          expect(sorted.last - sorted.first, lessThanOrEqualTo(1));
          // Never shorter on the left than on the right.
          for (var i = 1; i < flow.length; i++) {
            expect(flow[i], lessThanOrEqualTo(flow[i - 1]));
          }
        }
      }
    });
  });
}
