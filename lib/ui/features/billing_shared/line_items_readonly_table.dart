import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/billing/line_item_custom_fields.dart';
import 'package:admin/domain/date_placeholders.dart';
import 'package:admin/domain/tasks/line_item_notes_display.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/utils/formatting.dart';

// Column widths for the wide (table) layout. Item / Description flex; the
// numeric columns are fixed so they line up down the table.
const double _kQtyW = 60;
const double _kCostW = 96;
const double _kDiscW = 84;
const double _kTaxW = 104;
const double _kTotalW = 112;
const double _kPadH = 12;
const double _kGap = 10;

/// Read-only line-items table for the billing-doc detail Overview (Invoice /
/// Quote / Credit). Mirrors the edit screen's column set
/// (`line_item_editor/line_item_table_desktop.dart`) minus all interactivity.
///
/// Column visibility is data-driven: the Tax column shows only when some line
/// carries a tax, the Discount column only when some line carries one — so a
/// plain invoice stays a clean Item · Qty · Unit cost · Total grid. When the
/// fixed columns would crush the Item/Description flex (narrow detail panel),
/// the rows reflow into stacked cards.
///
/// Line total renders `gross` (`cost × quantity`, pre-discount/pre-tax) to
/// match what the edit table shows per row; document-level discount/tax land
/// in the totals card below.
///
/// A line's custom values ("Color: Red") read under its description rather
/// than as columns: product and hourly lines share this table but label their
/// four values from different company fields (`product1..4` / `task1..4`), so
/// no single header could name a slot.
class LineItemsReadonlyTable extends StatelessWidget {
  const LineItemsReadonlyTable({
    super.key,
    required this.items,
    this.formatter,
    this.currencyId,
    this.discountIsAmount = false,
    this.customFields,
  });

  final List<LineItem> items;
  final Formatter? formatter;
  final String? currencyId;

  /// How to render any per-line discount (mirrors the document-level
  /// `isAmountDiscount`): currency amount vs. percentage.
  final bool discountIsAmount;

  /// The company's `custom_fields` definitions, naming each line's custom
  /// values. Null (company not loaded yet) shows none.
  final Map<String, String>? customFields;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final rows = items.where((it) => !it.isBlank).toList(growable: false);
    if (rows.isEmpty) return _empty(context, tokens);

