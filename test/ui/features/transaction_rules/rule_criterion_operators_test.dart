import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/transaction_rule.dart';
import 'package:admin/ui/features/transaction_rules/widgets/rule_criterion_editor_sheet.dart';

void main() {
  // U2: a DEBIT rule using `is_empty` saves `value: ''`, which the server
  // 422-rejects (`rules.*.value` required + ConvertEmptyStringsToNull), parking
  // the save in the outbox forever. The operator is no longer offered for DEBIT
  // criteria. CREDIT keeps it — its value carries a non-empty placeholder the
  // server accepts.
  group('ruleOperatorsFor (U2: is_empty gating)', () {
    test('DEBIT string criteria do NOT offer is_empty', () {
      final ops = ruleOperatorsFor(kRuleSearchKeyDescription, isCredit: false);
      expect(ops, isNot(contains(kRuleOperatorIsEmpty)));
      expect(
        ops,
        contains(kRuleOperatorContains),
        reason: 'the other string operators still apply',
      );
    });

    test(
      'CREDIT string criteria keep is_empty (value carries a placeholder)',
      () {
        final ops = ruleOperatorsFor(r'$invoice.number', isCredit: true);
        expect(ops, contains(kRuleOperatorIsEmpty));
      },
    );

    test('numeric criteria never offer is_empty (either scope)', () {
      expect(
        ruleOperatorsFor(kRuleSearchKeyAmount, isCredit: false),
        isNot(contains(kRuleOperatorIsEmpty)),
      );
      expect(
        ruleOperatorsFor(r'$invoice.amount', isCredit: true),
        allOf(
          isNot(contains(kRuleOperatorIsEmpty)),
          contains(kRuleOperatorGreaterThan),
        ),
      );
    });
  });
}
