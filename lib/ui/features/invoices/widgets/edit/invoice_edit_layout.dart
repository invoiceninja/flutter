import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_doc_edit_layout.dart';
import 'package:admin/ui/features/billing_shared/edit/e_invoice_fields_tab.dart';
import 'package:admin/ui/features/billing_shared/pdf/billing_doc_draft_preview.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_edit_view_model.dart';

/// The invoice edit body: [BillingDocEditLayout] as an invoice. What makes it
/// one is [BillingDocType.invoice] — the partial beside its due date on a
/// phone, product stock at the picker, create-task-from-line-item — plus its
/// PDF fetcher with the delivery-note variant, the Settings tab's auto-bill
/// toggle and an E-Invoice tab carrying the Verifactu document type.
///
/// Per CLAUDE.md, this body lives under `/invoices/...` which is *not* under
/// `/settings/...` — so the wide-screen layout stretches to fill the
/// available width rather than capping at the settings-form max.
class InvoiceEditLayout extends StatelessWidget {
  const InvoiceEditLayout({
    super.key,
    required this.vm,
    this.showPdfTab = true,
  });

  final InvoiceEditViewModel vm;

  /// Whether the narrow strip carries a `PDF` tab — see
  /// [BillingDocEditLayout.showPdfTab] (invoiceninja/flutter#140).
  final bool showPdfTab;

  @override
  Widget build(BuildContext context) => BillingDocEditLayout<Invoice>(
    type: BillingDocType.invoice,
    vm: vm,
    showPdfTab: showPdfTab,
    slots: BillingDocEditSlots(
      pdfFetcher: (context) => _draftPdfFetcher(context, vm),
      deliveryNoteAvailable: () => _draftIsSaved(vm),
      autoBillEnabled: () => vm.draft.autoBillEnabled,
      onAutoBillEnabledChanged: vm.setAutoBillEnabled,
      eInvoiceTab: (context) => EInvoiceFieldsTab<Invoice>(
        vm: vm,
        entityKind: EInvoiceEntityKind.invoice,
        documentType: _invoiceDocType(vm.draft),
        formatter: context.read<Services>().formatterIfReady(vm.companyId),
      ),
    ),
  );
}

/// Delivery-note PDF lives behind a dedicated GET route that needs a real
/// (saved) invoice id, so the toggle stays hidden until the first save
/// round-trips.
bool _draftIsSaved(InvoiceEditViewModel vm) =>
    vm.draft.id.isNotEmpty && !vm.draft.id.startsWith('tmp_');

/// The one `live_preview` fetcher for an invoice draft — shared by the PDF
/// tab, the desktop pane and the header's preview button, so the three can't
/// disagree about which design or which variant they render.
BillingDocPdfFetcher _draftPdfFetcher(
  BuildContext context,
  InvoiceEditViewModel vm,
) {
  final services = context.read<Services>();
  return ({String? designId, required bool deliveryNote}) =>
      services.invoices.api.downloadPdf(
        entityJson: vm.draft.toApiJson(),
        designId:
            designId ?? (vm.draft.designId.isEmpty ? null : vm.draft.designId),
        deliveryNote: deliveryNote,
      );
}

/// The narrow edit header's draft-PDF button — see
/// [billingDocDraftPreviewButton].
Widget invoiceDraftPreviewButton(
  BuildContext context,
  InvoiceEditViewModel vm,
) => billingDocDraftPreviewButton(
  BillingDocType.invoice,
  vm,
  _draftPdfFetcher(context, vm),
  deliveryNoteAvailable: _draftIsSaved(vm),
);

/// Invoices additionally surface a Verifactu document-type chip on the
/// shared e-invoice tab, derived from the server-only `backup` map — credit /
/// recurring don't carry that, so the chip is invoice-only.
String? _invoiceDocType(Invoice d) {
  final b = d.backup;
  final v = b is Map<String, dynamic> ? b['document_type'] : null;
  return v is String ? v : null;
}
