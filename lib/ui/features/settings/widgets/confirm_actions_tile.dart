import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';

/// Settings → Device Settings → Security → Confirm actions toggle.
///
/// Device-local, on by default. When on, actions tagged
/// `EntityActionItem.confirm` (Approve, Mark Sent, Cancel, Send Now, Archive,
/// Delete, …) open an "Are you sure?" dialog first — see
/// invoiceninja/flutter#49, where users reported fat-fingering Approve and
/// Archive while working from a phone in the field.
class ConfirmActionsTile extends StatelessWidget {
  const ConfirmActionsTile({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<Services>().confirmActions;
    return ValueListenableBuilder<bool>(
      valueListenable: controller,
      builder: (context, enabled, _) => SwitchListTile(
        secondary: const Icon(Icons.help_outline),
        title: Text(context.tr('confirm_actions')),
        subtitle: Text(context.tr('confirm_actions_help')),
        value: enabled,
        onChanged: controller.set,
      ),
    );
  }
}
