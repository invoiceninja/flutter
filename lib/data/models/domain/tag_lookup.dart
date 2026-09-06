import 'package:admin/data/models/domain/tag.dart';

/// Every tag for one entity type, plus the `tmp_ -> real` aliases needed to
/// resolve an id the caller is still holding.
///
/// Exists because a tag id can outlive the row it names. `create` writes an
/// optimistic row under a `tmp_` id and hands that id to the parent draft;
/// when the create round-trips, `applyCreateResponseTemplate` inserts the real
/// row and **deletes the tmp one**, so every surface that resolves a name by
/// looking the stored id up in the tag list starts missing from that moment on
/// — which is how a chip came to render `tmp_1f3c…` as its name.
///
/// A plain class rather than a `freezed` model: it is derived state built per
/// stream emission, never serialized and never compared. `custom_field_types.dart`
/// is the precedent in this directory.
class TagLookup {
  TagLookup(this.all, this.aliases)
    : _byId = {for (final t in all) t.id: t},
      active = [
        for (final t in all)
          if (t.archivedAt == null && !t.isDeleted) t,
      ],
      reservedNames = {for (final t in all) t.name.trim().toLowerCase()};

  /// Every tag for the entity type, in **all** lifecycle states.
  final List<Tag> all;

  /// `tmp_ -> real` id map for tags whose create has round-tripped.
  final Map<String, String> aliases;

  final Map<String, Tag> _byId;

  /// The selectable pool — active tags only.
  final List<Tag> active;

  /// Trimmed, lowercased names across every lifecycle state, for the
  /// inline-create collision check. The server's
  /// `UNIQUE(company_id, entity_type, name)` ignores soft deletes, so an
  /// archived name still 422s — and offline a dead create row blocks the parent
  /// save (M1).
  ///
  /// The `trim()` must stay in step with `TagPickerField._canCreate`, which
  /// trims the typed query and folds `available` the same way. `newTagDraft`
  /// already trims on the way in, so nothing this app writes carries
  /// surrounding whitespace; folding both sides just stops the two halves of
  /// that check disagreeing about a name that arrived from elsewhere.
  final Set<String> reservedNames;

  static final TagLookup empty = TagLookup(
    const <Tag>[],
    const <String, String>{},
  );

  /// The tag [id] names, resolving a dead `tmp_` id through [aliases].
  ///
  /// Returns null when nothing matches — a tag another user deleted, or the
  /// one-frame window where the tmp row is gone and the alias has not arrived.
  /// Both are written in a single transaction and their watches fire in no
  /// guaranteed order, so that window is reachable on the happy path; callers
  /// must render a placeholder, never the raw id.
  Tag? operator [](String id) {
    final direct = _byId[id];
    if (direct != null) return direct;
    final real = aliases[id];
    return real == null ? null : _byId[real];
  }

  /// [id] rewritten to the real id when one is known, else unchanged.
  ///
  /// Use for *comparisons* — dedupe, "is this already selected" — never to
  /// rewrite what is stored: a chip's remove button has to delete exactly the
  /// id the draft holds.
  String canonicalId(String id) => this[id]?.id ?? id;
}
