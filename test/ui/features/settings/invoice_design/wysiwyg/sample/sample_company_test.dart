import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/sample/sample_data.dart';

/// The page shows the company's own letterhead where it has one.
void main() {
  final base = DesignerSampleData.fallback;

  test('what the company has set replaces the made-up value', () {
    final data = base.withCompany(
      name: 'Hartley & Daughters',
      logo: 'https://example.test/logo.png',
      phone: '020 7946 0000',
    );
    expect(data.company.name, 'Hartley & Daughters');
    expect(data.company.logo, 'https://example.test/logo.png');
    expect(data.company.phone, '020 7946 0000');
    // The client and the invoice are still the sample.
    expect(data.client.name, base.client.name);
    expect(data.invoice.number, base.invoice.number);
  });

  test('what it has not set keeps the sample value', () {
    final data = base.withCompany(name: '  ', email: null);
    expect(data.company.name, base.company.name);
    expect(data.company.email, base.company.email);
    expect(data.company.address1, base.company.address1);
  });

  test(
    'an address is taken whole, never half the company\'s and half ours',
    () {
      final data = base.withCompany(
        address1: '1 Mill Lane',
        city: 'Leeds',
        postalCode: 'LS1 4AP',
      );
      expect(data.company.address1, '1 Mill Lane');
      expect(
        data.company.address2,
        isEmpty,
        reason: 'not the sample\'s "Floor 12"',
      );
      expect(data.company.cityStatePostal, 'Leeds LS1 4AP');
      expect(data.company.postalCityState, 'LS1 4AP Leeds');
    },
  );
}
