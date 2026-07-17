import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/ui/core/widgets/link_text.dart';

/// Resolves an expense's number from the local Drift cache and renders it as a
/// `Text` (or a link when [link]). Mirror of `InvoiceNameLabel`: falls back to
/// the raw [expenseId] while the watch is empty and triggers a lazy per-id
/// hydrate on a cache miss. Drift dedupes identical watches, so N rows sharing
/// an expense share one subscription + one hydrate.
class ExpenseNameLabel extends StatefulWidget {
  const ExpenseNameLabel({
    super.key,
    required this.expenseId,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.link = false,
  });

  final String expenseId;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow overflow;
  final bool link;

  @override
  State<ExpenseNameLabel> createState() => _ExpenseNameLabelState();
}

class _ExpenseNameLabelState extends State<ExpenseNameLabel> {
  @override
  void initState() {
    super.initState();
    _ensure();
  }

  @override
  void didUpdateWidget(ExpenseNameLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expenseId != widget.expenseId) _ensure();
  }

  void _ensure() {
    final id = widget.expenseId;
    if (id.isEmpty) return;
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) return;
    services.expenses.ensureLoaded(companyId: companyId, id: id);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    if (widget.expenseId.isEmpty) {
      return Text(
        '—',
        style: widget.style ?? TextStyle(fontSize: 13, color: tokens.ink3),
      );
    }
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) {
      return _text(context, widget.expenseId);
    }
    return StreamBuilder<Expense?>(
      stream: services.expenses.watch(
        companyId: companyId,
        id: widget.expenseId,
      ),
      builder: (context, snapshot) {
        final expense = snapshot.data;
        final label = expense == null || expense.number.isEmpty
            ? widget.expenseId
            : expense.number;
        return _text(context, label);
      },
    );
  }

  Widget _text(BuildContext context, String text) => linkOrText(
    link: widget.link,
    label: text,
    onTap: widget.link
        ? () => goEntityFullDetail(context, '/expenses', widget.expenseId)
        : null,
    style: widget.style,
    maxLines: widget.maxLines,
    overflow: widget.overflow,
  );
}
