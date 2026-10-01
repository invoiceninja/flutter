import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/bank_transaction.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/core/detail/generic_detail_view_model.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/core/widgets/bank_account_name_label.dart';
import 'package:admin/ui/core/widgets/centered_form_column.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/transaction_rule_matched_chip.dart';
import 'package:admin/ui/features/transactions/widgets/transaction_actions.dart';
import 'package:admin/ui/features/transactions/widgets/transaction_match_panel.dart';
import 'package:admin/ui/features/transactions/widgets/transaction_matched_entities.dart';
import 'package:admin/ui/features/transactions/widgets/transaction_status_pill.dart';
import 'package:admin/utils/formatting.dart';

/// Read-only detail screen for a bank transaction. Header surfaces the
/// identity + status, then either the match panel (Unmatched/Matched) or
/// the matched-entities chip row (Converted). Actions row in the AppBar
/// dispatches edit / convert / unlink / archive / restore / delete.
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
    loadFormatter(_services, _companyId);
  }

  @override
  void dispose() {
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
      actionsForItem: (context, tx) => _ActionsRow(transaction: tx),
      bodyBuilder: (context, tx) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(InSpacing.lg(context)),
          // Whole body capped/centered (820) — not just an overview grid like
          // client/vendor detail. A transaction's match panel + matched
          // entities are compact (no long related-entity list), so this reads
          // cleanly at full width.
          child: CenteredFormColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(transaction: tx, formatter: formatter),
                SizedBox(height: InSpacing.lg(context)),
                if (tx.isUnmatched || tx.isMatched)
                  TransactionMatchPanel(
                    transaction: tx,
                    formatter: formatter,
                    runner: (convert, successKey) =>
                        _runConversion(context, tx, convert, successKey),
                  ),
                if (tx.isMatched || tx.isConverted) ...[
                  SizedBox(height: InSpacing.lg(context)),
                  _Section(
                    title: context.tr(tx.isConverted ? 'converted' : 'matched'),
                    child: TransactionMatchedEntities(transaction: tx),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.transaction, this.formatter});
  final BankTransaction transaction;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final tx = transaction;
    final sign = tx.isWithdrawal ? '-' : '+';
    final amountColor = tx.isWithdrawal ? tokens.overdue : tokens.paid;
    // Format through the central Formatter (symbol/code, separators,
    // precision) when it has resolved; until then fall back to the raw
    // fixed-2 with the bare currency code so the amount never renders blank.
    final formatted = formatter?.money(tx.amount, currencyId: tx.currencyId);
    final amountBody = (formatted != null && formatted.isNotEmpty)
        ? formatted
        : '${tx.currencyId.isEmpty ? '' : '${tx.currencyId} '}'
              '${tx.amount.toStringAsFixed(2)}';
    return Container(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(InRadii.r3),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TransactionStatusPill(statusId: tx.statusId, dotSize: 10),
              const Spacer(),
              Text(
                '$sign$amountBody',
                style: moneyTextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                ),
              ),
            ],
          ),
          if (tx.transactionRuleId.isNotEmpty &&
              (tx.isMatched || tx.isConverted)) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TransactionRuleMatchedChip(
                transactionRuleId: tx.transactionRuleId,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (tx.participantName.isNotEmpty) ...[
            Text(
              tx.participantName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
          ],
          if (tx.description.isNotEmpty)
            Text(tx.description, style: TextStyle(color: tokens.ink2)),
          const SizedBox(height: 12),
          _MetaRow(
            label: context.tr('date'),
            value: tx.date == null
                ? '—'
                : (formatter?.date(tx.date!.toIso()) ?? tx.date!.toIso()),
          ),
          if (tx.bankAccountId.isNotEmpty)
            _MetaRow(
              label: context.tr('bank_account'),
              valueChild: BankAccountNameLabel(
                bankAccountId: tx.bankAccountId,
                link: true,
                style: TextStyle(color: context.inTheme.ink),
              ),
            ),
          if (tx.participant.isNotEmpty)
            _MetaRow(label: context.tr('participant'), value: tx.participant),
          if (tx.tagIds.isNotEmpty)
            _MetaRow(
              label: context.tr('tags'),
              valueChild: EntityTagsView(
                entityType: 'bank_transaction',
                tagIds: tx.tagIds,
              ),
            ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, this.value = '', this.valueChild});
  final String label;
  final String value;

  /// When provided, rendered instead of the [value] string (used for
  /// reference rows that resolve a name via a `*NameLabel`).
  final Widget? valueChild;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final valueWidget =
        valueChild ?? Text(value, style: TextStyle(color: tokens.ink));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            // Tighter label gutter on narrow phones so the value keeps room.
            width: MediaQuery.sizeOf(context).width < 600 ? 96 : 120,
            child: Text(
              label,
              style: TextStyle(color: tokens.ink3, fontSize: 13),
            ),
          ),
          Expanded(child: valueWidget),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(InRadii.r3),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({required this.transaction});
  final BankTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    return EntityDetailActionsRow<TransactionAction>(
      items: TransactionActions.itemsFor(
        context,
        transaction,
        (action) => TransactionActions.dispatch(
          context,
          services,
          companyId,
          transaction,
          action,
        ),
      ),
    );
  }
}
