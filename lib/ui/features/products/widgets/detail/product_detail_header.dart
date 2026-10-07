import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/domain/date_placeholders.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_header_host.dart';
import 'package:admin/ui/core/widgets/clamped_text.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/utils/formatting.dart';

/// How much of a description the header shows before "More".
const int _kDescriptionLines = 2;

/// Per-entity wrapper over [EntityDetailHeaderHost]. `productKey` is the name
/// (falling back to `no_name_fallback`), on up to two lines — a product key
/// can be a sentence.
///
/// **The line under it is the product's description** — the same pair an
/// invoice line prints, key over description, and what tells two products
/// with similar keys apart. It used to be a "Notes" row in a card under a
/// tab. It is held to two lines with an in-place More, so a paragraph does
/// not push the page down; a reserved date keyword (`:MONTH`) is shown as the
/// date it stands for, as the list's Description column shows it
/// (invoiceninja/flutter#93). A product with no description has no line at
/// all, rather than the created / updated dates other headers fall back to:
/// those are the last two rows of the Details card a few lines down, and the
/// same two dates twice on one screen is noise.
///
/// **Tags sit under that.**
class ProductDetailHeader extends StatelessWidget {
  const ProductDetailHeader({
    super.key,
    required this.product,
    this.formatter,
    this.showStatePills = true,
  });

  final Product product;

  /// Renders a description's reserved date keywords through the company's
  /// date format. Null until it loads — the expansion then falls back to ISO
  /// dates rather than dropping out.
  final Formatter? formatter;

  /// False when the screen is already saying Deleted / Archived in a banner.
  final bool showStatePills;

  /// The description as the header prints it. Plain text as stored — a
  /// product's notes are not one of the HTML-bearing fields — with date
  /// keywords expanded and the ends trimmed.
  static String descriptionOf(Product product, Formatter? formatter) =>
      expandDatePlaceholders(product.notes, formatter: formatter).trim();

  @override
  Widget build(BuildContext context) {
    return EntityDetailHeaderHost<Product>(
      entity: product,
      entityType: EntityType.product,
      recordId: product.id,
      formatter: formatter,
      project: (context, p) {
        final description = descriptionOf(p, formatter);
        return EntityHeaderFields(
          seedForAvatar: p.id,
          displayName: p.productKey.isEmpty
              ? context.tr('no_name_fallback')
              : p.productKey,
          createdAt: p.createdAt,
          updatedAt: p.updatedAt,
          isDeleted: p.isDeleted,
          isArchived: p.archivedAt != null,
          isDirty: p.isDirty,
          nameMaxLines: 2,
          showStatePills: showStatePills,
          subtitle: description.isEmpty
              // Nothing, rather than the created / updated dates other
              // headers fall back to — see the class doc.
              ? const SizedBox.shrink()
              : ClampedText(
                  text: description,
                  maxLines: _kDescriptionLines,
                  // `ink2`, like every header subtitle: this line carries
                  // real information, and `ink3` at this size is under the
                  // contrast floor.
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.inTheme.ink2),
                ),
          tags: p.tagIds.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: EntityTagsView(
                    entityType: 'product',
                    tagIds: p.tagIds,
                  ),
                ),
        );
      },
    );
  }
}
