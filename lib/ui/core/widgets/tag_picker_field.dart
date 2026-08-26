import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/tag.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/tag_pill.dart';

/// Multi-select tag picker — selected tags render as removable colored chips
/// above a type-to-search field; matching tags drop down as you type. When
/// [onCreate] is non-null (admin) and the typed name matches no existing tag,
/// a `Create "name"` affordance appears in the dropdown. Mirrors React's
/// `TagPillSelector`; built on `RawAutocomplete` like `SearchableDropdownField`.
///
/// Operates purely on tag ids: [selectedIds] in, [onChanged] out. Names +
/// colors are resolved from [available] (the active tag cache for the entity
/// type), so a rename reflects immediately.
class TagPickerField extends StatefulWidget {
  const TagPickerField({
    super.key,
    required this.label,
    required this.available,
    required this.selectedIds,
    required this.onChanged,
    this.onCreate,
    this.reservedNames = const {},
    this.enabled = true,
  });

  /// Resolved (already-translated) field label.
  final String label;

  /// Active tags for the relevant entity type — the selectable pool + the
  /// source of names/colors for the selected chips.
  final List<Tag> available;

  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;

  /// Admin-only inline create. Returns the created [Tag] (added to the
  /// selection) or null if creation was declined/failed. Null hides the
  /// "Create" affordance for non-admins.
  final Future<Tag?> Function(String name)? onCreate;

  /// Lowercased names that already exist for this entity type across ALL
  /// lifecycle states (active, archived, deleted) — beyond [available], which
  /// is active-only. Inline-create is suppressed for any of these because the
  /// server's UNIQUE(company_id, entity_type, name) reserves soft-deleted names
  /// too, so creating a colliding name 422s and (offline) kills the parent save
  /// (M1).
  final Set<String> reservedNames;

  final bool enabled;

  @override
  State<TagPickerField> createState() => _TagPickerFieldState();
}

