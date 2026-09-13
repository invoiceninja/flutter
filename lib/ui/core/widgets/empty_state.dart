import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/widgets/widget_preview_support.dart';

/// Shared empty-state placeholder. Every list screen uses this so the
/// vocabulary stays consistent (vs. ad-hoc text widgets).
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    // SingleChildScrollView so a short host (dashboard card slot,
    // narrow drawer pane) lets the column shrink to its scroll area
    // instead of producing a RenderFlex overflow.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: EmptyStateBody(
          icon: icon,
          title: title,
          subtitle: subtitle,
          action: action,
        ),
      ),
    );
  }
}

/// [EmptyState]'s content column without its `Center` +
/// `SingleChildScrollView` host.
///
/// For a caller that is **already inside a vertical scroll view** and wants
/// the same vocabulary: nesting [EmptyState] there throws "Vertical viewport
/// was given unbounded height", because the inner viewport is handed an
/// infinite `maxHeight`. Such a caller supplies its own centring — typically
/// a bare `Center`, which shrink-wraps to `max(child, minHeight)` under an
/// infinite `maxHeight`, so an ancestor `ConstrainedBox(minHeight:)` centres
/// it in the viewport while a tall child (large text scale, short window)
/// simply scrolls. `LineItemCardListMobile` is the reference.
class EmptyStateBody extends StatelessWidget {
  const EmptyStateBody({
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 64, color: theme.colorScheme.outline),
        const SizedBox(height: 16),
        Text(title, style: theme.textTheme.titleMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.inTheme.ink3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (action != null) ...[const SizedBox(height: 24), action!],
      ],
    );
  }
}

@Preview(name: 'Default', group: 'EmptyState', theme: appPreviewTheme)
Widget previewEmptyStateDefault() {
  return const EmptyState(
    icon: Icons.inbox_outlined,
    title: 'No clients yet',
    subtitle: 'Create your first client to start tracking invoices.',
  );
}

@Preview(name: 'With action', group: 'EmptyState', theme: appPreviewTheme)
Widget previewEmptyStateWithAction() {
  return EmptyState(
    icon: Icons.search_off,
    title: 'No results',
    subtitle: 'Try clearing filters or searching for something else.',
    action: FilledButton.tonal(
      onPressed: () {},
      child: const Text('Clear filters'),
    ),
  );
}
