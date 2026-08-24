import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';

/// Collapsible group separator rendered inline in an entity list, directly
/// above the first row of each group (see `EntityListScreenScaffold`'s
/// `sectionHeaderBuilder`).
///
/// Styling mirrors `SidebarSectionHeader` — uppercase, letter-spaced, `ink3`
/// — so grouped lists read as the same design system. The whole row is the
/// tap target: tapping folds the group away, which is what actually makes
/// grouping shorten a long catalogue.
///
/// [count] is the number of **loaded** rows in the group, so it under-reports
/// until paging catches up. That's the same caveat the sidebar count badges
/// carry, and it stays useful precisely when a group is folded shut.
///
/// Deliberately sized by padding rather than a fixed height: Inter Tight's
/// descenders clip inside a fixed line box past ~1.14x text scale.
class EntityListSectionHeader extends StatelessWidget {
  const EntityListSectionHeader({
    required this.label,
    required this.count,
    required this.collapsed,
    required this.onToggle,
    this.isFirst = false,
    super.key,
  });

  final String label;
  final int count;
  final bool collapsed;
  final VoidCallback onToggle;

  /// Suppresses the top hairline for the first group, which would otherwise
  /// double up with the column-header strip / AppBar edge above it.
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final touch = Env.isTouchPrimary;
    final labelStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
      color: tokens.ink3,
    );
    return Semantics(
      header: true,
      button: true,
      expanded: !collapsed,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onToggle,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: isFirst
                  ? null
                  : Border(top: BorderSide(color: tokens.border)),
            ),
            child: ConstrainedBox(
              // A floor, never a fixed height — the label must be free to
              // grow with the user's text scale.
              constraints: BoxConstraints(
                minHeight: touch ? InSizes.touchTarget : 0,
              ),
              child: Padding(
                // Matches the rows' 16 px horizontal gutter so the label
                // lines up with the first cell.
                padding: EdgeInsetsDirectional.fromSTEB(
                  16,
                  InSpacing.lg(context),
                  16,
                  InSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(
                      collapsed
                          ? Icons.keyboard_arrow_right
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: tokens.ink3,
                    ),
                    const SizedBox(width: InSpacing.sm),
                    Expanded(
                      child: Text(
                        label.toUpperCase(),
                        style: labelStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: InSpacing.sm),
                    Text('$count', style: labelStyle),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
