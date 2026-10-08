import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/design_api_model.dart';
import 'package:admin/data/models/domain/design_block_layout.dart';
import 'package:admin/data/models/domain/design_block_wire.dart';
import 'package:admin/data/models/value/parsing.dart';

part 'design.freezed.dart';

/// Clean domain model for a Design row. Used by the Invoice Design settings
/// page's design pickers (`invoice_design_id`, `quote_design_id`, …) and
/// the upcoming Custom Designs CRUD list.
///
/// `entities` on the wire is a comma-separated string; we project it to
/// `List<String>` here so call sites can iterate without re-parsing. Re-join
/// on save (see [DesignPayload.toApiJson]).
@freezed
abstract class Design with _$Design {
  const factory Design({
    required String id,
    required String name,
    required bool isCustom,
    required bool isActive,
    required bool isTemplate,
    required bool isFree,
    required List<String> entities,
    required DesignTemplate template,
    required DateTime updatedAt,
    required DateTime createdAt,
    required DateTime? archivedAt,
    required bool isDeleted,
    @Default(false) bool isDirty,
  }) = _Design;

  factory Design.fromApi(DesignApi a) => Design(
    id: a.id,
    name: a.name,
    isCustom: a.isCustom,
    isActive: a.isActive,
    isTemplate: a.isTemplate,
    isFree: a.isFree,
    entities: a.entities.isEmpty
        ? const <String>[]
        : a.entities
              .split(',')
              .where((e) => e.isNotEmpty)
              .toList(growable: false),
    template: DesignTemplate.fromApi(a.design),
    updatedAt: epochSecondsToUtc(a.updatedAt),
    createdAt: epochSecondsToUtc(a.createdAt),
    archivedAt: epochSecondsToUtcOrNull(a.archivedAt),
    isDeleted: a.isDeleted,
  );
}

@freezed
abstract class DesignTemplate with _$DesignTemplate {
  const factory DesignTemplate({
    @Default('') String body,
    @Default('') String header,
    @Default('') String footer,
    @Default('') String includes,
    @Default('') String product,
    @Default('') String task,
    @Default(<DesignBlock>[]) List<DesignBlock> blocks,
    DocumentSettings? documentSettings,

    /// Fields the server sent that this model has no name for — carried so a
    /// save hands them back (`kDesignExtraKey`).
    @Default(<String, dynamic>{}) Map<String, dynamic> extra,
  }) = _DesignTemplate;

  factory DesignTemplate.fromApi(DesignTemplateApi a) => DesignTemplate(
    body: a.body,
    header: a.header,
    footer: a.footer,
    includes: a.includes,
    product: a.product,
    task: a.task,
    blocks: a.blocks.map(DesignBlock.fromApi).toList(growable: false),
    documentSettings: a.documentSettings == null
        ? null
        : DocumentSettings.fromApi(a.documentSettings!),
    extra: a.extra ?? const <String, dynamic>{},
  );
}

extension DesignTemplateApiMapper on DesignTemplate {
  /// Round-trip back to the API shape. Blocks are projected through
  /// [annotateBlocksAsApi] so each carries the `rowAlign` the server-side HTML
  /// generator places it by. This is the local payload shape; what the server
  /// is sent is `toApi().toWireJson()`, which also drops an empty `blocks`.
  DesignTemplateApi toApi() => DesignTemplateApi(
    body: body,
    header: header,
    footer: footer,
    includes: includes,
    product: product,
    task: task,
    blocks: annotateBlocksAsApi(blocks),
    documentSettings: documentSettings?.toApi(),
    extra: extra.isEmpty ? null : extra,
  );
}

/// A single WYSIWYG canvas block. `properties` stays a typed-loose
/// `Map<String, dynamic>` — the React schema is `Record<string, any>` with
/// only TypeScript hints, so block renderers and property panels read keys
/// directly. Use `DesignBlock.locked == true` to suppress drag/resize.
@freezed
abstract class DesignBlock with _$DesignBlock {
  const factory DesignBlock({
    required String id,
    required String type,
    required GridPosition gridPosition,
    @Default(<String, dynamic>{}) Map<String, dynamic> properties,
    @Default(false) bool locked,

    /// Unknown fields, as on [DesignTemplate.extra] — e.g. a block's `region`.
    @Default(<String, dynamic>{}) Map<String, dynamic> extra,
  }) = _DesignBlock;

