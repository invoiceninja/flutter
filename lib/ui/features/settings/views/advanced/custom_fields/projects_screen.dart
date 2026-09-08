import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';

import 'package:admin/ui/features/settings/views/advanced/custom_fields/custom_fields_shell.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

const kCustomFieldsProjectsSearchKeys = <String>[
  'project_field',
  'label',
  'field_type',
  'single_line_text',
  'multi_line_text',
  'switch',
  'date',
  'dropdown',
];

class CustomFieldsProjectsScreen extends StatelessWidget {
  const CustomFieldsProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) => SettingsFormShell(
    sections: [
      CustomFieldSlotsSection(
        prefix: 'project',
        title: context.tr('project_field'),
      ),
    ],
  );
}
