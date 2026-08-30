import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/detail_scroll_scope.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/features/clients/view_models/client_detail_view_model.dart';
import 'package:admin/ui/features/clients/widgets/client_actions.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_cards_grid.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_header.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_kpi_strip.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_tabs.dart';

class ClientDetailScreen extends StatefulWidget {
  const ClientDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen>
    with FormatterHostMixin {
  late final ClientDetailViewModel _vm;
  late final Services _services;
  late final String _companyId;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = ClientDetailViewModel(
      repo: _services.clients,
      companyId: _companyId,
      id: widget.id,
    );
    loadFormatter(_services, _companyId);
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EntityDetailScaffold<Client>(
      vm: _vm,
      hydrate: () =>
          _services.clients.ensureLoaded(companyId: _companyId, id: widget.id),
      emptyAction: entityListEmptyAction(context, EntityType.client),
      emptyIcon: Icons.person_off_outlined,
      emptyTitle: context.tr('client_not_found'),
      emptySubtitle: context.tr('client_not_found_subtitle'),
      // `c` is captured at item-tap time — a late-arriving stream update
      // can't change which client gets archived/restored mid-action.
      actionsForItem: (context, c) => EntityDetailActionsRow<ClientAction>(
        items: ClientActions.itemsFor(
          context,
          c,
          (a) => ClientActions.dispatch(context, _services, _companyId, c, a),
        ),
      ),
      bodyBuilder: (context, c) => SingleChildScrollView(
        controller: DetailScrollScope.maybeOf(context),
        padding: EdgeInsets.all(InSpacing.lg(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClientDetailHeader(client: c, formatter: formatter),
            const SizedBox(height: InSpacing.xl),
            ClientDetailKpiStrip(client: c, formatter: formatter),
            SizedBox(height: InSpacing.lg(context)),
            ClientDetailCardsGrid(client: c, formatter: formatter),
            const SizedBox(height: InSpacing.xl),
            ClientDetailTabs(client: c, formatter: formatter),
          ],
        ),
      ),
    );
  }
}
