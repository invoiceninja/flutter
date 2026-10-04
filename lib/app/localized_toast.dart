import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';

enum LocalizedToastKind { info, warning, error }

/// Toast a localized [key] straight onto the context-free [ToastController]
/// (rather than `Notify`, which needs a context to find it) — for code that
/// lives on `Services` and acts on something arriving from outside the app:
/// `DeepLinkRouter`, `SharedFileIntake`.
///
/// [context] is only read for its [Localization]. Without one — the sliver
/// before the first frame — the toast is skipped and [log]ged instead:
/// CLAUDE.md's context-free-toast rule is that the message must be
/// `tr()`-derived, and rendering the raw snake_case key at the user would be
/// worse than saying nothing.
void showLocalizedToast({
  required ToastController toasts,
  required BuildContext? context,
  required String key,
  Map<String, String>? params,
  required LocalizedToastKind kind,
  required Logger log,
}) {
  final loc = context == null ? null : Localization.of(context);
  if (loc == null) {
    log.warning('no localization yet, dropping toast "$key"');
    return;
  }
  // `no_unsubstituted_placeholders_test` only matches literal `tr('k')` /
  // `lookup('k')` call forms, so a key routed through here is invisible to it
  // — the exact case CLAUDE.md § Localization says needs the invariant
  // asserted where the lookup actually happens. A caller that forgets the
  // params of a key carrying `:company` / `:size` would otherwise ship a raw
  // token to the user instead of failing.
  //
  // Checked against the TEMPLATE, not the rendered string: a company legally
  // named "Acme :test" would otherwise trip this on the substituted output.
  assert(() {
    final template = loc.lookup(key);
    final unfilled = RegExp(r'(?<![A-Za-z0-9_/:]):([a-z][a-z0-9_]*)')
        .allMatches(template)
        .map((m) => m.group(1)!)
        .where((name) => !(params?.containsKey(name) ?? false));
    return unfilled.isEmpty;
  }(), 'toast "$key" has placeholders with no params passed.');
  final message = loc.lookup(key, params);
  switch (kind) {
    case LocalizedToastKind.info:
      toasts.info(message);
    case LocalizedToastKind.warning:
      toasts.warning(message);
    case LocalizedToastKind.error:
      toasts.error(message);
  }
}
