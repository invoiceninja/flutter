import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_gateway.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/utils/formatting.dart';

/// Three info cards for the CompanyGateway detail screen body:
///   1. Overview — label / provider / test mode / token billing.
///   2. Required fields — chips for each `require_*` toggle that's on.
///   3. Accepted payment types — chips for each enabled payment type.
class CompanyGatewayDetailCardsGrid extends StatelessWidget {
  const CompanyGatewayDetailCardsGrid({
    super.key,
    required this.gateway,
    required this.companyId,
  });

  final CompanyGateway gateway;
  final String companyId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _OverviewCard(gateway: gateway, companyId: companyId),
        _RequiredFieldsCard(gateway: gateway),
        _AcceptedTypesCard(gateway: gateway),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.gateway, required this.companyId});
  final CompanyGateway gateway;
  final String companyId;

  @override
  Widget build(BuildContext context) {
    final statics = context.read<Services>().statics;
    final provider = statics.gateway(gateway.gatewayKey);
    final providerName = provider?.name ?? context.tr('custom');
    final events = provider?.supportedEvents() ?? const <String>[];
    return FormSection(
      title: context.tr('overview'),
      spacing: 0,
      children: [
        if (gateway.label.isNotEmpty)
          _KeyValue(labelKey: 'label', value: gateway.label),
        _KeyValue(labelKey: 'gateway_type', value: providerName),
        _KeyValue(
          labelKey: 'test_mode',
          value: gateway.testMode ? context.tr('enabled') : context.tr('off'),
        ),
        _KeyValue(
          labelKey: 'token_billing',
          value: context.tr(gateway.tokenBilling),
        ),
        _WebhookRow(gateway: gateway, companyId: companyId),
        if (events.isNotEmpty) _SupportedEvents(events: events),
      ],
    );
  }
}

/// Webhook events the selected provider emits, listed under the webhook URL.
/// Mirrors admin-portal's gateway view. Hidden when the provider declares none.
class _SupportedEvents extends StatelessWidget {
  const _SupportedEvents({required this.events});
  final List<String> events;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: InSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('supported_events'),
            style: TextStyle(color: tokens.ink3),
          ),
          const SizedBox(height: 2),
          for (final event in events)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(event, style: TextStyle(color: tokens.ink)),
            ),
        ],
      ),
    );
  }
}

/// Inbound payment webhook URL with copy-to-clipboard. Merchants paste this
/// into the gateway provider's dashboard to receive payment-status callbacks.
/// Mirrors admin-portal's gateway view + React's `WebhookConfiguration`:
/// `{baseUrl}/payment_webhook/{company_key}/{gateway_id}`. Hidden until the
/// company (for its key) resolves and the gateway has a server-assigned id.
class _WebhookRow extends StatelessWidget {
  const _WebhookRow({required this.gateway, required this.companyId});
  final CompanyGateway gateway;
  final String companyId;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final baseUrl = services.auth.session.value?.baseUrl ?? '';
    if (baseUrl.isEmpty || gateway.id.isEmpty) return const SizedBox.shrink();
    final tokens = context.inTheme;
    return WatchBuilder<Company?>(
      cacheKey: companyId,
      create: () => services.company.watchCompany(companyId),
      builder: (context, snap) {
        final key = snap.data?.companyKey ?? '';
        if (key.isEmpty) return const SizedBox.shrink();
        // `cleanApiUrl` strips a trailing slash / `/api/v1` so a self-hosted
        // base URL composes a valid webhook route (it isn't under /api/v1).
        final url =
            '${cleanApiUrl(baseUrl)}/payment_webhook/$key/${gateway.id}';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: InSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('webhook_url'),
                style: TextStyle(color: tokens.ink3),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      url,
                      style: TextStyle(color: tokens.ink),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    tooltip: context.tr('copy'),
                    onPressed: () => copyToClipboard(context, url),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RequiredFieldsCard extends StatelessWidget {
  const _RequiredFieldsCard({required this.gateway});
  final CompanyGateway gateway;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (gateway.requireClientName) _chip(context, 'client_name'),
      if (gateway.requireClientPhone) _chip(context, 'phone'),
      if (gateway.requireContactName) _chip(context, 'contact_name'),
      if (gateway.requireContactEmail) _chip(context, 'email'),
      if (gateway.requireBillingAddress) _chip(context, 'billing_address'),
      if (gateway.requireShippingAddress) _chip(context, 'shipping_address'),
      if (gateway.requirePostalCode) _chip(context, 'postal_code'),
      if (gateway.requireCvv) _chip(context, 'cvv'),
    ];
    return FormSection(
      title: context.tr('required_fields_label'),
      children: [
        if (chips.isEmpty)
          Text(context.tr('off'))
        else
          Wrap(
            spacing: InSpacing.sm,
            runSpacing: InSpacing.sm,
            children: chips,
          ),
      ],
    );
  }

  Widget _chip(BuildContext context, String labelKey) =>
      Chip(label: Text(context.tr(labelKey)));
}

class _AcceptedTypesCard extends StatelessWidget {
  const _AcceptedTypesCard({required this.gateway});
  final CompanyGateway gateway;

  @override
  Widget build(BuildContext context) {
    final statics = context.read<Services>().statics;
    final enabledTypes = <String>[];
    gateway.feesAndLimits.forEach((typeId, fees) {
      if (fees.isEnabled) {
        final type = statics.gatewayType(typeId);
        // `GatewayType.name` is a localization key, not a display string —
        // see `kGatewayTypeLabelKey`. Fall back to a raw "type N" if the
        // server references an id we haven't cataloged yet.
        enabledTypes.add(type == null ? typeId : context.tr(type.name));
      }
    });
    return FormSection(
      title: context.tr('payment_methods'),
      children: [
        if (enabledTypes.isEmpty)
          Text(context.tr('no_payment_types_enabled'))
        else
          Wrap(
            spacing: InSpacing.sm,
            runSpacing: InSpacing.sm,
            children: [
              for (final name in enabledTypes) Chip(label: Text(name)),
            ],
          ),
      ],
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.labelKey, required this.value});
  final String labelKey;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: InSpacing.xs),
      // Narrow the label column on small widths (phones, or a narrow
      // master-detail pane) so the value keeps room. Measured off the actual
      // available width, not the whole screen.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelWidth = constraints.maxWidth < 360 ? 110.0 : 160.0;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: labelWidth,
                child: Text(
                  context.tr(labelKey),
                  style: TextStyle(color: tokens.ink3),
                ),
              ),
              Expanded(
                child: Text(value, style: TextStyle(color: tokens.ink)),
              ),
            ],
          );
        },
      ),
    );
  }
}
