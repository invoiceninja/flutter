import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/custom_field_detail_rows.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/core/widgets/detail_row_columns.dart';
import 'package:admin/ui/core/widgets/invoice_name_label.dart';
import 'package:admin/ui/core/widgets/user_name_label.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/formatting.dart';

/// "Details" card on the task screen — the reference fields nothing else on
/// the screen already says. Blank rows are omitted (no dash placeholder), and
/// a card with no rows builds nothing.
///
/// Not here, because each has a better home: the client, the project and the
/// number are the header's subtitle, tags sit under the name, and the
/// duration, rate, estimate and status are the standing card.
///
/// [company] supplies the custom-field labels. It is handed in rather than
/// watched here because the profile needs the same answer twice — this card
/// draws the rows, and the profile has to know whether there are any before
/// it gives the card a column.
class TaskDetailDetailsCard extends StatelessWidget {
  const TaskDetailDetailsCard({
    super.key,
    required this.task,
    this.company,
    this.formatter,
  });

  final Task task;

  /// Null while the company row is still loading — custom fields wait for it.
  final Company? company;

  /// Null (still loading) leaves the dates out.
  final Formatter? formatter;

  /// Whether the card draws anything. **Derived from [rowsFor]**, the list
  /// [build] renders, so the two cannot drift.
  static bool hasContent(
    BuildContext context,
    Task task,
    Company? company, {
    Formatter? formatter,
  }) => rowsFor(context, task, company, formatter: formatter).isNotEmpty;

  /// The rows, in display order.
  static List<Widget> rowsFor(
    BuildContext context,
    Task task,
    Company? company, {
    Formatter? formatter,
  }) {
    final t = task;
    final due = t.dueDate;
    return [
      if (t.assignedUserId.isNotEmpty)
        DetailInfoRow(
          label: context.tr('assigned_user'),
          value: '',
          copyable: false,
          child: UserNameLabel(userId: t.assignedUserId),
        ),
      // The day the work is promised for. A date only — the booked *time*
      // lives in the time log (`docs/task-scheduling.md`).
      // Not until the formatter is here: a raw ISO date is not how this
      // company reads dates.
      if (due != null && formatter != null)
        DetailInfoRow(
          label: context.tr('due_date'),
          value: formatter.date(due.toIso()),
          copyable: false,
        ),
      // An invoiced task is locked; this is the way to the invoice that
      // locked it. The row used to read just "Invoiced", which says that and
      // not which.
      if (t.isInvoiced) _InvoiceRow(invoiceId: t.invoiceId),
      ..._customRows(context, t, company, formatter),
      ..._timestampRows(context, t, formatter),
    ];
  }

  /// The configured, type-formatted custom-field rows. A slot renders only
  /// when the company has a label for it AND the task has a value.
  static List<Widget> _customRows(
    BuildContext context,
    Task t,
    Company? company,
    Formatter? formatter,
  ) {
    final rows = customFieldDetailRows(
      company: company,
      prefix: 'task',
      values: [t.customValue1, t.customValue2, t.customValue3, t.customValue4],
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
    Task t,
    Formatter? formatter,
  ) {
    if (formatter == null) return const [];
    // The local calendar day: these are UTC-backed server timestamps, and the
    // ISO date of the UTC instant is the wrong day across the boundary.
    String? day(DateTime dt) => dt.millisecondsSinceEpoch == 0
        ? null
        : formatter.date(dt.toLocal().toIso8601String().split('T').first);
    final created = day(t.createdAt);
    final updated = day(t.updatedAt);
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
    final rows = rowsFor(context, task, company, formatter: formatter);
    if (rows.isEmpty) return const SizedBox.shrink();
    return DashboardCardShell(
      title: context.tr('details'),
      child: DetailRowColumns(children: rows),
    );
  }
}

/// The invoice the task was billed on, by number — a link to that invoice for
/// a user who may view invoices (and has the module), plain text otherwise.
class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context) {
    final me = context.read<Services>().auth.session.value?.currentCompany;
    final canOpen =
        (me?.moduleEnabled(EntityType.invoice) ?? false) &&
        (me?.can('view_invoice') ?? false);
    return DetailInfoRow(
      label: context.tr('invoice'),
      value: '',
      copyable: false,
      child: InvoiceNameLabel(invoiceId: invoiceId, link: canOpen),
    );
  }
}
