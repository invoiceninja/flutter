import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_column_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// The tax column count was hard-coded to 1 in all five billing edit layouts,
/// so Tax Name 1 / Tax Rate 1 sat on every line item even for a company that
/// had line-item taxes switched off (invoiceninja/flutter#85).
void main() {
  group('LineItemColumnConfig.forCompany', () {
    test('taxes off → no tax columns', () {
      expect(
        LineItemColumnConfig.forCompany(enabledItemTaxRates: 0).taxColumnCount,
        0,
      );
    });

    test('follows the company through 1..3', () {
      for (var n = 1; n <= 3; n++) {
        expect(
          LineItemColumnConfig.forCompany(
            enabledItemTaxRates: n,
          ).taxColumnCount,
          n,
          reason: 'enabled_item_tax_rates=$n',
        );
      }
    });

    test('an unloaded company shows nothing rather than guessing', () {
      // Null is the frames before the company row arrives. Guessing 1 there is
      // how the old hard-coded default became invisible in the first place.
      expect(
        LineItemColumnConfig.forCompany(
          enabledItemTaxRates: null,
        ).taxColumnCount,
        0,
      );
    });

    test('an out-of-range value is clamped, never passed through', () {
      // The editor indexes three tax slots; a 4 would be a silent no-op at
      // best. Old servers have been seen returning odd values here.
      expect(
        LineItemColumnConfig.forCompany(enabledItemTaxRates: 9).taxColumnCount,
        3,
      );
      expect(
        LineItemColumnConfig.forCompany(enabledItemTaxRates: -1).taxColumnCount,
        0,
      );
    });

    test('discount stays on by default — only taxes moved', () {
      expect(
        LineItemColumnConfig.forCompany(enabledItemTaxRates: 0).showDiscount,
        isTrue,
      );
    });
  });
}
