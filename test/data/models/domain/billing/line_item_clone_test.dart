import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/billing/line_item_type.dart';

/// Cloning a billing doc used to carry each row's `task_id` / `expense_id`
/// straight over. Re-pointing the clone at a different client — the canonical
/// "same work, new client" use of clone — then dead-ended: the line still
/// claimed a task belonging to the ORIGINAL client, `validateCrossClient`
/// returned a `line_items` error, and `save()` hard-returned with no field the
/// form could fix. Server-generated unpaid-fee rows came along too, re-billing
/// a gateway fee that belonged to the source document.
void main() {
  LineItem taskLine() => emptyLineItem().copyWith(
    productKey: 'SVC',
    notes: 'Boiler service',
    cost: Decimal.fromInt(150),
    quantity: Decimal.fromInt(2),
    taxName1: 'GST',
    taxRate1: Decimal.fromInt(5),
    customValue1: 'keep me',
    typeId: LineItemType.task,
    taskId: 'task-1',
  );

  group('freshClone', () {
    test('drops the source links and demotes the row to standard', () {
      final clone = taskLine().freshClone();
      expect(clone.taskId, isNull);
      expect(clone.expenseId, isNull);
      expect(clone.typeId, LineItemType.standard);
    });

    test('keeps everything the user actually typed', () {
      final clone = taskLine().freshClone();
      expect(clone.productKey, 'SVC');
      expect(clone.notes, 'Boiler service');
      expect(clone.cost, Decimal.fromInt(150));
      expect(clone.quantity, Decimal.fromInt(2));
      expect(clone.taxName1, 'GST');
      expect(clone.taxRate1, Decimal.fromInt(5));
      expect(clone.customValue1, 'keep me');
    });

    test('leaves a plain row s type alone', () {
      final clone = emptyLineItem()
          .copyWith(productKey: 'X', typeId: LineItemType.standard)
          .freshClone();
      expect(clone.typeId, LineItemType.standard);
    });

    test('demotes an expense-derived row too', () {
      final clone = emptyLineItem()
          .copyWith(typeId: LineItemType.expense, expenseId: 'exp-1')
          .freshClone();
      expect(clone.expenseId, isNull);
      expect(clone.typeId, LineItemType.standard);
    });
  });

  group('clonedLineItems', () {
    test('sanitises every row and drops server-generated unpaid fees', () {
      final source = [
        taskLine(),
        emptyLineItem().copyWith(
          productKey: 'Gateway fee',
          cost: Decimal.fromInt(3),
          typeId: LineItemType.unpaidFee,
        ),
        emptyLineItem().copyWith(productKey: 'Widget'),
      ];

      final cloned = clonedLineItems(source);

      expect(cloned, hasLength(2), reason: 'the unpaid-fee row is dropped');
      expect(cloned.map((i) => i.productKey), ['SVC', 'Widget']);
      expect(cloned.every((i) => i.taskId == null), isTrue);
      expect(cloned.every((i) => i.expenseId == null), isTrue);
      expect(cloned.any((i) => i.typeId == LineItemType.unpaidFee), isFalse);
    });

    test('an empty list stays empty', () {
      expect(clonedLineItems(const []), isEmpty);
    });
  });
}
