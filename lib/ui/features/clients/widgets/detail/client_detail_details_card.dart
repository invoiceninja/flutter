import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/custom_field_detail_rows.dart';
import 'package:admin/ui/core/utils/external_url.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/core/widgets/phone_number_value.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';

/// "Details" card on the client detail screen — website, phone, vat / id
/// numbers, custom fields. Blank standard rows are omitted entirely (no dash
/// placeholder) in every layout — only populated fields render. Custom fields
/// stay conditional and append below the standard rows when populated.
///
/// In the wide grid the card still renders even when empty so the first column
/// keeps its slot (column symmetry); the stacked layout drops it entirely when
/// [hasContent] is false.
class ClientDetailDetailsCard extends StatelessWidget {
  const ClientDetailDetailsCard({super.key, required this.client});

  final Client client;

  /// Whether any field this card renders is populated. Mirrors the exact set
  /// shown in [build] (the four standard fields + the four conditional custom
  /// values) so the stacked layout can omit a wholly-empty card.
  static bool hasContent(Client c) =>
      c.website.isNotEmpty ||
      c.phone.isNotEmpty ||
      c.vatNumber.isNotEmpty ||
      c.idNumber.isNotEmpty ||
      c.classification.isNotEmpty ||
      c.currencyId.isNotEmpty ||
      c.languageId.isNotEmpty ||
      c.routingId.isNotEmpty ||
      c.isTaxExempt ||
      c.customValue1.isNotEmpty ||
      c.customValue2.isNotEmpty ||
      c.customValue3.isNotEmpty ||
      c.customValue4.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final websiteUri = _parseWebsite(client.website);
    // Resolve currency / language names lazily — only touch `Services` when a
    // value is actually set, so the card still renders in tests (and the first
    // post-login frame) without a Services provider, exactly like the address
    // card's country lookup guards on a non-empty id.
    String currencyName() =>
        context.read<Services>().statics.currency(client.currencyId)?.name ??
        client.currencyId;
    String languageName() =>
        context.read<Services>().statics.language(client.languageId)?.name ??
        client.languageId;

    // Blank standard rows are omitted entirely (no dash placeholder) in every
    // layout — only populated fields render.
    DetailInfoRow? stdRow(String label, String value, {VoidCallback? onTap}) {
      if (value.isEmpty) return null;
      return DetailInfoRow(label: label, value: value, onTap: onTap);
    }

    final rows = <Widget?>[
      stdRow(
        context.tr('website'),
        client.website,
        onTap: websiteUri == null
            ? null
            : () => _openWebsite(context, websiteUri),
      ),
      if (client.phone.isNotEmpty)
        PhoneDetailRow(
          label: context.tr('phone'),
          phone: client.phone,
          subject: client.displayName,
          clientId: client.id,
        ),
      stdRow(context.tr('vat_number'), client.vatNumber),
      stdRow(context.tr('id_number'), client.idNumber),
      // Per-client settings + classification surfaced read-side (mirror of the
      // edit Settings card). Shown only when explicitly set, so an inherited
      // currency/language or a blank classification stays out of the way.
      if (client.classification.isNotEmpty)
        DetailInfoRow(
          label: context.tr('classification'),
          value: context.tr(client.classification),
          copyable: false,
        ),
      if (client.currencyId.isNotEmpty)
        DetailInfoRow(
          label: context.tr('currency'),
          value: currencyName(),
          copyable: false,
        ),
      if (client.languageId.isNotEmpty)
        DetailInfoRow(
          label: context.tr('language'),
          value: languageName(),
          copyable: false,
        ),
      if (client.routingId.isNotEmpty)
        DetailInfoRow(label: context.tr('routing_id'), value: client.routingId),
      if (client.isTaxExempt)
        DetailInfoRow(
          label: context.tr('tax_exempt'),
          value: context.tr('yes'),
          copyable: false,
        ),
    ];
    // Custom fields need the company config (via Services). Only reach for it
    // when a value is actually present, so the card still renders in tests /
    // the first post-login frame without a Services provider — same lazy
    // guard as the currency / language lookups above.
    final hasCustom =
        client.customValue1.isNotEmpty ||
        client.customValue2.isNotEmpty ||
        client.customValue3.isNotEmpty ||
        client.customValue4.isNotEmpty;
    return DashboardCardShell(
      title: context.tr('details'),
      child: hasCustom
          ? _DetailsWithCustomFields(client: client, standardRows: rows)
          : DetailRowStack(children: rows),
    );
  }
}

/// Appends the client's configured, type-formatted custom-field rows below the
/// standard rows. Split out so [ClientDetailDetailsCard] only touches
/// `Services` when a custom value is present (preserving its no-Services test
/// path). Labels + switch/date formatting come from the company config.
class _DetailsWithCustomFields extends StatelessWidget {
  const _DetailsWithCustomFields({
    required this.client,
    required this.standardRows,
  });

  final Client client;
  final List<Widget?> standardRows;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final yes = context.tr('yes');
    final no = context.tr('no');
    return WatchBuilder<Company?>(
      cacheKey: companyId,
      create: () => services.company.watchCompany(companyId),
      builder: (context, snapshot) {
        final customRows = customFieldDetailRows(
          company: snapshot.data,
          prefix: 'client',
          values: [
            client.customValue1,
            client.customValue2,
            client.customValue3,
            client.customValue4,
          ],
          formatter: services.formatterIfReady(companyId),
          yes: yes,
          no: no,
        );
        return DetailRowStack(
          children: [
            ...standardRows,
            for (final r in customRows)
              DetailInfoRow(label: r.label, value: r.value),
          ],
        );
      },
    );
  }
}

/// Parses a user-entered website into a launchable URI. Returns null when
/// the value is empty, unparseable, has no host, or isn't an http(s) URL.
/// Bare hosts like `example.com` are upgraded to `https://example.com`.
Uri? _parseWebsite(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
  final uri = Uri.tryParse(withScheme);
  if (uri == null) return null;
  if (uri.host.isEmpty) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return null;
  return uri;
}

Future<void> _openWebsite(BuildContext context, Uri uri) =>
    openExternalUrl(context, uri.toString());
