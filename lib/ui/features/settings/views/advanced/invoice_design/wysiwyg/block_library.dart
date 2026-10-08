import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/design.dart';

/// Ports React's `block-library.tsx` — the catalog of WYSIWYG block types
/// plus their default sizes, default properties, icons, and category. New
/// blocks copy from one of these specs via [BlockSpec.newInstance].

enum BlockCategory { branding, content, data, layout }

class BlockSpec {
  const BlockSpec({
    required this.type,
    required this.labelKey,
    required this.icon,
    required this.defaultWidth,
    required this.defaultHeight,
    required this.defaultProperties,
    required this.category,
    this.essential = false,
    this.printed = true,
  });

  /// Stable wire identifier (matches React BlockType). Preserve casing —
  /// `tasks-table`, `client-shipping-info`, etc.
  final String type;

  /// Translation key for the user-facing label in the palette.
  final String labelKey;

  final IconData icon;
  final int defaultWidth;
  final int defaultHeight;
  final Map<String, dynamic> defaultProperties;
  final BlockCategory category;

  /// Marked `essential: true` in React — products/tasks tables and the totals
  /// block. Reserved for future hint chips.
  final bool essential;

  /// False for a block type the server has no renderer for: it is kept out
  /// of the palette, and one already on a design says it will not print.
  /// Today that is `tasks-table` — `JsonToSectionsAdapter::convertBlockToSection`
  /// has no arm for it, so the block prints nothing (`BACKEND.md`).
  final bool printed;

  DesignBlock newInstance({
    required String idPrefix,
    required int x,
    required int y,
  }) {
    return DesignBlock(
      id: newBlockId(type),
      type: type,
      gridPosition: GridPosition(x: x, y: y, w: defaultWidth, h: defaultHeight),
      properties: Map<String, dynamic>.from(defaultProperties),
    );
  }
}

/// Stable ID generator for a new (or duplicated) WYSIWYG block. Mirrors
/// React's `generateBlockId(type)` = `${type}-${uuidv4()}` so duplicates
/// produced on either platform have the same shape and round-trip without
/// surprise. Collisions are vanishingly unlikely; the server reissues IDs
/// on save anyway.
String newBlockId(String type) {
  final rnd = math.Random();
  String hex(int n) =>
      List.generate(n, (_) => rnd.nextInt(16).toRadixString(16)).join();
  return '$type-${hex(8)}-${hex(4)}-4${hex(3)}-${'89ab'[rnd.nextInt(4)]}${hex(3)}-${hex(12)}';
}

const _defaultValueColor = '#000000';
const _defaultLabelColor = '#6B7280';

/// Default table-region border properties. Mirrors React's
/// `DEFAULT_TABLE_REGION_BORDER_PROPS` in `utils/table-cell-borders.ts` —
/// applied to both `headerBorders` and `rowBorders` on table / tasks-table
/// blocks so the server has a starting border spec to render.
const Map<String, dynamic> _defaultTableRegionBorders = <String, dynamic>{
  'color': '#E5E7EB',
  'width': 1,
  'sides': <String, dynamic>{
    'top': true,
    'right': true,
    'bottom': true,
    'left': true,
  },
};

