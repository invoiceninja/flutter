import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/domain/email_candidates.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/external_url.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/utils/email_address.dart';

/// The `mailto:` URI for a stored email address, or null when the string is
/// not exactly one address.
///
/// Callers use the null to decide whether to draw a mail affordance at all —
/// see [cleanEmailAddress] for why this is strict rather than forgiving.
///
/// Like `telUri`, deliberately **not** routed through `openExternalUrl` /
/// `isSafeWebUrl`, which rejects `mailto:` by design: that predicate guards a
/// *server-supplied* URL, where here the scheme is a compile-time constant and
/// the path has been reduced to one address. `Uri(scheme:, path:)` does the
/// encoding itself.
Uri? mailtoUri(String email) {
  final address = cleanEmailAddress(email);
  return address.isEmpty ? null : _mailto(address);
}

/// [address] must already be clean. `&` is the one character the check lets
/// through that a `mailto:` gives a meaning to — the separator between
/// headers — so it goes out encoded: `r&d@acme.com` is `mailto:r%26d@…`,
/// which every client reads back as the address and none as a header.
Uri _mailto(String address) =>
    Uri(scheme: 'mailto', path: address.replaceAll('&', '%26'));

/// Opens the device's mail app on a new message to [email].
///
/// **Falls back to copying the address** when nothing takes the launch — a
/// desktop with no mail client set, most commonly. Writing to someone is the
/// user's goal; with no handler the next best thing is the address on the
/// clipboard, ready for the webmail tab they were going to open anyway, and a
/// "couldn't open the link" toast would be a dead end.
///
/// **On web there is no "nothing took it" to fall back from.** The browser
/// launcher opens the link and reports success whatever happens next
/// (`url_launcher_web` cannot see whether a handler exists), so a web user
/// with no mail handler — most of them, on webmail — got nothing at all. There
/// the address is copied *as well as* launched, and the toast says so.
Future<void> composeEmail(BuildContext context, String email) async {
  final address = cleanEmailAddress(email);
  if (address.isEmpty) return;
  // Captured before the await: the widget may be gone when the launcher
  // answers, and the captured path has no blank-message fallback, so the
  // string has to be `tr()`-derived — it is.
  final toasts = Notify.capture(context);
  final copied = context.tr('copied_to_clipboard', {
    'value': ellipsizeForToast(address),
  });
  final uri = _mailto(address);
  if (kIsWeb) {
    // Copy first: a browser only allows a clipboard write while the click
    // that asked for it is still being handled.
    await Clipboard.setData(ClipboardData(text: address));
    toasts?.success(copied);
    await launchExternalUri(uri);
    return;
  }
  if (await launchExternalUri(uri)) return;
  await Clipboard.setData(ClipboardData(text: address));
  toasts?.success(copied);
}

/// Writes to one of [candidates]: the only one outright, or the one the user
/// picks when there are several.
///
/// The email twin of `pickAndCallPhone`, and a picker for the same reason —
/// "email this client" has no single right answer on a client with three
/// contacts, and guessing the primary would quietly send the wrong person.
Future<void> pickAndComposeEmail(
  BuildContext context, {
  required List<EmailCandidate> candidates,
  required String partyName,
}) async {
  if (candidates.isEmpty) return;
  var picked = candidates.first;
  if (candidates.length > 1) {
    final chosen = await _showEmailCandidatePicker(
      context,
      candidates: candidates,
      partyName: partyName,
    );
    if (chosen == null) return;
    picked = chosen;
  }
  // The caller's context, never the picker's — see `pickAndCallPhone`.
  if (!context.mounted) return;
  await composeEmail(context, picked.email);
}

/// A bottom sheet on touch, a centred dialog with a pointer — the split the
/// phone picker makes, for the same reason: a sheet on the master-detail
/// pane's own navigator would be a slab pinned under a ~500 px column.
Future<EmailCandidate?> _showEmailCandidatePicker(
  BuildContext context, {
  required List<EmailCandidate> candidates,
  required String partyName,
}) {
  final email = context.tr('email');
  final title = partyName.isEmpty ? email : '$email · $partyName';
  Widget body(BuildContext ctx) =>
      _EmailPickerBody(title: title, candidates: candidates);
  if (Env.isTouchPrimary) {
    return showModalBottomSheet<EmailCandidate>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            InSpacing.lg(ctx),
            InSpacing.sm,
            InSpacing.lg(ctx),
            InSpacing.lg(ctx),
          ),
          child: body(ctx),
        ),
      ),
    );
  }
  return showDialog<EmailCandidate>(
    context: context,
    builder: (ctx) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: EdgeInsets.all(InSpacing.lg(ctx)),
          child: body(ctx),
        ),
      ),
    ),
  );
}

class _EmailPickerBody extends StatelessWidget {
  const _EmailPickerBody({required this.title, required this.candidates});

  final String title;
  final List<EmailCandidate> candidates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: InSpacing.sm),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: tokens.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final c in candidates)
                  InkWell(
                    onTap: () => Navigator.of(context).pop(c),
                    borderRadius: BorderRadius.circular(InRadii.r1),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: InSizes.touchTarget,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: InSpacing.sm,
                          vertical: InSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (c.label.isNotEmpty)
                                    Text(
                                      c.label,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: tokens.ink,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  Text(
                                    c.email,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: c.label.isEmpty
                                          ? tokens.ink
                                          : tokens.ink2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (c.isPrimary)
                              Tooltip(
                                message: context.tr('primary_contact'),
                                child: Icon(
                                  Icons.star,
                                  size: 14,
                                  color: tokens.accent,
                                  semanticLabel: context.tr('primary_contact'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
