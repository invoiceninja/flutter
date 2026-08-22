import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';

/// Phase 4a: reusable variable picker dialog. Returns the selected
/// variable token (e.g. `$client.name`) or null if the user cancels.
///
/// The catalog is curated — not exhaustive — to keep the list scannable.
/// Mirrors the most common tokens documented in
/// `wysiwyg/variables/variable_replacer.dart`.
Future<String?> showVariablePicker(
  BuildContext context, {
  Set<VariableCategory> categories = const {
    VariableCategory.client,
    VariableCategory.company,
    VariableCategory.contact,
    VariableCategory.invoice,
  },
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _VariablePickerDialog(categories: categories),
  );
}

enum VariableCategory { client, company, contact, invoice, shipping }

class _VariablePickerDialog extends StatelessWidget {
  const _VariablePickerDialog({required this.categories});

  final Set<VariableCategory> categories;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(InSpacing.lg(context)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('add_field'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: tokens.border),
            Expanded(
              child: ListView(
                children: [
                  for (final cat in categories) _CategorySection(category: cat),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.category});

  final VariableCategory category;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final variables = _kVariableCatalog[category]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            InSpacing.lg(context),
            InSpacing.md(context),
            InSpacing.lg(context),
            InSpacing.sm,
          ),
          child: Text(
            context.tr(_categoryKey(category)),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: tokens.ink3,
              letterSpacing: 1.0,
            ),
          ),
        ),
        for (final v in variables)
          ListTile(
            dense: true,
            title: Text(context.tr(v.labelKey)),
            subtitle: Text(
              v.token,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: tokens.ink3,
              ),
            ),
            onTap: () => Navigator.of(context).pop(v.token),
          ),
      ],
    );
  }

  String _categoryKey(VariableCategory c) => switch (c) {
    VariableCategory.client => 'client_details',
    VariableCategory.company => 'company_details',
    VariableCategory.contact => 'contact_details',
    VariableCategory.invoice => 'invoice_details',
    VariableCategory.shipping => 'shipping_address',
  };
}

class _VariableEntry {
  const _VariableEntry(this.labelKey, this.token);
  final String labelKey;
  final String token;
}

const Map<VariableCategory, List<_VariableEntry>> _kVariableCatalog = {
  VariableCategory.client: [
    _VariableEntry('client_name', r'$client.name'),
    _VariableEntry('client_number', r'$client.number'),
    _VariableEntry('address1', r'$client.address1'),
    _VariableEntry('address2', r'$client.address2'),
    _VariableEntry('city_state_postal', r'$client.city_state_postal'),
    _VariableEntry('country', r'$client.country'),
    _VariableEntry('phone', r'$client.phone'),
    _VariableEntry('email', r'$client.email'),
    _VariableEntry('vat_number', r'$client.vat_number'),
    _VariableEntry('id_number', r'$client.id_number'),
    _VariableEntry('custom1', r'$client.custom1'),
    _VariableEntry('custom2', r'$client.custom2'),
    _VariableEntry('custom3', r'$client.custom3'),
    _VariableEntry('custom4', r'$client.custom4'),
    _VariableEntry('tags', r'$client.tags'),
  ],
  VariableCategory.company: [
    _VariableEntry('company_name', r'$company.name'),
    _VariableEntry('address1', r'$company.address1'),
    _VariableEntry('address2', r'$company.address2'),
    _VariableEntry('city_state_postal', r'$company.city_state_postal'),
    _VariableEntry('country', r'$company.country'),
    _VariableEntry('phone', r'$company.phone'),
    _VariableEntry('email', r'$company.email'),
    _VariableEntry('website', r'$company.website'),
    _VariableEntry('vat_number', r'$company.vat_number'),
    _VariableEntry('id_number', r'$company.id_number'),
    _VariableEntry('tags', r'$company.tags'),
  ],
  VariableCategory.contact: [
    _VariableEntry('contact_full_name', r'$contact.full_name'),
    _VariableEntry('email', r'$contact.email'),
    _VariableEntry('phone', r'$contact.phone'),
    _VariableEntry('custom1', r'$contact.custom1'),
    _VariableEntry('custom2', r'$contact.custom2'),
  ],
  VariableCategory.invoice: [
    _VariableEntry('invoice_number', r'$invoice.number'),
    _VariableEntry('date', r'$invoice.date'),
    _VariableEntry('due_date', r'$invoice.due_date'),
    _VariableEntry('po_number', r'$invoice.po_number'),
    _VariableEntry('public_notes', r'$invoice.public_notes'),
    _VariableEntry('terms', r'$invoice.terms'),
    _VariableEntry('subtotal', r'$invoice.subtotal'),
    _VariableEntry('discount', r'$invoice.discount'),
    _VariableEntry('total', r'$invoice.total'),
    _VariableEntry('balance', r'$invoice.balance'),
    _VariableEntry('custom1', r'$invoice.custom1'),
    _VariableEntry('custom2', r'$invoice.custom2'),
    _VariableEntry('tags', r'$invoice.tags'),
  ],
  VariableCategory.shipping: [
    _VariableEntry('address1', r'$client.shipping_address1'),
    _VariableEntry('city_state_postal', r'$client.shipping_city_state_postal'),
    _VariableEntry('country', r'$client.shipping_country'),
  ],
};
