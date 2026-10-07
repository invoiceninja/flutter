import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/activity_note_actions.dart';
import 'package:admin/ui/core/detail/activity_note_buttons.dart';
import 'package:admin/ui/core/detail/build_standard_documents_tab.dart';
import 'package:admin/ui/core/detail/detail_tab_indices.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/entity_record_column.dart';
import 'package:admin/ui/core/detail/entity_state_banner.dart';
import 'package:admin/ui/core/detail/record_screen_controller.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_tab.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_view_model.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_comments_card.dart';
import 'package:admin/ui/features/payments/view_models/payment_detail_view_model.dart';
import 'package:admin/ui/features/payments/widgets/detail/payment_detail_allocations_tab.dart';
import 'package:admin/ui/features/payments/widgets/detail/payment_detail_header.dart';
import 'package:admin/ui/features/payments/widgets/detail/payment_detail_profile.dart';
import 'package:admin/ui/features/payments/widgets/detail/payment_detail_standing.dart';
import 'package:admin/ui/features/payments/widgets/payment_actions.dart';
import 'package:admin/utils/formatting.dart';

/// The payment record screen, on the record layout
/// (`docs/detail-screen-layout.md`): identity, quick actions, standing,
/// comments and the profile above a pinned tab strip.
///
/// The tabs are the payment's own history (Comments, Activity), what it was
/// applied to (Invoices — the landing tab) and its documents. There is no
/// Overview tab any more: its figures are the standing card, and its cards are
/// the profile.
class PaymentDetailScreen extends StatefulWidget {
  const PaymentDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen>
    with FormatterHostMixin {
  late final PaymentDetailViewModel _vm;
  late final Services _services;
  late final String _companyId;
  late final EntityActivityViewModel _activityVm;
  late final RecordScreenController _record;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = PaymentDetailViewModel.bound(
      _services.payments.watch(companyId: _companyId, id: widget.id),
    );
    // Owned here, not by the Activity tab, so the Comments card, the
    // Comments tab and the Activity tab share one fetch. Armed from
    // `bodyBuilder`.
    _activityVm = EntityActivityViewModel(
      api: _services.activities,
      outbox: _services.db.outboxDao,
      companyId: _companyId,
      entityWireName: 'payment',
      entityId: widget.id,
    );
    _record = RecordScreenController(
      services: _services,
      companyId: _companyId,
      routeId: widget.id,
      entityWireName: 'payment',
      refreshRecord: (id) =>
          _services.payments.refreshByIds(companyId: _companyId, ids: [id]),
      hasRecord: () => _vm.item != null,
      refreshWith: [_activityVm.refresh],
    );
    loadFormatter(_services, _companyId);
  }

