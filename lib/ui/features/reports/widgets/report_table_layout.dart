import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/domain/reports/report_column_types.dart';

/// Narrowest a column can be dragged, and the widest.
const double kReportColumnMinWidth = 72;
const double kReportColumnMaxWidth = 640;

/// Whether a column's values are figures — right-aligned, so their digits
/// line up down the column.
bool isReportColumnNumeric(ReportColumnType type) =>
    type == ReportColumnType.money ||
    type == ReportColumnType.number ||
    type == ReportColumnType.duration ||
    type == ReportColumnType.age;

/// The width a column takes until the reader drags it. Sized to what the
/// column usually holds, not uniformly: a table of equal 160 px columns gave
/// a status and an address the same room — and pushed the amounts, which are
/// what a report is read for, off the right-hand edge.
double defaultReportColumnWidth(ReportColumn column, {required bool leading}) {
  if (leading) return 220;
  switch (column.type) {
    case ReportColumnType.string:
      return switch (column.identifier.split('.').last) {
        // Short, fixed-shape values.
        'number' || 'po_number' || 'status' => 116,
        'currency' || 'currency_id' || 'country_id' => 96,
        'name' || 'email' => 188,
        // Prose.
        'public_notes' ||
        'private_notes' ||
        'notes' ||
        'description' ||
        'terms' ||
        'footer' => 240,
        _ => 152,
      };
    case ReportColumnType.money:
      return 124;
    case ReportColumnType.number:
    case ReportColumnType.duration:
      return 104;
    case ReportColumnType.date:
      return 112;
    case ReportColumnType.dateTime:
      return 164;
    case ReportColumnType.age:
    case ReportColumnType.boolean:
      return 88;
  }
}

/// How far over its pane a table may be and still be squeezed to fit rather
/// than scrolled. A table that scrolls sideways for the sake of forty pixels
/// hides its last column behind a gesture; past this, squeezing would start
/// to cut names short, and scrolling is the honest answer.
const double _kSqueezeLimit = 0.12;

/// The least of its width a text column keeps when squeezed.
const double _kSqueezeFloor = 0.72;

/// How a table of [columns] is laid out across [width].
///
/// The first column is held in place and the rest scroll beside it — but
/// only when they do not all fit. When they do, there is nothing to scroll:
/// the spare width is shared among the text columns (figures keep their
/// width, so amounts stay close to their labels) and the table fills its
/// card instead of sitting narrow at the left edge. When they miss by a
/// little, the text columns give it up instead (see [_kSqueezeLimit]).
class ReportTableLayout {
  ReportTableLayout._({
    required this.columns,
    required this.widths,
    required this.pinnedWidth,
    required this.scrollViewport,
    required this.scrollContent,
  });

