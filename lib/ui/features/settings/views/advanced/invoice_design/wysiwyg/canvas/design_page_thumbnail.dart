import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/models/domain/design_block_layout.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_renderers/_shared.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/canvas/block_preview.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/canvas/page_metrics.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/sample/sample_data.dart';

/// A layout drawn small: one sheet, as the canvas would draw it, with nothing
/// to interact with. The starter gallery shows these, so what a card
/// promises is what opens.
class DesignPageThumbnail extends StatelessWidget {
  const DesignPageThumbnail({
    super.key,
    required this.blocks,
    this.settings = const DocumentSettings(),
    this.sample,
  });

  final List<DesignBlock> blocks;
  final DocumentSettings settings;
  final DesignerSampleData? sample;

  static final ThemeData _paperTheme = buildInTheme(InTheme.light);

  @override
  Widget build(BuildContext context) {
    final metrics = DesignerPageMetrics.of(settings);
    final data = sample ?? DesignerSampleData.fallback;
    final rows = [
      for (final (i, row) in rowsOf(blocks).indexed)
        explicitRow(row, (_) => 'thumb-gap-$i'),
    ].where((r) => r.isNotEmpty).toList();

    return AspectRatio(
      aspectRatio: metrics.size.aspectRatio,
      child: FittedBox(
        fit: BoxFit.fitWidth,
        alignment: Alignment.topCenter,
        clipBehavior: Clip.hardEdge,
        child: ExcludeSemantics(
          child: IgnorePointer(
            child: Container(
              width: metrics.size.width,
              height: metrics.size.height,
              color: Colors.white, // paper
              padding: EdgeInsets.fromLTRB(
                metrics.insetLeft,
                metrics.insetTop,
                metrics.insetRight,
                metrics.insetBottom,
              ),
              alignment: Alignment.topLeft,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  child: SizedBox(
                    width: metrics.contentWidth,
                    child: FittedBox(
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: metrics.layoutWidth,
                        child: Theme(
                          data: _paperTheme,
                          child: MediaQuery.withNoTextScaling(
                            child: DesignerRenderScope(
                              formatter: null,
                              child: DefaultTextStyle(
                                style: TextStyle(
                                  // At this size the letters are texture;
                                  // the app's own face keeps it the same
                                  // texture on every platform.
                                  fontFamily: kSansFontFamily,
                                  fontSize: settings.globalFontSize.toDouble(),
                                  color: const Color(0xFF374151),
                                  height: 1.5,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (final row in rows)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: kDesignerRowGapPx,
                                        ),
                                        child: _row(
                                          row,
                                          metrics.layoutWidth,
                                          data,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(DesignRow cells, double width, DesignerSampleData data) {
    final children = <Widget>[];
    var x = 0.0;
    for (final slot in layoutRow(cells, width)) {
      if (slot.left > x) children.add(SizedBox(width: slot.left - x));
      x = slot.right;
      children.add(
        SizedBox(
          width: slot.width,
          child: isGapBlock(slot.block)
              ? null
              : BlockPreview(block: slot.block, sample: data),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
