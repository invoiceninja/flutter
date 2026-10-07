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
    this.subtitle,
    this.tags,
    this.nameMaxLines = 1,
    this.showStatePills = true,
  });

  /// Replaces the created/updated line under the name, and takes the number
  /// with it: a host that passes this puts the number in the subtitle (see
  /// [DetailSubtitle]) so a long name can use the whole first line.
  ///
  /// Null keeps the original layout, which every entity that has not adopted
  /// the record page still uses.
  final Widget? subtitle;

  /// The record's own tags, drawn under the subtitle. Null or a widget that
  /// builds nothing costs no space.
  final Widget? tags;

  /// How many lines the name may take. 1 everywhere except a host with a
  /// [subtitle], where there is no number sharing the baseline and a long
  /// company name would otherwise be cut off with no way to read it.
  final int nameMaxLines;

  /// False when the screen says the same thing in a banner — a Deleted pill
  /// under a "this record is deleted" strip is the word twice.
  final bool showStatePills;

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
                      maxLines: nameMaxLines,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (subtitle != null)
                    // The number rides in the subtitle instead.
                    const SizedBox.shrink()
                  else if (numberWidget != null) ...[
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
              subtitle ??
                  _Timestamps(
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    formatter: formatter,
                    tokens: tokens,
                  ),
              ?tags,
            ],
          ),
        ),
        _HeaderPills(
          // The Unsynced pill is not a lifecycle state and no banner repeats
          // it, so it survives `showStatePills: false`.
          isDeleted: showStatePills && isDeleted,
          isArchived: showStatePills && isArchived,
          isDirty: isDirty,
          tokens: tokens,
        ),
      ],
    );
  }
}

/// The fallback subtitle for a host that passes [EntityDetailHeader.subtitle]
/// but has nothing to put in it: the same created/updated line the header
/// draws on its own.
class DetailHeaderTimestamps extends StatelessWidget {
  const DetailHeaderTimestamps({
    super.key,
    required this.createdAt,
    required this.updatedAt,
    required this.formatter,
  });

  final DateTime createdAt;
  final DateTime updatedAt;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) => _Timestamps(
    createdAt: createdAt,
    updatedAt: updatedAt,
    formatter: formatter,
    tokens: context.inTheme,
  );
}

/// A header subtitle built from independent segments — a copyable number, a
/// place, a link to a parent record — joined by a middle dot.
///
/// Segments are widgets, not strings, so one can be copyable or tappable while
/// its neighbour is plain text. A `Wrap`, so a long subtitle breaks between
/// segments rather than mid-word or off the edge of a 440 px pane.
///
/// **Put a `CopyableValue` segment last.** With a pointer it reserves the
/// width of its hover icon whether or not the icon is showing; anywhere but
/// the end of the line that reads as a stray gap before the next separator.
///
/// Drawn in `ink2`: this line now carries real information (who, where), and
/// `ink3` on a card is under the 4.5:1 floor for text this small.
class DetailSubtitle extends StatelessWidget {
  const DetailSubtitle({super.key, required this.segments});

  /// Empty builds nothing; the caller decides what to show instead.
  final List<Widget> segments;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return const SizedBox.shrink();
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.inTheme.ink2);
    return DefaultTextStyle.merge(
      style: style,
      child: Wrap(
        // `start`, not `center`: a copyable segment is taller than a plain one
        // (it holds a 22 px icon slot, top-aligned), and centring the run sat
        // its text a few pixels above its neighbours'.
        crossAxisAlignment: WrapCrossAlignment.start,
        runSpacing: 2,
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0) const Text(_kSegmentSeparator),
            segments[i],
          ],
        ],
      ),
    );
  }
}

/// Typographic, not prose — the same middle dot the timestamp line joins on.
const String _kSegmentSeparator = '  ·  ';

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
