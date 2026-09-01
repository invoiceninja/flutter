import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/bank_transaction.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/data/models/domain/expense_category.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/detail/custom_field_detail_rows.dart';
import 'package:admin/ui/core/detail/entity_link_card.dart';
import 'package:admin/ui/core/widgets/centered_form_column.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/expenses/widgets/expense_status_pill.dart';
import 'package:admin/utils/formatting.dart';

/// Responsive grid for the expense detail body cards.
///
/// - **≥1000 px**: two equal-width columns. Left holds Summary, Notes, and
///   Tax Breakdown — the high-information cards that benefit from the wider
///   half-width column. Right holds the related-entity link cards (Vendor /
///   Client / Invoice / Project / Category), Payment metadata, and Custom
///   Fields. If the right column would be empty (no relations, no payment,
///   no custom fields) we fall back to single-column so the left content
///   doesn't get stretched by an empty sibling.
/// - **<1000 px**: single centered column (≤820 px), pre-refactor order.
class ExpenseDetailCardsGrid extends StatelessWidget {
  const ExpenseDetailCardsGrid({
    super.key,
    required this.expense,
    required this.companyId,
    this.formatter,
  });

  final Expense expense;
  final String companyId;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= Breakpoints.entityFormMultiColumn;
        if (wide) return _wide(context);
        return CenteredFormColumn(child: _stacked(context));
      },
    );
  }

  Widget _wide(BuildContext context) {
    final e = expense;
    final leftCards = <Widget>[
      _SummaryCard(expense: e, formatter: formatter),
      if (_hasAnyNote(e)) _NotesCard(expense: e),
      if (_hasAnyTax(e)) _TaxBreakdownCard(expense: e, formatter: formatter),
    ];
    final rightCards = _relatedCards(context, e);

    if (rightCards.isEmpty) {
      // Nothing for the sidebar — keep the left column at full width so
      // Summary / Notes / Tax don't get stretched against a void.
      return _stack(context, leftCards);
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _stack(context, leftCards)),
          SizedBox(width: InSpacing.md(context)),
          Expanded(child: _stack(context, rightCards)),
        ],
      ),
    );
  }

  Widget _stacked(BuildContext context) {
    final e = expense;
    final cards = <Widget>[
      _SummaryCard(expense: e, formatter: formatter),
      if (_hasAnyNote(e)) _NotesCard(expense: e),
      ..._relatedCards(context, e),
      if (_hasAnyTax(e)) _TaxBreakdownCard(expense: e, formatter: formatter),
    ];
    return _stack(context, cards);
  }

  List<Widget> _relatedCards(BuildContext context, Expense e) {
    final cards = <Widget>[];
    if (e.vendorId.isNotEmpty) {
      cards.add(
        EntityLinkCard<Vendor>(
          titleKey: 'vendor',
          icon: Icons.storefront_outlined,
          entityId: e.vendorId,
          routePath: '/vendors/${e.vendorId}',
          permissionKey: 'view_vendor',
          repo: context.read<Services>().vendors,
          watchBuilder: () => context.read<Services>().vendors.watch(
            companyId: companyId,
            id: e.vendorId,
          ),
          displayNameOf: (v) => v.name.isEmpty ? e.vendorId : v.name,
        ),
      );
    }
    if (e.clientId.isNotEmpty) {
      cards.add(
        EntityLinkCard<Client>(
          titleKey: 'client',
          icon: Icons.person_outline,
          entityId: e.clientId,
          routePath: '/clients/${e.clientId}',
          permissionKey: 'view_client',
          repo: context.read<Services>().clients,
          watchBuilder: () => context.read<Services>().clients.watch(
            companyId: companyId,
            id: e.clientId,
          ),
          displayNameOf: (c) =>
              c.displayName.isNotEmpty ? c.displayName : c.name,
        ),
      );
    }
    if (e.invoiceId.isNotEmpty) {
      cards.add(
        EntityLinkCard<Invoice>(
          titleKey: 'invoice',
          icon: Icons.receipt_long_outlined,
          entityId: e.invoiceId,
          routePath: '/invoices/${e.invoiceId}',
          permissionKey: 'view_invoice',
          repo: context.read<Services>().invoices,
          watchBuilder: () => context.read<Services>().invoices.watch(
            companyId: companyId,
            id: e.invoiceId,
          ),
          displayNameOf: (inv) => inv.number.isEmpty ? e.invoiceId : inv.number,
        ),
      );
    }
    if (e.projectId.isNotEmpty) {
      cards.add(
        EntityLinkCard<Project>(
          titleKey: 'project',
          icon: Icons.work_outline,
          entityId: e.projectId,
          routePath: '/projects/${e.projectId}',
          permissionKey: 'view_project',
          repo: context.read<Services>().projects,
          watchBuilder: () => context.read<Services>().projects.watch(
            companyId: companyId,
            id: e.projectId,
          ),
          displayNameOf: (p) => p.name.isEmpty ? e.projectId : p.name,
        ),
      );
    }
    if (e.categoryId.isNotEmpty) {
      cards.add(
        EntityLinkCard<ExpenseCategory>(
          titleKey: 'category',
          icon: Icons.label_outline,
          entityId: e.categoryId,
          routePath: '/settings/expense_categories/${e.categoryId}',
          permissionKey: 'view_expense',
          repo: context.read<Services>().expenseCategories,
          watchBuilder: () => context.read<Services>().expenseCategories.watch(
            companyId: companyId,
            id: e.categoryId,
          ),
          displayNameOf: (c) => c.name.isEmpty ? e.categoryId : c.name,
        ),
      );
    }
    // Link to the bank transaction this expense was created from / matched to.
    // Gated on the bank-transaction module being enabled for the company.
    if (e.transactionId.isNotEmpty) {
      cards.add(
        EntityLinkCard<BankTransaction>(
          titleKey: 'transaction',
          icon: Icons.swap_horiz_outlined,
          entityId: e.transactionId,
          routePath: '/transactions/${e.transactionId}',
          permissionKey: 'view_bank_transaction',
          module: EntityType.transaction,
          repo: context.read<Services>().bankTransactions,
          watchBuilder: () => context.read<Services>().bankTransactions.watch(
            companyId: companyId,
            id: e.transactionId,
          ),
          displayNameOf: (t) =>
              t.description.isEmpty ? e.transactionId : t.description,
        ),
      );
    }
    // Show the payment card whenever *any* payment metadata is set — including
    // a payment type alone, which no longer counts as "paid" status but is
    // still worth surfacing.
    if (_hasPaymentInfo(e)) {
      cards.add(_PaymentMetadataCard(expense: e, formatter: formatter));
    }
    if (_hasAnyCustomValue(e)) {
      cards.add(
        _CustomFieldsCard(
          expense: e,
          companyId: companyId,
          formatter: formatter,
        ),
      );
    }
    if (e.tagIds.isNotEmpty) {
      cards.add(
        DashboardCardShell(
          title: context.tr('tags'),
          child: EntityTagsView(entityType: 'expense', tagIds: e.tagIds),
        ),
      );
    }
    return cards;
  }

  Widget _stack(BuildContext context, List<Widget> cards) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) SizedBox(height: InSpacing.lg(context)),
          cards[i],
        ],
      ],
    );
  }
}

