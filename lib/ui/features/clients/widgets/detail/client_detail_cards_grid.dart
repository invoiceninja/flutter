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
///   If Contacts is empty, drops to two equal-width columns so Details and
///   Address don't get stretched by a zero-width sibling.
/// - **<1000 px**: single centered column (≤820 px), all cards stacked.
///
/// The KPI/Standing card has moved up into `ClientDetailKpiStrip` (rendered
/// by the screen above this grid), so this widget no longer owns it.
///
/// Most cards return `SizedBox.shrink()` from `build` when they have no data,
/// so empty cards collapse out of the layout naturally. The Details card is
/// the exception: it's kept in the ≥1000 px grid even when empty (so the
/// three `Expanded` columns stay aligned and no gap appears), but dropped
/// from the stacked single-column layout — mobile and the master-detail
/// sidebar preview pane — where an empty box is just wasted space.
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
    final hasContacts = c.contacts.isNotEmpty;
    final hasNotes = c.privateNotes.isNotEmpty || c.publicNotes.isNotEmpty;
    final columns = <Widget>[
      Expanded(child: ClientDetailDetailsCard(client: c)),
      SizedBox(width: InSpacing.md(context)),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClientDetailAddressCard(client: c),
            if (ClientDetailShippingAddressCard.hasContent(c)) ...[
              SizedBox(height: InSpacing.md(context)),
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
      ClientDetailAddressCard(client: c),
      if (ClientDetailShippingAddressCard.hasContent(c))
        ClientDetailShippingAddressCard(client: c),
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
