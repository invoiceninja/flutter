import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/credit.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_doc_edit_layout.dart';
import 'package:admin/ui/features/billing_shared/edit/credit_billing_reference_field.dart';
import 'package:admin/ui/features/billing_shared/edit/e_invoice_fields_tab.dart';
import 'package:admin/ui/features/billing_shared/pdf/billing_doc_draft_preview.dart';
import 'package:admin/ui/features/credits/view_models/credit_edit_view_model.dart';

/// The credit edit body: [BillingDocEditLayout] as a credit. What makes it one
/// is [BillingDocType.credit] — "Credit Date" / "Due Date", the partial after
/// the dates on a phone — plus its PDF fetcher and its E-Invoice tab, which
/// leads with the reference to the invoice being credited.
class CreditEditLayout extends StatelessWidget {
  const CreditEditLayout({super.key, required this.vm, this.showPdfTab = true});

  final CreditEditViewModel vm;

  /// Whether the narrow strip carries a `PDF` tab — see
  /// [BillingDocEditLayout.showPdfTab] (invoiceninja/flutter#140).
  final bool showPdfTab;

  @override
  Widget build(BuildContext context) => BillingDocEditLayout<Credit>(
    type: BillingDocType.credit,
    vm: vm,
    showPdfTab: showPdfTab,
    slots: BillingDocEditSlots(
      pdfFetcher: (context) => _draftPdfFetcher(context, vm),
      eInvoiceTab: (context) {
        final formatter = context.read<Services>().formatterIfReady(
          vm.companyId,
        );
        return EInvoiceFieldsTab<Credit>(
          vm: vm,
          entityKind: EInvoiceEntityKind.credit,
          formatter: formatter,
          leading: CreditBillingReferenceField(
            vm: vm,
            companyId: vm.companyId,
            formatter: formatter,
          ),
        );
      },
    ),
  );
}

/// The one `live_preview` fetcher for a credit draft — shared by the PDF tab,
/// the desktop pane and the header's preview button.
BillingDocPdfFetcher _draftPdfFetcher(
  BuildContext context,
  CreditEditViewModel vm,
) {
  final services = context.read<Services>();
  return ({String? designId, required bool deliveryNote}) =>
      services.credits.api.downloadPdf(
        entityJson: vm.draft.toApiJson(),
        designId:
            designId ?? (vm.draft.designId.isEmpty ? null : vm.draft.designId),
      );
}

/// The narrow edit header's draft-PDF button — see
/// [billingDocDraftPreviewButton].
Widget creditDraftPreviewButton(BuildContext context, CreditEditViewModel vm) =>
    billingDocDraftPreviewButton(
      BillingDocType.credit,
      vm,
      _draftPdfFetcher(context, vm),
    );
