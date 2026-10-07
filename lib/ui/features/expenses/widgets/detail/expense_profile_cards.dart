import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/custom_field_detail_rows.dart';
import 'package:admin/ui/core/widgets/clamped_text.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/core/widgets/detail_row_columns.dart';
import 'package:admin/ui/core/widgets/user_name_label.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/formatting.dart';

// The cards and rows an expense and a recurring expense share. The two are
// separate types with the same fields and no common supertype, so everything
// here takes the values themselves rather than either record.

/// A titled card of label / value rows.
///
/// Takes the rows it draws, so "does this card exist" and "what is in it"
/// are one list at the call site: a host builds the rows, and gives the card
/// a place in the profile only when there are some.
class ExpenseRowsCard extends StatelessWidget {
  const ExpenseRowsCard({super.key, required this.title, required this.rows});

  /// Already localized.
  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return DashboardCardShell(
      title: title,
      child: DetailRowColumns(children: rows),
    );
  }
}

/// A row that names another record and opens it.
///
/// [name] empty means the record has not resolved (not cached, deleted, not
/// this user's to fetch). The row is labelled, so it says so with a dash
/// rather than disappearing — an expense that is invoiced must not look as if
/// it is not — and the dash still opens the record for a user who may.
///
/// [onTap] null draws plain text: a name the user may read but not follow.
Widget linkedRecordRow({
  required String label,
  required String name,
  required VoidCallback? onTap,
}) => DetailInfoRow(
  label: label,
  value: name.isEmpty ? '—' : name,
  onTap: onTap,
  // A dash is not worth copying.
  copyable: name.isNotEmpty,
);

/// Decides whether a linked record may be opened, and builds the tap.
///
/// The destination is always **the record's own screen**
/// (`goEntityFullDetail`) — a link that landed on an edit form would save or
/// discard whatever was in it. Built in `build`, so it follows a company
/// switch.
class LinkedRecordOpener {
  LinkedRecordOpener(this.context)
    : _me = context.read<Services>().auth.session.value?.currentCompany;

  final BuildContext context;
  final AuthCompany? _me;

  bool moduleOn(EntityType type) => _me?.moduleEnabled(type) ?? false;

  /// Null — plain text — unless [module] is on and the user holds
  /// [permission].
  VoidCallback? to(
    EntityType module,
    String permission,
    String basePath,
    String id,
  ) {
    if (!moduleOn(module) || !(_me?.can(permission) ?? false)) return null;
    return () => goEntityFullDetail(context, basePath, id);
  }
}

/// What the record is and where it came from — the Details card's rows, for
/// an expense or a recurring one.
///
/// The currency is worth a row only when it is not the company's own: every
/// expense has one, and for nearly all of them it is the currency every amount
/// on the screen is already printed in.
List<Widget> expenseDetailsRows(
  BuildContext context, {
  required String number,
  required String projectId,
  required String projectName,
  required String assignedUserId,
  required String currencyId,
  required List<String> customValues,
  required Company? company,
  required DateTime createdAt,
  required DateTime updatedAt,
  required Formatter? formatter,
  String recurringExpenseId = '',
  String recurringExpenseNumber = '',
  List<Widget> scheduleRows = const [],
}) {
  final open = LinkedRecordOpener(context);
  final foreignCurrency =
      formatter != null &&
      currencyId.isNotEmpty &&
      currencyId != formatter.settings.currencyId;
  return [
    if (number.isNotEmpty)
      DetailInfoRow(label: context.tr('number'), value: number),
    if (projectId.isNotEmpty)
      linkedRecordRow(
        label: context.tr('project'),
        name: projectName,
        onTap: open.to(
          EntityType.project,
          'view_project',
          '/projects',
          projectId,
        ),
      ),
    // The schedule that made this expense.
    if (recurringExpenseId.isNotEmpty)
      linkedRecordRow(
        label: context.tr('recurring_expense'),
        name: recurringExpenseNumber.isEmpty ? '' : '#$recurringExpenseNumber',
        onTap: open.to(
          EntityType.recurringExpense,
          'view_recurring_expense',
          '/recurring_expenses',
          recurringExpenseId,
        ),
      ),
    if (assignedUserId.isNotEmpty)
      DetailInfoRow(
        label: context.tr('assigned_user'),
        value: '',
        copyable: false,
        child: UserNameLabel(userId: assignedUserId),
      ),
    if (foreignCurrency)
      DetailInfoRow(
        label: context.tr('currency'),
        value:
            context.read<Services>().statics.currency(currencyId)?.name ??
            currencyId,
        copyable: false,
      ),
    // A recurring expense's own facts — when it last ran.
    ...scheduleRows,
    ...expenseCustomFieldRows(
      context,
      company: company,
      values: customValues,
      formatter: formatter,
    ),
    ...recordTimestampRows(
      context,
      createdAt: createdAt,
      updatedAt: updatedAt,
      formatter: formatter,
    ),
  ];
}

