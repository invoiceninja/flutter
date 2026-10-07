import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/contact.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/detail_row_columns.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_address_card.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_contacts_card.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_details_card.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_notes_card.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_payment_methods_card.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_shipping_address_card.dart';
import 'package:admin/utils/formatting.dart';

/// A client's reference fields — who to talk to, the details, the address,
/// saved payment methods, notes. Always shown, between the comments card and
/// the tabs.
///
/// In order: Contacts, Details, Address (billing over shipping), Payment
/// Methods, Notes. Tags are not here; they are drawn under the client's name.
///
/// **Every entry is gated on its card's `hasContent`**, in both layouts. The
/// gap between cards is paid per entry rather than per painted card, so a card
/// that returned `SizedBox.shrink()` from its own `build` would leave a doubled
/// gap between its neighbours — and in the wide row an empty `Expanded` would
/// hold a third of the width for nothing.
///
/// * **≥ [Breakpoints.entityFormMultiColumn]**: Contacts · Details · Address
///   side by side as equal cards, as many of the three as have content, with
///   Payment Methods and Notes full width beneath. Contacts is a card *in that
///   row* on purpose: as a strip across the whole window, each contact's copy
///   and open-portal buttons sat at the far edge, a screen's width from the
///   name they belong to.
/// * **below**: one stack. The record column above this has already centred
///   and capped it, so there is no second cap here.
class ClientDetailProfile extends StatelessWidget {
  const ClientDetailProfile({
    super.key,
    required this.client,
    required this.company,
    this.formatter,
  });

  final Client client;

  /// For the Details card's rate and dates — see `ClientDetailDetailsCard`.
  final Formatter? formatter;

  /// For the custom-field labels in Details — see `ClientDetailDetailsCard`.
  final Company? company;

  @override
  Widget build(BuildContext context) {
    final s = _Sections.of(context, client, company, formatter);
    final gap = SizedBox(height: InSpacing.md(context));

    Widget contacts() => ClientDetailContactsCard(
      contacts: s.contacts,
      clientHash: client.clientHash,
      clientId: client.id,
      company: company,
    );
    Widget details() => ClientDetailDetailsCard(
      client: client,
      company: company,
      formatter: formatter,
    );
    // Billing over shipping; the pair pays the same per-entry gap. The billing
    // card is named for what it is standing next to: on its own it is just the
    // address, beside a different shipping address it is the billing one, and
    // when the two are the same place it is both.
    final billingTitle = s.sameAddress
        ? '${context.tr('billing_address')} · ${context.tr('shipping_address')}'
        : s.shipping
        ? context.tr('billing_address')
        : null;
    // [fill]: in the wide row this column is stretched to the row's height,
    // and the *last* card in it has to take that height — a `Column` that is
    // merely as tall as the row leaves its card short, ending above the
    // Contacts and Details cards beside it. Never in the stack, where the
    // height is unbounded and there is nothing to fill.
    Widget addresses({required bool fill}) {
      Widget last(Widget card) => fill ? Expanded(child: card) : card;
      final billing = ClientDetailAddressCard(
        client: client,
        title: billingTitle,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (s.address) s.shipping ? billing : last(billing),
          if (s.address && s.shipping) gap,
          if (s.shipping) last(ClientDetailShippingAddressCard(client: client)),
        ],
      );
    }

    final tail = <Widget>[
      if (s.paymentMethods) ClientDetailPaymentMethodsCard(client: client),
      if (s.notes) ClientDetailNotesCard(client: client),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= Breakpoints.entityFormMultiColumn;
        final hasAddress = s.address || s.shipping;
        final leadCount =
            (s.contacts.isNotEmpty ? 1 : 0) +
            (s.details ? 1 : 0) +
            (hasAddress ? 1 : 0);
        final inRow = wide && leadCount > 1;
        final lead = <Widget>[
          if (s.contacts.isNotEmpty) contacts(),
          if (s.details) details(),
          if (hasAddress) addresses(fill: inRow),
        ];
        final rows = <Widget>[
          if (inRow)
            // `IntrinsicHeight` so the cards in the row end on one line. Legal
            // here because none of the three contains a `LayoutBuilder` — the
            // Contacts card reads `MediaQuery` instead for exactly this reason.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < lead.length; i++) ...[
                    if (i > 0) SizedBox(width: InSpacing.md(context)),
                    Expanded(child: lead[i]),
                  ],
                ],
              ),
            )
          else if (wide && lead.length == 1)
            // Alone in its row — see `DetailRowColumnsScope`.
            DetailRowColumnsScope(columns: 2, child: lead.single)
          else
            ...lead,
          ...tail,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < rows.length; i++) ...[if (i > 0) gap, rows[i]],
          ],
        );
      },
    );
  }
}

/// Which of the profile's sections have content — computed once per build.
class _Sections {
  const _Sections({
    required this.contacts,
    required this.details,
    required this.address,
    required this.shipping,
    required this.sameAddress,
    required this.paymentMethods,
    required this.notes,
  });

  factory _Sections.of(
    BuildContext context,
    Client client,
    Company? company,
    Formatter? formatter,
  ) {
    final hasBilling = ClientDetailAddressCard.hasContent(client);
    final hasShipping = ClientDetailShippingAddressCard.hasContent(client);
    // The same place, compared as it is displayed — so a shipping address that
    // differs only in something the block does not print is still one block.
    final same =
        hasBilling &&
        hasShipping &&
        listEquals(
          ClientDetailAddressCard.linesFor(context, client),
          ClientDetailShippingAddressCard.linesFor(context, client),
        );
    return _Sections(
      contacts: visibleClientContacts(client.contacts, company: company),
      details: ClientDetailDetailsCard.hasContent(
        context,
        client,
        company,
        formatter: formatter,
      ),
      address: hasBilling,
      shipping: hasShipping && !same,
      sameAddress: same,
      paymentMethods: ClientDetailPaymentMethodsCard.hasContent(client),
      notes: ClientDetailNotesCard.hasContent(client),
    );
  }

  final List<Contact> contacts;
  final bool details;
  final bool address;

  /// A shipping address worth its own block — i.e. one that is not simply the
  /// billing address again.
  final bool shipping;

  /// Billing and shipping are the same place. The shipping block is dropped,
  /// and the billing one says so in its title rather than letting a user
  /// wonder whether this client ships somewhere that was never entered.
  final bool sameAddress;
  final bool paymentMethods;
  final bool notes;
}
