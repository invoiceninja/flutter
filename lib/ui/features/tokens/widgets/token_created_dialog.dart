import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// Display of a freshly-minted API token's raw bearer secret, shown when the
/// create syncs. The local row only ever carries the masked form; after
/// dismissal the secret can be shown again from the token's edit screen
/// (`TokenSecretField`, which fetches it from `GET /tokens/{id}`).
class TokenCreatedDialog extends StatelessWidget {
  const TokenCreatedDialog({required this.secret, super.key});
  final String secret;

  static Future<void> show(BuildContext context, String secret) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => TokenCreatedDialog(secret: secret),
      );

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return AlertDialog(
      title: Text(context.tr('token_created_dialog_title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('token_created_dialog_body')),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.surfaceAlt,
              borderRadius: BorderRadius.circular(InRadii.r2),
              border: Border.all(color: tokens.border),
            ),
            child: SelectableText(
              secret,
              style: const TextStyle(fontFamily: kMonoFontFamily, fontSize: 13),
            ),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          // `label:` keeps the secret itself out of the "Copied … " toast.
          onPressed: () =>
              copyToClipboard(context, secret, label: context.tr('token')),
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          child: Text(context.tr('copy_token')),
        ),
        SizedBox(width: InSpacing.md(context)),
        PrimaryDialogAction(
          label: context.tr('done'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
