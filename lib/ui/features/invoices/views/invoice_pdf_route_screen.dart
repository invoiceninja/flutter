import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/billing_doc_fields.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/history/document_version_route_mixin.dart';
import 'package:admin/ui/features/billing_shared/pdf/billing_doc_pdf_screen.dart';
import 'package:admin/ui/features/billing_shared/pdf/signed_copy_route_mixin.dart';

/// Route wrapper for `/invoices/:id/pdf`. Watches the invoice (to pick up
/// the latest number / design after a save round-trips) and renders the
/// shared [BillingDocPdfScreen] with a fetcher closure that hits the
/// `/api/v1/live_preview` endpoint via [InvoicesApi.downloadPdf].
///
/// With `?activity_id=` it instead renders that saved version, fetched from
/// `/api/v1/activities/download_entity/…`, and offers a picker over the
/// document's other versions.
class InvoicePdfRouteScreen extends StatefulWidget {
  const InvoicePdfRouteScreen({
    super.key,
    required this.id,
    this.initialDeliveryNote = false,
    this.activityId,
    this.signedCopy = false,
  });
  final String id;

  /// When true (route `?delivery_note=true`), the preview opens on the
  /// delivery-note variant with its toggle already on.
  final bool initialDeliveryNote;

  /// When set (route `?activity_id=`), the preview opens on that saved
  /// version rather than the live document.
  final String? activityId;

  /// When true (route `?signed=1`, the Signed Document pill), the preview is
  /// the stored DocuNinja-signed copy, even while the record has unsynced
  /// edits, for as long as the server would still serve it
  /// ([SignedCopyRouteMixin]).
  final bool signedCopy;

  @override
  State<InvoicePdfRouteScreen> createState() => _InvoicePdfRouteScreenState();
}

class _InvoicePdfRouteScreenState extends State<InvoicePdfRouteScreen>
    with FormatterHostMixin, DocumentVersionRouteMixin, SignedCopyRouteMixin {
  late final Services _services;
  late final Stream<Invoice?> _stream;
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
    _stream = _services.invoices.watch(companyId: _companyId, id: widget.id);
    loadFormatter(_services, _companyId);
    initVersions(_services, basePath: _services.invoices.api.basePath);
    initSignedCopy(_services, _companyId, widget.signedCopy);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Invoice?>(
      stream: _stream,
      builder: (context, snapshot) {
        final invoice = snapshot.data;
        if (invoice == null) {
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
          sync: invoice.sync,
          documents: invoice.documents,
        );
        final activityId = selectedActivityId;
        return BillingDocPdfScreen(
          entity: BillingDocType.invoice,
          entityNumber: invoice.number,
          initialDeliveryNote: widget.initialDeliveryNote,
          // A frozen version render has no delivery-note variant.
          deliveryNoteAvailable: activityId == null,
          revision: activityId,
          contentRevision: activityId == null ? invoice : null,
          hasUnsyncedChanges: invoice.isDirty,
          versions: versions,
          selectedActivityId: activityId,
          onVersionChanged: selectVersion,
          formatter: formatter,
          fetcher: activityId == null
              ? ({String? designId, required bool deliveryNote}) =>
                    _services.invoices.api.downloadPdf(
                      entityJson: invoice.toApiJson(),
                      designId:
                          designId ??
                          (invoice.designId.isEmpty ? null : invoice.designId),
                      deliveryNote: deliveryNote,
                      storedPdfKey: signedCopy
                          ? invoice.signedPdfInvitationKey
                          : invoice.storedPdfInvitationKey,
                    )
              : ({String? designId, required bool deliveryNote}) =>
                    _services.documentVersions.downloadVersionPdf(activityId),
        );
      },
    );
  }
}
