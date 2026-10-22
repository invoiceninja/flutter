import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/features/shell/widgets/company_picker.dart';

/// Mounts a [CompanyPicker] in the right form factor for the current layout.
///
/// On wide layouts, the picker pops up as a positioned overlay anchored to
/// [anchorKey]'s render box, top-aligned with it and opening beside it on the
/// content side — rightwards, or leftwards in a right-to-left locale, where
/// the rail sits at the right. When no
/// anchorKey is provided — e.g. for the ⌘K shortcut — the picker centres
/// itself in the viewport.
///
/// On narrow layouts the picker comes up as a scrollable bottom sheet that
/// respects the on-screen keyboard.
Future<void> showCompanyPicker(BuildContext context, {GlobalKey? anchorKey}) {
  final isWide = MediaQuery.sizeOf(context).width >= Breakpoints.wide;
  if (!isWide) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: const SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.all(12),
            child: CompanyPicker(fillWidth: true),
          ),
        ),
      ),
    );
  }

  Offset? topLeft;
  Size? anchorSize;
  if (anchorKey?.currentContext != null) {
    final box = anchorKey!.currentContext!.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      topLeft = box.localToGlobal(Offset.zero);
      anchorSize = box.size;
    }
  }

  return Navigator.of(context).push(
    _CompanyPickerRoute(
      topLeft: topLeft,
      anchorSize: anchorSize,
      // Snapshot the localized "Dismiss" string at construction time —
      // PopupRoute's `barrierLabel` getter has no BuildContext.
      barrierLabelText: context.tr('dismiss'),
    ),
  );
}

class _CompanyPickerRoute extends PopupRoute<void> {
  _CompanyPickerRoute({
    this.topLeft,
    this.anchorSize,
    required this.barrierLabelText,
  });

  final Offset? topLeft;
  final Size? anchorSize;
  final String barrierLabelText;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => barrierLabelText;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 120);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _PositionedPicker(topLeft: topLeft, anchorSize: anchorSize);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    );
  }
}

class _PositionedPicker extends StatelessWidget {
  const _PositionedPicker({required this.topLeft, required this.anchorSize});

  final Offset? topLeft;
  final Size? anchorSize;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    const pickerWidth = 320.0;
    const margin = 8.0;
    double left;
    double top;
    if (topLeft != null && anchorSize != null) {
      // Top-align the picker with the anchor and open it beside the sidebar
      // header on the content side: past the anchor's end edge, which is its
      // left edge in a right-to-left locale (the rail is at the right there).
      // Then clamp inside the viewport.
      left = Directionality.of(context) == TextDirection.rtl
          ? topLeft!.dx - margin - pickerWidth
          : topLeft!.dx + anchorSize!.width + margin;
      top = topLeft!.dy;
    } else {
      // ⌘K with no anchor — centre horizontally, offset a bit from the top.
      left = (screen.width - pickerWidth) / 2;
      top = 80;
    }
    final maxHeight = screen.height - top - margin;
    left = left.clamp(margin, screen.width - pickerWidth - margin);
    return Stack(
      children: [
        // rtl: physical — `left` is global-coordinate maths, already mirrored.
        Positioned(
          left: left,
          top: top.clamp(margin, screen.height - 160),
          width: pickerWidth,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: const CompanyPicker(),
          ),
        ),
      ],
    );
  }
}
