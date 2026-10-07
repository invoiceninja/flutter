import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/clients/client_past_due.dart';

/// The past-due line is the one figure on the client screen that the server
/// does not supply, so every way it could be wrong has a case here. The rule
/// under test: **say nothing unless it is proven.**
///
/// No clock is read anywhere — `today` is passed in — so this file has no
/// timezone dependence to guard against.

const _today = Date(2026, 6, 15);

Client _client(String balance, {bool dirty = false, String id = 'c1'}) =>
    Client.fromApi(
      ClientApi(id: id, name: 'Acme', balance: balance, updatedAt: 1),
    ).copyWith(isDirty: dirty);

Invoice _invoice(
  String id,
  String balance, {
  String due = '2026-06-01',
  String partialDue = '',
  String partial = '0',
  String status = '2',
  int archivedAt = 0,
  bool dirty = false,
}) => Invoice.fromApi(
  InvoiceApi(
    id: id,
    clientId: 'c1',
    statusId: status,
    amount: balance,
    balance: balance,
    dueDate: due,
    partial: partial,
    partialDueDate: partialDue,
    archivedAt: archivedAt,
    updatedAt: 1,
  ),
).copyWith(isDirty: dirty);

ClientPastDue? _run(
  String balance,
  List<Invoice> unpaid, {
  bool complete = true,
  bool clientDirty = false,
  String clientId = 'c1',
  Date today = _today,
}) => clientPastDue(
  client: _client(balance, dirty: clientDirty, id: clientId),
  unpaid: unpaid,
  fetchComplete: complete,
  today: today,
);

