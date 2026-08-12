import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/email/email_preview_binding.dart';

void main() {
  group('emailPreviewBinding', () {
    // The exact strings `TemplateEngine::setEntity()` resolves via
    // `ucfirst(Str::camel($entity))`. `purchase_order` must stay underscored:
    // `setSettingsObject()` matches on it to pick company (not client)
    // settings for a PO.
    const wireNames = <BillingDocType, String>{
      BillingDocType.invoice: 'invoice',
      BillingDocType.quote: 'quote',
      BillingDocType.credit: 'credit',
      BillingDocType.purchaseOrder: 'purchase_order',
      BillingDocType.recurringInvoice: 'recurring_invoice',
    };

    for (final entry in wireNames.entries) {
      test('${entry.key.name} binds to its own document as '
          '"${entry.value}"', () {
        expect(
          emailPreviewBinding(
            type: entry.key,
            entityId: 'z3YaOpbxql',
            hasInvitations: true,
          ),
          (entity: entry.value, entityId: 'z3YaOpbxql'),
        );
      });
    }

    test('a doc with no invitations stays on the generic sample', () {
      // Binding one is an HTTP 500, not a soft fallback — the server does
      // `new HtmlEngine($entity->invitations->first())` unguarded.
      expect(
        emailPreviewBinding(
          type: BillingDocType.recurringInvoice,
          entityId: 'z3YaOpbxql',
          hasInvitations: false,
        ),
        (entity: '', entityId: ''),
      );
    });

    test('an unsaved tmp_ id stays on the generic sample', () {
      expect(
        emailPreviewBinding(
          type: BillingDocType.invoice,
          entityId: 'tmp_9f2c',
          hasInvitations: true,
        ),
        (entity: '', entityId: ''),
      );
    });

    test('an empty id stays on the generic sample', () {
      expect(
        emailPreviewBinding(
          type: BillingDocType.invoice,
          entityId: '',
          hasInvitations: true,
        ),
        (entity: '', entityId: ''),
      );
    });
  });
}
