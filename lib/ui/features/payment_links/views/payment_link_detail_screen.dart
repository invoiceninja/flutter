import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/payment_link.dart';
import 'package:admin/data/models/domain/recurring_invoice.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/recurring_frequency.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/core/utils/external_url.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/invoices/widgets/invoice_status_pill.dart';
import 'package:admin/ui/features/payment_links/view_models/payment_link_detail_view_model.dart';
import 'package:admin/ui/features/payment_links/widgets/detail/payment_link_detail_actions_row.dart';
import 'package:admin/ui/features/payment_links/widgets/detail/payment_link_detail_header.dart';
import 'package:admin/ui/features/recurring_invoices/widgets/recurring_invoice_status_pill.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/utils/url_safety.dart';

/// Read-only Payment Link detail screen. Reached only via the Settings
/// sidebar. Body wraps [SettingsFormShell] so widths line up with the
/// rest of /settings, then renders the canonical detail header followed
/// by a single overview card (name + price + frequency + purchase page).
class PaymentLinkDetailScreen extends StatefulWidget {
  const PaymentLinkDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<PaymentLinkDetailScreen> createState() =>
      _PaymentLinkDetailScreenState();
}

class _PaymentLinkDetailScreenState extends State<PaymentLinkDetailScreen>
    with FormatterHostMixin {
  late final PaymentLinkDetailViewModel _vm;
  late final Services _services;
  late final String _companyId;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = PaymentLinkDetailViewModel.bound(
      _services.paymentLinks.watch(companyId: _companyId, id: widget.id),
    );
    loadFormatter(_services, _companyId);
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EntityDetailScaffold<PaymentLink>(
      id: widget.id,
      vm: _vm,
      hydrate: () => _services.paymentLinks.ensureLoaded(
        companyId: _companyId,
        id: widget.id,
      ),
      emptyAction: entityListEmptyAction(context, EntityType.paymentLink),
      emptyIcon: Icons.link_outlined,
      emptyTitle: context.tr('payment_link'),
      actionsForItem: (context, paymentLink) =>
          PaymentLinkDetailActionsRow(paymentLink: paymentLink),
      bodyBuilder: (context, paymentLink) {
        return SettingsFormShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PaymentLinkDetailHeader(
                paymentLink: paymentLink,
                formatter: formatter,
              ),
              SizedBox(height: InSpacing.xl),
              _OverviewCard(paymentLink: paymentLink, formatter: formatter),
              // Each related card owns its own leading gap and renders
              // nothing when empty, so a payment link with no invoices shows
              // no placeholder card (and no stray spacer).
              _RelatedInvoicesCard(
                services: _services,
                companyId: _companyId,
                subscriptionId: paymentLink.id,
                formatter: formatter,
              ),
              _RelatedRecurringInvoicesCard(
                services: _services,
                companyId: _companyId,
                subscriptionId: paymentLink.id,
                formatter: formatter,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.paymentLink, required this.formatter});

  final PaymentLink paymentLink;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final freqKey = kRecurringFrequencyLabelKey[paymentLink.frequencyId];
    final priceText = formatter == null
        ? '—'
        : formatter!.money(paymentLink.price);
    return FormSection(
      title: context.tr('overview'),
      spacing: 0,
      children: [
        if (paymentLink.name.isNotEmpty)
          _KeyValue(labelKey: 'name', value: paymentLink.name),
        _KeyValue(labelKey: 'price', value: priceText),
        if (freqKey != null)
          _KeyValue(labelKey: 'frequency', value: context.tr(freqKey)),
        if (paymentLink.purchasePage.isNotEmpty)
          _PurchasePageRow(url: paymentLink.purchasePage),
      ],
    );
  }
}

/// Narrower label column on small phones so long values / URLs keep a usable
/// amount of horizontal space instead of being squeezed by a fixed 140px gutter.
double _detailLabelWidth(double maxWidth) => maxWidth < 380 ? 100 : 140;

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.labelKey, required this.value});

  final String labelKey;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: InSpacing.sm),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _detailLabelWidth(constraints.maxWidth),
              child: Text(
                context.tr(labelKey),
                style: theme.textTheme.bodySmall?.copyWith(color: tokens.ink3),
              ),
            ),
            Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
          ],
        ),
      ),
    );
  }
}

