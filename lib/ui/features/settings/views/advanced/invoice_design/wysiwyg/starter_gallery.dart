import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/canvas/design_page_thumbnail.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/sample/sample_data.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/templates.dart';

/// Pick a layout to start from: an empty page, or one of the starters, each
/// shown as the page it makes. Returns its blocks (empty for Blank), or null
/// when dismissed.
///
/// A new visual design used to open on the first starter with no choice, and
/// the other two were unreachable code. [accent] is the company's colour,
/// for the starters that have a coloured rule or table header.
Future<List<DesignBlock>?> showStarterGallery(
  BuildContext context, {
  DesignerSampleData? sample,
  String? accent,
  String titleKey = 'choose_a_layout',
}) {
  return showDialog<List<DesignBlock>>(
    context: context,
    builder: (dialogContext) {
      final starters = buildStarterTemplates(accent: accent);
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(InSpacing.lg(dialogContext)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        dialogContext.tr(titleKey),
                        style: Theme.of(dialogContext).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: dialogContext.tr('close'),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
                SizedBox(height: InSpacing.sm),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cards = [
                      _StarterCard(
                        name: context.tr('blank'),
                        hint: context.tr('starter_blank_hint'),
                        blocks: const [],
                        sample: sample,
                      ),
                      for (final starter in starters)
                        _StarterCard(
                          name: context.tr(starter.nameKey),
                          hint: context.tr(starter.descriptionKey),
                          blocks: starter.blocks,
                          sample: sample,
                        ),
                    ];
                    final gap = InSpacing.lg(context);
                    final columns = starterGalleryColumns(
                      constraints.maxWidth,
                      cards.length,
                      gap: gap,
                    );
                    final width =
                        (constraints.maxWidth - gap * (columns - 1)) / columns;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final card in cards)
                          // `floorToDouble`: a card a hair too wide wraps.
                          SizedBox(width: width.floorToDouble(), child: card),
                      ],
                    );
                  },
                ),
                SizedBox(height: InSpacing.lg(dialogContext)),
                Text(
                  dialogContext.tr('starters_note'),
                  style: TextStyle(
                    fontSize: 12,
                    color: dialogContext.inTheme.ink3,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// How many cards across: as many as fit at [minCard] wide, at least two,
/// and never a count that leaves one card alone on the last line — five
/// cards in a space for four go three and two.
int starterGalleryColumns(
  double width,
  int count, {
  double gap = 16,
  double minCard = 150,
}) {
  var columns = ((width + gap) / (minCard + gap)).floor().clamp(2, count);
  if (columns > 2 && columns < count && count % columns == 1) columns -= 1;
  return columns;
}

class _StarterCard extends StatelessWidget {
  const _StarterCard({
    required this.name,
    required this.hint,
    required this.blocks,
    required this.sample,
  });

  final String name;
  final String hint;
  final List<DesignBlock> blocks;
  final DesignerSampleData? sample;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    void pick() => Navigator.of(context).pop(blocks);
    return Semantics(
      button: true,
      label: '$name. $hint',
      // The thumbnail and the two lines of text are one thing to a screen
      // reader; excluding them takes the ink well's action too, so it is
      // declared again here.
      excludeSemantics: true,
      onTap: pick,
      child: Material(
        color: tokens.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: tokens.border),
          borderRadius: BorderRadius.circular(InRadii.r2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: pick,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: tokens.bg,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: tokens.border, width: 0.5),
                    ),
                    child: DesignPageThumbnail(blocks: blocks, sample: sample),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Room for three lines whatever the hint's length, so a
                    // row of cards ends level.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            MediaQuery.textScalerOf(context).scale(11.5) *
                            1.4 *
                            3,
                      ),
                      child: Text(
                        hint,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: tokens.ink3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
