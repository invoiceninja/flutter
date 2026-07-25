import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/api/tag_api_model.dart';
import 'package:admin/data/models/domain/tag.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/core/widgets/tag_pill.dart';
import 'package:admin/ui/features/settings/widgets/settings_entity_list_scaffold.dart';

/// Search keys for the settings sidebar search. Colocated with the screen so
/// adding / renaming a field updates both ends in one place.
const kTagsSearchKeys = <String>['tags', 'name', 'color'];

/// `/settings/tags` — manage tags, scoped to one tag-bearing entity type via
/// the picker in the banner. Tags are polymorphic (each tag belongs to exactly
/// one entity type), so the picker also fixes the type on "+ New". Tap a row to
/// edit. Admin/owner-gated for create. (Widened from the original Task/Project
/// toggle to all 14 tag-bearing types — React #3242.)
class TagsScreen extends StatefulWidget {
  const TagsScreen({super.key});

  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  String _entityType = 'task';

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final me = services.auth.session.value?.currentCompany;
    final isAdminOrOwner = (me?.isAdmin ?? false) || (me?.isOwner ?? false);
    final repo = services.tags;

    return SettingsEntityListScaffold<Tag>(
      titleKey: 'tags',
      sectionTitleKey: 'tags',
      newRoute: '/settings/tags/new?entityType=$_entityType',
      newLabelKey: 'new_tag',
      emptyIcon: Icons.local_offer_outlined,
      emptyTitleKey: 'no_tags',
      emptyHintKey: 'no_tags_hint',
      supportsArchive: true,
      canCreate: isAdminOrOwner,
      banner: _EntityTypeToggle(
        value: _entityType,
        onChanged: (v) => setState(() => _entityType = v),
      ),
      refreshAll: () async {
        if (companyId.isEmpty) return;
        await repo.refreshAll(companyId: companyId);
      },
      stream: ({required includeArchived}) => repo.watchAll(
        companyId: companyId,
        entityType: _entityType,
        includeArchived: includeArchived,
      ),
      isArchivedOf: (t) => t.archivedAt != null,
      isDeletedOf: (t) => t.isDeleted,
      rowBuilder: (t) => _TagRow(key: ValueKey(t.id), tag: t),
      archivedRowBuilder: (t) => _TagRow.archived(key: ValueKey(t.id), tag: t),
    );
  }
}

/// Entity-type picker rendered above the list. Widened from the original
/// Task/Project segmented toggle to a searchable dropdown over all 14
/// tag-bearing types (too many for a `SegmentedButton`). Labels + ordering
/// come from the entity registry so a new tag-bearing entity shows up here for
/// free. (React #3242 — one `/settings/tags` route per type on the web.)
class _EntityTypeToggle extends StatelessWidget {
  const _EntityTypeToggle({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final registry = context.read<Services>().entityRegistry;
    // `effectiveLabelKey` is already the plural sidebar label (e.g. `tasks`,
    // `transactions`); fall back to the wire key if a type isn't registered.
    String labelFor(String type) =>
        context.tr(registry.byWireName(type)?.effectiveLabelKey ?? type);
    final types = kTagEntityTypes.toList()
      ..sort((a, b) => labelFor(a).compareTo(labelFor(b)));
    return Padding(
      padding: EdgeInsets.fromLTRB(
        InSpacing.lg(context),
        InSpacing.md(context),
        InSpacing.lg(context),
        0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: SearchableDropdownField<String>(
            label: context.tr('type'),
            items: types,
            initialValue: value,
            idOf: (t) => t,
            displayString: labelFor,
            onChanged: (t) {
              if (t != null) onChanged(t);
            },
          ),
        ),
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({required this.tag, super.key}) : _isArchived = false;

  const _TagRow.archived({required this.tag, super.key}) : _isArchived = true;

  final Tag tag;
  final bool _isArchived;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: parseTagColor(tag.color, fallback: tokens.ink3),
              shape: BoxShape.circle,
            ),
          ),
          title: Text(tag.name.isEmpty ? context.tr('untitled') : tag.name),
          trailing: _isArchived
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.draftSoft,
                    borderRadius: BorderRadius.circular(InRadii.r1),
                  ),
                  child: Text(
                    context.tr('archived'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: tokens.draft,
                    ),
                  ),
                )
              : const Icon(Icons.chevron_right),
          onTap: () => context.go('/settings/tags/${tag.id}'),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
