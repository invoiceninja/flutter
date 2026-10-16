import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Carries the active company's Custom Labels to `Localization.of`, which
/// layers them over the bundled strings.
///
/// The app installs one around everything `MaterialApp.builder` returns — the
/// router, the toast host and the shortcut-hint overlay alike — fed by
/// `CompanyLabelOverrides`. Below `Localizations` and above every route, so
/// one notify reaches each widget that read a string, and nothing else.
///
/// Not a reload of the localization delegate: that would re-read and decode
/// the locale's whole JSON bundle for a map of a few labels, and hold the
/// frame while it did.
class CompanyLabelsScope
    extends InheritedNotifier<ValueListenable<Map<String, String>>> {
  const CompanyLabelsScope({
    super.key,
    required ValueListenable<Map<String, String>> labels,
    required super.child,
  }) : super(notifier: labels);

  /// The labels above [context], registering [context] to rebuild when they
  /// change; null with no scope above it — every test that pumps a bare
  /// `MaterialApp`, which then reads the bundles alone.
  static Map<String, String>? labelsOf(BuildContext context) =>
      notifierOf(context)?.value;

  /// The notifier itself, for a screen that asks it more than the labels.
  static ValueListenable<Map<String, String>>? notifierOf(
    BuildContext context,
  ) => context
      .dependOnInheritedWidgetOfExactType<CompanyLabelsScope>()
      ?.notifier;
}
