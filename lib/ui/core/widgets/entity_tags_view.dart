import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/tag_lookup.dart';
import 'package:admin/ui/core/widgets/tag_pill.dart';

/// Read-only row of resolved tag chips for [tagIds], for detail screens and
/// list cells. Names/colors come from the tag cache in every lifecycle state,
/// so an attached-then-archived — or since-deleted — tag still renders its
/// name rather than a hashid. Renders nothing when there are no tags — callers
/// on detail screens rely on that to hide the row entirely (no dash).
///
/// Resolution goes through `watchLookup`, which folds in the `tmp_ -> real`
/// aliases: a tag created inline has its tmp row deleted the moment the create
/// round-trips, while the parent's stored `tagIds` keep that id until its own
/// echo lands. Without the aliases this printed `tmp_1f3c…` as the tag's name.
///
/// The per-cell `StreamBuilder` is deliberate, and matches `ClientNameLabel` /
/// `UserNameLabel` / every other id→name resolver: every cell in a column
/// builds the *same* query, and drift keys its active query streams by
/// SQL+variables+tables, so N rows share one underlying query. Don't "optimize"
/// this into a hoisted stream threaded through the column definitions — it
/// would diverge from the shared pattern for no measured gain.
class EntityTagsView extends StatefulWidget {
  const EntityTagsView({
    super.key,
    required this.entityType,
    required this.tagIds,
    this.spacing = InSpacing.sm,
  });

  final String entityType;
  final List<String> tagIds;
  final double spacing;

  @override
  State<EntityTagsView> createState() => _EntityTagsViewState();
}

class _EntityTagsViewState extends State<EntityTagsView> {
  Stream<TagLookup>? _lookup;
  String? _companyId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bind();
  }

  @override
  void didUpdateWidget(EntityTagsView old) {
    super.didUpdateWidget(old);
    // Going empty UNMOUNTS the StreamBuilder (see `build`), which cancels the
    // subscription and permanently closes `combineLatest2`'s single-
    // subscription controller. Dropping the reference here is what stops the
    // next non-empty rebuild mounting a StreamBuilder over that dead stream and
    // throwing `Bad state: Stream has already been listened to`.
    if (widget.tagIds.isEmpty) {
      _lookup = null;
      return;
    }
    // Re-binds when a row that had no tags gains one, and on a company switch —
    // `_bind` holds every guard it needs, so calling it unconditionally is both
    // cheaper to reason about and the only thing that makes its own
    // `companyId` check reachable.
    _bind(force: old.entityType != widget.entityType);
  }

  /// Held in state, not rebuilt in `build`: `watchLookup` combines two Drift
  /// watches and emits only once both have produced, so a per-build instance
  /// would restart that handshake on every parent rebuild.
  ///
  /// Nothing happens for an empty [tagIds] — this widget is mounted per list
  /// cell, and most rows have no tags. Reading `Services` and opening a stream
  /// for them would be pure waste, and it would newly require a provider in
  /// hosts that never needed one (the old build returned `SizedBox.shrink()`
  /// before touching `Services` at all).
  void _bind({bool force = false}) {
    if (widget.tagIds.isEmpty) return;
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    if (!force && _lookup != null && companyId == _companyId) return;
    _companyId = companyId;
    _lookup = services.tags.watchLookup(
      companyId: companyId,
      entityType: widget.entityType,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tagIds.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<TagLookup>(
      stream: _lookup,
      builder: (context, snap) {
        // Blank, not dashed, until the stream has spoken. `snap.data` alone
        // cannot tell "still loading" from "these ids are dead", and every
        // tagged card would otherwise paint a short placeholder and then reflow
        // to a taller `Wrap` of pills.
        if (!snap.hasData) return const SizedBox.shrink();
        final lookup = snap.data!;
        return Wrap(
          spacing: widget.spacing,
          runSpacing: widget.spacing,
          children: [
            // One pill per id, resolved or not. Collapsing the unresolved ones
            // into a single dash would make three dead tags read as one; the id
            // rides along on `Semantics` for screen readers and `debugDumpApp`,
            // never on screen (`ClientNameLabel`'s rule).
            for (final id in widget.tagIds)
              if (lookup[id] case final tag?)
                TagPill(name: tag.name, colorHex: tag.color)
              else
                TagPill(name: kUnresolvedTagLabel, semanticsLabel: id),
          ],
        );
      },
    );
  }
}
