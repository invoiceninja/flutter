import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/static/pdf_catalogs.dart';
import 'package:admin/domain/custom_field_pdf_offer.dart';

/// React #3360 — offer to print a custom field the moment it gets a label.
void main() {
  group('newlyLabelledPdfFields', () {
    test('only fields that had no label and now have one', () {
      final offers = newlyLabelledPdfFields(
        before: {'invoice1': 'Ref|single_line_text', 'product2': ''},
        after: {
          'invoice1': 'Reference|single_line_text', // renamed, not new
          'invoice2': 'Site|single_line_text',
          'product2': 'Colour',
          'surcharge1': 'Freight',
          'client1': 'Region', // not printable here
        },
      );
      expect(offers.map((o) => o.customKey), [
        'invoice2',
        'product2',
        'surcharge1',
      ]);
      expect(offers.map((o) => o.variable), [
        r'$invoice.custom2',
        r'$product.product2',
        r'$custom_surcharge1',
      ]);
      expect(offers.first.label, 'Site');
      expect(offers.first.section, PdfVariableSection.invoiceDetails);
    });
  });

  group('withPdfFields', () {
    const site = PdfFieldOffer(
      customKey: 'invoice2',
      label: 'Site',
      section: PdfVariableSection.invoiceDetails,
      variable: r'$invoice.custom2',
    );

    test('an unset section starts from the catalog default, then appends', () {
      final next = withPdfFields(null, [site]);
      final defaults = kPdfVariableSections[PdfVariableSection.invoiceDetails]!
          .defaultSelected;
      expect(next[PdfVariableSection.invoiceDetails], [
        ...defaults,
        r'$invoice.custom2',
      ]);
    });

    test('a saved section keeps its order and gets the field at the end', () {
      final next = withPdfFields(
        {
          PdfVariableSection.invoiceDetails: [r'$invoice.number'],
        },
        [site],
      );
      expect(next[PdfVariableSection.invoiceDetails], [
        r'$invoice.number',
        r'$invoice.custom2',
      ]);
    });

    test('never adds a variable twice, and leaves the input untouched', () {
      final current = {
        PdfVariableSection.invoiceDetails: [r'$invoice.custom2'],
      };
      final next = withPdfFields(current, [site]);
      expect(next[PdfVariableSection.invoiceDetails], [r'$invoice.custom2']);
      expect(
        identical(
          next[PdfVariableSection.invoiceDetails],
          current.values.single,
        ),
        isFalse,
      );
    });
  });
}