class _PurchasePageRow extends StatelessWidget {
  const _PurchasePageRow({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final hasUrl = url.isNotEmpty;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: InSpacing.sm),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: _detailLabelWidth(constraints.maxWidth),
              child: Text(
                context.tr('purchase_page'),
                style: theme.textTheme.bodySmall?.copyWith(color: tokens.ink3),
              ),
            ),
            Expanded(
              child: Text(
                hasUrl ? url : '—',
                style: theme.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasUrl && isSafeWebUrl(url))
              IconButton(
                icon: const Icon(Icons.open_in_new, size: 18),
                tooltip: context.tr('view'),
                onPressed: () => _open(context),
              ),
            if (hasUrl)
              IconButton(
                icon: const Icon(Icons.copy_outlined, size: 18),
                tooltip: context.tr('copy'),
                onPressed: () => copyToClipboard(context, url),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) => openExternalUrl(context, url);
}

/// Embedded "Invoices" card — invoices this payment link generated, filtered
/// locally by `subscription_id`. Mirrors admin-portal's subscription view,
/// which surfaced the same related lists. Reads local Drift (no extra fetch),
/// same as the Client detail invoices card.
class _RelatedInvoicesCard extends StatelessWidget {
  const _RelatedInvoicesCard({
    required this.services,
    required this.companyId,
    required this.subscriptionId,
    required this.formatter,
  });

  final Services services;
  final String companyId;
  final String subscriptionId;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    return WatchBuilder<List<Invoice>>(
      cacheKey: (companyId, subscriptionId),
      create: () => services.invoices.watchForSubscription(
        companyId: companyId,
        subscriptionId: subscriptionId,
      ),
      builder: (context, snapshot) {
        final invoices = snapshot.data ?? const <Invoice>[];
        if (invoices.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.only(top: InSpacing.lg(context)),
          child: FormSection(
            title: context.tr('invoices'),
            spacing: 0,
            children: [
              for (final inv in invoices)
                _RelatedEntityRow(
                  number: inv.number,
                  amountText: formatter?.money(inv.amount) ?? '—',
                  statusPill: InvoiceStatusPill(
                    statusId: inv.calculatedStatusId,
                    hasBounce: inv.hasBouncedInvitation,
                  ),
                  onTap: () => context.go('/invoices/${inv.id}'),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Embedded "Recurring Invoices" card — recurring invoices belonging to the
/// payment link (filtered locally by `subscription_id`).
class _RelatedRecurringInvoicesCard extends StatelessWidget {
  const _RelatedRecurringInvoicesCard({
    required this.services,
    required this.companyId,
    required this.subscriptionId,
    required this.formatter,
  });

  final Services services;
  final String companyId;
  final String subscriptionId;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    return WatchBuilder<List<RecurringInvoice>>(
      cacheKey: (companyId, subscriptionId),
      create: () => services.recurringInvoices.watchForSubscription(
        companyId: companyId,
        subscriptionId: subscriptionId,
      ),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <RecurringInvoice>[];
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.only(top: InSpacing.lg(context)),
          child: FormSection(
            title: context.tr('recurring_invoices'),
            spacing: 0,
            children: [
              for (final ri in items)
                _RelatedEntityRow(
                  number: ri.number,
                  amountText: formatter?.money(ri.amount) ?? '—',
                  statusPill: RecurringInvoiceStatusPill(
                    statusId: ri.calculatedStatusId,
                  ),
                  onTap: () => context.go('/recurring_invoices/${ri.id}'),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One tappable row inside a related-entity card — number on the left, an
/// optional status pill, and the amount on the right. Tapping opens the
/// entity's detail screen.
class _RelatedEntityRow extends StatelessWidget {
  const _RelatedEntityRow({
    required this.number,
    required this.amountText,
    required this.onTap,
    this.statusPill,
  });

  final String number;
  final String amountText;
  final VoidCallback onTap;
  final Widget? statusPill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: InSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                number.isEmpty ? '—' : number,
                style: theme.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (statusPill != null) ...[
              SizedBox(width: InSpacing.md(context)),
              statusPill!,
            ],
            SizedBox(width: InSpacing.md(context)),
            Text(amountText, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
