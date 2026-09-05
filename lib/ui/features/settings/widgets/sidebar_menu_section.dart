import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/domain/sidebar_menu.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/widgets/customize_menu_sheet.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/segmented_setting_row.dart';

/// Search keys for the settings sidebar search. Colocated with the section so
/// adding / renaming a field updates both ends in one place (see
/// `search_catalog_consistency_test`).
///
/// The layout option labels (`list` / `grid`) are deliberately absent: they are
/// values, not fields, and searching for a field surfaces the row that holds
/// both.
const kSidebarMenuSearchKeys = <String>[
  'menu',
  'menu_layout_help',
  'layout',
  'menu_order',
  'customize',
];

/// Device Settings card for the main menu — how the sidebar's nav block is laid
/// out, and what order its items appear in (invoiceninja/flutter#125).
///
/// Its own card immediately above Sidebar counters, on the reasoning
/// [ListStatusTabsSection] already sets out for that neighbourhood: both are
/// about the rail, but one is what the rows *are* and the other is what their
/// numbers *count*, so folding them together would read as one setting.
class SidebarMenuSection extends StatelessWidget {
  const SidebarMenuSection({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<Services>().sidebarMenu;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => FormSection(
        title: context.tr('menu'),
        spacing: 0,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: InSpacing.sm),
            child: Text(
              context.tr('menu_layout_help'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.inTheme.ink3),
            ),
          ),
          SegmentedSettingRow(
            leading: const Icon(Icons.grid_view_outlined),
            title: context.tr('layout'),
            subtitle: context.tr(_layoutLabelKey(controller.layout)),
            control: SegmentedButton<SidebarMenuLayout>(
              showSelectedIcon: false,
              segments: [
                for (final layout in SidebarMenuLayout.values)
                  ButtonSegment(
                    value: layout,
                    label: segmentLabel(context, _layoutLabelKey(layout)),
                  ),
              ],
              selected: {controller.layout},
              onSelectionChanged: (selection) =>
                  controller.setLayout(selection.first),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.reorder),
            // `menu_order`, never the bundled `order`: that key is the
            // invoicing noun and is translated as the *purchase order* in ten
            // locales (de "Bestellung", fr "Commande", nl "Bestelling", ja
            // "発注"), so this row would read as a purchase-order setting sitting
            // next to Layout. The bundle has no placeholder-free sibling that
            // means "sequence" either — `sort_order` is "Sortierreihenfolge",
            // which promises sorting rules rather than a manual arrangement —
            // so this is the third rung of CLAUDE.md's localization ladder: an
            // app-local key, English-only until Transifex carries it.
            title: Text(context.tr('menu_order')),
            trailing: TextButton(
              onPressed: () => openCustomizeMenu(context),
              child: Text(context.tr('customize')),
            ),
          ),
        ],
      ),
    );
  }
}

String _layoutLabelKey(SidebarMenuLayout layout) => switch (layout) {
  SidebarMenuLayout.list => 'list',
  SidebarMenuLayout.grid => 'grid',
};
