import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/settings/views/advanced/e_invoice/e_invoice_constants.dart';

/// Unit coverage for [visibleEInvoiceTypes] — the pure filter behind the
/// E-Invoice type dropdown. Mirrors React's `shouldShowPEPPOLOption` /
/// `shouldShowVERIFACTUOption` gating: PEPPOL needs Enterprise access + a
/// PEPPOL-network country; VERIFACTU needs the build flag + hosted + Spain;
/// an already-selected value always stays so the user can switch away.
void main() {
  // Defaults to the most-restrictive state so each test overrides only the
  // dimension it exercises.
  List<String> visible({
    String? selectedType,
    String? countryId,
    bool hasEnterpriseAccess = false,
    bool isHosted = false,
    bool verifactuFlagEnabled = false,
  }) => visibleEInvoiceTypes(
    selectedType: selectedType,
    countryId: countryId,
    hasEnterpriseAccess: hasEnterpriseAccess,
    isHosted: isHosted,
    verifactuFlagEnabled: verifactuFlagEnabled,
  );

  const germany = '276'; // PEPPOL-network country
  const france = '250'; // PEPPOL-network country (e-invoicing mandate)
  const usa = '840'; // neither PEPPOL nor Spain
  const spain = kEInvoiceCountryIdSpain; // '724' — not a PEPPOL country

  group('PEPPOL gating', () {
    test('shown with Enterprise access in a PEPPOL country', () {
      expect(
        visible(countryId: germany, hasEnterpriseAccess: true),
        contains(kEInvoiceTypePEPPOL),
      );
    });

    test('shown for France with Enterprise access on hosted (regression — '
        'was omitted from kPeppolCountries, blocking French PEPPOL '
        'onboarding)', () {
      expect(
        visible(countryId: france, hasEnterpriseAccess: true, isHosted: true),
        contains(kEInvoiceTypePEPPOL),
      );
    });

    // invoiceninja/ui#3305: a self-hosted French company can't register on
    // the PEPPOL network.
    test('hidden for France on self-hosted', () {
      expect(
        visible(countryId: france, hasEnterpriseAccess: true),
        isNot(contains(kEInvoiceTypePEPPOL)),
      );
      // Still offered when already saved, so the user can switch away.
      expect(
        visible(
          countryId: france,
          hasEnterpriseAccess: true,
          selectedType: kEInvoiceTypePEPPOL,
        ),
        contains(kEInvoiceTypePEPPOL),
      );
    });

    test('hidden without Enterprise access even in a PEPPOL country', () {
      expect(
        visible(countryId: germany, hasEnterpriseAccess: false),
        isNot(contains(kEInvoiceTypePEPPOL)),
      );
    });

    test('hidden in a non-PEPPOL country even with Enterprise access', () {
      expect(
        visible(countryId: usa, hasEnterpriseAccess: true),
        isNot(contains(kEInvoiceTypePEPPOL)),
      );
    });

    test('hidden when country is null', () {
      expect(
        visible(countryId: null, hasEnterpriseAccess: true),
        isNot(contains(kEInvoiceTypePEPPOL)),
      );
    });

    test('already-selected PEPPOL stays visible (switch-away safety)', () {
      // Lapsed plan + wrong country, but PEPPOL is the saved value.
      expect(
        visible(
          selectedType: kEInvoiceTypePEPPOL,
          countryId: usa,
          hasEnterpriseAccess: false,
        ),
        contains(kEInvoiceTypePEPPOL),
      );
    });
  });

  group('VERIFACTU gating', () {
    test('shown only with flag + hosted + Spain', () {
      expect(
        visible(countryId: spain, isHosted: true, verifactuFlagEnabled: true),
        contains(kEInvoiceTypeVERIFACTU),
      );
    });

    test('hidden when the build flag is off', () {
      expect(
        visible(countryId: spain, isHosted: true, verifactuFlagEnabled: false),
        isNot(contains(kEInvoiceTypeVERIFACTU)),
      );
    });

    test('hidden when not hosted', () {
      expect(
        visible(countryId: spain, isHosted: false, verifactuFlagEnabled: true),
        isNot(contains(kEInvoiceTypeVERIFACTU)),
      );
    });

    test('hidden outside Spain', () {
      expect(
        visible(countryId: germany, isHosted: true, verifactuFlagEnabled: true),
        isNot(contains(kEInvoiceTypeVERIFACTU)),
      );
    });

    test('already-selected VERIFACTU stays visible (switch-away safety)', () {
      expect(
        visible(
          selectedType: kEInvoiceTypeVERIFACTU,
          countryId: spain,
          verifactuFlagEnabled: false,
        ),
        contains(kEInvoiceTypeVERIFACTU),
      );
    });
  });

  group('always-on standards', () {
    test('EN16931 + OrderX are always offered regardless of plan/country', () {
      final result = visible(countryId: null);
      expect(result, contains(kEInvoiceTypeEN16931));
      expect(result, contains(kEInvoiceTypeOrderX_Basic));
    });

    test('preserves the canonical order of kEInvoiceTypes', () {
      final result = visible(
        countryId: germany,
        hasEnterpriseAccess: true,
        isHosted: true,
        verifactuFlagEnabled: true,
      );
      var lastIndex = -1;
      for (final type in result) {
        final index = kEInvoiceTypes.indexOf(type);
        expect(
          index,
          greaterThan(lastIndex),
          reason: '$type is out of canonical order',
        );
        lastIndex = index;
      }
    });
  });
}
