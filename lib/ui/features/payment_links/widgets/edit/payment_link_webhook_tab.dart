import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';
import 'package:admin/ui/features/settings/widgets/settings_text_field.dart';
import 'package:admin/ui/features/payment_links/view_models/payment_link_edit_view_model.dart';

/// Third tab — webhook URL + REST method + key/value headers list. The
/// headers editor uses a row-of-pairs pattern where the last row is an
/// always-present add slot: filling both fields and tapping Add (or
/// pressing Enter on the value field) promotes it to a permanent row.
class PaymentLinkWebhookTab extends StatelessWidget {
  const PaymentLinkWebhookTab({super.key, required this.vm});

  final PaymentLinkEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final method = vm.draft.webhookConfiguration.postPurchaseRestMethod;
    return SettingsFormShell(
      sections: [
        FormSection(
          title: context.tr('webhook'),
          children: [
            SettingsTextField(
              initialValue: vm.draft.webhookConfiguration.postPurchaseUrl,
              labelKey: 'webhook_url',
              onChanged: vm.setWebhookUrl,
              externalSyncKey: vm.original?.id,
              keyboardType: TextInputType.url,
              autocorrect: false,
            ),
            DropdownButtonFormField<String>(
              initialValue: const ['', 'post', 'put'].contains(method)
                  ? method
                  : '',
              items: [
                DropdownMenuItem(value: '', child: Text(context.tr('select'))),
                DropdownMenuItem(
                  value: 'post',
                  child: Text(context.tr('post')),
                ),
                DropdownMenuItem(value: 'put', child: Text(context.tr('put'))),
              ],
              decoration: InputDecoration(labelText: context.tr('rest_method')),
              onChanged: (v) => vm.setWebhookRestMethod(v ?? ''),
            ),
          ],
        ),
        FormSection(
          title: context.tr('headers'),
          children: [_HeadersEditor(vm: vm)],
        ),
      ],
    );
  }
}

class _HeadersEditor extends StatefulWidget {
  const _HeadersEditor({required this.vm});

  final PaymentLinkEditViewModel vm;

  @override
  State<_HeadersEditor> createState() => _HeadersEditorState();
}

class _HeadersEditorState extends State<_HeadersEditor> {
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  final FocusNode _keyFocus = FocusNode();
  final FocusNode _valueFocus = FocusNode();

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();
    _keyFocus.dispose();
    _valueFocus.dispose();
    super.dispose();
  }

  void _commitRow() {
    final key = _keyController.text.trim();
    final value = _valueController.text;
    if (key.isEmpty) return;
    widget.vm.addWebhookHeader(key, value);
    _keyController.clear();
    _valueController.clear();
    _keyFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final headers = widget.vm.draft.webhookConfiguration.postPurchaseHeaders;
    final tokens = context.inTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (headers.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: InSpacing.sm),
            child: Text(
              context.tr('no_headers'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.ink3),
            ),
          ),
        for (final entry in headers.entries)
          _HeaderRow(
            headerKey: entry.key,
            value: entry.value,
            onDelete: () => widget.vm.removeWebhookHeader(entry.key),
          ),
        SizedBox(height: InSpacing.md(context)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 4,
              child: TextField(
                controller: _keyController,
                focusNode: _keyFocus,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _valueFocus.requestFocus(),
                decoration: InputDecoration(
                  labelText: context.tr('header_key'),
                ),
              ),
            ),
            SizedBox(width: InSpacing.md(context)),
            Expanded(
              flex: 5,
              child: TextField(
                controller: _valueController,
                focusNode: _valueFocus,
                textInputAction: TextInputAction.done,
                // Intercept Enter: commit the row instead of bubbling to
                // FormSaveScope.trySubmit. Otherwise mid-add Enter fires a
                // half-state save (per CLAUDE.md § Forms § Enter to save).
                onSubmitted: (_) => _commitRow(),
                decoration: InputDecoration(
                  labelText: context.tr('header_value'),
                ),
              ),
            ),
            SizedBox(width: InSpacing.md(context)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: context.tr('add_header'),
              onPressed: _commitRow,
            ),
          ],
        ),
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.headerKey,
    required this.value,
    required this.onDelete,
  });

  final String headerKey;
  final String value;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: InSpacing.xs),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              headerKey,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: InSpacing.md(context)),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: TextStyle(color: tokens.ink2),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
