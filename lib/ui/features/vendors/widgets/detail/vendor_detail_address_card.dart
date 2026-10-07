import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/address_block.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/address_format.dart';

/// The vendor's address, as one [AddressBlock] — copyable whole, with a map
/// link. Builds nothing when there is no address to show ([hasContent]).
///
/// It used to be four label/value rows, which copied a line at a time and put
/// the city, state and postal code together under a row labelled "City".
class VendorDetailAddressCard extends StatelessWidget {
  const VendorDetailAddressCard({super.key, required this.vendor});

  final Vendor vendor;

  /// Whether there is an address to show. The card also self-hides, but the
  /// layout has to know *before* building it — see the gap note on
  /// `VendorDetailProfile`.
  ///
  /// **A country alone is not an address.** The server gives every vendor one
  /// — the company's own, when none was sent (`VendorRepository::save`) — so
  /// counting it put an "Address" card holding one word and a map link on
  /// every vendor ever created. A vendor with a country and nothing else gets
  /// a Country row in Details instead (`VendorDetailDetailsCard`).
  static bool hasContent(Vendor v) =>
      v.address1.isNotEmpty ||
      v.address2.isNotEmpty ||
      v.city.isNotEmpty ||
      v.state.isNotEmpty ||
      v.postalCode.isNotEmpty;

  /// The address as display lines, ordered for its country.
  ///
  /// The country is **always** included: these lines are also what gets
  /// copied and what the map is searched for.
  ///
  /// Statics load at sign-in; in the first frame after login the map can be
  /// empty, so an unresolved country falls back to its raw id — which keeps
  /// "has content" and "draws something" the same question.
  static List<String> linesFor(BuildContext context, Vendor v) {
    final country = v.countryId.isEmpty
        ? null
        : context.read<Services>().statics.country(v.countryId);
    return formatAddressLines(
      address1: v.address1,
      address2: v.address2,
      city: v.city,
      state: v.state,
      postalCode: v.postalCode,
      // Orders the city / state / postal line the way the server renders PDFs.
      swapPostalCode: country?.swapPostalCode ?? false,
      countryName: v.countryId.isEmpty ? '' : (country?.name ?? v.countryId),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!hasContent(vendor)) return const SizedBox.shrink();
    final lines = linesFor(context, vendor);
    return DashboardCardShell(
      title: context.tr('address'),
      child: AddressBlock(lines: lines),
    );
  }
}
