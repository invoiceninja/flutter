import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/domain/reports/report_document.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/charts/chart_chrome.dart';
import 'package:admin/ui/features/reports/widgets/charts/report_bar_list.dart';
import 'package:admin/utils/formatting.dart';

/// Rows of one table drawn before the rest are left to the download. The
/// tables are not lazily built — they scroll sideways as one piece, which a
/// lazy list cannot — so a table of thousands of lines is shown by its head.
const int kReportDocumentRowCap = 200;

/// Which column of a report's tables its lines are ranked by, counted from
/// zero. By position, not by name: the headers are in the server's
/// language. A file whose column there is not money simply gets no ranking.
const Map<String, int> _kRankedColumn = {
  'client_sales_report': 4,
  'client_balance_report': 4,
  'user_sales_report': 2,
};

/// A file-only report, on the screen: its facts as cards, its tables as
/// tables, and — where the report is one that has a shape — that shape drawn
/// above them.
///
/// Every string in a table is the server's own. They are already in the
/// right notation for their currency and the company's date format, and a
/// statement re-rendered by the client is a second opinion on someone's
/// receivables. What the app adds is what the file lacks: a total under each
/// column of amounts, and a picture.
class ReportDocumentView extends StatelessWidget {
  const ReportDocumentView({
    super.key,
    required this.document,
    required this.reportId,
    required this.formatter,
    required this.wide,
  });

  final ReportDocument document;
  final String reportId;
  final Formatter? formatter;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final gutter = wide ? InSpacing.xl : InSpacing.lg(context);
    final gap = InSpacing.lg(context);
    final children = <Widget>[];
    void add(Widget child, {double? before}) {
      if (children.isNotEmpty) children.add(SizedBox(height: before ?? gap));
      children.add(child);
    }

    if (document.meta.isNotEmpty) {
      add(
        Text(
          [
            for (final fact in document.meta)
              '${fact.label} ${fact.values.join(' – ')}',
          ].join('  ·  '),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: tokens.ink2),
        ),
      );
    }

    final ranked = _kRankedColumn[reportId];
    final aging = reportId == 'aged_receivable_summary_report';
    // A statement's bottom line: the last of the label-and-value parts it
    // opens with, when it opens with several ("Total Profit" under revenue,
    // expenses and their totals). Drawn heavier; nothing else is.
    var leading = 0;
    while (leading < document.blocks.length &&
        document.blocks[leading] is ReportDocFacts) {
      leading++;
    }
    final bottomLine = leading >= 2 ? document.blocks[leading - 1] : null;
    // The picture is of the report's own tables — the ones it opens with. A
    // file may go on to break the same figures down again under a heading
    // ("Invoices by month"); a ranking drawn over each of those would be a
    // chart of one month per currency, six times.
    var underHeading = false;
    for (final block in document.blocks) {
      switch (block) {
        case ReportDocHeading():
          underHeading = true;
          add(_Heading(text: block.text), before: InSpacing.xl);
        case ReportDocFacts():
          add(
            _FactsCard(facts: block, strong: identical(block, bottomLine)),
            before: InSpacing.sm,
          );
        case ReportDocTable():
          if (block.rows.isEmpty) continue;
          Widget? lead;
          if (underHeading) {
            lead = null;
          } else if (aging) {
            lead = _AgingCard.maybe(block, formatter);
          } else if (ranked != null) {
            lead = _RankedCard.maybe(block, ranked, formatter);
          }
          if (lead != null) add(lead);
          add(
            _TableCard(
              table: block,
              formatter: formatter,
              // The card above it has already said which currency this is.
              showCaption: lead == null,
            ),
            before: lead != null ? InSpacing.sm : null,
          );
      }
    }

    return ListView(
      // Always scrollable, so a short report can still be pulled to refresh.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(gutter),
      children: children,
    );
  }
}

