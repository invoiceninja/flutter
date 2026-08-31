import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';

/// Search keys for the settings sidebar search. Colocated with the section so
/// adding a field updates both ends in one place (see
/// `search_catalog_consistency_test`).
const kListStatusTabsSearchKeys = <String>['status_tabs', 'status_tabs_help'];

/// Device Settings card for the status tab strip above entity lists
/// (invoiceninja/flutter#98).
///
/// Its own card, immediately above Sidebar counters: the two share a
/// vocabulary — both surface the same per-entity buckets — but one is the rail
/// and one is the list, so folding them together would suggest a single
/// setting.
///
/// On by default. Note that switching it off hides the strip without clearing
/// an active tab: a list narrowed by a saved view still shows its strip, so a
/// live filter always has a control to clear it with.
class ListStatusTabsSection extends StatelessWidget {
  const ListStatusTabsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<Services>().statusTabs;
    return FormSection(
      title: context.tr('status_tabs'),
      spacing: 0,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: InSpacing.sm),
          child: Text(
            context.tr('status_tabs_help'),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.inTheme.ink3),
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: controller,
          builder: (context, enabled, _) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.tab_outlined),
            // `enabled`, not `status_tabs`: the FormSection heading already
            // says that, and repeating it reads as two controls. Noun heading +
            // action label is the house shape (see ContactsSyncSection).
            title: Text(context.tr('enabled')),
            value: enabled,
            onChanged: controller.set,
          ),
        ),
      ],
    );
  }
}
