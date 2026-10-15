import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/domain/billing/peppol_sending_status.dart';
import 'package:admin/l10n/localization.dart';

/// Whether the active company sends by PEPPOL, for the list rows below it.
///
/// Provided by the invoice and credit lists around each row, from the list
/// view model's company stream, so a row never reads the company itself —
/// the same shape as `InventoryScope` on the products list. Absent means no.
class PeppolStatusScope extends InheritedWidget {
  const PeppolStatusScope({
    super.key,
    required this.companyUsesPeppol,
    required super.child,
  });

  final bool companyUsesPeppol;

  static bool usesPeppol(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<PeppolStatusScope>()
          ?.companyUsesPeppol ??
      false;

  @override
  bool updateShouldNotify(PeppolStatusScope oldWidget) =>
      companyUsesPeppol != oldWidget.companyUsesPeppol;
}

/// The PEPPOL sent (green paper plane) or failed (red warning) mark beside a
/// list row's status pill — React ui#3410. Renders nothing unless the
/// [PeppolStatusScope] says the company sends by PEPPOL, the user hasn't
/// hidden it (Device Settings → E-Invoice), and [peppolSendingStatus] has
/// something to say about this document and its client.
///
/// Not a control: a list row and a table cell each already have exactly one
/// destination, so unlike React's failed mark it opens nothing. The hover
/// text is manual-triggered so it can't take the row's long press.
class PeppolStatusIcon extends StatefulWidget {
  const PeppolStatusIcon({
    super.key,
    required this.clientId,
    required this.backup,
    required this.isDraft,
    required this.isDeleted,
    required this.isArchived,
    this.padding = EdgeInsets.zero,
  });

  final String clientId;

  /// Around the mark only, so a row with no mark keeps no gap for it.
  final EdgeInsetsGeometry padding;

  /// The document's raw `backup` map; `guid` is the delivery reference.
  final Map<String, dynamic>? backup;
  final bool isDraft;
  final bool isDeleted;
  final bool isArchived;

  @override
  State<PeppolStatusIcon> createState() => _PeppolStatusIconState();
}

class _PeppolStatusIconState extends State<PeppolStatusIcon> {
  String? _ensuredFor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureClient();
  }

  @override
  void didUpdateWidget(PeppolStatusIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureClient();
  }

  /// The client's country decides whether there is a mark at all, and a list
  /// page doesn't bring its clients — so hydrate it, as `ClientNameLabel`
  /// does. Only for a PEPPOL company: everyone else never needs it.
  void _ensureClient() {
    final id = widget.clientId;
    if (id.isEmpty || id == _ensuredFor) return;
    if (!PeppolStatusScope.usesPeppol(context)) return;
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) return;
    _ensuredFor = id;
    services.clients.ensureLoaded(companyId: companyId, id: id);
  }

  @override
  Widget build(BuildContext context) {
    if (!PeppolStatusScope.usesPeppol(context) || widget.clientId.isEmpty) {
      return const SizedBox.shrink();
    }
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<bool>(
      valueListenable: services.hidePeppolStatus,
      builder: (context, hidden, _) {
        if (hidden) return const SizedBox.shrink();
        // Per-cell, like `ClientNameLabel`: drift shares one query per client
        // across every row that watches it.
        return StreamBuilder<Client?>(
          initialData: services.clients.peek(
            companyId: companyId,
            id: widget.clientId,
          ),
          stream: services.clients.watch(
            companyId: companyId,
            id: widget.clientId,
          ),
          builder: (context, snapshot) {
            final client = snapshot.data;
            final status = peppolSendingStatus(
              companyUsesPeppol: true,
              clientCountryId: client?.countryId,
              clientClassification: client?.classification ?? '',
              guid: peppolGuidOf(widget.backup),
              isDraft: widget.isDraft,
              isDeleted: widget.isDeleted,
              isArchived: widget.isArchived,
            );
            return status == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: widget.padding,
                    child: PeppolStatusMark(status: status),
                  );
          },
        );
      },
    );
  }
}

/// The mark itself, for a known [status].
class PeppolStatusMark extends StatelessWidget {
  const PeppolStatusMark({super.key, required this.status});

  final PeppolSendingStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final message = context.tr(switch (status) {
      PeppolSendingStatus.sent => 'peppol_sending_success',
      PeppolSendingStatus.failed => 'peppol_sending_failed',
    });
    final icon = switch (status) {
      // React's tilted paper plane.
      PeppolSendingStatus.sent => Transform.rotate(
        angle: -math.pi / 4,
        child: Icon(Icons.send, size: 15, color: tokens.paid),
      ),
      PeppolSendingStatus.failed => Icon(
        Icons.warning_amber_rounded,
        size: 16,
        color: tokens.overdue,
      ),
    };
    return Semantics(
      label: message,
      child: Tooltip(
        message: message,
        excludeFromSemantics: true,
        triggerMode: TooltipTriggerMode.manual,
        child: icon,
      ),
    );
  }
}
