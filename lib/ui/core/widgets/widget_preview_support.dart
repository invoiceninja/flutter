import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';

/// Theme callback shared by every `@Preview` in `lib/ui/core/widgets/`. Wires
/// the same `buildInTheme(...)` the app uses so previews carry the `InTheme`
/// extension and design tokens, not the Material defaults.
PreviewThemeData appPreviewTheme() => const _AppPreviewTheme();

/// Flutter 3.47 made [PreviewThemeData] an abstract `apply` hook (it no longer
/// takes `materialLight` / `materialDark`). The preview scaffold sets
/// `MediaQuery.platformBrightness` from each preview's light/dark toggle, so
/// the theme is picked from that.
final class _AppPreviewTheme extends PreviewThemeData {
  const _AppPreviewTheme();

  @override
  Widget apply(BuildContext context, Widget child) {
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return Theme(
      data: buildInTheme(dark ? InTheme.dark : InTheme.light),
      child: child,
    );
  }
}
