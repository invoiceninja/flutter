import 'package:decimal/decimal.dart';

import 'package:admin/data/models/value/money.dart';

/// A report the server produces only as a file, read back into something a
/// screen can show.
///
/// Ten reports — profit and loss, the aged-receivable pair, the client
/// balance and sales reports, the tax summary, user and product sales — have
/// no JSON form: the server writes a CSV and that is all there is. They used
/// to be a page that said "download it". Their files are not arbitrary,
/// though. Every one is some sequence of three things:
///
/// * a **heading** — a line with one cell;
/// * **facts** — lines of a label and its value ("Total Profit, $70,109.10");
/// * a **table** — a header line and rows under it, sometimes captioned by a
///   `Currency,GBP` line because the server writes one table per currency.
///
/// separated by blank lines or rules of dashes. [parseReportDocument] reads
/// that grammar and nothing more specific, so it does not need a parser per
/// report, and a report whose file gains a column or a section still reads.
///
/// **What it deliberately does not do is trust itself.** The headers are in
/// the server's language and the layouts are the server's to change, so
/// nothing here matches on a header's text, and [parseReportDocument]
/// returns null for a file it cannot make blocks of — at which point the
/// screen offers the download it always did.
class ReportDocument {
  const ReportDocument({
    required this.title,
    required this.meta,
    required this.blocks,
  });

  /// The file's own first heading, when it leads with one.
  final String? title;

  /// Facts that come before any table or section — "Created On", "Date
  /// Range", "Company Name". About the file, not part of the report.
  final List<ReportDocFact> meta;

  final List<ReportDocBlock> blocks;

  Iterable<ReportDocTable> get tables => blocks.whereType<ReportDocTable>();

  bool get isEmpty => blocks.isEmpty;
}

sealed class ReportDocBlock {
  const ReportDocBlock();
}

/// A line that names what follows it.
class ReportDocHeading extends ReportDocBlock {
  const ReportDocHeading(this.text);

  final String text;
}

/// One label and what it comes to. [values] is every non-blank cell after
/// the label, as written: a tax summary line carries the amount twice, once
/// formatted and once bare.
class ReportDocFact {
  const ReportDocFact({required this.label, required this.values});

  final String label;
  final List<String> values;

  /// The value to show: the first, which is the formatted one where the
  /// server wrote both.
  String get value => values.isEmpty ? '' : values.first;
}

class ReportDocFacts extends ReportDocBlock {
  const ReportDocFacts(this.entries);

  final List<ReportDocFact> entries;
}

/// What a table's column holds, as far as its cells show.
enum ReportDocColumnKind {
  /// Words, dates, identifiers — shown as written.
  text,

  /// Quantities with no currency: a count, a rate, an age. Right-aligned,
  /// not totalled — a column of tax rates has no meaningful sum, and nothing
  /// in the file says which bare numbers are counts.
  number,

  /// Amounts written with a currency symbol. Right-aligned and totalled.
  money,
}

class ReportDocTable extends ReportDocBlock {
  const ReportDocTable({
    required this.header,
    required this.rows,
    required this.kinds,
    required this.values,
    this.caption,
    this.currencyCode,
  });

  /// A line the server wrote over the table, when it wrote one.
  final String? caption;

  /// The ISO code from a `Currency,GBP` caption: the currency every amount
  /// in this table is in.
  final String? currencyCode;

  final List<String> header;

  /// The cells as the server wrote them — already in the right notation for
  /// their currency, and what is shown.
  final List<List<String>> rows;

  /// One per column.
  final List<ReportDocColumnKind> kinds;

  /// The cells as quantities: `values[row][column]`, null where the cell is
  /// not a number. For totals and charts only; display uses [rows].
  final List<List<Decimal?>> values;

  /// The sum of [column], or null when it is not a money column or holds no
  /// amounts.
  Decimal? total(int column) {
    if (column < 0 || column >= kinds.length) return null;
    if (kinds[column] != ReportDocColumnKind.money) return null;
    Decimal? sum;
    for (final row in values) {
      final v = column < row.length ? row[column] : null;
      if (v != null) sum = (sum ?? Decimal.zero) + v;
    }
    return sum;
  }
}

