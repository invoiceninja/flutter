import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/data/models/domain/vendor_contact.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/detail/custom_field_detail_rows.dart';
import 'package:admin/ui/core/utils/external_url.dart';
import 'package:admin/ui/core/widgets/centered_form_column.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/core/widgets/phone_number_value.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/address_format.dart';
import 'package:admin/utils/formatting.dart';

// ────────────────────────────────────────────────────────────────────
// Vendor detail screen cards. One file because the cards are small and
// almost always rendered together — mirror of how the Client detail
// cards live in `widgets/detail/client_detail_*.dart` but compacted
// into a single module since Vendor's surface is narrower than Client's.
// ────────────────────────────────────────────────────────────────────

/// Responsive grid for the vendor detail body cards.
///
/// - **≥1000 px**: three equal-width columns — Details · Address · Contacts —
///   with Notes spanning the full width on a second row when it has content.
/// - **<1000 px**: single centered column (≤820 px), all cards stacked.
///
/// The KPI strip has moved up into `VendorDetailKpiStrip` (rendered by the
/// screen above this grid), so this widget no longer owns it. Mirror of
/// `ClientDetailCardsGrid`.
class VendorDetailCardsGrid extends StatelessWidget {
  const VendorDetailCardsGrid({
    super.key,
    required this.vendor,
    required this.formatter,
  });

  final Vendor vendor;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= Breakpoints.entityFormMultiColumn;
        if (wide) return _wide(context);
        return CenteredFormColumn(child: _stacked(context));
      },
    );
  }

  Widget _wide(BuildContext context) {
    final hasContacts = vendor.contacts.isNotEmpty;
    final hasNotes =
        vendor.privateNotes.isNotEmpty || vendor.publicNotes.isNotEmpty;
    final columns = <Widget>[
      Expanded(
        child: VendorDetailDetailsCard(vendor: vendor, formatter: formatter),
      ),
      SizedBox(width: InSpacing.md(context)),
      Expanded(child: VendorDetailAddressCard(vendor: vendor)),
      if (hasContacts) ...[
        SizedBox(width: InSpacing.md(context)),
        Expanded(child: VendorDetailContactsCard(contacts: vendor.contacts)),
      ],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: columns,
          ),
        ),
        if (hasNotes) ...[
          SizedBox(height: InSpacing.md(context)),
          VendorDetailNotesCard(vendor: vendor),
        ],
        if (vendor.tagIds.isNotEmpty) ...[
          SizedBox(height: InSpacing.md(context)),
          _TagsCard(vendor: vendor),
        ],
      ],
    );
  }

  Widget _stacked(BuildContext context) {
    final cards = <Widget>[
      VendorDetailDetailsCard(vendor: vendor, formatter: formatter),
      VendorDetailAddressCard(vendor: vendor),
      VendorDetailContactsCard(contacts: vendor.contacts),
      if (vendor.privateNotes.isNotEmpty || vendor.publicNotes.isNotEmpty)
        VendorDetailNotesCard(vendor: vendor),
      if (vendor.tagIds.isNotEmpty) _TagsCard(vendor: vendor),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) SizedBox(height: InSpacing.md(context)),
          cards[i],
        ],
      ],
    );
  }
}

// Aggregate KPI strip extracted to `vendor_detail_kpi_strip.dart` — vendors
// have no server-side balance, so it shows locally-derived expense aggregates
// (total + last expense date) computed from the local Drift store.

// ───────────────────────── Details ─────────────────────────

class _TagsCard extends StatelessWidget {
  const _TagsCard({required this.vendor});
  final Vendor vendor;

  @override
  Widget build(BuildContext context) => DashboardCardShell(
    title: context.tr('tags'),
    child: EntityTagsView(entityType: 'vendor', tagIds: vendor.tagIds),
  );
}

class VendorDetailDetailsCard extends StatelessWidget {
  const VendorDetailDetailsCard({
    super.key,
    required this.vendor,
    this.formatter,
  });

