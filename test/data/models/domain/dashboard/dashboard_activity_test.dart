import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/ui/features/activity/activity_deep_link.dart';

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

    test('task/credit/vendor/purchase_order/recurring_expense/subscription '
        'ids parse from BOTH shapes (these were unparsed → dead activity '
        'taps)', () {
      // reactv2 nested objects (Activity::matchVar).
      final nested = DashboardActivity.fromJson(<String, dynamic>{
        'activity_type_id': 42,
        'id': '1',
        'created_at': 1,
        'task': {'label': '0023', 'hashed_id': 'task_h'},
        'credit': {'label': '77', 'hashed_id': 'credit_h'},
        'vendor': {'label': 'Acme Supply', 'hashed_id': 'vendor_h'},
        'purchase_order': {'label': 'PO-1', 'hashed_id': 'po_h'},
        'recurring_expense': {'label': 'Rent', 'hashed_id': 're_h'},
        'subscription': {'label': 'Gold', 'hashed_id': 'sub_h'},
      });
      expect(nested.taskId, 'task_h');
      expect(nested.creditId, 'credit_h');
      expect(nested.vendorId, 'vendor_h');
      expect(nested.purchaseOrderId, 'po_h');
      expect(nested.recurringExpenseId, 're_h');
      expect(nested.subscriptionId, 'sub_h');

      // ActivityTransformer flat ids.
      final flat = DashboardActivity.fromJson(<String, dynamic>{
        'activity_type_id': '42',
        'id': '2',
        'created_at': 1,
        'task_id': 'task_f',
        'credit_id': 'credit_f',
        'vendor_id': 'vendor_f',
        'purchase_order_id': 'po_f',
        'recurring_expense_id': 're_f',
      });
      expect(flat.taskId, 'task_f');
      expect(flat.creditId, 'credit_f');
      expect(flat.vendorId, 'vendor_f');
      expect(flat.purchaseOrderId, 'po_f');
      expect(flat.recurringExpenseId, 're_f');
    });
  });

  group('activityDeepLinkTarget', () {
    DashboardActivity activity(Map<String, dynamic> extra) =>
        DashboardActivity.fromJson(<String, dynamic>{
          'activity_type_id': 1,
          'id': 'a1',
          'created_at': 1,
          ...extra,
        });

    test('document refs precede the party fallbacks', () {
      expect(
        activityDeepLinkTarget(activity({'task_id': 't1', 'client_id': 'c1'})),
        '/tasks/t1',
      );
      expect(
        activityDeepLinkTarget(
          activity({'purchase_order_id': 'p1', 'vendor_id': 'v1'}),
        ),
        '/purchase_orders/p1',
      );
    });

    test('every new ref type maps to a real registered route', () {
      expect(
        activityDeepLinkTarget(activity({'credit_id': 'x'})),
        '/credits/x',
      );
      expect(
        activityDeepLinkTarget(activity({'recurring_expense_id': 'x'})),
        '/recurring_expenses/x',
      );
      expect(
        activityDeepLinkTarget(activity({'vendor_id': 'x'})),
        '/vendors/x',
      );
      expect(
        activityDeepLinkTarget(activity({'subscription_id': 'x'})),
        '/settings/payment_links/x',
      );
    });

    test('a system-only activity with no refs yields null', () {
      expect(activityDeepLinkTarget(activity(const {})), isNull);
    });
  });
}