class _TagPickerFieldState extends State<TagPickerField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _addTag(String id) {
    if (widget.selectedIds.contains(id)) return;
    widget.onChanged([...widget.selectedIds, id]);
  }

  void _removeTag(String id) {
    widget.onChanged(widget.selectedIds.where((e) => e != id).toList());
  }

  /// Id prefix for the synthetic "Create «name»" option.
  ///
  /// Flutter's `RawAutocomplete` only mounts its options overlay while the
  /// option list is NON-EMPTY (`_canShowOptionsView`), so a create row that
  /// lives purely inside `optionsViewBuilder` is unreachable in exactly the
  /// case it exists for — a name that matches no existing tag. Keeping one
  /// synthetic option in the list is how `ClientPickerField` solves the same
  /// problem. The query is part of the id so a fresh query is a fresh option:
  /// `RawAutocomplete._select` early-returns on an UNCHANGED selection, which
  /// would otherwise leave the row dead after one cancelled create.
  static const String _kCreatePrefix = '__create_tag__:';

  static bool _isCreateOption(Tag t) => t.id.startsWith(_kCreatePrefix);

  Tag _createOption(String query) => Tag(
    id: '$_kCreatePrefix$query',
    entityType: '',
    name: query,
    color: '',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    archivedAt: null,
    isDeleted: false,
  );

  bool _canCreate(String query) {
    final q = query.trim();
    if (widget.onCreate == null || q.isEmpty || _creating) return false;
    final lower = q.toLowerCase();
    // Suppress create when the name already exists (case-insensitive), checking
    // BOTH the active pool AND reservedNames (archived/deleted tags the pool
    // hides) — the server's UNIQUE rule ignores soft-deletes, so a collision
    // there 422s the create and kills the parent save offline (M1).
    if (widget.reservedNames.contains(lower)) return false;
    return !widget.available.any((t) => t.name.toLowerCase() == lower);
  }

  Future<void> _handleCreate(String name) async {
    final onCreate = widget.onCreate;
    final trimmed = name.trim();
    if (onCreate == null || trimmed.isEmpty || _creating) return;
    setState(() => _creating = true);
    Tag? created;
    try {
      created = await onCreate(trimmed);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
    if (!mounted || created == null) return;
    _addTag(created.id);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final byId = {for (final t in widget.available) t.id: t};

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(InRadii.r1),
      borderSide: BorderSide(color: tokens.border),
    );

    final chips = [
      for (final id in widget.selectedIds)
        TagPill(
          name: byId[id]?.name ?? id,
          colorHex: byId[id]?.color ?? '',
          onRemove: widget.enabled ? () => _removeTag(id) : null,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: InSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: theme.textTheme.bodySmall?.copyWith(color: tokens.ink2),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: InSpacing.sm),
            Wrap(
              spacing: InSpacing.sm,
              runSpacing: InSpacing.sm,
              children: chips,
            ),
          ],
          const SizedBox(height: InSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final fieldWidth = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : 360.0;
              final popoverWidth = math.min(fieldWidth, 360.0);
              return RawAutocomplete<Tag>(
                textEditingController: _controller,
                focusNode: _focusNode,
                displayStringForOption: (t) => t.name,
                optionsBuilder: (value) {
                  if (!widget.enabled) return const Iterable<Tag>.empty();
                  final q = value.text.trim().toLowerCase();
                  final selected = widget.selectedIds.toSet();
                  final pool = widget.available.where(
                    (t) => !selected.contains(t.id),
                  );
                  final raw = value.text.trim();
                  if (q.isEmpty) return pool.take(20);
                  final matches = pool
                      .where((t) => t.name.toLowerCase().contains(q))
                      .take(50);
                  // Keep the list non-empty so the overlay — and with it the
                  // create row — can mount at all. See [_kCreatePrefix].
                  if (!_canCreate(raw)) return matches;
                  return [...matches, _createOption(raw)];
                },
                onSelected: (tag) {
                  // Enter on the highlighted row reaches here; the create row
                  // is not a real tag. (Tapping it goes through its own
                  // `InkWell.onTap` below, which is the path CLAUDE.md
                  // prescribes — `_select` early-returns on an unchanged
                  // selection, so a tap must not depend on it.)
                  if (_isCreateOption(tag)) {
                    unawaited(_handleCreate(tag.name));
                    return;
                  }
                  _addTag(tag.id);
                  _controller.clear();
                },
                fieldViewBuilder:
                    (context, textController, focusNode, onFieldSubmitted) {
                      return Material(
                        type: MaterialType.transparency,
                        child: TextField(
                          controller: textController,
                          focusNode: focusNode,
                          enabled: widget.enabled,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            final q = textController.text.trim();
                            if (q.isEmpty) return;
                            final exact = widget.available.firstWhereOrNull(
                              (t) => t.name.toLowerCase() == q.toLowerCase(),
                            );
                            if (exact != null) {
                              _addTag(exact.id);
                              textController.clear();
                              return;
                            }
                            if (_canCreate(q)) {
                              _handleCreate(q);
                              return;
                            }
                            onFieldSubmitted();
                          },
                          decoration: InputDecoration(
                            hintText: context.tr('add_tag'),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: InSpacing.md(context),
                              vertical: 12,
                            ),
                            border: border,
                            enabledBorder: border,
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(InRadii.r1),
                              borderSide: BorderSide(
                                color: tokens.accent,
                                width: 1.5,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.local_offer_outlined,
                              size: 16,
                              color: tokens.ink3,
                            ),
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: tokens.ink,
                          ),
                        ),
                      );
                    },
                optionsViewBuilder: (context, onSelected, options) {
                  final query = _controller.text.trim();
                  final showCreate = _canCreate(query);
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(InRadii.r2),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: 280,
                          maxWidth: popoverWidth,
                        ),
                        child: ListView(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          children: [
                            for (final tag in options)
                              if (!_isCreateOption(tag))
                                InkWell(
                                  onTap: () => onSelected(tag),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: InSpacing.md(context),
                                      vertical: InSpacing.sm,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: parseTagColor(
                                              tag.color,
                                              fallback: tokens.ink3,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: InSpacing.sm),
                                        Expanded(
                                          child: Text(
                                            tag.name,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(color: tokens.ink),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            if (showCreate) ...[
                              if (options.any((t) => !_isCreateOption(t)))
                                Divider(height: 1, color: tokens.border),
                              InkWell(
                                onTap: () => _handleCreate(query),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: InSpacing.md(context),
                                    vertical: InSpacing.sm,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.add,
                                        size: 16,
                                        color: tokens.accent,
                                      ),
                                      const SizedBox(width: InSpacing.sm),
                                      Expanded(
                                        child: Text(
                                          context
                                              .tr('create_tag_named')
                                              .replaceFirst(':name', query),
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(color: tokens.accent),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
