import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/ui/core/widgets/centered_form_column.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_address_card.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_contacts_card.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_details_card.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_notes_card.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_payment_methods_card.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_shipping_address_card.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/formatting.dart';

/// Responsive grid for the client detail body cards.
///
/// - **≥1000 px**: three equal-width columns — Details · Address · Contacts —
///   with Notes spanning the full width on a second row when it has content.
///   If Contacts has no row to show, drops to two equal-width columns so
///   Details and Address don't get stretched by a zero-width sibling.
/// - **<1000 px**: single centered column (≤820 px), all cards stacked. Every
///   entry there is gated on its card's `hasContent`, because the gap loop
///   below pays `InSpacing.md` per *entry*, not per painted card — a card that
///   returns `SizedBox.shrink()` from its own `build` would leave a doubled
///   gap between its neighbours.
///
/// The KPI/Standing card has moved up into `ClientDetailKpiStrip` (rendered
/// by the screen above this grid), so this widget no longer owns it.
///
/// Most cards return `SizedBox.shrink()` from `build` when they have no data.
/// In the ≥1000 px grid that collapses a card's *height* but not its column —
/// an `Expanded` keeps its share of the row either way, which is the point:
/// the Details card is deliberately kept there even when empty so the three
/// columns stay aligned. It is dropped from the stacked single-column layout
/// (mobile and the master-detail sidebar preview pane), where an empty box is
/// just wasted space. Anywhere cards stack — the whole stacked list, and the
/// Address / Shipping pair inside the wide grid's middle column — the entry
/// must be gated, because the gap is paid per entry rather than per painted
/// card.
class ClientDetailCardsGrid extends StatelessWidget {
  const ClientDetailCardsGrid({
    super.key,
    required this.client,
    required this.formatter,
  });

  final Client client;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= Breakpoints.entityFormMultiColumn;
        if (wide) return _wide(context, client);
        return CenteredFormColumn(child: _stacked(context, client));
      },
    );
  }

  Widget _wide(BuildContext context, Client c) {
    final hasContacts = ClientDetailContactsCard.hasContent(c.contacts);
    final hasNotes = c.privateNotes.isNotEmpty || c.publicNotes.isNotEmpty;
    // The middle column stacks two cards, so it pays the same per-entry gap the
    // stacked layout does: a client with a shipping address but no billing one
    // left the Address card collapsed and its gap behind, pushing Shipping
    // ~12 px below the cards beside it.
    final hasAddress = ClientDetailAddressCard.hasContent(c);
    final hasShipping = ClientDetailShippingAddressCard.hasContent(c);
    final columns = <Widget>[
      Expanded(child: ClientDetailDetailsCard(client: c)),
      SizedBox(width: InSpacing.md(context)),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasAddress) ClientDetailAddressCard(client: c),
            if (hasShipping) ...[
              if (hasAddress) SizedBox(height: InSpacing.md(context)),
              ClientDetailShippingAddressCard(client: c),
            ],
          ],
        ),
      ),
      if (hasContacts) ...[
        SizedBox(width: InSpacing.md(context)),
        Expanded(
          child: ClientDetailContactsCard(
            contacts: c.contacts,
            clientHash: c.clientHash,
            clientId: c.id,
          ),
        ),
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
        if (ClientDetailPaymentMethodsCard.hasContent(c)) ...[
          SizedBox(height: InSpacing.md(context)),
          ClientDetailPaymentMethodsCard(client: c),
        ],
        if (hasNotes) ...[
          SizedBox(height: InSpacing.md(context)),
          ClientDetailNotesCard(client: c),
        ],
        if (c.tagIds.isNotEmpty) ...[
          SizedBox(height: InSpacing.md(context)),
          _TagsCard(client: c),
        ],
      ],
    );
  }

  Widget _stacked(BuildContext context, Client c) {
    final cards = <Widget>[
      if (ClientDetailDetailsCard.hasContent(c))
        ClientDetailDetailsCard(client: c),
      if (ClientDetailAddressCard.hasContent(c))
        ClientDetailAddressCard(client: c),
      if (ClientDetailShippingAddressCard.hasContent(c))
        ClientDetailShippingAddressCard(client: c),
      if (ClientDetailContactsCard.hasContent(c.contacts))
        ClientDetailContactsCard(
          contacts: c.contacts,
          clientHash: c.clientHash,
          clientId: c.id,
        ),
      if (ClientDetailPaymentMethodsCard.hasContent(c))
        ClientDetailPaymentMethodsCard(client: c),
      if (c.privateNotes.isNotEmpty || c.publicNotes.isNotEmpty)
        ClientDetailNotesCard(client: c),
      if (c.tagIds.isNotEmpty) _TagsCard(client: c),
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

class _TagsCard extends StatelessWidget {
  const _TagsCard({required this.client});
  final Client client;

  @override
  Widget build(BuildContext context) => DashboardCardShell(
    title: context.tr('tags'),
    child: EntityTagsView(entityType: 'client', tagIds: client.tagIds),
  );
}
