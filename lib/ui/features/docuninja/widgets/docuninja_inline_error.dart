import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';

/// A compact "this could not be read" line with Retry, shown over data that
/// is still on screen: a document whose re-read failed after an action, or a
/// list whose next page (or refresh) failed. The rows above stay usable;
/// this only says they may be out of date.
class DocuNinjaInlineError extends StatelessWidget {
  const DocuNinjaInlineError({
    super.key,
    required this.offline,
    required this.onRetry,
  });

  final bool offline;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: InSpacing.sm),
        child: Row(
          children: [
            Icon(
              offline ? Icons.cloud_off_outlined : Icons.error_outline,
              size: 18,
              color: tokens.ink2,
            ),
            const SizedBox(width: InSpacing.sm),
            Expanded(
              child: Text(
                context.tr(offline ? 'offline' : 'an_error_occurred_try_again'),
                style: TextStyle(color: tokens.ink2),
              ),
            ),
            TextButton(onPressed: onRetry, child: Text(context.tr('retry'))),
          ],
        ),
      ),
    );
  }
}
