import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_gateway.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/formatting.dart';

/// A gateway's reference fields: how it is set up, where its webhook lives,
/// what it asks a payer for and which payment methods it takes. Always shown.
///
/// **Each card is gated on having content**, derived from what it draws, so a
/// card that would be a title over nothing is not given a gap. Payment
/// Methods is the exception that proves it: a gateway with none enabled is
/// never offered to a payer, so that card says so rather than disappearing.
class CompanyGatewayDetailProfile extends StatelessWidget {
  const CompanyGatewayDetailProfile({
    super.key,
    required this.gateway,
    required this.company,
    this.formatter,
  });

  final CompanyGateway gateway;

  /// For the webhook URL, which is built from the company's key. Null while
  /// the company row is loading.
  final Company? company;

  /// For the created / updated dates. Null (still loading) leaves them out.
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final details = CompanyGatewayDetailsCard.rowsFor(
      context,
      gateway,
      company,
      formatter: formatter,
    );
    final required = CompanyGatewayRequiredFieldsCard.labelKeysFor(gateway);
    final cards = <Widget>[
      if (details.isNotEmpty)
        DashboardCardShell(
          title: context.tr('details'),
          child: DetailRowStack(children: details),
        ),
      CompanyGatewayPaymentMethodsCard(gateway: gateway),
      if (required.isNotEmpty)
        CompanyGatewayRequiredFieldsCard(gateway: gateway),
    ];
    final gap = SizedBox(height: InSpacing.md(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < cards.length; i++) ...[if (i > 0) gap, cards[i]],
      ],
    );
  }
}

/// The rows of the gateway's Details card — provider, Stripe account, token
/// billing, the webhook URL and the events it carries.
abstract final class CompanyGatewayDetailsCard {
  /// The inbound payment webhook URL merchants paste into the provider's
  /// dashboard: `{baseUrl}/payment_webhook/{company_key}/{gateway_id}`
  /// (admin-portal's gateway view, React's `WebhookConfiguration`). Null
  /// until the company's key is known and the gateway has a server id —
  /// a `tmp_` id is not a route the provider could ever call.
  static String? webhookUrl(
    BuildContext context,
    CompanyGateway gateway,
    Company? company,
  ) {
    final baseUrl = context.read<Services>().auth.session.value?.baseUrl ?? '';
    final key = company?.companyKey ?? '';
    if (baseUrl.isEmpty || key.isEmpty) return null;
    if (gateway.id.isEmpty || gateway.id.startsWith('tmp_')) return null;
    // `cleanApiUrl` strips a trailing slash / `/api/v1` so a self-hosted base
    // URL composes a valid webhook route (it isn't under /api/v1).
    return '${cleanApiUrl(baseUrl)}/payment_webhook/$key/${gateway.id}';
  }

  static List<Widget> rowsFor(
    BuildContext context,
    CompanyGateway gateway,
    Company? company, {
    Formatter? formatter,
  }) {
    final provider = context.read<Services>().statics.gateway(
      gateway.gatewayKey,
    );
    final events = provider?.supportedEvents() ?? const <String>[];
    final webhook = webhookUrl(context, gateway, company);
    // The local calendar day: these are UTC-backed server timestamps, and the
    // ISO date of the UTC instant is the wrong day across the boundary.
    String? day(int epochSeconds) => formatter == null || epochSeconds == 0
        ? null
        : formatter.date(
            DateTime.fromMillisecondsSinceEpoch(
              epochSeconds * 1000,
            ).toLocal().toIso8601String().split('T').first,
          );
    final created = day(gateway.createdAt);
    final updated = day(gateway.updatedAt);
    final valueStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: context.inTheme.ink,
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
    );
    return [
      DetailInfoRow(
        label: context.tr('provider'),
        value: provider?.name ?? context.tr('custom'),
        copyable: false,
      ),
      if (gateway.stripeAccountId.isNotEmpty)
        DetailInfoRow(
          label: context.tr('account_id'),
          value: gateway.stripeAccountId,
        ),
      // No Test Mode row: the header carries a Test pill while it is on, and
      // "Test Mode: Off" on every live gateway is a row that says nothing.
      DetailInfoRow(
        label: context.tr('token_billing'),
        value: context.tr(gateway.tokenBilling),
        copyable: false,
      ),
      if (webhook != null)
        DetailInfoRow(label: context.tr('webhook_url'), value: webhook),
      if (events.isNotEmpty)
        DetailInfoRow(
          label: context.tr('supported_events'),
          value: '',
          copyable: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < events.length; i++)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 2),
                  child: Text(events[i], style: valueStyle),
                ),
            ],
          ),
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

/// What the gateway makes a payer fill in. Built only when there is at least
/// one requirement — see [labelKeysFor].
class CompanyGatewayRequiredFieldsCard extends StatelessWidget {
  const CompanyGatewayRequiredFieldsCard({super.key, required this.gateway});

  final CompanyGateway gateway;

  /// The label key of every `require_*` toggle that is on. Empty means the
  /// card has nothing to show and the profile does not mount it.
  static List<String> labelKeysFor(CompanyGateway gateway) => [
    if (gateway.requireClientName) 'client_name',
    if (gateway.requireClientPhone) 'phone',
    if (gateway.requireContactName) 'contact_name',
    if (gateway.requireContactEmail) 'email',
    if (gateway.requireBillingAddress) 'billing_address',
    if (gateway.requireShippingAddress) 'shipping_address',
    if (gateway.requirePostalCode) 'postal_code',
    if (gateway.requireCvv) 'cvv',
  ];

  @override
  Widget build(BuildContext context) {
    final keys = labelKeysFor(gateway);
    if (keys.isEmpty) return const SizedBox.shrink();
    return DashboardCardShell(
      title: context.tr('required_fields_label'),
      child: _Labels(labels: [for (final k in keys) context.tr(k)]),
    );
  }
}

/// The payment methods the gateway accepts — or, when none is enabled, a line
/// saying so, because that gateway will never be offered to a payer.
class CompanyGatewayPaymentMethodsCard extends StatelessWidget {
  const CompanyGatewayPaymentMethodsCard({super.key, required this.gateway});

  final CompanyGateway gateway;

  @override
  Widget build(BuildContext context) {
    final statics = context.read<Services>().statics;
    final names = <String>[];
    gateway.feesAndLimits.forEach((typeId, fees) {
      if (!fees.isEnabled) return;
      final type = statics.gatewayType(typeId);
      // `GatewayType.name` is a localization key, not a display string — see
      // `kGatewayTypeLabelKey`. Fall back to the raw id if the server
      // references a type this build has not cataloged yet.
      names.add(type == null ? typeId : context.tr(type.name));
    });
    return DashboardCardShell(
      title: context.tr('payment_methods'),
      child: names.isEmpty
          ? Text(
              context.tr('no_payment_types_enabled'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.inTheme.ink2,
                fontSize: 12.5,
              ),
            )
          : _Labels(labels: names),
    );
  }
}

/// A wrapped run of small neutral labels. Rounded rectangles on the alternate
/// surface — these are facts about the gateway, not controls, so they are
/// deliberately not chips that look pressable.
class _Labels extends StatelessWidget {
  const _Labels({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Wrap(
      spacing: InSpacing.sm,
      runSpacing: InSpacing.sm,
      children: [
        for (final label in labels)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: InSpacing.sm,
              vertical: InSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: tokens.surfaceAlt,
              borderRadius: BorderRadius.circular(InRadii.r1),
              border: Border.all(color: tokens.border),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
