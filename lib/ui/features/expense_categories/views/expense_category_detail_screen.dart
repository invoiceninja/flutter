import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/expense_category.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/features/expense_categories/view_models/expense_category_detail_view_model.dart';
import 'package:admin/ui/features/expense_categories/widgets/detail/expense_category_detail_actions_row.dart';
import 'package:admin/ui/features/expense_categories/widgets/detail/expense_category_detail_header.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

/// Read-only ExpenseCategory detail screen. Reached only via the Settings
/// sidebar — the body lives inside [SettingsFormShell] so the max-width +
/// padding match every other Settings page, then renders the canonical
/// detail header followed by a single details card (name + color swatch).
class ExpenseCategoryDetailScreen extends StatefulWidget {
  const ExpenseCategoryDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<ExpenseCategoryDetailScreen> createState() =>
      _ExpenseCategoryDetailScreenState();
}

class _ExpenseCategoryDetailScreenState
    extends State<ExpenseCategoryDetailScreen> {
  late final ExpenseCategoryDetailViewModel _vm;
  late final Services _services;
  late final String _companyId;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = ExpenseCategoryDetailViewModel.bound(
      _services.expenseCategories.watch(companyId: _companyId, id: widget.id),
    );
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EntityDetailScaffold<ExpenseCategory>(
      vm: _vm,
      hydrate: () => _services.expenseCategories.ensureLoaded(
        companyId: _companyId,
        id: widget.id,
      ),
      emptyAction: entityListEmptyAction(context, EntityType.expenseCategory),
      emptyIcon: Icons.category_outlined,
      emptyTitle: context.tr('expense_category'),
      actionsForItem: (context, category) =>
          ExpenseCategoryDetailActionsRow(category: category),
      bodyBuilder: (context, category) => SettingsFormShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExpenseCategoryDetailHeader(category: category),
            SizedBox(height: InSpacing.xl),
            _OverviewCard(category: category),
          ],
        ),
      ),
    );
  }
}

/// Single info card on the detail screen — name + color swatch. Matches the
/// minimal field set: there's nothing else to show.
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.category});

  final ExpenseCategory category;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final raw = category.color.trim().replaceFirst('#', '');
    Color swatch = tokens.ink3;
    if (raw.length == 6) {
      final v = int.tryParse(raw, radix: 16);
      if (v != null) swatch = Color(0xFF000000 | v);
    }
    return FormSection(
      title: context.tr('overview'),
      spacing: 0,
      children: [
        if (category.name.isNotEmpty)
          _KeyValue(labelKey: 'name', value: category.name),
        if (category.color.isNotEmpty)
          _ColorRow(
            label: context.tr('color'),
            swatch: swatch,
            hex: category.color,
          ),
      ],
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.labelKey, required this.value});

  final String labelKey;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: InSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              context.tr(labelKey),
              style: theme.textTheme.bodySmall?.copyWith(color: tokens.ink3),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.label,
    required this.swatch,
    required this.hex,
  });

  final String label;
  final Color swatch;
  final String hex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: InSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: tokens.ink3),
            ),
          ),
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(color: swatch, shape: BoxShape.circle),
          ),
          SizedBox(width: InSpacing.md(context)),
          Expanded(
            child: Text(
              hex.isEmpty ? '—' : hex,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
