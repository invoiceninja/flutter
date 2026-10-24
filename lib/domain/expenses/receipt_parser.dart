/// Turns a receipt's recognised text into expense fields — the half of
/// receipt OCR that is the same on every platform (`docs/receipt-ocr.md`).
///
/// A leaf: models and utils only, so every rule is unit-testable without an
/// OCR engine. The engines (Vision, ML Kit, Windows.Media.Ocr) hand over text
/// fragments with boxes; [rebuildRows] puts them back into printed rows,
/// because no engine returns "TOTAL" and its amount together — ML Kit groups
/// text by column, Vision by observation — and every rule below matches rows.
library;

import 'dart:math' as math;

import 'package:decimal/decimal.dart';

import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/utils/search_fold.dart';

/// One piece of recognised text and where it sits on the page, in
/// normalised top-left coordinates (0–1 on both axes). Engines that report
/// pixels or a bottom-left origin are converted before they get here.
class OcrFragment {
  const OcrFragment(this.text, this.left, this.top, this.width, this.height);

  /// An engine-shaped map (`text`, `x`, `y`, `w`, `h`) — the channel's wire
  /// format. Null for an entry without text.
  static OcrFragment? fromMap(Object? m) {
    if (m is! Map) return null;
    final text = m['text'];
    if (text is! String || text.trim().isEmpty) return null;
    double n(Object? v) => v is num ? v.toDouble() : 0;
    return OcrFragment(text, n(m['x']), n(m['y']), n(m['w']), n(m['h']));
  }

  final String text;
  final double left;
  final double top;
  final double width;
  final double height;

  double get bottom => top + height;
  double get centerY => top + height / 2;
}

/// A printed row: the fragments that share a horizontal band, left to right.
class ReceiptRow {
  ReceiptRow(this.fragments);

  final List<OcrFragment> fragments;

  late final String text = fragments.map((f) => f.text.trim()).join(' ');
  late final String folded = foldSearchText(text);
  double get top => fragments.map((f) => f.top).reduce(math.min);
}

/// How sure the parser is of a value it read.
enum ReceiptConfidence {
  /// Found where a receipt prints it (a TOTAL row, an unambiguous date).
  sure,

  /// A best guess — the largest amount, a day/month that reads both ways, a
  /// total with an unfilled tip line. Shown as "please check".
  check,
}

class ReceiptField<T> {
  const ReceiptField(this.value, this.confidence);
  final T value;
  final ReceiptConfidence confidence;
}

/// One tax line. Either half may be missing ("VAT 19%" with no amount, or a
/// "GST 1.23" with no rate).
class ReceiptTax {
  const ReceiptTax({required this.name, this.rate, this.amount});
  final String name;
  final Decimal? rate;
  final Decimal? amount;
}

/// What a receipt says, as far as the rules could tell.
class ReceiptScan {
  const ReceiptScan({
    this.total,
    this.date,
    this.taxes = const [],
    this.vendorName,
    this.currencyCode,
    this.receiptNumber,
  });

  final ReceiptField<Decimal>? total;
  final ReceiptField<Date>? date;
  final List<ReceiptTax> taxes;

  /// Cleaned for display and matching: no store number, no card-processor
  /// prefix, title case instead of a till's capitals.
  final String? vendorName;

  /// An ISO code, only when the receipt names one or prints a symbol that can
  /// mean nothing else.
  final String? currencyCode;
  final String? receiptNumber;

  bool get isEmpty =>
      total == null &&
      date == null &&
      taxes.isEmpty &&
      vendorName == null &&
      currencyCode == null &&
      receiptNumber == null;
}

/// The order a company writes a numeric date in.
enum DateOrder { dmy, mdy, ymd }

/// [DateOrder] from a company date pattern (`dd/MM/yyyy`, `M/d/yyyy`,
/// `yyyy-MM-dd`, `d. MMM yyyy`): whichever of day and month comes first.
DateOrder dateOrderOf(String? pattern) {
  if (pattern == null) return DateOrder.mdy;
  final d = pattern.indexOf('d');
  final m = pattern.indexOf('M');
  final y = pattern.indexOf('y');
  if (y >= 0 && (d < 0 || y < d) && (m < 0 || y < m)) return DateOrder.ymd;
  if (d >= 0 && m >= 0 && d < m) return DateOrder.dmy;
  return DateOrder.mdy;
}

class ReceiptParseContext {
  const ReceiptParseContext({
    required this.today,
    this.dateOrder = DateOrder.mdy,
    this.currencies = const [],
    this.companyCurrency,
  });

  final Date today;
  final DateOrder dateOrder;
  final List<Currency> currencies;
  final Currency? companyCurrency;
}