bool _hasAnyTax(Expense e) =>
    e.taxAmount1 != Decimal.zero ||
    e.taxAmount2 != Decimal.zero ||
    e.taxAmount3 != Decimal.zero ||
    e.taxRate1 != Decimal.zero ||
    e.taxRate2 != Decimal.zero ||
    e.taxRate3 != Decimal.zero;

bool _hasAnyCustomValue(Expense e) =>
    e.customValue1.isNotEmpty ||
    e.customValue2.isNotEmpty ||
    e.customValue3.isNotEmpty ||
    e.customValue4.isNotEmpty;

bool _hasAnyNote(Expense e) =>
    e.publicNotes.isNotEmpty || e.privateNotes.isNotEmpty;

bool _hasPaymentInfo(Expense e) =>
    e.paymentDate != null ||
    e.paymentTypeId.isNotEmpty ||
    e.transactionReference.isNotEmpty;

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.copyValue});
  final String label;
  final Widget value;

  /// When non-empty, the value gets a copy affordance (hover icon on
  /// desktop/web, tap-to-copy on mobile) that copies this string.
  final String? copyValue;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // Tighten the label column on narrow phones so the value keeps a usable
    // width (a fixed 160px would eat ~half a 360px screen).
    final labelWidth = MediaQuery.sizeOf(context).width < 480 ? 100.0 : 160.0;
    Widget styled = DefaultTextStyle.merge(
      child: value,
      style: TextStyle(fontSize: 13, color: tokens.ink),
    );
    final copy = copyValue;
    if (copy != null && copy.isNotEmpty) {
      styled = CopyableValue(value: copy, child: styled);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: tokens.ink3),
            ),
          ),
          const SizedBox(width: InSpacing.sm),
          Expanded(child: styled),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.expense, required this.formatter});
  final Expense expense;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final e = expense;
    final f = formatter;
    final dateText = e.date == null
        ? '—'
        : (f == null ? e.date!.toIso() : f.date(e.date!.toIso()));
    final amountText = f == null
        ? e.amount.toString()
        : f.money(e.amount, clientCurrencyId: e.currencyId);
    final grossText = f == null
        ? e.grossAmount.toString()
        : f.money(e.grossAmount, clientCurrencyId: e.currencyId);
    final netText = f == null
        ? e.netAmount.toString()
        : f.money(e.netAmount, clientCurrencyId: e.currencyId);
    // Converted total in the invoice currency — only meaningful when an
    // invoice currency is set and the rate isn't a no-op.
    final hasConversion =
        e.invoiceCurrencyId.isNotEmpty &&
        e.effectiveExchangeRate != Decimal.one;
    final convertedText = f == null
        ? e.convertedAmount.toString()
        : f.money(e.convertedAmount, clientCurrencyId: e.invoiceCurrencyId);
    return DashboardCardShell(
      title: context.tr('details'),
      child: Column(
        children: [
          _Row(
            label: context.tr('status'),
            value: ExpenseStatusPill(statusId: e.calculatedStatusId),
          ),
          if (e.number.isNotEmpty)
            _Row(
              label: context.tr('number'),
              value: Text(e.number),
              copyValue: e.number,
            ),
          _Row(label: context.tr('date'), value: Text(dateText)),
          _Row(label: context.tr('amount'), value: Text(amountText)),
          // Net (amount minus tax) is only distinct from amount for inclusive
          // taxes; gross (amount plus tax) for exclusive.
          if (e.usesInclusiveTaxes && e.taxAmountSum != Decimal.zero)
            _Row(label: context.tr('net_amount'), value: Text(netText)),
          if (e.taxAmountSum != Decimal.zero)
            _Row(label: context.tr('gross_amount'), value: Text(grossText)),
          if (hasConversion)
            _Row(
              label: context.tr('converted_amount'),
              value: Text(convertedText),
            ),
        ],
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.expense});
  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final hasPrivate = expense.privateNotes.isNotEmpty;
    final hasPublic = expense.publicNotes.isNotEmpty;
    return DashboardCardShell(
      title: context.tr('notes'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasPrivate)
            _NotesBlock(
              label: context.tr('private_notes'),
              body: expense.privateNotes,
              labelColor: tokens.ink3,
              bodyStyle: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.ink,
              ),
            ),
          if (hasPrivate && hasPublic) ...[
            SizedBox(height: InSpacing.md(context)),
            Divider(height: 1, thickness: 1, color: tokens.border),
            SizedBox(height: InSpacing.md(context)),
          ],
          if (hasPublic)
            _NotesBlock(
              label: context.tr('public_notes'),
              body: expense.publicNotes,
              labelColor: tokens.ink3,
              bodyStyle: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.ink,
              ),
            ),
        ],
      ),
    );
  }
}

