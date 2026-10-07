import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/bank_account.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_header.dart';
import 'package:admin/utils/formatting.dart';

/// Per-entity header for the bank-account record screen: its name, and under
/// it the institution, the kind of account and how it is connected
/// ("Chase · Checking · Yodlee").
///
/// A manually entered account has none of the three, and falls back to the
/// created / updated dates the header shows for every other entity, so the
/// line is never blank.
class BankAccountDetailHeader extends StatelessWidget {
  const BankAccountDetailHeader({
    super.key,
    required this.account,
    this.formatter,
    this.showStatePills = true,
  });

  final BankAccount account;
  final Formatter? formatter;

  /// False when the screen is already saying Deleted / Archived in a banner.
  final bool showStatePills;

  @override
  Widget build(BuildContext context) {
    final a = account;
    final segments = [
      if (a.provider.trim().isNotEmpty) Text(a.provider.trim()),
      if (a.type.trim().isNotEmpty) Text(a.type.trim()),
      // "Manual" for an account nobody connected says nothing new; name the
      // aggregator only when there is one.
      if (a.integrationType.isNotEmpty)
        Text(context.tr(labelKeyForProvider(a.integrationType))),
    ];
    return EntityDetailHeader(
      seedForAvatar: a.id,
      displayName: a.name.trim().isEmpty ? context.tr('untitled') : a.name,
      createdAt: a.createdAt,
      updatedAt: a.updatedAt,
      isDeleted: a.isDeleted,
      isArchived: a.archivedAt != null,
      isDirty: a.isDirty,
      formatter: formatter,
      fallbackIcon: Icons.account_balance_outlined,
      nameMaxLines: 2,
      showStatePills: showStatePills,
      subtitle: segments.isEmpty
          ? DetailHeaderTimestamps(
              createdAt: a.createdAt,
              updatedAt: a.updatedAt,
              formatter: formatter,
            )
          : DetailSubtitle(segments: segments),
    );
  }
}
