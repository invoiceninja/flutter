import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company_gateway.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';

/// Read-only gateway display on the payment detail Overview tab. The gateway
/// is assigned by the payment processor and is never user-editable (see
/// `PaymentEditLayout`); this surfaces it for reference, matching the legacy
/// Flutter app's payment view. The caller gates on a non-empty
/// `companyGatewayId`, so this only renders for gateway-processed payments.
///
/// Name resolution mirrors the refund screen's lookup: company gateway →
/// `gatewayKey` → the statics `Gateway.name`, falling back to the gateway's
/// own label or id.
class PaymentDetailGatewayCard extends StatelessWidget {
  const PaymentDetailGatewayCard({
    super.key,
    required this.companyId,
    required this.companyGatewayId,
  });

  final String companyId;
  final String companyGatewayId;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    return WatchBuilder<CompanyGateway?>(
      cacheKey: (companyId, companyGatewayId),
      create: () => services.companyGateways.watch(
        companyId: companyId,
        id: companyGatewayId,
      ),
      builder: (context, snapshot) {
        final gateway = snapshot.data;
        final staticName =
            services.statics.gateways[gateway?.gatewayKey]?.name ?? '';
        final name = staticName.isNotEmpty
            ? staticName
            : ((gateway?.label.isNotEmpty ?? false)
                  ? gateway!.label
                  : companyGatewayId);
        return DashboardCardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr('gateway').toUpperCase(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.ink3,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: tokens.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