/// Static catalog of 17 block specs, mirroring the React block-library.
/// Translations are resolved at render time via [BlockSpec.labelKey].
final List<BlockSpec> kBlockLibrary = <BlockSpec>[
  // ── Branding ────────────────────────────────────────────────────────
  BlockSpec(
    type: 'logo',
    labelKey: 'company_logo',
    icon: Icons.business_outlined,
    defaultWidth: 4,
    defaultHeight: 4,
    defaultProperties: const {
      'source': r'$company.logo',
      'align': 'left',
      'maxWidth': '150px',
      'objectFit': 'contain',
    },
    category: BlockCategory.branding,
  ),
  BlockSpec(
    type: 'company-info',
    labelKey: 'company_details',
    icon: Icons.business_outlined,
    defaultWidth: 6,
    defaultHeight: 4,
    defaultProperties: _infoBlockDefaults(
      fieldConfigs: [
        _field('name', 'company_name', r'$company.name'),
        _field('address1', 'address1', r'$company.address1'),
        _field(
          'city_state_postal',
          'city_state_postal',
          r'$company.city_state_postal',
        ),
        _field('phone', 'phone', r'$company.phone'),
        _field('email', 'email', r'$company.email'),
      ],
      title: r'$from_label',
    ),
    category: BlockCategory.branding,
  ),

  // ── Content ─────────────────────────────────────────────────────────
  BlockSpec(
    type: 'text',
    labelKey: 'text',
    icon: Icons.text_fields_outlined,
    defaultWidth: 6,
    defaultHeight: 2,
    defaultProperties: const {
      'content': '',
      'fontWeight': 'normal',
      'lineHeight': '1.3',
      'align': 'left',
      'fontStyle': 'normal',
      'padding': '0px',
      'color': _defaultValueColor,
    },
    category: BlockCategory.content,
  ),
  BlockSpec(
    type: 'client-info',
    labelKey: 'client_details',
    icon: Icons.person_outline,
    defaultWidth: 6,
    defaultHeight: 4,
    defaultProperties: _infoBlockDefaults(
      fieldConfigs: [
        _field('name', 'client_name', r'$client.name'),
        _field('address1', 'address1', r'$client.address1'),
        _field(
          'city_state_postal',
          'city_state_postal',
          r'$client.city_state_postal',
        ),
        _field('phone', 'phone', r'$client.phone'),
        _field('email', 'email', r'$client.email'),
      ],
      title: r'$bill_to_label',
    ),
    category: BlockCategory.content,
  ),
  BlockSpec(
    type: 'client-shipping-info',
    labelKey: 'ship_to',
    icon: Icons.location_on_outlined,
    defaultWidth: 6,
    defaultHeight: 4,
    defaultProperties: _infoBlockDefaults(
      fieldConfigs: [
        _field('shipping_address1', 'address1', r'$client.shipping_address1'),
        _field(
          'shipping_city_state_postal',
          'city_state_postal',
          r'$client.shipping_city_state_postal',
        ),
      ],
      title: r'$ship_to_label',
    ),
    category: BlockCategory.content,
  ),
  BlockSpec(
    type: 'invoice-details',
    labelKey: 'invoice_details',
    icon: Icons.receipt_outlined,
    defaultWidth: 6,
    defaultHeight: 5,
    defaultProperties: {
      'fieldConfigs': [
        _field(
          'number',
          r'$number_label',
          r'$number',
          prefix: r'$number_label: ',
        ),
        _field('date', r'$date_label', r'$date', prefix: r'$date_label: '),
        _field(
          'due_date',
          r'$due_date_label',
          r'$due_date',
          prefix: r'$due_date_label: ',
        ),
        _field(
          'balance',
          r'$balance_label',
          r'$balance',
          prefix: r'$balance_label: ',
        ),
      ],
      'lineHeight': '1.3',
      'align': 'right',
      'color': _defaultValueColor,
      'labelColor': _defaultLabelColor,
      'showLabels': true,
      'labelAlign': 'right',
      'valueAlign': 'right',
      'labelPadding': '0px',
      'valuePadding': '0px',
      'labelValueGap': '12px',
      'rowSpacing': '0px',
      'valueMinWidth': '',
    },
    category: BlockCategory.content,
  ),
  BlockSpec(
    type: 'public-notes',
    labelKey: 'public_notes',
    icon: Icons.sticky_note_2_outlined,
    defaultWidth: 12,
    defaultHeight: 3,
    defaultProperties: const {
      'content': r'$public_notes',
      'fontWeight': 'normal',
      'lineHeight': '1.3',
      'align': 'left',
      'fontStyle': 'normal',
      'padding': '0px',
      'color': _defaultValueColor,
    },
    category: BlockCategory.content,
  ),
  BlockSpec(
    type: 'footer',
    labelKey: 'footer',
    icon: Icons.south_outlined,
    defaultWidth: 12,
    defaultHeight: 2,
    defaultProperties: const {
      'content': r'$footer',
      'fontWeight': 'normal',
      'lineHeight': '1.3',
      'color': '#6B7280',
      'align': 'center',
      'fontStyle': 'normal',
      'padding': '0px',
    },
    category: BlockCategory.content,
  ),
  BlockSpec(
    type: 'terms',
    labelKey: 'terms',
    icon: Icons.description_outlined,
    defaultWidth: 12,
    defaultHeight: 3,
    defaultProperties: const {
      'content': r'$terms',
      'fontWeight': 'normal',
      'lineHeight': '1.3',
      'align': 'left',
      'fontStyle': 'normal',
      'padding': '0px',
      'color': _defaultValueColor,
    },
    category: BlockCategory.content,
  ),
  BlockSpec(
    type: 'image',
    labelKey: 'image',
    icon: Icons.image_outlined,
    defaultWidth: 3,
    defaultHeight: 3,
    defaultProperties: const {
      'source': '',
      'align': 'center',
      'maxWidth': '200px',
      'objectFit': 'contain',
    },
    category: BlockCategory.content,
  ),

  // ── Data ────────────────────────────────────────────────────────────
  BlockSpec(
    type: 'table',
    labelKey: 'products',
    icon: Icons.table_chart_outlined,
    defaultWidth: 12,
    defaultHeight: 8,
    defaultProperties: _tableDefaults(
      columns: [
        _col(
          'product_key',
          r'$product.item_label',
          'item.product_key',
          '25%',
          'left',
        ),
        _col(
          'notes',
          r'$product.description_label',
          'item.notes',
          '30%',
          'left',
        ),
        _col(
          'quantity',
          r'$product.quantity_label',
          'item.quantity',
          '10%',
          'center',
        ),
        _col('cost', r'$product.unit_cost_label', 'item.cost', '15%', 'right'),
        _col(
          'line_total',
          r'$product.line_total_label',
          'item.line_total',
          '15%',
          'right',
        ),
      ],
    ),
    category: BlockCategory.data,
    essential: true,
  ),
  BlockSpec(
    type: 'tasks-table',
    labelKey: 'tasks',
    icon: Icons.access_time_outlined,
    defaultWidth: 12,
    defaultHeight: 8,
    defaultProperties: _tableDefaults(
      columns: [
        _col(
          'service',
          r'$task.service_label',
          'item.product_key',
          '25%',
          'left',
        ),
        _col('notes', r'$task.description_label', 'item.notes', '30%', 'left'),
        _col('hours', r'$task.hours_label', 'item.quantity', '10%', 'center'),
        _col('rate', r'$task.rate_label', 'item.cost', '15%', 'right'),
        _col(
          'line_total',
          r'$task.line_total_label',
          'item.line_total',
          '15%',
          'right',
        ),
      ],
    ),
    category: BlockCategory.data,
    essential: true,
    printed: false,
  ),
  BlockSpec(
    type: 'total',
    labelKey: 'invoice_total',
    icon: Icons.attach_money_outlined,
    defaultWidth: 6,
    defaultHeight: 6,
    defaultProperties: const {
      'items': [
        {'label': r'$subtotal_label', 'field': r'$subtotal', 'show': true},
        {'label': r'$discount_label', 'field': r'$discount', 'show': true},
        {'label': r'$taxes_label', 'field': r'$taxes', 'show': true},
        {
          'label': r'$total_label',
          'field': r'$total',
          'show': true,
          'isTotal': true,
        },
        {
          'label': r'$paid_to_date_label',
          'field': r'$paid_to_date',
          'show': true,
        },
        {
          'label': r'$balance_due_label',
          'field': r'$balance_due',
          'show': true,
          'isBalance': true,
        },
      ],
      'align': 'right',
      'labelAlign': 'right',
      'valueAlign': 'right',
      'labelColor': _defaultLabelColor,
      'amountColor': _defaultValueColor,
      'totalFontWeight': 'bold',
      'totalColor': _defaultValueColor,
      'balanceColor': _defaultValueColor,
      'spacing': '0px',
      'labelPadding': '0px',
      'valuePadding': '0px',
      'labelValueGap': '10px',
      'valueMinWidth': '',
      'showLabels': true,
    },
    category: BlockCategory.data,
    essential: true,
  ),

  // ── Layout ──────────────────────────────────────────────────────────
  BlockSpec(
    type: 'divider',
    labelKey: 'divider_line',
    icon: Icons.remove_outlined,
    defaultWidth: 12,
    defaultHeight: 1,
    defaultProperties: const {
      'thickness': '1px',
      'color': '#E5E7EB',
      'style': 'solid',
      'marginTop': '10px',
      'marginBottom': '10px',
    },
    category: BlockCategory.layout,
  ),
  BlockSpec(
    type: 'spacer',
    labelKey: 'spacer',
    icon: Icons.space_bar_outlined,
    defaultWidth: 12,
    defaultHeight: 2,
    defaultProperties: const {'height': '40px'},
    category: BlockCategory.layout,
  ),
  BlockSpec(
    type: 'qrcode',
    labelKey: 'qr_code',
    icon: Icons.qr_code_outlined,
    defaultWidth: 2,
    defaultHeight: 2,
    defaultProperties: const {
      'qrType': 'payment_link',
      'data': r'$payment_qrcode',
      'size': '100px',
      'align': 'center',
    },
    category: BlockCategory.layout,
  ),
  BlockSpec(
    type: 'signature',
    labelKey: 'invoice_signature',
    icon: Icons.draw_outlined,
    defaultWidth: 4,
    defaultHeight: 3,
    defaultProperties: const {
      'label': '',
      'showLine': true,
      'showDate': true,
      'align': 'left',
      'color': '#6B7280',
    },
    category: BlockCategory.layout,
  ),
];

