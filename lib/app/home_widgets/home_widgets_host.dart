import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/widgets.dart';

import 'package:admin/app/home_widgets/home_widget_commands.dart';
import 'package:admin/app/home_widgets/home_widget_publisher.dart';
import 'package:admin/l10n/localization.dart';

/// Connects the home-screen widgets to the app's widget tree: hands the
/// publisher the app's strings (which only a `BuildContext` can reach), and
/// the app's lifecycle to both halves.
///
/// * **Going to the background** (paused, hidden, inactive, or a desktop
///   quit) flushes a pending write — iOS suspends the app before the 2 s
///   debounce would fire, and the widget would keep a timer the user had
///   just stopped.
/// * **Coming back** fetches what the widgets show and applies whatever they
///   queued while the app was away.
///
/// Draws nothing; inert when the widgets are off ([publisher] null).
class HomeWidgetsHost extends StatefulWidget {
  const HomeWidgetsHost({
    super.key,
    required this.publisher,
    required this.commands,
  });

  final HomeWidgetPublisher? publisher;
  final HomeWidgetCommands? commands;

  @override
  State<HomeWidgetsHost> createState() => _HomeWidgetsHostState();
}

class _HomeWidgetsHostState extends State<HomeWidgetsHost> {
  AppLifecycleListener? _lifecycle;
  Localization? _localization;
  TextDirection? _direction;

  @override
  void initState() {
    super.initState();
    if (widget.publisher == null) return;
    _lifecycle = AppLifecycleListener(
      onResume: _onResume,
      onInactive: _flush,
      onHide: _flush,
      onPause: _flush,
      onExitRequested: () async {
        await widget.publisher?.flush();
        return AppExitResponse.exit;
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final publisher = widget.publisher;
    if (publisher == null) return;
    final localization = Localization.of(context);
    final direction = Directionality.maybeOf(context);
    if (localization == null) return;
    if (identical(localization, _localization) && direction == _direction) {
      return;
    }
    _localization = localization;
    _direction = direction;
    publisher.setLocalization(
      // The bundled words, not the active company's Custom Labels: there is
      // one `strings` map for every widget, and a widget pinned to another
      // company would otherwise read the active one's words for things.
      localization.lookupBundled,
      localeTag: Localizations.localeOf(context).toLanguageTag(),
      rtl: direction == TextDirection.rtl,
    );
    // Once the strings exist: a Stop applied at a cold start may need its
    // toast.
    widget.commands?.start();
  }

  void _flush() => unawaited(widget.publisher?.flush());

  void _onResume() {
    unawaited(widget.publisher?.fetch());
    widget.publisher?.schedule();
    unawaited(widget.commands?.run());
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