/// How a currency writes its numbers, by ISO code — so `€1.717,00` under a
/// `Currency,EUR` caption is read as one thousand seven hundred and
/// seventeen. Null for a code the caller does not know, where the cell is
/// read by its own shape instead.
typedef ReportDocNumberStyles = FormattedNumberStyle? Function(String code);

/// [csv] as a [ReportDocument], or null when it is not one this can read —
/// empty, or no table and no facts in it at all.
ReportDocument? parseReportDocument(
  String csv, {
  ReportDocNumberStyles? numberStyleFor,
  FormattedNumberStyle? defaultStyle,
}) {
  final records = parseCsvRecords(csv);
  if (records.isEmpty) return null;

  // Runs of records between blank lines and dashed rules.
  final runs = <List<List<String>>>[];
  var current = <List<String>>[];
  void flush() {
    if (current.isNotEmpty) runs.add(current);
    current = <List<String>>[];
  }

  for (final record in records) {
    if (_isBlank(record) || _isRule(record)) {
      flush();
    } else {
      current.add(record);
    }
  }
  flush();
  if (runs.isEmpty) return null;

  String? title;
  final meta = <ReportDocFact>[];
  final blocks = <ReportDocBlock>[];
  // Facts are "about the file" only until the report itself has started.
  var started = false;

  for (final run in runs) {
    String? caption;
    String? currencyCode;
    // Label-and-value lines met so far in this run, not yet placed.
    var pending = <ReportDocFact>[];
    void placeFacts() {
      final facts = pending;
      pending = <ReportDocFact>[];
      if (facts.isEmpty) return;
      final figures = facts.any((f) => f.values.any(_isNumberLike));
      if (!figures &&
          started &&
          facts.length == 1 &&
          facts.single.values.length == 1) {
        // One line of two words, inside the report: the header of a table
        // the server wrote no rows under ("Tax Name, Tax Amount" when no
        // tax was charged). As a fact it would read "Tax Name: Tax Amount".
        return;
      }
      // A statement begins at its first figure: "Company Name" and "Date
      // Range" are about the file, "Total Revenue" is the report.
      if (!started && !figures) {
        meta.addAll(facts);
      } else {
        blocks.add(ReportDocFacts(facts));
        started = true;
      }
    }

    for (var i = 0; i < run.length; i++) {
      final cells = _trimmed(run[i]);
      if (cells.isEmpty) continue;
      if (cells.length == 1) {
        placeFacts();
        // A heading. The file's very first is its title.
        if (title == null && blocks.isEmpty && meta.isEmpty && !started) {
          title = cells.single;
        } else {
          blocks.add(ReportDocHeading(cells.single));
          started = true;
        }
        continue;
      }
      // The `Currency,GBP` line the server puts over a per-currency table.
      if (cells.length == 2 &&
          _kCurrencyCode.hasMatch(cells[1]) &&
          i + 1 < run.length &&
          _trimmed(run[i + 1]).length > 2) {
        placeFacts();
        caption = cells.join(' ');
        currencyCode = cells[1];
        continue;
      }
      if (_looksTabular(run, i)) {
        placeFacts();
        final style =
            (currencyCode == null
                ? null
                : numberStyleFor?.call(currencyCode)) ??
            defaultStyle;
        final table = _table(
          run.sublist(i),
          caption: caption,
          currencyCode: currencyCode,
          style: style,
        );
        if (table != null) {
          blocks.add(table);
          started = true;
        }
        // A table runs to the end of its run.
        break;
      }
      // Neither: a label and what follows it. It may still be followed by a
      // table — the server does not always leave a blank line between a
      // file's preamble and its first section.
      final fact = _fact(run[i]);
      if (fact != null) pending.add(fact);
    }
    placeFacts();
  }

  if (blocks.isEmpty) return null;
  return ReportDocument(title: title, meta: meta, blocks: blocks);
}

final _kCurrencyCode = RegExp(r'^[A-Z]{3}$');

