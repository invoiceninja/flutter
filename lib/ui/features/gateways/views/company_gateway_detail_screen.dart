import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company_gateway.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/features/gateways/view_models/company_gateway_detail_view_model.dart';
import 'package:admin/ui/features/gateways/widgets/detail/company_gateway_detail_actions_row.dart';
import 'package:admin/ui/features/gateways/widgets/detail/company_gateway_detail_cards.dart';
import 'package:admin/ui/features/gateways/widgets/detail/company_gateway_detail_header.dart';
import 'package:admin/ui/features/gateways/widgets/detail/company_gateway_system_logs_card.dart';

/// Read-only CompanyGateway detail screen — mirrors `ProjectDetailScreen` and
/// uses the standard `EntityDetailScaffold` for chrome.
class CompanyGatewayDetailScreen extends StatefulWidget {
  const CompanyGatewayDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<CompanyGatewayDetailScreen> createState() =>
      _CompanyGatewayDetailScreenState();
}

class _CompanyGatewayDetailScreenState
    extends State<CompanyGatewayDetailScreen> {
  late final CompanyGatewayDetailViewModel _vm;
  late final Services _services;
  late final String _companyId;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = CompanyGatewayDetailViewModel.bound(
      _services.companyGateways.watch(companyId: _companyId, id: widget.id),
    );
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EntityDetailScaffold<CompanyGateway>(
      vm: _vm,
      hydrate: () => _services.companyGateways.ensureLoaded(
        companyId: _companyId,
        id: widget.id,
      ),
      emptyAction: entityListEmptyAction(context, EntityType.companyGateway),
      emptyIcon: Icons.account_balance_wallet_outlined,
      emptyTitle: context.tr('company_gateway'),
      actionsForItem: (context, gateway) =>
          CompanyGatewayDetailActionsRow(gateway: gateway),
      bodyBuilder: (context, gateway) => SingleChildScrollView(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CompanyGatewayDetailHeader(gateway: gateway, companyId: _companyId),
            const SizedBox(height: InSpacing.xl),
            CompanyGatewayDetailCardsGrid(
              gateway: gateway,
              companyId: _companyId,
            ),
            CompanyGatewaySystemLogsCard(
              gateway: gateway,
              companyId: _companyId,
            ),
          ],
        ),
      ),
    );
  }
}