class _NotesBlock extends StatelessWidget {
  const _NotesBlock({
    required this.label,
    required this.body,
    required this.labelColor,
    required this.bodyStyle,
  });

  final String label;
  final String body;
  final Color labelColor;
  final TextStyle? bodyStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: labelColor,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: InSpacing.xs),
        Text(body, style: bodyStyle),
      ],
    );
  }
}

class _TaxBreakdownCard extends StatelessWidget {
  const _TaxBreakdownCard({required this.expense, required this.formatter});
  final Expense expense;
  final Formatter? formatter;

  String _fmt(Decimal amount) {
    final f = formatter;
    if (f == null) return amount.toString();
    return f.money(amount, clientCurrencyId: expense.currencyId);
  }

  /// In by-amount mode the rate is 0, so show just the amount — a "0% ·"
  /// prefix would misrepresent a fixed-amount tax.
  String _valueText(Decimal rate, Decimal amount) =>
      expense.calculateTaxByAmount ? _fmt(amount) : '$rate% · ${_fmt(amount)}';

  @override
  Widget build(BuildContext context) {
    final e = expense;
    return DashboardCardShell(
      title: context.tr('tax_breakdown'),
      child: Column(
        children: [
          if (e.taxName1.isNotEmpty ||
              e.taxRate1 != Decimal.zero ||
              e.taxAmount1Computed != Decimal.zero)
            _Row(
              label: e.taxName1.isEmpty ? context.tr('tax_rate1') : e.taxName1,
              value: Text(_valueText(e.taxRate1, e.taxAmount1Computed)),
            ),
          if (e.taxName2.isNotEmpty ||
              e.taxRate2 != Decimal.zero ||
              e.taxAmount2Computed != Decimal.zero)
            _Row(
              label: e.taxName2.isEmpty ? context.tr('tax_rate2') : e.taxName2,
              value: Text(_valueText(e.taxRate2, e.taxAmount2Computed)),
            ),
          if (e.taxName3.isNotEmpty ||
              e.taxRate3 != Decimal.zero ||
              e.taxAmount3Computed != Decimal.zero)
            _Row(
              label: e.taxName3.isEmpty ? context.tr('tax_rate3') : e.taxName3,
              value: Text(_valueText(e.taxRate3, e.taxAmount3Computed)),
            ),
          _Row(
            label: context.tr('inclusive_taxes'),
            value: Text(
              e.usesInclusiveTaxes ? context.tr('yes') : context.tr('no'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMetadataCard extends StatelessWidget {
  const _PaymentMetadataCard({required this.expense, required this.formatter});
  final Expense expense;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final e = expense;
    final f = formatter;
    final dateText = e.paymentDate == null
        ? '—'
        : (f == null ? e.paymentDate!.toIso() : f.date(e.paymentDate!.toIso()));
    // Resolve the payment type id to its human name (e.g. "1" → "Credit
    // Card") via the statics bundle, the same lookup the edit form uses.
    final paymentTypeName =
        context.read<Services>().statics.paymentType(e.paymentTypeId)?.name ??
        e.paymentTypeId;
    return DashboardCardShell(
      title: context.tr('payment'),
      child: Column(
        children: [
          _Row(label: context.tr('payment_date'), value: Text(dateText)),
          if (e.paymentTypeId.isNotEmpty)
            _Row(
              label: context.tr('payment_type'),
              value: Text(paymentTypeName),
            ),
          if (e.transactionReference.isNotEmpty)
            _Row(
              label: context.tr('transaction_reference'),
              value: Text(e.transactionReference),
              copyValue: e.transactionReference,
            ),
        ],
      ),
    );
  }
}

class _CustomFieldsCard extends StatelessWidget {
  const _CustomFieldsCard({
    required this.expense,
    required this.companyId,
    this.formatter,
  });
  final Expense expense;
  final String companyId;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final e = expense;
    final yes = context.tr('yes');
    final no = context.tr('no');
    return WatchBuilder<Company?>(
      cacheKey: companyId,
      create: () => context.read<Services>().company.watchCompany(companyId),
      builder: (context, snapshot) {
        final rows = customFieldDetailRows(
          company: snapshot.data,
          prefix: 'expense',
          values: [
            e.customValue1,
            e.customValue2,
            e.customValue3,
            e.customValue4,
          ],
          formatter: formatter,
          yes: yes,
          no: no,
        );
        if (rows.isEmpty) return const SizedBox.shrink();
        return DashboardCardShell(
          title: context.tr('custom_fields'),
          child: Column(
            children: [
              for (final r in rows) _Row(label: r.label, value: Text(r.value)),
            ],
          ),
        );
      },
    );
  }
}
