import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_gateway.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_header.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/gateways/gateway_order_writer.dart';
import 'package:admin/utils/formatting.dart';

/// Per-entity header for the CompanyGateway detail screen. Maps the
/// gateway's domain fields into the shared `EntityDetailHeader` slots; the
/// "Default" + "Test-mode" pills render as a Row sibling above the header so
/// users can see them at-a-glance.
class CompanyGatewayDetailHeader extends StatelessWidget {
  const CompanyGatewayDetailHeader({
    super.key,
    required this.gateway,
    required this.companyId,
    this.formatter,
  });

  final CompanyGateway gateway;
  final String companyId;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final statics = context.read<Services>().statics;
    final providerName = statics.gateway(gateway.gatewayKey)?.name;
    final displayName = gateway.resolveDisplayName(gatewayName: providerName);
    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      gateway.createdAt * 1000,
    );
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(
      gateway.updatedAt * 1000,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _pills(context),
        EntityDetailHeader(
          seedForAvatar: gateway.id.isEmpty ? displayName : gateway.id,
          displayName: displayName,
          number: providerName != null && providerName != displayName
              ? providerName
              : null,
          createdAt: createdAt,
          updatedAt: updatedAt,
          isDeleted: gateway.isDeleted,
          isArchived: gateway.archivedAt != 0,
          isDirty: gateway.isDirty,
          formatter: formatter,
        ),
      ],
    );
  }

  /// "Default" + "Test" pills above the header. The default flag comes from
  /// the company's `company_gateway_ids` (first id = default), so it's watched
  /// rather than passed in.
  Widget _pills(BuildContext context) {
    final services = context.read<Services>();
    final tokens = context.inTheme;
    return WatchBuilder<Company?>(
      cacheKey: companyId,
      create: () => services.company.watchCompany(companyId),
      builder: (context, snap) {
        final csv = snap.data?.settings.companyGatewayIds ?? '';
        final isDefault =
            gateway.id.isNotEmpty && gateway.id == firstGatewayId(csv);
        final pills = <Widget>[
          if (isDefault)
            StatusPill(
              label: context.tr('default'),
              fgColor: tokens.accent,
              bgColor: tokens.accentSoft,
            ),
          if (gateway.testMode)
            StatusPill(
              label: context.tr('test'),
              fgColor: tokens.sent,
              bgColor: tokens.sentSoft,
            ),
        ];
        if (pills.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.only(bottom: InSpacing.md(context)),
          child: Wrap(spacing: 6, runSpacing: 4, children: pills),
        );
      },
    );
  }
}
