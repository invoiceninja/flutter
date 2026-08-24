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

  /// Default minimal config — qty/cost/total only, one tax column hidden.
  /// Used as a safe fallback when company settings haven't loaded yet.
  static const minimal = LineItemColumnConfig(
    taxColumnCount: 0,
    showDiscount: false,
  );

  /// The config a billing-doc editor should show for [enabledItemTaxRates] —
  /// the company's `enabled_item_tax_rates` (0..3).
  ///
  /// The tax count used to be hard-coded to 1 in all five edit layouts, so
  /// Tax Name 1 / Tax Rate 1 sat on every line item even for a company with
  /// line-item taxes switched off (invoiceninja/flutter#85). Null — the frames
  /// before the company row loads — means "unknown", and shows nothing rather
  /// than guessing a tax field into existence.
  factory LineItemColumnConfig.forCompany({
    required int? enabledItemTaxRates,
    bool showDiscount = true,
  }) => LineItemColumnConfig(
    taxColumnCount: (enabledItemTaxRates ?? 0).clamp(0, 3),
    showDiscount: showDiscount,
  );

  LineItemColumnConfig copyWith({
    bool? showCustom1,
    bool? showCustom2,
    bool? showCustom3,
    bool? showCustom4,
    int? taxColumnCount,
    bool? showDiscount,
    bool? useTaxCategories,
  }) => LineItemColumnConfig(
    showCustom1: showCustom1 ?? this.showCustom1,
    showCustom2: showCustom2 ?? this.showCustom2,
    showCustom3: showCustom3 ?? this.showCustom3,
    showCustom4: showCustom4 ?? this.showCustom4,
    taxColumnCount: taxColumnCount ?? this.taxColumnCount,
    showDiscount: showDiscount ?? this.showDiscount,
    useTaxCategories: useTaxCategories ?? this.useTaxCategories,
  );
}