/// Whether, how and on which invoice the expense is passed on to a client —
/// the edit form's Invoicing and Currency Conversion sections.
///
/// "Should be invoiced" goes once the expense is on an invoice: the row above
/// it has answered the question. [exchangeRate] is the effective rate, and
/// the conversion rows appear only when an invoice currency is set and that
/// rate is not a no-op.
List<Widget> expenseInvoicingRows(
  BuildContext context, {
  required String invoiceId,
  required String invoiceNumber,
  required bool shouldBeInvoiced,
  required bool invoiceDocuments,
  required String invoiceCurrencyId,
  required Decimal exchangeRate,
  required Formatter? formatter,
}) {
  final open = LinkedRecordOpener(context);
  final hasConversion =
      invoiceCurrencyId.isNotEmpty && exchangeRate != Decimal.one;
  return [
    if (invoiceId.isNotEmpty)
      linkedRecordRow(
        label: context.tr('invoice'),
        name: invoiceNumber.isEmpty ? '' : '#$invoiceNumber',
        onTap: open.to(
          EntityType.invoice,
          'view_invoice',
          '/invoices',
          invoiceId,
        ),
      ),
    if (shouldBeInvoiced && invoiceId.isEmpty)
      DetailInfoRow(
        label: context.tr('should_be_invoiced'),
        value: context.tr('yes'),
        copyable: false,
      ),
    if (invoiceDocuments)
      DetailInfoRow(
        label: context.tr('invoice_documents'),
        value: context.tr('yes'),
        copyable: false,
      ),
    if (hasConversion) ...[
      DetailInfoRow(
        label: context.tr('invoice_currency'),
        value:
            context
                .read<Services>()
                .statics
                .currency(invoiceCurrencyId)
                ?.name ??
            invoiceCurrencyId,
        copyable: false,
      ),
      DetailInfoRow(
        label: context.tr('exchange_rate'),
        value:
            formatter?.decimal(exchangeRate.toDouble(), maxDecimals: 6) ??
            exchangeRate.toString(),
        monospace: true,
      ),
    ],
  ];
}

/// How it was paid. Shown for any of the three fields — a payment type alone
/// does not make an expense "paid", but it is still what the user entered —
/// and for the bank transaction the expense was created from or matched to,
/// where the company uses that module at all.
List<Widget> expensePaymentRows(
  BuildContext context, {
  required Date? paymentDate,
  required String paymentTypeId,
  required String transactionReference,
  required String transactionId,
  required String transactionName,
  required Formatter? formatter,
}) {
  final open = LinkedRecordOpener(context);
  return [
    // Never the raw ISO date: it waits for the company's format.
    if (paymentDate != null && formatter != null)
      DetailInfoRow(
        label: context.tr('payment_date'),
        value: formatter.date(paymentDate.toIso()),
        copyable: false,
      ),
    if (paymentTypeId.isNotEmpty)
      DetailInfoRow(
        label: context.tr('payment_type'),
        // The id resolved to its name ("Credit Card") — the lookup the edit
        // form uses.
        value:
            context.read<Services>().statics.paymentType(paymentTypeId)?.name ??
            paymentTypeId,
        copyable: false,
      ),
    if (transactionReference.isNotEmpty)
      DetailInfoRow(
        label: context.tr('transaction_reference'),
        value: transactionReference,
      ),
    if (transactionId.isNotEmpty && open.moduleOn(EntityType.transaction))
      linkedRecordRow(
        label: context.tr('transaction'),
        name: transactionName,
        onTap: open.to(
          EntityType.transaction,
          'view_bank_transaction',
          '/transactions',
          transactionId,
        ),
      ),
  ];
}

/// One tax line on an expense.
typedef ExpenseTaxTier = ({String name, Decimal rate, Decimal amount});

/// The label for a tax with no name of its own, by slot.
const List<String> _kTaxRateKeys = ['tax_rate1', 'tax_rate2', 'tax_rate3'];

