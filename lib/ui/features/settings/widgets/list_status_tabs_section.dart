import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';

/// Search keys for the settings sidebar search. Colocated with the section so
/// adding a field updates both ends in one place (see
/// `search_catalog_consistency_test`).
const kListStatusTabsSearchKeys = <String>['status_tabs', 'status_tabs_help'];

/// Device Settings switch for the status tab strip above entity lists
/// (invoiceninja/flutter#98) — the first row of Device Settings → Appearance →
/// Lists, beside the other switches about what a list shows.
///
/// A row, not a card of its own any more, and still not folded into Sidebar
/// counters: the two share a vocabulary — both surface the same per-entity
/// buckets — but one is the rail and one is the list, so one control would
/// suggest a single setting.
///
/// On by default. Note that switching it off hides the strip without clearing
/// an active tab: a list narrowed by a saved view still shows its strip, so a
/// live filter always has a control to clear it with.
class ListStatusTabsTile extends StatelessWidget {
  const ListStatusTabsTile({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<Services>().statusTabs;
    return ValueListenableBuilder<bool>(
      valueListenable: controller,
      builder: (context, enabled, _) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(Icons.tab_outlined),
        title: Text(context.tr('status_tabs')),
        subtitle: Text(context.tr('status_tabs_help')),
        value: enabled,
        onChanged: controller.set,
      ),
    );
  }
}