bool _isBlank(List<String> record) => record.every((c) => c.trim().isEmpty);

/// A rule of dashes the server draws between the parts of a statement.
bool _isRule(List<String> record) =>
    record.length == 1 && RegExp(r'^-{3,}$').hasMatch(record.single.trim());

List<String> _trimmed(List<String> record) {
  // Trailing empties are padding, not columns.
  var end = record.length;
  while (end > 0 && record[end - 1].trim().isEmpty) {
    end--;
  }
  return [for (var i = 0; i < end; i++) record[i].trim()];
}

/// Whether the records from [start] are a header and rows: a first line of
/// three or more cells none of which is a number, or of two such cells with
/// rows of numbers under it.
bool _looksTabular(List<List<String>> run, int start) {
  if (start >= run.length) return false;
  final head = _trimmed(run[start]);
  if (head.length < 2) return false;
  // A header names every column and none of the names is a number. A line
  // with a blank cell in it is the server padding a label and its value
  // (`"Created On"," ",08/Oct/2026`).
  if (head.any((c) => c.isEmpty || c == '-' || _isNumberLike(c))) return false;
  // A header has rows under it. A last line of several words is a label and
  // its values ("Date Range, 01/Jan/2026, 31/Dec/2026"), whatever it looks
  // like.
  if (start == run.length - 1) return false;
  if (head.length >= 3) return true;
  // Two cells: a label and its value look the same as a two-column header.
  // It is a header when what follows is rows of the same width that hold
  // numbers.
  for (var i = start + 1; i < run.length; i++) {
    final cells = _trimmed(run[i]);
    if (cells.length != 2 || !_isNumberLike(cells[1])) return false;
  }
  return true;
}

ReportDocFact? _fact(List<String> record) {
  final cells = [
    for (final c in record)
      if (c.trim().isNotEmpty && c.trim() != '-') c.trim(),
  ];
  if (cells.isEmpty) return null;
  return ReportDocFact(label: cells.first, values: cells.sublist(1));
}

ReportDocTable? _table(
  List<List<String>> records, {
  required String? caption,
  required String? currencyCode,
  required FormattedNumberStyle? style,
}) {
  if (records.isEmpty) return null;
  final header = _trimmed(records.first);
  final width = header.length;
  if (width == 0) return null;
  final rows = <List<String>>[];
  for (final record in records.skip(1)) {
    final cells = [for (final c in record) c.trim()];
    // Pad a short row and fold a long one's overflow into its last cell, so
    // every row is exactly as wide as the header it sits under.
    if (cells.length < width) {
      cells.addAll(List.filled(width - cells.length, ''));
    } else if (cells.length > width) {
      final extra = cells.sublist(width).where((c) => c.isNotEmpty);
      final kept = cells.sublist(0, width);
      if (extra.isNotEmpty) kept[width - 1] = [kept.last, ...extra].join(' ');
      rows.add(kept);
      continue;
    }
    rows.add(cells);
  }

  final values = [
    for (final row in rows) [for (final cell in row) _number(cell, style)],
  ];
  final kinds = <ReportDocColumnKind>[];
  for (var c = 0; c < width; c++) {
    var filled = 0;
    var numeric = 0;
    var symbols = 0;
    for (var r = 0; r < rows.length; r++) {
      final cell = rows[r][c];
      if (cell.isEmpty) continue;
      filled++;
      if (values[r][c] != null) {
        numeric++;
        if (_hasCurrencySymbol(cell)) symbols++;
      }
    }
    if (filled == 0 || numeric < filled) {
      // One cell that is not a number makes it a column of text: an invoice
      // number column is all digits until "INV-0042".
      kinds.add(ReportDocColumnKind.text);
      for (final row in values) {
        row[c] = null;
      }
    } else if (symbols * 2 > numeric) {
      kinds.add(ReportDocColumnKind.money);
    } else {
      kinds.add(ReportDocColumnKind.number);
    }
  }
  return ReportDocTable(
    caption: caption,
    currencyCode: currencyCode,
    header: header,
    rows: rows,
    kinds: kinds,
    values: values,
  );
}

