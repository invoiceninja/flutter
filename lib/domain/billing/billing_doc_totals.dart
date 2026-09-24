import 'package:admin/data/models/domain/billing/billing_doc_fields.dart';
import 'package:admin/domain/billing/totals_calculator.dart';

/// The [computeTotals] input for any billing document. It was written out by
/// hand eight times — in each edit view model and three detail screens — and
/// a field added to one copy and not the others would have made a document's
/// edit screen and its detail screen disagree about its total.
extension BillingDocTotals on BillingDocFields {
  BillingTotalsInput get totalsInput => BillingTotalsInput(
    lineItems: lineItems,
    discount: discount,
    isAmountDiscount: isAmountDiscount,
    usesInclusiveTaxes: usesInclusiveTaxes,
    taxName1: taxName1,
    taxRate1: taxRate1,
    taxName2: taxName2,
    taxRate2: taxRate2,
    taxName3: taxName3,
    taxRate3: taxRate3,
    customSurcharge1: customSurcharge1,
    customSurcharge2: customSurcharge2,
    customSurcharge3: customSurcharge3,
    customSurcharge4: customSurcharge4,
    customTaxes1: customTaxes1,
    customTaxes2: customTaxes2,
    customTaxes3: customTaxes3,
    customTaxes4: customTaxes4,
  );
}
