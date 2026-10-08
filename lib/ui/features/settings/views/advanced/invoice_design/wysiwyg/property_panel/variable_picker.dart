import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_renderers/_shared.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/sample/sample_data.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/variables/variable_replacer.dart';
import 'package:admin/utils/formatting.dart';

/// A field the user picked: its `$token`, and the name it was listed under.
class VariablePick {
  const VariablePick({
    required this.token,
    required this.labelKey,
    required this.label,
  });

  final String token;

  /// Localization key of the field's name — stored as an info row's label.
  final String labelKey;

  /// The name as shown (a company's own custom-field name when it has one).
  final String label;
}

enum VariableCategory { client, company, contact, invoice, shipping }

/// Pick a document field to insert — a searchable list, grouped, each row
/// showing the field's name, an example of what it prints and its `$token`.
///
/// [customFieldLabels] are the names the company gave its custom fields, by
/// slot (`client1`, `invoice2`…); a slot with a name is listed under it, and
/// one without is left out rather than offered as "First Custom".
///
/// A dialog on a wide window, a sheet on a narrow one — both routes, so
/// Android's back closes either. Returns null when dismissed.
Future<VariablePick?> showVariablePicker(
  BuildContext context, {
  Set<VariableCategory> categories = const {
    VariableCategory.client,
    VariableCategory.company,
    VariableCategory.contact,
    VariableCategory.invoice,
  },
  Map<String, String> customFieldLabels = const {},
}) {
  final body = _VariablePickerBody(
    categories: categories,
    customFieldLabels: customFieldLabels,
    // Read here: the picker is a route, outside the designer's scope.
    sample: DesignerRenderScope.sampleOf(context),
    formatter: DesignerRenderScope.formatterOf(context),
  );
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<VariablePick>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 600),
          child: body,
        ),
      ),
    );
  }
  return showModalBottomSheet<VariablePick>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final insets = MediaQuery.viewInsetsOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: insets),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: (MediaQuery.sizeOf(ctx).height - insets) * 0.85,
          ),
          child: body,
        ),
      );
    },
  );
}

class _VariablePickerBody extends StatefulWidget {
  const _VariablePickerBody({
    required this.categories,
    required this.customFieldLabels,
    required this.sample,
    required this.formatter,
  });

  final Set<VariableCategory> categories;
  final Map<String, String> customFieldLabels;

  /// The document on the page: each field's example is its value there.
  final DesignerSampleData sample;
  final Formatter? formatter;

  @override
  State<_VariablePickerBody> createState() => _VariablePickerBodyState();
}

class _VariablePickerBodyState extends State<_VariablePickerBody> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final needle = _query.text.trim().toLowerCase();
    final sections = <Widget>[];
    for (final category in widget.categories) {
      final rows = <Widget>[];
      for (final entry in _kVariableCatalog[category]!) {
        String label;
        final slot = entry.customSlot;
        if (slot != null) {
          // A custom field is offered under the name the company gave it,
          // and not at all when the slot is unused.
          label = widget.customFieldLabels[slot]?.trim() ?? '';
          if (label.isEmpty) continue;
        } else {
          label = context.tr(entry.labelKey);
        }
        final example = replaceVariables(
          entry.token,
          data: widget.sample,
          formatter: widget.formatter,
        );
        if (needle.isNotEmpty &&
            !label.toLowerCase().contains(needle) &&
            !entry.token.toLowerCase().contains(needle) &&
            !example.toLowerCase().contains(needle)) {
          continue;
        }
        rows.add(
          ListTile(
            dense: true,
            title: Text(label),
            subtitle: Text(
              // The example, when the sample document has one.
              example == entry.token || example.isEmpty
                  ? entry.token
                  : '$example  ·  ${entry.token}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: tokens.ink3),
            ),
            onTap: () => Navigator.of(context).pop(
              VariablePick(
                token: entry.token,
                labelKey: entry.labelKey,
                label: label,
              ),
            ),
          ),
        );
      }
      if (rows.isEmpty) continue;
      sections
        ..add(
          Padding(
            padding: EdgeInsets.fromLTRB(
              InSpacing.lg(context),
              InSpacing.md(context),
              InSpacing.lg(context),
              InSpacing.xs,
            ),
            child: Text(
              context.tr(_categoryKey(category)).toUpperCase(),
              style: TextStyle(
                fontSize: 10.5,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w600,
                color: tokens.ink3,
              ),
            ),
          ),
        )
        ..addAll(rows);
    }

    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              InSpacing.lg(context),
              InSpacing.lg(context),
              InSpacing.lg(context),
              InSpacing.sm,
            ),
            child: TextField(
              controller: _query,
              autofocus: true,
              autocorrect: false,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText: context.tr('search_fields'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Flexible(
            child: sections.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(InSpacing.lg(context)),
                    child: Text(
                      context.tr('no_results'),
                      style: TextStyle(color: tokens.ink3),
                    ),
                  )
                : ListView(shrinkWrap: true, children: sections),
          ),
        ],
      ),
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
  const _VariableEntry(this.labelKey, this.token, {this.customSlot});

  final String labelKey;
  final String token;

  /// For a custom field: its slot in the company's custom-field settings.
  final String? customSlot;
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
    _VariableEntry('custom1', r'$client.custom1', customSlot: 'client1'),
    _VariableEntry('custom2', r'$client.custom2', customSlot: 'client2'),
    _VariableEntry('custom3', r'$client.custom3', customSlot: 'client3'),
    _VariableEntry('custom4', r'$client.custom4', customSlot: 'client4'),
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
    _VariableEntry('custom1', r'$contact.custom1', customSlot: 'contact1'),
    _VariableEntry('custom2', r'$contact.custom2', customSlot: 'contact2'),
  ],
  VariableCategory.invoice: [
    _VariableEntry('invoice_number', r'$invoice.number'),
    _VariableEntry('date', r'$invoice.date'),
    _VariableEntry('due_date', r'$invoice.due_date'),
    _VariableEntry('po_number', r'$invoice.po_number'),
    _VariableEntry('public_notes', r'$invoice.public_notes'),
    _VariableEntry('terms', r'$terms'),
    _VariableEntry('subtotal', r'$invoice.subtotal'),
    _VariableEntry('discount', r'$invoice.discount'),
    _VariableEntry('total', r'$invoice.total'),
    _VariableEntry('balance', r'$invoice.balance'),
    _VariableEntry('custom1', r'$invoice.custom1', customSlot: 'invoice1'),
    _VariableEntry('custom2', r'$invoice.custom2', customSlot: 'invoice2'),
    _VariableEntry('custom3', r'$invoice.custom3', customSlot: 'invoice3'),
    _VariableEntry('custom4', r'$invoice.custom4', customSlot: 'invoice4'),
    _VariableEntry('tags', r'$invoice.tags'),
  ],
  VariableCategory.shipping: [
    _VariableEntry('address1', r'$client.shipping_address1'),
    _VariableEntry('city_state_postal', r'$client.shipping_city_state_postal'),
    _VariableEntry('country', r'$client.shipping_country'),
  ],
};
