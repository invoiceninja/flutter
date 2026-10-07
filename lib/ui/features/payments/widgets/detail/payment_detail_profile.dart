import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_gateway.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/detail/custom_field_detail_rows.dart';
import 'package:admin/ui/core/widgets/clamped_text.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/core/widgets/detail_row_columns.dart';
import 'package:admin/ui/core/widgets/user_name_label.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/projects/widgets/project_name_label.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/utils/notes_html.dart';

/// A payment's reference fields — how and when it was paid, where it came
/// from, the user's own note. Always shown, between the comments card and the
/// tabs.
///
/// The screen it replaces showed none of this: the type, the date, the
/// transaction reference and the note could only be read by opening the
/// payment for editing.
///
/// **Each card is gated on having content**, derived from the rows it draws,
/// so a card that would be a title over nothing is not given a gap.
///
/// Details is the only lead card a payment has, so on a wide window it runs
/// its rows in two columns rather than leaving four fifths of a full-width
/// card blank. The note stays full width beneath it.
class PaymentDetailProfile extends StatelessWidget {
  const PaymentDetailProfile({
    super.key,
    required this.payment,
    required this.company,
    this.formatter,
  });

  final Payment payment;

  /// For the custom-field labels. Null while the company row is loading.
  final Company? company;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    // The gateway's name is a stream (the payment carries only its id), and
    // whether there is a Gateway row decides whether there is a Details card
    // at all — so it is resolved here, once, and handed to both.
    if (payment.companyGatewayId.isEmpty) return _build(context, '');
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    return WatchBuilder<CompanyGateway?>(
      cacheKey: (companyId, payment.companyGatewayId),
      create: () => services.companyGateways.watch(
        companyId: companyId,
        id: payment.companyGatewayId,
      ),
      builder: (context, snapshot) {
        final gateway = snapshot.data;
        // Company gateway → `gatewayKey` → the statics `Gateway.name`,
        // falling back to the gateway's own label (the refund screen's
        // lookup). Never the raw id: an unresolved gateway is no row.
        final staticName =
            services.statics.gateways[gateway?.gatewayKey]?.name ?? '';
        return _build(
          context,
          staticName.isNotEmpty ? staticName : (gateway?.label ?? ''),
        );
      },
    );
  }

  Widget _build(BuildContext context, String gatewayName) {
    final hasDetails = PaymentDetailDetailsCard.hasContent(
      context,
      payment,
      company,
      formatter: formatter,
      gatewayName: gatewayName,
    );
    final hasNotes = PaymentDetailNotesCard.hasContent(payment);
    final gap = SizedBox(height: InSpacing.md(context));
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= Breakpoints.entityFormMultiColumn;
        final cards = <Widget>[
          if (hasDetails)
            PaymentDetailDetailsCard(
              payment: payment,
              company: company,
              formatter: formatter,
              gatewayName: gatewayName,
              columns: wide ? 2 : 1,
            ),
          if (hasNotes) PaymentDetailNotesCard(payment: payment),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) gap,
              cards[i],
            ],
          ],
        );
      },
    );
  }
}

/// "Details" on the payment record — number, date, type, reference, gateway,
/// conversion, custom fields. Blank rows are left out, and a card with no rows
/// builds nothing.
class PaymentDetailDetailsCard extends StatelessWidget {
  const PaymentDetailDetailsCard({
    super.key,
    required this.payment,
    this.company,
    this.formatter,
    this.gatewayName = '',
    this.columns = 1,
  });

  final Payment payment;
  final Company? company;
  final Formatter? formatter;

  /// The gateway that took the payment, by name — resolved by the profile.
  /// Empty (a manual payment, or one whose gateway is gone) draws no row.
  final String gatewayName;

  /// How many columns the rows run in — 2 when this card has a wide window's
  /// full width to itself. See `DetailRowColumns`.
  final int columns;

  /// Derived from [rowsFor], the list [build] renders, so the two cannot
  /// drift.
  static bool hasContent(
    BuildContext context,
    Payment payment,
    Company? company, {
    Formatter? formatter,
    String gatewayName = '',
  }) => rowsFor(
    context,
    payment,
    company,
    formatter: formatter,
    gatewayName: gatewayName,
  ).isNotEmpty;

