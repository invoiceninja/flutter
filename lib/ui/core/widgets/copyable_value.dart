import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';

/// Writes [value] to the system clipboard, fires a light haptic on touch
/// platforms, and surfaces the standard `copied_to_clipboard` toast.
///
/// Shared by [CopyableValue], `CellCopyHover`, and any bespoke copy button so
/// every copy in the app gives identical feedback. The toast value is
/// ellipsized so a long URL / address doesn't blow out the snackbar.
///
/// [label] names the thing in the toast instead of the payload — pass it when
/// [value] is a blob (a log dump, a design JSON, a cURL command) that reads as
/// noise inside "Copied … to the clipboard". Every caller should still route
/// through here rather than reaching for a placeholder-free key: the bundled
/// `copied_to_clipboard` string is translated in every locale, whereas an
/// app-local replacement would be English-only.
///
/// [messenger] is for a caller whose context may be popped before the toast
/// lands (see `outbox_screen`); it's threaded straight to [Notify.success].
Future<void> copyToClipboard(
  BuildContext context,
  String value, {
  String? label,
  ScaffoldMessengerState? messenger,
}) async {
  final message = context.tr('copied_to_clipboard', {
    'value': ellipsizeForToast(label ?? value),
  });
  await Clipboard.setData(ClipboardData(text: value));
  // Light confirmation buzz on touch — distinguishes an intentional copy from
  // a mis-tap. No-op / skipped off mobile.
  if (Env.isMobile) {
    await HapticFeedback.selectionClick();
  }
  if (!context.mounted) return;
  Notify.success(context, message, messenger: messenger);
}

/// Trims an over-long value so the confirmation toast stays a single line.
String ellipsizeForToast(String s, {int max = 40}) {
  if (s.length <= max) return s;
  return '${s.substring(0, max)}…';
}

/// The small copy affordance: a bordered chip with a copy glyph that writes
/// [value] to the clipboard on click.
///
/// Keyboard-focusable by default (Tab + Enter copies) — pass
/// [canRequestFocus] `false` for dense surfaces like table cells where Tab
/// should walk rows, not stop on every cell.
class CopyIconButton extends StatelessWidget {
  const CopyIconButton({
    super.key,
    required this.value,
    this.canRequestFocus = true,
  });

  final String value;
  final bool canRequestFocus;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final radius = BorderRadius.circular(InRadii.r1);
    return Tooltip(
      message: context.tr('copy'),
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: tokens.border),
        ),
        child: InkWell(
          onTap: () => copyToClipboard(context, value),
          borderRadius: radius,
          canRequestFocus: canRequestFocus,
          child: Semantics(
            button: true,
            label: context.tr('copy'),
            child: SizedBox(
              width: 22,
              height: 22,
              child: Icon(Icons.content_copy, size: 14, color: tokens.ink3),
            ),
          ),
        ),
      ),
    );
  }
}

/// Adds a copy affordance to a read-only value display.
///
/// - **Desktop / web (mouse):** a [CopyIconButton] fades in on hover. With
///   [fillWidth] (the default) the icon is pinned to the trailing edge so it
///   forms a consistent column down a stack of rows and never overlaps a
///   wrapped value, while the value text stays left next to its label. Keyboard
///   users can Tab to the button. There is deliberately **no** tap-to-copy on
///   the value here — a click must still place a cursor / start a selection.
/// - **Native mobile (touch):** no icon; tapping the value copies it (or
///   long-press, for values whose tap is already taken — e.g. a launchable
///   link). A light haptic fires on copy.
///
/// Renders [child] unchanged (no affordance) when [value] is empty.
///
/// The platform split is intentional: the hover icon shows whenever a mouse is
/// present (`!Env.isMobile`, i.e. desktop + web), and tap-to-copy is limited to
/// native mobile (`Env.isMobile`) so desktop-web value clicks keep selecting
/// text instead of copying.
class CopyableValue extends StatefulWidget {
  const CopyableValue({
    super.key,
    required this.value,
    required this.child,
    this.enableTapToCopy = true,
    this.enableLongPressToCopy = false,
    this.fillWidth = true,
  });

  /// The exact string written to the clipboard.
  final String value;

  /// The value's display widget (plain `Text`, `LinkText`, monospace amount…).
  final Widget child;

  /// Mobile single-tap copies the value. Turn off when [child] handles its own
  /// tap (e.g. a link that launches a URL).
  final bool enableTapToCopy;

  /// Mobile long-press copies the value. Use for link-bearing values whose tap
  /// is taken, so long-press still yields the underlying string.
  final bool enableLongPressToCopy;

  /// When true (default) the value fills the available width and the hover icon
  /// sits at the trailing edge — the right look inside a labeled detail row.
  /// Pass false for an inline value (e.g. the header `#number`) so the icon
  /// hugs the value instead of stretching across an unbounded row.
  final bool fillWidth;

  @override
  State<CopyableValue> createState() => _CopyableValueState();
}

class _CopyableValueState extends State<CopyableValue> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    if (value.isEmpty) return widget.child;

    // Native mobile: tap / long-press the value to copy; no hover icon.
    if (Env.isMobile) {
      final onTap = widget.enableTapToCopy
          ? () => copyToClipboard(context, value)
          : null;
      final onLongPress = widget.enableLongPressToCopy
          ? () => copyToClipboard(context, value)
          : null;
      if (onTap == null && onLongPress == null) return widget.child;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: widget.child,
      );
    }

    // Desktop + web: hover reveals a trailing copy icon. The slot is always in
    // the layout (opacity animates) so the row doesn't shift when it appears.
    return MouseRegion(
      onEnter: (_) {
        if (!_hovering) setState(() => _hovering = true);
      },
      onExit: (_) {
        if (_hovering) setState(() => _hovering = false);
      },
      child: Row(
        mainAxisSize: widget.fillWidth ? MainAxisSize.max : MainAxisSize.min,
        // Top-align the value (and icon) with the label — the host rows
        // (DetailInfoRow, header) are CrossAxisAlignment.start; without this
        // the 22px icon would vertically center the value below its label.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.fillWidth)
            Expanded(child: widget.child)
          else
            Flexible(child: widget.child),
          const SizedBox(width: InSpacing.sm),
          IgnorePointer(
            ignoring: !_hovering,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 100),
              opacity: _hovering ? 1.0 : 0.0,
              child: CopyIconButton(value: value),
            ),
          ),
        ],
      ),
    );
  }
}
