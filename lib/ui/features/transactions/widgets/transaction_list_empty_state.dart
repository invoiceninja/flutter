import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/bank_account.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/features/bank_accounts/widgets/bank_connect.dart';
import 'package:admin/ui/features/transactions/view_models/transaction_list_view_model.dart';

/// Empty-state copy that matches the active filter set.
///
/// The base case is bank-account aware (invoiceninja/flutter#67, #68). A
/// company with nothing linked is told to connect a bank and handed a button
/// that goes there, rather than being left to find Settings on its own; a
/// company that *has* a bank account is not told to connect one it already
/// has — its feed simply hasn't produced anything yet.
///
/// "Has a bank account" means a *linked* one: a manual account is a ledger
/// the user posts to by hand and will never emit a transaction, so it must
/// not silence the connect nudge.
class TransactionListEmptyState extends StatelessWidget {
  const TransactionListEmptyState({super.key, required this.vm});

  final TransactionListViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (!vm.hasActiveFilters) return const _BaseEmptyState();
    final onlyArchived =
        vm.states.length == 1 &&
        vm.states.contains(EntityState.archived) &&
        vm.customFilters.isEmpty &&
        vm.extraFilters.isEmpty &&
        vm.search.isEmpty;
    final onlyDeleted =
        vm.states.length == 1 &&
        vm.states.contains(EntityState.deleted) &&
        vm.customFilters.isEmpty &&
        vm.extraFilters.isEmpty &&
        vm.search.isEmpty;
    if (onlyArchived) {
      return EmptyState(
        icon: Icons.archive_outlined,
        title: context.tr('no_archived_transactions'),
      );
    }
    if (onlyDeleted) {
      return EmptyState(
        icon: Icons.delete_outline,
        title: context.tr('no_deleted_transactions'),
      );
    }
    return EmptyState(
      icon: Icons.filter_alt_off_outlined,
      title: context.tr('no_transactions_match_filters'),
      action: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
        onPressed: vm.clearAllFilters,
        icon: const Icon(Icons.close),
        label: Text(context.tr('clear_filters')),
      ),
    );
  }
}

/// "No transactions yet" — the unfiltered case, which reads the local bank
/// accounts to decide what to say and whether to offer the connect CTA.
class _BaseEmptyState extends StatelessWidget {
  const _BaseEmptyState();

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    return StreamBuilder<List<BankAccount>>(
      stream: services.bankAccounts.watchAll(companyId: companyId),
      builder: (context, snapshot) {
        // Drift-backed, so the first frame is the only one without data; until
        // then assume "linked" and withhold the CTA rather than flashing a
        // connect prompt at a company that already has a feed.
        final accounts = snapshot.data;
        final hasLinked =
            accounts == null ||
            accounts.any((a) => !bankAccountNeedsConnecting(a));
        return EmptyState(
          icon: Icons.swap_horiz,
          title: context.tr('no_transactions_yet'),
          subtitle: context.tr(
            hasLinked
                ? 'no_transactions_connected_hint'
                : 'no_transactions_hint',
          ),
          action: hasLinked
              ? null
              : FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 44),
                  ),
                  icon: const Icon(Icons.add_link),
                  label: Text(context.tr('connect_accounts')),
                  // Routes to Credit Cards & Banks rather than firing the
                  // aggregator handshake straight from here: a company with
                  // nothing set up may want a manual account instead, and the
                  // hosted connect flow is enterprise-gated.
                  onPressed: () => context.go('/settings/bank_accounts'),
                ),
        );
      },
    );
  }
}
