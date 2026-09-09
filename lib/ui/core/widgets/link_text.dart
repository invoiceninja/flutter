import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/ui/core/widgets/widget_preview_support.dart';

/// Text styled as a link: underline on hover with the click cursor. Used
/// to mark clickable text inside larger tap surfaces (table cells inside a
/// `TableRowInkWell`, "View all" labels inside an `InkWell`, etc.) so the
/// word reads as a navigable link before the user mouses over it.
///
/// The hover underline is the whole affordance on a pointer platform — and it
/// can never fire on touch, which is why [underlineAtRest] exists. Callers
/// that route through [linkOrText] get that decision made for them.
///
/// When [onTap] is non-null the widget also handles the tap itself; when
/// null, it's a pure visual that relies on an ancestor (`InkWell` /
/// `TableRowInkWell`) to handle the tap.
class LinkText extends StatefulWidget {
  const LinkText({
    super.key,
    required this.label,
    this.style,
    this.color,
    this.hoverColor,
    this.onTap,
    this.maxLines,
    this.overflow,
    this.enabled = true,
    this.underlineAtRest = false,
  });

  final String label;

  /// Base text style. The widget applies `color` and the hover underline on
  /// top of it.
  final TextStyle? style;

  /// Resting color. Defaults to the [style]'s color, or `tokens.ink` if the
  /// style doesn't set one. Override to give the link a different tone.
  final Color? color;

  /// Hover color. Defaults to the same as [color] (underline alone is the
  /// hover cue); pass a brighter tone for an extra emphasis bump.
  final Color? hoverColor;

  final VoidCallback? onTap;

  /// Show the underline at rest, not only on hover. Set it where hover can
  /// never fire — on touch the hover cue is unreachable, so the affordance
  /// has to be visible *before* the tap. Off by default so the pointer
  /// surfaces that rely on hover alone (the Number cell's [cellLink], the
  /// dashboard tables) stay exactly as they are. The decision belongs to
  /// [linkOrText]; this is only the mechanism.
  final bool underlineAtRest;

  final int? maxLines;
  final TextOverflow? overflow;

  /// When false, the widget renders as plain text (no hover, no underline,
  /// no cursor change). Used for disabled link states (e.g. "Refresh" while
  /// a refresh is already in flight).
  final bool enabled;

  @override
  State<LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<LinkText> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final resolvedColor = widget.color ?? widget.style?.color ?? tokens.ink;
    final resolvedHover = widget.hoverColor ?? resolvedColor;
    final base = widget.style ?? const TextStyle();
    final showUnderline =
        widget.enabled && (_hovering || widget.underlineAtRest);
    final effective = base.copyWith(
      color: widget.enabled
          ? (_hovering ? resolvedHover : resolvedColor)
          : base.color,
      decoration: showUnderline
          ? TextDecoration.underline
          : TextDecoration.none,
      decorationColor: showUnderline
          ? (_hovering ? resolvedHover : resolvedColor)
          : null,
    );
    Widget text = Text(
      widget.label,
      style: effective,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
    if (!widget.enabled) return text;
    if (widget.onTap != null) {
      text = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: text,
      );
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: text,
    );
  }
}

/// Whether a link must show its affordance **at rest** rather than on hover.
///
/// Gated on the input device, not the viewport — the same reasoning as
/// `InSizes.touchTarget`: a narrow desktop window still has a mouse, and a
/// tablet at any width still has fingers. A pure function so the rule is
/// unit-testable without pumping a widget.
bool get linkNeedsAtRestCue => Env.isTouchPrimary;

/// The at-rest colour for a cross-entity link, or `null` to leave the
/// caller's own styling alone (which is what every pointer platform gets, so
/// desktop rendering is unchanged).
///
/// `accentInk`, **not** `accent`: a selected list row is filled with
/// `accentSoft` (`selectable_list_row.dart`), and `accent` is the same mid
/// blue in BOTH brightnesses — it lands at ~3.2:1 on the dark `accentSoft`,
/// under the 4.5:1 floor. `accentInk` shifts per brightness and clears it
/// either way. Same call `client_picker_field.dart`, `tag_picker_field.dart`
/// and `line_item_table_desktop.dart` already made.
Color? linkAtRestColor(BuildContext context) =>
    linkNeedsAtRestCue ? context.inTheme.accentInk : null;

/// Render [label] as a [LinkText] when [link] is true and an [onTap] is
/// supplied, otherwise as plain [Text]. Shared by the `*NameLabel` widgets so
/// column cells and detail surfaces stay consistent.
///
/// The link variant is a touch bolder (`w500`) than the surrounding cell, and
/// **on touch it also underlines and recolours at rest** — because the hover
/// underline that carries "this is a link" on a pointer platform can never
/// fire there (invoiceninja/flutter#128).
///
/// The underline is the affordance and the colour only rides along: `accent`
/// is user-overridable per (company, user), `_deriveAccentInk` re-derives this
/// family from whatever the user picked, and the second stock swatch
/// (`#1F2937`) clamps to near-black in light mode — so a colour-only cue can
/// silently evaporate, and a green- or red-branded company would get client
/// names that read as `paid` / `overdue`.
///
/// A cross-entity link must NOT be used inside a narrow list row: the row owns
/// the tap there, and a nested opaque [LinkText] steals it. See
/// `test/lint/no_list_tile_name_link_test.dart`.
Widget linkOrText({
  required BuildContext context,
  required bool link,
  required String label,
  VoidCallback? onTap,
  TextStyle? style,
  int? maxLines,
  TextOverflow? overflow,
}) {
  if (!link || onTap == null) {
    return Text(label, style: style, maxLines: maxLines, overflow: overflow);
  }
  // `onTap` on the Semantics as well as the child: `excludeSemantics: true`
  // drops the descendant `GestureDetector`'s node INCLUDING its
  // `SemanticsAction.tap`, so without it the bridge reports a link with no
  // `ACTION_CLICK` and TalkBack / switch access have nothing to invoke.
  // `link:` rather than `button:` — a cross-entity jump is a link, and that is
  // what a screen reader should announce.
  return Semantics(
    link: true,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: LinkText(
      label: label,
      onTap: onTap,
      color: linkAtRestColor(context),
      underlineAtRest: linkNeedsAtRestCue,
      style: (style ?? const TextStyle()).copyWith(fontWeight: FontWeight.w500),
      maxLines: maxLines,
      overflow: overflow,
    ),
  );
}

@Preview(name: 'Default', group: 'LinkText', theme: appPreviewTheme)
Widget previewLinkText() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: LinkText(label: 'invoiceninja.com', onTap: () {}),
  );
}

@Preview(name: 'Disabled', group: 'LinkText', theme: appPreviewTheme)
Widget previewLinkTextDisabled() {
  return const Padding(
    padding: EdgeInsets.all(16),
    child: LinkText(label: 'Refreshing…', enabled: false),
  );
}
