import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/group_setting.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/custom_field_detail_rows.dart';
import 'package:admin/ui/core/utils/external_url.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/core/widgets/detail_row_columns.dart';
import 'package:admin/ui/core/widgets/party_money_cell.dart';
import 'package:admin/ui/core/widgets/phone_number_value.dart';
import 'package:admin/ui/core/widgets/user_name_label.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/formatting.dart';

/// "Details" card on the client detail screen — website, phone, vat / id
/// numbers, per-client settings, custom fields. Blank rows are omitted
/// entirely (no dash placeholder) in every layout — only populated fields
/// render — and a card with no rows builds nothing.
///
/// [company] supplies the custom-field labels. It is handed in rather than
/// watched here because the profile needs the same answer twice: this card
/// draws the rows, and the profile has to know whether there are any before
/// it gives the card a column. Two watches could disagree for a frame; one
/// cannot.
class ClientDetailDetailsCard extends StatelessWidget {
  const ClientDetailDetailsCard({
    super.key,
    required this.client,
    this.company,
    this.formatter,
  });

  final Client client;

  /// Null while the company row is still loading — custom fields wait for it.
  final Company? company;

  /// For the task rate and the created / updated dates. Null (still loading)
  /// leaves the dates out and prints the rate as a bare number.
  final Formatter? formatter;

  /// Whether the card draws anything. **Derived from [rowsFor]**, the list
  /// [build] renders, so the two cannot drift: the old hand-written predicate
  /// counted a custom value whose label was never configured, which the card
  /// then did not draw — a titled card with nothing in it.
  static bool hasContent(
    BuildContext context,
    Client client,
    Company? company, {
    Formatter? formatter,
  }) => rowsFor(context, client, company, formatter: formatter).isNotEmpty;

