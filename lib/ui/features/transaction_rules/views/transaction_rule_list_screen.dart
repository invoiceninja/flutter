import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart' show highlightSelectedIdFromRoute;
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/transaction_rule.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/core/widgets/unsynced_pill.dart';
import 'package:admin/ui/features/settings/widgets/plan_gate_banner.dart';
import 'package:admin/ui/features/settings/widgets/settings_entity_list_scaffold.dart';

const kTransactionRulesListSearchKeys = <String>[
  'transaction_rules',
  'transaction_rule',
  'new_transaction_rule',
  'applies_to',
  'match_all_rules',
  'auto_convert',
];

/// `/settings/bank_accounts/transaction_rules` — list every transaction
/// rule. Tap a row to edit; tap "+ New transaction rule" to create.
class TransactionRuleListScreen extends StatelessWidget {
  const TransactionRuleListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final session = services.auth.session.value;
    final companyId = session?.currentCompanyId ?? '';
    final hasAccess = session?.hasProAccess ?? false;
    final repo = services.transactionRules;

    return SettingsEntityListScaffold<TransactionRule>(
      titleKey: 'transaction_rules',
      sectionTitleKey: 'transaction_rules',
      newRoute: '/settings/bank_accounts/transaction_rules/new',
      newLabelKey: 'new_transaction_rule',
      emptyIcon: Icons.rule_outlined,
      emptyTitleKey: 'no_transaction_rules',
      emptyHintKey: 'no_transaction_rules_hint',
      supportsArchive: true,
      refreshAll: () async {
        if (companyId.isEmpty) return;
        await repo.refreshAll(companyId: companyId);
      },
      stream: ({required includeArchived}) => includeArchived
          ? repo.watchAllIncludingArchived(companyId: companyId)
          : repo.watchAll(companyId: companyId),
      isArchivedOf: (r) => r.archivedAt != null,
      isDeletedOf: (r) => r.isDeleted,
      rowBuilder: (r) => _TransactionRuleRow(key: ValueKey(r.id), rule: r),
      archivedRowBuilder: (r) =>
          _TransactionRuleRow.archived(key: ValueKey(r.id), rule: r),
      banner: const PlanGateBanner(style: PlanGateStyle.stripe),
      canCreate: hasAccess,
    );
  }
}

class _TransactionRuleRow extends StatelessWidget {
  const _TransactionRuleRow({required this.rule, super.key})
    : _isArchived = false;

  const _TransactionRuleRow.archived({required this.rule, super.key})
    : _isArchived = true;

  final TransactionRule rule;
  final bool _isArchived;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final displayName = rule.name.trim().isEmpty
        ? context.tr('untitled')
        : rule.name;

    final appliesToKey = rule.isDebit ? 'withdrawal' : 'deposit';
    final detailParts = <String>[
      context.tr(appliesToKey),
      if (rule.isDebit && rule.vendorName.isNotEmpty) rule.vendorName,
      if (rule.isDebit && rule.categoryName.isNotEmpty) rule.categoryName,
    ];
    final isUrlSelected = highlightSelectedIdFromRoute(context) == rule.id;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(Icons.rule_outlined, color: tokens.ink2),
          title: Text(displayName),
          subtitle: Text(
            detailParts.join(' · '),
            style: TextStyle(color: tokens.ink2, fontSize: 12),
          ),
          trailing: _isArchived
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.draftSoft,
                    borderRadius: BorderRadius.circular(InRadii.r1),
                  ),
                  child: Text(
                    context.tr('archived'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: tokens.draft,
                    ),
                  ),
                )
              // An unsynced row takes the state slot rather than sitting
              // beside the chevron — see UnsyncedPill on the width budget.
              : rule.isDirty
              ? const UnsyncedPill()
              : const Icon(Icons.chevron_right),
          onTap: isUrlSelected
              ? () => MasterDetailNavScope.requestClose(
                  context,
                  basePath: '/settings/bank_accounts/transaction_rules',
                )
              : () => context.go(
                  '/settings/bank_accounts/transaction_rules/${rule.id}',
                ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
