import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/address_block.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/address_format.dart';

/// The client's shipping address — the shipping_* mirror of
/// [ClientDetailAddressCard]. Builds nothing when every shipping field is
/// empty, which is the common case.
///
/// `ClientDetailProfile` does not mount this when the shipping address is the
/// same place as the billing one; it retitles the billing card instead.
class ClientDetailShippingAddressCard extends StatelessWidget {
  const ClientDetailShippingAddressCard({super.key, required this.client});

  final Client client;

  /// Whether any shipping field is populated — drives both this card's
  /// visibility and the layout's decision to give it an entry.
  static bool hasContent(Client c) =>
      c.shippingAddress1.isNotEmpty ||
      c.shippingAddress2.isNotEmpty ||
      c.shippingCity.isNotEmpty ||
      c.shippingState.isNotEmpty ||
      c.shippingPostalCode.isNotEmpty ||
      c.shippingCountryId.isNotEmpty;

  /// See [ClientDetailAddressCard.linesFor].
  static List<String> linesFor(BuildContext context, Client c) {
    final country = c.shippingCountryId.isEmpty
        ? null
        : context.read<Services>().statics.country(c.shippingCountryId);
    return formatAddressLines(
      address1: c.shippingAddress1,
      address2: c.shippingAddress2,
      city: c.shippingCity,
      state: c.shippingState,
      postalCode: c.shippingPostalCode,
      swapPostalCode: country?.swapPostalCode ?? false,
      countryName: c.shippingCountryId.isEmpty
          ? ''
          : (country?.name ?? c.shippingCountryId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = linesFor(context, client);
    if (lines.isEmpty) return const SizedBox.shrink();
    return DashboardCardShell(
      title: context.tr('shipping_address'),
      child: AddressBlock(lines: lines),
    );
  }
}
