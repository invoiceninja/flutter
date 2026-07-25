import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/bank_transaction_api_model.dart';
import 'package:admin/data/models/domain/bank_transaction.dart';

void main() {
  group('BankTransaction tags wire round-trip', () {
    test('parses server [{id,name,color}] objects into tagIds', () {
      final api = BankTransactionApi.fromJson({
        'id': 'bt1',
        'tags': [
          {'id': 't1', 'name': 'Payroll', 'color': '#ff0000'},
          {'id': 't2', 'name': 'Reconciled', 'color': null},
        ],
      });
      expect(BankTransaction.fromApi(api).tagIds, ['t1', 't2']);
    });

    test('parses bare ["id"] strings (the payload round-trip form)', () {
      final api = BankTransactionApi.fromJson({
        'id': 'bt1',
        'tags': ['t1', 't2'],
      });
      expect(BankTransaction.fromApi(api).tagIds, ['t1', 't2']);
    });

    // Unlike the other entities, `toApiJson` here serializes via the API
    // model's `toJson()` and then overwrites `json['tags']` with the bare id
    // list — verify that override wins over the nested TagRefApi objects.
    test('toApiJson emits tags as the bare id list, not nested objects', () {
      final api = BankTransactionApi.fromJson({
        'id': 'bt1',
        'tags': [
          {'id': 't1', 'name': 'Payroll', 'color': '#ff0000'},
          {'id': 't2', 'name': 'Reconciled'},
        ],
      });
      expect(BankTransaction.fromApi(api).toApiJson()['tags'], ['t1', 't2']);
    });

    test('empty tags round-trips to an empty list', () {
      final api = BankTransactionApi.fromJson({'id': 'bt1'});
      final t = BankTransaction.fromApi(api);
      expect(t.tagIds, isEmpty);
      expect(t.toApiJson()['tags'], isEmpty);
    });
  });
}