// ── Rows ─────────────────────────────────────────────────────────────────

/// [fragments] grouped into printed rows, top to bottom, each left to right.
/// A fragment joins a row when its vertical centre falls inside the row's
/// band — so a label and an amount printed on the same line meet again even
/// when the engine returned them in different blocks.
List<ReceiptRow> rebuildRows(Iterable<OcrFragment> fragments) {
  final sorted = fragments.where((f) => f.text.trim().isNotEmpty).toList()
    ..sort((a, b) => a.centerY.compareTo(b.centerY));
  final rows = <List<OcrFragment>>[];
  final bands = <(double, double)>[];
  for (final f in sorted) {
    var placed = false;
    for (var i = rows.length - 1; i >= 0 && i >= rows.length - 3; i--) {
      final (top, bottom) = bands[i];
      if (f.centerY >= top && f.centerY <= bottom) {
        rows[i].add(f);
        // The band grows to hold the row's fragments; a fragment joins only
        // by its centre, so a tall one can't pull in the rows around it.
        bands[i] = (math.min(top, f.top), math.max(bottom, f.bottom));
        placed = true;
        break;
      }
    }
    if (!placed) {
      rows.add([f]);
      bands.add((f.top, f.bottom));
    }
  }
  return [
    for (final r in rows)
      ReceiptRow(r..sort((a, b) => a.left.compareTo(b.left))),
  ];
}

// ── Amounts ──────────────────────────────────────────────────────────────

/// A number on a receipt and where it was.
class _Amount {
  const _Amount(this.value, this.hasDecimals, this.start, this.end);
  final Decimal value;
  final bool hasDecimals;
  final int start;
  final int end;
}

final _amountPattern = RegExp(
  // Grouping by NBSP / thin space / `'` / `.` / `,` anywhere; by a plain
  // space only before a comma decimal (`1 234,56`) — elsewhere a plain space
  // is just a gap between columns (`ROOM 2 189.00` is 2 at 189.00).
  r"(?<![\d.,'])(-)?(\d{1,3}(?:[\u00A0\u202F'.,]\d{3})+|\d{1,3}(?: \d{3})+(?=,\d{2}(?!\d))|\d+)"
  r'(?:([.,])(\d{1,3}))?(-)?(?![\d%])',
);

/// Every amount in [text], read with [precision] decimal places: the last
/// `.` or `,` followed by exactly [precision] digits is the decimal point,
/// any other separator groups thousands. A `1.234` is 1234 at precision 2
/// and 1.234 at precision 3 (KWD).
List<_Amount> _amounts(String text, int precision) {
  final out = <_Amount>[];
  for (final m in _amountPattern.allMatches(text)) {
    final negative = m.group(1) != null || m.group(5) != null;
    var whole = m.group(2)!;
    final sep = m.group(3);
    final frac = m.group(4);
    String digits;
    var hasDecimals = false;
    if (sep != null && frac != null) {
      if (precision > 0 && frac.length == precision) {
        digits = '${whole.replaceAll(RegExp(r'[^\d]'), '')}.$frac';
        hasDecimals = true;
      } else if (frac.length == 3) {
        // A thousands group after all: `1.234` at precision 2, `1,500` JPY.
        digits = '${whole.replaceAll(RegExp(r'[^\d]'), '')}$frac';
      } else {
        // `12.5` — one decimal digit, still a decimal.
        digits = '${whole.replaceAll(RegExp(r'[^\d]'), '')}.$frac';
        hasDecimals = true;
      }
    } else if (precision == 3 &&
        RegExp(r'^\d{1,3}[.,]\d{3}$').hasMatch(whole)) {
      // A three-decimal currency (KWD, BHD, OMR): `3.250` is 3.25, not the
      // thousands group it would be anywhere else.
      digits = whole.replaceAll(',', '.');
      hasDecimals = true;
    } else {
      // `1,234` alone is a thousands group.
      whole = whole.replaceAll(RegExp(r'[^\d]'), '');
      digits = whole;
    }
    final value = Decimal.tryParse(digits);
    if (value == null) continue;
    out.add(_Amount(negative ? -value : value, hasDecimals, m.start, m.end));
  }
  return out;
}

/// `19%`, `8.625 %`, and Turkish `%18`. Not the tail of `100%`.
final _percentPattern = RegExp(
  r'(?<![\d.,])(\d{1,2}(?:[.,]\d{1,3})?)\s?%|%\s?(\d{1,2}(?:[.,]\d{1,3})?)(?![\d.,])',
);

Decimal? _percent(String text) {
  final m = _percentPattern.firstMatch(text);
  if (m == null) return null;
  return Decimal.tryParse((m.group(1) ?? m.group(2)!).replaceAll(',', '.'));
}

