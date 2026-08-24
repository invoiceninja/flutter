import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/external_url.dart';
import 'package:admin/ui/core/widgets/notify.dart';

/// Read-only computed URL row. Used by the Client Portal Settings tab to
/// surface the Login URL and by the Registration tab for the Registration
/// URL. Renders the URL as selectable text with two trailing icon buttons:
/// copy-to-clipboard and open-in-new-tab.
///
/// The URL is computed by the caller — this widget is purely presentation.
class PortalUrlDisplay extends StatelessWidget {
  const PortalUrlDisplay({super.key, required this.label, required this.url});

  /// Localized label shown above the URL (e.g. `t('login_url')`).
  final String label;

  /// Fully-formed URL — caller decides hosted-subdomain vs hosted-domain
  /// vs self-hosted shape.
  final String url;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(color: tokens.ink2),
        ),
        SizedBox(height: InSpacing.xs),
        Row(
          children: [
            Icon(Icons.link, color: tokens.ink2),
            SizedBox(width: InSpacing.md(context)),
            Expanded(
              child: SelectableText(
                url,
                style: theme.textTheme.bodyMedium?.copyWith(color: tokens.ink),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.content_copy),
              tooltip: context.tr('copy'),
              onPressed: () => _copy(context),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: context.tr('open'),
              onPressed: () => _open(context),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _copy(BuildContext context) async {
    final copiedText = context
        .tr('copied_to_clipboard')
        .replaceAll(':value', url);
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    Notify.success(context, copiedText);
  }

  Future<void> _open(BuildContext context) async {
    await openExternalUrl(context, url);
  }
}