  final Vendor vendor;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final yes = context.tr('yes');
    final no = context.tr('no');
    final websiteUri = _parseWebsite(vendor.website);
    return WatchBuilder<Company?>(
      cacheKey: companyId,
      create: () => services.company.watchCompany(companyId),
      builder: (context, snapshot) {
        final customRows = customFieldDetailRows(
          company: snapshot.data,
          prefix: 'vendor',
          values: [
            vendor.customValue1,
            vendor.customValue2,
            vendor.customValue3,
            vendor.customValue4,
          ],
          formatter: formatter,
          yes: yes,
          no: no,
        );
        final statics = services.statics;
        final currencyName = vendor.currencyId.isEmpty
            ? ''
            : (statics.currency(vendor.currencyId)?.name ?? '');
        final languageName = vendor.languageId.isEmpty
            ? ''
            : (statics.language(vendor.languageId)?.name ?? '');
        final lastLoginText = vendor.lastLogin == null
            ? ''
            : (formatter?.date(vendor.lastLogin!.toIso8601String()) ??
                  vendor.lastLogin!.toIso8601String());
        final rows = <Widget?>[
          if (vendor.website.isNotEmpty)
            DetailInfoRow(
              label: context.tr('website'),
              value: vendor.website,
              onTap: websiteUri == null
                  ? null
                  : () => _openWebsite(context, websiteUri),
            ),
          if (vendor.phone.isNotEmpty)
            // No `clientId` — a vendor has no settings cascade of its own, so
            // the out-of-hours check falls back to the company's timezone.
            PhoneDetailRow(
              label: context.tr('phone'),
              phone: vendor.phone,
              subject: vendor.name,
            ),
          if (vendor.vatNumber.isNotEmpty)
            DetailInfoRow(
              label: context.tr('vat_number'),
              value: vendor.vatNumber,
            ),
          if (vendor.idNumber.isNotEmpty)
            DetailInfoRow(
              label: context.tr('id_number'),
              value: vendor.idNumber,
            ),
          if (vendor.classification.isNotEmpty)
            DetailInfoRow(
              label: context.tr('classification'),
              value: context.tr(vendor.classification),
              copyable: false,
            ),
          if (vendor.routingId.isNotEmpty)
            DetailInfoRow(
              label: context.tr('routing_id'),
              value: vendor.routingId,
            ),
          if (vendor.isTaxExempt)
            DetailInfoRow(
              label: context.tr('tax_exempt'),
              value: yes,
              copyable: false,
            ),
          if (currencyName.isNotEmpty)
            DetailInfoRow(
              label: context.tr('currency'),
              value: currencyName,
              copyable: false,
            ),
          if (languageName.isNotEmpty)
            DetailInfoRow(
              label: context.tr('language'),
              value: languageName,
              copyable: false,
            ),
          if (lastLoginText.isNotEmpty)
            DetailInfoRow(
              label: context.tr('last_login'),
              value: lastLoginText,
              copyable: false,
            ),
          for (final r in customRows)
            DetailInfoRow(label: r.label, value: r.value),
        ];
        return DashboardCardShell(
          title: context.tr('details'),
          child: DetailRowStack(children: rows),
        );
      },
    );
  }
}

// ───────────────────────── Address ─────────────────────────

class VendorDetailAddressCard extends StatelessWidget {
  const VendorDetailAddressCard({super.key, required this.vendor});

  final Vendor vendor;

  @override
  Widget build(BuildContext context) {
    final countryObj = vendor.countryId.isEmpty
        ? null
        : context.read<Services>().statics.country(vendor.countryId);
    final cityLine = cityStateZip(
      city: vendor.city,
      state: vendor.state,
      postalCode: vendor.postalCode,
      swapPostalCode: countryObj?.swapPostalCode ?? false,
    );
    final country = vendor.countryId.isEmpty
        ? ''
        : (countryObj?.name ?? vendor.countryId);

    final rows = <Widget?>[
      if (vendor.address1.isNotEmpty)
        DetailInfoRow(label: context.tr('address1'), value: vendor.address1),
      if (vendor.address2.isNotEmpty)
        DetailInfoRow(label: context.tr('address2'), value: vendor.address2),
      if (cityLine.isNotEmpty)
        DetailInfoRow(label: context.tr('city'), value: cityLine),
      if (country.isNotEmpty)
        DetailInfoRow(
          label: context.tr('country'),
          value: country,
          copyable: false,
        ),
    ];
    if (rows.whereType<Widget>().isEmpty) return const SizedBox.shrink();
    return DashboardCardShell(
      title: context.tr('address'),
      child: DetailRowStack(children: rows),
    );
  }
}

// ───────────────────────── Contacts ─────────────────────────

class VendorDetailContactsCard extends StatelessWidget {
  const VendorDetailContactsCard({super.key, required this.contacts});

