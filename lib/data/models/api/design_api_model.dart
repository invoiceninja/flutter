import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/json_coercion.dart';

part 'design_api_model.freezed.dart';
part 'design_api_model.g.dart';

/// HTML template payload nested under `design.design` on each Design row.
/// Mirrors the server contract: six raw HTML strings the PDF renderer
/// concatenates (`includes` CSS, `header`, `body`, `product`, `task`,
/// `footer`), plus the WYSIWYG builder's `blocks` array and
/// `documentSettings` overrides.
///
/// `body` is the only required section for `is_template = true` rows;
/// non-template designs carry every section.
///
/// `blocks` and `documentSettings` come from the React `invoice-designer`
/// branch (May 2026). They are persisted as **camelCase** on the wire —
/// unlike most of the API which uses snake_case — so the Freezed classes
/// MUST NOT apply `@JsonSerializable(fieldRename: FieldRename.snake)` to
/// the new sub-shapes. Server preserves all fields end-to-end (verified
/// against demo).
@freezed
abstract class DesignTemplateApi with _$DesignTemplateApi {
  const factory DesignTemplateApi({
    @Default('') String body,
    @Default('') String header,
    @Default('') String footer,
    @Default('') String includes,
    @Default('') String product,
    @Default('') String task,
    @Default(<DesignBlockApi>[]) List<DesignBlockApi> blocks,
    @JsonKey(includeIfNull: false) DocumentSettingsApi? documentSettings,
    @JsonKey(
      name: kDesignExtraKey,
      readValue: _readTemplateExtra,
      includeIfNull: false,
    )
    Map<String, dynamic>? extra,
  }) = _DesignTemplateApi;

  factory DesignTemplateApi.fromJson(Map<String, dynamic> json) =>
      _$DesignTemplateApiFromJson(json);
}

/// Key the local Drift payload keeps a design's unknown fields under. It never
/// reaches the server: [DesignTemplateWire.toWireJson] spreads the fields back
/// to where they came from.
///
/// The other client's builder writes fields this app has no model for
/// (`builderGridVersion`, `layout`, `customCss`, a block's `region`, the
/// pagination settings). A typed model that only knows its own fields drops
/// them on the first save, so each of the three shapes carries the leftovers.
const kDesignExtraKey = '__extra';

const _kTemplateKeys = <String>{
  'body',
  'header',
  'footer',
  'includes',
  'product',
  'task',
  'blocks',
  'documentSettings',
};

const _kBlockKeys = <String>{
  'id',
  'type',
  'gridPosition',
  'properties',
  'locked',
  'rowAlign',
  'rowWidth',
  'colStart',
  'colSpan',
};

const _kDocumentSettingsKeys = <String>{
  'pageLayout',
  'pageSize',
  'globalFontSize',
  'primaryFont',
  'secondaryFont',
  'showPaidStamp',
  'showShippingAddress',
  'embedDocuments',
  'hideEmptyColumns',
  'pageNumbering',
  'pageMarginTop',
  'pageMarginRight',
  'pageMarginBottom',
  'pageMarginLeft',
  'pagePaddingTop',
  'pagePaddingRight',
  'pagePaddingBottom',
  'pagePaddingLeft',
};

/// The fields of [json] that [known] does not name, plus whatever a local
/// payload already parked under [kDesignExtraKey]. Null when there are none,
/// so a design this app wrote serializes exactly as before.
Map<String, dynamic>? _unknownFields(
  Map<dynamic, dynamic> json,
  Set<String> known,
) {
  final out = <String, dynamic>{};
  final parked = json[kDesignExtraKey];
  if (parked is Map) {
    for (final e in parked.entries) {
      out['${e.key}'] = e.value;
    }
  }
  for (final e in json.entries) {
    final key = '${e.key}';
    if (key == kDesignExtraKey || known.contains(key)) continue;
    out[key] = e.value;
  }
  return out.isEmpty ? null : out;
}