  factory DesignBlock.fromApi(DesignBlockApi a) => DesignBlock(
    id: a.id,
    type: a.type,
    gridPosition: GridPosition.fromApi(a.gridPosition),
    properties: a.properties == null
        ? const <String, dynamic>{}
        : Map<String, dynamic>.from(a.properties!),
    locked: a.locked ?? false,
    extra: a.extra ?? const <String, dynamic>{},
  );
}

extension DesignBlockApiMapper on DesignBlock {
  /// `properties` is always present, and passes through
  /// [wireBlockProperties]: the server reads it unguarded, so a block without
  /// one is a failed render of the whole document.
  DesignBlockApi toApi() => DesignBlockApi(
    id: id,
    type: type,
    gridPosition: gridPosition.toApi(),
    properties: Map<String, dynamic>.from(
      wireBlockProperties(type, properties),
    ),
    locked: locked ? true : null,
    extra: extra.isEmpty ? null : extra,
  );
}

/// `x` 0..=11 column index, `w` 1..=12 column span. `y` and `h` are row
/// indices (unbounded).
@freezed
abstract class GridPosition with _$GridPosition {
  const factory GridPosition({
    required int x,
    required int y,
    required int w,
    required int h,
  }) = _GridPosition;

  factory GridPosition.fromApi(GridPositionApi a) =>
      GridPosition(x: a.x, y: a.y, w: a.w, h: a.h);
}

extension GridPositionApiMapper on GridPosition {
  GridPositionApi toApi() => GridPositionApi(x: x, y: y, w: w, h: h);
}

/// Per-template document-level settings, seeded from `company.settings` and
/// overridable per design. All fields are required once present.
@freezed
abstract class DocumentSettings with _$DocumentSettings {
  const factory DocumentSettings({
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

    /// Unknown fields, as on [DesignTemplate.extra] — e.g. `pagination`.
    @Default(<String, dynamic>{}) Map<String, dynamic> extra,
  }) = _DocumentSettings;

  factory DocumentSettings.fromApi(DocumentSettingsApi a) => DocumentSettings(
    pageLayout: a.pageLayout,
    pageSize: a.pageSize,
    globalFontSize: a.globalFontSize,
    primaryFont: a.primaryFont,
    secondaryFont: a.secondaryFont,
    showPaidStamp: a.showPaidStamp,
    showShippingAddress: a.showShippingAddress,
    embedDocuments: a.embedDocuments,
    hideEmptyColumns: a.hideEmptyColumns,
    pageNumbering: a.pageNumbering,
    pageMarginTop: a.pageMarginTop,
    pageMarginRight: a.pageMarginRight,
    pageMarginBottom: a.pageMarginBottom,
    pageMarginLeft: a.pageMarginLeft,
    pagePaddingTop: a.pagePaddingTop,
    pagePaddingRight: a.pagePaddingRight,
    pagePaddingBottom: a.pagePaddingBottom,
    pagePaddingLeft: a.pagePaddingLeft,
    extra: a.extra ?? const <String, dynamic>{},
  );
}

extension DocumentSettingsApiMapper on DocumentSettings {
  DocumentSettingsApi toApi() => DocumentSettingsApi(
    pageLayout: pageLayout,
    pageSize: pageSize,
    globalFontSize: globalFontSize,
    primaryFont: primaryFont,
    secondaryFont: secondaryFont,
    showPaidStamp: showPaidStamp,
    showShippingAddress: showShippingAddress,
    embedDocuments: embedDocuments,
    hideEmptyColumns: hideEmptyColumns,
    pageNumbering: pageNumbering,
    pageMarginTop: pageMarginTop,
    pageMarginRight: pageMarginRight,
    pageMarginBottom: pageMarginBottom,
    pageMarginLeft: pageMarginLeft,
    pagePaddingTop: pagePaddingTop,
    pagePaddingRight: pagePaddingRight,
    pagePaddingBottom: pagePaddingBottom,
    pagePaddingLeft: pagePaddingLeft,
    extra: extra.isEmpty ? null : extra,
  );
}

extension DesignPayload on Design {
  Map<String, dynamic> toApiJson({bool preserveTempId = false}) {
    return <String, dynamic>{
      if (preserveTempId || !id.startsWith('tmp_')) 'id': id,
      'name': name,
      'is_custom': isCustom,
      'is_active': isActive,
      'is_template': isTemplate,
      'is_free': isFree,
      'entities': entities.join(','),
      'design': template.toApi().toWireJson(),
    };
  }
}