  final List<VendorContact> contacts;

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) return const SizedBox.shrink();
    return DashboardCardShell(
      title: context.tr('contacts'),
      child: DetailRowStack(children: contacts.map(_ContactRow.new).toList()),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow(this.contact);
  final VendorContact contact;

  // Scoped at the row, not at the number — see the same note on the client
  // card's `_ContactRow`: the Call / Message buttons are built here.
  @override
  Widget build(BuildContext context) => PhoneActionsScope(builder: _buildRow);

  Widget _buildRow(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final name = ('${contact.firstName} ${contact.lastName}').trim();
    final hasName = name.isNotEmpty;
    // When there's no name the email becomes the title; only then is the email
    // not repeated as a secondary line.
    final title = hasName
        ? name
        : (contact.email.isNotEmpty
              ? contact.email
              : context.tr('no_name_fallback'));
    final titleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: tokens.ink,
      fontWeight: FontWeight.w500,
    );
    final subStyle = theme.textTheme.bodySmall?.copyWith(color: tokens.ink3);
    // The email shows as a secondary line only when a name occupies the title.
    final secondaryEmail = hasName ? contact.email : '';

    final actions = contact.phone.isEmpty
        ? const <Widget>[]
        : phoneActionButtons(
            context,
            contact.phone,
            subject: _vendorContactSubject(context, contact),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: InSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title is copyable only when it's the email (no name).
                if (hasName || contact.email.isEmpty)
                  Text(title, style: titleStyle)
                else
                  CopyableValue(
                    value: contact.email,
                    child: Text(title, style: titleStyle),
                  ),
                if (secondaryEmail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  CopyableValue(
                    value: secondaryEmail,
                    child: Text(secondaryEmail, style: subStyle),
                  ),
                ],
                if (contact.phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  PhoneNumberValue(
                    phone: contact.phone,
                    style: subStyle,
                    subject: _vendorContactSubject(context, contact),
                  ),
                  // This card had no action row before; Call / Message is the
                  // first thing to need one.
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: InSpacing.xs),
                    Wrap(spacing: InSpacing.sm, children: actions),
                  ],
                ],
              ],
            ),
          ),
          if (contact.isPrimary)
            Padding(
              padding: const EdgeInsets.only(left: InSpacing.sm, top: 2),
              child: Icon(Icons.star, size: 14, color: tokens.accent),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────── Notes ─────────────────────────

class VendorDetailNotesCard extends StatelessWidget {
  const VendorDetailNotesCard({super.key, required this.vendor});

  final Vendor vendor;

  @override
  Widget build(BuildContext context) {
    final hasPrivate = vendor.privateNotes.isNotEmpty;
    final hasPublic = vendor.publicNotes.isNotEmpty;
    if (!hasPrivate && !hasPublic) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    return DashboardCardShell(
      title: context.tr('notes'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasPrivate)
            _NotesBlock(
              label: context.tr('private_notes'),
              body: vendor.privateNotes,
              labelColor: tokens.ink3,
              bodyStyle: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.ink,
              ),
            ),
          if (hasPrivate && hasPublic) ...[
            SizedBox(height: InSpacing.md(context)),
            Divider(height: 1, thickness: 1, color: tokens.border),
            SizedBox(height: InSpacing.md(context)),
          ],
          if (hasPublic)
            _NotesBlock(
              label: context.tr('public_notes'),
              body: vendor.publicNotes,
              labelColor: tokens.ink3,
              bodyStyle: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.ink,
              ),
            ),
        ],
      ),
    );
  }
}

class _NotesBlock extends StatelessWidget {
  const _NotesBlock({
    required this.label,
    required this.body,
    required this.labelColor,
    required this.bodyStyle,
  });

  final String label;
  final String body;
  final Color labelColor;
  final TextStyle? bodyStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: labelColor,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: InSpacing.xs),
        Text(body, style: bodyStyle),
      ],
    );
  }
}

// ───────────────────────── Website opener ─────────────────────────

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

/// Who the confirmation prompt names when this vendor contact is called.
String _vendorContactSubject(BuildContext context, VendorContact contact) {
  final name = ('${contact.firstName} ${contact.lastName}').trim();
  if (name.isNotEmpty) return name;
  if (contact.email.isNotEmpty) return contact.email;
  return context.tr('no_name_fallback');
}