Object? _readTemplateExtra(Map<dynamic, dynamic> json, String _) =>
    _unknownFields(json, _kTemplateKeys);

Object? _readBlockExtra(Map<dynamic, dynamic> json, String _) =>
    _unknownFields(json, _kBlockKeys);

Object? _readDocumentSettingsExtra(Map<dynamic, dynamic> json, String _) =>
    _unknownFields(json, _kDocumentSettingsKeys);

Map<String, dynamic> _spreadExtra(Map<String, dynamic> json) {
  final extra = json.remove(kDesignExtraKey);
  if (extra is Map) {
    for (final e in extra.entries) {
      json.putIfAbsent('${e.key}', () => e.value);
    }
  }
  return json;
}

extension DesignTemplateWire on DesignTemplateApi {
  /// The JSON the server is sent — for a save and for a preview alike.
  ///
  /// Differs from [toJson] (the local payload shape) in two ways. Unknown
  /// fields go back to the level they were read from. And **`blocks` is left
  /// out when there are none**: the server takes a custom design for a block
  /// design whenever the key is present (`isset`, so an empty list counts) and
  /// then ignores its HTML, which rendered every HTML design this app saved as
  /// a blank page.
  Map<String, dynamic> toWireJson() {
    final json = _spreadExtra(toJson());
    if (blocks.isEmpty) {
      json.remove('blocks');
    } else {
      json['blocks'] = [for (final b in blocks) _spreadExtra(b.toJson())];
    }
    final settings = documentSettings;
    if (settings != null) {
      json['documentSettings'] = _spreadExtra(settings.toJson());
    }
    return json;
  }
}

/// A block's `properties` as a map, whatever came back.
///
/// PHP has one array type, so an object with no keys is re-encoded as `[]`
/// — and a block with no properties is always sent with the key. A hard
/// cast threw on that echo: the save's response was never applied, and
/// `tolerantList` then dropped the whole design from every list.
Map<String, dynamic>? _blockProperties(Object? raw) => switch (raw) {
  null => null,
  final Map<dynamic, dynamic> map => Map<String, dynamic>.from(map),
  _ => const <String, dynamic>{},
};

/// A single block on the WYSIWYG canvas. `properties` stays opaque
/// (`Map<String, dynamic>`) at the API boundary — React uses
/// `Record<string, any>` with only TS-level type hints, so renderers and
/// property-panels deserialize the map into typed locals as needed.
///
/// `type` strings are stable contract — preserve casing exactly
/// (`tasks-table`, `client-shipping-info`, etc.).
///
/// `rowAlign` / `rowWidth` / `colStart` / `colSpan` are **derived at save
/// time** by `annotateBlocksAsApi` (`design_block_layout.dart`). They are not
/// stored on the in-memory [DesignBlock] domain object — a fresh value is
/// projected every save from `gridPosition` + the block's row siblings.
/// The server's HTML generator uses them to place blocks within flex rows.
@freezed
abstract class DesignBlockApi with _$DesignBlockApi {
  const factory DesignBlockApi({
    @Default('') String id,
    @Default('') String type,
    @Default(GridPositionApi()) GridPositionApi gridPosition,
    @JsonKey(includeIfNull: false, fromJson: _blockProperties)
    Map<String, dynamic>? properties,
    @JsonKey(includeIfNull: false) bool? locked,
    @JsonKey(includeIfNull: false) String? rowAlign,
    @JsonKey(includeIfNull: false) String? rowWidth,
    @JsonKey(includeIfNull: false) int? colStart,
    @JsonKey(includeIfNull: false) int? colSpan,
    @JsonKey(
      name: kDesignExtraKey,
      readValue: _readBlockExtra,
      includeIfNull: false,
    )
    Map<String, dynamic>? extra,
  }) = _DesignBlockApi;

  factory DesignBlockApi.fromJson(Map<String, dynamic> json) =>
      _$DesignBlockApiFromJson(json);
}

