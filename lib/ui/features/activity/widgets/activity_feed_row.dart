import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/ui/features/dashboard/helpers/activity_formatter.dart';
import 'package:admin/utils/formatting.dart';

/// The audit-lens `meta` line for [ActivityFeedRow]: an absolute,
/// company-formatted local timestamp joined with the originating IP.
///
/// `Formatter.date` suffixes a missing `Z` and calls `.toLocal()` itself, so
/// the UTC epoch the server sends is what must go in — hence `isUtc: true`.
/// Falls back to the relative [ActivityRender.meta] until the company
/// `Formatter` has loaded, and note the IP is only in the raw payload
/// (`DashboardActivity` doesn't destructure it).
String activityAuditMeta(
  DashboardActivity a, {
  required ActivityRender render,
  required Formatter? formatter,
}) {
  final when =
      formatter?.date(
        DateTime.fromMillisecondsSinceEpoch(
          a.createdAt * 1000,
          isUtc: true,
        ).toIso8601String(),
        showTime: true,
        showSeconds: false,
      ) ??
      render.meta;
  final ip = (a.raw['ip'] ?? '').toString();
  return ip.isEmpty ? when : '$when · $ip';
}

/// Visual weight of an [ActivityFeedRow].
enum ActivityRowDensity {
  /// The dashboard card's compact row — 26 px circle, 12.5/11 px text.
  card,

  /// Full-page / detail-section row — 28 px rounded square, body text styles.
  page,
}

/// One rendered activity line, shared by the dashboard card, the `/activity`
/// screen, and the per-user activity section on User Details.
///
/// [meta] is supplied by the caller rather than derived here because the three
/// surfaces answer different questions with it: the card shows relative time
/// ("2 minutes ago"), while the audit lenses show an absolute company-formatted
/// timestamp joined with the originating IP.
///
/// **A row with no [onTap] renders inert** — no ripple, no chevron, no `button`
/// semantics. `activityDeepLinkTarget` returns null for system-only rows that
/// reference no entity, and dressing those as tappable was tolerable across the
/// card's five rows but is a screenful of dead taps on the full feed.
class ActivityFeedRow extends StatelessWidget {
  const ActivityFeedRow({
    super.key,
    required this.render,
    required this.meta,
    this.density = ActivityRowDensity.page,
    this.onTap,
  });

  final ActivityRender render;
  final String meta;
  final ActivityRowDensity density;

  /// Null → the row is not a navigation target and must not look like one.
  final VoidCallback? onTap;

  bool get _isCard => density == ActivityRowDensity.card;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final (bg, fg) = activityToneColors(tokens, render.tone);

    final avatarSize = _isCard ? 26.0 : 28.0;
    final content = Padding(
      padding: _isCard
          ? const EdgeInsets.symmetric(vertical: 10, horizontal: 4)
          : const EdgeInsets.symmetric(vertical: InSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: avatarSize,
            height: avatarSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              shape: _isCard ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: _isCard ? null : BorderRadius.circular(InRadii.r2),
            ),
            child: Icon(render.icon, size: _isCard ? 14 : 16, color: fg),
          ),
          SizedBox(width: _isCard ? 10 : InSpacing.md(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  render.title,
                  // The dashboard card only. A logged call's note is
                  // deliberately multi-line (a metadata header, then what was
                  // said), and five unbounded ones grew the card to fill its
                  // column. The full-page feed and the User Details audit
                  // section stay unclamped on purpose: a typed comment can run
                  // to six lines (`add_comment_dialog.dart`), the row's tap
                  // deep-links to the *entity* rather than to the note, and
                  // there is no other place on those screens to read the rest.
                  maxLines: _isCard ? 2 : null,
                  overflow: _isCard ? TextOverflow.ellipsis : null,
                  style: _isCard
                      ? TextStyle(
                          fontSize: 12.5,
                          color: tokens.ink,
                          height: 1.35,
                        )
                      : theme.textTheme.bodyMedium,
                ),
                if (!_isCard) const SizedBox(height: 2),
                Text(
                  meta,
                  style: _isCard
                      ? TextStyle(fontSize: 11, color: tokens.ink3)
                      : theme.textTheme.bodySmall?.copyWith(color: tokens.ink3),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: _isCard ? 14 : 16,
              color: tokens.ink3,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return content;

    final tappable = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(InRadii.r1),
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.pressed)) return tokens.border;
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return tokens.surfaceAlt;
          }
          return null;
        }),
        child: content,
      ),
    );
    return Semantics(
      button: true,
      label: '${render.title} $meta',
      child: ExcludeSemantics(child: tappable),
    );
  }
}

/// Placeholder rows shown while the activity cache is still empty. Shared so
/// the card and the full feed agree on what "loading" looks like.
class ActivityFeedSkeleton extends StatelessWidget {
  const ActivityFeedSkeleton({
    super.key,
    this.count = 5,
    this.density = ActivityRowDensity.card,
  });

  final int count;
  final ActivityRowDensity density;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final isCard = density == ActivityRowDensity.card;
    final avatarSize = isCard ? 26.0 : 28.0;
    return Column(
      children: List.generate(count, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  color: tokens.surfaceAlt,
                  shape: isCard ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: isCard
                      ? null
                      : BorderRadius.circular(InRadii.r2),
                ),
              ),
              SizedBox(width: isCard ? 10 : InSpacing.md(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 180,
                      height: 12,
                      decoration: BoxDecoration(
                        color: tokens.surfaceAlt,
                        borderRadius: BorderRadius.circular(InRadii.r1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 80,
                      height: 10,
                      decoration: BoxDecoration(
                        color: tokens.surfaceAlt,
                        borderRadius: BorderRadius.circular(InRadii.r1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
