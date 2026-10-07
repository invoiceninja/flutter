import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/data/models/domain/vendor_contact.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_header.dart';
import 'package:admin/ui/core/detail/entity_detail_header_host.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/utils/formatting.dart';

/// What a vendor is called on screen: its `name`, else its primary (or first)
/// contact's name, else that contact's email, else `no_name_fallback`.
///
/// One function because the name is printed in two places on the record
/// screen — the header, and the fixed bar once the header has scrolled away —
/// and a vendor that is "Jane Doe" in one must not be "(no name)" in the
/// other.
String vendorDisplayName(BuildContext context, Vendor v) {
  if (v.name.isNotEmpty) return v.name;
  final c = _leadContact(v.contacts);
  if (c != null) {
    final composed = ('${c.firstName} ${c.lastName}').trim();
    if (composed.isNotEmpty) return composed;
    if (c.email.isNotEmpty) return c.email;
  }
  return context.tr('no_name_fallback');
}

VendorContact? _leadContact(List<VendorContact> contacts) {
  if (contacts.isEmpty) return null;
  for (final c in contacts) {
    if (c.isPrimary) return c;
  }
  return contacts.first;
}

/// Per-entity wrapper over [EntityDetailHeaderHost]: the vendor's name
/// ([vendorDisplayName]) and the line under it.
///
/// **The subtitle is place · number.** It does not name the contact: the
/// Contacts card below has every one of them. When a vendor has neither a
/// number nor a city, the line falls back to the created/updated dates the
/// header shows for every other entity, so it is never blank.
///
/// **Tags sit under the subtitle.** They are the user's own classification of
/// this vendor, and a label worth applying is a label worth seeing without
/// opening anything. They used to be a card of their own at the foot of the
/// page.
class VendorDetailHeader extends StatelessWidget {
  const VendorDetailHeader({
    super.key,
    required this.vendor,
    this.formatter,
    this.showStatePills = true,
  });

  final Vendor vendor;
  final Formatter? formatter;

  /// False when the screen is already saying Deleted / Archived in a banner.
  final bool showStatePills;

  @override
  Widget build(BuildContext context) {
    return EntityDetailHeaderHost<Vendor>(
      entity: vendor,
      entityType: EntityType.vendor,
      recordId: vendor.id,
      formatter: formatter,
      project: (context, v) {
        final segments = _segments(context, v);
        return EntityHeaderFields(
          seedForAvatar: v.id,
          displayName: vendorDisplayName(context, v),
          createdAt: v.createdAt,
          updatedAt: v.updatedAt,
          isDeleted: v.isDeleted,
          isArchived: v.archivedAt != null,
          isDirty: v.isDirty,
          // A company name can run long, and with the number moved into the
          // subtitle there is nothing sharing its baseline to protect.
          nameMaxLines: 2,
          showStatePills: showStatePills,
          subtitle: segments.isEmpty
              ? DetailHeaderTimestamps(
                  createdAt: v.createdAt,
                  updatedAt: v.updatedAt,
                  formatter: formatter,
                )
              : DetailSubtitle(segments: segments),
          tags: v.tagIds.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: EntityTagsView(entityType: 'vendor', tagIds: v.tagIds),
                ),
        );
      },
    );
  }

  List<Widget> _segments(BuildContext context, Vendor v) {
    final place = _place(context, v);
    return [
      if (place.isNotEmpty) Text(place),
      // Its own segment so it stays copyable (it copies the bare number), and
      // LAST: with a pointer `CopyableValue` reserves the width of its hover
      // icon whether or not it is showing, which mid-line reads as a stray gap
      // before the next separator.
      if (v.number.isNotEmpty)
        CopyableValue(
          value: v.number,
          fillWidth: false,
          child: Text('#${v.number}'),
        ),
    ];
  }

  /// "City, Country" — enough to tell two vendors with the same name apart.
  ///
  /// **Only with a city.** The server gives every vendor a country whether or
  /// not anyone chose one, so a country on its own says nothing about this
  /// vendor; under a city it completes the place. The country name comes from
  /// the statics cache and is simply left out until that has loaded; a raw id
  /// here would be noise in the most prominent line on the screen.
  String _place(BuildContext context, Vendor v) {
    if (v.city.isEmpty) return '';
    final country = v.countryId.isEmpty
        ? ''
        : (context.read<Services>().statics.country(v.countryId)?.name ?? '');
    return [v.city, if (country.isNotEmpty) country].join(', ');
  }
}
