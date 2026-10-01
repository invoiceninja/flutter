import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/quickbooks/quickbooks_invoice.dart';

/// React's `getQuickbooksInvoiceActions` (invoiceninja/ui#3284), rule for rule.
void main() {
  Map<String, dynamic> qb(String direction) => {
    'settings': {
      'invoice': {'direction': direction},
    },
  };

  List<String> actions(Map<String, dynamic>? sync, Map<String, dynamic>? q) =>
      quickbooksInvoiceActions(
        QuickbooksInvoiceSync.fromJson(sync),
        q,
      ).map((a) => a.wire).toList();

  test('nothing at all without a connection', () {
    expect(quickbooksConnected(null), isFalse);
    expect(quickbooksConnected(const {}), isFalse);
    expect(actions(const {'qb_status': 'linkable'}, null), isEmpty);
    expect(actions(const {'qb_status': 'linkable'}, const {}), isEmpty);
  });

  test('Check Record is always offered', () {
    expect(actions(null, qb('none')), ['check_record']);
  });

  test('unlinked + linkable → Force Link', () {
    expect(actions(const {'qb_status': 'linkable'}, qb('none')), [
      'check_record',
      'force_link',
    ]);
  });

  test('linked → Force Pull only when invoices pull', () {
    const linked = {'qb_id': '42', 'qb_status': 'synced'};
    expect(actions(linked, qb('pull')), ['check_record', 'force_pull']);
    expect(actions(linked, qb('bidirectional')), [
      'check_record',
      'force_pull',
    ]);
    expect(actions(linked, qb('push')), ['check_record']);
  });

  test('Force Push needs a failure message and a push direction', () {
    const failed = {'qb_status': 'syncable', 'qb_status_message': 'Boom'};
    expect(actions(failed, qb('push')), ['check_record', 'force_push']);
    expect(actions(failed, qb('pull')), ['check_record']);
    expect(actions(const {'qb_status': 'syncable'}, qb('push')), [
      'check_record',
    ]);
    expect(
      actions(const {
        'qb_id': '7',
        'qb_status': 'synced',
        'qb_status_message': 'Boom',
      }, qb('bidirectional')),
      ['check_record', 'force_pull', 'force_push'],
    );
  });

  test('a check report parses the server shape (CheckInvoice)', () {
    final check = QuickbooksInvoiceCheck.fromJson({
      'outcome': 'data_mismatch',
      'linked': false,
      'message': ' Totals differ ',
      'checked_at': '2026-10-01T12:00:00+00:00',
      'quickbooks': {'id': '99', 'number': 'INV-1', 'total': 110.5},
      'comparison': {
        'number': {
          'matches': true,
          'invoice_ninja': 'INV-1',
          'quickbooks': 'INV-1',
        },
        'total': {'matches': false, 'invoice_ninja': 100, 'quickbooks': 110.5},
      },
      'recommended_actions': ['change_invoice_number', 'force_link'],
    });
    expect(check.outcome, 'data_mismatch');
    expect(check.message, 'Totals differ');
    expect(check.quickbooksId, '99');
    expect(check.number!.matches, isTrue);
    expect(check.total!.matches, isFalse);
    expect(check.total!.quickbooks, '110.5');
    expect(check.recommendedActions, ['change_invoice_number', 'force_link']);
    expect(
      QuickbooksInvoiceAction.fromWire(check.recommendedActions.last),
      QuickbooksInvoiceAction.forceLink,
    );
  });

  test('a report with no QuickBooks record has no comparison', () {
    final check = QuickbooksInvoiceCheck.fromJson({
      'outcome': 'syncable',
      'linked': false,
      'message': '',
      'quickbooks': null,
      'comparison': null,
      'recommended_actions': <String>[],
    });
    expect(check.quickbooksId, '');
    expect(check.number, isNull);
    expect(check.total, isNull);
  });
}
