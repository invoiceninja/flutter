import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';

/// An icon tile beside a short title and a line of body — how the
/// mobile-app promo pitches the phone app and how the What's New dialog
/// leads with a release's highlights, so the two read as one family.
///
/// With [onTap] the whole row is the target (a full touch target on touch),
/// with a trailing chevron. [inset] gives a row without one the same insets,
/// so a list mixing the two keeps its icons in one column.
class FeatureRow extends StatelessWidget {
  const FeatureRow({
    required this.icon,
    required this.title,
    required this.body,
    this.onTap,
    this.inset = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final content = [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: tokens.accentSoft,
          borderRadius: BorderRadius.circular(InRadii.r2),
        ),
        child: Icon(icon, size: 18, color: tokens.accentInk),
      ),
      SizedBox(width: InSpacing.md(context)),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tokens.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              body,
              style: TextStyle(fontSize: 13, height: 1.4, color: tokens.ink3),
            ),
          ],
        ),
      ),
    ];
    final tap = onTap;
    if (tap == null && !inset) {
      return Padding(
        padding: EdgeInsets.only(bottom: InSpacing.lg(context)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: content,
        ),
      );
    }
    final row = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: Env.isTouchPrimary ? InSizes.touchTarget : 0,
      ),
      child: Padding(
        padding: const EdgeInsets.all(InSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...content,
            if (tap != null) ...[
              const SizedBox(width: InSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Icon(Icons.chevron_right, size: 20, color: tokens.ink3),
              ),
            ],
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: InSpacing.xs),
      child: tap == null
          ? row
          : MergeSemantics(
              child: Semantics(
                link: true,
                // A local Material, never `Ink` (docs/sidebar-and-shell.md).
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: tap,
                    borderRadius: BorderRadius.circular(InRadii.r2),
                    child: row,
                  ),
                ),
              ),
            ),
    );
  }
}
