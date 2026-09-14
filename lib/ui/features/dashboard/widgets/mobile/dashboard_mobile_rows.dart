import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_list_rows.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/ui/core/widgets/party_money_cell.dart';
import 'package:admin/ui/features/dashboard/view_models/billing_pipeline_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/status_badge.dart';
import 'package:admin/ui/features/invoices/widgets/invoice_status_pill.dart';
import 'package:admin/ui/features/quotes/widgets/quote_status_pill.dart';
import 'package:admin/utils/formatting.dart';

/// Mobile-stacked row widgets shared by the mobile dashboard cards. Each row
/// follows the same anatomy:
///
///   number + status pill on the top-left
///   client name beneath
///   amount + date stacked on the right
///
/// Lifted out of `mobile_dashboard_body.dart` so the body can focus on
/// layout composition. Status labels + tones are resolved via the statics on
/// `StatusBadge` so desktop and mobile stay in lock-step.

/// Stacked invoice row. When [alwaysOverdue] is true (used by the "Needs your
/// attention" card, already filtered to past-due), every row paints as
/// overdue. Otherwise overdue is derived from `statusId != paid && dueDate <
/// today`, matching `DashboardInvoiceTable._row` on desktop.
class MobileInvoiceRow extends StatelessWidget {
  const MobileInvoiceRow({
    super.key,
    required this.row,
    required this.formatter,
    required this.today,
    required this.onTap,
    this.alwaysOverdue = false,
  });

  final DashboardInvoiceRow row;
  final Formatter formatter;
  final Date today;
  final VoidCallback onTap;
  final bool alwaysOverdue;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final overdue =
        alwaysOverdue ||
        (row.statusId != 4 &&
            row.dueDate != null &&
            row.dueDate!.compareTo(today) < 0);
    final daysOverdue = (overdue && row.dueDate != null)
        ? today.differenceInDays(row.dueDate!)
        : null;
    final tone = StatusBadge.toneForInvoiceStatus(
      row.statusId,
      overdue: overdue,
    );
    final statusLabel = overdue && daysOverdue != null && daysOverdue > 0
        ? '${context.tr('overdue')} · ${daysOverdue}d'
        : StatusBadge.invoiceStatusLabel(
            context,
            row.statusId,
            overdue: overdue,
          );

    final dueText = row.dueDate != null
        ? formatter.date(row.dueDate!.toIso())
        : '—';
    final currencyKey = row.currencyId.isEmpty ? null : row.currencyId;
    final amountText = formatter.money(
      row.balance,
      clientCurrencyId: currencyKey,
    );

    return _RowShell(
      onTap: onTap,
      leading: _LeadingIdentity(
        number: row.number,
        client: Text(row.clientName),
        statusBadge: StatusBadge(tone: tone, label: statusLabel),
      ),
      trailing: _TrailingAmountDate(
        amountText: amountText,
        dateText: dueText,
        dateColor: overdue ? tokens.overdue : tokens.ink3,
      ),
    );
  }
}

/// Stacked payment row for the "Recent payments" card.
class MobilePaymentRow extends StatelessWidget {
  const MobilePaymentRow({
    super.key,
    required this.row,
    required this.formatter,
    required this.onTap,
  });

  final DashboardPaymentRow row;
  final Formatter formatter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final (statusLabel, statusTone) = StatusBadge.paymentStatus(
      context,
      row.statusId,
    );
    final dateText = row.date != null ? formatter.date(row.date!.toIso()) : '—';
    final currencyKey = row.currencyId.isEmpty ? null : row.currencyId;
    final amountText = formatter.money(row.amount, currencyId: currencyKey);

    return _RowShell(
      onTap: onTap,
      leading: _LeadingIdentity(
        number: row.number,
        client: Text(row.clientName),
        statusBadge: StatusBadge(tone: statusTone, label: statusLabel),
      ),
      trailing: _TrailingAmountDate(
        amountText: amountText,
        dateText: dateText,
        dateColor: tokens.ink3,
      ),
    );
  }
}

/// Stacked quote row for "Upcoming / Expired quotes" cards. When [expired]
/// is true the status pill becomes "Expired" with overdue tone and the date
/// switches to `validUntil`.
class MobileQuoteRow extends StatelessWidget {
  const MobileQuoteRow({
    super.key,
    required this.row,
    required this.formatter,
    required this.onTap,
    required this.expired,
  });

  final DashboardQuoteRow row;
  final Formatter formatter;
  final VoidCallback onTap;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final tone = StatusBadge.toneForQuoteStatus(row.statusId, expired: expired);
    final statusLabel = expired
        ? context.tr('expired')
        : StatusBadge.quoteStatusLabel(context, row.statusId);
    final dateSource = expired ? row.validUntil : row.date;
    final dateText = dateSource != null
        ? formatter.date(dateSource.toIso())
        : '—';
    final currencyKey = row.currencyId.isEmpty ? null : row.currencyId;
    final amountText = formatter.money(
      row.amount,
      clientCurrencyId: currencyKey,
    );

    return _RowShell(
      onTap: onTap,
      leading: _LeadingIdentity(
        number: row.number,
        client: Text(row.clientName),
        statusBadge: StatusBadge(tone: tone, label: statusLabel),
      ),
      trailing: _TrailingAmountDate(
        amountText: amountText,
        dateText: dateText,
        dateColor: expired ? tokens.overdue : tokens.ink3,
      ),
    );
  }
}

