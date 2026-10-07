import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/data/models/domain/vendor_contact.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/detail/record_profile_layout.dart';
import 'package:admin/ui/features/vendors/widgets/detail/vendor_detail_address_card.dart';
import 'package:admin/ui/features/vendors/widgets/detail/vendor_detail_contacts_card.dart';
import 'package:admin/ui/features/vendors/widgets/detail/vendor_detail_details_card.dart';
import 'package:admin/ui/features/vendors/widgets/detail/vendor_detail_notes_card.dart';
import 'package:admin/utils/formatting.dart';

/// A vendor's reference fields — who to talk to, the details, the address,
/// notes. Always shown, between the comments card and the tabs. The vendor
/// half of `ClientDetailProfile`.
///
/// In order: Contacts, Details, Address, Notes. Tags are not here; they are
/// drawn under the vendor's name.
///
/// **Every entry is gated on its card's `hasContent`**, in both layouts. The
/// gap between cards is paid per entry rather than per painted card, so a card
/// that returned `SizedBox.shrink()` from its own `build` would leave a doubled
/// gap between its neighbours — and in the wide row an empty `Expanded` would
/// hold a third of the width for nothing.
///
/// * **≥ [Breakpoints.entityFormMultiColumn]**: Contacts · Details · Address
///   side by side as equal cards that end on one line, as many of the three as
///   have content, with Notes full width beneath. Contacts is a card *in that
///   row* on purpose: across the whole window each contact's buttons would sit
///   a screen's width from the name they belong to.
/// * **below**: one stack. The record column above this has already centred
///   and capped it, so there is no second cap here.
class VendorDetailProfile extends StatelessWidget {
  const VendorDetailProfile({
    super.key,
    required this.vendor,
    required this.company,
    this.formatter,
  });

  final Vendor vendor;

  /// For the custom-field labels in Details and on each contact.
  final Company? company;

  /// For the Details card's dates.
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final contacts = visibleVendorContacts(vendor.contacts, company: company);
    final hasDetails = VendorDetailDetailsCard.hasContent(
      context,
      vendor,
      company,
      formatter: formatter,
    );
    final hasAddress = VendorDetailAddressCard.hasContent(vendor);
    final hasNotes = VendorDetailNotesCard.hasContent(vendor);
    final lead = <Widget>[
      if (contacts.isNotEmpty) _contacts(contacts),
      if (hasDetails)
        VendorDetailDetailsCard(
          vendor: vendor,
          company: company,
          formatter: formatter,
        ),
      if (hasAddress) VendorDetailAddressCard(vendor: vendor),
    ];
    final tail = <Widget>[if (hasNotes) VendorDetailNotesCard(vendor: vendor)];

    // The level row, the lone-card case and the stack are the shared
    // layout's; this decides only which cards exist.
    return RecordProfileLayout(lead: lead, tail: tail);
  }

  Widget _contacts(List<VendorContact> contacts) => VendorDetailContactsCard(
    contacts: contacts,
    vendorId: vendor.id,
    company: company,
  );
}
