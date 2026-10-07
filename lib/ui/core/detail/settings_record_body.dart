import 'package:flutter/material.dart';

import 'package:admin/ui/core/detail/detail_scroll_scope.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

/// The body of a record screen that lives under `/settings/...` — an expense
/// category, a company gateway, a payment link.
///
/// Such a screen goes through [SettingsFormShell] like every other settings
/// page (centred, capped at 720 px — CLAUDE.md § Settings screens), which
/// means the shell owns the scroll view. That left two things a record screen
/// needs with nothing to hold on to:
///
///  * **the page's scroll controller.** `EntityDetailScaffold` publishes one
///    through [DetailScrollScope] and watches it to fade the compact title in
///    once the header has scrolled away. The shell's list takes no controller,
///    so it is handed this one as the *primary* controller instead — on every
///    platform, since a list inherits a primary controller by itself only on
///    mobile.
///  * **pull-to-refresh.** A list that inherits a primary controller is
///    always-scrollable, so a record shorter than its viewport can still be
///    pulled (`docs/pull-to-refresh.md`).
///
/// Do not put a second vertical scroll view under this: it would inherit the
/// same controller.
class SettingsRecordBody extends StatelessWidget {
  const SettingsRecordBody({super.key, required this.child, this.onRefresh});

  /// Normally an `EntityRecordColumn`. The shell's 720 px cap is below the
  /// column's two-column breakpoint, so it is always the single stack here.
  final Widget child;

  /// Pull-to-refresh. Null leaves the page with no indicator.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    Widget body = SettingsFormShell(child: child);
    final scroll = DetailScrollScope.maybeOf(context);
    if (scroll != null) {
      body = PrimaryScrollController(
        controller: scroll,
        automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
        child: body,
      );
    }
    final refresh = onRefresh;
    if (refresh == null) return body;
    return RefreshIndicator(onRefresh: refresh, child: body);
  }
}
