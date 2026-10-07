import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/color_hex.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/custom_field_detail_rows.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/core/widgets/detail_row_columns.dart';
import 'package:admin/ui/core/widgets/party_money_cell.dart';
import 'package:admin/ui/core/widgets/user_name_label.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/formatting.dart';

/// "Details" card on the project screen — what the edit form can set and
/// nothing else on the screen already says. Blank rows are omitted (no dash
/// placeholder), and a card with no rows builds nothing.
///
/// Not here, because each has a better home: the client and the number are
/// the header's subtitle, tags sit under the name, budgeted hours is a figure
/// on the standing card, and the notes have a card of their own.
///
/// [company] supplies the custom-field labels. It is handed in rather than
/// watched here because the profile needs the same answer twice — this card
/// draws the rows, and the profile has to know whether there are any before
/// it gives the card a column.
class ProjectDetailDetailsCard extends StatelessWidget {
  const ProjectDetailDetailsCard({
    super.key,
    required this.project,
    this.company,
    this.formatter,
  });

  final Project project;

  /// Null while the company row is still loading — custom fields wait for it.
  final Company? company;

  /// Null (still loading) leaves the dates out and prints money as a bare
  /// number, which is still the right number.
  final Formatter? formatter;

  /// Whether the card draws anything. **Derived from [rowsFor]**, the list
  /// [build] renders, so the two cannot drift.
  static bool hasContent(
    BuildContext context,
    Project project,
    Company? company, {
    Formatter? formatter,
  }) => rowsFor(context, project, company, formatter: formatter).isNotEmpty;

  /// The rows, in display order.
  static List<Widget> rowsFor(
    BuildContext context,
    Project project,
    Company? company, {
    Formatter? formatter,
  }) {
    final p = project;
    final due = p.dueDate;
    return [
      // Not until the formatter is here: a raw ISO date is not how this
      // company reads dates, and the row arrives with the rest a frame later.
      if (due != null && formatter != null)
        DetailInfoRow(
          label: context.tr('due_date'),
          value: formatter.date(due.toIso()),
          copyable: false,
        ),
      if (p.assignedUserId.isNotEmpty)
        DetailInfoRow(
          label: context.tr('assigned_user'),
          value: '',
          copyable: false,
          child: UserNameLabel(userId: p.assignedUserId),
        ),
      // A stored zero is "no rate of its own" — the tasks then bill at the
      // client's or the company's — so there is nothing to print.
      if (p.taskRate != Decimal.zero)
        _MoneyRow(
          labelKey: 'task_rate',
          amount: p.taskRate,
          clientId: p.clientId,
          formatter: formatter,
        ),
      // Likewise optional: blank means "budgeted hours × task rate".
      if (p.budgetedAmount != Decimal.zero)
        _MoneyRow(
          labelKey: 'budgeted_amount',
          amount: p.budgetedAmount,
          clientId: p.clientId,
          formatter: formatter,
        ),
      if (p.color.isNotEmpty)
        DetailInfoRow(
          label: context.tr('color'),
          value: p.color,
          monospace: true,
          trailing: Padding(
            // 2 down: the row is top-aligned and the swatch is shorter than
            // the line of text it sits beside.
            padding: const EdgeInsets.only(left: InSpacing.sm, top: 2),
            child: _ColorSwatch(hex: p.color),
          ),
        ),
      ..._customRows(context, p, company, formatter),
      ..._timestampRows(context, p, formatter),
    ];
  }

  /// The configured, type-formatted custom-field rows. A slot renders only
  /// when the company has a label for it AND the project has a value.
  static List<Widget> _customRows(
    BuildContext context,
    Project p,
    Company? company,
    Formatter? formatter,
  ) {
    final rows = customFieldDetailRows(
      company: company,
      prefix: 'project',
      values: [p.customValue1, p.customValue2, p.customValue3, p.customValue4],
      formatter: formatter,
      yes: context.tr('yes'),
      no: context.tr('no'),
    );
    return [
      for (final r in rows) DetailInfoRow(label: r.label, value: r.value),
    ];
  }

  /// Created / updated, at the foot: the two facts about a record a user
  /// wants least often, and until now the line under its name.
  static List<Widget> _timestampRows(
    BuildContext context,
    Project p,
    Formatter? formatter,
  ) {
    if (formatter == null) return const [];
    // The local calendar day: these are UTC-backed server timestamps, and the
    // ISO date of the UTC instant is the wrong day across the boundary.
    String? day(DateTime dt) => dt.millisecondsSinceEpoch == 0
        ? null
        : formatter.date(dt.toLocal().toIso8601String().split('T').first);
    final created = day(p.createdAt);
    final updated = day(p.updatedAt);
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

  @override
  Widget build(BuildContext context) {
    final rows = rowsFor(context, project, company, formatter: formatter);
    if (rows.isEmpty) return const SizedBox.shrink();
    return DashboardCardShell(
      title: context.tr('details'),
      child: DetailRowColumns(children: rows),
    );
  }
}

/// An amount in the currency the project's client is billed in — through
/// `PartyCurrencyBuilder`, the client → group → company cascade, like the
/// standing card above it. A project with no client is in the company's.
class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.labelKey,
    required this.amount,
    required this.clientId,
    required this.formatter,
  });

  final String labelKey;
  final Decimal amount;
  final String clientId;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final f = formatter;
    if (f == null) {
      return DetailInfoRow(
        label: context.tr(labelKey),
        value: amount.toString(),
        monospace: true,
        copyable: false,
      );
    }
    return PartyCurrencyBuilder(
      clientId: clientId,
      builder: (context, currencyId) => DetailInfoRow(
        label: context.tr(labelKey),
        value: f.money(amount, clientCurrencyId: currencyId),
        monospace: true,
        copyable: false,
      ),
    );
  }
}

/// The project's colour, as the kanban and the calendar draw it.
class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.hex});

  final String hex;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: parseHexColor(hex) ?? Colors.transparent,
        borderRadius: BorderRadius.circular(InRadii.r1 / 2),
        border: Border.all(color: context.inTheme.border),
      ),
    );
  }
}
