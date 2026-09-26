// Server row errors are keyed by the row's index in the FULL line-item list
// (`line_items.3.cost`), but each per-type editor renders only its subset.
// The wrapper used to pass no row errors at all — so on an invoice, quote,
// credit or recurring invoice a 422 on one line highlighted nothing.

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/ui/features/billing_shared/items/billing_doc_items_tabs.dart';

LineItem _p(String key) => emptyLineItem().copyWith(productKey: key);
LineItem _t(String id) => emptyLineItem().copyWith(taskId: id);

bool _isTask(LineItem li) => (li.taskId ?? '').isNotEmpty;
bool _isProduct(LineItem li) => !_isTask(li);

void main() {
  // [P0, T1, P2, T3, P4]
  final items = [_p('a'), _t('t1'), _p('b'), _t('t2'), _p('c')];

  test('re-keys each error to the row\'s index in its subset', () {
    final errors = {
      2: {'cost': 'bad cost'},
      3: {'quantity': 'bad qty'},
    };
    expect(
      subsetRowErrors(
        lineItems: items,
        rowErrors: errors,
        inSubset: _isProduct,
      ),
      {
        1: {'cost': 'bad cost'},
      },
    );
    expect(
      subsetRowErrors(lineItems: items, rowErrors: errors, inSubset: _isTask),
      {
        1: {'quantity': 'bad qty'},
      },
    );
  });

  test('the whole list is the identity', () {
    final errors = {
      0: {'notes': 'x'},
      4: {'cost': 'y'},
    };
    expect(
      subsetRowErrors(
        lineItems: items,
        rowErrors: errors,
        inSubset: (_) => true,
      ),
      errors,
    );
  });

  test('nothing in, nothing out', () {
    expect(
      subsetRowErrors(lineItems: items, rowErrors: null, inSubset: _isTask),
      isEmpty,
    );
    expect(
      subsetRowErrors(
        lineItems: items,
        rowErrors: {
          0: {'cost': 'x'},
        },
        inSubset: _isTask,
      ),
      isEmpty,
    );
  });
}
