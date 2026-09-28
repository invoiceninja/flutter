import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/transaction_rule.dart';
import 'package:admin/ui/features/transaction_rules/widgets/rule_criterion_editor_sheet.dart';

void main() {
  // A DEBIT `is_empty` criterion saves `value: ''`. The server used to 422 it
  // (`rules.*.value` required + ConvertEmptyStringsToNull), so the operator was
  // withheld for DEBIT (review U2); since fd8cd8ad6c the rule is
  // `required_unless:rules.*.operator,is_empty` and it is offered again.
  group('ruleOperatorsFor', () {
    test('DEBIT string criteria offer is_empty', () {
      final ops = ruleOperatorsFor(kRuleSearchKeyDescription);
      expect(ops, contains(kRuleOperatorIsEmpty));
      expect(ops, contains(kRuleOperatorContains));
    });

    test('CREDIT string criteria offer is_empty', () {
      expect(
        ruleOperatorsFor(r'$invoice.number'),
        contains(kRuleOperatorIsEmpty),
      );
    });

    test('numeric criteria never offer is_empty', () {
      // The server's matchNumberOperator only handles =,<,<=,>,>=.
      expect(
        ruleOperatorsFor(kRuleSearchKeyAmount),
        isNot(contains(kRuleOperatorIsEmpty)),
      );
      expect(
        ruleOperatorsFor(r'$invoice.amount'),
        allOf(
          isNot(contains(kRuleOperatorIsEmpty)),
          contains(kRuleOperatorGreaterThan),
        ),
      );
    });
  });
}
