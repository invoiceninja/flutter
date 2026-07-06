import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';

void main() {
  group('DashboardActivity.fromJson', () {
    test('reactv2 shape: captures labels + ids from nested objects', () {
      // The shape returned by `GET /api/v1/activities?reactv2`
      // (`Activity::activity_string()`): nested `{label, hashed_id}` objects
      // keyed by token, no flat `<token>_id` keys.
      final a = DashboardActivity.fromJson(<String, dynamic>{
        'activity_type_id': 4,
        'id': '90',
        'created_at': 1783310471,
        'notes': '',
        'ip': '127.0.0.1',
        'user': {'label': 'Madelyn Pfannerstill', 'hashed_id': 'VolejRejNm'},
        'invoice': {'label': '0025', 'hashed_id': 'z3YaOpbxql'},
        'client': {'label': 'Shanahan PLC', 'hashed_id': 'l4zbq2dprO'},
      });

      expect(a.activityTypeId, 4);
      // Labels resolved for rendering.
      expect(a.labels['user'], 'Madelyn Pfannerstill');
      expect(a.labels['invoice'], '0025');
      expect(a.labels['client'], 'Shanahan PLC');
      // Ids come from the nested hashed_id — this is what restores navigation.
      expect(a.userId, 'VolejRejNm');
      expect(a.invoiceId, 'z3YaOpbxql');
      expect(a.clientId, 'l4zbq2dprO');
      // Tokens absent from this row stay null.
      expect(a.quoteId, isNull);
      expect(a.paymentId, isNull);
    });

    test('reactv2 contact row: contact label + quote id resolved', () {
      final a = DashboardActivity.fromJson(<String, dynamic>{
        'activity_type_id': 21,
        'id': '91',
        'created_at': 1783323181,
        'contact': {
          'label': 'Lance Pagac',
          'hashed_id': 'ContactAAA',
          'contact_entity': 'clients',
        },
        'quote': {'label': '0023', 'hashed_id': '7N1aMAaWmp'},
        'client': {'label': 'Cruickshank Group', 'hashed_id': 'ClientBBBB'},
      });

      expect(a.labels['contact'], 'Lance Pagac');
      expect(a.labels['quote'], '0023');
      expect(a.quoteId, '7N1aMAaWmp');
      expect(a.contactId, 'ContactAAA');
      expect(a.clientId, 'ClientBBBB');
    });

    test('amount token (empty hashed_id) still contributes a label', () {
      final a = DashboardActivity.fromJson(<String, dynamic>{
        'activity_type_id': 10,
        'id': '5',
        'created_at': 1783310471,
        'payment': {'label': '0007', 'hashed_id': 'PpAyMeNt00'},
        'payment_amount': {'label': r'$100.00', 'hashed_id': ''},
        'invoice': {'label': '0025', 'hashed_id': 'z3YaOpbxql'},
        'client': {'label': 'Shanahan PLC', 'hashed_id': 'l4zbq2dprO'},
      });

      // Amount tokens have no hashed_id but do carry a label.
      expect(a.labels['payment_amount'], r'$100.00');
      expect(a.labels['payment'], '0007');
      expect(a.paymentId, 'PpAyMeNt00');
    });

    test('ActivityTransformer shape: flat ids parsed, no labels', () {
      // The shape returned by `GET /api/v1/activities?user_id=` (the
      // user-activity feed): flat hashed `<token>_id` keys, no label objects.
      final a = DashboardActivity.fromJson(<String, dynamic>{
        'activity_type_id': '4',
        'id': '90',
        'created_at': 1783310471,
        'user_id': 'VolejRejNm',
        'client_id': 'l4zbq2dprO',
        'invoice_id': 'z3YaOpbxql',
        'quote_id': '',
        'notes': '',
      });

      expect(a.activityTypeId, 4);
      // No nested objects → no labels; the formatter falls back to nouns.
      expect(a.labels, isEmpty);
      // Flat ids still parse, so navigation is preserved for this feed.
      expect(a.userId, 'VolejRejNm');
      expect(a.clientId, 'l4zbq2dprO');
      expect(a.invoiceId, 'z3YaOpbxql');
      // An empty flat id resolves to null.
      expect(a.quoteId, isNull);
    });
  });
}