/// The amounts of [row] that are money: not a percentage, not part of a
/// date, a time or a phone number.
List<_Amount> _moneyIn(ReceiptRow row, int precision) {
  var text = row.text;
  // Blank out what only looks like a number.
  for (final p in [_percentPattern, ..._dateLike, _timeLike, _phoneLike]) {
    text = text.replaceAllMapped(p, (m) => ' ' * m.group(0)!.length);
  }
  return [
    for (final a in _amounts(text, precision))
      if (a.value != Decimal.zero) a,
  ];
}

final _dateLike = [
  RegExp(r'\b\d{4}[-/.]\d{1,2}[-/.]\d{1,2}\b'),
  RegExp(r'\b\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}\b'),
];

/// `01.02.25.67.89` — a dotted phone number, which would otherwise read as a
/// date.
final _dottedRun = RegExp(r'\d{1,2}(?:[-/.]\d{2}){3,}');
final _timeLike = RegExp(r'\b\d{1,2}:\d{2}(?::\d{2})?\b');
final _phoneLike = RegExp(r'(?:\+|\()?\d{2,4}[)\s-]+\d{3,4}[\s-]\d{3,4}');

// ── Keywords ─────────────────────────────────────────────────────────────

bool _hasWord(String folded, Iterable<String> words) {
  for (final w in words) {
    for (var i = folded.indexOf(w); i >= 0; i = folded.indexOf(w, i + 1)) {
      final before = i == 0 ? ' ' : folded[i - 1];
      final afterAt = i + w.length;
      final after = afterAt >= folded.length ? ' ' : folded[afterAt];
      if (!_isLetter(before) && !_isLetter(after)) return true;
    }
  }
  return false;
}

bool _isLetter(String c) => RegExp(r'[a-zÀ-ɏ]').hasMatch(c);

const _totalWords = [
  'total',
  'grand total',
  'amount due',
  'balance due',
  'total due',
  'amount',
  'to pay',
  'gesamt',
  'gesamtbetrag',
  'gesamtsumme',
  'endsumme',
  'summe',
  'zu zahlen',
  'endbetrag',
  'total ttc',
  'net a payer',
  'montant',
  'importe',
  'totale',
  'totaal',
  'te betalen',
  'totalt',
  'att betala',
  'summa',
  'yhteensa',
  'i alt',
  'lacznie',
  'razem',
  'suma',
  'celkem',
  'valor total',
  'total a pagar',
  'totale complessivo',
];

/// Totals that name themselves so plainly that no exclusion below can be
/// meant — `Net à payer` despite `net`.
const _strongTotalWords = [
  'grand total',
  'amount due',
  'balance due',
  'total due',
  'total ttc',
  'net a payer',
  'te betalen',
  'zu zahlen',
  'a pagar',
  'att betala',
];

const _notTotalWords = [
  'subtotal',
  'sub total',
  'sub-total',
  'zwischensumme',
  'sous-total',
  'sous total',
  'subtotaal',
  'subtotale',
  'delsumma',
  'mellemsum',
  'net',
  'netto',
  'nettobetrag',
  'total ht',
  'ht',
  'excl',
  'excluding',
  'exkl',
  'ohne',
  'hors taxe',
  'sans tva',
  'saving',
  'savings',
  'saved',
  'discount',
  'rabatt',
  'remise',
  'descuento',
  'sconto',
  'korting',
  'items',
  'artikel',
  'articles',
  'qty',
  'change',
  'cash',
  'bar',
  'gegeben',
  'ruckgeld',
  'wechselgeld',
  'rendu',
  'cambio',
  'resto',
  'tip',
  'tips',
  'gratuity',
  'trinkgeld',
  'pourboire',
  'propina',
  'mancia',
  'fooi',
  'tendered',
  'tender',
  'entregado',
  'cashback',
  'cash back',
  'paid',
  'card',
  'visa',
  'mastercard',
  'amex',
  'points',
  'loyalty',
  'balance 0',
  'previous balance',
];

const _taxWords = [
  'steuer',
  'kdv',
  'mva',
  'ddv',
  'pdv',
  'vat',
  'tax',
  'gst',
  'hst',
  'pst',
  'qst',
  'mwst',
  'ust',
  'tva',
  'iva',
  'btw',
  'moms',
  'alv',
  'igv',
  'cgst',
  'sgst',
  'igst',
  'dph',
  'ptu',
  'vat%',
  'sales tax',
  'mehrwertsteuer',
  'umsatzsteuer',
];

const _taxIdWords = [
  'no',
  'nr',
  'reg',
  'registration',
  'id',
  'idnr',
  'uid',
  'number',
  'nummer',
  'invoice',
  'inv',
];

