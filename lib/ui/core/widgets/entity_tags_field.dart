import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/tag.dart';
import 'package:admin/data/models/domain/tag_lookup.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/tag_picker_field.dart';

/// Drop-in tag picker for an entity edit form. Streams the tag cache for
/// [entityType] (`task` / `project` / …), gates inline-create to admins/owners,
/// and emits the selected id set via [onChanged]. The edit VM only needs a
/// `setTagIds(List<String>)` setter and `draft.tagIds`.
///
/// Reads `watchLookup` rather than `watchAllAnyState` so a just-created tag
/// keeps its name: the create's `tmp_` row is deleted the moment it
/// round-trips, and the draft still holds that id, so a lookup over the tag
/// list alone starts missing and the chip printed `tmp_1f3c…`.
///
/// Stateful purely to hold that stream. `watchLookup` combines two Drift
/// watches and only emits once **both** have produced, so rebuilding it inside
/// `build` — as this widget used to, on every keystroke, because the host form
/// notifies per character — would restart that handshake each time.
class EntityTagsField extends StatefulWidget {
  const EntityTagsField({
    super.key,
    required this.entityType,
    required this.selectedIds,
    required this.onChanged,
    this.enabled = true,
  });

  final String entityType;
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;
  final bool enabled;

  @override
  State<EntityTagsField> createState() => _EntityTagsFieldState();
}

class _EntityTagsFieldState extends State<EntityTagsField> {
  Stream<TagLookup>? _lookup;
  String? _companyId;
  bool _isAdminOrOwner = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bind();
  }

  @override
  void didUpdateWidget(EntityTagsField old) {
    super.didUpdateWidget(old);
    // Unconditional: `_bind` holds every guard it needs, and gating this on
    // `entityType` alone made its own `companyId` check unreachable — this
    // State registers no inherited dependency (`context.read` is
    // `listen: false`), so `didChangeDependencies` runs exactly once and
    // `_companyId` / `_isAdminOrOwner` would be frozen at mount.
    _bind(force: old.entityType != widget.entityType);
  }

  void _bind({bool force = false}) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    if (!force && _lookup != null && companyId == _companyId) return;
    final me = services.auth.session.value?.currentCompany;
    _companyId = companyId;
    _isAdminOrOwner = (me?.isAdmin ?? false) || (me?.isOwner ?? false);
    _lookup = services.tags.watchLookup(
      companyId: companyId,
      entityType: widget.entityType,
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return StreamBuilder<TagLookup>(
      stream: _lookup,
      builder: (context, snap) {
        final lookup = snap.data ?? TagLookup.empty;
        return TagPickerField(
          label: context.tr('tags'),
          available: lookup.active,
          resolveById: (id) => lookup[id],
          reservedNames: lookup.reservedNames,
          selectedIds: widget.selectedIds,
          enabled: widget.enabled,
          onChanged: widget.onChanged,
          onCreate: _isAdminOrOwner
              ? (name) async {
                  final result = await services.tags.create(
                    companyId: _companyId ?? '',
                    draft: newTagDraft(
                      name: name,
                      entityType: widget.entityType,
                    ),
                  );
                  return result.entity;
                }
              : null,
        );
      },
    );
  }
}
