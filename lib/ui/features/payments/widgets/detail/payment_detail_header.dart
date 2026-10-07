import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_header.dart';
import 'package:admin/ui/core/detail/entity_detail_header_host.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/ui/features/payments/widgets/payment_status_pill.dart';
import 'package:admin/utils/formatting.dart';

/// Per-entity wrapper over [EntityDetailHeaderHost]: the payment's number as
/// its name, and under it who paid, when, and how.
///
/// **The client is a link, and it opens the client — never an edit screen.**
/// `ClientNameLabel(link: true)` goes to the client's full-screen view.
///
/// **The status rides under the subtitle with the tags.** A payment's status
/// (Completed, Refunded, Unapplied …) is part of what it *is*, and the header
/// used to say nothing about it: the pill was on the list row and gone the
/// moment the row was opened.
class PaymentDetailHeader extends StatelessWidget {
  const PaymentDetailHeader({
    super.key,
    required this.payment,
    this.formatter,
    this.showStatePills = true,
  });

  final Payment payment;
  final Formatter? formatter;

  /// False when the screen is already saying Deleted / Archived in a banner.
  final bool showStatePills;

  @override
  Widget build(BuildContext context) {
    return EntityDetailHeaderHost<Payment>(
      entity: payment,
      entityType: EntityType.payment,
      recordId: payment.id,
      formatter: formatter,
      project: (context, p) {
        final segments = _segments(context, p);
        return EntityHeaderFields(
          seedForAvatar: p.id,
          displayName: p.number.isEmpty
              ? context.tr('no_name_fallback')
              : '#${p.number}',
          createdAt: p.createdAt,
          updatedAt: p.updatedAt,
          isDeleted: p.isDeleted,
          isArchived: p.archivedAt != null,
          isDirty: p.isDirty,
          showStatePills: showStatePills,
          subtitle: segments.isEmpty
              ? DetailHeaderTimestamps(
                  createdAt: p.createdAt,
                  updatedAt: p.updatedAt,
                  formatter: formatter,
                )
              : DetailSubtitle(segments: segments),
          tags: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: InSpacing.sm,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PaymentStatusPill(statusId: p.calculatedStatusId),
                if (p.tagIds.isNotEmpty)
                  EntityTagsView(entityType: 'payment', tagIds: p.tagIds),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _segments(BuildContext context, Payment p) {
    final date = p.date;
    final f = formatter;
    final type = p.typeId.isEmpty
        ? ''
        : (context.read<Services>().statics.paymentType(p.typeId)?.name ?? '');
    return [
      if (p.clientId.isNotEmpty)
        ClientNameLabel(
          clientId: p.clientId,
          link: true,
          // The link tone at rest too: on a pointer platform the label only
          // underlines on hover, and in a line of muted text that is a link
          // nobody finds.
          style: TextStyle(color: context.inTheme.accentInk),
        ),
      // Not until the formatter is here: a raw ISO date in the most prominent
      // line on the screen is worse than a date that arrives a frame later.
      if (date != null && f != null) Text(f.date(date.toIso())),
      if (type.isNotEmpty) Text(type),
    ];
  }
}
