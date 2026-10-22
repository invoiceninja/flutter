import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/company_repository.dart'
    show kCompanyWireName;
import 'package:admin/ui/features/settings/views/advanced/client_portal/widgets/portal_url_display.dart';

/// A portal URL row whose QR code is offered only for the address the server
/// holds.
///
/// [url] follows the settings draft, so the text previews an address as it is
/// typed. The QR code is what gets printed, so it waits until the address is
/// confirmed: [url] equals [savedUrl] (built from the saved company — nothing
/// edited since the last save) and the company has no change in the outbox
/// the server has not accepted. A hosted subdomain that is already taken
/// saves locally, then 422s; until then — and for as long as the rejected row
/// stays dead — the local row carries it. A code printed from it would lead
/// to another company's portal. → docs/client-portal-urls.md
class ConfirmedPortalUrlDisplay extends StatefulWidget {
  const ConfirmedPortalUrlDisplay({
    super.key,
    required this.companyId,
    required this.label,
    required this.url,
    required this.savedUrl,
  });

  final String companyId;
  final String label;

  /// The address the draft resolves to.
  final String url;

  /// The address the saved company resolves to, or `''` when it has none.
  final String savedUrl;

  @override
  State<ConfirmedPortalUrlDisplay> createState() =>
      _ConfirmedPortalUrlDisplayState();
}

class _ConfirmedPortalUrlDisplayState extends State<ConfirmedPortalUrlDisplay> {
  // Hoisted: a stream built in `build` re-subscribes on every rebuild, and a
  // keystroke in the domain field rebuilds this row.
  late Stream<bool> _unaccepted;

  @override
  void initState() {
    super.initState();
    _unaccepted = _watch();
  }

  @override
  void didUpdateWidget(ConfirmedPortalUrlDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) _unaccepted = _watch();
  }

  Stream<bool> _watch() =>
      context.read<Services>().db.outboxDao.watchHasUnacceptedRecordEdit(
        companyId: widget.companyId,
        entityType: kCompanyWireName,
        entityId: widget.companyId,
      );

  @override
  Widget build(BuildContext context) => StreamBuilder<bool>(
    stream: _unaccepted,
    builder: (context, snapshot) {
      final unaccepted = snapshot.data;
      final unsaved = widget.url != widget.savedUrl;
      final confirmed = !unsaved && unaccepted == false;
      return PortalUrlDisplay(
        label: widget.label,
        url: widget.url,
        showQrCode: confirmed,
        // Before the outbox has answered nothing is known yet, so the QR
        // waits without a notice rather than flashing one.
        qrCodeAfterSync: unsaved || unaccepted == true,
      );
    },
  );
}
