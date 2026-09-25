import 'dart:convert';

import 'package:admin/data/models/api/design_api_model.dart'
    show DesignTemplateApi;
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/design_repository.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';

/// Minimal HTML scaffold seeded by the "Blank" start-from option. Mirrors
/// React's blank design (`<ninja>` is the line-item injection point the
/// server understands).
const String kBlankDesignBody =
    '<html>\n\t<head>\n\t</head>\n\t<body>\n\t\t<ninja>\n\n\t\t</ninja>\n\t</body>\n</html>\n';

/// Drives `/settings/invoice_design/custom_designs` create + edit.
/// Optimistic — `save()` lands the draft in Drift via the repo; the
/// outbox handles the server round-trip. Mirrors
/// [TaskStatusEditViewModel].
class DesignEditViewModel extends GenericEditViewModel<Design> {
  DesignEditViewModel({
    required this.repo,
    required this.companyId,
    Design? existing,
    super.sync,
    super.connectivity,
  }) : super(
         initialDraft: existing ?? _emptyDesign(),
         original: existing,
         companyId: companyId,
       );

  final DesignRepository repo;
  final String companyId;

  /// Document types a custom design (non-template) can be bound to.
  /// Matches React `Settings.tsx:307-310`. The wire stores these
  /// comma-joined in `Design.entities`.
  static const supportedEntities = <String>[
    'invoice',
    'quote',
    'credit',
    'purchase_order',
  ];

  /// Document types a custom **template** (`is_template = true`) can be
  /// bound to. Mirrors React `Create.tsx:35-45`'s `templateEntites` list
  /// (and admin-portal v1's `design_edit.dart:503-512`, which lacks
  /// `expense`). Singular `snake_case` per existing wire convention.
  static const supportedTemplateEntities = <String>[
    'invoice',
    'payment',
    'client',
    'quote',
    'credit',
    'purchase_order',
    'project',
    'task',
    'expense',
  ];

  /// Bumped every time the *whole template* is replaced wholesale
  /// (`loadFrom` / `loadBlankScaffold` / `importFromJson` / `reset`). The
  /// per-section code editors key their reseed off this instead of
  /// `original?.id` — for a brand-new design `original` is null and never
  /// changes, so a Start-from selection would otherwise leave the editors
  /// showing stale empty text. Per-keystroke setters do NOT bump it.
  int get seedRevision => _seedRevision;
  int _seedRevision = 0;

  @override
  bool draftIsNonEmpty() {
    final d = draft;
    return d.name.isNotEmpty || templateIsNonEmpty;
  }

  /// True when any template section has content. Drives the "discard current
  /// HTML?" confirm before a Start-from overwrites the draft.
  bool get templateIsNonEmpty {
    final t = draft.template;
    return t.body.isNotEmpty ||
        t.header.isNotEmpty ||
        t.footer.isNotEmpty ||
        t.includes.isNotEmpty ||
        t.product.isNotEmpty ||
        t.task.isNotEmpty;
  }

  @override
  Future<SaveResult<Design>> performSave() async {
    if (savesAsCreate) {
      final result = await repo.create(
        companyId: companyId,
        draft: draft,
        existingTempId: recoveryTempId,
      );
      rememberCreateTempId(result.entity.id);
      return result;
    }
    return repo.save(companyId: companyId, design: draft);
  }

  void resetToEmpty() {
    reset(emptyDraft: _emptyDesign());
    _seedRevision++;
    _seedCaretToNinja = false;
  }

  void setName(String v) => updateDraft(draft.copyWith(name: v));

  /// One-shot flag set by [setIsTemplate] when it just seeded the
  /// scaffold; the body editor calls [consumeSeedCaretToNinja] to drop
  /// the caret inside the freshly-seeded `<ninja>` block instead of
  /// leaving it at line 0. Cleared by every other reseed path so it
  /// can't yank the cursor on a Start-from / Import / Blank reseed.
  bool _seedCaretToNinja = false;

  /// Returns the current flag value and clears it. Called once per
  /// `seedRevision` bump by the body editor.
  bool consumeSeedCaretToNinja() {
    final v = _seedCaretToNinja;
    _seedCaretToNinja = false;
    return v;
  }

  /// Toggle the `is_template` flag. Flipping ON over an empty body seeds
  /// the minimal `<ninja></ninja>` scaffold (mirrors React
  /// `Create.tsx:108-130`); existing body content is preserved either
  /// way so the user doesn't lose work when experimenting.
  ///
  /// On toggle OFF, template-only entity tokens (expense / client /
  /// payment / project / task) are filtered out — the design-mode UI
  /// can't surface them anyway and leaving them in `draft.entities`
  /// would silently ship to the server. Data loss is intentional and
  /// predictable (the entities just dropped from view).
  void setIsTemplate(bool v) {
    final t = draft.template;
    // `trim()` so a body that's just whitespace (e.g. a few stray newlines)
    // still counts as empty and gets the scaffold.
    if (v && t.body.trim().isEmpty) {
      updateDraft(
        draft.copyWith(
          isTemplate: true,
          template: t.copyWith(body: kBlankDesignBody),
        ),
      );
      _seedRevision++;
      _seedCaretToNinja = true;
    } else if (v) {
      updateDraft(draft.copyWith(isTemplate: true));
    } else {
      // Toggling OFF — sanitize entities to the design-mode subset.
      updateDraft(
        draft.copyWith(
          isTemplate: false,
          entities: draft.entities.where(supportedEntities.contains).toList(),
        ),
      );
    }
  }

