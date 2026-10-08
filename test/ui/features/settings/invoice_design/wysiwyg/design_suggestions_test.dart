import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/design.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/design_suggestions.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/templates.dart';

DesignBlock _block(String type, [Map<String, dynamic> properties = const {}]) =>
    DesignBlock(
      id: '$type-${properties.hashCode}',
      type: type,
      gridPosition: const GridPosition(x: 0, y: 0, w: 12, h: 2),
      properties: properties,
    );

void main() {
  List<DesignSuggestion> of(List<DesignBlock> blocks, {bool logo = true}) =>
      designSuggestions(blocks, companyHasLogo: logo);

  test('an empty page has nothing to say — it cannot be saved at all', () {
    expect(of(const []), isEmpty);
  });

  test('every starter is clean', () {
    for (final starter in buildStarterTemplates()) {
      expect(of(starter.blocks), isEmpty, reason: starter.id);
    }
  });

  test('no line items, no totals', () {
    expect(of([_block('text')]), [
      DesignSuggestion.noLineItems,
      DesignSuggestion.noTotals,
    ]);
    // Both are settled by adding the block.
    expect(DesignSuggestion.noLineItems.fixWithBlock, 'table');
    expect(DesignSuggestion.noTotals.fixWithBlock, 'total');
  });

  test('two totals blocks', () {
    expect(
      of([
        _block('table'),
        _block('total'),
        _block('total', {'a': 1}),
      ]),
      [DesignSuggestion.twoTotals],
    );
    expect(DesignSuggestion.twoTotals.fixWithBlock, isNull);
  });

  test('a logo block on a company with no logo', () {
    final page = [_block('logo'), _block('table'), _block('total')];
    expect(of(page), isEmpty);
    expect(of(page, logo: false), [DesignSuggestion.noCompanyLogo]);
  });

  test('an image block counts only when it shows the company logo', () {
    final own = [
      _block('image', {'source': 'data:image/png;base64,AAAA'}),
      _block('table'),
      _block('total'),
    ];
    expect(of(own, logo: false), isEmpty);
    final companys = [
      _block('image', {'source': r'$company.logo'}),
      _block('table'),
      _block('total'),
    ];
    expect(of(companys, logo: false), [DesignSuggestion.noCompanyLogo]);
  });
}
