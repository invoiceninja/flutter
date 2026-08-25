import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/party_money_cell.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_card_list_mobile.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_column_config.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_table_desktop.dart';

/// Entry widget for editing the line-item list on any billing-doc edit
/// screen (Invoice / Quote / Credit / PO / RecurringInvoice). Switches
/// between the desktop inline-table and the mobile card-list based on
/// the available width.
///
/// The two underlying widgets share the same `(items, onChanged,
/// newItemFactory, config)` signature so the editor itself is just a
/// `LayoutBuilder`. Both delegate to `showLineItemEditDialog` for actual
/// row editing (M3 first cut) — M3.5 / M4 introduces inline-editable
/// cells with product autocomplete on desktop.
class LineItemEditor extends StatefulWidget {
  const LineItemEditor({
    super.key,
    required this.companyId,
    required this.items,
    required this.onChanged,
    required this.newItemFactory,
    this.clientId,
    this.vendorId,
    this.config = LineItemColumnConfig.minimal,
    this.controller,
    this.disabledReasonKey,
    this.rowErrors,
    this.onPickItems,
    this.showStockQuantity = false,
    this.onCreateTaskFromLineItem,
  });

  /// Company scope for the desktop table's product autocomplete +
  /// company-format-settings (decimal separator).
  final String companyId;

  /// The billing doc's client. When the company's `convert_products` is on
  /// and the client's currency differs from the company's, a filled product's
  /// price is converted to the client currency (React parity). Empty/null
  /// (e.g. purchase orders, which bill a vendor) → no conversion.
  ///
  /// Also the display-currency source for client-billed docs — line-item money
  /// renders in this client's currency (see [vendorId] for the PO counterpart).
  final String? clientId;

  /// The billing doc's vendor (purchase orders). Display-currency source for
  /// vendor-billed docs: line-item money renders in this vendor's currency.
  /// Client-billed docs leave it null and use [clientId] instead. Resolved via
  /// [PartyCurrencyBuilder], which ranks vendor over client.
  final String? vendorId;

  final List<LineItem> items;
  final ValueChanged<List<LineItem>> onChanged;

  /// Factory invoked when the user taps "Add item". The host typically
  /// returns [emptyLineItem] but can seed defaults (e.g. apply the
  /// company's default tax rate name + rate).
  final LineItem Function() newItemFactory;

  /// Which optional columns to show — driven by company settings.
  final LineItemColumnConfig config;

  /// Optional handle the host can pass in to call `flushPending()` on
  /// the desktop table at save time, ensuring the 250 ms cell debounce
  /// doesn't drop the last keystrokes. No-op on mobile (the dialog
  /// commits synchronously on tap).
  final LineItemTableDesktopController? controller;

  /// When non-null, render a placeholder card with this localization
  /// key as the message instead of the editable table — used to gate
  /// the items section until a client (or vendor for PO) is picked.
  /// Avoids letting users type rows the server will reject as 422 for
  /// missing client_id.
  final String? disabledReasonKey;

  /// Per-row server validation errors keyed by line-item index. Keys
  /// inside each map mirror the API field names (`cost`, `quantity`,
  /// `product_key`, `notes`). Values are localized error messages.
  /// Surfaced inline in the desktop table and in the mobile dialog.
  final Map<int, Map<String, String>>? rowErrors;

  /// Forwarded to the mobile card list — the empty-state "Add item"
  /// button routes through this callback (the items-section FAB shares
  /// the same closure). No-op on desktop; the desktop table's ghost row
  /// covers the same affordance inline.
  final VoidCallback? onPickItems;

  /// Invoice host only — show the bracketed in-stock count on product rows in
  /// the desktop typeahead. ANDed with the company's `trackInventory` at the
  /// cell; other billing docs leave it false.
  final bool showStockQuantity;

  /// When set, each row offers "Create Task" — schedule the work the line
  /// describes as a dated task (invoiceninja/flutter#88). Injected by the
  /// invoice / quote layouts, the way `ClientPickerField.onCreateRequested` is,
  /// so this widget stays free of task-feature imports. Null on credit /
  /// recurring invoice / purchase order, where the affordance never renders.
  final ValueChanged<LineItem>? onCreateTaskFromLineItem;

  @override
  State<LineItemEditor> createState() => _LineItemEditorState();
}

class _LineItemEditorState extends State<LineItemEditor> {
  /// Cached, not built in `build`: `watchCompany` returns a fresh stream per
  /// call and this editor rebuilds on every VM notification, so a per-build
  /// stream restarted the Drift query each time. Same trap, and the same fix,
  /// as `InvoiceDesignPreviewPane`, which documents it.
  late Stream<Company?> _companyStream = _watchCompany();

  Stream<Company?> _watchCompany() =>
      context.read<Services>().company.watchCompany(widget.companyId);

