import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/purchase_order.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_doc_edit_layout.dart';
import 'package:admin/ui/features/billing_shared/pdf/billing_doc_draft_preview.dart';
import 'package:admin/ui/features/purchase_orders/view_models/purchase_order_edit_view_model.dart';

/// The purchase order edit body: [BillingDocEditLayout] as a purchase order.
/// What makes it one is [BillingDocType.purchaseOrder] — addressed to a
/// vendor (the vendor picker, frozen once saved, and the vendor's contacts),
/// one number field labelled "PO Number", no partial payment, a Products-only
/// item picker — plus its PDF fetcher.
class PurchaseOrderEditLayout extends StatelessWidget {
  const PurchaseOrderEditLayout({
    super.key,
    required this.vm,
    this.showPdfTab = true,
  });

  final PurchaseOrderEditViewModel vm;

  /// Whether the narrow strip carries a `PDF` tab — see
  /// [BillingDocEditLayout.showPdfTab] (invoiceninja/flutter#140).
  final bool showPdfTab;

  @override
  Widget build(BuildContext context) => BillingDocEditLayout<PurchaseOrder>(
    type: BillingDocType.purchaseOrder,
    vm: vm,
    showPdfTab: showPdfTab,
    slots: BillingDocEditSlots(
      pdfFetcher: (context) => _draftPdfFetcher(context, vm),
    ),
  );
}

/// The one `live_preview` fetcher for a purchase-order draft — shared by the
/// PDF tab, the desktop pane and the header's preview button.
BillingDocPdfFetcher _draftPdfFetcher(
  BuildContext context,
  PurchaseOrderEditViewModel vm,
) {
  final services = context.read<Services>();
  return ({String? designId, required bool deliveryNote}) =>
      services.purchaseOrders.api.downloadPdf(
        entityJson: vm.draft.toApiJson(),
        designId:
            designId ?? (vm.draft.designId.isEmpty ? null : vm.draft.designId),
      );
}

/// The narrow edit header's draft-PDF button — see
/// [billingDocDraftPreviewButton]. Gated on the **vendor**: a purchase order
/// has no client, and the server cannot render one without a vendor.
Widget purchaseOrderDraftPreviewButton(
  BuildContext context,
  PurchaseOrderEditViewModel vm,
) => billingDocDraftPreviewButton(
  BillingDocType.purchaseOrder,
  vm,
  _draftPdfFetcher(context, vm),
);