  @override
  void dispose() {
    _record.dispose();
    _activityVm.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _dispatch(Payment p, PaymentAction action) =>
      PaymentActions.dispatch(context, _services, _companyId, p, action);

  @override
  Widget build(BuildContext context) {
    return EntityDetailScaffold<Payment>(
      id: widget.id,
      vm: _vm,
      hydrate: () =>
          _services.payments.ensureLoaded(companyId: _companyId, id: widget.id),
      emptyAction: entityListEmptyAction(context, EntityType.payment),
      emptyIcon: Icons.payments_outlined,
      emptyTitle: context.tr('payment_not_found'),
      // `p` is captured at item-tap time — a late-arriving stream update
      // can't change which payment gets archived / restored mid-action.
      actionsForItem: (context, p) => EntityDetailActionsRow<PaymentAction>(
        items: PaymentActions.itemsFor(context, p, (a) => _dispatch(p, a)),
      ),
      compactTitleForItem: (context, p) =>
          _CompactTitle(payment: p, formatter: formatter),
      // A deleted payment is read-only until restored.
      isReadOnly: (p) => p.isDeleted,
      onRefresh: _record.refresh,
      bannerForItem: (context, p) => recordStateBanner<PaymentAction>(
        context,
        items: PaymentActions.itemsFor(context, p, (a) => _dispatch(p, a)),
        restoreKind: PaymentAction.restore,
        entityId: p.id,
        isDeleted: p.isDeleted,
        archivedAt: p.archivedAt,
        formatter: formatter,
      ),
      bodyBuilder: (context, p) => _body(context, p),
    );
  }

  Widget _body(BuildContext context, Payment p) {
    _activityVm.kick();
    Future<void> submit(String text) => _services.payments.addComment(
      companyId: _companyId,
      entityId: p.id,
      text: text,
    );
    // Built once here, not in `initState` (`promptLogCallFor` needs a subject
    // off the resolved record) and not twice (the card and the tabs must not
    // each hold their own copy — see `EntityNoteActions`).
    //
    // A deleted payment takes no new notes: the feed stays readable, its
    // buttons go.
    final notes = p.isDeleted
        ? EntityNoteActions.none
        : EntityNoteActions(
            onAddComment: () =>
                promptAddCommentFor(context, entityId: p.id, submit: submit),
            onLogCall: () => promptLogCallFor(
              context,
              companyId: _companyId,
              entityId: p.id,
              subject: p.number.isEmpty ? '' : '#${p.number}',
              clientId: p.clientId,
              submit: submit,
            ),
          );
    _record.attach(recordId: p.id, revision: p.updatedAt);
    final allocations = paymentAllocationsOf(p).length;
    // The tabs own the `TabController`, so they wrap the page and hand back
    // the strip and the body for it to place — which is what lets the strip
    // stay pinned while the page scrolls under it.
    return EntityDetailTabs(
      initialIndex: 2,
      selectTab: _record.selectTab,
      onReveal: _record.page.revealTabs,
      layoutBuilder: (context, strip, body) => _record.buildPage(
        strip: strip,
        body: body,
        top: _top(context, p, notes),
      ),
      tabs: [
        EntityDetailTab(
          id: DetailTabIds.comments,
          label: context.tr('comments'),
          icon: Icons.comment_outlined,
          bodyBuilder: (_) => EntityActivityTab(
            vm: _activityVm,
            formatter: formatter,
            actions: notes,
            commentsOnly: true,
            hostWireName: 'payment',
          ),
        ),
        EntityDetailTab(
          id: DetailTabIds.activity,
          label: context.tr('activity'),
          icon: Icons.history_outlined,
          bodyBuilder: (_) => EntityActivityTab(
            vm: _activityVm,
            formatter: formatter,
            actions: notes,
            hostWireName: 'payment',
          ),
        ),
        EntityDetailTab(
          id: DetailTabIds.invoices,
          // Exact: the allocations ride on the payment's own payload.
          count: allocations,
          label: context.tr('invoices'),
          icon: Icons.receipt_long_outlined,
          bodyBuilder: (_) =>
              PaymentDetailAllocationsTab(payment: p, formatter: formatter),
        ),
        buildStandardDocumentsTab(
          context: context,
          companyId: _companyId,
          entityId: p.id,
          documents: p.documents,
          repo: _services.payments,
          formatter: formatter,
          // A deleted payment lists what it has and takes nothing new.
          readOnly: p.isDeleted,
        ),
      ],
    );
  }

  /// Everything above the tabs. One company watch, hoisted here, feeds the
  /// Details card: which custom-field rows exist depends on the labels the
  /// company has given them.
  Widget _top(BuildContext context, Payment p, EntityNoteActions notes) {
    return WatchBuilder<Company?>(
      cacheKey: _companyId,
      // Seeded from what is already in memory, so the rows that depend on the
      // company (custom-field labels) are there in the first frame rather
      // than arriving a frame late and pushing the tabs down.
      initialData: _services.company.peek(
        companyId: _companyId,
        id: _companyId,
      ),
      create: () => _services.company.watchCompany(_companyId),
      builder: (context, company) => EntityRecordColumn(
        header: PaymentDetailHeader(
          payment: p,
          formatter: formatter,
          // The banner above the page already says Deleted / Archived.
          showStatePills: !p.isDeleted && p.archivedAt == null,
        ),
        quickActions: EntityQuickActions<PaymentAction>(
          priority: PaymentActions.quickItemsFor(
            context,
            p,
            (a) => _dispatch(p, a),
          ),
        ),
        standing: PaymentDetailStanding(
          payment: p,
          formatter: formatter,
          onOpenApplied: () =>
              _record.selectTab.selectId(DetailTabIds.invoices),
        ),
        comments: EntityCommentsCard(
          vm: _activityVm,
          formatter: formatter,
          actions: notes,
          hostWireName: 'payment',
          onViewAll: () => _record.selectTab.select(kCommentsTabIndex),
          matchFormColumn: true,
        ),
        profile: PaymentDetailProfile(
          payment: p,
          company: company.data,
          formatter: formatter,
        ),
      ),
    );
  }
}

/// The payment's number and amount, for the fixed bar once the header has
/// scrolled away.
class _CompactTitle extends StatelessWidget {
  const _CompactTitle({required this.payment, required this.formatter});

  final Payment payment;
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
          payment.number.isEmpty
              ? context.tr('no_name_fallback')
              : '#${payment.number}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: tokens.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          formatter?.money(
                payment.amount,
                clientCurrencyId: payment.currencyId,
              ) ??
              '',
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
