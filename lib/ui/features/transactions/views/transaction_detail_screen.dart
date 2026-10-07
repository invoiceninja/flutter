import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/bank_transaction.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/detail_scroll_scope.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/entity_record_column.dart';
import 'package:admin/ui/core/detail/entity_state_banner.dart';
import 'package:admin/ui/core/detail/generic_detail_view_model.dart';
import 'package:admin/ui/core/detail/record_screen_controller.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/core/widgets/bank_account_name_label.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/transactions/widgets/detail/transaction_detail_header.dart';
import 'package:admin/ui/features/transactions/widgets/detail/transaction_detail_profile.dart';
import 'package:admin/ui/features/transactions/widgets/detail/transaction_detail_standing.dart';
import 'package:admin/ui/features/transactions/widgets/transaction_actions.dart';
import 'package:admin/ui/features/transactions/widgets/transaction_match_panel.dart';
import 'package:admin/utils/formatting.dart';

/// The bank-transaction record screen, on the record layout
/// (`docs/detail-screen-layout.md`): identity, quick actions (Convert /
/// Unlink, when there is a match to act on), the amount and status as its
/// standing, then Details, what it is linked to, and — while it still needs
/// accounting for — the match panel.
///
/// No page tabs: the match panel has two of its own (create / link), and they
/// are a form, not a list that needs a pinned strip.
class TransactionDetailScreen extends StatefulWidget {
  const TransactionDetailScreen({required this.id, super.key});

  final String id;

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen>
    with FormatterHostMixin {
  late final GenericDetailViewModel<BankTransaction> _vm;
  late final RecordScreenController _record;
  late final Services _services;
  late final String _companyId;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = GenericDetailViewModel<BankTransaction>.bound(
      _services.bankTransactions.watch(companyId: _companyId, id: widget.id),
    );
    _record = RecordScreenController(
      services: _services,
      companyId: _companyId,
      routeId: widget.id,
      entityWireName: 'bank_transaction',
      // By id, never `refreshAll`: the table is far too large to sweep for
      // one record. A match made on another device shows up on open.
      refreshRecord: (id) => _services.bankTransactions.refreshByIds(
        companyId: _companyId,
        ids: [id],
      ),
      hasRecord: () => _vm.item != null,
    );
    loadFormatter(_services, _companyId);
  }

  @override
  void dispose() {
    _record.dispose();
    _vm.dispose();
    super.dispose();
  }

  /// Converts [tx] and, beside the list on a wide layout, moves straight on
  /// to the next transaction that still needs converting — or closes the
  /// pane when none is left (React #3396). Reconciling a statement is a
  /// sequence, and stopping on a row that is now done made every step a
  /// round trip through the list.
  ///
  /// The list is read BEFORE converting: on a status-filtered list (the
  /// Unmatched tab) the conversion can drop this very row, and its position
  /// is what "next" is measured from. Rows with a conversion still in the
  /// outbox are skipped too — their status only changes once it syncs, so
  /// offline they would otherwise all still read as unconverted.
  ///
  /// The toast is raised before navigating, with a View action back to the
  /// transaction just converted, so moving on never hides what happened.
  /// Narrow layouts have no list beside the detail, so they stay put.
  Future<void> _runConversion(
    BuildContext context,
    BankTransaction tx,
    Future<void> Function() convert,
    String successKey,
  ) async {
    final wide = MasterDetailPaneScope.paneActionsOf(context) != null;
    final nav = wide ? MasterDetailNavScope.maybeOf(context) : null;
    final ids = List<String>.of(nav?.itemIds ?? const <String>[]);
    final items = List<Object?>.of(nav?.items ?? const <Object?>[]);
    final router = GoRouter.of(context);
    final here = GoRouterState.of(context).uri.toString();

    await convert();
    if (!context.mounted) return;

    final message = context.tr(successKey);
    final from = ids.indexOf(tx.id);
    if (nav == null || from < 0) {
      Notify.success(context, message);
      return;
    }
    final pending = await _pendingConversionIds();
    if (!context.mounted) return;
    String? next;
    for (var i = from + 1; i < ids.length; i++) {
      final item = i < items.length ? items[i] : null;
      if (item is BankTransaction &&
          (item.isUnmatched || item.isMatched) &&
          !pending.contains(item.id)) {
        next = item.id;
        break;
      }
    }
    Notify.success(
      context,
      message,
      action: NotifyAction(context.tr('view'), () => router.go(here)),
    );
    if (next != null) {
      goEntityRecord(context, EntityType.transaction, next);
    } else {
      MasterDetailNavScope.requestClose(context, basePath: '/transactions');
    }
  }

