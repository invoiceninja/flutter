import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:admin/app/hide_empty_panels_controller.dart';
import 'package:admin/ui/features/dashboard/helpers/hide_empty_panels.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';

/// Hands [builder] the panel kinds this device is leaving off the dashboard
/// right now because they have nothing to show (invoiceninja/flutter#161) —
/// empty whenever the "Hide empty panels" preference resolves to off.
///
/// The one place the three readers — the wide `DashboardPanelGrid`, the
/// mobile body's panel list and the Customize sheet's Panels tab — learn
/// that answer, for reasons that are each invisible at a call site:
///
/// * **It has to listen.** A section emission bumps only its own card's
///   notifier, never the view model, so a panel list built under the global
///   notify would never find out that a panel emptied. This listens to
///   [DashboardViewModel.emptyPanels] and to the preference.
/// * **It rebuilds only when its answer changes.** With the preference off —
///   the default everywhere but a phone — a panel emptying out changes nothing
///   on screen, so it must not rebuild the list (every card, the chart, the
///   task calendar's day loads) beneath it.
/// * **It subscribes only when [vm] or [pref] is replaced.** A fresh
///   `Listenable.merge` per build would re-subscribe on every parent rebuild,
///   and the Customize sheet outlives the view model it was opened with: after
///   a company switch disposes that view model, the sheet's next rebuild would
///   call `addListener` on a disposed notifier.
/// * **Automatic means [hidesEmptyPanelsByDefault]**, cached from the last
///   build (a `MediaQuery` change rebuilds this anyway) so the listener can
///   resolve the preference without a context.
///
/// **Always wrap, even while the preference is off.** Swapping between this
/// builder and a bare child changes the widget type above the list, which
/// re-creates the whole `ListView` or grid: the scroll position goes, and so
/// does the state of the two Drift-backed panels beneath it.
class HiddenEmptyPanelsBuilder extends StatefulWidget {
  const HiddenEmptyPanelsBuilder({
    super.key,
    required this.vm,
    required this.pref,
    required this.builder,
  });

  final DashboardViewModel vm;
  final HideEmptyPanelsController pref;

  /// [hidden] is either empty or [DashboardViewModel.emptyPanels]: every kind
  /// in it has loaded, holds no rows, and is cache-backed — so a builder may
  /// drop it (card and gap together) without first checking what kind it is.
  final Widget Function(BuildContext context, Set<String> hidden) builder;

  @override
  State<HiddenEmptyPanelsBuilder> createState() =>
      _HiddenEmptyPanelsBuilderState();
}

class _HiddenEmptyPanelsBuilderState extends State<HiddenEmptyPanelsBuilder> {
  bool _byDefault = false;
  Set<String> _hidden = const <String>{};

  @override
  void initState() {
    super.initState();
    _subscribe(widget);
  }

  @override
  void didUpdateWidget(HiddenEmptyPanelsBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.vm, widget.vm) ||
        !identical(oldWidget.pref, widget.pref)) {
      _unsubscribe(oldWidget);
      _subscribe(widget);
    }
  }

  @override
  void dispose() {
    _unsubscribe(widget);
    super.dispose();
  }

  void _subscribe(HiddenEmptyPanelsBuilder source) {
    source.vm.emptyPanels.addListener(_onChanged);
    source.pref.addListener(_onChanged);
  }

  // `removeListener` is safe on a disposed notifier, which is what the old
  // view model's is by the time a company switch reaches this.
  void _unsubscribe(HiddenEmptyPanelsBuilder source) {
    source.vm.emptyPanels.removeListener(_onChanged);
    source.pref.removeListener(_onChanged);
  }

  Set<String> _resolve() => widget.pref.effectiveFor(isPhone: _byDefault)
      ? widget.vm.emptyPanels.value
      : const <String>{};

  void _onChanged() {
    if (setEquals(_resolve(), _hidden)) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _byDefault = hidesEmptyPanelsByDefault(context);
    _hidden = _resolve();
    return widget.builder(context, _hidden);
  }
}