void main() {
  group('proven', () {
    test('the late part of the balance, and how many invoices it is', () {
      final r = _run('1740', [
        _invoice('a', '1000'), // due June 1 — late
        _invoice('b', '240', due: '2026-05-20'), // late
        _invoice('c', '500', due: '2026-07-01'), // not yet due
      ]);
      expect(r, isNotNull);
      expect(r!.amount, Decimal.parse('1240'));
      expect(r.count, 2);
    });

    test('nothing late is a zero, not an unknown', () {
      final r = _run('500', [_invoice('c', '500', due: '2026-07-01')]);
      expect(r, (amount: Decimal.zero, count: 0));
    });

    test('an invoice with no due date is owed but never late', () {
      final r = _run('500', [_invoice('c', '500', due: '')]);
      expect(r, (amount: Decimal.zero, count: 0));
    });

    test('an archived invoice still counts — the server sums it', () {
      final r = _run('1000', [_invoice('a', '1000', archivedAt: 1700000000)]);
      expect(r!.amount, Decimal.parse('1000'));
      expect(r.count, 1);
    });

    test('a partial invoice is late by its partial due date', () {
      final r = _run('800', [
        _invoice(
          'a',
          '800',
          status: '3',
          due: '2026-07-30',
          partialDue: '2026-06-10',
        ),
      ]);
      expect(r!.count, 1);
    });
  });

  group('a deposit', () {
    // An invoice can ask for part of its total ahead of its own due date. The
    // invoice is late the day the deposit is — but only the deposit is.
    test('overdue while the invoice is not: only the deposit is late', () {
      // It used to read "Past Due: $10,000.00" for a $1,000 deposit.
      final r = _run('10000', [
        _invoice(
          'a',
          '10000',
          partial: '1000',
          partialDue: '2026-06-10',
          due: '2026-07-30',
        ),
      ]);
      expect(r!.amount, Decimal.parse('1000'));
      expect(r.count, 1, reason: 'still one late invoice');
    });

    test('with no full due date at all: still only the deposit', () {
      final r = _run('10000', [
        _invoice(
          'a',
          '10000',
          partial: '1000',
          partialDue: '2026-06-10',
          due: '',
        ),
      ]);
      expect(r!.amount, Decimal.parse('1000'));
    });

    test('once the invoice itself is overdue, all of it is late', () {
      final r = _run('10000', [
        _invoice(
          'a',
          '10000',
          partial: '1000',
          partialDue: '2026-05-01',
          due: '2026-06-01',
        ),
      ]);
      expect(r!.amount, Decimal.parse('10000'));
    });

    test('never more than is still owed', () {
      // A deposit larger than the remaining balance — most of it was paid.
      final r = _run('300', [
        _invoice(
          'a',
          '300',
          partial: '1000',
          partialDue: '2026-06-10',
          due: '2026-07-30',
        ),
      ]);
      expect(r!.amount, Decimal.parse('300'));
    });

    test('sums with ordinary late invoices', () {
      final r = _run('10500', [
        _invoice(
          'deposit',
          '10000',
          partial: '1000',
          partialDue: '2026-06-10',
          due: '2026-07-30',
        ),
        _invoice('plain', '500', due: '2026-06-01'),
      ]);
      expect(r!.amount, Decimal.parse('1500'));
      expect(r.count, 2);
    });

    test('cents add up exactly', () {
      // Three thirds that a double would sum to 0.30000000000000004.
      final r = _run('0.30', [
        _invoice('a', '0.10'),
        _invoice('b', '0.10'),
        _invoice('c', '0.10'),
      ]);
      expect(r!.amount, Decimal.parse('0.30'));
    });
  });

  group('the day it becomes late', () {
    final dueThe15th = [_invoice('a', '100', due: '2026-06-15')];

    test('not on its due date', () {
      expect(_run('100', dueThe15th, today: const Date(2026, 6, 15))!.count, 0);
    });

    test('the day after', () {
      expect(_run('100', dueThe15th, today: const Date(2026, 6, 16))!.count, 1);
    });
  });

  group('not proven, so nothing is said', () {
    test('the fetch did not come back complete', () {
      // Offline, an error, or more unpaid invoices than one page holds.
      expect(_run('1000', [_invoice('a', '1000')], complete: false), isNull);
    });

    test('an invoice is missing from the cache', () {
      // The balance says 1,500 is owed; only 1,000 of it is on this device.
      expect(_run('1500', [_invoice('a', '1000')]), isNull);
    });

    test('a cached invoice has since been paid', () {
      // A narrowed fetch cannot correct this: a paid invoice is simply absent
      // from "unpaid", so its stale row stays. The sums give it away.
      expect(
        _run('1000', [_invoice('a', '1000'), _invoice('stale', '400')]),
        isNull,
      );
    });

    test('stale and missing that happen to cancel out — before the fetch', () {
      // Equal monthly invoices: March was paid (stale here), April was never
      // cached. The sum matches the balance and March looks late. This is the
      // case the sum check alone gets wrong, and why `fetchComplete` exists.
      final cache = [_invoice('march', '1000', due: '2026-03-31')];
      expect(_run('1000', cache, complete: false), isNull);
    });

    test('…and after it, when April has arrived', () {
      final cache = [
        _invoice('march', '1000', due: '2026-03-31'),
        _invoice('april', '1000', due: '2026-07-31'),
      ];
      expect(_run('1000', cache), isNull, reason: 'the sums now disagree');
    });

    test('an invoice is mid-edit', () {
      expect(_run('1000', [_invoice('a', '1000', dirty: true)]), isNull);
    });

    test('an invoice exists only on this device', () {
      expect(_run('1000', [_invoice('tmp_x', '1000')]), isNull);
    });

    test('the client itself is mid-edit, or not synced', () {
      expect(_run('1000', [_invoice('a', '1000')], clientDirty: true), isNull);
      expect(_run('1000', [_invoice('a', '1000')], clientId: 'tmp_c'), isNull);
    });

    test('nothing cached at all, with a balance owed', () {
      expect(_run('1000', const []), isNull);
    });
  });

  group('Invoice.isPastDueOn', () {
    test('agrees with isPastDue for today', () {
      final late = _invoice('a', '100', due: '2000-01-01');
      final future = _invoice('b', '100', due: '2999-01-01');
      expect(late.isPastDueOn(Date.today()), late.isPastDue);
      expect(future.isPastDueOn(Date.today()), future.isPastDue);
      expect(late.isPastDue, isTrue);
      expect(future.isPastDue, isFalse);
    });

    test('a draft, a paid or a zero-balance invoice is never late', () {
      expect(_invoice('a', '100', status: '1').isPastDueOn(_today), isFalse);
      expect(_invoice('a', '100', status: '4').isPastDueOn(_today), isFalse);
      expect(_invoice('a', '0').isPastDueOn(_today), isFalse);
    });
  });
}
