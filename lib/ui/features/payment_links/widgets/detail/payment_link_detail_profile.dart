import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/payment_link.dart';
import 'package:admin/data/models/domain/recurring_invoice.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/recurring_frequency.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/external_url.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/invoices/widgets/invoice_status_pill.dart';
import 'package:admin/ui/features/payment_links/widgets/detail/payment_link_detail_standing.dart';
import 'package:admin/ui/features/recurring_invoices/widgets/recurring_invoice_status_pill.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/utils/url_safety.dart';

/// A payment link's reference fields, and the documents it has produced:
/// Details, then Invoices and Recurring Invoices when there are any.
///
/// The Details card used to stop at name, price, frequency and purchase page;
/// finding out whether a link auto-bills, how long its trial runs or what its
/// promo code is meant opening it for editing.
///
/// **Details is gated on having rows** (derived from the list it draws). The
/// two related cards are streams, so each **owns its leading gap** and builds
/// nothing while empty — a gap paid here would be paid for a card that then
/// draws nothing.
class PaymentLinkDetailProfile extends StatelessWidget {
  const PaymentLinkDetailProfile({
    super.key,
    required this.paymentLink,
    required this.companyId,
    this.formatter,
  });

  final PaymentLink paymentLink;
  final String companyId;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final rows = PaymentLinkDetailsCard.rowsFor(
      context,
      paymentLink,
      formatter: formatter,
    );
    final services = context.read<Services>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (rows.isNotEmpty)
          DashboardCardShell(
            title: context.tr('details'),
            child: DetailRowStack(children: rows),
          ),
        _RelatedCard<Invoice>(
          // Invoices this payment link generated, filtered locally by
          // `subscription_id` — local Drift, no extra fetch.
          cacheKey: ('invoices', companyId, paymentLink.id),
          title: context.tr('invoices'),
          leadingGap: rows.isNotEmpty,
          create: () => services.invoices.watchForSubscription(
            companyId: companyId,
            subscriptionId: paymentLink.id,
          ),
          rowBuilder: (context, inv) => _RelatedRow(
            number: inv.number,
            amount: formatter?.money(inv.amount) ?? '',
            pill: InvoiceStatusPill(
              statusId: inv.calculatedStatusId,
              hasBounce: inv.hasBouncedInvitation,
            ),
            onTap: _opener(context, EntityType.invoice, '/invoices', inv.id),
          ),
        ),
        _RelatedCard<RecurringInvoice>(
          cacheKey: ('recurring_invoices', companyId, paymentLink.id),
          title: context.tr('recurring_invoices'),
          leadingGap: true,
          create: () => services.recurringInvoices.watchForSubscription(
            companyId: companyId,
            subscriptionId: paymentLink.id,
          ),
          rowBuilder: (context, ri) => _RelatedRow(
            number: ri.number,
            amount: formatter?.money(ri.amount) ?? '',
            pill: RecurringInvoiceStatusPill(statusId: ri.calculatedStatusId),
            onTap: _opener(
              context,
              EntityType.recurringInvoice,
              '/recurring_invoices',
              ri.id,
            ),
          ),
        ),
      ],
    );
  }

  /// Opens the record's full-screen **view** — never an edit screen. Null
  /// (a plain row) when the module is off or the user may not view it.
  VoidCallback? _opener(
    BuildContext context,
    EntityType type,
    String basePath,
    String id,
  ) {
    final me = context.read<Services>().auth.session.value?.currentCompany;
    final permission = type == EntityType.invoice
        ? 'view_invoice'
        : 'view_recurring_invoice';
    final allowed =
        (me?.moduleEnabled(type) ?? false) && (me?.can(permission) ?? false);
    return allowed ? () => goEntityFullDetail(context, basePath, id) : null;
  }
}

