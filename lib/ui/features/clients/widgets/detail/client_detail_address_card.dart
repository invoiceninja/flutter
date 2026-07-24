import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/address_format.dart';

/// "Address" card on the client detail screen. Renders street, city/state/zip,
/// and country (country name resolved via the cached statics map when
/// available; falls back to the raw id otherwise). Hides entirely when every
/// field is empty.
class ClientDetailAddressCard extends StatelessWidget {
  const ClientDetailAddressCard({super.key, required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    // Resolve the country once — its name AND its swap_postal_code flag, which
    // orders the city/state/postal line the same way the server renders PDFs.
    final countryObj = client.countryId.isEmpty
        ? null
        : context.read<Services>().statics.country(client.countryId);
    final cityLine = cityStateZip(
      city: client.city,
      state: client.state,
      postalCode: client.postalCode,
      swapPostalCode: countryObj?.swapPostalCode ?? false,
    );
    // Statics load at sign-in; in the first frame after login the map can be
    // empty — fall back to the raw id so the row still renders something.
    final country = client.countryId.isEmpty
        ? ''
        : (countryObj?.name ?? client.countryId);

    final rows = <Widget?>[
      if (client.address1.isNotEmpty)
        DetailInfoRow(label: context.tr('address1'), value: client.address1),
      if (client.address2.isNotEmpty)
        DetailInfoRow(label: context.tr('address2'), value: client.address2),
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
