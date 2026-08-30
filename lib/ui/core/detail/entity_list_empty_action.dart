import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';

/// Escape hatch for a detail screen whose record never resolved — the
/// `emptyAction` on `EntityDetailScaffold`.
///
/// A record can legitimately fail to resolve: deleted server-side, outside
/// this user's permissions, or a shared link that has gone stale. Deep links
/// make that reachable from outside the app, where the user has no history to
/// go back to, so the empty state has to offer a way onward rather than being
/// a dead end.
///
/// Returns null for an entity with no list route, so the caller can pass it
/// straight through.
Widget? entityListEmptyAction(BuildContext context, EntityType type) {
  final handlers = context.read<Services>().entityRegistry[type];
  if (handlers == null || handlers.routePath.isEmpty) return null;
  return FilledButton.tonal(
    // CLAUDE.md: a centered single action must constrain its own width, or
    // the theme's `Size.fromHeight(44)` stretches it edge to edge.
    style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
    onPressed: () => GoRouter.of(context).go(handlers.routePath),
    child: Text(context.tr(handlers.effectiveLabelKey)),
  );
}
