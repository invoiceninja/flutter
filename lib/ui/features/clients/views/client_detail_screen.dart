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
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_view_model.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_comments_card.dart';
import 'package:admin/domain/phone/phone_candidates.dart';
import 'package:admin/ui/core/detail/activity_note_actions.dart';
import 'package:admin/ui/core/detail/activity_note_buttons.dart';
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
  late final EntityActivityViewModel _activityVm;
  late final Services _services;
  late final String _companyId;
  final TabSelectionController _selectTab = TabSelectionController();

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
    // Owned here, not by the Activity tab, so the Comments card, the Comments
    // tab and the Activity tab share one fetch. Armed from `bodyBuilder`.
    _activityVm = EntityActivityViewModel(
      api: _services.activities,
      outbox: _services.db.outboxDao,
      companyId: _companyId,
      entityWireName: 'client',
      entityId: widget.id,
    );
    loadFormatter(_services, _companyId);
  }

  @override
  void dispose() {
    _activityVm.dispose();
    _selectTab.dispose();
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EntityDetailScaffold<Client>(
      id: widget.id,
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
      bodyBuilder: (context, c) => _body(context, c),
    );
  }

  Widget _body(BuildContext context, Client c) {
    _activityVm.kick();
    Future<void> submit(String text) => _services.clients.addComment(
      companyId: _companyId,
      clientId: c.id,
      text: text,
    );
    // Built once here, not in `initState` (`promptLogCallFor` needs a subject
    // and phone candidates off the resolved record) and not twice (the card and
    // the tabs must not each hold their own copy — see `EntityNoteActions`).
    final notes = EntityNoteActions(
      onAddComment: () =>
          promptAddCommentFor(context, entityId: c.id, submit: submit),
      onLogCall: () => promptLogCallFor(
        context,
        companyId: _companyId,
        entityId: c.id,
        subject: c.displayName,
        candidates: clientPhoneCandidates(c),
        submit: submit,
      ),
    );
    return SingleChildScrollView(
      controller: DetailScrollScope.maybeOf(context),
      padding: EdgeInsets.all(InSpacing.lg(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClientDetailHeader(client: c, formatter: formatter),
          const SizedBox(height: InSpacing.xl),
          ClientDetailKpiStrip(client: c, formatter: formatter),
          SizedBox(height: InSpacing.lg(context)),
          EntityCommentsCard(
            vm: _activityVm,
            formatter: formatter,
            actions: notes,
            hostWireName: 'client',
            onViewAll: () => _selectTab.select(0),
            matchFormColumn: true,
          ),
          ClientDetailCardsGrid(client: c, formatter: formatter),
          const SizedBox(height: InSpacing.xl),
          ClientDetailTabs(
            client: c,
            formatter: formatter,
            activityVm: _activityVm,
            selectTab: _selectTab,
            notes: notes,
          ),
        ],
      ),
    );
  }
}
