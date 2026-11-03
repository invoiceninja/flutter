import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/dashboard/helpers/hide_empty_panels.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';

/// Search keys for the settings sidebar search. Colocated with the section so
/// adding a field updates both ends in one place (see
/// `search_catalog_consistency_test`).
const kDashboardPanelsSearchKeys = <String>[
  'dashboard',
  'hide_empty_panels',
  'hide_empty_panels_help',
];

/// Device Settings card for the "Hide empty panels" preference
/// (invoiceninja/flutter#161): leave a dashboard panel off the dashboard while
/// it has nothing to show, instead of rendering "No upcoming quotes".
///
/// The same controller as the switch in the dashboard's Customize → Panels
/// tab; this card is the one settings search can find.
///
/// **The switch shows the effective value**, not the stored one. Stored null
/// means automatic — on for a phone, off for a tablet or a desktop — so it is
/// resolved against this window through `effectiveIn`, the same helper the
/// dashboard uses. Flipping it to what this device would pick anyway goes
/// back to automatic; only a different answer is stored as an override.
///
/// On Device Settings → Appearance, after the list switches and before the
/// two rail cards, so it doesn't split them — and above the long Sidebar
/// counters card, so on a phone, the device the default is for, it is in
/// reach.
class DashboardPanelsSection extends StatelessWidget {
  const DashboardPanelsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<Services>().hideEmptyPanels;
    return FormSection(
      title: context.tr('dashboard'),
      spacing: 0,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: InSpacing.sm),
          child: Text(
            context.tr('hide_empty_panels_help'),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.inTheme.ink3),
          ),
        ),
        ValueListenableBuilder<bool?>(
          valueListenable: controller,
          builder: (context, _, _) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.dashboard_customize_outlined),
            title: Text(context.tr('hide_empty_panels')),
            value: controller.effectiveIn(context),
            onChanged: (value) => controller.setIn(context, value),
          ),
        ),
      ],
    );
  }
}
