import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/tag.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/picker_dismissal.dart';
import 'package:admin/ui/core/widgets/tag_pill.dart';

final _log = Logger('TagPickerField');

/// Multi-select tag picker — selected tags render as removable colored chips
/// above a type-to-search field; matching tags drop down as you type. When
/// [onCreate] is non-null (admin) and the typed name matches no existing tag,
/// a `Create "name"` affordance appears in the dropdown. Mirrors React's
/// `TagPillSelector`; built on `RawAutocomplete` like `SearchableDropdownField`.
///
/// Operates purely on tag ids: [selectedIds] in, [onChanged] out. Names +
/// colors are resolved through [resolveById], so a rename reflects immediately
/// — and so does the tmp -> real swap a create makes, which [available] alone
/// cannot survive (the tmp row is deleted when the create round-trips, and the
/// draft still holds its id).
class TagPickerField extends StatefulWidget {
  const TagPickerField({
    super.key,
    required this.label,
    required this.available,
    required this.selectedIds,
    required this.onChanged,
    this.onCreate,
    this.resolveById,
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

  /// Resolves a stored id to its tag, following a `tmp_ -> real` alias when the
  /// create has already round-tripped. Defaults to a plain lookup over
  /// [available], which keeps the widget pumpable without `Services`; the app
  /// passes `TagLookup`'s so a just-created tag keeps its name.
  final Tag? Function(String id)? resolveById;

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

  /// The list last handed to [TagPickerField.onChanged], until the parent's
  /// `selectedIds` catches up. Two commits can land before the parent
  /// rebuilds — a comma typed while a create is in flight queues a second
  /// batch that runs straight after the first — and building the second from
  /// the stale `selectedIds` would drop what the first added.
  List<String>? _emittedIds;

  List<String> get _currentIds => _emittedIds ?? widget.selectedIds;

  void _emit(List<String> next) {
    _emittedIds = next;
    widget.onChanged(next);
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(TagPickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The parent caught up (or changed the list itself). A rebuild that hands
    // back the old list is not a catch-up, so the pending emit stands.
    if (!listEquals(oldWidget.selectedIds, widget.selectedIds)) {
      _emittedIds = null;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// The tag [id] names, alias-aware. Falls back to a plain scan of
  /// [TagPickerField.available] so the widget stays pumpable without a repo.
  Tag? _resolve(String id) {
    final resolve = widget.resolveById;
    if (resolve != null) return resolve(id);
    for (final t in widget.available) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// [id] rewritten to the real id when the create has round-tripped.
  ///
  /// For COMPARISONS only — "is this already selected", dedupe. Never for
  /// storage: [_removeTag] must delete exactly the id the draft holds.
  String _canonical(String id) => _resolve(id)?.id ?? id;

  /// The selection as canonical ids, so a tag held under a dead `tmp_` id is
  /// still recognised as selected. Without this the dropdown re-offers the tag
  /// the user just created (its real row is in `available` while the draft
  /// holds the tmp id) and picking it appends a SECOND id for the same tag.
  Set<String> get _selectedCanonical => {
    for (final id in _currentIds) _canonical(id),
  };

  void _addTag(String id) => _addTags([id]);

  /// Appends [ids] in one [TagPickerField.onChanged] — calling it once per id
  /// would rebuild each from the same stale `selectedIds` and keep only the
  /// last.
  void _addTags(Iterable<String> ids) {
    final current = _currentIds;
    final seen = _selectedCanonical;
    final next = [...current];
    for (final id in ids) {
      if (seen.add(_canonical(id))) next.add(id);
    }
    if (next.length != current.length) _emit(next);
  }

  /// The existing tag whose name is exactly [name] (case-insensitive), if any.
  Tag? _exactMatch(String name) {
    final lower = name.trim().toLowerCase();
    return widget.available.firstWhereOrNull(
      (t) => t.name.trim().toLowerCase() == lower,
    );
  }

  /// Serializes comma commits so a second comma typed while a create is in
  /// flight waits for it instead of tripping the `_creating` guard.
  Future<void> _commitQueue = Future<void>.value();

  /// A comma is a delimiter here, never part of a name: the server rejects a
  /// tag name containing one (`commas_not_allowed`, React #3371), and a tag
  /// created inline is saved alongside the parent record — so a rejected one
  /// would fail that save too. Typing or pasting `a, b` commits `a` exactly as
  /// Enter would (pick the existing tag, or create it) and leaves `b` in the
  /// field to keep typing.
  ///
  /// A name that can't be committed — no match, and no create rights — stays
  /// in the field with the comma dropped, rather than vanishing.
  void _onTextChanged(String text) {
    if (!text.contains(',')) return;
    final parts = text.split(',');
    final remainder = parts.removeLast().trimLeft();
    final commit = <String>[];
    final keep = <String>[];
    for (final part in parts) {
      final name = part.trim();
      if (name.isEmpty) continue;
      (_exactMatch(name) != null || _mayCreate(name) ? commit : keep).add(name);
    }
    final text0 = [...keep, if (remainder.isNotEmpty) remainder].join(' ');
    _controller.value = TextEditingValue(
      text: text0,
      selection: TextSelection.collapsed(offset: text0.length),
    );
    if (commit.isEmpty) return;
    // A failed create must not wedge the queue: a rejected future would skip
    // every later `.then`, silently dropping each comma commit after it.
    _commitQueue = _commitQueue.then((_) => _commitNames(commit)).catchError((
      Object e,
      StackTrace st,
    ) {
      _log.warning('Tag comma commit failed', e, st);
    });
  }

  Future<void> _commitNames(List<String> names) async {
    final picked = <String>[];
    final createdNames = <String>{};
    for (final raw in names) {
      final name = raw.trim();
      if (name.isEmpty || !mounted) continue;
      final exact = _exactMatch(name);
      if (exact != null) {
        picked.add(exact.id);
        continue;
      }
      // `a, a` names one tag: the first create isn't in `available` yet, so
      // without this the second would create a duplicate.
      if (!createdNames.add(name.toLowerCase())) continue;
      if (!_mayCreate(name)) continue;
      final created = await _create(name);
      if (created != null) picked.add(created.id);
    }
    if (mounted && picked.isNotEmpty) _addTags(picked);
  }

  void _removeTag(String id) {
    _emit(_currentIds.where((e) => e != id).toList());
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

  bool _canCreate(String query) => !_creating && _mayCreate(query);

  /// [_canCreate] without the in-flight guard — whether [query] is a name the
  /// user may create at all.
  bool _mayCreate(String query) {
    final q = query.trim();
    if (widget.onCreate == null || q.isEmpty) return false;
    final lower = q.toLowerCase();
    // Suppress create when the name already exists (case-insensitive), checking
    // BOTH the active pool AND reservedNames (archived/deleted tags the pool
    // hides) — the server's UNIQUE rule ignores soft-deletes, so a collision
    // there 422s the create and kills the parent save offline (M1).
    if (widget.reservedNames.contains(lower)) return false;
    // `.trim()` on both sides: `reservedNames` folds the same way (see
    // `TagLookup`), and `q` is trimmed above — an asymmetric compare would
    // let the two halves of this check disagree about the same tag.
    return !widget.available.any((t) => t.name.trim().toLowerCase() == lower);
  }

  /// Runs [TagPickerField.onCreate] for [name], holding [_creating] while it
  /// is in flight. Null when declined, failed, or already busy.
  Future<Tag?> _create(String name) async {
    final onCreate = widget.onCreate;
    final trimmed = name.trim();
    if (onCreate == null || trimmed.isEmpty || _creating) return null;
    setState(() => _creating = true);
    try {
      return await onCreate(trimmed);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _handleCreate(String name) async {
    final created = await _create(name);
    if (!mounted || created == null) return;
    _addTag(created.id);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(InRadii.r1),
      borderSide: BorderSide(color: tokens.border),
    );

    // An unresolvable id keeps its chip even though it renders no name: the ✕
    // is the only handle that can take a stranded id back out of the draft, and
    // that id is still going to the server. Read-only surfaces drop it instead
    // (`EntityTagsView`).
    final chips = [
      for (final id in _currentIds)
        () {
          final tag = _resolve(id);
          return TagPill(
            name: tag?.name ?? kUnresolvedTagLabel,
            colorHex: tag?.color ?? '',
            semanticsLabel: tag == null ? id : null,
            onRemove: widget.enabled ? () => _removeTag(id) : null,
          );
        }(),
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
                // Flip above the field when there is more room there. Left at
                // the `.down` default, a tag field low on a phone gets only the
                // space beneath it, floored at a ~48 px sliver.
                optionsViewOpenDirection: OptionsViewOpenDirection.mostSpace,
                optionsBuilder: (value) {
                  if (!widget.enabled) return const Iterable<Tag>.empty();
                  final q = value.text.trim().toLowerCase();
                  final selected = _selectedCanonical;
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
                          // On native touch nothing else can close the popover
                          // — see `picker_dismissal.dart`.
                          onTapOutside: dismissPickerOnTapOutside(focusNode),
                          enabled: widget.enabled,
                          textInputAction: TextInputAction.done,
                          onChanged: _onTextChanged,
                          onSubmitted: (_) {
                            final q = textController.text.trim();
                            if (q.isEmpty) return;
                            final exact = _exactMatch(q);
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
                  // No `Align` of our own: `RawAutocomplete` already wraps this
                  // in `ConstrainedBox(tight) -> Align(topStart|bottomStart)`,
                  // and a bare `Align` shrink-wraps only under an infinite
                  // constraint — so ours filled the whole bounding box and left
                  // the SDK's alignment nothing to move, stranding an
                  // upward-opening popover at the top of the screen.
                  return BackDismissiblePickerOverlay(
                    focusNode: _focusNode,
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
                                        // `accentInk`, not `accent` — `accent`
                                        // is the same mid blue in both
                                        // brightnesses and lands at ~3.2:1 on
                                        // the dark `accentSoft` highlight.
                                        color: tokens.accentInk,
                                      ),
                                      const SizedBox(width: InSpacing.sm),
                                      Expanded(
                                        child: Text(
                                          context
                                              .tr('create_tag_named')
                                              .replaceFirst(':name', query),
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: tokens.accentInk,
                                              ),
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
