import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/ui/features/billing_shared/view_models/billing_doc_edit_view_model.dart';

/// Which billing-doc type owns this tab. Drives the small per-entity
/// branches: only credits show the billing-reference [leading] card, and
/// only recurring invoices serialize the period as the React-style
/// pipe-delimited `Invoice.InvoicePeriod.0.Description` string.
enum EInvoiceEntityKind { invoice, credit, recurringInvoice }

/// Reusable e-invoice (PEPPOL/UBL) edit tab, shared by invoice / credit /
/// recurring-invoice edit layouts.
///
/// `eInvoice` is an open-ended `Map<String, dynamic>` on the wire rather
/// than a typed model. This surfaces the period (start + end) + actual
/// delivery date, an optional [leading] card (credit billing reference),
/// and the document-type read-out (F1 / R1 / R2 for Verifactu — only
/// invoices carry that today via their `backup` map). The generic
/// [GenericBillingDocEditViewModel] owns `eInvoiceOf` / `setEInvoiceField`
/// / `setEInvoicePath`, so every billing-doc type works through the same
/// path with only the [entityKind] branch.
class EInvoiceFieldsTab<T> extends StatelessWidget {
  const EInvoiceFieldsTab({
    required this.vm,
    required this.entityKind,
    this.documentType,
    this.formatter,
    this.leading,
    super.key,
  });

  final GenericBillingDocEditViewModel<T> vm;

  final EInvoiceEntityKind entityKind;

  /// Optional Verifactu document-type chip (invoice-only today). Null hides
  /// the chip — credit / recurring don't carry a `backup` map.
  final String? documentType;

  /// Active company `Formatter`. Passed in from the caller (the generic VM
  /// doesn't expose `companyId`) so the period dates render/parse with the
  /// company date format instead of raw ISO. Null falls back to ISO.
  final Formatter? formatter;

  /// Optional card rendered at the top of the tab (the credit
  /// billing-reference picker). Null for invoice / recurring.
  final Widget? leading;

  /// React serializes the recurring-invoice period as a single
  /// pipe-delimited string here rather than the nested StartDate/EndDate
  /// pair invoices/credits use.
  static const _recurringPeriodPath = <Object>[
    'Invoice',
    'InvoicePeriod',
    0,
    'Description',
  ];

  /// The UBL paths the server actually consumes — the `$invoice_period` and
  /// `$actual_delivery_date` PDF variables read
  /// `e_invoice.Invoice.InvoicePeriod.0.StartDate/EndDate` and
  /// `e_invoice.Invoice.Delivery.0.ActualDeliveryDate` (HtmlEngine.php; the
  /// engine is shared, so the `Invoice` root applies to credits too), the
  /// PEPPOL XML builder reads the same period path, and React's invoice
  /// EInvoice tab writes these exact keys. The flat keys this tab used to
  /// write (`invoice_period_start` / `invoice_period_end` /
  /// `actual_delivery_date`) have **no server consumer** — they're kept
  /// below strictly as read fallbacks so values saved by older builds still
  /// display, and are cleared on the next write.
  static const _periodStartPath = <Object>[
    'Invoice',
    'InvoicePeriod',
    0,
    'StartDate',
  ];
  static const _periodEndPath = <Object>[
    'Invoice',
    'InvoicePeriod',
    0,
    'EndDate',
  ];
  static const _deliveryPath = <Object>[
    'Invoice',
    'Delivery',
    0,
    'ActualDeliveryDate',
  ];

  Date? _readFlatDate(String key) {
    final raw = vm.eInvoiceOf(vm.draft)?[key];
    if (raw is String) return Date.tryParse(raw);
    return null;
  }

  Date? _readPathDate(List<Object> path) {
    final raw = vm.readEInvoicePath(vm.draft, path);
    if (raw is String) return Date.tryParse(raw);
    return null;
  }

  ({Date? start, Date? end}) _readPeriod() {
    if (entityKind == EInvoiceEntityKind.recurringInvoice) {
      final desc = vm.readEInvoicePath(vm.draft, _recurringPeriodPath);
      if (desc is String && desc.isNotEmpty) {
        // The complete UBL form is "start|end"; tolerate a pipeless legacy
        // value (treat it as the start) so a single-value record still reads.
        final parts = desc.split('|');
        return (
          start: Date.tryParse(parts[0]),
          end: parts.length > 1 ? Date.tryParse(parts[1]) : null,
        );
      }
      // Partial entry (only one date so far) is buffered in the flat keys —
      // and so are legacy records saved before this reconcile. Fall through.
    }
    final start = _readPathDate(_periodStartPath);
    final end = _readPathDate(_periodEndPath);
    if (start != null || end != null) return (start: start, end: end);
    // Legacy fallback: flat keys written by older builds of this app.
    return (
      start: _readFlatDate('invoice_period_start'),
      end: _readFlatDate('invoice_period_end'),
    );
  }

