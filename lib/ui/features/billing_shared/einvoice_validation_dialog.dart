import 'package:flutter/material.dart';

import 'package:admin/data/services/invoices_api.dart';
import 'package:admin/l10n/localization.dart';

/// Shows an e-invoice pre-flight result (`einvoice/validateEntity`): "passed",
/// or the server's issues as a bulleted list. Shared by the invoice and credit
/// Validate actions.
Future<void> showEInvoiceValidationDialog(
  BuildContext context,
  EInvoiceValidation result,
) => showDialog<void>(
  context: context,
  builder: (d) {
    final flat = result.messages.where((s) => s.isNotEmpty).toList();
    final ok = result.passes && flat.isEmpty;
    return AlertDialog(
      title: Text(d.tr('validate')),
      content: ok
          ? Text(d.tr('validation_passed'))
          : SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final m in flat)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('• $m'),
                      ),
                  ],
                ),
              ),
            ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          onPressed: () => Navigator.of(d).pop(),
          child: Text(d.tr('close')),
        ),
      ],
    );
  },
);