const _inclusiveWords = [
  'incl',
  'inkl',
  'including',
  'included',
  'inclusive',
  'ttc',
  'enthalten',
  'inclus',
  'incluido',
  'incluso',
  'inbegrepen',
];

const _tipWords = [
  'tip',
  'tips',
  'gratuity',
  'trinkgeld',
  'pourboire',
  'propina',
  'mancia',
  'fooi',
  'dricks',
  'drikkepenge',
];

const _dateWords = [
  'date',
  'datum',
  'fecha',
  'data',
  'dato',
  'paivamaara',
  'pvm',
  'fecha:',
];

const _boilerplate = [
  'receipt',
  'welcome',
  'tax invoice',
  'invoice',
  'thank you',
  'thanks',
  'kassenbon',
  'quittung',
  'beleg',
  'rechnung',
  'ticket',
  'facture',
  'factura',
  'fattura',
  'scontrino',
  'kassabon',
  'kvitto',
  'kvittering',
  'customer copy',
  'merchant copy',
  'duplicate',
  'tel',
  'phone',
  'www',
  'http',
  'vat no',
  'vat reg',
  'abn',
  'gst no',
  'ust-id',
  'siret',
  'order',
  'server',
  'cashier',
  'kasse',
  'caisse',
];

// ── Dates ────────────────────────────────────────────────────────────────

/// Month names a receipt is likely to print, folded, in the app's main
/// languages. Hand-held rather than read from `intl`'s locale data, which
/// would add every locale's symbols to the app for a dozen words.
const _months = <String, List<String>>{
  'en': [
    'january',
    'february',
    'march',
    'april',
    'may',
    'june',
    'july',
    'august',
    'september',
    'october',
    'november',
    'december',
  ],
  'de': [
    'januar',
    'februar',
    'marz',
    'april',
    'mai',
    'juni',
    'juli',
    'august',
    'september',
    'oktober',
    'november',
    'dezember',
  ],
  'fr': [
    'janvier',
    'fevrier',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'aout',
    'septembre',
    'octobre',
    'novembre',
    'decembre',
  ],
  'es': [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ],
  'it': [
    'gennaio',
    'febbraio',
    'marzo',
    'aprile',
    'maggio',
    'giugno',
    'luglio',
    'agosto',
    'settembre',
    'ottobre',
    'novembre',
    'dicembre',
  ],
  'nl': [
    'januari',
    'februari',
    'maart',
    'april',
    'mei',
    'juni',
    'juli',
    'augustus',
    'september',
    'oktober',
    'november',
    'december',
  ],
  'pt': [
    'janeiro',
    'fevereiro',
    'marco',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ],
  'sv': [
    'januari',
    'februari',
    'mars',
    'april',
    'maj',
    'juni',
    'juli',
    'augusti',
    'september',
    'oktober',
    'november',
    'december',
  ],
  'da': [
    'januar',
    'februar',
    'marts',
    'april',
    'maj',
    'juni',
    'juli',
    'august',
    'september',
    'oktober',
    'november',
    'december',
  ],
  'fi': [
    'tammikuu',
    'helmikuu',
    'maaliskuu',
    'huhtikuu',
    'toukokuu',
    'kesakuu',
    'heinakuu',
    'elokuu',
    'syyskuu',
    'lokakuu',
    'marraskuu',
    'joulukuu',
  ],
  'pl': [
    'stycznia',
    'lutego',
    'marca',
    'kwietnia',
    'maja',
    'czerwca',
    'lipca',
    'sierpnia',
    'wrzesnia',
    'pazdziernika',
    'listopada',
    'grudnia',
  ],
};

/// The abbreviations tills print, folded, by month. Checked before the
/// prefix rule below: `mar` is March on every receipt, though Finnish
/// `marraskuu` (November) also starts with it.
const _monthAbbreviations = <String, int>{
  'jan': 1,
  'janv': 1,
  'ene': 1,
  'gen': 1,
  'tam': 1,
  'sty': 1,
  'feb': 2,
  'febr': 2,
  'fev': 2,
  'fevr': 2,
  'hel': 2,
  'lut': 2,
  'mar': 3,
  'mrt': 3,
  'mars': 3,
  'maa': 3,
  'apr': 4,
  'avr': 4,
  'abr': 4,
  'huh': 4,
  'kwi': 4,
  'may': 5,
  'mai': 5,
  'mei': 5,
  'mag': 5,
  'maj': 5,
  'tou': 5,
  'jun': 6,
  'juin': 6,
  'giu': 6,
  'kes': 6,
  'cze': 6,
  'jul': 7,
  'juil': 7,
  'lug': 7,
  'hei': 7,
  'lip': 7,
  'aug': 8,
  'aout': 8,
  'ago': 8,
  'elo': 8,
  'sie': 8,
  'sep': 9,
  'sept': 9,
  'set': 9,
  'syy': 9,
  'wrz': 9,
  'oct': 10,
  'okt': 10,
  'ott': 10,
  'out': 10,
  'lok': 10,
  'paz': 10,
  'nov': 11,
  'lis': 11,
  'dec': 12,
  'dez': 12,
  'dic': 12,
  'jou': 12,
  'gru': 12,
};

