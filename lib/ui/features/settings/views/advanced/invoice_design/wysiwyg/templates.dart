import 'package:admin/data/models/domain/design.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_library.dart';

/// The layouts a new visual design can start from, shown as thumbnails by
/// the starter gallery.
///
/// A starter is told apart by its picture, so each one has to *look*
/// different: three of the four used to be the same unstyled blocks in a
/// slightly different order, which made a gallery of them a choice between
/// near-identical pages. Where a starter sets a style it sets it on the
/// blocks themselves — there is nothing to a starter beyond the blocks it
/// drops, so the user restyles it like anything else.
///
/// Pure data: no DB, no network. Rebuilt per call so every pick gets blocks
/// with new ids.

class DesignTemplateStarter {
  const DesignTemplateStarter({
    required this.id,
    required this.nameKey,
    required this.descriptionKey,
    required this.category,
    required this.blocks,
  });

  final String id;
  final String nameKey;
  final String descriptionKey;

  /// Category for the gallery filter chips. Mirrors React's
  /// `modern` / `classic` / `minimal` / `creative` values.
  final String category;
  final List<DesignBlock> blocks;
}

/// A block of [type] at a grid position, with the library's defaults and
/// then [style] over them.
DesignBlock _b(
  String type,
  int x,
  int y, {
  int? w,
  int? h,
  Map<String, dynamic> style = const {},
}) {
  final spec = blockSpecFor(type);
  if (spec == null) {
    throw ArgumentError('Unknown block type "$type" in starter template');
  }
  final block = spec.newInstance(idPrefix: spec.type, x: x, y: y);
  return block.copyWith(
    gridPosition: GridPosition(
      x: x,
      y: y,
      w: w ?? spec.defaultWidth,
      h: h ?? spec.defaultHeight,
    ),
    properties: {...block.properties, ...style},
  );
}

/// The colour the Bold starter is drawn in when the company has not chosen
/// one.
const String kStarterInk = '#111827';

/// The starters, built fresh. [accent] is the company's own colour (a hex
/// string), used where a starter has a coloured rule or table header.
List<DesignTemplateStarter> buildStarterTemplates({String? accent}) => [
  DesignTemplateStarter(
    id: 'standard',
    nameKey: 'starter_standard',
    descriptionKey: 'starter_standard_hint',
    category: 'classic',
    blocks: _standardLayout(),
  ),
  DesignTemplateStarter(
    id: 'bold',
    nameKey: 'starter_bold',
    descriptionKey: 'starter_bold_hint',
    category: 'modern',
    blocks: _boldLayout(_hexOr(accent, kStarterInk)),
  ),
  DesignTemplateStarter(
    id: 'minimal',
    nameKey: 'starter_minimal',
    descriptionKey: 'starter_minimal_hint',
    category: 'minimal',
    blocks: _minimalLayout(),
  ),
  DesignTemplateStarter(
    id: 'quote_friendly',
    nameKey: 'starter_quote_friendly',
    descriptionKey: 'starter_quote_friendly_hint',
    category: 'modern',
    blocks: _quoteFriendlyLayout(),
  ),
];

String _hexOr(String? value, String fallback) {
  final v = (value ?? '').trim();
  return RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(v) ? v.toUpperCase() : fallback;
}

/// Classic two-column header: logo + invoice details up top, client info
/// + ship-to side by side, products table, then totals on the right.
List<DesignBlock> _standardLayout() => [
  _b('logo', 0, 0, w: 4, h: 4),
  _b('invoice-details', 6, 0, w: 6, h: 4),
  _b('client-info', 0, 4, w: 6, h: 4),
  _b('client-shipping-info', 6, 4, w: 6, h: 4),
  _b('table', 0, 8, w: 12, h: 8),
  _b('total', 6, 16, w: 6, h: 6),
  _b('public-notes', 0, 22, w: 12, h: 3),
  _b('footer', 0, 25, w: 12, h: 2),
];

/// A large document title over a coloured rule, the company's details beside
/// its logo, and a table header in the same colour. After React's "Modern
/// Professional".
List<DesignBlock> _boldLayout(String accent) => [
  _b('logo', 0, 0, w: 5, h: 3),
  _b('company-info', 7, 0, w: 5, h: 3, style: const {'align': 'right'}),
  _b(
    'text',
    0,
    3,
    w: 12,
    h: 2,
    style: const {
      'content': r'$entity_label',
      'fontSize': '32px',
      'fontWeight': 'bold',
      'color': kStarterInk,
    },
  ),
  _b(
    'divider',
    0,
    5,
    style: {
      'thickness': '2px',
      'color': accent,
      'marginTop': '0px',
      'marginBottom': '6px',
    },
  ),
  _b('client-info', 0, 6, w: 6, h: 4),
  _b('invoice-details', 6, 6, w: 6, h: 4),
  _b(
    'table',
    0,
    10,
    w: 12,
    h: 8,
    style: {
      'headerBg': accent,
      'headerColor': '#FFFFFF',
      'alternateRows': false,
    },
  ),
  _b('public-notes', 0, 18, w: 6, h: 4),
  _b('total', 6, 18, w: 6, h: 6),
  _b('footer', 0, 24, w: 12, h: 2),
];

/// Minimal — a single column, no shipping address, and a table with no
/// shading: a white header and plain rows.
List<DesignBlock> _minimalLayout() => [
  _b('logo', 0, 0, w: 3, h: 3),
  _b('invoice-details', 8, 0, w: 4, h: 3),
  _b('client-info', 0, 3, w: 12, h: 4),
  _b(
    'table',
    0,
    7,
    w: 12,
    h: 8,
    style: const {'headerBg': '#FFFFFF', 'alternateRows': false},
  ),
  _b('total', 6, 15, w: 6, h: 6),
  _b('footer', 0, 21, w: 12, h: 2),
];

/// Quote-friendly — emphasizes terms + public notes alongside the totals.
List<DesignBlock> _quoteFriendlyLayout() => [
  _b('logo', 0, 0, w: 4, h: 3),
  _b('company-info', 8, 0, w: 4, h: 3),
  _b('client-info', 0, 3, w: 6, h: 4),
  _b('invoice-details', 6, 3, w: 6, h: 4),
  _b('table', 0, 7, w: 12, h: 8),
  _b('public-notes', 0, 15, w: 6, h: 4),
  _b('total', 6, 15, w: 6, h: 4),
  _b('terms', 0, 19, w: 12, h: 3),
  _b('signature', 0, 22, w: 4, h: 3),
  _b('footer', 0, 25, w: 12, h: 2),
];
