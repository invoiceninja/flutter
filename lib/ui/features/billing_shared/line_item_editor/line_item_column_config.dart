import 'package:flutter/foundation.dart';

import 'package:admin/data/models/domain/billing/line_item_custom_fields.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/ui/core/utils/company_labels.dart';

/// Which optional columns the [LineItemEditor] shows. Driven from the
/// active company's settings; built once per edit-screen mount.
///
/// The custom-field columns come from the company's `product1..4` — or
/// `task1..4` on a task table — see [customFields]. The discount column hides
/// when the company has product discounts disabled. Tax columns count is
/// 0..3 — the company's tax-rate enablement bitmask drives this.
class LineItemColumnConfig {
  const LineItemColumnConfig({
    this.customFields = const [],
    this.taxColumnCount = 1,
    this.showDiscount = false,
    this.useTaxCategories = false,
    this.labels = const CompanyLabels.empty(),
    this.isTaskTable = false,
  });

  /// The company's configured custom fields for this table, in slot order —
  /// one column on the desktop table and one field in the edit dialog each.
  /// Empty until [forCompany] resolves them, and empty for a company that
  /// defines none.
  ///
  /// The line item stored `customValue1..4` all along — a product picked
  /// from the phone picker copied its values in — but nothing ever turned a
  /// slot on, so no surface showed or edited them.
  final List<LineItemCustomField> customFields;

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

  /// The table holds hourly (`type_id` 2) lines — the Tasks tab of
  /// `BillingDocItemsTabs`. Only the words change: [labelKey] renames Item /
  /// Unit Cost / Quantity to Service / Rate / Hours, the columns admin-portal
  /// and the server's PDF task table use for the same three fields.
  final bool isTaskTable;

  /// The label key to show for the column / field named [key]. A task table
  /// swaps the three product words for their hourly counterparts; every other
  /// key passes through. Resolve the result through [labels], so a company's
  /// Custom Label for `service` / `rate` / `hours` wins, as it does on the PDF.
  String labelKey(String key) {
    if (!isTaskTable) return key;
    return switch (key) {
      'item' || 'product' => 'service',
      'unit_cost' => 'rate',
      'quantity' => 'hours',
      _ => key,
    };
  }

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
  ///
  /// And where the custom fields arrive: `product1..4`, or `task1..4` for a
  /// task table, the labels React and admin-portal use for the same columns.
  LineItemColumnConfig forCompany(Company? company) => company == null
      ? this
      : copyWith(
          showDiscount: showDiscount && company.enableProductDiscount,
          taxColumnCount: company.enabledItemTaxRates.clamp(0, 3),
          labels: CompanyLabels.fromCompany(company),
          customFields: lineItemCustomFields(
            company.customFields,
            task: isTaskTable,
          ),
        );

  // Value equality: [forCompany] builds a new config on every editor build,
  // and the desktop table reuses a row's widget only while its config is
  // unchanged — by identity, no row could ever be reused.
  @override
  bool operator ==(Object other) =>
      other is LineItemColumnConfig &&
      listEquals(other.customFields, customFields) &&
      other.taxColumnCount == taxColumnCount &&
      other.showDiscount == showDiscount &&
      other.useTaxCategories == useTaxCategories &&
      other.labels == labels &&
      other.isTaskTable == isTaskTable;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(customFields),
    taxColumnCount,
    showDiscount,
    useTaxCategories,
    labels,
    isTaskTable,
  );

  LineItemColumnConfig copyWith({
    List<LineItemCustomField>? customFields,
    int? taxColumnCount,
    bool? showDiscount,
    bool? useTaxCategories,
    CompanyLabels? labels,
    bool? isTaskTable,
  }) => LineItemColumnConfig(
    customFields: customFields ?? this.customFields,
    taxColumnCount: taxColumnCount ?? this.taxColumnCount,
    showDiscount: showDiscount ?? this.showDiscount,
    useTaxCategories: useTaxCategories ?? this.useTaxCategories,
    labels: labels ?? this.labels,
    isTaskTable: isTaskTable ?? this.isTaskTable,
  );
}
