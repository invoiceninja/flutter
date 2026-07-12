import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';

/// Modal picker for the Run Template action. Lets the user pick a design
/// template; on Save returns the chosen `design.id` to the caller, which
/// enqueues `MutationKind.runTemplate` against the server.
///
/// Templates today are sourced from the company's `designs` bundle — same
/// list the Invoice Design picker uses. Email templates (reminder1/2/3,
/// endless, custom1..3) are kept distinct on the server and land in a
/// follow-up alongside the bulk-email run-template variant.
Future<String?> showRunTemplateDialog(BuildContext context) async {
  final services = context.read<Services>();
  final companyId = services.auth.session.value!.currentCompanyId;
  final allDesigns = await services.designs
      .watchAll(companyId: companyId)
      .first;
  final designs = allDesigns.where((d) => d.isTemplate).toList();
  if (!context.mounted) return null;
  return showDialog<String>(
    context: context,
    builder: (_) => _RunTemplateDialog(designs: designs),
  );
}

class _RunTemplateDialog extends StatefulWidget {
  const _RunTemplateDialog({required this.designs});

  final List<Design> designs;

  @override
  State<_RunTemplateDialog> createState() => _RunTemplateDialogState();
}

class _RunTemplateDialogState extends State<_RunTemplateDialog> {
  Design? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('run_template')),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SearchableDropdownField<Design>(
              label: context.tr('template'),
              items: widget.designs,
              initialValue: _selected,
              displayString: (d) => d.name,
              idOf: (d) => d.id,
              onChanged: (d) => setState(() => _selected = d),
            ),
          ],
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('cancel')),
            ),
            const SizedBox(width: 8),
            PrimaryDialogAction(
              label: context.tr('run'),
              onPressed: () => Navigator.of(context).pop(_selected!.id),
              enabled: _selected != null,
              // Disabled until a template is picked + dropdown eats Enter —
              // so no Enter hint.
              autofocus: false,
              showEnterHint: false,
            ),
          ],
        ),
      ],
    );
  }
}
