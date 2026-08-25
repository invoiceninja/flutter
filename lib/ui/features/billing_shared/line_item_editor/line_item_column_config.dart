import 'package:admin/data/models/domain/company.dart';
import 'package:admin/ui/core/utils/company_labels.dart';

/// Which optional columns the [LineItemEditor] shows. Driven from the
/// active company's settings; built once per edit-screen mount.
///
/// The four custom slots map to `company.customFields['product1'..]`
/// (admin-portal calls these line-item customs, even though the keys
/// reference product fields). The discount column hides when the company
/// has product discounts disabled. Tax columns count is 0..3 — the
/// company's tax-rate enablement bitmask drives this.
class LineItemColumnConfig {
  const LineItemColumnConfig({
    this.showCustom1 = false,
    this.showCustom2 = false,
    this.showCustom3 = false,
    this.showCustom4 = false,
    this.taxColumnCount = 1,
    this.showDiscount = false,
    this.useTaxCategories = false,
    this.labels = const CompanyLabels.empty(),
  });

  /// Show the four invoice-line custom-value columns. Each is independent.
  final bool showCustom1;
  final bool showCustom2;
  final bool showCustom3;
  final bool showCustom4;

  /// How many of the three tax-rate slots to surface. 0 hides taxes
  /// entirely; 1..3 progressively shows tax_name1/rate1 through 3.
  final int taxColumnCount;

  /// Show the per-line discount column.
  final bool showDiscount;

  /// When true, the line-item editor exposes a tax_category dropdown
  /// instead of name + rate fields (server computes taxes). Today the
  /// admin-portal toggle is `company.settings.calculate_taxes`. When set,
  /// `taxColumnCount` is ignored in favor of a single category cell.
  final bool useTaxCategories;

  /// The company's Custom Labels, applied to the column headers. Empty until
  /// [forCompany] fills it in, so a header always has the bundled string to
  /// fall back on.
  final CompanyLabels labels;

  /// Default minimal config — qty/cost/total only, one tax column hidden.
  /// Used as a safe fallback when company settings haven't loaded yet.
  static const minimal = LineItemColumnConfig(
    taxColumnCount: 0,
    showDiscount: false,
  );

  /// This config narrowed by what [company] actually enables — the host
  /// declares what it *wants* to show, the company decides what it *may*.
  ///
  /// A null company means "not loaded yet", and keeps the host's config
  /// rather than guessing: a first frame that guessed would reflow the table
  /// the moment the row landed. The tax count was hard-coded to 1 by all five
  /// edit layouts before this existed, so a company with line-item taxes off
  /// still got Tax Name 1 / Tax Rate 1 on every row
  /// (invoiceninja/flutter#85). Clamped to the three slots the editor renders.
  ///
  /// Also the point where the company's Custom Labels
  /// (`settings.translations`) reach the headers — the server, React and
  /// admin-portal all honor them and this app was storing them without ever
  /// reading them back (invoiceninja/flutter#84).
  LineItemColumnConfig forCompany(Company? company) => company == null
      ? this
      : copyWith(
          showDiscount: showDiscount && company.enableProductDiscount,
          taxColumnCount: company.enabledItemTaxRates.clamp(0, 3),
          labels: CompanyLabels.fromCompany(company),
        );

  LineItemColumnConfig copyWith({
    bool? showCustom1,
    bool? showCustom2,
    bool? showCustom3,
    bool? showCustom4,
    int? taxColumnCount,
    bool? showDiscount,
    bool? useTaxCategories,
    CompanyLabels? labels,
  }) => LineItemColumnConfig(
    showCustom1: showCustom1 ?? this.showCustom1,
    showCustom2: showCustom2 ?? this.showCustom2,
    showCustom3: showCustom3 ?? this.showCustom3,
    showCustom4: showCustom4 ?? this.showCustom4,
    taxColumnCount: taxColumnCount ?? this.taxColumnCount,
    showDiscount: showDiscount ?? this.showDiscount,
    useTaxCategories: useTaxCategories ?? this.useTaxCategories,
    labels: labels ?? this.labels,
  );
}
