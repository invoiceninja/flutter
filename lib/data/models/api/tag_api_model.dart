import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/json_coercion.dart';

part 'tag_api_model.freezed.dart';
part 'tag_api_model.g.dart';

/// The canonical short `entity_type` keys a tag can be scoped to. These match
/// each entity module's `wireName` (note the bank-transaction module's is
/// `bank_transaction`). Tags are per-type — the same name may exist once per
/// (company, entity_type).
const Set<String> kTagEntityTypes = <String>{
  'client',
  'product',
  'invoice',
  'payment',
  'recurring_invoice',
  'quote',
  'credit',
  'project',
  'task',
  'vendor',
  'expense',
  'bank_transaction',
  'purchase_order',
  'recurring_expense',
};

/// Normalize a tag's `entity_type` to its canonical short key.
///
/// The server may echo the short key (`invoice`), the FQCN
/// (`App\Models\RecurringInvoice`), or a morph/plural alias (`invoices`). The
/// index endpoint and our create payload both speak the short key, so we
/// normalize on every ingest.
String normalizeTagEntityType(String raw) {
  final v = raw.trim();
  if (kTagEntityTypes.contains(v)) return v;
  // Class-name tail after a namespace / path separator → snake_case.
  var tail = v;
  for (final sep in const <String>['\\', '/']) {
    final i = tail.lastIndexOf(sep);
    if (i >= 0) tail = tail.substring(i + 1);
  }
  final snake = _pascalToSnake(tail);
  if (kTagEntityTypes.contains(snake)) return snake;
  // Plural morph alias (`invoices` → `invoice`).
  if (snake.endsWith('s')) {
    final singular = snake.substring(0, snake.length - 1);
    if (kTagEntityTypes.contains(singular)) return singular;
  }
  // Defensive: an unexpected value falls through unchanged so a future
  // taggable type isn't silently coerced.
  return v;
}

/// `RecurringInvoice` → `recurring_invoice`. Inserts an underscore before each
/// interior uppercase letter (avoids RegExp lookbehind for portability).
String _pascalToSnake(String s) {
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final ch = s[i];
    final isUpper = ch.toUpperCase() == ch && ch.toLowerCase() != ch;
    if (i > 0 && isUpper) buf.write('_');
    buf.write(ch.toLowerCase());
  }
  return buf.toString();
}

/// Raw JSON shape of a tag as returned by `/api/v1/tags`.
@freezed
abstract class TagApi with _$TagApi {
  const factory TagApi({
    @Default('') String id,
    // Echoed as the FQCN by the server; normalize via [normalizeTagEntityType]
    // before it reaches the domain model.
    @JsonKey(name: 'entity_type') @Default('') String entityType,
    @Default('') String name,
    // Hex string (`#RRGGBB`) or null when unset.
    String? color,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
  }) = _TagApi;

  factory TagApi.fromJson(Map<String, dynamic> json) => _$TagApiFromJson(json);
}

/// Minimal embedded tag shape as it appears on a task/project (`tags:
/// [{id, name, color}]`). Carried only so the repository can derive the
/// denormalized `tag_names` sort column on ingest — the domain model keeps
/// just the ids and resolves name/color from the tag cache for rendering.
@freezed
abstract class TagRefApi with _$TagRefApi {
  const factory TagRefApi({
    @Default('') String id,
    @Default('') String name,
    String? color,
  }) = _TagRefApi;

  factory TagRefApi.fromJson(Map<String, dynamic> json) =>
      _$TagRefApiFromJson(json);
}

/// Tolerant converter for a task/project `tags` field. Accepts both the
/// server's `[{id, name, color}]` mini-objects and the bare `["id", ...]`
/// form our own `toApiJson` / Drift-payload round-trip emits, yielding
/// [TagRefApi]s either way (name/color empty for the bare-id form).
class EmbeddedTagsConverter implements JsonConverter<List<TagRefApi>, Object?> {
  const EmbeddedTagsConverter();

  @override
  List<TagRefApi> fromJson(Object? json) {
    if (json is! List) return const <TagRefApi>[];
    final out = <TagRefApi>[];
    for (final e in json) {
      if (e is String) {
        if (e.isNotEmpty) out.add(TagRefApi(id: e));
      } else if (e is Map) {
        out.add(TagRefApi.fromJson(e.cast<String, dynamic>()));
      }
    }
    return out;
  }

  @override
  Object toJson(List<TagRefApi> object) =>
      object.map((t) => t.toJson()).toList();
}

/// `GET /tags` response envelope.
@freezed
abstract class TagListApi with _$TagListApi {
  const factory TagListApi({
    @JsonKey(fromJson: _tagListData) @Default([]) List<TagApi> data,
  }) = _TagListApi;

  factory TagListApi.fromJson(Map<String, dynamic> json) =>
      _$TagListApiFromJson(json);
}

/// `POST/PUT /tags/{id}` single-item envelope.
@freezed
abstract class TagItemApi with _$TagItemApi {
  const factory TagItemApi({required TagApi data}) = _TagItemApi;

  factory TagItemApi.fromJson(Map<String, dynamic> json) =>
      _$TagItemApiFromJson(json);
}

List<TagApi> _tagListData(Object? raw) =>
    tolerantList(raw, TagApi.fromJson, label: 'tag');