  /// Transactions with a conversion queued but not yet answered.
  Future<Set<String>> _pendingConversionIds() async {
    final rows = await _services.db.outboxDao.watchAll(_companyId).first;
    return {
      for (final r in rows)
        if (r.entityType == 'bank_transaction' &&
            r.state != 'dead' &&
            const {
              'match_to_payment',
              'link_to_payment',
              'match_to_expense',
              'link_to_expense',
            }.contains(r.mutationKind))
          r.entityId,
    };
  }

  void _dispatch(BankTransaction tx, TransactionAction action) =>
      TransactionActions.dispatch(context, _services, _companyId, tx, action);

  @override
  Widget build(BuildContext context) {
    return EntityDetailScaffold<BankTransaction>(
      id: widget.id,
      vm: _vm,
      hydrate: () => _services.bankTransactions.ensureLoaded(
        companyId: _companyId,
        id: widget.id,
      ),
      emptyAction: entityListEmptyAction(context, EntityType.transaction),
      emptyIcon: Icons.swap_horiz,
      emptyTitle: context.tr('transaction_not_found'),
      // `tx` is captured at item-tap time — a late-arriving stream update
      // can't change which transaction gets archived / restored mid-action.
      actionsForItem: (context, tx) =>
          EntityDetailActionsRow<TransactionAction>(
            items: TransactionActions.itemsFor(
              context,
              tx,
              (a) => _dispatch(tx, a),
            ),
          ),
      compactTitleForItem: (context, tx) =>
          _CompactTitle(transaction: tx, formatter: formatter),
      // A deleted transaction is read-only until restored.
      isReadOnly: (tx) => tx.isDeleted,
      onRefresh: _record.refresh,
      bannerForItem: (context, tx) => recordStateBanner<TransactionAction>(
        context,
        items: TransactionActions.itemsFor(
          context,
          tx,
          (a) => _dispatch(tx, a),
        ),
        restoreKind: TransactionAction.restore,
        entityId: tx.id,
        isDeleted: tx.isDeleted,
        archivedAt: tx.archivedAt,
        formatter: formatter,
      ),
      bodyBuilder: (context, tx) {
        _record.attach(recordId: tx.id, revision: tx.updatedAt);
        // A deleted transaction is read-only: it is not matched to anything
        // until it has been restored.
        final canMatch = !tx.isDeleted && (tx.isUnmatched || tx.isMatched);
        return RefreshIndicator(
          onRefresh: _record.refresh,
          child: SingleChildScrollView(
            controller: DetailScrollScope.maybeOf(context),
            // Handed a controller, so it has to ask to be pullable when the
            // record is shorter than its viewport (`docs/pull-to-refresh.md`).
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(InSpacing.lg(context)),
            child: EntityRecordColumn(
              header: TransactionDetailHeader(
                transaction: tx,
                formatter: formatter,
                // Opens the account's own record — never an edit screen.
                bankAccount: tx.bankAccountId.isEmpty
                    ? null
                    : BankAccountNameLabel(
                        bankAccountId: tx.bankAccountId,
                        link: true,
                        // The link tone at rest too: on a pointer platform
                        // the label only underlines on hover, and in a line
                        // of muted text that is a link nobody finds.
                        style: TextStyle(color: context.inTheme.accentInk),
                      ),
                // The banner above the page already says Deleted / Archived.
                showStatePills: !tx.isDeleted && tx.archivedAt == null,
              ),
              quickActions: EntityQuickActions<TransactionAction>(
                priority: TransactionActions.quickItemsFor(
                  context,
                  tx,
                  (a) => _dispatch(tx, a),
                ),
              ),
              standing: TransactionDetailStanding(
                transaction: tx,
                formatter: formatter,
              ),
              profile: TransactionDetailProfile(
                transaction: tx,
                formatter: formatter,
                work: canMatch
                    ? TransactionMatchPanel(
                        transaction: tx,
                        formatter: formatter,
                        runner: (convert, successKey) =>
                            _runConversion(context, tx, convert, successKey),
                      )
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The transaction's description and signed amount, for the fixed bar once
/// the header has scrolled away.
class _CompactTitle extends StatelessWidget {
  const _CompactTitle({required this.transaction, required this.formatter});

  final BankTransaction transaction;
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
          transactionDisplayName(context, transaction),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: tokens.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          transactionAmountText(transaction, formatter),
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
