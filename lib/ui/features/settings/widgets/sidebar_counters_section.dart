import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/app_database.dart' show CompanyRow;
import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/shell/widgets/sidebar_badge.dart';

/// Search keys for the settings sidebar search. Colocated with the section so
/// adding a field updates both ends in one place (see
/// `search_catalog_consistency_test`).
const kSidebarCountersSearchKeys = <String>[
  'sidebar_counters',
  'sidebar_counters_help',
];

/// Device Settings card for choosing what each sidebar row's count badge
/// counts — the discoverable, keyboard-reachable half of issue #9. (The other
/// half is right-clicking the row itself, which needs a pointer.)
///
/// Each row previews the **real badge**, fed by the same stream and rendered in
/// the same colour the rail will use, so picking "Overdue" shows the actual red
/// number you're about to get rather than making you go and look.
class SidebarCountersSection extends StatelessWidget {
  const SidebarCountersSection({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    if (companyId.isEmpty) return const SizedBox.shrink();
    final enabledModules =
        services.auth.session.value?.currentCompany?.enabledModules ?? 0;
    final rows = [
      for (final h in services.entityRegistry.sidebarTop)
        if (!h.disabled &&
            h.badgeStream != null &&
            isEntityModuleEnabledForCompany(h.type, enabledModules))
          h,
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<CompanyRow?>(
      stream: services.db.companiesDao.watchById(companyId),
      builder: (context, snap) {
        final trackInventory = snap.data?.trackInventory ?? false;
        return ListenableBuilder(
          listenable: services.sidebarBadgeModes,
          builder: (context, _) => FormSection(
            title: context.tr('sidebar_counters'),
            spacing: 0,
            trailing: services.sidebarBadgeModes.hasOverrides
                ? TextButton(
                    onPressed: services.sidebarBadgeModes.resetAll,
                    child: Text(context.tr('reset')),
                  )
                : null,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: InSpacing.sm),
                child: Text(
                  context.tr('sidebar_counters_help'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.inTheme.ink3),
                ),
              ),
              for (final h in rows)
                _CounterRow(
                  handlers: h,
                  companyId: companyId,
                  trackInventory: trackInventory,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CounterRow extends StatelessWidget {
  const _CounterRow({
    required this.handlers,
    required this.companyId,
    required this.trackInventory,
  });

  final EntityHandlers handlers;
  final String companyId;
  final bool trackInventory;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    // Same list the row's right-click menu reads, filtered the same way, so
    // the two pickers can't offer different things.
    final modes = availableBadgeModes(
      handlers.badgeModes,
      trackInventory: trackInventory,
    );
    final selected = services.sidebarBadgeModes.modeFor(
      handlers.type,
      available: modes,
    );
    final mode = modes.firstWhere(
      (m) => m.id == selected,
      orElse: () => modes.first,
    );
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(handlers.effectiveOutlinedIcon, size: 20),
      title: Text(context.tr(handlers.effectiveLabelKey)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Rendered unconditionally, even on `none` (where its stream is a
          // constant zero and it collapses itself): dropping the widget out of
          // the children list would shift the dropdown into a different element
          // slot and rebuild it mid-interaction.
          _BadgePreview(
            entityType: handlers.type,
            companyId: companyId,
            mode: mode,
          ),
          SizedBox(width: InSpacing.sm),
          DropdownButton<String>(
            value: selected,
            isDense: true,
            // Borderless — sits flush in the trailing slot like the theme rows.
            underline: const SizedBox.shrink(),
            onChanged: (value) {
              if (value == null) return;
              services.sidebarBadgeModes.set(handlers.type, value);
            },
            items: [
              for (final m in modes)
                DropdownMenuItem(
                  value: m.id,
                  child: Text(context.tr(m.labelKey)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Live preview of the badge this row will render in the sidebar. Same widget,
/// same query, same tone — so the setting shows its own effect.
class _BadgePreview extends StatefulWidget {
  const _BadgePreview({
    required this.entityType,
    required this.companyId,
    required this.mode,
  });

  final EntityType entityType;
  final String companyId;
  final SidebarBadgeMode mode;

  @override
  State<_BadgePreview> createState() => _BadgePreviewState();
}

class _BadgePreviewState extends State<_BadgePreview> {
  Stream<int>? _counts;
  String? _sourceKey;

  /// (Re)build the hoisted count stream only when what it counts changes.
  ///
  /// This card lives under a `ListenableBuilder` on the mode controller, so
  /// touching *one* dropdown rebuilds every row. Handing `StreamBuilder` a
  /// freshly-built stream each time makes it tear down and re-subscribe — so
  /// one dropdown change would re-run all 14 Drift queries. (It wouldn't
  /// *flicker*: `StreamBuilder.afterDisconnected` carries the last snapshot
  /// data across a stream swap. The cost is churn, not a visible blink.)
  /// Same pattern as `PartyMoneyCell._ensureStream` and the sidebar's own
  /// `_cachedBadge`.
  void _ensureStream() {
    final key =
        '${widget.entityType.name}:${widget.companyId}:${widget.mode.id}';
    if (key == _sourceKey) return;
    _sourceKey = key;
    _counts = context.read<Services>().watchEntityCount(
      widget.entityType,
      widget.companyId,
      modeId: widget.mode.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureStream();
    return StreamBuilder<int>(
      stream: _counts,
      builder: (context, snap) {
        final count = snap.data ?? 0;
        // Zero renders nothing here for the same reason it does in the rail:
        // "no overdue invoices" is the absence of a badge, not a badge reading
        // zero. Keeps the preview honest about what you'll actually see.
        if (count == 0) return const SizedBox.shrink();
        return SidebarBadge(count: count, tone: widget.mode.tone);
      },
    );
  }
}
