import 'package:flutter/widgets.dart';

import 'package:admin/app/hide_empty_panels_controller.dart';
import 'package:admin/ui/core/adaptive.dart';

/// Whether "Hide empty panels" is on by default on the device showing
/// [context] — the one definition of *automatic* (invoiceninja/flutter#161).
///
/// A phone, and only a phone: the issue asks for the default where a scroll
/// is expensive and says it "wouldn't make sense on desktops, laptops or
/// tablets". `Env.isTouchPrimary` alone would be the wrong question, since a
/// tablet is touch-primary too; `Breakpoints.isPhone` adds the short-side test.
/// It reads the window, not the pane, so the dashboard, the Customize sheet
/// floating over it and the Device Settings card all get the same answer.
bool hidesEmptyPanelsByDefault(BuildContext context) =>
    Breakpoints.isPhone(context);

/// The UI's way into [HideEmptyPanelsController]: every reader and writer
/// resolves *automatic* through [hidesEmptyPanelsByDefault], so a switch can
/// never show a different answer from the dashboard behind it. Don't call
/// `effectiveFor` / `set` from a widget — a caller that passed its own notion
/// of "phone" (the Customize sheet's `mobileLayout`, say) would disagree with
/// the dashboard in a 600–832 px desktop window and nothing would notice.
/// (`HiddenEmptyPanelsBuilder` is the one exception: its listener has no
/// context, so it caches [hidesEmptyPanelsByDefault] from its last build.)
extension HideEmptyPanelsInContext on HideEmptyPanelsController {
  /// Whether empty panels are hidden on this device right now.
  bool effectiveIn(BuildContext context) =>
      effectiveFor(isPhone: hidesEmptyPanelsByDefault(context));

  /// Store [enabled] — as automatic when it is what this device would pick.
  Future<void> setIn(BuildContext context, bool enabled) =>
      set(enabled, isPhone: hidesEmptyPanelsByDefault(context));
}
