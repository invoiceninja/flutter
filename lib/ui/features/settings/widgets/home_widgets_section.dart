import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/services/home_widget_bridge.dart';
import 'package:admin/domain/home_widgets/widget_snapshot.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';

/// Search keys for the settings sidebar search. Colocated with the section so
/// adding a field updates both ends in one place (see
/// `search_catalog_consistency_test`).
const kHomeWidgetsSearchKeys = <String>['widget_settings_section'];

/// Whether [HomeWidgetsSection] renders — and so whether settings search
/// offers its keys: only where there are home-screen widgets.
bool homeWidgetsSectionShown() =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// Device Settings card for the home-screen widgets
/// (docs/home-screen-widgets.md): how to add one, and — on Android, where an
/// app may ask the launcher — a button per widget that places it.
///
/// A widget is placed from the home screen, never from the app, so without
/// this nothing in the app says they exist.
class HomeWidgetsSection extends StatefulWidget {
  const HomeWidgetsSection({super.key, this.bridge});

  /// Injected by tests; the app's own channel otherwise.
  final HomeWidgetBridge? bridge;

  @override
  State<HomeWidgetsSection> createState() => _HomeWidgetsSectionState();
}

class _HomeWidgetsSectionState extends State<HomeWidgetsSection> {
  late final HomeWidgetBridge _bridge = widget.bridge ?? HomeWidgetBridge();

  Future<void> _pin(WidgetKind kind) async {
    final asked = await _bridge.pin(kind);
    if (!mounted || asked) return;
    // The launcher can't take one from an app: say how to add it by hand.
    Notify.info(context, context.tr('widget_pin_unsupported'));
  }

  @override
  Widget build(BuildContext context) {
    if (!homeWidgetsSectionShown()) return const SizedBox.shrink();
    final android = defaultTargetPlatform == TargetPlatform.android;
    return FormSection(
      title: context.tr('widget_settings_section'),
      children: [
        Text(
          context.tr(switch (defaultTargetPlatform) {
            TargetPlatform.android => 'widget_settings_help_android',
            TargetPlatform.macOS => 'widget_settings_help_macos',
            _ => 'widget_settings_help_ios',
          }),
          style: TextStyle(color: context.inTheme.ink2, height: 1.4),
        ),
        if (android)
          Wrap(
            spacing: InSpacing.sm,
            runSpacing: InSpacing.sm,
            children: [
              for (final (kind, key, icon) in const [
                (
                  WidgetKind.snapshot,
                  'widget_add_snapshot',
                  Icons.insights_outlined,
                ),
                (
                  WidgetKind.attention,
                  'widget_add_attention',
                  Icons.priority_high_outlined,
                ),
                (WidgetKind.timer, 'widget_add_timer', Icons.timer_outlined),
              ])
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 40),
                  ),
                  onPressed: () => unawaited(_pin(kind)),
                  icon: Icon(icon, size: 18),
                  label: Text(context.tr(key)),
                ),
            ],
          ),
      ],
    );
  }
}
