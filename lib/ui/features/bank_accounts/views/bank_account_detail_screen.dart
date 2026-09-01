import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/bank_account.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/detail_scroll_scope.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/core/detail/generic_detail_view_model.dart';
import 'package:admin/ui/features/bank_accounts/views/bank_account_list_screen.dart'
    show kBankAccountsListSearchKeys;
import 'package:admin/ui/features/bank_accounts/widgets/bank_account_actions.dart';
import 'package:admin/ui/features/bank_accounts/widgets/reconnect_banner.dart';
import 'package:admin/ui/features/transactions/views/transaction_list_screen.dart';
import 'package:admin/utils/formatting.dart';

/// `/settings/bank_accounts/:id` — read-only detail view for one bank
/// integration. Header surfaces balance + provider + status + quick-edit
/// `auto_sync` switch. Reconnect banner appears when the upstream
/// provider has dropped the connection. Below the header, an embedded
/// `TransactionListScreen` filtered to this integration shows recent
/// transactions; tap "View all" to drop into the full
/// `/transactions?bank_account_id=<id>` workspace screen.
class BankAccountDetailScreen extends StatefulWidget {
  const BankAccountDetailScreen({required this.id, super.key});

  /// Search keys for the in-app settings search — re-exports the list
  /// screen's keys so the detail page surfaces in the same searches.
  static const searchKeys = kBankAccountsListSearchKeys;

  final String id;

  @override
  State<BankAccountDetailScreen> createState() =>
      _BankAccountDetailScreenState();
}

class _BankAccountDetailScreenState extends State<BankAccountDetailScreen> {
  late final GenericDetailViewModel<BankAccount> _vm;
  late final Services _services;
  late final String _companyId;
  Future<Formatter>? _formatterFuture;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = GenericDetailViewModel<BankAccount>.bound(
      _services.bankAccounts.watch(companyId: _companyId, id: widget.id),
    );
    _formatterFuture = _services.formatterFor(_companyId);
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  /// Quick-edit auto_sync from the header — flips a single field and
  /// persists immediately via the standard outbox path. No save button
  /// since this is the only edit on the detail screen; the full edit
  /// form is one tap away.
  Future<void> _toggleAutoSync(BankAccount account, bool value) async {
    await _services.bankAccounts.save(
      companyId: _companyId,
      account: account.copyWith(autoSync: value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Formatter>(
      future: _formatterFuture,
      builder: (context, snapshot) {
        final formatter = snapshot.data;
        return EntityDetailScaffold<BankAccount>(
          id: widget.id,
          vm: _vm,
          hydrate: () => _services.bankAccounts.ensureLoaded(
            companyId: _companyId,
            id: widget.id,
          ),
          emptyAction: entityListEmptyAction(context, EntityType.bankAccount),
          emptyIcon: Icons.account_balance_outlined,
          emptyTitle: context.tr('bank_account_not_found'),
          actionsForItem: (context, account) => _ActionsRow(account: account),
          bodyBuilder: (context, account) {
            return SingleChildScrollView(
              controller: DetailScrollScope.maybeOf(context),
              padding: EdgeInsets.all(InSpacing.lg(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ReconnectBanner(account: account),
                  _Header(
                    account: account,
                    formatter: formatter,
                    onAutoSyncChanged: (v) => _toggleAutoSync(account, v),
                  ),
                  SizedBox(height: InSpacing.lg(context)),
                  _RecentTransactionsSection(bankAccountId: account.id),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.account,
    required this.formatter,
    required this.onAutoSyncChanged,
  });

  final BankAccount account;
  final Formatter? formatter;
  final ValueChanged<bool> onAutoSyncChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final displayName = account.name.trim().isEmpty
        ? context.tr('untitled')
        : account.name;
    final balanceText = _formatBalance();
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (account.provider.isNotEmpty ||
                        account.type.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (account.type.isNotEmpty) account.type,
                          if (account.provider.isNotEmpty) account.provider,
                        ].join(' · '),
                        style: TextStyle(color: tokens.ink2, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: InSpacing.md(context)),
              Text(
                balanceText,
                style: moneyTextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: tokens.ink,
                ),
              ),
            ],
          ),
          SizedBox(height: InSpacing.lg(context)),
          // Quick-edit row. Auto-sync is by far the most-flipped field
          // on this screen; surfacing it on the header avoids a trip
          // through the full edit form. When `account.isDirty` is true
          // there's an outbox row pending — render a small spinner so
          // the user sees the change is queued for sync.
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Row(
              children: [
                Text(context.tr('auto_sync')),
                if (account.isDirty) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: tokens.ink3,
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              context.tr('auto_sync_help'),
              style: TextStyle(color: tokens.ink2, fontSize: 12),
            ),
            value: account.autoSync,
            onChanged: onAutoSyncChanged,
          ),
        ],
      ),
    );
  }

  String _formatBalance() {
    if (formatter == null) {
      final prefix = account.currency.isEmpty ? '' : '${account.currency} ';
      return '$prefix${account.balance}';
    }
    String? resolvedId;
    if (account.currency.isNotEmpty) {
      final upper = account.currency.toUpperCase();
      for (final entry in formatter!.currencies.entries) {
        if (entry.value.code.toUpperCase() == upper) {
          resolvedId = entry.key;
          break;
        }
      }
    }
    final formatted = formatter!.money(account.balance, currencyId: resolvedId);
    if (formatted.isNotEmpty) return formatted;
    final prefix = account.currency.isEmpty ? '' : '${account.currency} ';
    return '$prefix${account.balance}';
  }
}

class _RecentTransactionsSection extends StatelessWidget {
  const _RecentTransactionsSection({required this.bankAccountId});

  final String bankAccountId;

  @override
  Widget build(BuildContext context) {
    // Reuses TransactionListScreen scoped to this bank account with
    // `embedded: true`: it renders its own slim toolbar (filter + New)
    // and grows with the detail page (single scrollbar, no card chrome) —
    // consistent with the client/vendor related-entity tabs.
    return TransactionListScreen(bankAccountId: bankAccountId, embedded: true);
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({required this.account});
  final BankAccount account;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    return EntityDetailActionsRow<BankAccountAction>(
      items: BankAccountActions.itemsFor(
        context,
        account,
        (action) => BankAccountActions.dispatch(
          context,
          services,
          companyId,
          account,
          action,
        ),
      ),
    );
  }
}
