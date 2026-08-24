import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/avatar_tint.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/initials_avatar.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/ui/core/widgets/unsynced_pill.dart';
import 'package:admin/utils/formatting.dart';

/// Top-of-page identity row shared by every entity detail screen.
///
/// Layout: tinted-initials avatar | name (+ optional `#<number>`) +
/// created/updated subtitle | deleted / archived / unsynced status pills.
/// Action buttons live in the screen's AppBar via
/// `EntityDetailActionsRow`, not here.
///
/// Per-entity wrappers (`ClientDetailHeader`, `ProductDetailHeader`, …)
/// resolve the display-name cascade + optional number and forward
/// status/timestamp fields straight from the domain model.
class EntityDetailHeader extends StatelessWidget {
  const EntityDetailHeader({
    super.key,
    required this.seedForAvatar,
    required this.displayName,
    this.number,
    this.numberWidget,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
    required this.isArchived,
    required this.isDirty,
    this.formatter,
    this.fallbackIcon,
  });

  final String seedForAvatar;
  final String displayName;
  final String? number;

  /// Entity-type icon shown in the avatar when [displayName] yields no
  /// initials — i.e. a number-only identity like a task/invoice/payment
  /// (`#0009`). Named entities keep their tinted initials; this only swaps in
  /// for the otherwise-`?` case. Null falls back to the literal `?`.
  final IconData? fallbackIcon;

  /// Optional widget rendered in the secondary slot beside the display
  /// name (no `#` prefix), used for resolved references like a client
  /// name. Takes precedence over [number] when non-null.
  final Widget? numberWidget;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final bool isArchived;
  final bool isDirty;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Avatar(
          seed: seedForAvatar,
          initials: initialsFor(displayName),
          fallbackIcon: fallbackIcon,
        ),
        SizedBox(width: InSpacing.lg(context)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: tokens.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (numberWidget != null) ...[
                    const SizedBox(width: InSpacing.sm),
                    numberWidget!,
                  ] else if (number != null && number!.isNotEmpty) ...[
                    const SizedBox(width: InSpacing.sm),
                    // Copies the bare number (no `#`); icon hugs the value.
                    CopyableValue(
                      value: number!,
                      fillWidth: false,
                      child: Text(
                        '#${number!}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: tokens.ink3,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              _Timestamps(
                createdAt: createdAt,
                updatedAt: updatedAt,
                formatter: formatter,
                tokens: tokens,
              ),
            ],
          ),
        ),
        _HeaderPills(
          isDeleted: isDeleted,
          isArchived: isArchived,
          isDirty: isDirty,
          tokens: tokens,
        ),
      ],
    );
  }
}

class _Timestamps extends StatelessWidget {
  const _Timestamps({
    required this.createdAt,
    required this.updatedAt,
    required this.formatter,
    required this.tokens,
  });
  final DateTime createdAt;
  final DateTime updatedAt;
  final Formatter? formatter;
  final InTheme tokens;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final created = _format(createdAt);
    final updated = _format(updatedAt);
    final parts = <String>[
      if (created.isNotEmpty) context.tr('created_short', {'date': created}),
      if (updated.isNotEmpty) context.tr('updated_short', {'date': updated}),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join(' · '),
      style: theme.textTheme.bodySmall?.copyWith(color: tokens.ink3),
    );
  }

  String _format(DateTime dt) {
    if (dt.millisecondsSinceEpoch == 0) return '';
    final f = formatter;
    if (f == null) return '';
    // toLocal() first: these are server epoch timestamps (UTC-backed), and
    // taking the ISO date of the UTC instant renders the wrong calendar day
    // for any user whose evening/morning falls across the UTC boundary
    // (e.g. created 23:30 UTC = next day in UTC+2 — the header said
    // "yesterday"). No-op when the value is already local.
    return f.date(dt.toLocal().toIso8601String().split('T').first);
  }
}

class _HeaderPills extends StatelessWidget {
  const _HeaderPills({
    required this.isDeleted,
    required this.isArchived,
    required this.isDirty,
    required this.tokens,
  });
  final bool isDeleted;
  final bool isArchived;
  final bool isDirty;
  final InTheme tokens;

  @override
  Widget build(BuildContext context) {
    final pills = <Widget>[];
    if (isDeleted) {
      pills.add(
        StatusPill(
          label: context.tr('deleted'),
          fgColor: tokens.overdue,
          bgColor: tokens.overdueSoft,
          tooltip: context.tr('deleted_soft_delete_tooltip'),
        ),
      );
    } else if (isArchived) {
      pills.add(
        StatusPill(
          label: context.tr('archived'),
          fgColor: tokens.draft,
          bgColor: tokens.draftSoft,
          tooltip: context.tr('archived'),
        ),
      );
    }
    if (isDirty) {
      pills.add(const UnsyncedPill());
    }
    if (pills.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 4, children: pills);
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.seed, this.initials, this.fallbackIcon});
  final String seed;
  final String? initials;
  final IconData? fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: avatarTintFor(seed),
        borderRadius: BorderRadius.circular(InRadii.r2),
      ),
      child: _content(),
    );
  }

  Widget _content() {
    final text = initials;
    if (text != null) {
      return Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          height: 1,
        ),
      );
    }
    if (fallbackIcon != null) {
      return Icon(fallbackIcon, color: Colors.white, size: 28);
    }
    // No usable initials and no entity icon — last-resort placeholder.
    return const Text(
      '?',
      style: TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1,
      ),
    );
  }
}
