import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';

import 'package:admin/ui/features/settings/views/advanced/custom_fields/custom_fields_shell.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

const kCustomFieldsExpensesSearchKeys = <String>[
  'expense_field',
  'label',
  'field_type',
  'single_line_text',
  'multi_line_text',
  'switch',
  'date',
  'dropdown',
];

class CustomFieldsExpensesScreen extends StatelessWidget {
  const CustomFieldsExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) => SettingsFormShell(
    sections: [
      CustomFieldSlotsSection(
        prefix: 'expense',
        title: context.tr('expense_field'),
      ),
    ],
  );
}
