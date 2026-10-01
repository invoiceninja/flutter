import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/billing_shared/billing_cross_clone.dart';
import 'package:admin/ui/features/billing_shared/edit/credit_billing_reference_field.dart';

/// Invoice → credit on PEPPOL fills the credit note's billing reference
/// (invoiceninja/ui#3290) — at exactly the path the credit edit screen's
/// field reads, or the field would show empty and the next save drop it.
void main() {
  Object? at(Object? node, List<Object> path) {
    var cur = node;
    for (final key in path) {
      if (key is int) {
        cur = (cur as List)[key];
      } else {
        cur = (cur as Map)[key];
      }
    }
    return cur;
  }

  test('lands on the paths CreditBillingReferenceField edits', () {
    final block = peppolCreditBillingReference(
      invoiceNumber: 'INV-0012',
      issueDate: '2026-09-01',
    );
    expect(at(block, CreditBillingReferenceField.idPath), 'INV-0012');
    expect(at(block, CreditBillingReferenceField.issueDatePath), '2026-09-01');
  });
}
