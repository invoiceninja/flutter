import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/address_block.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/address_format.dart';

/// The client's billing address, as one [AddressBlock] — copyable whole, with
/// a map link. Builds nothing when every field is empty.
///
/// [title] is the caller's because what this card should be called depends on
/// what else is on screen: "Address" when it is the only one, "Billing
/// Address" beside a different shipping address, and both names together when
/// the two are the same place (see `ClientDetailProfile`).
class ClientDetailAddressCard extends StatelessWidget {
  const ClientDetailAddressCard({super.key, required this.client, this.title});

  final Client client;

  /// Already localized. Null uses `address`.
  final String? title;

  /// Whether any address field is populated. The card also self-hides, but the
  /// layout has to know *before* building it — see the gap note on
  /// `ClientDetailProfile`, which gates every entry on this, including the
  /// pair where this card stacks above Shipping.
  /// Mirrors `ClientDetailShippingAddressCard.hasContent`.
  static bool hasContent(Client c) =>
      c.address1.isNotEmpty ||
      c.address2.isNotEmpty ||
      c.city.isNotEmpty ||
      c.state.isNotEmpty ||
      c.postalCode.isNotEmpty ||
      c.countryId.isNotEmpty;

  /// The address as display lines, ordered for its country.
  ///
  /// The country is **always** included. `Formatter.address` leaves a domestic
  /// one off, which is right on a PDF and wrong here: these lines are also
  /// what gets copied and what the map is searched for.
  ///
  /// Statics load at sign-in; in the first frame after login the map can be
  /// empty, so an unresolved country falls back to its raw id — which keeps
  /// "has content" and "draws something" the same question.
  static List<String> linesFor(BuildContext context, Client c) {
    final country = c.countryId.isEmpty
        ? null
        : context.read<Services>().statics.country(c.countryId);
    return formatAddressLines(
      address1: c.address1,
      address2: c.address2,
      city: c.city,
      state: c.state,
      postalCode: c.postalCode,
      // Orders the city / state / postal line the way the server renders PDFs.
      swapPostalCode: country?.swapPostalCode ?? false,
      countryName: c.countryId.isEmpty ? '' : (country?.name ?? c.countryId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = linesFor(context, client);
    if (lines.isEmpty) return const SizedBox.shrink();
    return DashboardCardShell(
      title: title ?? context.tr('address'),
      child: AddressBlock(lines: lines),
    );
  }
}