/// A block's position on the 12-column grid. `x` in `0..=11`,
/// `w` in `1..=12`. `y` and `h` are unbounded row indices.
@freezed
abstract class GridPositionApi with _$GridPositionApi {
  const factory GridPositionApi({
    @Default(0) int x,
    @Default(0) int y,
    @Default(1) int w,
    @Default(1) int h,
  }) = _GridPositionApi;

  factory GridPositionApi.fromJson(Map<String, dynamic> json) =>
      _$GridPositionApiFromJson(json);
}

/// Per-template document-level settings. Initially seeded from
/// `company.settings` (page_layout / page_size / font_size / primary_font /
/// secondary_font / show_paid_stamp / show_shipping_address /
/// embed_documents / hide_empty_columns_on_pdf / page_numbering) but stored
/// on the template so designs can override company defaults.
///
/// Per-side `pageMargin*` and `pagePadding*` are integer pixels driving
/// `@page { margin }` and `.invoice-container` padding in the rendered PDF.
@freezed
abstract class DocumentSettingsApi with _$DocumentSettingsApi {
  const factory DocumentSettingsApi({
    @Default('portrait') String pageLayout,
    @Default('A4') String pageSize,
    @Default(16) int globalFontSize,
    @Default('Roboto') String primaryFont,
    @Default('Roboto') String secondaryFont,
    @Default(false) bool showPaidStamp,
    @Default(false) bool showShippingAddress,
    @Default(false) bool embedDocuments,
    @Default(false) bool hideEmptyColumns,
    @Default(false) bool pageNumbering,
    @Default(0) int pageMarginTop,
    @Default(0) int pageMarginRight,
    @Default(0) int pageMarginBottom,
    @Default(0) int pageMarginLeft,
    @Default(30) int pagePaddingTop,
    @Default(30) int pagePaddingRight,
    @Default(30) int pagePaddingBottom,
    @Default(30) int pagePaddingLeft,
    @JsonKey(
      name: kDesignExtraKey,
      readValue: _readDocumentSettingsExtra,
      includeIfNull: false,
    )
    Map<String, dynamic>? extra,
  }) = _DocumentSettingsApi;

  factory DocumentSettingsApi.fromJson(Map<String, dynamic> json) =>
      _$DocumentSettingsApiFromJson(json);
}

/// Raw JSON shape of a design row as returned by `/api/v1/designs` and
/// bundled in `data[N].company.designs` on `/login`/`/refresh`.
///
/// `entities` is a comma-separated string on the wire (e.g. `"invoice,quote"`)
/// — not a JSON array. Domain projection ([Design]) splits on `,`.
@freezed
abstract class DesignApi with _$DesignApi {
  const factory DesignApi({
    @Default('') String id,
    @Default('') String name,
    @JsonKey(name: 'is_custom') @Default(false) bool isCustom,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'is_template') @Default(false) bool isTemplate,
    @JsonKey(name: 'is_free') @Default(true) bool isFree,
    @Default('') String entities,
    @Default(DesignTemplateApi()) DesignTemplateApi design,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
  }) = _DesignApi;

  factory DesignApi.fromJson(Map<String, dynamic> json) =>
      _$DesignApiFromJson(json);
}

/// `GET /designs` response envelope.
@freezed
abstract class DesignListApi with _$DesignListApi {
  const factory DesignListApi({
    @JsonKey(fromJson: _designListData)
    @Default(<DesignApi>[])
    List<DesignApi> data,
  }) = _DesignListApi;

  factory DesignListApi.fromJson(Map<String, dynamic> json) =>
      _$DesignListApiFromJson(json);
}

/// `POST/PUT /designs/{id}` single-item envelope.
@freezed
abstract class DesignItemApi with _$DesignItemApi {
  const factory DesignItemApi({required DesignApi data}) = _DesignItemApi;

  factory DesignItemApi.fromJson(Map<String, dynamic> json) =>
      _$DesignItemApiFromJson(json);
}

List<DesignApi> _designListData(Object? raw) =>
    tolerantList(raw, DesignApi.fromJson, label: 'design');
