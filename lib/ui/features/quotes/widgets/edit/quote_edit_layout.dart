import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_doc_edit_layout.dart';
import 'package:admin/ui/features/billing_shared/pdf/billing_doc_draft_preview.dart';
import 'package:admin/ui/features/quotes/view_models/quote_edit_view_model.dart';

/// The quote edit body: [BillingDocEditLayout] as a quote. What makes it one
/// is [BillingDocType.quote] — "Quote Date" / "Valid Until", the partial
/// after Discount on a phone, create-task-from-line-item — plus its PDF
/// fetcher. No E-Invoice tab: PEPPOL submission applies to invoices, credits
/// and recurring invoices only.
class QuoteEditLayout extends StatelessWidget {
  const QuoteEditLayout({super.key, required this.vm, this.showPdfTab = true});

  final QuoteEditViewModel vm;

  /// Whether the narrow strip carries a `PDF` tab — see
  /// [BillingDocEditLayout.showPdfTab] (invoiceninja/flutter#140).
  final bool showPdfTab;

  @override
  Widget build(BuildContext context) => BillingDocEditLayout<Quote>(
    type: BillingDocType.quote,
    vm: vm,
    showPdfTab: showPdfTab,
    slots: BillingDocEditSlots(
      pdfFetcher: (context) => _draftPdfFetcher(context, vm),
    ),
  );
}

/// The one `live_preview` fetcher for a quote draft — shared by the PDF tab,
/// the desktop pane and the header's preview button.
BillingDocPdfFetcher _draftPdfFetcher(
  BuildContext context,
  QuoteEditViewModel vm,
) {
  final services = context.read<Services>();
  return ({String? designId, required bool deliveryNote}) =>
      services.quotes.api.downloadPdf(
        entityJson: vm.draft.toApiJson(),
        designId:
            designId ?? (vm.draft.designId.isEmpty ? null : vm.draft.designId),
      );
}

/// The narrow edit header's draft-PDF button — see
/// [billingDocDraftPreviewButton].
Widget quoteDraftPreviewButton(BuildContext context, QuoteEditViewModel vm) =>
    billingDocDraftPreviewButton(
      BillingDocType.quote,
      vm,
      _draftPdfFetcher(context, vm),
    );
