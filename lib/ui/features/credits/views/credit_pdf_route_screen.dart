import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/credit.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/history/document_version_route_mixin.dart';
import 'package:admin/ui/features/billing_shared/pdf/billing_doc_pdf_screen.dart';

/// Route wrapper for `/credits/:id/pdf`. Mirrors `QuotePdfRouteScreen`.
class CreditPdfRouteScreen extends StatefulWidget {
  const CreditPdfRouteScreen({super.key, required this.id, this.activityId});
  final String id;

  /// When set (route `?activity_id=`), the preview opens on that saved
  /// version rather than the live document.
  final String? activityId;

  @override
  State<CreditPdfRouteScreen> createState() => _CreditPdfRouteScreenState();
}

class _CreditPdfRouteScreenState extends State<CreditPdfRouteScreen>
    with FormatterHostMixin, DocumentVersionRouteMixin {
  late final Services _services;
  late final Stream<Credit?> _stream;
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
    _stream = _services.credits.watch(companyId: _companyId, id: widget.id);
    loadFormatter(_services, _companyId);
    initVersions(_services, basePath: _services.credits.api.basePath);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Credit?>(
      stream: _stream,
      builder: (context, snapshot) {
        final credit = snapshot.data;
        if (credit == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final activityId = selectedActivityId;
        return BillingDocPdfScreen(
          entity: BillingDocType.credit,
          entityNumber: credit.number,
          // A frozen version render has no delivery-note variant.
          deliveryNoteAvailable: activityId == null,
          revision: activityId,
          autoRefreshDebounce: Duration.zero,
          versions: versions,
          selectedActivityId: activityId,
          onVersionChanged: selectVersion,
          formatter: formatter,
          fetcher: activityId == null
              ? ({String? designId, required bool deliveryNote}) =>
                    _services.credits.api.downloadPdf(
                      entityJson: credit.toApiJson(),
                      designId:
                          designId ??
                          (credit.designId.isEmpty ? null : credit.designId),
                    )
              : ({String? designId, required bool deliveryNote}) =>
                    _services.documentVersions.downloadVersionPdf(activityId),
        );
      },
    );
  }
}
