import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_settings.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_column_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// The tax column count was hard-coded to 1 in all five billing edit layouts,
/// so Tax Name 1 / Tax Rate 1 sat on every line item even for a company that
/// had line-item taxes switched off (invoiceninja/flutter#85). `forCompany` is
/// the narrowing `LineItemEditor` applies to the host's declared config.
void main() {
  const host = LineItemColumnConfig(showDiscount: true, taxColumnCount: 1);

  Company company({
    int taxRates = 0,
    bool discount = true,
    Map<String, dynamic>? translations,
  }) => Company(
    id: 'co',
    enabledItemTaxRates: taxRates,
    enableProductDiscount: discount,
    settings: CompanySettings(translations: translations),
  );

  group('tax columns', () {
    test('taxes off → no tax columns, whatever the host asked for', () {
      expect(host.forCompany(company()).taxColumnCount, 0);
    });

    test('follows the company through 1..3', () {
      for (var n = 1; n <= 3; n++) {
        expect(
          host.forCompany(company(taxRates: n)).taxColumnCount,
          n,
          reason: 'enabled_item_tax_rates=$n',
        );
      }
    });

    test('an out-of-range value is clamped, never passed through', () {
      // The editor renders three tax slots; a 4 would be a silent no-op at
      // best. Old servers have been seen returning odd values here.
      expect(host.forCompany(company(taxRates: 9)).taxColumnCount, 3);
      expect(host.forCompany(company(taxRates: -1)).taxColumnCount, 0);
    });
  });

  group('discount column', () {
    test('the company can take it away', () {
      expect(host.forCompany(company(discount: false)).showDiscount, isFalse);
    });

    test('but cannot grant what the host never offered', () {
      const noDiscount = LineItemColumnConfig(showDiscount: false);
      expect(noDiscount.forCompany(company()).showDiscount, isFalse);
    });
  });

  group('custom labels', () {
    // The app stored `settings.translations` (Settings → Localization →
    // Custom Labels) and never read it back, so a company that had renamed a
    // column saw the rename on its PDFs, in React and in the v1 app but not
    // here (invoiceninja/flutter#84). `forCompany` is where it lands.
    test('an override reaches the config', () {
      final config = host.forCompany(
        company(translations: const {'unit_cost': 'Unit Price'}),
      );
      expect(config.labels['unit_cost'], 'Unit Price');
    });

    test('a key the company has not overridden stays null', () {
      final config = host.forCompany(
        company(translations: const {'unit_cost': 'Unit Price'}),
      );
      expect(config.labels['item'], isNull);
    });

    test('blank and whitespace-only overrides are dropped', () {
      // The Custom Labels editor seeds a newly added row with '' and the
      // server coerces nulls to '' — neither may blank a column header.
      final config = host.forCompany(
        company(translations: const {'unit_cost': '', 'item': '   '}),
      );
      expect(config.labels['unit_cost'], isNull);
      expect(config.labels['item'], isNull);
    });

    test('a non-string value is dropped rather than stringified', () {
      // The field is Map<String, dynamic>: some accounts store a nested
      // object under a lang key, which would render as `{a: b}` on a header.
      final config = host.forCompany(
        company(
          translations: const {
            'unit_cost': {'a': 'b'},
          },
        ),
      );
      expect(config.labels['unit_cost'], isNull);
    });

    test('a company with no translations narrows to no overrides', () {
      expect(host.forCompany(company()).labels['unit_cost'], isNull);
    });
  });

  test('an unloaded company keeps the host config verbatim', () {
    // Null is the frames before the company row arrives. Narrowing to 0 there
    // would show the table, then reflow it a beat later.
    expect(host.forCompany(null), same(host));
  });
}
