# How a local list search matches text

Companion to CLAUDE.md § Sync — non-obvious rules. That section carries the rule (every local search predicate goes through `searchLike`). This doc covers why SQLite can't do this on its own, how the fold works without folding the stored data, how contacts are matched, and what each piece cost when measured. The code is `lib/utils/search_fold.dart` (the fold table) and `lib/data/db/dao/_search_fold.dart` (the SQL).

## Every local search predicate goes through searchLike

**What shipped.** A German user reported that searching for `Müller` "does not always work", and that typing `mue` sometimes did (invoiceninja/flutter, Oct 2026). The `mue` hit was luck: it matched an ASCII email such as `mueller@…`.

**Why.** A list shows only what the local Drift `watchPage(search:)` returns. The server's `filter=` matches are upserted into Drift and then read back through that same local predicate. So the local SQL has the final say, and anything it rejects disappears, even a row the server found. That local SQL was SQLite, and SQLite folds case **for ASCII only**:

- `LIKE` ignores case for `A`–`Z` and nothing else, so `über` did not match `Überseehandel`. This affected `client_dao`, `vendor_dao` and `user_dao`, which compared the raw search.
- `lower()` lowercases `A`–`Z` and nothing else. Every other DAO did `col.lower().like(search.toLowerCase())`. Dart lowercases the search (`Ü`→`ü`), but `lower('Österreich')` stays `Österreich`, so a capital umlaut in the data could never match.
- Neither build has ICU or a Unicode extension. The native `libsqlite3mc`'s compile options list only FTS5, RTREE, math and session. `web/sqlite3.wasm` is a plain build.
- Text stored decomposed (`u` + U+0308) never matched a typed `ü`.

**What the server does.** It is MySQL with `utf8mb4_unicode_ci`, which ignores both case **and** accents (`ü` = `u`). The old app (`admin-portal/lib/utils/strings.dart` `matchesString`) used Dart's `toLowerCase().contains`: Unicode case folding, no accent folding.

**The rule.** `searchLike(value, search)` matches exactly when `foldSearchText(value).contains(foldSearchText(search))`:
- case is folded in every script;
- accents are folded through `kSearchFoldMap`, which covers Latin-1 and Latin Extended-A (`ü`→`u`, `ß`→`ss`, `æ`→`ae`, `Ł`→`l`, …);
- the common combining marks are dropped.

That makes the local match a superset of both the server's and the old app's. Folding more than the server does can only surface an extra cached row offline, which is harmless; folding less hides rows the server found.

What this means for a German user: `mü`, `MÜ` and `mu` all find `Müller`. `mueller` finds it only through an ASCII email, the same as on the server and in the old app.

`test/data/db/dao/search_fold_sql_test.dart` pins the rule. It checks every value × search pair in a corpus against `foldSearchText(value).contains(foldSearchText(search))` in Dart, because the SQL never runs the Dart fold and that test is the only thing holding the two together.

## The fold runs on the search, not on the stored value

The obvious implementation nests one `replace()` per table entry (205 of them) around each column and then calls `lower()`. It is correct, and it made `clients.list_search` ten times slower (1.4 → 13 ms; the replace chain allocates a new string per call). The shipped version folds the *search* instead:

