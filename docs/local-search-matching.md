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

- `clients.contact_search` / `vendors.contact_search` hold every contact's searchable fields, already run through `foldSearchText`, one per line (`foldedSearchLines`). The one-per-line layout means no search can match across two fields: a search never holds a newline.
- Both companion mappers in each repository write the column. Those mappers are the only writers of contacts; `rekeyRow` moves only the payload's `id`.
- A match is `instr(contact_search, foldSearchText(search)) > 0` (`contactSearchMatches`), which is exact because both sides are already folded.
- **A NULL column is a row stored before v16.** The search reads that row's payload instead (the `json_tree` path, with a `{`-prefix shape check, since a `json_valid` guard parsed every payload twice). Folding is Dart work over every payload, too slow to run in `onUpgrade` in front of `runApp()`. So `fillContactSearch` fills the old rows in batches of 200 after a company activates (`Services` → `_fillContactSearch`). It notifies no watcher, because the search returns the same rows either way, only faster. Its update is guarded with `IS NULL`, so a row a mapper rewrote meanwhile keeps the newer value.
- The client column carries the phone because `ClientFilters` searches it. The billing documents, which search `client.contacts` without the phone, read the same column, a superset like the accent folding.

Pinned by `client_vendor_name_search_test.dart` (the fallback path: rows inserted with the column NULL) and `migration_test.dart` › v15 → v16 (NULL after the upgrade, found through the payload, filled, found through the column).

## Client search splits on spaces, like the server

`ClientFilters::filter` splits the search on spaces and requires every word to match some field. Locally the whole text was one pattern, so `Hans Müller` found only a client whose name held that exact phrase, and `Müller Hans` found nothing. `ClientDao.watchPage` now ANDs one group per word. No other server filter splits, so no other DAO does.

## Dart-side matchers fold too

The suggestion lists inside the search field filter in Dart: the `client:` / `vendor:` / `project:` names (`server_name_suggestions.dart`), the country, group, industry, size, user, currency and language keys (`client_filter_keys.dart`), and the searchable dropdowns (`searchable_dropdown_field.dart`). They use `foldSearchText` on both sides, so `oster` offers `Österreich` and the offline suggestions agree with the list.

The `/activity` search does too (`ActivityViewModel._matchesBase`: the rendered title, the notes and every label). It used plain `toLowerCase().contains`, and in a right-to-left locale `ActivityFormatter` wraps each substituted value in U+2068 … U+2069, so a search spanning a value and the words around it (`العميل Globex`) matched nothing. `foldSearchText` strips bidi controls; the title memo holds the folded string, since the search is its only reader. `activity_view_model_test` › search matches across the bidi isolates of an RTL title.

## Known limits

- The accent table covers Latin-1 Supplement and Latin Extended-A. A letter outside it (Vietnamese `ạ`, Latin Extended-B) matches only itself, in either case. Extending it is a data change to `_kFoldGroups`, and the parity test then covers the new entries.
- Sorting is untouched. `ORDER BY lower(name)` still places `Ö` after `z`.
- A search with more than three ligature pairs (`ss`, `ae`, `oe`, `ij`, `th`) gets only eight `GLOB` variants. The later pairs then match only as two letters, so they no longer find a `ß` or `æ` in a non-ASCII value. The all-letters reading is always kept.
- `%` and `_` are literal locally, while the server's `LIKE` treats them as wildcards. This deliberately breaks the superset rule: `50%` no longer finds `500`, so a server row matched only through a wildcard is hidden.