  void toggleEntity(String entity, bool selected) {
    final next = List<String>.from(draft.entities)..remove(entity);
    if (selected) next.add(entity);
    updateDraft(draft.copyWith(entities: next));
  }

  void setBody(String v) =>
      updateDraft(draft.copyWith(template: draft.template.copyWith(body: v)));
  void setHeader(String v) =>
      updateDraft(draft.copyWith(template: draft.template.copyWith(header: v)));
  void setFooter(String v) =>
      updateDraft(draft.copyWith(template: draft.template.copyWith(footer: v)));
  void setIncludes(String v) => updateDraft(
    draft.copyWith(template: draft.template.copyWith(includes: v)),
  );
  void setProduct(String v) => updateDraft(
    draft.copyWith(template: draft.template.copyWith(product: v)),
  );
  void setTask(String v) =>
      updateDraft(draft.copyWith(template: draft.template.copyWith(task: v)));

  /// Seed name / entities / template from an existing design (the
  /// "duplicate / new from existing" / "Edit a copy" flow) while keeping the
  /// current id so the save still targets this draft. Always lands as a
  /// **custom, non-template** design even when the source is a built-in —
  /// otherwise the saved row and the `/preview` payload would carry the
  /// source's `is_custom:false` / `is_template:true` flags.
  void loadFrom(Design source) {
    // We always force isTemplate=false on a copy. Drop any template-only
    // entity tokens (expense / client / payment / project / task) the
    // source may have carried — otherwise they'd persist invisibly into
    // the design-mode draft and ship to the server on Save.
    final filteredEntities = source.entities
        .where(supportedEntities.contains)
        .toList();
    updateDraft(
      draft.copyWith(
        name: draft.name.isEmpty ? source.name : draft.name,
        entities: filteredEntities,
        template: source.template,
        isCustom: true,
        isTemplate: false,
      ),
    );
    _seedRevision++;
    _seedCaretToNinja = false;
  }

  /// "Blank" start-from option: a minimal valid HTML scaffold.
  void loadBlankScaffold() {
    updateDraft(
      draft.copyWith(
        template: const DesignTemplate(body: kBlankDesignBody),
        isCustom: true,
        isTemplate: false,
      ),
    );
    _seedRevision++;
    _seedCaretToNinja = false;
  }

  /// Seed the draft from exported design JSON (the [DesignPayload.toApiJson]
  /// shape produced by Export). Returns an error string on malformed input,
  /// or null on success. Keeps the current id so Save targets this draft.
  String? importFromJson(String raw) {
    final Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } catch (_) {
      return 'invalid_json';
    }
    if (parsed is! Map) return 'invalid_json';
    final map = parsed.cast<String, dynamic>();
    // `design` block may be nested (our export) or the whole thing may be a
    // bare template map; accept both.
    final designBlock = map['design'];
    final tmplSrc = designBlock is Map
        ? designBlock.cast<String, dynamic>()
        : map.cast<String, dynamic>();
    final entitiesRaw = map['entities'];
    final entities = entitiesRaw is List
        ? entitiesRaw.map((e) => e.toString()).toList()
        : entitiesRaw is String
        ? entitiesRaw.split(',').where((e) => e.isNotEmpty).toList()
        : <String>[];
    final DesignTemplate template;
    try {
      // Deserialize through the API model (as the WYSIWYG VM does) so the
      // visual-builder `blocks` + `documentSettings` survive a JSON
      // round-trip — not just the six HTML string sections.
      template = DesignTemplate.fromApi(DesignTemplateApi.fromJson(tmplSrc));
    } catch (_) {
      return 'invalid_json';
    }
    updateDraft(
      draft.copyWith(
        name: (map['name'] ?? draft.name).toString(),
        entities: entities.isEmpty ? draft.entities : entities,
        template: template,
        isCustom: true,
        isTemplate: false,
      ),
    );
    _seedRevision++;
    _seedCaretToNinja = false;
    return null;
  }
}

Design _emptyDesign() => Design(
  id: '',
  name: '',
  isCustom: true,
  isActive: true,
  isTemplate: false,
  isFree: false,
  entities: const <String>[],
  template: const DesignTemplate(),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  archivedAt: null,
  isDeleted: false,
);
