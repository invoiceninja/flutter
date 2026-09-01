import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/expense_category.dart';
import 'package:admin/ui/core/widgets/link_text.dart';

/// Resolves the expense-category name from the local Drift cache and
/// renders it as a `Text` (or a link when [link]). Falls back to the
/// raw `categoryId` while the watch is empty; on a cache miss it
/// triggers a lazy per-id hydrate (`ExpenseCategoryRepository.
/// ensureLoaded`) so the name resolves even when the category isn't
/// cached.
///
/// Drift dedupes identical watch queries (and the repo dedupes the
/// hydrate fetch), so N rows for the same category share one
/// subscription and one network call.
class CategoryNameLabel extends StatefulWidget {
  const CategoryNameLabel({
    super.key,
    required this.categoryId,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.link = false,
  });

  final String categoryId;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow overflow;

  /// When true the resolved name renders as a hover-underlined link to
  /// the expense category's full-screen view. Off by default.
  final bool link;

  @override
  State<CategoryNameLabel> createState() => _CategoryNameLabelState();
}

class _CategoryNameLabelState extends State<CategoryNameLabel> {
  @override
  void initState() {
    super.initState();
    _ensure();
  }

  @override
  void didUpdateWidget(CategoryNameLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryId != widget.categoryId) _ensure();
  }

  /// Lazily hydrate the referenced category into Drift if it isn't
  /// cached. No-op / deduped / negative-cached in the repo, so it's safe
  /// to fire unconditionally here.
  void _ensure() {
    final id = widget.categoryId;
    if (id.isEmpty) return;
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) return;
    services.expenseCategories.ensureLoaded(companyId: companyId, id: id);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    if (widget.categoryId.isEmpty) {
      return Text(
        '—',
        style: widget.style ?? TextStyle(fontSize: 13, color: tokens.ink3),
      );
    }
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) {
      return _text(context, widget.categoryId);
    }
    return StreamBuilder<ExpenseCategory?>(
      initialData: services.expenseCategories.peek(
        companyId: companyId,
        id: widget.categoryId,
      ),
      stream: services.expenseCategories.watch(
        companyId: companyId,
        id: widget.categoryId,
      ),
      builder: (context, snapshot) {
        final category = snapshot.data;
        final name = category == null || category.name.isEmpty
            ? widget.categoryId
            : category.name;
        return _text(context, name);
      },
    );
  }

  Widget _text(BuildContext context, String text) => linkOrText(
    link: widget.link,
    label: text,
    onTap: widget.link
        ? () => goEntityFullDetail(
            context,
            '/settings/expense_categories',
            widget.categoryId,
          )
        : null,
    style: widget.style,
    maxLines: widget.maxLines,
    overflow: widget.overflow,
  );
}