    final showTax = rows.any(_hasTax);
    final showDiscount = rows.any((it) => it.discount != Decimal.zero);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r3),
        color: tokens.surface,
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fixed =
              _kQtyW +
              _kCostW +
              _kTotalW +
              (showDiscount ? _kDiscW : 0) +
              (showTax ? _kTaxW : 0);
          // Keep ~240px for the Item + Description flex columns; below that the
          // table is unreadable, so stack instead.
          final stacked = constraints.maxWidth - fixed < 240;
          if (stacked) {
            return Column(
              children: [
                for (var i = 0; i < rows.length; i++)
                  _stackedRow(
                    context,
                    rows[i],
                    isLast: i == rows.length - 1,
                    showTax: showTax,
                    showDiscount: showDiscount,
                  ),
              ],
            );
          }
          return Column(
            children: [
              _headerRow(context, showTax: showTax, showDiscount: showDiscount),
              for (var i = 0; i < rows.length; i++)
                _dataRow(
                  context,
                  rows[i],
                  isLast: i == rows.length - 1,
                  showTax: showTax,
                  showDiscount: showDiscount,
                ),
            ],
          );
        },
      ),
    );
  }

  // ── Wide layout ────────────────────────────────────────────────────────

  Widget _headerRow(
    BuildContext context, {
    required bool showTax,
    required bool showDiscount,
  }) {
    final tokens = context.inTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _kPadH, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          _flexHead(3, context.tr('item'), tokens),
          _flexHead(4, context.tr('description'), tokens),
          _numHead(_kQtyW, context.tr('quantity'), tokens),
          _numHead(_kCostW, context.tr('unit_cost'), tokens),
          if (showDiscount) _numHead(_kDiscW, context.tr('discount'), tokens),
          if (showTax) _numHead(_kTaxW, context.tr('tax'), tokens),
          _numHead(_kTotalW, context.tr('line_total'), tokens),
        ],
      ),
    );
  }

  Widget _dataRow(
    BuildContext context,
    LineItem it, {
    required bool isLast,
    required bool showTax,
    required bool showDiscount,
  }) {
    final tokens = context.inTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _kPadH, vertical: 10),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: tokens.border)),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _flexCell(
            3,
            it.productKey.isEmpty ? '—' : it.productKey,
            tokens,
            strong: true,
          ),
          // Task-generated notes carry the PDF's presentational markup
          // (`<div class="project-header">`, `<br/>`); strip it for display
          // so the column reads as text, not tags. See
          // `lineItemNotesPlainText`.
          _descriptionCell(context, it, tokens),
          _numCell(_kQtyW, _qty(it.quantity), tokens),
          _numCell(_kCostW, _money(it.cost), tokens),
          if (showDiscount)
            _numCell(
              _kDiscW,
              it.discount == Decimal.zero ? '—' : _discountLabel(it),
              tokens,
            ),
          if (showTax)
            _numCell(_kTaxW, _hasTax(it) ? _taxLabel(it) : '—', tokens),
          _numCell(_kTotalW, _money(it.gross), tokens, strong: true),
        ],
      ),
    );
  }

  // ── Narrow (stacked) layout ──────────────────────────────────────────────

  Widget _stackedRow(
    BuildContext context,
    LineItem it, {
    required bool isLast,
    required bool showTax,
    required bool showDiscount,
  }) {
    final tokens = context.inTheme;
    final meta = <String>[
      '${_qty(it.quantity)} × ${_money(it.cost)}',
      if (showDiscount && it.discount != Decimal.zero)
        '${context.tr('discount')}: ${_discountLabel(it)}',
      if (showTax && _hasTax(it)) '${context.tr('tax')}: ${_taxLabel(it)}',
    ];
    final notes = _notesText(it);
    final custom = _customSummary(context, it);
    final title = it.productKey.isNotEmpty
        ? it.productKey
        // One line only for the title — the rest of the note follows in the
        // subtitle below when there's a product key to head the row.
        : (notes.isEmpty ? '—' : notes.split('\n').first);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _kPadH, vertical: 12),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: tokens.border)),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: tokens.ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _money(it.gross),
                style: moneyTextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: tokens.ink,
                ),
              ),
            ],
          ),
          if (it.productKey.isNotEmpty && notes.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(notes, style: TextStyle(fontSize: 12, color: tokens.ink2)),
          ],
          if (custom.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(custom, style: _customStyle(tokens)),
          ],
          const SizedBox(height: 4),
          Text(
            meta.join('   ·   '),
            style: TextStyle(
              fontSize: 11.5,
              color: tokens.ink3,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context, InTheme tokens) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 24),
    decoration: BoxDecoration(
      border: Border.all(color: tokens.border),
      borderRadius: BorderRadius.circular(InRadii.r3),
      color: tokens.surface,
    ),
    child: Text(
      context.tr('no_records_found'),
      textAlign: TextAlign.center,
      style: TextStyle(color: tokens.ink3, fontSize: 13),
    ),
  );

  // ── Cell helpers ─────────────────────────────────────────────────────────

  /// The wide layout's Description column: the notes, then the line's custom
  /// values. Neither is capped to fewer lines than the notes always had —
  /// this is the one place a value too long for the edit table can be read.
  Widget _descriptionCell(BuildContext context, LineItem it, InTheme tokens) {
    final custom = _customSummary(context, it);
    if (custom.isEmpty) {
      return _flexCell(4, _notesText(it), tokens, color: tokens.ink2);
    }
    final notes = _notesText(it);
    return Expanded(
      flex: 4,
      child: Padding(
        padding: const EdgeInsets.only(right: _kGap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notes.isNotEmpty) ...[
              Text(
                notes,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: tokens.ink2),
              ),
              const SizedBox(height: 2),
            ],
            Text(custom, style: _customStyle(tokens)),
          ],
        ),
      ),
    );
  }

  /// `Label: value` for each custom value [it] holds, labelled from the
  /// company's `task1..4` for an hourly line and `product1..4` otherwise.
  String _customSummary(BuildContext context, LineItem it) =>
      lineItemCustomValueRows(
        it,
        lineItemCustomFields(customFields, task: lineItemUsesTaskFields(it)),
        yes: context.tr('yes'),
        no: context.tr('no'),
        formatter: formatter,
      ).map((r) => '${r.label}: ${r.value}').join('   ·   ');

  TextStyle _customStyle(InTheme tokens) =>
      TextStyle(fontSize: 11.5, color: tokens.ink3);

  Widget _flexHead(int flex, String text, InTheme tokens) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.only(right: _kGap),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: tokens.ink3,
          letterSpacing: 0.3,
        ),
      ),
    ),
  );

  Widget _numHead(double w, String text, InTheme tokens) => SizedBox(
    width: w,
    child: Text(
      text,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: tokens.ink3,
        letterSpacing: 0.3,
      ),
    ),
  );

  Widget _flexCell(
    int flex,
    String text,
    InTheme tokens, {
    bool strong = false,
    Color? color,
  }) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.only(right: _kGap),
      child: Text(
        text,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: strong ? FontWeight.w500 : FontWeight.w400,
          color: color ?? tokens.ink,
        ),
      ),
    ),
  );

  Widget _numCell(
    double w,
    String text,
    InTheme tokens, {
    bool strong = false,
  }) => SizedBox(
    width: w,
    child: Text(
      text,
      textAlign: TextAlign.right,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: moneyTextStyle(
        fontSize: 13,
        fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
        color: tokens.ink,
      ),
    ),
  );

  // ── Formatting ───────────────────────────────────────────────────────────

  bool _hasTax(LineItem it) =>
      it.taxName1.trim().isNotEmpty ||
      it.taxName2.trim().isNotEmpty ||
      it.taxName3.trim().isNotEmpty ||
      it.taxRate1 != Decimal.zero ||
      it.taxRate2 != Decimal.zero ||
      it.taxRate3 != Decimal.zero;

  String _money(Decimal v) =>
      formatter?.money(v, clientCurrencyId: currencyId) ?? v.toString();

  String _qty(Decimal v) => formatter?.decimal(v.toDouble()) ?? v.toString();

  /// Strip the PDF's presentational markup, then render any reserved date
  /// keyword as the date it becomes (invoiceninja/flutter#93).
  ///
  /// Both passes are needed and in this order: `lineItemNotesPlainText` drops
  /// the `<div class="project-header">` wrapper a task-generated note opens
  /// with, and expanding afterwards means no `/` from a closing tag can be
  /// mistaken for an arithmetic operator — the bug upstream works around with
  /// a `str_replace("</", "")` (`Helpers.php:272`).
  ///
  /// Worth doing even though the server expands and *persists* line-item notes
  /// when a document is created (`BaseRepository.php:217-227`): that guard runs
  /// only for a new model and never for a recurring invoice, so a keyword typed
  /// into an existing document stays raw in the database and is expanded only
  /// when the PDF is built.
  String _notesText(LineItem it) => expandDatePlaceholders(
    lineItemNotesPlainText(it.notes),
    formatter: formatter,
  );

  String _discountLabel(LineItem it) =>
      discountIsAmount ? _money(it.discount) : '${_qty(it.discount)}%';

  String _taxLabel(LineItem it) {
    final parts = <String>[];
    void add(String name, Decimal rate) {
      final n = name.trim();
      final hasRate = rate != Decimal.zero;
      if (n.isEmpty && !hasRate) return;
      final rateStr = hasRate ? '${_qty(rate)}%' : '';
      parts.add(
        [if (n.isNotEmpty) n, if (rateStr.isNotEmpty) rateStr].join(' '),
      );
    }

    add(it.taxName1, it.taxRate1);
    add(it.taxName2, it.taxRate2);
    add(it.taxName3, it.taxRate3);
    return parts.join(', ');
  }
}
