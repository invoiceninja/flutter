import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';

/// "Click to navigate to a related entity" card used on detail screens.
///
/// Renders a labelled card (`titleKey` → uppercase translation) with one
/// row: icon + entity display name + chevron. Tapping the row navigates
/// to [routePath] when the current company grants [permissionKey].
///
/// The permission check is read **lazily** inside `build()` — a captured
/// bool would not rebuild on company switch.
class EntityLinkCard<T> extends StatelessWidget {
  const EntityLinkCard({
    super.key,
    required this.titleKey,
    required this.icon,
    required this.entityId,
    required this.routePath,
    required this.permissionKey,
    required this.watchBuilder,
    this.repo,
    required this.displayNameOf,
    this.module,
  });

  /// Localization key for the card title (e.g. `'client'`, `'project'`).
  final String titleKey;

  /// Leading icon for the row.
  final IconData icon;

  /// The linked entity's id. Shown as a fallback while the stream is empty.
  final String entityId;

  /// Destination route (e.g. `'/clients/<id>'`).
  final String routePath;

  /// Permission name passed to `currentCompany.can(...)`. When false the
  /// row is non-tappable and the chevron hides.
  final String permissionKey;

  /// Builder for the watch stream. A thunk, so [WatchBuilder] can own the
  /// subscription and re-run it only when the (company, entity) it watches
  /// actually changes — a repo `watch*` returns a fresh stream per call, so
  /// calling this straight into a `StreamBuilder` would re-subscribe on every
  /// parent rebuild and blank the name each time.
  final Stream<T?> Function() watchBuilder;

  /// Display-name projection for the resolved entity.
  final String Function(T) displayNameOf;

  /// The repository backing [watchBuilder], used ONLY to read a first-frame
  /// seed (`peek`) so a fresh mount doesn't paint the raw id for a frame.
  ///
  /// A repo rather than a plain `initialData` value: the card derives the seed
  /// from its own [entityId], so a caller cannot hand it a seed for one id next
  /// to a stream for another. Omit it and the card behaves exactly as before.
  final BaseEntityRepository<T, dynamic>? repo;

  /// When set, the whole card is hidden if this module is disabled for the
  /// active company — for cross-entity links into module-gated entities.
  /// Callers usually gate at the call site; this is the catch-all.
  final EntityType? module;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final services = context.read<Services>();
    final m = module;
    if (m != null &&
        !(services.auth.session.value?.currentCompany?.moduleEnabled(m) ??
            false)) {
      return const SizedBox.shrink();
    }
    final canView =
        services.auth.session.value?.currentCompany?.can(permissionKey) ??
        false;
    final companyId = services.auth.session.value?.currentCompanyId;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r3),
      ),
      padding: EdgeInsets.all(InSpacing.lg(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr(titleKey).toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tokens.ink3,
              letterSpacing: 0.4,
            ),
          ),
          SizedBox(height: InSpacing.md(context)),
          // TextButton (not InkWell) so the row participates in tab-traversal
          // — keyboard users hit Enter / Space to navigate, matching the
          // mouse affordance. `OutlinedButton` would add a second border
          // inside the card's outer border; `TextButton` keeps the card
          // chrome single-bordered while still rendering Material 3 focus
          // outlines + hover/press states.
          TextButton(
            onPressed: canView ? () => context.go(routePath) : null,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: Alignment.centerLeft,
              foregroundColor: tokens.ink,
            ),
            child: Row(
              children: [
                Icon(icon, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: WatchBuilder<T?>(
                    // The real guard against a company switch is route-level:
                    // `companySafeLocation` rewrites `/x/<id>` → `/x` and
                    // `BranchCompanyGate` resets offstage branches, so this
                    // card is unmounted before company B's data exists. The
                    // companyId component here is belt-and-braces ONLY — it
                    // cannot do more, because `watchBuilder` is opaque to us
                    // and every call site's thunk closes over its screen's
                    // `initState`-captured `_companyId`. Re-running `create`
                    // on a live-id change would hand back the same
                    // old-company stream. Hoist companyId into the
                    // constructor if that ever needs to be load-bearing.
                    cacheKey: (companyId, entityId),
                    initialData: repo?.peek(
                      companyId: companyId ?? '',
                      id: entityId,
                    ),
                    create: watchBuilder,
                    builder: (context, snapshot) {
                      final entity = snapshot.data;
                      final name = entity == null ? '' : displayNameOf(entity);
                      // Never the raw hashid — see `ClientNameLabel`. The row
                      // still links to the record either way; the id stays
                      // available to screen readers.
                      return Semantics(
                        label: name.isEmpty ? entityId : null,
                        child: Text(
                          name.isEmpty ? '—' : name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
                if (canView) const Icon(Icons.chevron_right, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