/// Stacked recurring-invoice row for "Upcoming recurring invoices". No
/// status pill — the cadence leads the row instead.
class MobileRecurringInvoiceRow extends StatelessWidget {
  const MobileRecurringInvoiceRow({
    super.key,
    required this.row,
    required this.formatter,
    required this.onTap,
  });

  final DashboardRecurringInvoiceRow row;
  final Formatter formatter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final nextText = row.nextSendDate != null
        ? formatter.date(row.nextSendDate!.toIso())
        : '—';
    final currencyKey = row.currencyId.isEmpty ? null : row.currencyId;
    final amountText = formatter.money(
      row.amount,
      clientCurrencyId: currencyKey,
    );

    return _RowShell(
      onTap: onTap,
      leading: _LeadingIdentity(
        number: row.number,
        client: Text(row.clientName),
        statusBadge: null,
      ),
      trailing: _TrailingAmountDate(
        amountText: amountText,
        dateText: nextText,
        dateColor: tokens.ink3,
      ),
    );
  }
}

// ── Internal shells ────────────────────────────────────────────────────

/// Stacked row for the consolidated Invoices & Quotes panel
/// (invoiceninja/flutter#155).
///
/// The one row here built from domain models rather than a cache-backed DTO, so
/// the client name resolves through [ClientNameLabel] instead of arriving
/// denormalized, and the status pill takes `calculatedStatusId` (past-due /
/// expired / viewed come out right for free).
///
/// [showType] names the source record on a tab where both entities
/// participate — inline in the number line, never as a third line.
class MobileBillingPipelineRow extends StatelessWidget {
  const MobileBillingPipelineRow({
    super.key,
    required this.row,
    required this.formatter,
    required this.showType,
    required this.onTap,
  });

  final BillingPipelineRow row;
  final Formatter formatter;
  final bool showType;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final isInvoice = row.type == EntityType.invoice;
    final dateText = row.date is Date
        ? formatter.date((row.date! as Date).toIso())
        : '—';
    final pillStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: tokens.ink,
    );

    return _RowShell(
      onTap: onTap,
      leading: _LeadingIdentity(
        number: row.number,
        numberPrefix: showType
            ? context.tr(isInvoice ? 'invoice' : 'quote')
            : null,
        client: ClientNameLabel(clientId: row.clientId),
        statusBadge: isInvoice
            ? InvoiceStatusPill(
                statusId: row.statusId,
                dotSize: 6,
                textStyle: pillStyle,
                hasBounce: row.hasBounce,
              )
            : QuoteStatusPill(
                statusId: row.statusId,
                dotSize: 6,
                textStyle: pillStyle,
                hasBounce: row.hasBounce,
              ),
      ),
      trailing: PartyCurrencyBuilder(
        clientId: row.clientId,
        builder: (context, currencyId) => _TrailingAmountDate(
          amountText: formatter.money(
            row.amount as Decimal,
            clientCurrencyId: currencyId,
          ),
          dateText: dateText,
          dateColor: tokens.ink3,
        ),
      ),
    );
  }
}

class _RowShell extends StatelessWidget {
  const _RowShell({
    required this.onTap,
    required this.leading,
    required this.trailing,
  });

  final VoidCallback onTap;
  final Widget leading;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: leading),
            const SizedBox(width: 10),
            // Cap the amount/date column so an exotic long amount ellipsizes
            // instead of overflowing the row on a narrow phone. Short amounts
            // (the common case) stay intrinsic and leave the rest to `leading`.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: trailing,
            ),
          ],
        ),
      ),
    );
  }
}

class _LeadingIdentity extends StatelessWidget {
  const _LeadingIdentity({
    required this.number,
    required this.client,
    required this.statusBadge,
    this.numberPrefix,
  });

  final String number;

  /// The client line. A **widget**, not a string: the dashboard's cache-backed
  /// rows carry a denormalized `clientName`, while a Drift-backed panel has
  /// only a `clientId` and must resolve it through `ClientNameLabel`. Styling
  /// stays here — see the `DefaultTextStyle` in [build] — so a label that
  /// brings its own lighter fallback still reads like its four siblings.
  final Widget client;

  final Widget? statusBadge;

  /// Prepended to the number, `Invoice · INV-2041`, to name the source record
  /// on a list that mixes two entities. Inline rather than a third line: the
  /// row is ~63 px and a third line takes five rows from ~315 to ~425 px.
  final String? numberPrefix;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final label = number.isEmpty ? '—' : number;
    final numberText = Text(
      numberPrefix == null ? label : '$numberPrefix · $label',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 11.5),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (statusBadge != null)
          Row(
            children: [
              Flexible(child: numberText),
              const SizedBox(width: 8),
              statusBadge!,
            ],
          )
        else
          numberText,
        const SizedBox(height: 3),
        // The style lives here, not in the caller's widget: `ClientNameLabel`'s
        // own fallback is `13 / ink3`, a lighter colour and weight, so without
        // this the panel's row would read subtly unlike its four siblings.
        DefaultTextStyle.merge(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: tokens.ink,
          ),
          child: client,
        ),
      ],
    );
  }
}

class _TrailingAmountDate extends StatelessWidget {
  const _TrailingAmountDate({
    required this.amountText,
    required this.dateText,
    required this.dateColor,
  });

  final String amountText;
  final String dateText;
  final Color dateColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          amountText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: moneyTextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: tokens.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          dateText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10.5, color: dateColor),
        ),
      ],
    );
  }
}