/// The Taxes card's rows: one per tax that is set, then how the amount
/// relates to them.
///
/// A tier is drawn when it has a name, a rate or an amount. In by-amount mode
/// the rate is zero, so the row shows the amount alone — a "0% ·" in front of
/// it would misdescribe a fixed-amount tax.
///
/// "Inclusive Taxes" appears only when it is on, and only beside a tax: it is
/// a statement about the taxes above it, and on its own it is a setting.
List<Widget> expenseTaxRows(
  BuildContext context, {
  required List<ExpenseTaxTier> tiers,
  required bool byAmount,
  required bool inclusive,
  required String Function(Decimal amount) money,
}) {
  assert(tiers.length <= _kTaxRateKeys.length);
  final rows = <Widget>[
    for (var i = 0; i < tiers.length; i++)
      if (tiers[i].name.isNotEmpty ||
          tiers[i].rate != Decimal.zero ||
          tiers[i].amount != Decimal.zero)
        DetailInfoRow(
          label: tiers[i].name.isEmpty
              ? context.tr(_kTaxRateKeys[i])
              : tiers[i].name,
          value: byAmount
              ? money(tiers[i].amount)
              : [
                  '${tiers[i].rate}%',
                  // Blank while the formatter loads; the rate still stands.
                  if (money(tiers[i].amount).isNotEmpty) money(tiers[i].amount),
                ].join(' · '),
          monospace: true,
        ),
  ];
  if (rows.isEmpty) return const [];
  return [
    ...rows,
    if (inclusive)
      DetailInfoRow(
        label: context.tr('inclusive_taxes'),
        value: context.tr('yes'),
        copyable: false,
      ),
  ];
}

/// The configured, type-formatted custom-field rows. A slot renders only when
/// the company has a label for it **and** the record has a value — a value
/// with no label is one nobody can name.
///
/// Recurring expenses use the expense custom fields: the company configures
/// one set for both.
List<Widget> expenseCustomFieldRows(
  BuildContext context, {
  required Company? company,
  required List<String> values,
  required Formatter? formatter,
}) {
  if (company == null || values.every((v) => v.isEmpty)) return const [];
  final rows = customFieldDetailRows(
    company: company,
    prefix: 'expense',
    values: values,
    formatter: formatter,
    yes: context.tr('yes'),
    no: context.tr('no'),
  );
  return [for (final r in rows) DetailInfoRow(label: r.label, value: r.value)];
}

/// Created / updated, for the foot of a Details card.
///
/// As local calendar days: these are UTC-backed server timestamps, and the
/// ISO date of the UTC instant is the wrong day across the boundary. Left out
/// until the formatter is here (never a raw ISO date), and for a record that
/// has not been to the server yet (epoch zero).
List<Widget> recordTimestampRows(
  BuildContext context, {
  required DateTime createdAt,
  required DateTime updatedAt,
  required Formatter? formatter,
}) {
  if (formatter == null) return const [];
  String? day(DateTime dt) => dt.millisecondsSinceEpoch == 0
      ? null
      : formatter.date(dt.toLocal().toIso8601String().split('T').first);
  final created = day(createdAt);
  final updated = day(updatedAt);
  return [
    if (created != null)
      DetailInfoRow(
        label: context.tr('created_at'),
        value: created,
        copyable: false,
      ),
    if (updated != null)
      DetailInfoRow(
        label: context.tr('updated_at'),
        value: updated,
        copyable: false,
      ),
  ];
}

/// Private + public notes. Renders either or both; builds nothing when both
/// are blank.
///
/// **Plain text, as stored.** An expense's notes are edited in a plain text
/// area in every client and are not one of the HTML-bearing fields
/// (`docs/rich-text-editing.md`), so they are neither flattened nor decoded
/// here — only trimmed, so a note of blank lines does not open a card.
class ExpenseNotesCard extends StatelessWidget {
  const ExpenseNotesCard({
    super.key,
    required this.privateNotes,
    required this.publicNotes,
  });

  final String privateNotes;
  final String publicNotes;

  /// Whether this card would draw anything — the same test [build] makes.
  static bool hasContent({
    required String privateNotes,
    required String publicNotes,
  }) => privateNotes.trim().isNotEmpty || publicNotes.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final private = privateNotes.trim();
    final public = publicNotes.trim();
    if (private.isEmpty && public.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(color: tokens.ink);
    return DashboardCardShell(
      title: context.tr('notes'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (private.isNotEmpty)
            _NotesBlock(
              label: context.tr('private_notes'),
              body: private,
              bodyStyle: bodyStyle,
            ),
          if (private.isNotEmpty && public.isNotEmpty) ...[
            SizedBox(height: InSpacing.md(context)),
            Divider(height: 1, thickness: 1, color: tokens.border),
            SizedBox(height: InSpacing.md(context)),
          ],
          if (public.isNotEmpty)
            _NotesBlock(
              label: context.tr('public_notes'),
              body: public,
              bodyStyle: bodyStyle,
            ),
        ],
      ),
    );
  }
}

/// Enough to read a typical note whole, short enough that an essay does not
/// take the page.
const int _kNoteLines = 6;

class _NotesBlock extends StatelessWidget {
  const _NotesBlock({
    required this.label,
    required this.body,
    required this.bodyStyle,
  });

  final String label;
  final String body;
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
            // `ink2`: `ink3` at this size is under the contrast floor on a
            // card.
            color: context.inTheme.ink2,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: InSpacing.xs),
        // A note has no length limit; unclamped, one long one decides where
        // everything below this card starts.
        ClampedText(text: body, maxLines: _kNoteLines, style: bodyStyle),
      ],
    );
  }
}
