import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/billing_doc_fields.dart';
import 'package:admin/data/models/domain/purchase_order.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/history/document_version_route_mixin.dart';
import 'package:admin/ui/features/billing_shared/pdf/billing_doc_pdf_screen.dart';
import 'package:admin/ui/features/billing_shared/pdf/signed_copy_route_mixin.dart';

/// Route wrapper for `/purchase_orders/:id/pdf`. Mirrors
/// `CreditPdfRouteScreen`.
class PurchaseOrderPdfRouteScreen extends StatefulWidget {
  const PurchaseOrderPdfRouteScreen({
    super.key,
    required this.id,
    this.activityId,
    this.signedCopy = false,
  });
  final String id;

  /// When set (route `?activity_id=`), the preview opens on that saved
  /// version rather than the live document.
  final String? activityId;

  /// When true (route `?signed=1`, the Signed Document pill), the preview is
  /// the stored DocuNinja-signed copy, even while the record has unsynced
  /// edits, for as long as the server would still serve it
  /// ([SignedCopyRouteMixin]).
  final bool signedCopy;

  @override
  State<PurchaseOrderPdfRouteScreen> createState() =>
      _PurchaseOrderPdfRouteScreenState();
}

class _PurchaseOrderPdfRouteScreenState
    extends State<PurchaseOrderPdfRouteScreen>
    with FormatterHostMixin, DocumentVersionRouteMixin, SignedCopyRouteMixin {
  late final Services _services;
  late final Stream<PurchaseOrder?> _stream;
  late final String _companyId;

  @override
  String get entityId => widget.id;

  @override
  String? get initialActivityId => widget.activityId;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _stream = _services.purchaseOrders.watch(
      companyId: _companyId,
      id: widget.id,
    );
    loadFormatter(_services, _companyId);
    initVersions(_services, basePath: _services.purchaseOrders.api.basePath);
    initSignedCopy(_services, _companyId, widget.signedCopy);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PurchaseOrder?>(
      stream: _stream,
      builder: (context, snapshot) {
        final po = snapshot.data;
        if (po == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!signedCopyReady) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final signedCopy = opensSignedCopy(
          services: _services,
          requested: widget.signedCopy,
          sync: po.sync,
          documents: po.documents,
        );
        final activityId = selectedActivityId;
        return BillingDocPdfScreen(
          entity: BillingDocType.purchaseOrder,
          entityNumber: po.number,
          // A frozen version render has no delivery-note variant.
          deliveryNoteAvailable: activityId == null,
          revision: activityId,
          contentRevision: activityId == null ? po : null,
          hasUnsyncedChanges: po.isDirty,
          versions: versions,
          selectedActivityId: activityId,
          onVersionChanged: selectVersion,
          formatter: formatter,
          fetcher: activityId == null
              ? ({String? designId, required bool deliveryNote}) =>
                    _services.purchaseOrders.api.downloadPdf(
                      entityJson: po.toApiJson(),
                      designId:
                          designId ??
                          (po.designId.isEmpty ? null : po.designId),
                      storedPdfKey: signedCopy
                          ? po.signedPdfInvitationKey
                          : po.storedPdfInvitationKey,
                    )
              : ({String? designId, required bool deliveryNote}) =>
                    _services.documentVersions.downloadVersionPdf(activityId),
        );
      },
    );
  }
}