  factory ReportTableLayout.of({
    required List<ReportColumn> columns,
    required double width,
    Map<String, double> userWidths = const {},
    double? pinnedMaxFraction,
  }) {
    if (columns.isEmpty) {
      return ReportTableLayout._(
        columns: const [],
        widths: const [],
        pinnedWidth: 0,
        scrollViewport: 0,
        scrollContent: 0,
      );
    }
    final widths = [
      for (var i = 0; i < columns.length; i++)
        (userWidths[columns[i].identifier] ??
                defaultReportColumnWidth(columns[i], leading: i == 0))
            .clamp(kReportColumnMinWidth, kReportColumnMaxWidth)
            .toDouble(),
    ];
    // On a narrow pane the held column must not swallow the screen.
    final pinnedCap = pinnedMaxFraction == null
        ? double.infinity
        : math.max(kReportColumnMinWidth, width * pinnedMaxFraction);
    if (!userWidths.containsKey(columns.first.identifier)) {
      widths[0] = math.min(widths[0], pinnedCap);
    }
    final total = widths.fold<double>(0, (a, b) => a + b);
    if (total <= width) {
      // Everything fits: hand the spare width to the columns nobody sized —
      // the text ones first.
      var spare = width - total;
      bool flexible(int i, {required bool textOnly}) =>
          !userWidths.containsKey(columns[i].identifier) &&
          (!textOnly || columns[i].type == ReportColumnType.string);
      var takers = [
        for (var i = 0; i < columns.length; i++)
          if (flexible(i, textOnly: true)) i,
      ];
      if (takers.isEmpty) {
        takers = [
          for (var i = 0; i < columns.length; i++)
            if (flexible(i, textOnly: false)) i,
        ];
      }
      if (takers.isEmpty) takers = [columns.length - 1];
      final share = spare / takers.length;
      for (final i in takers) {
        widths[i] += share;
        spare -= share;
      }
      return ReportTableLayout._(
        columns: columns,
        widths: widths,
        pinnedWidth: widths.first,
        scrollViewport: width - widths.first,
        scrollContent: width - widths.first,
      );
    }
    // A little too wide: take the difference out of the text columns nobody
    // sized, in proportion, rather than scroll for it.
    final over = total - width;
    if (over <= width * _kSqueezeLimit) {
      final givers = [
        for (var i = 0; i < columns.length; i++)
          if (columns[i].type == ReportColumnType.string &&
              !userWidths.containsKey(columns[i].identifier))
            i,
      ];
      double slack(int i) => math.max(
        0,
        widths[i] - math.max(kReportColumnMinWidth, widths[i] * _kSqueezeFloor),
      );
      final available = givers.fold<double>(0, (a, i) => a + slack(i));
      if (available >= over && available > 0) {
        for (final i in givers) {
          widths[i] -= over * slack(i) / available;
        }
        return ReportTableLayout._(
          columns: columns,
          widths: widths,
          pinnedWidth: widths.first,
          scrollViewport: width - widths.first,
          scrollContent: width - widths.first,
        );
      }
    }
    return ReportTableLayout._(
      columns: columns,
      widths: widths,
      pinnedWidth: widths.first,
      scrollViewport: math.max(0, width - widths.first),
      scrollContent: total - widths.first,
    );
  }

  final List<ReportColumn> columns;

  /// One width per column, in order.
  final List<double> widths;

  /// Width of the first column, which does not scroll.
  final double pinnedWidth;

  /// The room the other columns have, and the room they need.
  final double scrollViewport;
  final double scrollContent;

  bool get scrolls => scrollContent > scrollViewport + 0.5;

  double get maxScroll => math.max(0, scrollContent - scrollViewport);
}

/// Tells a horizontal [ViewportOffset] how far it may scroll.
///
/// The table's columns are not children of a horizontal viewport — they are
/// cells of rows inside a *vertical* scroll view, each painted at minus the
/// offset — so nothing would otherwise report the scrollable extent, and the
/// offset would have nowhere to go. This does what a viewport's layout does:
/// it applies the viewport and content dimensions, and nothing else.
class ReportTableScrollExtent extends SingleChildRenderObjectWidget {
  const ReportTableScrollExtent({
    super.key,
    required this.offset,
    required this.viewport,
    required this.content,
    required super.child,
  });

  final ViewportOffset offset;
  final double viewport;
  final double content;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderScrollExtent(offset, viewport, content);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderScrollExtent)
      ..offset = offset
      ..viewport = viewport
      ..content = content;
  }
}

class _RenderScrollExtent extends RenderProxyBox {
  _RenderScrollExtent(this._offset, this._viewport, this._content);

  ViewportOffset _offset;
  set offset(ViewportOffset value) {
    if (identical(value, _offset)) return;
    _offset = value;
    markNeedsLayout();
  }

  double _viewport;
  set viewport(double value) {
    if (value == _viewport) return;
    _viewport = value;
    markNeedsLayout();
  }

  double _content;
  set content(double value) {
    if (value == _content) return;
    _content = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    super.performLayout();
    _offset.applyViewportDimension(_viewport);
    _offset.applyContentDimensions(0, math.max(0, _content - _viewport));
  }
}

/// What a table row needs to know about the horizontal scroll: where it is,
/// and how the columns are laid out. Provided once above the rows.
class ReportTableScrollScope extends InheritedWidget {
  const ReportTableScrollScope({
    super.key,
    required this.offset,
    required this.layout,
    required super.child,
  });

  final ViewportOffset offset;
  final ReportTableLayout layout;

  static ReportTableScrollScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReportTableScrollScope>()!;

  @override
  bool updateShouldNotify(ReportTableScrollScope oldWidget) =>
      !identical(oldWidget.offset, offset) ||
      !identical(oldWidget.layout, layout);
}