  /// The rows, in display order.
  ///
  /// Every per-client field the edit screen can set has a row here, shown
  /// when it is set. The view used to stop at five of them, so finding out a
  /// client's payment terms meant opening it for editing.
  static List<Widget> rowsFor(
    BuildContext context,
    Client client,
    Company? company, {
    Formatter? formatter,
  }) {
    final websiteUri = _parseWebsite(client.website);
    final settings = client.settings ?? const <String, dynamic>{};
    // A stored zero is "no rate of its own", the same as no key at all.
    final rawRate = settings['default_task_rate'];
    final Object? taskRate =
        rawRate == null ||
            '$rawRate'.isEmpty ||
            Decimal.tryParse('$rawRate') == Decimal.zero
        ? null
        : rawRate as Object;
    final validUntil = settings['valid_until']?.toString() ?? '';
    final sendReminders = settings['send_reminders'];
    // "30 Days": the bare unit word, which every bundle has as a noun.
    // `count_days` reads ":count les jours" in French.
    String days(String n) => '$n ${context.tr('days')}';
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

    return [
      if (client.website.isNotEmpty)
        DetailInfoRow(
          label: context.tr('website'),
          value: client.website,
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
          logTarget: (
            type: EntityType.client,
            id: client.id,
            subject: client.displayName,
          ),
        ),
      if (client.vatNumber.isNotEmpty)
        DetailInfoRow(label: context.tr('vat_number'), value: client.vatNumber),
      if (client.idNumber.isNotEmpty)
        DetailInfoRow(label: context.tr('id_number'), value: client.idNumber),
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
      if (client.paymentTerms.isNotEmpty)
        DetailInfoRow(
          label: context.tr('payment_terms'),
          value: days(client.paymentTerms),
          copyable: false,
        ),
      if (taskRate != null)
        _TaskRateRow(client: client, rate: taskRate, formatter: formatter),
      if (validUntil.isNotEmpty)
        DetailInfoRow(
          label: context.tr('valid_until'),
          value: days(validUntil),
          copyable: false,
        ),
      if (sendReminders is bool)
        DetailInfoRow(
          label: context.tr('send_reminders'),
          value: context.tr(sendReminders ? 'enabled' : 'disabled'),
          copyable: false,
        ),
      if (client.groupSettingsId.isNotEmpty) _GroupRow(client: client),
      if (client.assignedUserId.isNotEmpty)
        DetailInfoRow(
          label: context.tr('assigned_user'),
          value: '',
          copyable: false,
          child: UserNameLabel(userId: client.assignedUserId),
        ),
      if (client.industryId.isNotEmpty)
        DetailInfoRow(
          label: context.tr('industry'),
          value:
              context
                  .read<Services>()
                  .statics
                  .industry(client.industryId)
                  ?.name ??
              client.industryId,
          copyable: false,
        ),
      if (client.sizeId.isNotEmpty)
        DetailInfoRow(
          label: context.tr('size_id'),
          value:
              context.read<Services>().statics.size(client.sizeId)?.name ??
              client.sizeId,
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
      if (client.hasValidVatNumber)
        DetailInfoRow(
          label: context.tr('valid_vat_number'),
          value: context.tr('yes'),
          copyable: false,
        ),
      ..._customRows(context, client, company),
      ..._timestampRows(context, client, formatter),
    ];
  }

  /// Created / updated, at the foot. They used to be the line under the
  /// client's name — the most prominent spot on the screen for the two facts
  /// about it a user wants least often.
  static List<Widget> _timestampRows(
    BuildContext context,
    Client client,
    Formatter? formatter,
  ) {
    if (formatter == null) return const [];
    // The local calendar day: these are UTC-backed server timestamps, and the
    // ISO date of the UTC instant is the wrong day across the boundary.
    String? day(DateTime dt) => dt.millisecondsSinceEpoch == 0
        ? null
        : formatter.date(dt.toLocal().toIso8601String().split('T').first);
    final created = day(client.createdAt);
    final updated = day(client.updatedAt);
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

  /// The configured, type-formatted custom-field rows. A slot renders only
  /// when the company has a label for it AND the client has a value.
  static List<Widget> _customRows(
    BuildContext context,
    Client client,
    Company? company,
  ) {
    final values = [
      client.customValue1,
      client.customValue2,
      client.customValue3,
      client.customValue4,
    ];
    // Only reach for `Services` (the date formatter) when a value is present —
    // same lazy guard as the currency / language lookups above.
    if (company == null || values.every((v) => v.isEmpty)) return const [];
    final services = context.read<Services>();
    final rows = customFieldDetailRows(
      company: company,
      prefix: 'client',
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

  @override
  Widget build(BuildContext context) {
    final rows = rowsFor(context, client, company, formatter: formatter);
    if (rows.isEmpty) return const SizedBox.shrink();
    return DashboardCardShell(
      title: context.tr('details'),
      child: DetailRowColumns(children: rows),
    );
  }
}

/// The client's group, by name, linking to the group's settings for a user
/// who can open them.
///
/// Its own widget because the name is a stream: groups are bundled reference
/// data in Drift, and a client carries only the id. Until the row resolves it
/// shows the label with an empty value rather than the raw id.
/// The client's own task rate, in the currency the client is billed in.
///
/// Through `PartyCurrencyBuilder` — the client → group → company cascade —
/// like the standing card above it. Passing the client's own `currencyId`
/// alone formats a group-inheriting client's rate in the *company* currency:
/// dollars here, beside a balance in euros.
class _TaskRateRow extends StatelessWidget {
  const _TaskRateRow({
    required this.client,
    required this.rate,
    required this.formatter,
  });

  final Client client;
  final Object rate;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final parsed = Decimal.tryParse('$rate');
    final f = formatter;
    // The bare number until the formatter is here, which is still the right
    // number.
    if (parsed == null || f == null) {
      return DetailInfoRow(
        label: context.tr('task_rate'),
        value: '$rate',
        copyable: false,
      );
    }
    return PartyCurrencyBuilder(
      clientId: client.id,
      builder: (context, currencyId) => DetailInfoRow(
        label: context.tr('task_rate'),
        value: f.money(
          parsed,
          clientCurrencyId: currencyId ?? client.currencyId,
        ),
        copyable: false,
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final session = services.auth.session.value;
    final companyId = session?.currentCompanyId ?? '';
    final me = session?.currentCompany;
    // Group settings live under Settings, which is admin / owner territory.
    final canOpen = (me?.isAdmin ?? false) || (me?.isOwner ?? false);
    final id = client.groupSettingsId;
    return WatchBuilder<GroupSetting?>(
      cacheKey: (companyId, id),
      create: () =>
          services.groupSettings.watchByRealId(companyId: companyId, id: id),
      builder: (context, snapshot) {
        final name = snapshot.data?.name ?? '';
        return DetailInfoRow(
          label: context.tr('group'),
          value: name,
          copyable: false,
          onTap: canOpen && name.isNotEmpty
              ? () => context.go('/settings/group_settings/$id')
              : null,
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
