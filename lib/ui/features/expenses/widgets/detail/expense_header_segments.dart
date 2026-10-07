import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/link_text.dart';
import 'package:admin/ui/features/expenses/widgets/detail/expense_linked_names.dart';

/// One entry in the line under an expense's number: a small icon, then a
/// name or a date.
///
/// **The icon is the label.** A client's subtitle is one kind of thing after
/// another (a place, a number) and needs none; an expense's names two
/// companies in a row — who was paid and who it is for — and "Staples, Acme"
/// does not say which is which. The icons are the ones the sidebar uses for
/// the same records, and the tooltip spells the word out.
///
/// With [onTap] the name is a link to that record's own screen; without it,
/// plain text.
class ExpenseHeaderSegment extends StatelessWidget {
  const ExpenseHeaderSegment({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final String label;

  /// What the icon stands for — "Vendor", "Client", "Category".
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Decorative: the tooltip and the text carry the meaning.
          ExcludeSemantics(
            child: Icon(icon, size: 14, color: context.inTheme.ink3),
          ),
          const SizedBox(width: InSpacing.xs),
          Flexible(
            child: linkOrText(
              context: context,
              link: onTap != null,
              label: label,
              onTap: onTap,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// The line under an expense's number: its [ExpenseHeaderSegment]s side by
/// side, wrapping between them on a narrow pane.
///
/// **No separator between entries** — unlike `DetailSubtitle`, which joins
/// plain-text segments with a middle dot. Here each entry opens with its own
/// icon, which already says where one ends and the next begins; and a dot is
/// a separate child of the `Wrap`, so on a 480 px pane the line broke after
/// one and left it hanging at the end of the first row.
///
/// Drawn in `ink2`, like every header subtitle: it carries real information,
/// and `ink3` at this size is under the contrast floor.
class ExpenseHeaderSubtitle extends StatelessWidget {
  const ExpenseHeaderSubtitle({super.key, required this.segments});

  /// Empty builds nothing; the caller decides what to show instead.
  final List<Widget> segments;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return const SizedBox.shrink();
    return DefaultTextStyle.merge(
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: context.inTheme.ink2),
      child: Wrap(
        spacing: InSpacing.md(context) + InSpacing.xs,
        runSpacing: 2,
        children: segments,
      ),
    );
  }
}

/// Who was paid, who it is for and what kind of spending it is — the entries
/// an expense and a recurring expense share, in that order.
///
/// An entry exists only for a link whose name has resolved ([names]); an
/// unresolved one is left out rather than drawn as an icon beside a dash.
///
/// Each name opens **the record's own screen**, never an edit form, and only
/// for a user who may open it: the vendor needs its module and
/// `view_vendor`, the client `view_client`. A name the user may not follow is
/// still shown — the expense lists print it too — as plain text.
List<Widget> expensePartySegments(
  BuildContext context, {
  required ExpenseLinkedNames names,
  required String vendorId,
  required String clientId,
  required String categoryId,
}) {
  final services = context.read<Services>();
  final me = services.auth.session.value?.currentCompany;
  IconData iconOf(EntityType type, IconData fallback) =>
      services.entityRegistry[type]?.icon ?? fallback;
  final canOpenVendor =
      (me?.moduleEnabled(EntityType.vendor) ?? false) &&
      (me?.can('view_vendor') ?? false);
  final canOpenClient = me?.can('view_client') ?? false;
  // The category screen lives under Settings and asks for nothing more than
  // the expense itself does.
  final canOpenCategory = me?.can('view_expense') ?? false;
  return [
    if (names.vendor.isNotEmpty)
      ExpenseHeaderSegment(
        icon: iconOf(EntityType.vendor, Icons.storefront_outlined),
        label: names.vendor,
        tooltip: context.tr('vendor'),
        onTap: canOpenVendor
            ? () => goEntityFullDetail(context, '/vendors', vendorId)
            : null,
      ),
    if (names.client.isNotEmpty)
      ExpenseHeaderSegment(
        icon: iconOf(EntityType.client, Icons.person_outline),
        label: names.client,
        tooltip: context.tr('client'),
        onTap: canOpenClient
            ? () => goEntityFullDetail(context, '/clients', clientId)
            : null,
      ),
    if (names.category.isNotEmpty)
      ExpenseHeaderSegment(
        icon: Icons.label_outline,
        label: names.category,
        tooltip: context.tr('category'),
        onTap: canOpenCategory
            ? () => goEntityFullDetail(
                context,
                '/settings/expense_categories',
                categoryId,
              )
            : null,
      ),
  ];
}
