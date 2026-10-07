import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_header.dart';
import 'package:admin/ui/core/detail/entity_detail_header_host.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/utils/formatting.dart';

/// Per-entity wrapper over [EntityDetailHeaderHost]. Resolves the client's
/// display-name cascade (`displayName` → `name` → `no_name_fallback`) and
/// builds the line under it.
///
/// **The subtitle is place · number.** It does not name the contact: the
/// Contacts card below has every one of them, and the same name twice within
/// a hundred pixels is noise. When a client has neither a number nor an
/// address, the line falls back to the created/updated dates the header shows
/// for every other entity, so it is never blank.
///
/// **Tags sit under the subtitle.** They are the user's own classification of
/// this client ("VIP", "Retainer"), and a label worth applying is a label
/// worth seeing without opening anything.
class ClientDetailHeader extends StatelessWidget {
  const ClientDetailHeader({
    super.key,
    required this.client,
    this.formatter,
    this.showStatePills = true,
  });

  final Client client;
  final Formatter? formatter;

  /// False when the screen is already saying Deleted / Archived in a banner.
  final bool showStatePills;

  @override
  Widget build(BuildContext context) {
    return EntityDetailHeaderHost<Client>(
      entity: client,
      entityType: EntityType.client,
      recordId: client.id,
      formatter: formatter,
      project: (context, c) {
        final segments = _segments(context, c);
        return EntityHeaderFields(
          seedForAvatar: c.id,
          displayName: c.displayName.isNotEmpty
              ? c.displayName
              : (c.name.isNotEmpty ? c.name : context.tr('no_name_fallback')),
          createdAt: c.createdAt,
          updatedAt: c.updatedAt,
          isDeleted: c.isDeleted,
          isArchived: c.archivedAt != null,
          isDirty: c.isDirty,
          // A company name can run long, and with the number moved into the
          // subtitle there is nothing sharing its baseline to protect.
          nameMaxLines: 2,
          showStatePills: showStatePills,
          subtitle: segments.isEmpty
              ? DetailHeaderTimestamps(
                  createdAt: c.createdAt,
                  updatedAt: c.updatedAt,
                  formatter: formatter,
                )
              : DetailSubtitle(segments: segments),
          tags: c.tagIds.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: EntityTagsView(entityType: 'client', tagIds: c.tagIds),
                ),
        );
      },
    );
  }

  List<Widget> _segments(BuildContext context, Client c) {
    final place = _place(context, c);
    return [
      if (place.isNotEmpty) Text(place),
      // Its own segment so it stays copyable (it copies the bare number), and
      // LAST: with a pointer `CopyableValue` reserves the width of its hover
      // icon whether or not it is showing, which mid-line reads as a stray gap
      // before the next separator.
      if (c.number.isNotEmpty)
        CopyableValue(
          value: c.number,
          fillWidth: false,
          child: Text('#${c.number}'),
        ),
    ];
  }

  /// "City, Country" from the billing address — enough to tell two clients
  /// with the same name apart. The country name comes from the statics cache
  /// and is simply left out until that has loaded; a raw id here would be
  /// noise in the most prominent line on the screen.
  String _place(BuildContext context, Client c) {
    final country = c.countryId.isEmpty
        ? ''
        : (context.read<Services>().statics.country(c.countryId)?.name ?? '');
    return [
      if (c.city.isNotEmpty) c.city,
      if (country.isNotEmpty) country,
    ].join(', ');
  }
}