/// The month a folded word names — a till's abbreviation, the full name, or
/// failing those an abbreviation that only one month (across every
/// language) starts with. Null for anything else.
int? _monthOf(String word) {
  final w = word.replaceAll('.', '');
  if (w.length < 3) return null;
  final abbreviation = _monthAbbreviations[w];
  if (abbreviation != null) return abbreviation;
  final hits = <int>{};
  for (final names in _months.values) {
    for (var i = 0; i < 12; i++) {
      if (names[i] == w || (w.length >= 3 && names[i].startsWith(w))) {
        hits.add(i + 1);
      }
    }
  }
  return hits.length == 1 ? hits.single : null;
}

final _ymd = RegExp(r'\b(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})\b');
final _numericDate = RegExp(
  r'(?<![\d][-/.])\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})\b(?![-/.]\d)',
);

/// `15 Mar 2026`, `15. März 2026`, `15-Mar-2026`, `15/MAR/26`, `15MAR26`.
final _dayMonthName = RegExp(
  r'\b(\d{1,2})\.?[\s\-/]*([a-z]{3,})\.?[\s\-/,]*(\d{2,4})\b',
);
final _monthNameDay = RegExp(r'\b([a-z]{3,})\.?\s+(\d{1,2}),?\s+(\d{2,4})\b');

Date? _valid(int y, int m, int d) {
  if (y < 100) y += 2000;
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  final dt = DateTime(y, m, d);
  if (dt.month != m || dt.day != d) return null;
  return Date(y, m, d);
}

bool _inBounds(Date d, Date today) {
  // UTC: a local DateTime loses an hour the day the clocks change, and
  // "tomorrow" would fall outside the bound.
  final dt = DateTime.utc(d.year, d.month, d.day);
  final t = DateTime.utc(today.year, today.month, today.day);
  return !dt.isAfter(t.add(const Duration(days: 1))) &&
      !dt.isBefore(t.subtract(const Duration(days: 730)));
}