  void _commitPeriod(Date? start, Date? end) {
    if (entityKind == EInvoiceEntityKind.recurringInvoice) {
      if (start != null && end != null) {
        // Complete: emit the canonical UBL string, drop the flat buffer so
        // we never ship both encodings.
        vm.setEInvoicePath(
          _recurringPeriodPath,
          '${start.toIso()}|${end.toIso()}',
        );
        vm.setEInvoiceField('invoice_period_start', null);
        vm.setEInvoiceField('invoice_period_end', null);
      } else {
        // Partial: keep the half-entered value in the flat keys so it
        // survives the rebuild; clear any stale Description.
        vm.setEInvoicePath(_recurringPeriodPath, null);
        vm.setEInvoiceField('invoice_period_start', start?.toIso());
        vm.setEInvoiceField('invoice_period_end', end?.toIso());
      }
      return;
    }
    vm.setEInvoicePath(_periodStartPath, start?.toIso());
    vm.setEInvoicePath(_periodEndPath, end?.toIso());
    // Migrate away from the dead flat keys older builds wrote.
    vm.setEInvoiceField('invoice_period_start', null);
    vm.setEInvoiceField('invoice_period_end', null);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final docType = documentType;
    return ListView(
      // On a wide editor this sits in the fixed-height notes card on a page
      // that scrolls; a primary list would claim every drag even when the
      // form fits (docs/rich-text-editing.md, the `primary: false` heading).
      primary: false,
      padding: EdgeInsets.all(InSpacing.lg(context)),
      children: [
        if (docType != null && docType.isNotEmpty)
          Container(
            margin: EdgeInsets.only(bottom: InSpacing.md(context)),
            padding: EdgeInsets.all(InSpacing.md(context)),
            decoration: BoxDecoration(
              border: Border.all(color: tokens.border),
              borderRadius: BorderRadius.circular(InRadii.r2),
              color: tokens.surface,
            ),
            child: Row(
              children: [
                Icon(Icons.qr_code_2_outlined, size: 18, color: tokens.ink3),
                const SizedBox(width: 8),
                Text(
                  context.tr('document_type'),
                  style: TextStyle(color: tokens.ink3, fontSize: 12),
                ),
                const SizedBox(width: 8),
                Text(
                  docType,
                  style: TextStyle(
                    color: tokens.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        if (leading != null) ...[
          leading!,
          SizedBox(height: InSpacing.lg(context)),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final period = _readPeriod();
            final start = InDateField(
              value: period.start?.toDateTime(),
              formatter: formatter,
              onChanged: (d) => _commitPeriod(
                d == null ? null : Date(d.year, d.month, d.day),
                _readPeriod().end,
              ),
              labelText: context.tr('invoice_period_start'),
              clearable: true,
            );
            final end = InDateField(
              value: period.end?.toDateTime(),
              formatter: formatter,
              onChanged: (d) => _commitPeriod(
                _readPeriod().start,
                d == null ? null : Date(d.year, d.month, d.day),
              ),
              labelText: context.tr('invoice_period_end'),
              clearable: true,
            );
            if (Breakpoints.isWide(constraints)) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: start),
                  SizedBox(width: InSpacing.md(context)),
                  Expanded(child: end),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                start,
                SizedBox(height: InSpacing.md(context)),
                end,
              ],
            );
          },
        ),
        SizedBox(height: InSpacing.md(context)),
        InDateField(
          value:
              (_readPathDate(_deliveryPath) ??
                      _readFlatDate('actual_delivery_date'))
                  ?.toDateTime(),
          formatter: formatter,
          onChanged: (d) {
            vm.setEInvoicePath(
              _deliveryPath,
              d == null ? null : Date(d.year, d.month, d.day).toIso(),
            );
            // Migrate away from the dead flat key older builds wrote.
            vm.setEInvoiceField('actual_delivery_date', null);
          },
          labelText: context.tr('actual_delivery_date'),
          clearable: true,
        ),
        SizedBox(height: InSpacing.lg(context)),
        Text(
          context.tr('einvoice_help'),
          style: TextStyle(color: tokens.ink3, fontSize: 12),
        ),
      ],
    );
  }
}
