/// What a visual-designer block's `properties` must look like before the server
/// sees them. Applied by `DesignBlock.toApi()`, so a save and a preview agree.
///
/// Three things the PDF renderer does that the typed model cannot express, each
/// confirmed against the live server (`docs/invoice-designer.md`):
///
/// * every block converter reads `$block['properties']` unguarded, and the
///   spacer's reads `properties.height` the same way — a block without them is
///   an HTTP 500 for the whole document, not a blank cell;
/// * a table column's `header` and an info block's `title` are printed exactly
///   as stored. A `$…_label` token is translated; a bare localization key
///   (`unit_cost`, `bill_to`) is printed as the key.
library;

/// Default height for a spacer whose `height` was cleared.
const kDefaultSpacerHeight = '40px';

/// Block types whose `properties.columns` are table columns.
const _kTableTypes = <String>{'table', 'tasks-table'};

/// Block types whose `properties.title` is an optional heading.
const _kInfoTypes = <String>{
  'client-info',
  'company-info',
  'client-shipping-info',
};

/// The localization keys this app used to seed a product column's `header`
/// with, mapped to the label token the server translates.
const Map<String, String> kLegacyProductHeaderTokens = {
  'item': r'$product.item_label',
  'description': r'$product.description_label',
  'qty': r'$product.quantity_label',
  'unit_cost': r'$product.unit_cost_label',
  'line_total': r'$product.line_total_label',
  'net_cost': r'$product.net_cost_label',
  'gross_line_total': r'$product.gross_line_total_label',
  'discount': r'$product.discount_label',
  'tax': r'$product.tax_label',
  'custom1': r'$product.product1_label',
  'custom2': r'$product.product2_label',
};

/// As [kLegacyProductHeaderTokens], for a `tasks-table`.
const Map<String, String> kLegacyTaskHeaderTokens = {
  'service': r'$task.service_label',
  'description': r'$task.description_label',
  'hours': r'$task.hours_label',
  'rate': r'$task.rate_label',
  'line_total': r'$task.line_total_label',
  'discount': r'$task.discount_label',
  'tax': r'$task.tax_label',
};

/// As [kLegacyProductHeaderTokens], for an info block's `title`. The company
/// block was seeded with `company_details`, which has no token of its own —
/// `$from_label` is the server's heading for the sender.
const Map<String, String> kLegacyTitleTokens = {
  'bill_to': r'$bill_to_label',
  'ship_to': r'$ship_to_label',
  'company_details': r'$from_label',
};

/// The label token for a legacy column [header] of a [blockType] table, or
/// [header] itself when it is already a token or something the user typed.
String upgradeLegacyColumnHeader(String blockType, String header) {
  final map = blockType == 'tasks-table'
      ? kLegacyTaskHeaderTokens
      : kLegacyProductHeaderTokens;
  return map[header.trim()] ?? header;
}

/// The label token for a legacy info-block [title], or [title] itself.
String upgradeLegacyTitle(String title) =>
    kLegacyTitleTokens[title.trim()] ?? title;

/// [properties] as the server must receive them for a block of [type]. Returns
/// the same map when nothing needs changing.
Map<String, dynamic> wireBlockProperties(
  String type,
  Map<String, dynamic> properties,
) {
  if (type == 'spacer') {
    final height = properties['height'];
    if (height is String && height.trim().isNotEmpty) return properties;
    // A bare number is not a CSS length, but it is what was meant: `0` is a
    // gap cell, and replacing it with the default would print it 40px tall.
    if (height is num) return {...properties, 'height': '${height}px'};
    return {...properties, 'height': kDefaultSpacerHeight};
  }
  if (_kTableTypes.contains(type)) {
    final columns = properties['columns'];
    if (columns is! List) return properties;
    var changed = false;
    final next = <dynamic>[];
    for (final column in columns) {
      final header = column is Map ? column['header'] : null;
      if (column is Map && header is String) {
        final upgraded = upgradeLegacyColumnHeader(type, header);
        if (upgraded != header) {
          changed = true;
          next.add(<String, dynamic>{
            for (final e in column.entries) '${e.key}': e.value,
            'header': upgraded,
          });
          continue;
        }
      }
      next.add(column);
    }
    return changed ? {...properties, 'columns': next} : properties;
  }
  if (_kInfoTypes.contains(type)) {
    final title = properties['title'];
    if (title is! String) return properties;
    final upgraded = upgradeLegacyTitle(title);
    return upgraded == title ? properties : {...properties, 'title': upgraded};
  }
  return properties;
}
