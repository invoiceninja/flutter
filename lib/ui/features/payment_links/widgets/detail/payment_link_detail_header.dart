import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/payment_link.dart';
import 'package:admin/domain/recurring_frequency.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_header.dart';
import 'package:admin/utils/formatting.dart';

/// Per-entity header for the Payment Link record screen. Wraps the shared
/// [EntityDetailHeader] with the payment link's identity fields. Falls back
/// to `no_name_fallback` for nameless rows so the avatar seed stays
/// deterministic.
///
/// **The subtitle is how often it bills** ("Monthly", or "Once") — what tells
/// two tiers of the same product apart at a glance. The price is the standing
/// card's.
class PaymentLinkDetailHeader extends StatelessWidget {
  const PaymentLinkDetailHeader({
    super.key,
    required this.paymentLink,
    this.formatter,
    this.showStatePills = true,
  });

  final PaymentLink paymentLink;
  final Formatter? formatter;

  /// False when the screen is already saying Deleted / Archived in a banner.
  final bool showStatePills;

  @override
  Widget build(BuildContext context) {
    final freqKey = kRecurringFrequencyLabelKey[paymentLink.frequencyId];
    return EntityDetailHeader(
      // The id, never the name: a rename must not reshuffle the tint.
      seedForAvatar: paymentLink.id,
      displayName: paymentLink.name.isEmpty
          ? context.tr('no_name_fallback')
          : paymentLink.name,
      createdAt: paymentLink.createdAt,
      updatedAt: paymentLink.updatedAt,
      isDeleted: paymentLink.isDeleted,
      isArchived: paymentLink.archivedAt != null,
      isDirty: paymentLink.isDirty,
      formatter: formatter,
      nameMaxLines: 2,
      showStatePills: showStatePills,
      subtitle: DetailSubtitle(segments: [Text(context.tr(freqKey ?? 'once'))]),
    );
  }
}
