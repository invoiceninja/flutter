/// Stored footers shared by the HTML-source tests (invoiceninja/flutter#174).
library;

/// The footers `MarkdownTextField` used to destroy, by what happened to each
/// (invoiceninja/flutter#174). Every one is a three-column table; they differ
/// only in who wrote the markup.
///
/// What the web app's TipTap editor writes: flattened to three paragraphs.
const kTipTapTable =
    '<table style="min-width: 75px"><colgroup><col style="min-width: 25px">'
    '<col style="min-width: 25px"><col style="min-width: 25px"></colgroup>'
    '<tbody><tr><td colspan="1" rowspan="1"><p>Company GmbH</p></td>'
    '<td colspan="1" rowspan="1"><p>Bank: ACME</p></td>'
    '<td colspan="1" rowspan="1"><p>VAT: DE123</p></td></tr></tbody></table>';

/// The legacy TinyMCE editor, which pretty-prints: flattened the same way.
const kTinyMceTable =
    '<table style="border-collapse: collapse; width: 100%;" border="1">'
    '<colgroup><col style="width: 33.3333%;"><col style="width: 33.3333%;">'
    '<col style="width: 33.3333%;"></colgroup>\n<tbody>\n<tr>\n'
    '<td>Company GmbH</td>\n<td>Bank: ACME</td>\n<td>VAT: DE123</td>\n'
    '</tr>\n</tbody>\n</table>';

/// Hand-written and indented: everything after the first line became one
/// code block.
const kIndentedTable =
    '<table width="100%">\n  <tr>\n    <td>\n      Company GmbH<br>\n'
    '      Street 1\n    </td>\n    <td>\n      Bank: ACME<br>\n'
    '      IBAN: DE00\n    </td>\n    <td>\n      VAT: DE123\n    </td>\n'
    '  </tr>\n</table>';

/// Hand-written with a valueless attribute, an unquoted value holding a
/// space, and smart quotes — three shapes the fold's tag pattern refuses.
/// Each reached the editor as a **blank document**: the report's "appears
/// empty".
const kBlankingTables = <String>[
  '<table><tr><td nowrap>Company GmbH</td><td nowrap>Bank: ACME</td>'
      '<td nowrap>VAT: DE123</td></tr></table>',
  '<table width=100%><tr><td style=width:33%; text-align:left>Company</td>'
      '<td style=width:33%; text-align:center>Bank</td>'
      '<td style=width:33%; text-align:right>VAT</td></tr></table>',
  '<table><tr><td style=“width: 33%”>Company</td>'
      '<td style=“width: 33%”>Bank</td><td style=“width: 33%”>VAT</td>'
      '</tr></table>',
];
