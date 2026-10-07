import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/expense_category.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/core/detail/entity_record_column.dart';
import 'package:admin/ui/core/detail/entity_state_banner.dart';
import 'package:admin/ui/core/detail/record_screen_controller.dart';
import 'package:admin/ui/core/detail/settings_record_body.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/features/expense_categories/view_models/expense_category_detail_view_model.dart';
import 'package:admin/ui/features/expense_categories/widgets/detail/expense_category_detail_header.dart';
import 'package:admin/ui/features/expense_categories/widgets/detail/expense_category_detail_profile.dart';
import 'package:admin/ui/features/expense_categories/widgets/expense_category_actions.dart';

/// The expense-category record screen, on the record layout
/// (`docs/detail-screen-layout.md`) as far as a category has anything to put
/// in it: identity and a Details card. No quick-action tiles, no standing
/// card, no tabs — there is no figure the server keeps for a category and no
/// action beyond the ones in the bar.
///
/// Reached only via the Settings sidebar, so the body goes through
/// `SettingsFormShell` (in [SettingsRecordBody]) and its width matches every
/// other settings page.
class ExpenseCategoryDetailScreen extends StatefulWidget {
  const ExpenseCategoryDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<ExpenseCategoryDetailScreen> createState() =>
      _ExpenseCategoryDetailScreenState();
}

class _ExpenseCategoryDetailScreenState
    extends State<ExpenseCategoryDetailScreen>
    with FormatterHostMixin {
  late final ExpenseCategoryDetailViewModel _vm;
  late final RecordScreenController _record;
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
    _record = RecordScreenController(
      services: _services,
      companyId: _companyId,
      routeId: widget.id,
      entityWireName: 'expense_category',
      // Categories are bundled reference data: the repository has no by-id
      // re-fetch (this is the base no-op), so opening one asks the server
      // nothing…
      refreshRecord: (id) => _services.expenseCategories.refreshByIds(
        companyId: _companyId,
        ids: [id],
      ),
      hasRecord: () => _vm.item != null,
      // …and a pull or `R` runs what the list's own refresh runs: the delta
      // of a table that is a few dozen rows at most.
      refreshWith: [_refreshCategories],
    );
    loadFormatter(_services, _companyId);
  }

  Future<void> _refreshCategories() async {
    if (!_record.mayRefreshRecord) return;
    await _services.expenseCategories.refreshAll(companyId: _companyId);
  }

  @override
  void dispose() {
    _record.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _dispatch(ExpenseCategory category, ExpenseCategoryAction action) =>
      ExpenseCategoryActions.dispatch(
        context,
        _services,
        _companyId,
        category,
        action,
      );

  @override
  Widget build(BuildContext context) {
    return EntityDetailScaffold<ExpenseCategory>(
      id: widget.id,
      vm: _vm,
      hydrate: () => _services.expenseCategories.ensureLoaded(
        companyId: _companyId,
        id: widget.id,
      ),
      emptyAction: entityListEmptyAction(context, EntityType.expenseCategory),
      emptyIcon: Icons.category_outlined,
      emptyTitle: context.tr('expense_category'),
      actionsForItem: (context, c) =>
          EntityDetailActionsRow<ExpenseCategoryAction>(
            items: ExpenseCategoryActions.itemsFor(
              context,
              c,
              (a) => _dispatch(c, a),
            ),
          ),
      compactTitleForItem: (context, c) => _CompactTitle(category: c),
      // A deleted category is read-only until restored.
      isReadOnly: (c) => c.isDeleted,
      onRefresh: _record.refresh,
      bannerForItem: (context, c) => recordStateBanner<ExpenseCategoryAction>(
        context,
        items: ExpenseCategoryActions.itemsFor(
          context,
          c,
          (a) => _dispatch(c, a),
        ),
        restoreKind: ExpenseCategoryAction.restore,
        entityId: c.id,
        isDeleted: c.isDeleted,
        archivedAt: c.archivedAt,
        formatter: formatter,
      ),
      bodyBuilder: (context, c) {
        _record.attach(recordId: c.id, revision: c.updatedAt);
        return SettingsRecordBody(
          onRefresh: _record.refresh,
          child: EntityRecordColumn(
            header: ExpenseCategoryDetailHeader(
              category: c,
              formatter: formatter,
              // The banner above the page already says Deleted / Archived.
              showStatePills: !c.isDeleted && c.archivedAt == null,
            ),
            profile:
                ExpenseCategoryDetailProfile.hasContent(
                  context,
                  c,
                  formatter: formatter,
                )
                ? ExpenseCategoryDetailProfile(
                    category: c,
                    formatter: formatter,
                  )
                : null,
          ),
        );
      },
    );
  }
}

/// The category's name, for the fixed bar once the header has scrolled away.
class _CompactTitle extends StatelessWidget {
  const _CompactTitle({required this.category});

  final ExpenseCategory category;

  @override
  Widget build(BuildContext context) {
    return Text(
      category.name.isEmpty ? context.tr('no_name_fallback') : category.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: context.inTheme.ink,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