/// The dates [row] can be read as, each with how sure that reading is.
List<ReceiptField<Date>> _datesIn(
  ReceiptRow row,
  ReceiptParseContext ctx, {
  required bool dayFirstHint,
}) {
  final out = <ReceiptField<Date>>[];
  if (_dottedRun.hasMatch(row.text)) return out;
  for (final m in _ymd.allMatches(row.text)) {
    final d = _valid(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    if (d != null && _inBounds(d, ctx.today)) {
      out.add(ReceiptField(d, ReceiptConfidence.sure));
    }
  }
  for (final m in _numericDate.allMatches(row.text)) {
    final a = int.parse(m[1]!), b = int.parse(m[2]!), y = int.parse(m[3]!);
    final dmy = _valid(y, b, a);
    final mdy = _valid(y, a, b);
    final readings = [
      if (dmy != null && _inBounds(dmy, ctx.today)) (dmy, DateOrder.dmy),
      if (mdy != null && _inBounds(mdy, ctx.today)) (mdy, DateOrder.mdy),
    ];
    if (readings.isEmpty) continue;
    if (readings.length == 1 || readings[0].$1 == readings[1].$1) {
      out.add(ReceiptField(readings.first.$1, ReceiptConfidence.sure));
      continue;
    }
    // Both readings are real dates. The company's order wins, then a
    // day-first currency; still a guess, so it asks to be checked.
    final preferred = switch (ctx.dateOrder) {
      DateOrder.dmy => DateOrder.dmy,
      DateOrder.mdy => dayFirstHint ? DateOrder.dmy : DateOrder.mdy,
      DateOrder.ymd => dayFirstHint ? DateOrder.dmy : DateOrder.mdy,
    };
    final pick = readings.firstWhere((r) => r.$2 == preferred).$1;
    out.add(ReceiptField(pick, ReceiptConfidence.check));
  }
  for (final m in _dayMonthName.allMatches(row.folded)) {
    final month = _monthOf(m[2]!);
    if (month == null) continue;
    final d = _valid(int.parse(m[3]!), month, int.parse(m[1]!));
    if (d != null && _inBounds(d, ctx.today)) {
      out.add(ReceiptField(d, ReceiptConfidence.sure));
    }
  }
  for (final m in _monthNameDay.allMatches(row.folded)) {
    final month = _monthOf(m[1]!);
    if (month == null) continue;
    final d = _valid(int.parse(m[3]!), month, int.parse(m[2]!));
    if (d != null && _inBounds(d, ctx.today)) {
      out.add(ReceiptField(d, ReceiptConfidence.sure));
    }
  }
  return out;
}

// ── Currency ─────────────────────────────────────────────────────────────

/// Symbols that name one currency only. `$`, `kr`, `¥`, `R`, `Fr` are left
/// out on purpose: each is shared, and a wrong currency is worse than none.
const _uniqueSymbols = <String, String>{
  '€': 'EUR',
  '£': 'GBP',
  '₹': 'INR',
  '₩': 'KRW',
  '₪': 'ILS',
  '₺': 'TRY',
  '₽': 'RUB',
  'zł': 'PLN',
  'kč': 'CZK',
  '฿': 'THB',
  '₫': 'VND',
  '₱': 'PHP',
  'r\$': 'BRL',
  'chf': 'CHF',
  'a\$': 'AUD',
  'c\$': 'CAD',
  'nz\$': 'NZD',
  'us\$': 'USD',
  'hk\$': 'HKD',
  's\$': 'SGD',
  'ft': 'HUF',
  'lei': 'RON',
};

String? _currencyIn(List<ReceiptRow> rows, ReceiptParseContext ctx) {
  final codes = {for (final c in ctx.currencies) c.code.toUpperCase()};
  // An ISO code counts only beside an amount: `ALL SALES FINAL`, `LG CUP`
  // and `TOP UP` are words that happen to be currency codes.
  final isoPattern = RegExp(r'(?<![A-Za-z])([A-Z]{3})(?![A-Za-z])');
  for (final row in rows.reversed) {
    for (final m in isoPattern.allMatches(row.text)) {
      final code = m[1]!;
      if (codes.contains(code) && _besideAmount(row.text, m.start, m.end)) {
        return code;
      }
    }
  }
  for (final row in rows.reversed) {
    final lower = row.text.toLowerCase();
    for (final e in _uniqueSymbols.entries) {
      for (
        var at = lower.indexOf(e.key);
        at >= 0;
        at = lower.indexOf(e.key, at + 1)
      ) {
        final end = at + e.key.length;
        if (RegExp(r'[a-z]').hasMatch(e.key)) {
          // A letter symbol (`ft`, `lei`, `chf`, `zł`) is a word of its
          // own, beside an amount: not `FT LAUDERDALE`, not `50 FT CORD`.
          final word =
              !_isLetter(at == 0 ? ' ' : lower[at - 1]) &&
              !_isLetter(end >= lower.length ? ' ' : lower[end]);
          if (!word || !_besideAmount(lower, at, end, priceLike: true)) {
            continue;
          }
        }
        if (codes.isEmpty || codes.contains(e.value)) return e.value;
      }
    }
  }
  return null;
}

/// Whether a digit sits right before [start] or right after [end] in
/// [text] (one space allowed). [priceLike] asks for an amount with
/// decimals on that side — `50 FT` is a length, `1 500 Ft` a price.
bool _besideAmount(String text, int start, int end, {bool priceLike = false}) {
  final before = text.substring(0, start);
  final after = text.substring(end);
  if (priceLike) {
    return RegExp(r'\d[.,]\d{1,3}\s?$').hasMatch(before) ||
        RegExp(r'^\s?\d[\d .,\u00A0]*[.,]\d').hasMatch(after) ||
        RegExp(r'\d{1,3}(?:[ .\u00A0]\d{3})+\s?$').hasMatch(before);
  }
  return RegExp(r'\d\s?$').hasMatch(before) ||
      RegExp(r'^[\s:]?\s?\(?\s?\d').hasMatch(after) ||
      // The code closing a row that holds an amount: `23,47 EUR`.
      (RegExp(r'^\)?\s*$').hasMatch(after) &&
          RegExp(r'\d[.,]\d').hasMatch(before));
}

// ── Vendor ───────────────────────────────────────────────────────────────

/// An address line: a house number before a street word (`399 4th St`,
/// `Hauptstr. 12` the other way round), a full street word anywhere, or a
/// postcode beside a place (`MA 02108`, `10115 Berlin`). Not a name that
/// merely starts with a number (`24 Hour Fitness`) or holds `St.`
/// (`St. John's Bakery`).
final _addressLike = RegExp(
  r'^\d+[a-z]?\s+(?:\S+\s+){0,3}(?:street|st|road|rd|avenue|ave|blvd|lane|ln|'
  r'drive|dr|way|place|pl)\b'
  r'|\b(?:street|road|avenue|boulevard|strasse|straße|weg|platz|rue|calle|'
  r'straat|gatan|vej|suite)\b'
  r'|\b\p{L}+str\.?\s+\d'
  r'|\b[A-Z]{2}\s+\d{5}(?:-\d{4})?\b'
  r'|\b\d{4,5}\s+\p{Lu}\p{Ll}+',
  caseSensitive: false,
  unicode: true,
);
final _urlLike = RegExp(
  r'(https?://|www\.|\.[a-z]{2,4}\b)',
  caseSensitive: false,
);
final _processorPrefix = RegExp(
  r'^(sq|tst|sp|paypal|pp|ppl|ext|pos|sumup|izettle|zettle)\s*\*\s*',
  caseSensitive: false,
);
final _storeNumber = RegExp(
  r'\s*(#\s*\d+|\bno\.?\s*\d+|\bnr\.?\s*\d+|\bstore\s*\d+|\b\d{3,}\b)\s*',
  caseSensitive: false,
);

/// A till's vendor line made readable: `SQ *BLUE BOTTLE #102` → `Blue
/// Bottle`. Null when nothing is left.
String? cleanVendorName(String raw) {
  var s = raw.trim().replaceFirst(_processorPrefix, '');
  s = s.replaceAll(_storeNumber, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  s = s.replaceAll(RegExp(r'^[^\p{L}\d]+|[^\p{L}\d.)]+$', unicode: true), '');
  if (s.replaceAll(RegExp(r'[^\p{L}]', unicode: true), '').length < 2) {
    return null;
  }
  final letters = s.replaceAll(RegExp(r'[^\p{L}]', unicode: true), '');
  if (letters == letters.toUpperCase() && letters.length > 3) {
    s = s
        .split(' ')
        .map(
          (w) => w.isEmpty || RegExp(r'^(\p{L}\.)+$', unicode: true).hasMatch(w)
              // `S.A.`, `B.V.` stay as printed.
              ? w
              : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
  return s;
}

String? _vendorIn(List<ReceiptRow> rows) {
  for (final row in rows.take(6)) {
    final t = row.text.trim();
    final letters = t.replaceAll(RegExp(r'[^\p{L}]', unicode: true), '');
    if (letters.length < 3) continue;
    if (letters.length < t.replaceAll(' ', '').length / 2) continue;
    if (_hasWord(row.folded, _boilerplate)) continue;
    if (_urlLike.hasMatch(t) || _phoneLike.hasMatch(t)) continue;
    if (_addressLike.hasMatch(t)) continue;
    if (_dateLike.any((p) => p.hasMatch(t))) continue;
    final cleaned = cleanVendorName(t);
    if (cleaned != null) return cleaned;
  }
  return null;
}

// ── Receipt number ───────────────────────────────────────────────────────

final _receiptNumber = RegExp(
  r'\b(?:receipt|rechnung|beleg|bon|ticket|facture|factura|fattura|invoice|'
  r'inv|transaction|trans|order|kvitto|kvittering)'
  // `Bon-Nr.`, `Factura simplificada nº`: a hyphen, or one word, between.
  r'(?:[\s\-]+[a-z\u00C0-\u024F]+)?[\s\-]*'
  r'(?:no\.?|nr\.?|number|num\.?|n°|nº|#)\s*[:#.]?\s*([A-Z0-9][A-Z0-9\-/]{2,})',
  caseSensitive: false,
);

String? _receiptNumberIn(List<ReceiptRow> rows) {
  for (final row in rows) {
    final m = _receiptNumber.firstMatch(row.text);
    if (m != null && RegExp(r'\d').hasMatch(m[1]!)) return m[1];
  }
  return null;
}

// ── Parse ────────────────────────────────────────────────────────────────

/// What [rows] say a receipt was for. Never throws; a field the rules can't
/// find is null.
ReceiptScan parseReceiptRows(List<ReceiptRow> rows, ReceiptParseContext ctx) {
  if (rows.isEmpty) return const ReceiptScan();
  final currencyCode = _currencyIn(rows, ctx);
  final currency = currencyCode == null
      ? ctx.companyCurrency
      : ctx.currencies
                .where((c) => c.code.toUpperCase() == currencyCode)
                .firstOrNull ??
            ctx.companyCurrency;
  final precision = currency?.precision ?? 2;
  final dayFirstHint = currencyCode == 'EUR' || currencyCode == 'GBP';

  // Total: the last TOTAL-like row with an amount.
  ReceiptField<Decimal>? total;
  var tipWithoutAmount = false;
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    final f = row.folded;
    if (_hasWord(f, _tipWords) && _moneyIn(row, precision).isEmpty) {
      tipWithoutAmount = true;
    }
    if (!_hasWord(f, _totalWords)) continue;
    if (!_hasWord(f, _strongTotalWords) && _hasWord(f, _notTotalWords)) {
      continue;
    }
    final taxRow = _hasWord(f, _taxWords);
    if (taxRow && !_hasWord(f, _inclusiveWords)) continue;
    var money = _moneyIn(row, precision);
    // The amount sometimes lands a row lower: a label printed above it, or
    // a slanted photo. Take it only from a row that is just a number.
    if (money.isEmpty && i + 1 < rows.length) {
      final next = rows[i + 1];
      final hasLetters = RegExp(
        r'\p{L}{2,}',
        unicode: true,
      ).hasMatch(next.text.replaceAll(RegExp(r'\b[A-Z]{3}\b'), ''));
      if (!hasLetters) money = _moneyIn(next, precision);
    }
    final positive = money.where((a) => a.value > Decimal.zero).toList();
    if (positive.isEmpty) continue;
    final value = positive.last.value;
    // `GST INCL. IN TOTAL 3.85` under `TOTAL 42.30` is the tax in the total,
    // not a new total.
    if (taxRow && total != null && value < total.value) continue;
    total = ReceiptField(value, ReceiptConfidence.sure);
  }
  if (total == null) {
    // The largest decimal amount in the lower part that isn't change, cash,
    // a discount or a tip — a guess.
    Decimal? best;
    final from = (rows.length * 0.4).floor();
    for (final row in rows.skip(from)) {
      if (_hasWord(row.folded, _notTotalWords)) continue;
      if (_hasWord(row.folded, _taxWords)) continue;
      for (final a in _moneyIn(row, precision)) {
        if (!a.hasDecimals && precision > 0) continue;
        if (a.value <= Decimal.zero) continue;
        if (best == null || a.value > best) best = a.value;
      }
    }
    if (best != null) total = ReceiptField(best, ReceiptConfidence.check);
  }
  if (total != null && tipWithoutAmount) {
    total = ReceiptField(total.value, ReceiptConfidence.check);
  }

  // Taxes: one per tax row, de-duplicated by rate.
  final taxes = <ReceiptTax>[];
  for (final row in rows) {
    final f = row.folded;
    if (!_hasWord(f, _taxWords)) continue;
    // `VAT No GB123…`, `USt-IdNr`, `VAT: GB 123 4567 89`, `TAX INVOICE 0042`
    // — an identifier or a heading, not an amount.
    if ((_hasWord(f, _taxIdWords) ||
            RegExp(r'\b[A-Z]{2}\s?\d{3}').hasMatch(row.text)) &&
        !_percentPattern.hasMatch(row.text)) {
      continue;
    }
    final rate = _percent(row.text);
    final money = _moneyIn(row, precision);
    var amount = money.isEmpty ? null : money.last.value;
    if (amount != null && total != null && amount >= total.value) {
      amount = null; // "Total incl. VAT 23.80" — the total again.
    }
    if (rate == null && amount == null) continue;
    final name = _taxWords
        .firstWhere((w) => _hasWord(f, [w]), orElse: () => 'tax')
        .toUpperCase();
    final tax = ReceiptTax(name: name, rate: rate, amount: amount);
    // The same tax printed twice (a summary block repeating a line) is one
    // tax; CGST and SGST at the same rate are two.
    final same = taxes.indexWhere(
      (t) =>
          t.name == name &&
          (t.rate != null
              ? t.rate == rate
              : rate == null && t.amount == amount),
    );
    if (same >= 0) {
      taxes[same] = tax;
    } else {
      taxes.add(tax);
    }
  }

  // Date: one on a DATE row wins, else the first one found.
  ReceiptField<Date>? date;
  for (final row in rows) {
    final found = _datesIn(row, ctx, dayFirstHint: dayFirstHint);
    if (found.isEmpty) continue;
    if (_hasWord(row.folded, _dateWords)) {
      date = found.first;
      break;
    }
    date ??= found.first;
  }

  // A currency that only repeats the company's is not worth a field.
  final reportedCurrency =
      currencyCode != null &&
          currencyCode != ctx.companyCurrency?.code.toUpperCase()
      ? currencyCode
      : null;

  return ReceiptScan(
    total: total,
    date: date,
    taxes: taxes,
    vendorName: _vendorIn(rows),
    currencyCode: reportedCurrency,
    receiptNumber: _receiptNumberIn(rows),
  );
}

/// [parseReceiptRows] over raw engine fragments.
ReceiptScan parseReceiptText(
  Iterable<OcrFragment> fragments,
  ReceiptParseContext ctx,
) => parseReceiptRows(rebuildRows(fragments), ctx);
