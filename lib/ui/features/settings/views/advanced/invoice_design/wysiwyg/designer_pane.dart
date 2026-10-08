import 'package:flutter/material.dart';

/// Which of the designer's layouts a pane is wide enough for.
enum DesignerTier {
  /// The page's structure as a list of rows — too narrow to draw the page.
  outline,

  /// The canvas alone: the palette is a sheet behind "Add block" and the
  /// property panel a drawer that opens with a selection.
  canvas,

  /// Canvas and property panel side by side; the palette stays behind
  /// "Add block" so the page keeps its width.
  docked,

  /// Palette · canvas · property panel.
  full,
}

/// Below this the pane cannot show the page at a size anyone could work on.
const double kDesignerCanvasFrom = 560;

/// From here the property panel has a column of its own.
const double kDesignerDockedFrom = 900;

/// From here the palette has one too. The two fixed columns take 562px, so
/// this leaves the page at least 84% of its true size; three panes at the
/// old 1024 left it at 23%.
const double kDesignerFullFrom = 1280;

DesignerTier designerTierFor(double paneWidth) {
  if (paneWidth >= kDesignerFullFrom) return DesignerTier.full;
  if (paneWidth >= kDesignerDockedFrom) return DesignerTier.docked;
  if (paneWidth >= kDesignerCanvasFrom) return DesignerTier.canvas;
  return DesignerTier.outline;
}

/// The width the designer actually has.
///
/// **Not the window's.** The designer is a route inside the app shell, laid
/// out beside the sidebar — 232px of the window, or 64 collapsed — so
/// `MediaQuery.sizeOf(context).width` overstates its room by that much.
/// Every breakpoint here used to read the window: a 1280px window chose the
/// three-pane layout for a 1048px pane and drew the page at half size, and an
/// iPad in portrait got an app-bar toolbar that left the name field nothing.
/// The screen measures its pane with a `LayoutBuilder` and publishes it here;
/// the toolbar (in the app bar) and the workspace (in the body) both read it.
class DesignerPane extends InheritedWidget {
  const DesignerPane({super.key, required this.width, required super.child});

  final double width;

  /// The pane's width, or the window's where nothing measured one — a
  /// toolbar or workspace pumped on its own fills its window.
  static double widthOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DesignerPane>()?.width ??
      MediaQuery.sizeOf(context).width;

  static DesignerTier tierOf(BuildContext context) =>
      designerTierFor(widthOf(context));

  @override
  bool updateShouldNotify(DesignerPane old) => old.width != width;
}

/// Where `showMenu` should open for something at [globalRect].
///
/// `showMenu` places its menu in the coordinates of the nearest navigator's
/// overlay, and the designer's navigator starts at the sidebar's edge, not
/// the window's — so a rect straight from `localToGlobal` opened every menu a
/// sidebar's width to the right of what was pressed. [context] must be the
/// one handed to `showMenu`.
RelativeRect menuAnchor(BuildContext context, Rect globalRect) {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  return RelativeRect.fromRect(
    overlay.globalToLocal(globalRect.topLeft) & globalRect.size,
    Offset.zero & overlay.size,
  );
}
