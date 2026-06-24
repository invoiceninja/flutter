// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'design_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DesignTemplateApi _$DesignTemplateApiFromJson(Map<String, dynamic> json) =>
    _DesignTemplateApi(
      body: json['body'] as String? ?? '',
      header: json['header'] as String? ?? '',
      footer: json['footer'] as String? ?? '',
      includes: json['includes'] as String? ?? '',
      product: json['product'] as String? ?? '',
      task: json['task'] as String? ?? '',
      blocks:
          (json['blocks'] as List<dynamic>?)
              ?.map((e) => DesignBlockApi.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <DesignBlockApi>[],
      documentSettings: json['documentSettings'] == null
          ? null
          : DocumentSettingsApi.fromJson(
              json['documentSettings'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$DesignTemplateApiToJson(_DesignTemplateApi instance) =>
    <String, dynamic>{
      'body': instance.body,
      'header': instance.header,
      'footer': instance.footer,
      'includes': instance.includes,
      'product': instance.product,
      'task': instance.task,
      'blocks': instance.blocks,
      'documentSettings': ?instance.documentSettings,
    };

_DesignBlockApi _$DesignBlockApiFromJson(Map<String, dynamic> json) =>
    _DesignBlockApi(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      gridPosition: json['gridPosition'] == null
          ? const GridPositionApi()
          : GridPositionApi.fromJson(
              json['gridPosition'] as Map<String, dynamic>,
            ),
      properties: json['properties'] as Map<String, dynamic>?,
      locked: json['locked'] as bool?,
      rowAlign: json['rowAlign'] as String?,
      rowWidth: json['rowWidth'] as String?,
      colStart: (json['colStart'] as num?)?.toInt(),
      colSpan: (json['colSpan'] as num?)?.toInt(),
    );

Map<String, dynamic> _$DesignBlockApiToJson(_DesignBlockApi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'gridPosition': instance.gridPosition,
      'properties': ?instance.properties,
      'locked': ?instance.locked,
      'rowAlign': ?instance.rowAlign,
      'rowWidth': ?instance.rowWidth,
      'colStart': ?instance.colStart,
      'colSpan': ?instance.colSpan,
    };

_GridPositionApi _$GridPositionApiFromJson(Map<String, dynamic> json) =>
    _GridPositionApi(
      x: (json['x'] as num?)?.toInt() ?? 0,
      y: (json['y'] as num?)?.toInt() ?? 0,
      w: (json['w'] as num?)?.toInt() ?? 1,
      h: (json['h'] as num?)?.toInt() ?? 1,
    );

Map<String, dynamic> _$GridPositionApiToJson(_GridPositionApi instance) =>
    <String, dynamic>{
      'x': instance.x,
      'y': instance.y,
      'w': instance.w,
      'h': instance.h,
    };

_DocumentSettingsApi _$DocumentSettingsApiFromJson(Map<String, dynamic> json) =>
    _DocumentSettingsApi(
      pageLayout: json['pageLayout'] as String? ?? 'portrait',
      pageSize: json['pageSize'] as String? ?? 'A4',
      globalFontSize: (json['globalFontSize'] as num?)?.toInt() ?? 16,
      primaryFont: json['primaryFont'] as String? ?? 'Roboto',
      secondaryFont: json['secondaryFont'] as String? ?? 'Roboto',
      showPaidStamp: json['showPaidStamp'] as bool? ?? false,
      showShippingAddress: json['showShippingAddress'] as bool? ?? false,
      embedDocuments: json['embedDocuments'] as bool? ?? false,
      hideEmptyColumns: json['hideEmptyColumns'] as bool? ?? false,
      pageNumbering: json['pageNumbering'] as bool? ?? false,
      pageMarginTop: (json['pageMarginTop'] as num?)?.toInt() ?? 0,
      pageMarginRight: (json['pageMarginRight'] as num?)?.toInt() ?? 0,
      pageMarginBottom: (json['pageMarginBottom'] as num?)?.toInt() ?? 0,
      pageMarginLeft: (json['pageMarginLeft'] as num?)?.toInt() ?? 0,
      pagePaddingTop: (json['pagePaddingTop'] as num?)?.toInt() ?? 30,
      pagePaddingRight: (json['pagePaddingRight'] as num?)?.toInt() ?? 30,
      pagePaddingBottom: (json['pagePaddingBottom'] as num?)?.toInt() ?? 30,
      pagePaddingLeft: (json['pagePaddingLeft'] as num?)?.toInt() ?? 30,
    );

Map<String, dynamic> _$DocumentSettingsApiToJson(
  _DocumentSettingsApi instance,
) => <String, dynamic>{
  'pageLayout': instance.pageLayout,
  'pageSize': instance.pageSize,
  'globalFontSize': instance.globalFontSize,
  'primaryFont': instance.primaryFont,
  'secondaryFont': instance.secondaryFont,
  'showPaidStamp': instance.showPaidStamp,
  'showShippingAddress': instance.showShippingAddress,
  'embedDocuments': instance.embedDocuments,
  'hideEmptyColumns': instance.hideEmptyColumns,
  'pageNumbering': instance.pageNumbering,
  'pageMarginTop': instance.pageMarginTop,
  'pageMarginRight': instance.pageMarginRight,
  'pageMarginBottom': instance.pageMarginBottom,
  'pageMarginLeft': instance.pageMarginLeft,
  'pagePaddingTop': instance.pagePaddingTop,
  'pagePaddingRight': instance.pagePaddingRight,
  'pagePaddingBottom': instance.pagePaddingBottom,
  'pagePaddingLeft': instance.pagePaddingLeft,
};

_DesignApi _$DesignApiFromJson(Map<String, dynamic> json) => _DesignApi(
  id: json['id'] as String? ?? '',
  name: json['name'] as String? ?? '',
  isCustom: json['is_custom'] as bool? ?? false,
  isActive: json['is_active'] as bool? ?? true,
  isTemplate: json['is_template'] as bool? ?? false,
  isFree: json['is_free'] as bool? ?? true,
  entities: json['entities'] as String? ?? '',
  design: json['design'] == null
      ? const DesignTemplateApi()
      : DesignTemplateApi.fromJson(json['design'] as Map<String, dynamic>),
  createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
  updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
  archivedAt: (json['archived_at'] as num?)?.toInt() ?? 0,
  isDeleted: json['is_deleted'] as bool? ?? false,
);

Map<String, dynamic> _$DesignApiToJson(_DesignApi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'is_custom': instance.isCustom,
      'is_active': instance.isActive,
      'is_template': instance.isTemplate,
      'is_free': instance.isFree,
      'entities': instance.entities,
      'design': instance.design,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'archived_at': instance.archivedAt,
      'is_deleted': instance.isDeleted,
    };

_DesignListApi _$DesignListApiFromJson(Map<String, dynamic> json) =>
    _DesignListApi(
      data: json['data'] == null
          ? const <DesignApi>[]
          : _designListData(json['data']),
    );

Map<String, dynamic> _$DesignListApiToJson(_DesignListApi instance) =>
    <String, dynamic>{'data': instance.data};

_DesignItemApi _$DesignItemApiFromJson(Map<String, dynamic> json) =>
    _DesignItemApi(
      data: DesignApi.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DesignItemApiToJson(_DesignItemApi instance) =>
    <String, dynamic>{'data': instance.data};