/// [value] of the currency with ISO [code] as the app writes money — or in
/// the company's own currency when the table named none.
String _money(Formatter? formatter, Decimal value, String? code) {
  if (formatter == null) return value.toString();
  String? id;
  if (code != null) {
    for (final c in formatter.currencies.values) {
      if (c.code.toUpperCase() == code) {
        id = c.id;
        break;
      }
    }
    // A currency the app has no record of: the number and its code, rather
    // than the amount dressed in the company's symbol.
    if (id == null) {
      return '${NumberFormat('#,##0.00').format(value.toDouble())} $code';
    }
  }
  return formatter.money(value, currencyId: id);
}

String _percent(double share) {
  final p = share * 100;
  return '${p.toStringAsFixed(p < 10 && p > 0 ? 1 : 0)}%';
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final radius = BorderRadius.circular(InRadii.r3);
    return Material(
      color: tokens.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: tokens.border),
        borderRadius: radius,
      ),
      child: child,
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: tokens.ink2,
        ),
      ),
    );
  }
}

/// Lines of a label and what it comes to.
class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.facts, this.strong = false});

  final ReportDocFacts facts;

  /// The statement's bottom line — see [ReportDocumentView.build].
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final pad = InSpacing.lg(context);
    final single = strong;
    return _Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < facts.entries.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: tokens.border),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: pad, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      facts.entries[i].label,
                      style: TextStyle(
                        fontSize: 13,
                        color: tokens.ink,
                        fontWeight: single ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: InSpacing.sm),
                  Text(
                    facts.entries[i].value,
                    style: moneyTextStyle(
                      fontSize: single ? 15 : 13,
                      fontWeight: single ? FontWeight.w600 : FontWeight.w500,
                      color: tokens.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// How receivables are spread across how late they are: one bar per
/// currency, and each bucket's amount and share in words beneath it.
class _AgingCard extends StatelessWidget {
  const _AgingCard({
    required this.labels,
    required this.amounts,
    required this.total,
    required this.currencyCode,
    required this.formatter,
  });

  /// The buckets are every money column but the last, which is their sum —
  /// by position, because the headers are in the server's language.
  static Widget? maybe(ReportDocTable table, Formatter? formatter) {
    final money = [
      for (var c = 0; c < table.kinds.length; c++)
        if (table.kinds[c] == ReportDocColumnKind.money) c,
    ];
    if (money.length < 3) return null;
    final buckets = money.sublist(0, money.length - 1);
    final amounts = [for (final c in buckets) table.total(c) ?? Decimal.zero];
    final total = amounts.fold(Decimal.zero, (a, b) => a + b);
    if (total <= Decimal.zero) return null;
    return _AgingCard(
      labels: [for (final c in buckets) table.header[c]],
      amounts: amounts,
      total: total,
      currencyCode: table.currencyCode,
      formatter: formatter,
    );
  }

  final List<String> labels;
  final List<Decimal> amounts;
  final Decimal total;
  final String? currencyCode;
  final Formatter? formatter;

  /// One hue, lighter to darker with lateness — the buckets are an order,
  /// not a set of unrelated things. The first is not late at all, and is
  /// drawn in a neutral rather than as the palest shade of overdue.
  Color _color(InTheme tokens, int index) {
    if (index == 0) return tokens.seriesOther;
    final steps = math.max(1, labels.length - 1);
    final t = 0.35 + 0.65 * (index / steps);
    return Color.lerp(tokens.surface, tokens.overdue, t)!;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final shares = [for (final a in amounts) (a / total).toDouble()];
    final lastShown = shares.lastIndexWhere((s) => s > 0);
    final description = [
      for (var i = 0; i < labels.length; i++)
        '${labels[i]}: ${_money(formatter, amounts[i], currencyCode)}',
    ].join(', ');
    return _Card(
      child: Padding(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    currencyCode ?? context.tr('total'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: tokens.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  _money(formatter, total, currencyCode),
                  style: moneyTextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: tokens.ink,
                  ),
                ),
              ],
            ),
            SizedBox(height: InSpacing.md(context)),
            Semantics(
              image: true,
              label: description,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 14,
                  child: Row(
                    children: [
                      for (var i = 0; i < shares.length; i++)
                        if (shares[i] > 0)
                          Expanded(
                            flex: math.max(1, (shares[i] * 1000).round()),
                            child: Container(
                              // A hairline of the surface separates two
                              // neighbours; no outline round each, and none
                              // after the last.
                              margin: EdgeInsetsDirectional.only(
                                end: i == lastShown ? 0 : 2,
                              ),
                              color: _color(tokens, i),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: InSpacing.md(context)),
            // Every bucket in words: the bar says how they compare, this
            // says what they are — and is all a colour-blind reader needs.
            Wrap(
              spacing: InSpacing.xl,
              runSpacing: InSpacing.sm,
              children: [
                for (var i = 0; i < labels.length; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ChartSwatch(color: _color(tokens, i)),
                      const SizedBox(width: 6),
                      Text(
                        labels[i],
                        style: TextStyle(fontSize: 12, color: tokens.ink2),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _money(formatter, amounts[i], currencyCode),
                        style: moneyTextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: amounts[i] == Decimal.zero
                              ? tokens.ink3
                              : tokens.ink,
                        ),
                      ),
                      if (shares[i] > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          _percent(shares[i]),
                          style: TextStyle(fontSize: 11, color: tokens.ink3),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The lines of a table ranked by one of its amounts: who the money is from.
class _RankedCard extends StatelessWidget {
  const _RankedCard({
    required this.title,
    required this.lines,
    required this.total,
  });

  static const int _limit = 10;

  static Widget? maybe(ReportDocTable table, int column, Formatter? formatter) {
    if (column >= table.kinds.length ||
        table.kinds[column] != ReportDocColumnKind.money ||
        table.rows.length < 2) {
      return null;
    }
    final lines = <({String label, String text, Decimal value})>[];
    for (var r = 0; r < table.rows.length; r++) {
      final value = table.values[r][column];
      if (value == null || value <= Decimal.zero) continue;
      lines.add((
        label: table.rows[r].first,
        text: table.rows[r][column],
        value: value,
      ));
    }
    if (lines.length < 2) return null;
    lines.sort((a, b) => b.value.compareTo(a.value));
    final total = lines.fold(Decimal.zero, (a, l) => a + l.value);
    final caption = table.currencyCode;
    return _RankedCard(
      title: caption == null
          ? table.header[column]
          : '${table.header[column]} · $caption',
      lines: lines.take(_limit).toList(),
      total: total,
    );
  }

  final String title;
  final List<({String label, String text, Decimal value})> lines;
  final Decimal total;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final max = lines.first.value;
    return _Card(
      child: Padding(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: tokens.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: InSpacing.sm),
            ReportBarList(
              items: [
                for (final line in lines)
                  ReportBarListItem(
                    label: line.label.isEmpty ? '—' : line.label,
                    // The server's own string: already in its currency's
                    // notation.
                    valueText: line.text,
                    shareText: _percent((line.value / total).toDouble()),
                    fraction: (line.value / max).toDouble(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One table of the file, with a total under each column of amounts.
class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.table,
    required this.formatter,
    this.showCaption = true,
  });

  final ReportDocTable table;
  final Formatter? formatter;
  final bool showCaption;

  static const double _pad = 12;

  bool _numeric(int c) => table.kinds[c] != ReportDocColumnKind.text;

  /// Sized to what the column holds — the header, a sample of its cells and
  /// its total — within limits: a notes column does not get to be a screen
  /// wide, and an amount is never cut short, because half an amount is a
  /// different amount.
  List<double> _widths(
    BuildContext context,
    int rowCount,
    List<String?> totals,
  ) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final widths = <double>[];
    for (var c = 0; c < table.header.length; c++) {
      var chars = table.header[c].length + 2;
      for (var r = 0; r < math.min(rowCount, 60); r++) {
        chars = math.max(chars, table.rows[r][c].length);
      }
      chars = math.max(chars, totals[c]?.length ?? 0);
      final numeric = _numeric(c);
      // The amount face is monospaced and wider per glyph than the text
      // face averages.
      final perChar = numeric ? 8.4 : 6.6;
      final width = chars * perChar * scale + _pad * 2 + (numeric ? 6 : 0);
      widths.add(
        numeric ? math.max(72.0, width) : width.clamp(72.0, 260.0).toDouble(),
      );
    }
    return widths;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final tr = context.tr;
    final shown = math.min(table.rows.length, kReportDocumentRowCap);
    final totals = [
      for (var c = 0; c < table.header.length; c++) table.total(c),
    ];
    final hasTotals = totals.any((t) => t != null);
    final totalTexts = [
      for (final t in totals)
        t == null ? null : _money(formatter, t, table.currencyCode),
    ];
    final natural = _widths(context, shown, totalTexts);
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final rowHeight = 36.0 * scale;
    final headerStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      color: tokens.ink3,
    );

    Widget content(List<double> widths) {
      Widget cell(int c, String text, {TextStyle? style, bool header = false}) {
        final numeric = _numeric(c);
        final base = table.kinds[c] == ReportDocColumnKind.text || header
            ? TextStyle(fontSize: 13, height: 1.2, color: tokens.ink)
            : moneyTextStyle(fontSize: 13, color: tokens.ink);
        return SizedBox(
          width: widths[c],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _pad),
            child: Align(
              alignment: numeric
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
              child: Text(
                text,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: base.merge(style),
              ),
            ),
          ),
        );
      }

      Widget line(List<Widget> cells, {Color? color, bool last = false}) =>
          Container(
            height: rowHeight,
            decoration: BoxDecoration(
              color: color,
              border: last
                  ? null
                  : Border(bottom: BorderSide(color: tokens.border)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: cells),
          );

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line([
            for (var c = 0; c < table.header.length; c++)
              cell(
                c,
                table.header[c].toUpperCase(),
                style: headerStyle,
                header: true,
              ),
          ], color: tokens.surfaceAlt),
          for (var r = 0; r < shown; r++)
            line([
              for (var c = 0; c < table.header.length; c++)
                cell(
                  c,
                  table.rows[r][c],
                  style: table.values[r][c] == Decimal.zero
                      ? TextStyle(color: tokens.ink3)
                      : null,
                ),
            ], last: r == shown - 1 && !hasTotals),
          if (hasTotals)
            line([
              for (var c = 0; c < table.header.length; c++)
                cell(
                  c,
                  c == 0 && totals[0] == null
                      ? tr('total')
                      : (totalTexts[c] ?? ''),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
            ], last: true),
        ],
      );
    }

    final caption = showCaption ? table.caption : null;
    final truncated = table.rows.length > shown;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (caption != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(_pad, 10, _pad, 10),
              child: Text(
                caption,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: tokens.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (caption != null)
            Divider(height: 1, thickness: 1, color: tokens.border),
          // Sideways as one piece when it is wider than the pane; filling
          // the pane when it is not.
          LayoutBuilder(
            builder: (context, constraints) {
              final width = natural.fold<double>(0, (a, b) => a + b);
              if (width >= constraints.maxWidth) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: content(natural),
                );
              }
              // Spare room goes to the first column, so the amounts stay
              // against the far edge and close to each other.
              return content([
                natural.first + constraints.maxWidth - width,
                ...natural.skip(1),
              ]);
            },
          ),
          if (truncated) ...[
            Divider(height: 1, thickness: 1, color: tokens.border),
            Padding(
              padding: const EdgeInsets.all(_pad),
              child: Text(
                tr('report_rows_truncated', {
                  'shown': '$shown',
                  'total': '${table.rows.length}',
                }),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.ink2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
