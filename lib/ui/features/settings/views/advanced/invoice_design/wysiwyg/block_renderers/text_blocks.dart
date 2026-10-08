import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/design.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_renderers/_shared.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/sample/sample_data.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/variables/variable_replacer.dart';

/// Shared formatted-text renderer for the four text-bearing block types:
/// `text`, `public-notes`, `terms`, `footer`. Mirrors the visual choices
/// in React `BlockRenderer.tsx` — variable substitution through the
/// sample data, font styling from `fontSize` / `fontWeight` / `color` /
/// `fontStyle` / `lineHeight`, alignment from `align`, padding from
/// `padding` (single CSS-px string applied symmetrically).
class FormattedTextBlock extends StatelessWidget {
  const FormattedTextBlock({
    super.key,
    required this.block,
    required this.sample,
    this.defaultContent,
  });

  final DesignBlock block;
  final DesignerSampleData sample;

  /// Fallback content for blocks like `footer` / `terms` that have a
  /// default token (e.g. `$footer`); the text-block default is empty.
  final String? defaultContent;

  @override
  Widget build(BuildContext context) {
    final props = block.properties;
    final rawContent = (props['content'] as String?)?.trim();
    final source = (rawContent == null || rawContent.isEmpty)
        ? (defaultContent ?? '')
        : rawContent;
    final resolved = replaceVariables(
      source,
      data: sample,
      formatter: DesignerRenderScope.formatterOf(context),
    );

    final padding = parsePx(props['padding']) ?? 0.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      child: Text(
        resolved,
        textAlign: parseTextAlign(props['align'] as String?),
        style: TextStyle(
          fontSize: parsePx(props['fontSize']) ?? inheritedFontSize(context),
          fontWeight: parseFontWeight(props['fontWeight'] as String?),
          fontStyle: parseFontStyle(props['fontStyle'] as String?),
          color: parseCssColor(props['color'] as String?),
          height:
              parsePx(props['lineHeight']) ??
              double.tryParse((props['lineHeight'] as String?) ?? '') ??
              1.3,
        ),
      ),
    );
  }
}
