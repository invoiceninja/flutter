import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/custom_field_detail_rows.dart';
import 'package:admin/ui/core/utils/external_url.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/core/widgets/detail_row_columns.dart';
import 'package:admin/ui/core/widgets/phone_number_value.dart';
import 'package:admin/ui/core/widgets/user_name_label.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/vendors/widgets/detail/vendor_detail_address_card.dart';
import 'package:admin/utils/formatting.dart';

/// "Details" card on the vendor record screen — website, phone, vat / id
/// numbers, classification, currency and language, custom fields, and when
/// the record was made. Blank rows are omitted entirely (no dash placeholder)
/// and a card with no rows builds nothing.
///
/// [company] supplies the custom-field labels. It is handed in rather than
/// watched here because the profile needs the same answer twice: this card
/// draws the rows, and the profile has to know whether there are any before
/// it gives the card a column. Two watches could disagree for a frame; one
/// cannot.
class VendorDetailDetailsCard extends StatelessWidget {
  const VendorDetailDetailsCard({
    super.key,
    required this.vendor,
    this.company,
    this.formatter,
  });

  final Vendor vendor;

  /// Null while the company row is still loading — custom fields wait for it.
  final Company? company;

  /// For the dates. Null (still loading) leaves them out.
  final Formatter? formatter;

  /// Whether the card draws anything. **Derived from [rowsFor]**, the list
  /// [build] renders, so the two cannot drift: the hand-written predicate this
  /// replaced counted a custom value whose label was never configured, which
  /// the card then did not draw — a titled card with nothing in it.
  static bool hasContent(
    BuildContext context,
    Vendor vendor,
    Company? company, {
    Formatter? formatter,
  }) => rowsFor(context, vendor, company, formatter: formatter).isNotEmpty;

  /// The rows, in display order.
  static List<Widget> rowsFor(
    BuildContext context,
    Vendor vendor,
    Company? company, {
    Formatter? formatter,
  }) {
    final websiteUri = _parseWebsite(vendor.website);
    // Resolve currency / language names lazily — only touch `Services` when a
    // value is actually set, so the card still renders without a provider in
    // a test that sets neither. An id the statics cannot resolve (they load at
    // sign-in, so the first frame after a cold start can find them empty)
    // falls back to the raw id rather than dropping the row.
    String currencyName() =>
        context.read<Services>().statics.currency(vendor.currencyId)?.name ??
        vendor.currencyId;
    String languageName() =>
        context.read<Services>().statics.language(vendor.languageId)?.name ??
        vendor.languageId;
    final lastLogin = vendor.lastLogin;

    return [
      if (vendor.website.isNotEmpty)
        DetailInfoRow(
          label: context.tr('website'),
          value: vendor.website,
          onTap: websiteUri == null
              ? null
              : () => openExternalUrl(context, websiteUri.toString()),
        ),
      if (vendor.phone.isNotEmpty)
        // No `clientId` — a vendor has no settings cascade of its own, so the
        // out-of-hours check falls back to the company's timezone.
        PhoneDetailRow(
          label: context.tr('phone'),
          phone: vendor.phone,
          subject: vendor.name,
          logTarget: (
            type: EntityType.vendor,
            id: vendor.id,
            subject: vendor.name,
          ),
        ),
      if (vendor.vatNumber.isNotEmpty)
        DetailInfoRow(label: context.tr('vat_number'), value: vendor.vatNumber),
      if (vendor.idNumber.isNotEmpty)
        DetailInfoRow(label: context.tr('id_number'), value: vendor.idNumber),
      if (vendor.classification.isNotEmpty)
        DetailInfoRow(
          label: context.tr('classification'),
          value: context.tr(vendor.classification),
          copyable: false,
        ),
      if (vendor.currencyId.isNotEmpty)
        DetailInfoRow(
          label: context.tr('currency'),
          value: currencyName(),
          copyable: false,
        ),
      if (vendor.languageId.isNotEmpty)
        DetailInfoRow(
          label: context.tr('language'),
          value: languageName(),
          copyable: false,
        ),
      // A country with no address around it: the Address card does not open
      // for one word (see `VendorDetailAddressCard.hasContent`), so it is a
      // row here. With an address it is the block's last line instead.
      if (vendor.countryId.isNotEmpty &&
          !VendorDetailAddressCard.hasContent(vendor))
        DetailInfoRow(
          label: context.tr('country'),
          value:
              context
                  .read<Services>()
                  .statics
                  .country(vendor.countryId)
                  ?.name ??
              vendor.countryId,
          copyable: false,
        ),
      if (vendor.assignedUserId.isNotEmpty)
        DetailInfoRow(
          label: context.tr('assigned_user'),
          value: '',
          copyable: false,
          child: UserNameLabel(userId: vendor.assignedUserId),
        ),
      if (vendor.routingId.isNotEmpty)
        DetailInfoRow(label: context.tr('routing_id'), value: vendor.routingId),
      if (vendor.isTaxExempt)
        DetailInfoRow(
          label: context.tr('tax_exempt'),
          value: context.tr('yes'),
          copyable: false,
        ),
      // The vendor's own last portal login, as a local calendar day. It is a
      // UTC instant, and the ISO date of the UTC instant is the wrong day for
      // anyone whose evening crosses the boundary.
      if (lastLogin != null && formatter != null)
        DetailInfoRow(
          label: context.tr('last_login'),
          value: formatter.date(_localDay(lastLogin)),
          copyable: false,
        ),
      ..._customRows(context, vendor, company),
      ..._timestampRows(context, vendor, formatter),
    ];
  }

  static String _localDay(DateTime utc) =>
      utc.toLocal().toIso8601String().split('T').first;

  /// Created / updated, at the foot. The header shows them only for a vendor
  /// with neither a place nor a number to put under its name.
  static List<Widget> _timestampRows(
    BuildContext context,
    Vendor vendor,
    Formatter? formatter,
  ) {
    if (formatter == null) return const [];
    String? day(DateTime dt) =>
        dt.millisecondsSinceEpoch == 0 ? null : formatter.date(_localDay(dt));
    final created = day(vendor.createdAt);
    final updated = day(vendor.updatedAt);
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
  /// when the company has a label for it AND the vendor has a value.
  static List<Widget> _customRows(
    BuildContext context,
    Vendor vendor,
    Company? company,
  ) {
    final values = [
      vendor.customValue1,
      vendor.customValue2,
      vendor.customValue3,
      vendor.customValue4,
    ];
    // Only reach for `Services` (the date formatter) when a value is present —
    // same lazy guard as the currency / language lookups above.
    if (company == null || values.every((v) => v.isEmpty)) return const [];
    final services = context.read<Services>();
    final rows = customFieldDetailRows(
      company: company,
      prefix: 'vendor',
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
    final rows = rowsFor(context, vendor, company, formatter: formatter);
    if (rows.isEmpty) return const SizedBox.shrink();
    return DashboardCardShell(
      title: context.tr('details'),
      child: DetailRowColumns(children: rows),
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
