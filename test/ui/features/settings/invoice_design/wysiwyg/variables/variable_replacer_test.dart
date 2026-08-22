import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/sample/sample_data.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/variables/variable_replacer.dart';

void main() {
  final data = DesignerSampleData.fallback;

  group('save mode (data == null)', () {
    test('leaves all tokens literal — server substitutes them', () {
      const template = r'$client.name lives at $client.address1, $total due';
      expect(replaceVariables(template), template);
    });
  });

  group('company / client / contact substitution', () {
    test(r'substitutes $company.name', () {
      expect(
        replaceVariables(r'$company.name', data: data),
        'Your Company LLC',
      );
    });
    test(r'substitutes $client.address1 + city_state_postal', () {
      expect(
        replaceVariables(
          r'$client.address1, $client.city_state_postal',
          data: data,
        ),
        '123 Business Street, New York, NY 10001',
      );
    });
    test(r'substitutes $contact.full_name', () {
      expect(replaceVariables(r'$contact.full_name', data: data), 'Jane Smith');
    });
    test('substitutes the tag tokens on all three namespaces', () {
      expect(
        replaceVariables(
          r'$client.tags | $company.tags | $invoice.tags',
          data: data,
        ),
        'VIP, Wholesale | Design, Consulting | Priority, Net30',
      );
    });
    test('shipping token is matched before bare client.address1', () {
      expect(
        replaceVariables(
          r'$client.shipping_address1 | $client.address1',
          data: data,
        ),
        '400 Warehouse Way | 123 Business Street',
      );
    });
  });

  group('invoice + entity aliases', () {
    test(r'$invoice.number and $entity.number both resolve', () {
      expect(replaceVariables(r'$invoice.number', data: data), 'INV-0001');
      expect(replaceVariables(r'$entity.number', data: data), 'INV-0001');
    });
    test(r'$number flat alias resolves', () {
      expect(replaceVariables(r'$number', data: data), 'INV-0001');
    });
    test(r'$invoice.custom1 resolves', () {
      expect(
        replaceVariables(r'$invoice.custom1', data: data),
        'Custom Invoice Field 1',
      );
    });
  });

  group('money formatting (en-US fallback)', () {
    test(r'$total formats as $1,650.00', () {
      expect(replaceVariables(r'$total', data: data), r'$1,650.00');
    });
    test(r'$balance_due is matched before $balance', () {
      expect(
        replaceVariables(r'$balance_due / $balance', data: data),
        r'$1,650.00 / $1,650.00',
      );
    });
    test(r'$amount aliases $invoice.total', () {
      expect(replaceVariables(r'$amount', data: data), r'$1,650.00');
    });
    test(r'$invoice.subtotal formats as $1,500.00', () {
      expect(replaceVariables(r'$invoice.subtotal', data: data), r'$1,500.00');
    });
    test(r'zero $partial still formats', () {
      expect(replaceVariables(r'$partial', data: data), r'$0.00');
    });
  });

  group('date formatting (en-US fallback)', () {
    test(r'$date formats as Dec 9, 2025', () {
      expect(replaceVariables(r'$date', data: data), 'Dec 9, 2025');
    });
    test(r'$invoice.due_date formats', () {
      expect(
        replaceVariables(r'$invoice.due_date', data: data),
        'Dec 23, 2025',
      );
    });
  });

  group('resolveItemVariable', () {
    final item = data.lineItems.first;
    test('plain string field — product_key', () {
      expect(
        resolveItemVariable('item.product_key', item, data: data),
        'WEB-DESIGN',
      );
    });
    test('decimal money field — line_total', () {
      expect(
        resolveItemVariable('item.line_total', item, data: data),
        r'$1,000.00',
      );
    });
    test('quantity renders as integer when whole', () {
      expect(resolveItemVariable('item.quantity', item, data: data), '1');
    });
    test('quantity 5 (whole)', () {
      expect(
        resolveItemVariable('item.quantity', data.lineItems[1], data: data),
        '5',
      );
    });
    test('save mode leaves the token literal', () {
      expect(resolveItemVariable('item.product_key', item), 'item.product_key');
    });
    test('unknown item.field → empty string', () {
      expect(resolveItemVariable('item.nonexistent', item, data: data), '');
    });
    test('non-item variable falls through to replaceVariables', () {
      expect(
        resolveItemVariable(r'$company.name', item, data: data),
        'Your Company LLC',
      );
    });
  });

  group('QR code placeholders', () {
    test(r'$payment_qr_code resolves to placeholder', () {
      expect(
        replaceVariables(r'$payment_qr_code', data: data),
        '[Payment QR Code]',
      );
    });
  });

  group('custom values', () {
    test(r'$client.custom1..4 all resolve', () {
      expect(
        replaceVariables(
          r'$client.custom1|$client.custom2|$client.custom3|$client.custom4',
          data: data,
        ),
        'Custom Client Field 1|Custom Client Field 2|Custom Client Field 3|Custom Client Field 4',
      );
    });
  });

  group('robustness', () {
    test('template with no variables is returned unchanged', () {
      expect(replaceVariables('plain text', data: data), 'plain text');
    });
    test('mixed text + variables flows naturally', () {
      const t = r'Invoice $number issued to $client.name for $amount';
      expect(
        replaceVariables(t, data: data),
        r'Invoice INV-0001 issued to Acme Corporation for $1,650.00',
      );
    });
    test('decimal precision is preserved in sample data', () {
      expect(data.invoice.subtotal, Decimal.parse('1500.00'));
      expect(data.lineItems[1].quantity, Decimal.parse('5'));
    });
  });

  group('replaceLabelVariables (Phase 8i)', () {
    String upper(String key) => key.toUpperCase();

    test('translates a single token', () {
      expect(replaceLabelVariables(r'$subtotal_label', upper), 'SUBTOTAL');
    });

    test('translates ten representative tokens', () {
      // (token, expected localization key)
      const samples = <List<String>>[
        [r'$number_label', 'invoice_number'],
        [r'$date_label', 'invoice_date'],
        [r'$due_date_label', 'due_date'],
        [r'$subtotal_label', 'subtotal'],
        [r'$total_label', 'total'],
        [r'$balance_due_label', 'balance_due'],
        [r'$client.email_label', 'email'],
        [r'$client.address1_label', 'address1'],
        [r'$company.name_label', 'company_name'],
        [r'$product.unit_cost_label', 'unit_cost'],
      ];
      for (final s in samples) {
        expect(
          replaceLabelVariables(s[0], upper),
          s[1].toUpperCase(),
          reason: 'token ${s[0]}',
        );
      }
    });

    test('unknown tokens stay literal', () {
      expect(
        replaceLabelVariables(r'$totally_made_up_label', upper),
        r'$totally_made_up_label',
      );
    });

    test('non-label text passes through unchanged', () {
      expect(replaceLabelVariables('Invoice', upper), 'Invoice');
      expect(replaceLabelVariables('', upper), '');
      expect(
        replaceLabelVariables(r'$client.name', upper),
        r'$client.name',
        reason: 'data tokens are not label tokens — no _label suffix',
      );
    });

    test('mixed labels in one string each translate independently', () {
      expect(
        replaceLabelVariables(
          r'$subtotal_label: 1.00 / $total_label: 2.00',
          upper,
        ),
        'SUBTOTAL: 1.00 / TOTAL: 2.00',
      );
    });

    test(
      'kLabelTranslationMap covers core entity + client + company + product',
      () {
        expect(kLabelTranslationMap.length, greaterThan(80));
        expect(kLabelTranslationMap[r'$subtotal_label'], 'subtotal');
        expect(kLabelTranslationMap[r'$client.address1_label'], 'address1');
        expect(kLabelTranslationMap[r'$company.phone_label'], 'phone');
        expect(kLabelTranslationMap[r'$task.hours_label'], 'hours');
      },
    );
  });
}
