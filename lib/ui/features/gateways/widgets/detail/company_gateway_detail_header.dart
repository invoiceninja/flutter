import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_gateway.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_header.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/ui/features/gateways/gateway_order_writer.dart';
import 'package:admin/utils/formatting.dart';

/// Per-entity header for the CompanyGateway record screen. Maps the gateway's
/// domain fields into the shared [EntityDetailHeader] slots.
///
/// **The subtitle is the provider** ("Stripe") whenever the gateway's own
/// label is something else — a company can hold two gateways from one
/// provider, and the label alone does not say which processor is behind it.
///
/// **"Default" and "Test" ride under the subtitle**, where a record's own
/// labels go. They used to be a row *above* the name, which pushed the
/// identity down and read as a banner. The default flag comes from the
/// company's `company_gateway_ids` (first id = default), so [company] is
/// handed in — the screen watches it once for this and the Details card.
class CompanyGatewayDetailHeader extends StatelessWidget {
  const CompanyGatewayDetailHeader({
    super.key,
    required this.gateway,
    required this.company,
    this.formatter,
    this.showStatePills = true,
  });

  final CompanyGateway gateway;

  /// Null while the company row is loading — no Default pill until then.
  final Company? company;
  final Formatter? formatter;

  /// False when the screen is already saying Deleted / Archived in a banner.
  final bool showStatePills;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final statics = context.read<Services>().statics;
    final providerName = statics.gateway(gateway.gatewayKey)?.name;
    final displayName = gateway.resolveDisplayName(gatewayName: providerName);
    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      gateway.createdAt * 1000,
    );
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(
      gateway.updatedAt * 1000,
    );
    final isDefault =
        gateway.id.isNotEmpty &&
        gateway.id == firstGatewayId(company?.settings.companyGatewayIds ?? '');
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
    final showProvider =
        providerName != null &&
        providerName.isNotEmpty &&
        providerName != displayName;
    return EntityDetailHeader(
      seedForAvatar: gateway.id.isEmpty ? displayName : gateway.id,
      displayName: displayName,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isDeleted: gateway.isDeleted,
      isArchived: gateway.archivedAt != 0,
      isDirty: gateway.isDirty,
      formatter: formatter,
      nameMaxLines: 2,
      showStatePills: showStatePills,
      subtitle: showProvider
          ? DetailSubtitle(segments: [Text(providerName)])
          : DetailHeaderTimestamps(
              createdAt: createdAt,
              updatedAt: updatedAt,
              formatter: formatter,
            ),
      tags: pills.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(spacing: 6, runSpacing: 4, children: pills),
            ),
    );
  }
}