- **An all-ASCII value** (`length(x) = octet_length(x)`, which is nearly every row) takes `x LIKE '%<folded search>%' ESCAPE '\'`. For such a value SQLite's ASCII case folding *is* the whole fold, and a non-ASCII letter in the folded search can't match it anyway.
- **Any other value** is matched by `GLOB` with one character class per search letter, listing every character that folds to it: `garcia` becomes `*[gGĝğġģĜĞĠĢ][aAàá…]…*`. The class also holds the letter's own uppercase, so Cyrillic and Greek fold too (`дми` finds `ДМИТРИЙ`), which a `replace()` chain could never do.
- **Ligatures**: a search pair that a single letter folds to (`ss` ← `ß`, `ae` ← `æ`, `oe`, `ij`, `th`) gets one more pattern with that letter in its place, up to 8 variants. The all-letters reading always comes first, so the cap never drops it. A pair can also be cut in half at the edges of a match (`as` is in `aß` → `ass`), so the first and last classes take the ligatures that end or start with their letter.
- **Combining marks** are stripped from the stored value with 14 `replace()` calls, but only when it has one. The guard is `instr(CAST(x AS BLOB), x'CC') > 0`, a byte search. Every stripped mark encodes with the UTF-8 lead byte `0xCC`, and a lead byte is never a continuation byte, so the guard is exact. A `GLOB '*[marks]*'` guard cost fifteen times as much.
- `%`, `_` and `\` are escaped for `LIKE`; `*`, `?` and `[` become one-character classes for `GLOB`. No DAO escaped `%` / `_` before, so `50%` used to match `500`.

**Measured** (M2 Pro, `dart tools/perf/main.dart run --name list_search`; HEAD → this design):

| Benchmark | Before | `replace()` chain | GLOB only | GLOB + ASCII `LIKE` |
|---|--:|--:|--:|--:|
| `clients.list_search` | 1.4 | 13.4 | 2.8 | 2.4 |
| `invoices.list_search` | 12.3 | — | 16.6 | 15.6 |

The figures are ms with no contact matching, except the last invoice column, which includes it. The leftover cost is the ASCII check on each value.

**JSON-held fields** (`payloadJsonLike`: notes, transaction reference) pass `COALESCE(json_extract(payload, …), '')` as the value, so it is evaluated more than once per row. SQLite's JSON parse cache makes the repeat cheap. Guarding on the whole payload instead (`instr` over 10 KB of invoice JSON) was slower (21 ms against 16.6), and so was always stripping marks (19.4 ms).

## A contact is matched through a pre-folded column, not the payload

`ClientFilters::filter` searches each client's contacts (first name, last name, email, phone). `VendorFilters` searches the vendor's contacts (first, last, email). The invoice, quote, credit, recurring invoice, payment and task filters search `client.contacts` (first, last, email). Locally, contacts live only inside each row's `payload`, so the local search used to drop every server row found through a contact (`Jürgen`).

Reading them from the payload (`json_tree` over `$.contacts`) is correct and costs a JSON parse of every payload on every keystroke. It made `clients.list_search` 16 ms and `invoices.list_search` 32 ms, and the cost grows with the account. So since schema v16:

- `clients.contact_search` / `vendors.contact_search` hold every contact's searchable fields, already run through `foldSearchText`, one per line (`foldedSearchLines`). The one-per-line layout means no search word can match across two fields: a word never holds a newline. Different words of one search may match different contacts' fields (see [Every list search matches each word on its own](#every-list-search-matches-each-word-on-its-own)).
- Both companion mappers in each repository write the column. Those mappers are the only writers of contacts; `rekeyRow` moves only the payload's `id`.
- A match is `instr(contact_search, foldSearchText(search)) > 0` (`contactSearchMatches`), which is exact because both sides are already folded.
- **A NULL column is a row stored before v16.** The search reads that row's payload instead (the `json_tree` path, with a `{`-prefix shape check, since a `json_valid` guard parsed every payload twice). Folding is Dart work over every payload, too slow to run in `onUpgrade` in front of `runApp()`. So `fillContactSearch` fills the old rows in batches of 200 after a company activates (`Services` → `_fillContactSearch`). It notifies no watcher, because the search returns the same rows either way, only faster. Its update is guarded with `IS NULL`, so a row a mapper rewrote meanwhile keeps the newer value.
- The client column carries the phone because `ClientFilters` searches it. The billing documents, which search `client.contacts` without the phone, read the same column, a superset like the accent folding.

Pinned by `client_vendor_name_search_test.dart` (the fallback path: rows inserted with the column NULL) and `migration_test.dart` › v15 → v16 (NULL after the upgrade, found through the payload, filled, found through the column).

## Line items are matched per value, from the payload

The server's search on all five billing documents — `InvoiceFilters`, `QuoteFilters`, `CreditFilters`, `RecurringInvoiceFilters` and `PurchaseOrderFilters` → `filter()` — matches `line_items[*].notes` and `line_items[*].product_key`. The local predicates left line items out, so a document the server found through one was fetched and then hidden: searching a product or a work description found nothing (invoiceninja/flutter#185).

`lineItemSearchMatches` (`_search_fold.dart`) is the last term of each DAO's search, so a row a cheaper field already matched never walks its JSON. It is an `EXISTS` over `json_tree(jsonb(<payload>), '$.line_items')`, keeping only the `notes` and `product_key` nodes and running `searchLike` on each value:

- Each value is matched on its own, so one search *word* never spans two items or two fields (the server's LIKE over the serialised array can; see Known limits). Different words of one search may match different items, since the helper is called once per word.
- The `{` shape check is the contacts path's: a payload that isn't a JSON object, or has no `line_items`, matches nothing rather than throwing.
- Not a scalar subquery handed to `searchLike`: it repeats its value several times in the SQL (length, octet_length, LIKE, every GLOB variant), and SQLite re-runs a correlated subquery each time.

The cost lands on rows nothing else matched — every item of every such row is walked. On `invoices.list_search` (5,000 invoices × 8 lines, a term no line item holds, so the worst case), scaled to the reference machine:

| Shape | ms | Budget |
|---|--:|--:|
| Before line items | 14.5 | 36 |
| `json_tree(<payload>)` — the contacts path as is | ~41 | 36 |
| `json_tree(jsonb(<payload>))` — shipped | 33.7 | 36 |
| `json_each` + `->>` per key | 59.3 | 36 |

`jsonb()` lets the walk reuse the parse the notes search (`json_extract`) already made of the same payload in the statement; `json_tree` on the text would parse it again. Extracting the two keys per item with `->>` was slower still, because each repetition inside `searchLike` reads the item again. The budget's `since` accepts the slowdown. If the account sizes it is measured against grow, the next step is the contacts approach — a pre-folded column written by the mappers (§ A contact is matched through a pre-folded column).

Pinned by `line_item_search_test.dart`: the helper on its own (fields, folding, no cross-item or cross-field match, every malformed shape, literals), and each of the five DAOs through `watchPage(search:)`.

## Dates and amounts are matched the way the server renders them

`InvoiceFilters`, `CreditFilters` and `PurchaseOrderFilters` also LIKE `date`, `amount` and `balance`; `RecurringInvoiceFilters` `date` and `amount`; `QuoteFilters` none of them. The local predicates left them out — the same fetched-then-hidden bug as line items, for a typed date or amount (found alongside #185).

- **A date** (`YYYY-MM-DD` text on both sides) goes through `serverDateLike`, a plain `searchLike`.
- **An amount** is a MySQL `decimal(20,6)`, which LIKE reads as `150.000000`, so `150.00` finds an amount of 150 there. Locally it is stored as text (`150`), so `serverDecimalLike` matches `printf('%.6f', CAST(amount AS REAL))` instead of the column.
- **Both answer in Dart when the search can't match**: those strings hold only digits, `-` (and `.`), so a search with any other character skips the comparison and the per-row `printf`. Without that the 5,000-invoice text search went from 33.7 to 36.1 ms, over its budget; with it, a text search costs nothing extra.

Pinned by `billing_search_server_fields_test.dart`.

## A payload that isn't a JSON object never breaks a search

`payloadJsonLike` (the notes search on billing documents, expenses, recurring expenses and payments) called `json_extract` on every row's payload. On a payload that isn't JSON (`''` on an old row) SQLite throws "malformed JSON", and the whole list's search failed, not just that row's match — though only for a search that reached that row's notes, so one that matched the number first hid it. It now uses the same `{` shape check as the contacts and line-item searches, and reads such a payload as empty. Pinned by `billing_search_server_fields_test.dart` › a payload that is not a JSON object never breaks the search.

## Client search splits on spaces, like the server

`ClientFilters::filter` splits the search on spaces and requires every word to match some field. Locally the whole text was one pattern, so `Hans Müller` found only a client whose name held that exact phrase, and `Müller Hans` found nothing. `ClientDao.watchPage` now ANDs one group per word. Every other DAO does too now, through `everyWordMatches` — see the next section.

## Every list search matches each word on its own

**What shipped.** A user moving from the old desktop app reported that `s22 120hz` did not find "Samsung Galaxy S22 5G OLED 120Hz Screen (TCGJ)": the old app split the search into words, and this one matched the whole text as one phrase, so the words had to sit side by side in one field.

**The rule.** `searchWords` (`lib/utils/search_fold.dart`) splits the text on any whitespace, drops words with no letter or digit (`-`, `&`), dedupes them after folding, drops a word contained in another (`s2` beside `s22`), and keeps at most `kMaxSearchWords` (8 — each word is one OR chain of `searchLike`s, each binding up to nine SQL variables). A query that cleaning would empty (`-`, `- -`) keeps its whitespace-split words — as `ClientFilters` splits them — never "match everything". Every word must then match *some* field — different words may match different fields — through `everyWordMatches` (`_search_fold.dart`) in every DAO's `watchPage`, and `containsEveryWord` / `fieldsMatchEveryWord` in Dart, accents folded. The Dart side is every picker and in-memory search: the searchable dropdowns (every entity, statics and gateway picker), the line-item cells (product, tax rate, dropdown custom field) and the line-item picker's task and expense tabs, every `key:` filter's value list (statuses, tags, categories, custom values, countries, currencies…), the transaction-match pickers, the template and invoice-designer variable pickers, the design "add field" dialog, the report gallery, saved views, column, group-by and filter-choice pickers and the report row search, the command palette's report hits, `/activity`, tags and the debug panel's network filter. Settings search keeps its ranking (prefix, then word start, then every word) but compares folded text and takes its words from `searchWords`. Left as they are, on purpose: prefix suggestions (`quickValueSuggestions`, date presets, filter-key names), the code editor's single-token completions, a report's per-column "contains" filter, and the `name:` / `vat_number:` filter tokens, which mirror the server's phrase `LIKE`. `everyWordMatches` runs the longest word first, the likeliest to reject a row early.

**Why nothing disappears locally.** A field holding the phrase holds each of its words, so the every-word match is a superset of the old phrase match: no cached row that matched before is hidden. A one-word search is unchanged. On the server side the trade is different — one word returns more rows than the phrase did, so a row the phrase had on page 1 can now sit a few pages in. That is what the refill, Load more and the pickers' phrase fetch (below) are for.

**Measured** (M2 Pro, `dart tools/perf/main.dart run --name list_search`, 5,000 invoices): the two-word `invoices.list_search` (`Region 3`) 11.3 ms median, the one-word `invoices.list_search_one_word` (`Region`) 8.6 ms — the longest word runs first and rejects most rows before the second word's line-item walk.

**What the server is sent.** Only `ClientFilters` splits words; every other `*Filters::filter` LIKEs the whole text, so sending `s22 120hz` finds nothing. `BaseEntityRepository.wireSearchTerm` sends such a server `serverSearchTerms(search).first` instead — a word with letters and digits, letter first (`s22`, `INV-0012`, what people type when they know what they want), then digit first (`120hz`), then letters only, longest first, and a word with no letter at all (`2`, `2024`) last: the servers LIKE dates, amounts, balances and time logs, so `%2%` matches nearly every invoice and would page through the whole table for one row. The local every-word search narrows the superset it returns. `serverSplitsSearchWords` is `true` only on `ClientRepository`. An exact-name lookup passes `phraseOnWire: true` (the vendor duplicate check in `vendor_inline_create.dart`): the phrase is the narrowest term there, and three pages of `International` could miss "Acme Holdings International".

**Lists page through the superset.** A page of rows matching one word can filter down to a few — no scroll extent, so the scroll trigger never fires. A multi-word search therefore counts as a local-only narrowing (`GenericListViewModel.localOnlyFilterActive`), and a short page auto-chains `loadMore`, like `stock:` and `tag:`, for up to five pages. Between chained pages `refillPending` keeps the loading footer up instead of a flash of "No records found" (it goes false after a failed fetch, which ends the chain, so a spinner never outlives one). When that budget is spent with the server holding more and the list still short, `autoChainExhausted` puts a **Load more** button in the empty state (`NoMatchActions`) and in the list footer; it re-arms the budget (`continueAutoChain`). For clients the server's page is exact, so `hasMore` ends the chain on its own.

**Pickers fetch per word.** A picker reads page 1 only, and page 1 of the one word sent can hold none of the wanted rows (`screen` on a phone-parts catalog). `ensureSearchLoaded` (`lib/data/repositories/search_fetch.dart`) fetches page 1 of the whole phrase (`phraseOnWire`) and of the first two `serverSearchTerms`, in parallel — a search-scoped fetch never touches the cursor, so they don't interfere — or once, whole, when the server splits. The phrase fetch is what keeps a picker from offering to create a record that exists: "Web Hosting Basic" in a catalog of a hundred hosting products is on page 1 of the phrase, not necessarily of any one word. The desktop line-item product cell, the mobile line-item picker and the `client:` / `vendor:` / `project:` suggestions (`namesWithServerSearch`) use it. The two line-item pickers also pass `rankSearch: true` to `ProductDao.watchPage`, which leads with the rows whose product key alone holds every word; the desktop cell lifts an exact key above even those, since Tab / Enter takes the first row.

**Expenses search their amount.** `ExpenseFilters` and `RecurringExpenseFilters` LIKE `amount`; the two DAOs now match it through `serverDecimalLike`, as the billing documents do, so a server match on the amount is no longer hidden (`expense_amount_search_test.dart`).

**Exact-name checks squash whitespace.** The "is this already a product / vendor / expense category" checks that hide a Create row compare `squashWhitespace` + `foldSearchText` on both sides, so `Acme  Corp` is not offered as a new record beside `Acme Corp`.

**What was left out.** Fuzzy (subsequence) matching — the old app's opt-in "flexible search" — was rejected: no server filter can do it, so it would only ever search the cache; in SQL it is a GLOB class per letter on top of the fold's (the ~10× cost measured above); and it is noisy (`s22` matches any text with an `s` then two `2`s). A server change that splits every entity's filter into words like `ClientFilters` is tracked in `BACKEND.md` § H4; once a release carries it, `serverSplitsSearchWords` becomes a version check and list pages are exact again.

Pinned by `search_fold_test.dart` (the word rules and the server term), `product_dao_search_test.dart` (the feedback case, order, fields, ranking), `line_item_search_test.dart` (every billing list), `client_vendor_name_search_test.dart`, `search_fetch_test.dart`, the vendor / client repository wire tests, `generic_list_view_model_smoke_test.dart` › a multi-word search, `entity_list_empty_state_test.dart` › Load more, `searchable_dropdown_field_test.dart` and `line_item_picker_create_product_test.dart`.

## Dart-side matchers fold too

The suggestion lists inside the search field filter in Dart: the `client:` / `vendor:` / `project:` names (`server_name_suggestions.dart`), the country, group, industry, size, user, currency and language keys (`client_filter_keys.dart`), and the searchable dropdowns (`searchable_dropdown_field.dart`). They use `foldSearchText` on both sides, so `oster` offers `Österreich` and the offline suggestions agree with the list.

The `/activity` search does too (`ActivityViewModel._matchesBase`: the rendered title, the notes and every label). It used plain `toLowerCase().contains`, and in a right-to-left locale `ActivityFormatter` wraps each substituted value in U+2068 … U+2069, so a search spanning a value and the words around it (`العميل Globex`) matched nothing. `foldSearchText` strips bidi controls; the title memo holds the folded string, since the search is its only reader. `activity_view_model_test` › search matches across the bidi isolates of an RTL title.

## Known limits

- The accent table covers Latin-1 Supplement and Latin Extended-A. A letter outside it (Vietnamese `ạ`, Latin Extended-B) matches only itself, in either case. Extending it is a data change to `_kFoldGroups`, and the parity test then covers the new entries.
- Sorting is untouched. `ORDER BY lower(name)` still places `Ö` after `z`.
- A search with more than three ligature pairs (`ss`, `ae`, `oe`, `ij`, `th`) gets only eight `GLOB` variants. The later pairs then match only as two letters, so they no longer find a `ß` or `æ` in a non-ASCII value. The all-letters reading is always kept.
- The server LIKEs line items as one serialised array (`["notes …", "SKU…"]`), so a search word spanning two items, or holding the JSON's own quotes and commas, can match there and not locally. Matching each value on its own is deliberately narrower.
- An amount is compared as a double (`CAST(amount AS REAL)`), so one with more than about fifteen significant digits can render differently from MySQL's exact decimal in its last places.
- `%` and `_` are literal locally, while the server's `LIKE` treats them as wildcards. This deliberately breaks the superset rule: `50%` no longer finds `500`, so a server row matched only through a wildcard is hidden.