/// Characters a formatted amount is made of besides its currency symbol.
final _kNumberBody = RegExp(r"^[\d.,\s'  ()+-]+$");

bool _hasCurrencySymbol(String cell) => !_kNumberBody.hasMatch(cell.trim());

bool _isNumberLike(String cell) => _number(cell, null) != null;

/// [cell] as a quantity, or null when it is not one.
///
/// What is allowed around the digits is a currency symbol or code, and
/// nothing else — and three kinds of thing look like that without being it:
///
/// * **An identifier that is all digits.** `0004` is a client number;
///   reading it as four would right-align it and total it. A leading zero
///   followed by another digit is the tell — an amount is never written so.
/// * **A word joined to a number by a hyphen.** `July-2026` is a column
///   header in the client sales file, `INV-0042` an invoice number. Taken
///   for "-2026 in the currency July", a month header stopped being a
///   header and its whole table was read as loose lines.
/// * **A word and a bare number.** `May 2026`. Letters beside the digits
///   are a currency only as an ISO code (`USD 100`) or beside a figure that
///   is *formatted* as an amount (`kr 1 250,00`).
Decimal? _number(String cell, FormattedNumberStyle? style) {
  final text = cell.trim();
  if (text.isEmpty || !text.contains(RegExp(r'\d'))) return null;
  // Peel what stands before the figure and after it; what is left must be
  // nothing but a number.
  final lead = RegExp(r'^[^\d(+-]+').stringMatch(text) ?? '';
  final rest = text.substring(lead.length);
  final trail = RegExp(r'[^\d)]+$').stringMatch(rest) ?? '';
  final body = rest.substring(0, rest.length - trail.length).trim();
  if (body.isEmpty || !_kNumberBody.hasMatch(body)) return null;
  // A symbol, not a sentence that happens to hold a figure ("Invoice 0007",
  // "120+ Days").
  final affix = '${lead.trim()}${trail.trim()}';
  if (affix.length > 4) return null;
  if (RegExp(r'\p{L}', unicode: true).hasMatch(affix)) {
    if (RegExp(r'^[+-]').hasMatch(body)) return null;
    final isoCode = RegExp(r'^[A-Z]{3}$').hasMatch(affix);
    final formatted = RegExp("[.,\\s'\u00A0\u202F]").hasMatch(body);
    if (!isoCode && !formatted) return null;
  }
  if (RegExp(r'^[+-]?0\d').hasMatch(body)) return null;
  // A range (`0 - 30`), a phone number or an ISO date is not an amount.
  if (RegExp(r'\d\s*-\s*\d').hasMatch(body)) return null;
  try {
    return parseFormattedMoney(body, style: style);
  } catch (_) {
    return null;
  }
}

/// [csv] as records of cells, by RFC 4180: a quoted cell may hold commas,
/// line breaks and doubled quotes. Blank lines are kept (as a single empty
/// cell) because here they mean something — they separate a file's parts.
List<List<String>> parseCsvRecords(String csv) {
  var text = csv;
  // A byte-order mark is not part of the first cell.
  if (text.startsWith('﻿')) text = text.substring(1);
  final records = <List<String>>[];
  var record = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  var wasQuoted = false;
  void endCell() {
    record.add(cell.toString());
    cell.clear();
    wasQuoted = false;
  }

  void endRecord() {
    endCell();
    records.add(record);
    record = <String>[];
  }

  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(ch);
      }
      continue;
    }
    if (ch == '"' && cell.isEmpty && !wasQuoted) {
      quoted = true;
      wasQuoted = true;
    } else if (ch == ',') {
      endCell();
    } else if (ch == '\n') {
      endRecord();
    } else if (ch == '\r') {
      // Part of a CRLF, or a bare CR line ending.
      if (i + 1 < text.length && text[i + 1] == '\n') continue;
      endRecord();
    } else {
      cell.write(ch);
    }
  }
  if (cell.isNotEmpty || record.isNotEmpty) endRecord();
  return records;
}
