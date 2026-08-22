import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/static/pdf_catalogs.dart';

void main() {
  group('kPdfVariableSections', () {
    test('every section keyed under [PdfVariableSection] is present in '
        '[kPdfVariableSectionOrder] in display order', () {
      final keys = kPdfVariableSections.keys.toSet();
      final order = kPdfVariableSectionOrder.toSet();
      expect(
        keys,
        order,
        reason:
            'kPdfVariableSections and kPdfVariableSectionOrder must '
            'enumerate the same section keys',
      );
    });

    test('every section\'s defaultSelected is a subset of available', () {
      for (final entry in kPdfVariableSections.entries) {
        final cat = entry.value;
        final missing = cat.defaultSelected
            .where((v) => !cat.available.contains(v))
            .toList();
        expect(
          missing,
          isEmpty,
          reason:
              'section "${entry.key}" defaultSelected includes variables '
              'that are not in `available`: $missing',
        );
      }
    });

    test('every available variable starts with \$', () {
      for (final entry in kPdfVariableSections.entries) {
        for (final v in entry.value.available) {
          expect(
            v.startsWith('\$'),
            isTrue,
            reason: 'section "${entry.key}" variable "$v" missing leading \$',
          );
        }
      }
    });

    test('client_details includes location_name and postal_city variants '
        '(audit follow-up)', () {
      final available =
          kPdfVariableSections[PdfVariableSection.clientDetails]!.available;
      expect(available, contains('\$client.location_name'));
      expect(available, contains('\$client.postal_city'));
      expect(available, contains('\$client.postal_city_state'));
    });

    test('purchase_order_details includes po_number and balance_due '
        '(audit follow-up)', () {
      final available =
          kPdfVariableSections[PdfVariableSection.purchaseOrderDetails]!
              .available;
      expect(available, contains('\$purchase_order.po_number'));
      expect(available, contains('\$purchase_order.balance_due'));
    });

    test('total_columns default-selected leads with net_subtotal '
        '(matches backend getEntityVariableDefaults)', () {
      final defaults = kPdfVariableSections[PdfVariableSection.totalColumns]!
          .defaultSelected;
      expect(defaults.first, '\$net_subtotal');
      expect(defaults, contains('\$subtotal'));
    });

    test('default-selected lists track the backend getEntityVariableDefaults '
        'additions (audit follow-up)', () {
      List<String> defaultsFor(String key) =>
          kPdfVariableSections[key]!.defaultSelected;

      // client_details leads with the location name.
      expect(
        defaultsFor(PdfVariableSection.clientDetails).first,
        '\$client.location_name',
      );
      // invoice / quote details carry the project column last.
      expect(
        defaultsFor(PdfVariableSection.invoiceDetails).last,
        '\$invoice.project',
      );
      expect(
        defaultsFor(PdfVariableSection.quoteDetails).last,
        '\$quote.project',
      );
      // credit details include the valid-until date.
      expect(
        defaultsFor(PdfVariableSection.creditDetails),
        contains('\$credit.valid_until'),
      );
      // vendor details include country + phone.
      expect(
        defaultsFor(PdfVariableSection.vendorDetails),
        containsAll(<String>['\$vendor.country', '\$vendor.phone']),
      );
    });

    test('every section that can carry tags offers the tag variable', () {
      // Tags are renderable on PDFs; each section exposes the token for the
      // entity it describes. `companyAddress` mirrors `companyDetails` and
      // `productQuoteColumns` mirrors `productColumns` — those pairs have
      // always offered the same variables and differ only in defaults.
      const expected = <String, String>{
        PdfVariableSection.clientDetails: r'$client.tags',
        PdfVariableSection.companyDetails: r'$company.tags',
        PdfVariableSection.companyAddress: r'$company.tags',
        PdfVariableSection.invoiceDetails: r'$invoice.tags',
        PdfVariableSection.quoteDetails: r'$quote.tags',
        PdfVariableSection.creditDetails: r'$credit.tags',
        PdfVariableSection.vendorDetails: r'$vendor.tags',
        PdfVariableSection.purchaseOrderDetails: r'$purchase_order.tags',
        PdfVariableSection.productColumns: r'$product.tags',
        PdfVariableSection.productQuoteColumns: r'$product.tags',
        PdfVariableSection.taskColumns: r'$task.tags',
      };

      expected.forEach((section, token) {
        expect(
          kPdfVariableSections[section]!.available,
          contains(token),
          reason: 'section "$section" should offer $token',
        );
      });
    });

    test('no section default-selects a tag variable (tags stay opt-in)', () {
      for (final entry in kPdfVariableSections.entries) {
        final tagged = entry.value.defaultSelected
            .where((v) => v.endsWith('.tags'))
            .toList();
        expect(
          tagged,
          isEmpty,
          reason:
              'section "${entry.key}" default-selects $tagged, but the backend '
              'getEntityVariableDefaults() carries no tag variable — a default '
              'here would put an unrendered token on every new company',
        );
      }
    });
  });
}
