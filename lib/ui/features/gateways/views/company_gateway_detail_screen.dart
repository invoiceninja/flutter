import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_gateway.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/entity_record_column.dart';
import 'package:admin/ui/core/detail/entity_state_banner.dart';
import 'package:admin/ui/core/detail/record_screen_controller.dart';
import 'package:admin/ui/core/detail/settings_record_body.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/gateways/view_models/company_gateway_detail_view_model.dart';
import 'package:admin/ui/features/gateways/widgets/company_gateway_actions.dart';
import 'package:admin/ui/features/gateways/widgets/detail/company_gateway_detail_header.dart';
import 'package:admin/ui/features/gateways/widgets/detail/company_gateway_detail_profile.dart';
import 'package:admin/ui/features/gateways/widgets/detail/company_gateway_system_logs_card.dart';

/// The company-gateway record screen, on the record layout
/// (`docs/detail-screen-layout.md`): identity, quick actions where the
/// provider has any (Stripe), and the profile. No standing card — the server
/// keeps no figure for a gateway — and no tabs.
///
/// Reached only via the Settings sidebar, so the body goes through
/// `SettingsFormShell` (in [SettingsRecordBody]). It used to be a bare scroll
/// view that ran edge to edge, unlike every other settings page.
class CompanyGatewayDetailScreen extends StatefulWidget {
  const CompanyGatewayDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<CompanyGatewayDetailScreen> createState() =>
      _CompanyGatewayDetailScreenState();
}

class _CompanyGatewayDetailScreenState extends State<CompanyGatewayDetailScreen>
    with FormatterHostMixin {
  late final CompanyGatewayDetailViewModel _vm;
  late final RecordScreenController _record;
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
    _record = RecordScreenController(
      services: _services,
      companyId: _companyId,
      routeId: widget.id,
      entityWireName: 'company_gateway',
      // Gateways are bundled reference data: the repository has no by-id
      // re-fetch (this is the base no-op), so opening one asks the server
      // nothing…
      refreshRecord: (id) => _services.companyGateways.refreshByIds(
        companyId: _companyId,
        ids: [id],
      ),
      hasRecord: () => _vm.item != null,
      // …and a pull or `R` runs what the list's own refresh runs — the delta
      // of a table that is a handful of rows — plus the logs under the card.
      refreshWith: [_refreshGateways, _refreshLogs],
    );
    loadFormatter(_services, _companyId);
  }

  Future<void> _refreshGateways() async {
    if (!_record.mayRefreshRecord) return;
    await _services.companyGateways.refreshAll(companyId: _companyId);
  }

  /// The System Logs card reads a company-wide cache that only admins and
  /// owners may fetch (the endpoint is a 403 for anyone else).
  Future<void> _refreshLogs() async {
    if (!_record.mayRefreshRecord) return;
    final me = _services.auth.session.value?.currentCompany;
    if (!((me?.isAdmin ?? false) || (me?.isOwner ?? false))) return;
    await _services.systemLogs.refresh(_companyId);
  }

  @override
  void dispose() {
    _record.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _dispatch(CompanyGateway gateway, CompanyGatewayAction action) =>
      CompanyGatewayActions.dispatch(
        context,
        _services,
        _companyId,
        gateway,
        action,
      );

  /// A gateway's timestamps are epoch seconds, with 0 for "never".
  static DateTime? _archivedAt(CompanyGateway g) => g.archivedAt == 0
      ? null
      : DateTime.fromMillisecondsSinceEpoch(g.archivedAt * 1000, isUtc: true);

  @override
  Widget build(BuildContext context) {
    return EntityDetailScaffold<CompanyGateway>(
      id: widget.id,
      vm: _vm,
      hydrate: () => _services.companyGateways.ensureLoaded(
        companyId: _companyId,
        id: widget.id,
      ),
      emptyAction: entityListEmptyAction(context, EntityType.companyGateway),
      emptyIcon: Icons.account_balance_wallet_outlined,
      emptyTitle: context.tr('company_gateway'),
      actionsForItem: (context, g) =>
          EntityDetailActionsRow<CompanyGatewayAction>(
            items: CompanyGatewayActions.itemsFor(
              context,
              g,
              (a) => _dispatch(g, a),
            ),
          ),
      compactTitleForItem: (context, g) => _CompactTitle(gateway: g),
      // A deleted gateway is read-only until restored.
      isReadOnly: (g) => g.isDeleted,
      onRefresh: _record.refresh,
      bannerForItem: (context, g) => recordStateBanner<CompanyGatewayAction>(
        context,
        items: CompanyGatewayActions.itemsFor(
          context,
          g,
          (a) => _dispatch(g, a),
        ),
        restoreKind: CompanyGatewayAction.restore,
        entityId: g.id,
        isDeleted: g.isDeleted,
        archivedAt: _archivedAt(g),
        formatter: formatter,
      ),
      bodyBuilder: (context, g) {
        _record.attach(recordId: g.id, revision: g.updatedAt);
        final archived = g.archivedAt != 0;
        // One company watch, hoisted here: the header's Default pill and the
        // Details card's webhook URL both come from the company row.
        return WatchBuilder<Company?>(
          cacheKey: _companyId,
          // Seeded, so the Default pill and the rows that depend on the
          // company are there in the first frame.
          initialData: _services.company.peek(
            companyId: _companyId,
            id: _companyId,
          ),
          create: () => _services.company.watchCompany(_companyId),
          builder: (context, company) => SettingsRecordBody(
            onRefresh: _record.refresh,
            child: EntityRecordColumn(
              header: CompanyGatewayDetailHeader(
                gateway: g,
                company: company.data,
                formatter: formatter,
                // The banner above the page already says Deleted / Archived.
                showStatePills: !g.isDeleted && !archived,
              ),
              quickActions: EntityQuickActions<CompanyGatewayAction>(
                priority: CompanyGatewayActions.quickItemsFor(
                  context,
                  g,
                  (a) => _dispatch(g, a),
                ),
              ),
              profile: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  CompanyGatewayDetailProfile(
                    gateway: g,
                    company: company.data,
                    formatter: formatter,
                  ),
                  // Owns its leading gap — it builds nothing for a user who
                  // may not read the logs, or a provider that writes none.
                  CompanyGatewaySystemLogsCard(
                    gateway: g,
                    companyId: _companyId,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The gateway's name, for the fixed bar once the header has scrolled away.
class _CompactTitle extends StatelessWidget {
  const _CompactTitle({required this.gateway});

  final CompanyGateway gateway;

  @override
  Widget build(BuildContext context) {
    final provider = context
        .read<Services>()
        .statics
        .gateway(gateway.gatewayKey)
        ?.name;
    return Text(
      gateway.resolveDisplayName(gatewayName: provider),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: context.inTheme.ink,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