// ── shared helpers (kept above the catalog list in source order) ─────────

Map<String, dynamic> _field(
  String id,
  String labelKey,
  String variable, {
  String prefix = '',
  String suffix = '',
}) => <String, dynamic>{
  'id': id,
  'label': labelKey,
  'variable': variable,
  if (prefix.isNotEmpty) 'prefix': prefix,
  if (suffix.isNotEmpty) 'suffix': suffix,
  'hideIfEmpty': true,
};

Map<String, dynamic> _col(
  String id,
  String header,
  String field,
  String width,
  String align,
) => <String, dynamic>{
  'id': id,
  'header': header,
  'field': field,
  'width': width,
  'align': align,
};

Map<String, dynamic> _infoBlockDefaults({
  required List<Map<String, dynamic>> fieldConfigs,
  required String title,
}) => <String, dynamic>{
  'fieldConfigs': fieldConfigs,
  'lineHeight': '1.3',
  'align': 'left',
  'color': _defaultValueColor,
  'showTitle': false,
  'title': title,
  'titleFontWeight': 'bold',
};

Map<String, dynamic> _tableDefaults({
  required List<Map<String, dynamic>> columns,
}) => <String, dynamic>{
  'columns': columns,
  'headerBg': '#F3F4F6',
  'headerColor': _defaultValueColor,
  'headerFontWeight': 'bold',
  'rowBg': '#FFFFFF',
  'rowColor': _defaultValueColor,
  'alternateRowBg': '#F9FAFB',
  // Phase 1.5 #2: both border regions need defaults so the server renders
  // tables with the expected styling. Two separate copies — the property
  // panel will edit each independently in Phase 2.
  'headerBorders': Map<String, dynamic>.from(_defaultTableRegionBorders)
    ..['sides'] = Map<String, dynamic>.from(
      _defaultTableRegionBorders['sides'] as Map<String, dynamic>,
    ),
  'rowBorders': Map<String, dynamic>.from(_defaultTableRegionBorders)
    ..['sides'] = Map<String, dynamic>.from(
      _defaultTableRegionBorders['sides'] as Map<String, dynamic>,
    ),
  'padding': '8px',
  'showBorders': true,
  'alternateRows': true,
};

/// Type → spec lookup index, frozen at import time. Lets [blockSpecFor]
/// run in O(1) instead of an O(N) linear scan (Phase 15a) — matters on
/// the mobile reorder list where the lookup fires per row per scroll
/// frame.
final Map<String, BlockSpec> _kBlockSpecsByType = Map.unmodifiable({
  for (final spec in kBlockLibrary) spec.type: spec,
});

/// Find a block spec by its `type` string. Returns null when the type is
/// unknown — render the fallback "Unknown block" placeholder in that case
/// so a future server-side block type doesn't crash the canvas.
BlockSpec? blockSpecFor(String type) => _kBlockSpecsByType[type];