  @override
  void didUpdateWidget(LineItemEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only on an actual company switch — anything looser reintroduces the
    // churn this exists to avoid.
    if (oldWidget.companyId != widget.companyId) {
      _companyStream = _watchCompany();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.disabledReasonKey != null) {
      return _DisabledItemsPlaceholder(reasonKey: widget.disabledReasonKey!);
    }
    final services = context.read<Services>();
    return StreamBuilder<Company?>(
      stream: _companyStream,
      builder: (context, snap) {
        final company = snap.data;
        // Gate the discount column on the company's `enable_product_discount`
        // (Settings → Product Settings). Hiding the column only suppresses the
        // input — any existing per-line discount stays on the model and is
        // still submitted. Until the company loads we keep the host's widget.config
        // so the common (enabled) case doesn't flash the column away.
        //
        // The tax columns ride along on the same read: `enabled_item_tax_rates`
        // used to be hard-coded to 1 by all five edit layouts, so a company
        // with line-item taxes off still got Tax Name 1 / Tax Rate 1 on every
        // row (invoiceninja/flutter#85). Same null-means-keep-the-host's-widget.config
        // rule as the discount column, and for the same reason — a first frame
        // that guesses 0 would reflow the table once the company lands.
        final effectiveConfig = widget.config.forCompany(company);
        // Convert a filled product's price to the client's currency only when
        // the company opts in and a client is set (purchase orders have none →
        // no conversion). The StreamBuilder<Client?> stays in the tree
        // unconditionally (empty stream when not converting) so toggling the
        // client / conversion state never re-types this position and tears down
        // the LineItemTableDesktop below — which holds row controllers, focus,
        // and pending debounced edits.
        final convert =
            company != null &&
            company.convertProducts &&
            (widget.clientId?.isNotEmpty ?? false);
        return StreamBuilder<Client?>(
          stream: convert
              ? services.clients.watchByRealId(
                  companyId: widget.companyId,
                  id: widget.clientId!,
                )
              : const Stream<Client?>.empty(),
          builder: (context, clientSnap) {
            Decimal? rate;
            if (convert) {
              final clientCurrencyId = clientSnap.data?.currencyId ?? '';
              final companyCurrencyId = company.settings.currencyId ?? '';
              if (clientCurrencyId.isNotEmpty &&
                  companyCurrencyId.isNotEmpty &&
                  clientCurrencyId != companyCurrencyId) {
                // company → client, matching React's
                // `clientCurrency.exchange_rate / companyCurrency.exchange_rate`.
                rate = crossCurrencyRate(
                  services.statics.currencies,
                  fromExpenseCurrencyId: companyCurrencyId,
                  toInvoiceCurrencyId: clientCurrencyId,
                );
              }
            }
            // Resolve the display currency from the doc's party — vendor for a
            // PO, client for client-billed docs — so line-item money renders in
            // the document currency instead of the company default (mirrors the
            // detail screen + totals block). The builder is always in the tree
            // (constant shape) so the desktop table's row controllers survive.
            return PartyCurrencyBuilder(
              clientId: widget.clientId,
              vendorId: widget.vendorId,
              builder: (context, currencyId) =>
                  _buildLayout(effectiveConfig, rate, currencyId),
            );
          },
        );
      },
    );
  }

  Widget _buildLayout(
    LineItemColumnConfig effectiveConfig,
    Decimal? productConversionRate,
    String? currencyId,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            Breakpoints.isWide(constraints) && constraints.maxWidth >= 700;
        if (wide) {
          return LineItemTableDesktop(
            companyId: widget.companyId,
            items: widget.items,
            onChanged: widget.onChanged,
            newItemFactory: widget.newItemFactory,
            config: effectiveConfig,
            currencyId: currencyId,
            productConversionRate: productConversionRate,
            controller: widget.controller,
            rowErrors: widget.rowErrors,
            showStockQuantity: widget.showStockQuantity,
            onCreateTaskFromLineItem: widget.onCreateTaskFromLineItem,
          );
        }
        return LineItemCardListMobile(
          companyId: widget.companyId,
          items: widget.items,
          onChanged: widget.onChanged,
          newItemFactory: widget.newItemFactory,
          config: effectiveConfig,
          currencyId: currencyId,
          onPickItems: widget.onPickItems,
          onCreateTaskFromLineItem: widget.onCreateTaskFromLineItem,
        );
      },
    );
  }
}

/// Placeholder rendered in place of the line-widget.items table when the
/// host indicates the section isn't ready yet (typically: no client
/// picked). Matches the table's outer chrome so the layout doesn't
/// shift when widget.items become editable.
class _DisabledItemsPlaceholder extends StatelessWidget {
  const _DisabledItemsPlaceholder({required this.reasonKey});
  final String reasonKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(InRadii.r3),
        border: Border.all(color: tokens.border),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.xl,
      ),
      child: Center(
        child: Text(
          context.tr(reasonKey),
          style: TextStyle(color: tokens.ink3, fontSize: 14),
        ),
      ),
    );
  }
}
