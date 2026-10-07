import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/payment_link.dart';
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
import 'package:admin/ui/features/payment_links/view_models/payment_link_detail_view_model.dart';
import 'package:admin/ui/features/payment_links/widgets/detail/payment_link_detail_header.dart';
import 'package:admin/ui/features/payment_links/widgets/detail/payment_link_detail_profile.dart';
import 'package:admin/ui/features/payment_links/widgets/detail/payment_link_detail_standing.dart';
import 'package:admin/ui/features/payment_links/widgets/payment_link_actions.dart';
import 'package:admin/utils/formatting.dart';

/// The Payment Link record screen, on the record layout
/// (`docs/detail-screen-layout.md`): identity, quick actions (copy or open the
/// purchase page, clone), the price as its standing, and the profile —
/// Details, then the invoices and recurring invoices the link has produced.
/// No tabs.
///
/// Reached only via the Settings sidebar, so the body goes through
/// `SettingsFormShell` (in [SettingsRecordBody]) and its width matches every
/// other settings page.
class PaymentLinkDetailScreen extends StatefulWidget {
  const PaymentLinkDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<PaymentLinkDetailScreen> createState() =>
      _PaymentLinkDetailScreenState();
}

class _PaymentLinkDetailScreenState extends State<PaymentLinkDetailScreen>
    with FormatterHostMixin {
  late final PaymentLinkDetailViewModel _vm;
  late final RecordScreenController _record;
  late final Services _services;
  late final String _companyId;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = PaymentLinkDetailViewModel.bound(
      _services.paymentLinks.watch(companyId: _companyId, id: widget.id),
    );
    _record = RecordScreenController(
      services: _services,
      companyId: _companyId,
      routeId: widget.id,
      entityWireName: 'payment_link',
      // Payment links are bundled reference data: the repository has no
      // by-id re-fetch (this is the base no-op), so opening one asks the
      // server nothing…
      refreshRecord: (id) =>
          _services.paymentLinks.refreshByIds(companyId: _companyId, ids: [id]),
      hasRecord: () => _vm.item != null,
      // …and a pull or `R` runs what the list's own refresh runs: the delta
      // of a table that is a handful of rows.
      refreshWith: [_refreshLinks],
    );
    loadFormatter(_services, _companyId);
  }

  Future<void> _refreshLinks() async {
    if (!_record.mayRefreshRecord) return;
    await _services.paymentLinks.refreshAll(companyId: _companyId);
  }

  @override
  void dispose() {
    _record.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _dispatch(PaymentLink link, PaymentLinkAction action) =>
      PaymentLinkActions.dispatch(context, _services, _companyId, link, action);

  @override
  Widget build(BuildContext context) {
    return EntityDetailScaffold<PaymentLink>(
      id: widget.id,
      vm: _vm,
      hydrate: () => _services.paymentLinks.ensureLoaded(
        companyId: _companyId,
        id: widget.id,
      ),
      emptyAction: entityListEmptyAction(context, EntityType.paymentLink),
      emptyIcon: Icons.link_outlined,
      emptyTitle: context.tr('payment_link'),
      actionsForItem: (context, link) =>
          EntityDetailActionsRow<PaymentLinkAction>(
            items: PaymentLinkActions.itemsFor(
              context,
              link,
              (a) => _dispatch(link, a),
            ),
          ),
      compactTitleForItem: (context, link) =>
          _CompactTitle(paymentLink: link, formatter: formatter),
      // A deleted link is read-only until restored.
      isReadOnly: (link) => link.isDeleted,
      onRefresh: _record.refresh,
      bannerForItem: (context, link) => recordStateBanner<PaymentLinkAction>(
        context,
        items: PaymentLinkActions.itemsFor(
          context,
          link,
          (a) => _dispatch(link, a),
        ),
        restoreKind: PaymentLinkAction.restore,
        entityId: link.id,
        isDeleted: link.isDeleted,
        archivedAt: link.archivedAt,
        formatter: formatter,
      ),
      bodyBuilder: (context, link) {
        _record.attach(recordId: link.id, revision: link.updatedAt);
        return SettingsRecordBody(
          onRefresh: _record.refresh,
          child: EntityRecordColumn(
            header: PaymentLinkDetailHeader(
              paymentLink: link,
              formatter: formatter,
              // The banner above the page already says Deleted / Archived.
              showStatePills: !link.isDeleted && link.archivedAt == null,
            ),
            quickActions: EntityQuickActions<PaymentLinkAction>(
              priority: PaymentLinkActions.quickItemsFor(
                context,
                link,
                (a) => _dispatch(link, a),
              ),
            ),
            standing: PaymentLinkDetailStanding(
              paymentLink: link,
              formatter: formatter,
            ),
            profile: PaymentLinkDetailProfile(
              paymentLink: link,
              companyId: _companyId,
              formatter: formatter,
            ),
          ),
        );
      },
    );
  }
}

/// The link's name and price, for the fixed bar once the header has scrolled
/// away.
class _CompactTitle extends StatelessWidget {
  const _CompactTitle({required this.paymentLink, required this.formatter});

  final PaymentLink paymentLink;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          paymentLink.name.isEmpty
              ? context.tr('no_name_fallback')
              : paymentLink.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: tokens.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          PaymentLinkDetailStanding.priceText(paymentLink, formatter),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: tokens.ink2)
              .merge(moneyTextStyle()),
        ),
      ],
    );
  }
}