/// The rows of a payment link's Details card, in display order. A row exists
/// only for a setting that is actually set.
abstract final class PaymentLinkDetailsCard {
  static List<Widget> rowsFor(
    BuildContext context,
    PaymentLink link, {
    Formatter? formatter,
  }) {
    final freqKey = kRecurringFrequencyLabelKey[link.frequencyId];
    final url = link.purchasePage;
    // "30 Days": the bare unit word, which every bundle has as a noun.
    String days(int seconds) {
      final n = seconds ~/ 86400;
      return '$n ${context.tr(n == 1 ? 'day' : 'days')}';
    }

    String promoDiscount() => link.isAmountDiscount
        ? PaymentLinkDetailStanding.formatMoney(
            link.promoDiscount,
            link,
            formatter,
          )
        : '${link.promoDiscount}%';
    // The local calendar day: these are UTC-backed server timestamps, and the
    // ISO date of the UTC instant is the wrong day across the boundary.
    String? day(DateTime dt) =>
        formatter == null || dt.millisecondsSinceEpoch == 0
        ? null
        : formatter.date(dt.toLocal().toIso8601String().split('T').first);
    final created = day(link.createdAt);
    final updated = day(link.updatedAt);
    final discount = link.promoDiscount == Decimal.zero ? '' : promoDiscount();
    return [
      if (url.isNotEmpty)
        DetailInfoRow(
          label: context.tr('purchase_page'),
          value: url,
          onTap: isSafeWebUrl(url) ? () => openExternalUrl(context, url) : null,
          // What the tap does, for a screen reader: the value alone is a URL.
          semanticsLabel: isSafeWebUrl(url)
              ? '${context.tr('purchase_page')}: ${context.tr('open')}'
              : null,
          tooltip: isSafeWebUrl(url) && !Env.isTouchPrimary
              ? context.tr('open')
              : null,
        ),
      DetailInfoRow(
        label: context.tr('frequency'),
        value: context.tr(freqKey ?? 'once'),
        copyable: false,
      ),
      // Cycles only mean something on a link that repeats.
      if (freqKey != null)
        DetailInfoRow(
          label: context.tr('remaining_cycles'),
          value: link.remainingCycles < 0
              ? context.tr('endless')
              : '${link.remainingCycles}',
          copyable: false,
        ),
      if (link.autoBill.isNotEmpty)
        DetailInfoRow(
          label: context.tr('auto_bill'),
          value: context.tr(link.autoBill),
          copyable: false,
        ),
      if (link.promoCode.isNotEmpty)
        DetailInfoRow(label: context.tr('promo_code'), value: link.promoCode),
      if (link.promoCode.isNotEmpty && discount.isNotEmpty)
        DetailInfoRow(
          label: context.tr('promo_discount'),
          value: discount,
          copyable: false,
        ),
      if (link.trialEnabled && link.trialDuration > 0)
        DetailInfoRow(
          label: context.tr('trial_duration'),
          value: days(link.trialDuration),
          copyable: false,
        ),
      if (link.allowCancellation && link.refundPeriod > 0)
        DetailInfoRow(
          label: context.tr('refund_period'),
          value: days(link.refundPeriod),
          copyable: false,
        ),
      if (link.perSeatEnabled && link.maxSeatsLimit > 0)
        DetailInfoRow(
          label: context.tr('max_seats_limit'),
          value: '${link.maxSeatsLimit}',
          copyable: false,
        ),
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
}

/// A card listing the records a stream yields, built only while there are
/// some. Owns its leading gap — see [PaymentLinkDetailProfile].
class _RelatedCard<T> extends StatelessWidget {
  const _RelatedCard({
    required this.cacheKey,
    required this.title,
    required this.leadingGap,
    required this.create,
    required this.rowBuilder,
  });

  final Object cacheKey;
  final String title;
  final bool leadingGap;
  final Stream<List<T>> Function() create;
  final Widget Function(BuildContext context, T item) rowBuilder;

  @override
  Widget build(BuildContext context) {
    return WatchBuilder<List<T>>(
      cacheKey: cacheKey,
      create: create,
      builder: (context, snapshot) {
        final items = snapshot.data ?? <T>[];
        if (items.isEmpty) return const SizedBox.shrink();
        final tokens = context.inTheme;
        return Padding(
          padding: EdgeInsets.only(top: leadingGap ? InSpacing.md(context) : 0),
          child: DashboardCardShell(
            title: title,
            // The colour is painted by the shell; a transparent `Material`
            // gives the rows' ink something to draw on.
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, thickness: 1, color: tokens.border),
                    rowBuilder(context, items[i]),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One row inside a related card — number, status, amount. The row is the
/// link to its record when the user may open it.
class _RelatedRow extends StatelessWidget {
  const _RelatedRow({
    required this.number,
    required this.amount,
    required this.pill,
    required this.onTap,
  });

  final String number;
  final String amount;
  final Widget pill;

  /// Null draws a plain row — the user may not open the record.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final label = number.isEmpty ? context.tr('no_name_fallback') : '#$number';
    final row = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: Env.isTouchPrimary ? InSizes.touchTarget : 36,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: onTap == null ? tokens.ink : tokens.accentInk,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: InSpacing.sm),
          pill,
          const SizedBox(width: InSpacing.sm),
          Text(
            amount,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: tokens.ink, fontWeight: FontWeight.w600)
                .merge(moneyTextStyle()),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: '$label $amount',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(InRadii.r1),
        child: row,
      ),
    );
  }
}