  /// The rows, in display order.
  static List<Widget> rowsFor(
    BuildContext context,
    Payment payment,
    Company? company, {
    Formatter? formatter,
    String gatewayName = '',
  }) {
    final p = payment;
    final f = formatter;
    final statics = context.read<Services>().statics;
    final type = p.typeId.isEmpty
        ? ''
        : (statics.paymentType(p.typeId)?.name ?? '');
    final date = p.date;
    // A conversion is worth a row only when there is one: a foreign currency
    // named, and a rate that is not the identity (0 is the legacy "none").
    final converted =
        p.exchangeCurrencyId.isNotEmpty &&
        p.exchangeCurrencyId != p.currencyId &&
        p.effectiveExchangeRate != Decimal.one;
    return [
      if (p.number.isNotEmpty)
        DetailInfoRow(label: context.tr('number'), value: p.number),
      if (date != null && f != null)
        DetailInfoRow(
          label: context.tr('payment_date'),
          value: f.date(date.toIso()),
          copyable: false,
        ),
      if (type.isNotEmpty)
        DetailInfoRow(
          label: context.tr('payment_type'),
          value: type,
          copyable: false,
        ),
      if (p.transactionReference.isNotEmpty)
        DetailInfoRow(
          label: context.tr('transaction_reference'),
          value: p.transactionReference,
        ),
      // Assigned by the processor and never user-editable; here for
      // reference.
      if (gatewayName.isNotEmpty)
        DetailInfoRow(
          label: context.tr('gateway'),
          value: gatewayName,
          copyable: false,
        ),
      if (converted) ...[
        DetailInfoRow(
          label: context.tr('exchange_rate'),
          value:
              f?.decimal(p.exchangeRate.toDouble(), maxDecimals: 6) ??
              p.exchangeRate.toString(),
          copyable: false,
        ),
        if (f != null)
          DetailInfoRow(
            label: context.tr('converted_amount'),
            value: f.money(
              p.amount * p.effectiveExchangeRate,
              currencyId: p.exchangeCurrencyId,
            ),
            copyable: false,
          ),
      ],
      if (p.projectId.isNotEmpty)
        DetailInfoRow(
          label: context.tr('project'),
          value: '',
          copyable: false,
          child: ProjectNameLabel(
            projectId: p.projectId,
            style: _valueStyle(context),
          ),
        ),
      if (p.assignedUserId.isNotEmpty)
        DetailInfoRow(
          label: context.tr('assigned_user'),
          value: '',
          copyable: false,
          child: UserNameLabel(
            userId: p.assignedUserId,
            style: _valueStyle(context),
          ),
        ),
      ..._customRows(context, p, company),
      ..._timestampRows(context, p, f),
    ];
  }

  /// The value style `DetailInfoRow` gives a string, for a row whose value is
  /// a widget and so does not get it.
  static TextStyle? _valueStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall?.copyWith(
        color: context.inTheme.ink,
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
      );

  static List<Widget> _customRows(
    BuildContext context,
    Payment p,
    Company? company,
  ) {
    final values = [
      p.customValue1,
      p.customValue2,
      p.customValue3,
      p.customValue4,
    ];
    if (company == null || values.every((v) => v.isEmpty)) return const [];
    final services = context.read<Services>();
    final rows = customFieldDetailRows(
      company: company,
      prefix: 'payment',
      values: values,
      formatter: services.formatterIfReady(
        services.auth.session.value?.currentCompanyId ?? '',
      ),
      yes: context.tr('yes'),
      no: context.tr('no'),
    );
    return [
      for (final r in rows) DetailInfoRow(label: r.label, value: r.value),
    ];
  }

  /// Created / updated, at the foot — the two facts about a payment a user
  /// wants least often.
  static List<Widget> _timestampRows(
    BuildContext context,
    Payment p,
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
    final rows = rowsFor(
      context,
      payment,
      company,
      formatter: formatter,
      gatewayName: gatewayName,
    );
    if (rows.isEmpty) return const SizedBox.shrink();
    return DashboardCardShell(
      title: context.tr('details'),
      child: DetailRowColumns(columns: columns, children: rows),
    );
  }
}

/// The user's private note on the payment. Hidden when there are no words in
/// it — the field is free text, and markup that renders as nothing must not
/// open a card.
class PaymentDetailNotesCard extends StatelessWidget {
  const PaymentDetailNotesCard({super.key, required this.payment});

  final Payment payment;

  static bool hasContent(Payment payment) =>
      plainTextFromHtml(payment.privateNotes).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final notes = plainTextFromHtml(payment.privateNotes);
    if (notes.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    return DashboardCardShell(
      title: context.tr('private_notes'),
      // A note has no length limit; unclamped, one long one decides where
      // everything below this card starts.
      child: ClampedText(
        text: notes,
        maxLines: 6,
        style: theme.textTheme.bodyMedium?.copyWith(color: tokens.ink),
      ),
    );
  }
}
